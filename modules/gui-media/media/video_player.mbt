// 播放器组件（批 D）：把解码出来的帧回灌进自绘像素，配一条控制条与字幕叠加。
//
// 三条口径：
// ① **CPU 回灌 + 软解**（方案 §4.2 第 3 条）：帧走 `@render.Bitmap` → `Painter`，
//    不走子表面，所以画面能被裁剪、能盖浮层、能与自绘控件混排；
// ② 时钟在引擎里（墙钟 + 帧时间戳），UI 只负责每 tick 推一步并重绘；
//    排期通道用 `@core.set_timeout`（本栈的进程级延时通道），组件不自己起线程；
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
/// 控制条分区常量：绘制与命中都读这一组，改一处不会漏另一处。
const BAR_PAUSE_W = 34.0
const BAR_STEP_W = 36.0
const BAR_SPEED_W = 40.0
const BAR_TRACK_X = 154.0
const BAR_VOL_W = 80.0
const BAR_TIME_W = 150.0
const BAR_GAP = 8.0

///|
/// 倍速档位（点一次走一档，转回 1x）。放在表里而不是就地加减，
/// 是为了让「浮点累加会不会漂出档位」这个问题不存在。
let bar_speeds : ReadOnlyArray[Double] = [1.0, 1.25, 1.5, 2.0, 0.75]

///|
/// 第 i 次点击对应的档位（i 可任意增长，含负数）。
pub fn bar_speed_at(i : Int) -> Double {
  let n = bar_speeds.length()
  let k = i % n
  bar_speeds[if k < 0 { k + n } else { k }]
}

///|
/// 倍速标签（档位表里给短写法，表外一律两位小数加 x）。
pub fn vp_fmt_speed(v : Double) -> String {
  if v == 1.0 {
    "1x"
  } else if v == 1.25 {
    "1.25x"
  } else if v == 1.5 {
    "1.5x"
  } else if v == 2.0 {
    "2x"
  } else if v == 0.75 {
    "0.75x"
  } else {
    v.to_string() + "x"
  }
}

///|
/// 音量条左端（贴着右侧时间文字，倒着排以免窄条时互相压住）。
fn bar_vol_x(w : Double) -> Double { w - BAR_TIME_W - BAR_VOL_W - BAR_GAP }

///|
/// 窄到放不下「轨道 + 音量 + 时间」三件时，音量条整个让位（绘制与命中
/// 同一条判据，否则会出现「看得见却点不着」或反过来）。
fn bar_has_volume(w : Double) -> Bool { w >= 440.0 }

///|
/// 进度轨宽度（窄到 40px 以下就不再缩，否则拖动没有分辨率可言）。
fn bar_track_w(w : Double) -> Double {
  let right = if bar_has_volume(w) {
    bar_vol_x(w) - BAR_GAP
  } else {
    w - BAR_TIME_W - BAR_GAP
  }
  let t = right - BAR_TRACK_X
  if t < 40.0 { 40.0 } else { t }
}

fn bar_clamp01(f : Double) -> Double {
  if f < 0.0 { 0.0 } else if f > 1.0 { 1.0 } else { f }
}

///|
/// 控制条的命中分区：返回 (分区名, 比例 0..1)。分区名是
/// `"pause"|"step_back"|"step_fwd"|"speed"|"seek"|"volume"|""`（空串=不响应区）。
/// 纯函数，独立于绘制与事件投递，方便无头断言。
pub fn bar_hit(
  x : Double,
  _y : Double,
  w : Double,
  h : Double,
) -> (String, Double) {
  if h <= 0.0 || w <= 0.0 {
    ("", 0.0)
  } else if x < BAR_PAUSE_W {
    ("pause", 0.0)
  } else if x < BAR_PAUSE_W + BAR_STEP_W {
    ("step_back", 0.0)
  } else if x < BAR_PAUSE_W + BAR_STEP_W * 2.0 {
    ("step_fwd", 0.0)
  } else if x < BAR_PAUSE_W + BAR_STEP_W * 2.0 + BAR_SPEED_W {
    ("speed", 0.0)
  } else if x > w - BAR_TIME_W {
    ("", 0.0)
  } else if bar_has_volume(w) && x >= bar_vol_x(w) {
    ("volume", bar_clamp01((x - bar_vol_x(w)) / BAR_VOL_W))
  } else {
    ("seek", bar_clamp01((x - BAR_TRACK_X) / bar_track_w(w)))
  }
}

