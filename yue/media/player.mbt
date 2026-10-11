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
/// 控制条的命中分区：返回 ("pause"|"seek"|"" , 进度比例 0..1)。
/// 纯函数，独立于绘制与事件投递，方便无头断言。
pub fn player_bar_hit(
  x : Double,
  _y : Double,
  w : Double,
  h : Double,
) -> (String, Double) {
  if h <= 0.0 || w <= 0.0 {
    ("", 0.0)
  } else if x < 34.0 {
    ("pause", 0.0)
  } else if x > w - 150.0 {
    ("", 0.0)
  } else {
    let track_w = if w - 190.0 < 40.0 { 40.0 } else { w - 190.0 }
    let frac = (x - 42.0) / track_w
    let clamped = if frac < 0.0 { 0.0 } else if frac > 1.0 { 1.0 } else { frac }
    ("seek", clamped)
  }
}

///|
/// 播放器控件。`subtitle` 传**已读好的字幕文本**（SRT/VTT，读取交调用方，本组件不做 IO）；
/// 打不开媒体时不抛异常——画一块说明板并把原因经 `on_error` 交出去（探测 + 降级不静默）。
pub fn player_t(
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
  on_error? : (String) -> Unit = fn(_s : String) -> Unit { () },
  handle? : (@core.Widget) -> Unit = fn(_w : @core.Widget) -> Unit { () },
) -> @core.Node {
  let engine = match VideoPlayer::make(path) {
    Ok(p) => p
    Err(e) => {
      on_error(e)
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
          "打不开媒体：" + e,
          13.0,
          @theme.theme_danger(),
        )
      })
      handle(w)
      return @core.node_of(w)
    }
  }
  let cues = subtitle_parse(subtitle)
  let frame_no : Ref[Int] = Ref(-1)
  let image : Ref[@render.Image?] = Ref(None)
  let dragging : Ref[Bool] = Ref(false)
  let drag_frac : Ref[Double] = Ref(0.0)
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
    p.fill_rect(42.0, 15.0, r.w - 190.0, 4.0)
    p.set_fill_color(@theme.theme_primary())
    p.fill_rect(42.0, 15.0, (r.w - 190.0) * frac, 4.0)
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
        let hit = player_bar_hit(ev.x, ev.y, bar_w.val, 34.0)
        if hit.0 == "pause" {
          if engine.is_playing() {
            engine.pause()
          } else {
            engine.play()
          }
          @core.invalidate()
        } else if hit.0 == "seek" {
          dragging.val = true
          drag_frac.val = hit.1
          @core.invalidate()
        }
        true
      }
      @core.Move => {
        if dragging.val {
          let hit = player_bar_hit(ev.x, ev.y, bar_w.val, 34.0)
          drag_frac.val = hit.1
          @core.invalidate()
        }
        dragging.val
      }
      @core.Up => {
        if dragging.val {
          // 抬手才真 seek（防抖）：拖动期间只挪显示位置
          dragging.val = false
          engine.seek(drag_frac.val * engine.duration())
          @core.invalidate()
        }
        true
      }
      @core.Leave => dragging.val
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
