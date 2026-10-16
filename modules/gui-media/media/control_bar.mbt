// 播放器控制条（`video` 与 `audio` 共用）：左边一排真按钮（悬停浅底、Tab 可达、
// 焦点环由 `ui` 画），右边一块自绘显示区（进度轨 + 音量条 + 时间文字）。
//
// 三条口径：
// ① 分区判据只有一份——绘制与命中都读 `BAR_*`，改一处不会漏另一处；显示区之外
//    的按键都是独立控件，不再参与像素分区（旧版把播放/跳转/倍速画在同一块自绘
//    区里，代价是它们没有悬停、没有焦点环、也进不了 Tab 链）；
// ② 倍速与缩放用**文字按钮**显示当前档——图标说不清「1.25x」和「铺满」；
// ③ 进度抬手才 seek（真 seek 要回退到关键帧，每步都发就是一场风暴），音量每步
//    生效（它不触发解码，边拖边听才是预期）。

///|
/// 控制条高度与显示区分区常量。
const BAR_H : Double = 34.0
const BAR_VOL_W : Double = 80.0
const BAR_TIME_W : Double = 150.0
const BAR_GAP : Double = 8.0

///|
/// 进度轨至少留多宽（窄到放不下「轨道 + 音量 + 时间」时音量条整个让位，
/// 绘制与命中同一条判据，否则会出现「看得见却点不着」或反过来）。
const BAR_TRACK_MIN : Double = 120.0

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
/// 缩放档位标签（0 等比适配 / 1 铺满裁切 / 2 原始像素）。
pub fn vp_zoom_label(mode : Int) -> String {
  match mode {
    1 => "铺满"
    2 => "1:1"
    _ => "适配"
  }
}

///|
/// 画面在控件矩形里的落位：适配取小边、铺满取大边（超出由控件裁剪）、
/// 1:1 用原始像素，三者都居中。尺寸非法给零矩形（不画）。
pub fn vp_fit_rect(
  vw : Double,
  vh : Double,
  rw : Double,
  rh : Double,
  mode : Int,
) -> (Double, Double, Double, Double) {
  if vw <= 0.0 || vh <= 0.0 || rw <= 0.0 || rh <= 0.0 {
    (0.0, 0.0, 0.0, 0.0)
  } else {
    let fit = rw / vw
    let fill = rh / vh
    let s =
      match mode {
        1 => if fit > fill { fit } else { fill }
        2 => 1.0
        _ => if fit < fill { fit } else { fill }
      }
    let dw = vw * s
    let dh = vh * s
    ((rw - dw) / 2.0, (rh - dh) / 2.0, dw, dh)
  }
}

///|
/// 音量条左端（贴着右侧时间文字，倒着排以免窄条时互相压住）。
fn bar_vol_x(w : Double) -> Double { w - BAR_TIME_W - BAR_VOL_W - BAR_GAP }

///|
/// 放不放得下「轨道 + 音量 + 时间」三件。
fn bar_has_volume(w : Double) -> Bool {
  w >= BAR_TRACK_MIN + BAR_GAP * 2.0 + BAR_VOL_W + BAR_TIME_W
}

///|
/// 进度轨宽度（窄到 40px 以下就不再缩，否则拖动没有分辨率可言）。
fn bar_track_w(w : Double) -> Double {
  let right = if bar_has_volume(w) {
    bar_vol_x(w) - BAR_GAP
  } else {
    w - BAR_TIME_W - BAR_GAP
  }
  let t = right
  if t < 40.0 { 40.0 } else { t }
}

fn bar_clamp01(f : Double) -> Double {
  if f < 0.0 { 0.0 } else if f > 1.0 { 1.0 } else { f }
}

///|
/// 显示区的命中分区：`x` 是显示区本地横坐标。返回 (分区名, 比例 0..1)，
/// 分区名是 `"seek"|"volume"|""`（空串=右侧时间文字，不响应）。纯函数，
/// 独立于绘制与事件投递，方便无头断言。
pub fn bar_hit(x : Double, w : Double) -> (String, Double) {
  if w <= 0.0 {
    ("", 0.0)
  } else if x > w - BAR_TIME_W {
    ("", 0.0)
  } else if bar_has_volume(w) && x >= bar_vol_x(w) {
    ("volume", bar_clamp01((x - bar_vol_x(w)) / BAR_VOL_W))
  } else {
    ("seek", bar_clamp01(x / bar_track_w(w)))
  }
}

