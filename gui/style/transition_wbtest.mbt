// `transition` 回归：插值集合的端点与中点、状态机按假时钟推进、反向打断从
// 当前显示值续接、没配过渡的控件不留账。

///|
fn hex_of(c : Color?) -> String {
  match c {
    None => ""
    Some(Hex(s)) | Some(Named(s)) | Some(Var(s)) => s
  }
}

///|
test "lerp_style：颜色/边框宽/圆角/字号/行逐字段插值，集合外取目标值" {
  let from = style(
    background_color="#000000",
    color="#000000",
    border_width=1.0,
    border_radius=0.0,
    font_size=12.0,
    line_height=16.0,
    opacity=0.4,
  )
  let to = style(
    background_color="#ffffff",
    color="#ffffff",
    border_width=3.0,
    border_radius=10.0,
    font_size=16.0,
    line_height=20.0,
    opacity=1.0,
  )
  assert_eq(hex_of(lerp_style(from, to, 0.0).background_color), "#000000")
  assert_eq(hex_of(lerp_style(from, to, 1.0).background_color), "#ffffff")
  let sm = lerp_style(from, to, 0.5)
  assert_eq(hex_of(sm.background_color), "#808080")
  assert_eq(hex_of(sm.color), "#808080")
  assert_eq(sm.border_width, Some(2.0))
  assert_eq(sm.border_radius, Some(5.0))
  // 字号与行高都在集合里（CSS 也是按 `<length>` 插值）：中帧给中值。
  // 旧口径这两条直接取目标，看着就是「跳变不是动画」
  assert_eq(sm.font_size, Some(14.0))
  assert_eq(sm.line_height, Some(18.0))
  // 集合外的字段仍取目标值（整层透明度的生效点在 apply 落 Widget 字段）
  assert_eq(sm.opacity, Some(1.0))
}

///|
test "lerp_style：只有一端写了颜色就不动那一条" {
  let from = style(background_color="#000000")
  let to = style(border_radius=6.0)
  let v = lerp_style(from, to, 0.5)
  assert_eq(hex_of(v.background_color), "")
  assert_eq(v.border_radius, Some(6.0))
}

///|
test "step：首帧不动画，换桶按帧插值，到点交目标值" {
  let id = 9101
  let base = style(transition_ms=100.0, background_color="#000000")
  let over = style(transition_ms=100.0, background_color="#ffffff")
  assert_eq(hex_of(step(id, base, 1000L).background_color), "#000000")
  assert_false(anim_running(id))
  // 换了目标：起点仍是当前显示值（不跳变）
  assert_eq(hex_of(step(id, over, 1000L).background_color), "#000000")
  assert_true(anim_running(id))
  // 只改颜色 ⇒ 矩形不变 ⇒ 仍走局部置脏（别把 P5 的优化弄丢）
  assert_false(anim_needs_full_paint(id))
  assert_eq(hex_of(step(id, over, 1050L).background_color), "#808080")
  assert_eq(hex_of(step(id, over, 1075L).background_color), "#d7d7d7")
  assert_eq(hex_of(step(id, over, 1100L).background_color), "#ffffff")
  assert_false(anim_running(id))
}

///|
test "step：过渡中途换回原目标，从当前显示值续接" {
  let id = 9102
  let base = style(transition_ms=200.0, background_color="#000000")
  let over = style(transition_ms=200.0, background_color="#ffffff")
  let _ = step(id, base, 0L)
  let _ = step(id, over, 0L)
  // 200ms 里走了 1/4 拍：smoothstep 给 0.15625 → #282828
  assert_eq(hex_of(step(id, over, 50L).background_color), "#282828")
  // 反向段的起点必须就是刚才那一帧的值
  assert_eq(hex_of(step(id, base, 50L).background_color), "#282828")
  assert_true(anim_running(id))
  assert_eq(hex_of(step(id, base, 250L).background_color), "#000000")
  assert_false(anim_running(id))
}

