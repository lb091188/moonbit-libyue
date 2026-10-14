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
test "lerp_style：颜色/边框宽/圆角逐字段插值，集合外取目标值" {
  let from = style(
    background_color="#000000",
    color="#000000",
    border_width=1.0,
    border_radius=0.0,
    font_size=12.0,
  )
  let to = style(
    background_color="#ffffff",
    color="#ffffff",
    border_width=3.0,
    border_radius=10.0,
    font_size=16.0,
  )
  assert_eq(hex_of(lerp_style(from, to, 0.0).background_color), "#000000")
  assert_eq(hex_of(lerp_style(from, to, 1.0).background_color), "#ffffff")
  let sm = lerp_style(from, to, 0.5)
  assert_eq(hex_of(sm.background_color), "#808080")
  assert_eq(hex_of(sm.color), "#808080")
  assert_eq(sm.border_width, Some(2.0))
  assert_eq(sm.border_radius, Some(5.0))
  // 插值集合外的字段不插，直接取目标
  assert_eq(sm.font_size, Some(16.0))
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
test "step：目标只在插值集合外的属性上不同（字号）时直接落定" {
  let id = 9103
  let a = style(transition_ms=100.0, font_size=12.0, background_color="#000000")
  let b = style(transition_ms=100.0, font_size=16.0, background_color="#000000")
  let _ = step(id, a, 0L)
  let v = step(id, b, 0L)
  assert_eq(v.font_size, Some(16.0))
  assert_false(anim_running(id))
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