///|
/// 打不开媒体时的说明板（两个组件共用）：铺满底色、红字写原因，不抛异常
/// ——探测 + 降级不静默。
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
/// 切当前窗全屏。控件层拿不到窗口，走进程级宿主单槽（`App::set_fullscreen`
/// 的门面注释同条口径）；没有宿主（无头测试）返回 false，调用方据此不动
/// 自己的档位状态。
fn player_set_fullscreen(on : Bool) -> Bool {
  match @core.host_active() {
    Some(app) => {
      app.set_fullscreen(on)
      true
    }
    None => false
  }
}

///|
/// 显示区：进度轨 + 音量条 + 时间文字。读数与动作都经闭包取，两个组件共用
/// 同一份绘制与命中判据。`dragging` 由调用方的时钟读——拖动期间即使暂停也要
/// 重绘，抬手才落 seek。
fn player_display(
  pos : () -> Double,
  dur : () -> Double,
  vol : () -> Double,
  set_vol : (Double) -> Unit,
  seek_to : (Double) -> Unit,
  dragging : Ref[Bool],
) -> @core.Widget {
  let w = @core.Widget::new()
  w.node.set_flex_grow(1.0)
  w.node.set_height(@yoga.fixed(BAR_H))
  // 窄到只剩时间文字时轨道就点不着了，给个下限让布局去挤按钮而不是挤轨道
  w.node.set_min_width(@yoga.fixed(200.0))
  let drag_frac : Ref[Double] = Ref(0.0)
  let vol_drag : Ref[Bool] = Ref(false)
  let bar_w : Ref[Double] = Ref(0.0)
  w.on_draw = Some(fn(
    _w : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    bar_w.val = r.w
    p.set_fill_color(@theme.theme_bg_panel())
    p.fill_rect(0.0, 0.0, r.w, r.h)
    let duration = dur()
    let t = if dragging.val { drag_frac.val * duration } else { pos() }
    let frac = vp_pct(t, duration)
    p.set_fill_color(@theme.theme_border())
    p.fill_rect(0.0, 15.0, bar_track_w(r.w), 4.0)
    p.set_fill_color(@theme.theme_primary())
    p.fill_rect(0.0, 15.0, bar_track_w(r.w) * frac, 4.0)
    if bar_has_volume(r.w) {
      let v = vol()
      p.set_fill_color(@theme.theme_border())
      p.fill_rect(bar_vol_x(r.w), 15.0, BAR_VOL_W, 4.0)
      p.set_fill_color(@theme.theme_text_secondary())
      p.fill_rect(bar_vol_x(r.w), 15.0, BAR_VOL_W * v, 4.0)
    }
    p.flush()
    let _ = @text.draw_text_at(
      p,
      r.w - BAR_TIME_W + 8.0,
      9.0,
      vp_fmt_time(t) + " / " + vp_fmt_time(duration),
      12.0,
      @theme.theme_text_secondary(),
    )
  })
  w.on_pointer = Some(fn(
    _w : @core.Widget,
    ev : @core.PointerEvent,
  ) -> Bool {
    match ev.kind {
      @widget.PointerKind::Down => {
        let hit = bar_hit(ev.x, bar_w.val)
        if hit.0 == "seek" {
          dragging.val = true
          drag_frac.val = hit.1
          @core.invalidate()
        } else if hit.0 == "volume" {
          vol_drag.val = true
          set_vol(hit.1)
          @core.invalidate()
        }
        true
      }
      @widget.PointerKind::Move => {
        let hit = bar_hit(ev.x, bar_w.val)
        if dragging.val {
          drag_frac.val = hit.1
          @core.invalidate()
        } else if vol_drag.val {
          set_vol(hit.1)
          @core.invalidate()
        }
        dragging.val || vol_drag.val
      }
      @widget.PointerKind::Up => {
        if dragging.val {
          dragging.val = false
          seek_to(drag_frac.val * dur())
          @core.invalidate()
        }
        vol_drag.val = false
        true
      }
      @widget.PointerKind::Leave => dragging.val || vol_drag.val
    }
  })
  w
}

