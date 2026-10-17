// 播放器组件（批 D）：把解码出来的帧回灌进自绘像素，配一条控制条与字幕叠加。
//
// 三条口径：
// ① **CPU 回灌 + 软解**（方案 §4.2 第 3 条）：帧走 `@render.Bitmap` → `Painter`，
//    不走子表面，所以画面能被裁剪、能盖浮层、能与自绘控件混排；
// ② 时钟在引擎里（墙钟 + 帧时间戳），UI 只负责每 tick 推一步并重绘；
//    排期通道用 `@shell.set_timeout`（本栈的进程级延时通道），组件不自己起线程；
// ③ seek 防抖：拖动进度条期间只更新**显示位置**，抬手才真 seek——旧链的坑是
//    每次拖动都 seek 一次，关键帧距离长时画面会卡一整拍。

///|
/// 解码帧（RGBA，行主序）→ 本栈位图（BGRA 预乘）。alpha 一律置 255，
/// 预乘与非预乘在不透明像素上同值，所以只需换 R/B。
pub fn rgba_to_bitmap(
  rgba : Bytes,
  width : Int,
  height : Int,
) -> @render.Bitmap {
  let bm = @render.Bitmap::new(width, height)
  let n = width * height * 4
  let have = if rgba.length() < n { rgba.length() } else { n }
  let data = bm.data
  let mut i = 0
  // 一个像素只要凑齐 R/G/B 三字节就写（alpha 恒置不透明）
  while i + 3 <= have {
    data[i] = rgba[i + 2]
    data[i + 1] = rgba[i + 1]
    data[i + 2] = rgba[i]
    data[i + 3] = b'\xff'
    i = i + 4
  }
  bm
}