///|
/// 打不开媒体时的说明板（`video` 与 `audio` 共用）：铺满底色、
/// 红字写原因，不抛异常——探测 + 降级不静默。
fn media_error_board(
  msg : String,
  width : Double,
  height : Double,
  handle : (@core.Widget) -> Unit,
) -> @core.Node {
  let w = @core.Widget::new()
  w.set_size(width, height)
  w.on_draw = Some(fn(
    _w : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    p.set_fill_color(@theme.theme_bg_page())
    p.fill_rect(0.0, 0.0, r.w, r.h)
    p.flush()
    let _ = @text.draw_text_at(
      p,
      8.0,
      8.0,
      msg,
      13.0,
      @theme.theme_danger(),
    )
  })
  handle(w)
  @core.node_of(w)
}

///|
/// 播放器控件。`subtitle` 传**已读好的字幕文本**（SRT/VTT，外部文件的读取归调用方，
/// 本组件不碰使用者的磁盘路径）；留空时组件会试一次**容器内嵌轨**（那是媒体文件
/// 自己的内容，走解码器不是走 IO）。打不开媒体时不抛异常——画一块说明板并把原因
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
  handle? : (@core.Widget) -> Unit = fn(_w : @core.Widget) -> Unit { () },
) -> @core.Node {
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
  let drag_frac : Ref[Double] = Ref(0.0)
  let vol_drag : Ref[Bool] = Ref(false)
  let speed_i = Ref(0)
  let bar_w : Ref[Double] = Ref(0.0)
  if auto_play {
    engine.play()
  }
  let screen = @core.Widget::new()
  screen.node.set_flex_grow(1.0)
  screen.node.set_min_height(@yoga.fixed(40.0))
  screen.on_draw = Some(fn(
    _w : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
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
            // 等比适配（fit）：画面居中，两边留黑
            let vw = engine.frame_width().to_double()
            let vh = engine.frame_height().to_double()
            if vw > 0.0 && vh > 0.0 {
              let s = if r.w / vw < r.h / vh { r.w / vw } else { r.h / vh }
              let dw = vw * s
              let dh = vh * s
              p.draw_image(img, (r.w - dw) / 2.0, (r.h - dh) / 2.0, dw, dh)
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
  let bar = @core.Widget::new()
  bar.node.set_height(@yoga.fixed(34.0))
  bar.on_draw = Some(fn(
    _w : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    bar_w.val = r.w
    p.set_fill_color(@theme.theme_bg_panel())
    p.fill_rect(0.0, 0.0, r.w, r.h)
    let dur = engine.duration()
    let t = if dragging.val {
      drag_frac.val * dur
    } else {
      engine.current()
    }
    let frac = vp_pct(t, dur)
    p.set_fill_color(@theme.theme_border())
    p.fill_rect(BAR_TRACK_X, 15.0, bar_track_w(r.w), 4.0)
    p.set_fill_color(@theme.theme_primary())
    p.fill_rect(BAR_TRACK_X, 15.0, bar_track_w(r.w) * frac, 4.0)
    // 音量条：画的是引擎里的实际音量，不是本地副本（否则拖动与静音会各说各话）
    if bar_has_volume(r.w) {
      let vol = engine.get_volume()
      p.set_fill_color(@theme.theme_border())
      p.fill_rect(bar_vol_x(r.w), 15.0, BAR_VOL_W, 4.0)
      p.set_fill_color(@theme.theme_text_secondary())
      p.fill_rect(bar_vol_x(r.w), 15.0, BAR_VOL_W * vol, 4.0)
    }
    p.flush()
    let _ = @text.draw_text_at(
      p,
      8.0,
      9.0,
      if engine.is_playing() { "❚❚" } else { "▶" },
      13.0,
      @theme.theme_text_primary(),
    )
    let _ = @text.draw_text_at(
      p,
      38.0,
      9.0,
      "|<",
      12.0,
      @theme.theme_text_secondary(),
    )
    let _ = @text.draw_text_at(
      p,
      74.0,
      9.0,
      ">|",
      12.0,
      @theme.theme_text_secondary(),
    )
    let _ = @text.draw_text_at(
      p,
      110.0,
      9.0,
      vp_fmt_speed(engine.get_speed()),
      12.0,
      @theme.theme_text_secondary(),
    )
    let _ = @text.draw_text_at(
      p,
      r.w - 142.0,
      9.0,
      vp_fmt_time(t) + " / " + vp_fmt_time(dur),
      12.0,
      @theme.theme_text_secondary(),
    )
  })
  bar.on_pointer = Some(fn(
    _w : @core.Widget,
    ev : @core.PointerEvent,
  ) -> Bool {
    match ev.kind {
      @core.Down => {
        let hit = bar_hit(ev.x, ev.y, bar_w.val, 34.0)
        if hit.0 == "pause" {
          if engine.is_playing() {
            engine.pause()
          } else {
            engine.play()
          }
          @core.invalidate()
        } else if hit.0 == "step_back" || hit.0 == "step_fwd" {
          // 逐帧：引擎自己先暂停再解到落点，组件不碰时钟
          engine.step(if hit.0 == "step_back" { -1 } else { 1 })
          @core.invalidate()
        } else if hit.0 == "speed" {
          speed_i.val = speed_i.val + 1
          let v = bar_speed_at(speed_i.val)
          engine.set_speed(v)
          on_speed(v)
          @core.invalidate()
        } else if hit.0 == "seek" {
          dragging.val = true
          drag_frac.val = hit.1
          @core.invalidate()
        } else if hit.0 == "volume" {
          vol_drag.val = true
          engine.set_volume(hit.1)
          @core.invalidate()
        }
        true
      }
      @core.Move => {
        if dragging.val {
          let hit = bar_hit(ev.x, ev.y, bar_w.val, 34.0)
          drag_frac.val = hit.1
          @core.invalidate()
        } else if vol_drag.val {
          let hit = bar_hit(ev.x, ev.y, bar_w.val, 34.0)
          engine.set_volume(hit.1)
          @core.invalidate()
        }
        dragging.val || vol_drag.val
      }
      @core.Up => {
        if dragging.val {
          // 抬手才真 seek（防抖）：拖动期间只挪显示位置。音量相反——
          // 每步都生效才是「边拖边听」，且它不触发解码，没有关键帧代价。
          dragging.val = false
          engine.seek(drag_frac.val * engine.duration())
          @core.invalidate()
        }
        vol_drag.val = false
        true
      }
      @core.Leave => dragging.val || vol_drag.val
    }
  })
  let root = @core.Widget::new()
  root.node.set_flex_direction(@yoga.Column)
  root.node.set_width(@yoga.fixed(width))
  root.node.set_height(@yoga.fixed(height))
  root.append_child(screen)
  root.append_child(bar)
  let tick : Ref[() -> Unit] = Ref(fn() { () })
  tick.val = fn() -> Unit {
    engine.tick()
    on_tick(engine.current(), engine.frames_decoded(), engine.is_playing())
    if engine.is_playing() || dragging.val {
      @core.invalidate()
    }
    let _ = @core.set_timeout(33, tick.val)
  }
  let _ = @core.set_timeout(33, tick.val)
  handle(root)
  @core.node_of(root)
}