///|
/// 把播放器快捷键挂到当前窗的**按键兜底通道**上（`App::add_key_fallthrough`）：
/// 空格播放/暂停、回车全屏、`←`/`→` 后退/前进、`↑`/`↓` 音量、`Esc` 退全屏。
/// 三条口径：① 不点窗口也能用，但焦点在输入框里时按键被编辑器吃掉，播放器
/// 不抢字；② 通道没有反注册口，所以每次按键先问 `watch`（本组件根控件）
/// 「还在被画吗」——换载摘掉的播放器不再吃键，同窗多台时注册序在前的先接；
/// ③ 没有宿主（无头测试）时什么都不挂。
fn player_bind_keys(
  watch : @core.Widget,
  on_toggle : () -> Unit,
  on_back : () -> Unit,
  on_fwd : () -> Unit,
  on_full : () -> Unit,
  on_vol : (Double) -> Unit,
  is_full : () -> Bool,
) -> Unit {
  match @core.host_active() {
    None => ()
    Some(app) => app.add_key_fallthrough(fn(
      ev : @core.KeyEvent,
    ) -> Bool {
      if !watch.is_painted() {
        false
      } else if ev.keysym == @core.KS_SPACE {
        on_toggle()
        true
      } else if ev.keysym == @core.KS_RETURN {
        on_full()
        true
      } else if ev.keysym == @core.KS_LEFT {
        on_back()
        true
      } else if ev.keysym == @core.KS_RIGHT {
        on_fwd()
        true
      } else if ev.keysym == @core.KS_UP {
        on_vol(0.05)
        true
      } else if ev.keysym == @core.KS_DOWN {
        on_vol(0.0 - 0.05)
        true
      } else if ev.keysym == @core.KS_ESCAPE && is_full() {
        // 只在真处于全屏时接管：窗口态的 Esc 还有别的用途
        on_full()
        true
      } else {
        false
      }
    })
  }
}

///|
/// 整条控制条。`zoom` 给 `None` 时不画缩放键（音频没有画面可缩）。
fn player_bar(
  playing : @core.Store[Bool],
  speed : @core.Store[Double],
  full : @core.Store[Bool],
  zoom : @core.Store[Int]?,
  back_icon : @icons.IconKind,
  fwd_icon : @icons.IconKind,
  on_toggle : () -> Unit,
  on_back : () -> Unit,
  on_fwd : () -> Unit,
  on_speed : () -> Unit,
  on_full : () -> Unit,
  on_zoom : () -> Unit,
  display : @core.Widget,
) -> @core.Node {
  let kids : Array[@core.Node] = [
    @core.bind_node(playing.signal(), fn(p : Bool) -> @core.Node {
      @ui.icon_button(
        if p { @icons.VideoPause } else { @icons.VideoPlay },
        on_click=on_toggle,
        icon_size=16.0,
        box_size=28.0,
      )
    }),
    @ui.icon_button(
      back_icon,
      on_click=on_back,
      icon_size=16.0,
      box_size=28.0,
    ),
    @ui.icon_button(
      fwd_icon,
      on_click=on_fwd,
      icon_size=16.0,
      box_size=28.0,
    ),
    @core.bind_node(speed.signal(), fn(v : Double) -> @core.Node {
      @ui.button(
        vp_fmt_speed(v),
        on_click=on_speed,
        variant=@ui.Text,
        font_size=12.0,
      )
    }),
  ]
  match zoom {
    Some(z) => kids.push(
      @core.bind_node(z.signal(), fn(m : Int) -> @core.Node {
        @ui.button(
          vp_zoom_label(m),
          on_click=on_zoom,
          variant=@ui.Text,
          font_size=12.0,
        )
      }),
    )
    None => ()
  }
  kids.push(@core.bind_node(full.signal(), fn(f : Bool) -> @core.Node {
    @ui.icon_button(
      if f { @icons.FullscreenExit } else { @icons.Fullscreen },
      on_click=on_full,
      icon_size=16.0,
      box_size=28.0,
    )
  }))
  kids.push(@core.node_of(display))
  @ui.row(
    kids,
    column_gap=2.0,
    height=BAR_H,
    padding=2.0,
    background_color="bg_panel",
    align_items=@yoga.AlignItems::Center,
  )
}