///|
/// 字号进插值集合（用户反馈「字号动画不是动画，是直接的变化」的落点）：
/// 只改字号也要起表、中帧要给中间值，落定后 `shown` 就是目标值。
test "step：只改字号也按帧插值，中帧给中间值" {
  let id = 9103
  let a = style(transition_ms=100.0, font_size=12.0, background_color="#000000")
  let b = style(transition_ms=100.0, font_size=16.0, background_color="#000000")
  let _ = step(id, a, 0L)
  assert_eq(step(id, b, 0L).font_size, Some(12.0))
  assert_true(anim_running(id), msg="只改字号没起表")
  // 字号在变 ⇒ 矩形会长大 ⇒ 必须整窗置脏（局部脏区按上一帧的矩形并，新露出的
  // 那圈会被裁掉）
  assert_true(anim_needs_full_paint(id))
  // 四分之一程：smoothstep(0.25)=0.15625 → 12.625；半程 smoothstep(0.5)=0.5 → 14
  assert_eq(step(id, b, 25L).font_size, Some(12.625))
  assert_eq(step(id, b, 50L).font_size, Some(14.0))
  assert_eq(anim_shown_font_size(id), Some(14.0))
  assert_eq(step(id, b, 100L).font_size, Some(16.0))
  assert_false(anim_running(id))
  assert_eq(anim_shown_font_size(id), Some(16.0))
  forget_anim(id)
  // 反向打断：中帧换回原值，起点仍是当前显示值（不跳回端点）
  let r = 9105
  let _ = step(r, a, 0L)
  let _ = step(r, b, 0L)
  assert_eq(step(r, b, 50L).font_size, Some(14.0))
  assert_eq(step(r, a, 50L).font_size, Some(14.0))
  assert_true(anim_running(r))
  assert_eq(step(r, a, 150L).font_size, Some(12.0))
  forget_anim(r)
  // 只改行高同理：起表、中帧给中值、也要整窗置脏（行高定单行档的行盒高）
  let g = 9106
  let la = style(transition_ms=100.0, line_height=16.0)
  let lb = style(transition_ms=100.0, line_height=20.0)
  let _ = step(g, la, 0L)
  let _ = step(g, lb, 0L)
  assert_true(anim_running(g), msg="只改行高没起表")
  assert_eq(step(g, lb, 50L).line_height, Some(18.0))
  assert_eq(anim_shown_line_height(g), Some(18.0))
  assert_true(anim_needs_full_paint(g))
  forget_anim(g)
}

///|
/// 测量期要按「这一帧该画的字号/行高」量：这两条是绘制与测量共用的属性，盒子若
/// 还按基块量，字放大后就被裁在半盒里（看着仍是跳变）。这条把两边对齐钉住。
test "resolved_for_measure：与绘制期同一份字号与行高，落定后跟目标值" {
  let w = @core.Widget::new()
  apply(
    w,
    style(
      transition_ms=100.0,
      font_size=13.0,
      line_height=20.0,
      hover=style(font_size=17.0, line_height=28.0),
      background_color="#000000",
    ),
  )
  // 首帧：还没起表，测量按基块
  assert_eq(resolved_for_measure(w.id).font_size, Some(13.0))
  assert_eq(resolved_for_measure(w.id).line_height, Some(20.0))
  w.hovered = true
  // 走一帧绘制期入口（真实时钟），测量期读到的必须与这一帧绘制用的同值
  let drawn = style_for(w)
  let meas = resolved_for_measure(w.id)
  assert_eq(meas.font_size, drawn.font_size)
  assert_eq(meas.line_height, drawn.line_height)
  match (meas.font_size, meas.line_height) {
    (Some(f), Some(l)) => assert_true(
      f >= 13.0 && f <= 17.0 && l >= 20.0 && l <= 28.0,
      msg="测量期读数越出两端：字号 \{f}、行高 \{l}",
    )
    _ => assert_true(false, msg="测量期丢了字号或行高")
  }
  // 基块不被写坏（测量走的是副本）
  assert_eq(resolved_by_id(w.id).font_size, Some(13.0))
  assert_eq(resolved_by_id(w.id).line_height, Some(20.0))
  forget_anim(w.id)
}

///|
test "style_for：配了 transition_ms 才走插值，没配的控件不留账" {
  let w = @core.Widget::new()
  apply(
    w,
    style(
      transition_ms=100.0,
      background_color="#000000",
      hover=style(background_color="#ffffff"),
    ),
  )
  assert_eq(hex_of(style_for(w).background_color), "#000000")
  assert_false(anim_running(w.id))
  w.hovered = true
  assert_eq(hex_of(style_for(w).background_color), "#000000")
  assert_true(anim_running(w.id))
  w.hovered = false
  assert_eq(hex_of(style_for(w).background_color), "#000000")
  assert_false(anim_running(w.id))
  let plain = @core.Widget::new()
  apply(plain, style(background_color="#000000"))
  let before = anim_count()
  assert_eq(hex_of(style_for(plain).background_color), "#000000")
  assert_eq(anim_count(), before)
  assert_false(anim_running(plain.id))
}