///|
/// 视频播放控件：画面（`vp_fit_rect` 三档缩放）+ 字幕叠加 + 共用控制条。
/// `subtitle` 传**已读好的字幕文本**（SRT/VTT，外部文件的读取归调用方，
/// 本组件不碰使用者的磁盘路径）；留空时组件会试一次**容器内嵌轨**（那是媒体文件
/// 自己的内容，走解码器不是走 IO）。打不开时不抛异常——画一块说明板并把原因
/// 经 `on_error` 交出去（探测 + 降级不静默）。
pub fn video(
  path : String,
  subtitle? : String = "",
  width? : Double = 640.0,
  height? : Double = 360.0,
  auto_play? : Bool = false,
  /// 每 tick 的观测口（位置秒 / 已解码帧数 / 是否在播）：示例与测试靠它证明
  /// 「帧在推进、时钟在走」，而不是一张贴图。
  on_tick? : (Double, Int, Bool) -> Unit = fn(
    _t : Double,
    _frames : Int,
    _playing : Bool,
  ) -> Unit { () },
  /// 倍速档位变化的观测口（控制条点倍速键时回调）：调用方要把它显示到
  /// 界面或写进回证时不必去猜引擎状态。
  on_speed? : (Double) -> Unit = fn(_v : Double) -> Unit { () },
  /// 字幕来源的观测口（条数 + 是否来自内嵌轨），打开时回调一次：外部文本与
  /// 内嵌轨在界面上是同一排字，调用方要区分得从这里取，而不是猜文件旁边有没有 .srt。
  on_subtitle? : (Int, Bool) -> Unit = fn(_n : Int, _embedded : Bool) -> Unit {
    ()
  },
  on_error? : (String) -> Unit = fn(_s : String) -> Unit { () },
  handle? : (@widget.Widget) -> Unit = fn(_w : @widget.Widget) -> Unit { () },
) -> @widget.Node {
  let engine = match VideoPlayer::make(path) {
    Ok(p) => p
    Err(e) => {
      on_error(e)
      return media_error_board(
        "打不开媒体：" + e,
        width,
        height,
        handle,
      )
    }
  }
  // 字幕两条来源：调用方给的外部文本优先（那是明确意图）；没给才试容器的内嵌轨。
  // 内嵌轨只在打开时整条读一次（字幕稀疏，一次读完比逐帧查解码器便宜，也不碰主
  // 时间轴的读位置），之后照常按位置查表。读失败不阻断播放，但原因照 `on_error`
  // 交出去——「这条片没字幕」与「字幕轨解不开」不能混成同一个空表。
  let none_cue : Array[Cue] = []
  let from_embedded = subtitle.length() == 0
  let cues =
    if !from_embedded {
      subtitle_parse(subtitle)
    } else {
      match @ffmbt.subtitle_cues(path) {
        Ok(list) => subtitle_from_embedded(list)
        Err(e) => {
          on_error("内嵌字幕读取失败：" + e.to_string())
          none_cue
        }
      }
    }
  on_subtitle(cues.length(), from_embedded && cues.length() > 0)
  let frame_no : Ref[Int] = Ref(-1)
  let image : Ref[@render.Image?] = Ref(None)
  let dragging : Ref[Bool] = Ref(false)
  let speed_i : Ref[Int] = Ref(0)
  // 按钮行是**真控件**，档位/态变了要重挂，所以读数走 Store（`Store::set` 等值
  // 不重发，每 tick 刷一次不产生重建）
  let playing : @base.Store[Bool] = @base.Store::new(false)
  let speed_st : @base.Store[Double] = @base.Store::new(1.0)
  let full_st : @base.Store[Bool] = @base.Store::new(false)
  let zoom_st : @base.Store[Int] = @base.Store::new(0)
  if auto_play {
    engine.play()
  }
  playing.set(engine.is_playing())
  fn toggle() -> Unit {
    if engine.is_playing() {
      engine.pause()
    } else {
      engine.play()
    }
    playing.set(engine.is_playing())
    @widget.invalidate()
  }
  fn step_by(n : Int) -> Unit {
    // 逐帧：引擎自己先暂停再解到落点，组件不碰时钟
    engine.step(n)
    playing.set(engine.is_playing())
    @widget.invalidate()
  }
  fn cycle_speed() -> Unit {
    speed_i.val = speed_i.val + 1
    let v = bar_speed_at(speed_i.val)
    engine.set_speed(v)
    speed_st.set(v)
    on_speed(v)
    @widget.invalidate()
  }
  fn toggle_full() -> Unit {
    let on = !full_st.get()
    if player_set_fullscreen(on) {
      full_st.set(on)
      @widget.invalidate()
    }
  }
  fn cycle_zoom() -> Unit {
    zoom_st.set((zoom_st.get() + 1) % 3)
    @widget.invalidate()
  }
  fn bump_vol(d : Double) -> Unit {
    engine.set_volume(bar_clamp01(engine.get_volume() + d))
    @widget.invalidate()
  }
  let screen = @widget.Widget::new()
  screen.node.set_flex_grow(1.0)
  screen.node.set_min_height(@yoga.fixed(40.0))
  screen.on_draw = Some(fn(
    _w : @widget.Widget,
    p : @render.Painter,
    r : @base.Rect,
  ) -> Unit {
    p.set_fill_color("#000000")
    p.fill_rect(0.0, 0.0, r.w, r.h)
    let cur = engine.current_frame()
    match cur {
      None => ()
      Some(rgba) => {
        let no = engine.frames_decoded()
        if no != frame_no.val {
          frame_no.val = no
          let bm = rgba_to_bitmap(rgba, engine.frame_width(), engine.frame_height())
          image.val = Some(@render.Image::from_bitmap(bm))
        }
        match image.val {
          None => ()
          Some(img) => {
            // 三档缩放（适配/铺满/1:1）都居中，超出部分由控件矩形裁掉
            let vw = engine.frame_width().to_double()
            let vh = engine.frame_height().to_double()
            let box = vp_fit_rect(vw, vh, r.w, r.h, zoom_st.get())
            if box.2 > 0.0 {
              p.draw_image(img, box.0, box.1, box.2, box.3)
            }
          }
        }
      }
    }
    let sub = subtitle_at(cues, engine.current())
    if sub.length() > 0 {
      p.flush()
      let _ = @text.draw_text_at(
        p,
        8.0,
        r.h - 26.0,
        sub.replace(old="\n", new=" "),
        15.0,
        "#ffffff",
      )
    }
  })
  let display = player_display(
    fn() -> Double { engine.current() },
    fn() -> Double { engine.duration() },
    fn() -> Double { engine.get_volume() },
    fn(v : Double) -> Unit {
      engine.set_volume(v)
      @widget.invalidate()
    },
    fn(t : Double) -> Unit {
      engine.seek(t)
      @widget.invalidate()
    },
    dragging,
  )
  let root = @widget.Widget::new()
  root.node.set_flex_direction(@yoga.Column)
  root.node.set_width(@yoga.fixed(width))
  root.node.set_height(@yoga.fixed(height))
  root.append_child(screen)
  let _ = player_bar(
    playing,
    speed_st,
    full_st,
    Some(zoom_st),
    @icons.ArrowLeft,
    @icons.ArrowRight,
    toggle,
    fn() -> Unit { step_by(-1) },
    fn() -> Unit { step_by(1) },
    cycle_speed,
    toggle_full,
    cycle_zoom,
    display,
  ).mount_into(root)
  player_bind_keys(
    root,
    toggle,
    fn() -> Unit { step_by(-1) },
    fn() -> Unit { step_by(1) },
    toggle_full,
    bump_vol,
    fn() -> Bool { full_st.get() },
  )
  let tick : Ref[() -> Unit] = Ref(fn() { () })
  tick.val = fn() -> Unit {
    engine.tick()
    playing.set(engine.is_playing())
    on_tick(engine.current(), engine.frames_decoded(), engine.is_playing())
    if engine.is_playing() || dragging.val {
      @widget.invalidate()
    }
    let _ = @shell.set_timeout(33, tick.val)
  }
  let _ = @shell.set_timeout(33, tick.val)
  handle(root)
  @widget.node_of(root)
}
