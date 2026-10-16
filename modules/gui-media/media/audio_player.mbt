// 音频播放组件：引擎是 `AudioPlayer`（ffmpeg 解码 + miniaudio 设备直出），
// 控制条与 `video` 共用同一套分区常量，差别只在没有画面。
//
// 三条口径：
// ① 纯音频专用——带视频轨的文件走 `video`，两者不互相代打：本组件的位置
//    读数是设备已消费字节，`video` 的是墙钟 + 帧时间戳，塞进同一个组件
//    等于让两条时钟互相冒充；
// ② 时钟在引擎里，UI 每 tick 调一次 `pump` 推进队列并重绘，排期走
//    `@core.set_timeout`，组件不起线程；
// ③ seek 防抖同 `video`：拖动期间只挪显示位置，抬手才真 seek；音量相反，
//    每步都生效（它不触发解码，没有关键帧代价）。

///|
/// 快退/快进落点：当前位置加偏移，钳在 `[0, 时长]`；时长未知（容器无时长头）
/// 时只钳下界，否则 `vp_clamp_t` 会把未知时长的落点打回 0。
pub fn ap_skip(cur : Double, duration_s : Double, delta : Double) -> Double {
  let t = cur + delta
  if duration_s <= 0.0 {
    if t < 0.0 { 0.0 } else { t }
  } else {
    vp_clamp_t(t, duration_s)
  }
}

///|
/// 快退/快进键的步长（秒）。
let ap_skip_step : Double = 5.0

///|
/// 音频播放控件。`width`/`height` 是整块控件尺寸（默认只有一条控制条高）；
/// 组件被外层撑高时，多出来的高度归上方舞台区（当前只在无输出设备时写字，
/// 频谱动画也落在这块）。打不开时不抛异常——画说明板并把原因经 `on_error`
/// 交出去（探测 + 降级不静默）。
pub fn audio(
  path : String,
  width? : Double = 560.0,
  height? : Double = 34.0,
  auto_play? : Bool = false,
  volume? : Double = 0.8,
  looping? : Bool = false,
  /// 每 tick 的观测口（位置秒 / 是否在播）：示例与回证靠它证明时钟在走。
  on_tick? : (Double, Bool) -> Unit = fn(
    _t : Double,
    _playing : Bool,
  ) -> Unit { () },
  /// 倍速档位变化的观测口（控制条点倍速键时回调）。
  on_speed? : (Double) -> Unit = fn(_v : Double) -> Unit { () },
  on_error? : (String) -> Unit = fn(_s : String) -> Unit { () },
  handle? : (@core.Widget) -> Unit = fn(_w : @core.Widget) -> Unit { () },
) -> @core.Node {
  let engine = match AudioPlayer::make(path, volume~, looping~) {
    Ok(p) => p
    Err(e) => {
      on_error(e)
      return media_error_board("打不开音频：" + e, width, height, handle)
    }
  }
  let dragging : Ref[Bool] = Ref(false)
  let drag_frac : Ref[Double] = Ref(0.0)
  let vol_drag : Ref[Bool] = Ref(false)
  let speed_i = Ref(0)
  let bar_w : Ref[Double] = Ref(0.0)
  if auto_play {
    engine.play()
  }
  // 舞台区：撑高时占住多出来的高度，无输出设备的降级说明写在这里。
  let stage = @core.Widget::new()
  stage.node.set_flex_grow(1.0)
  stage.node.set_min_height(@yoga.fixed(0.0))
  stage.on_draw = Some(fn(
    _w : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    if r.h <= 0.0 {
      return
    }
    p.set_fill_color(@theme.theme_bg_panel())
    p.fill_rect(0.0, 0.0, r.w, r.h)
    if engine.is_muted() {
      p.flush()
      let _ = @text.draw_text_at(
        p,
        8.0,
        (r.h - 13.0) / 2.0,
        "没有可用输出设备：按静音推进，状态机照常走",
        13.0,
        @theme.theme_text_secondary(),
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
    let t = if dragging.val { drag_frac.val * dur } else { engine.current() }
    let frac = vp_pct(t, dur)
    p.set_fill_color(@theme.theme_border())
    p.fill_rect(BAR_TRACK_X, 15.0, bar_track_w(r.w), 4.0)
    p.set_fill_color(@theme.theme_primary())
    p.fill_rect(BAR_TRACK_X, 15.0, bar_track_w(r.w) * frac, 4.0)
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
    // 两个跳转键写秒数而不是视频那对 |< >|：音频没有「帧」可走。
    let _ = @text.draw_text_at(
      p,
      38.0,
      10.0,
      "-5s",
      11.0,
      @theme.theme_text_secondary(),
    )
    let _ = @text.draw_text_at(
      p,
      74.0,
      10.0,
      "+5s",
      11.0,
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
          let delta = if hit.0 == "step_back" {
            -ap_skip_step
          } else {
            ap_skip_step
          }
          engine.seek(ap_skip(engine.current(), engine.duration(), delta))
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
  root.append_child(stage)
  root.append_child(bar)
  let tick : Ref[() -> Unit] = Ref(fn() { () })
  tick.val = fn() -> Unit {
    engine.pump()
    on_tick(engine.current(), engine.is_playing())
    if engine.is_playing() || dragging.val {
      @core.invalidate()
    }
    let _ = @core.set_timeout(ap_tick_ms, tick.val)
  }
  let _ = @core.set_timeout(ap_tick_ms, tick.val)
  handle(root)
  @core.node_of(root)
}
