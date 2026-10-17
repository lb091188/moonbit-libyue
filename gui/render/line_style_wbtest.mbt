// W35 收尾：Painter.line_cap/join + draw_path 无头回归。
// Cairo 后端在纯 CI 无显示时不可用；本 wbtest 走 Pure 后端（set_line_cap/join 是 no-op
// 但不炸）+ draw_path 回放路径序列。

test "Painter.set_line_cap/join 在 Pure 后端不抛错" {
  let bmp = Bitmap::new(4, 4)
  let p = Painter::new(bmp)
  p.set_line_cap(Round)
  p.set_line_join(Bevel)
  p.set_line_cap(Butt)
  p.set_line_join(Miter)
}

test "draw_path 回放 Path 序列不抛错" {
  let bmp = Bitmap::new(8, 8)
  let p = Painter::new(bmp)
  let path = Path::new()
  path.move_to(1.0, 1.0)
  path.line_to(5.0, 1.0)
  path.line_to(5.0, 5.0)
  path.close()
  p.draw_path(path)
  // 只是不抛；具体像素覆盖由 Cairo 真机验收承担
}

test "LineCap/LineJoin 枚举变体齐全" {
  let a : LineCap = Butt
  let b : LineCap = Round
  let c : LineCap = Square
  let d : LineJoin = Miter
  let e : LineJoin = Round
  let f : LineJoin = Bevel
  assert_true(line_cap_to_int(a) == 0)
  assert_true(line_cap_to_int(b) == 1)
  assert_true(line_cap_to_int(c) == 2)
  assert_true(line_join_to_int(d) == 0)
  assert_true(line_join_to_int(e) == 1)
  assert_true(line_join_to_int(f) == 2)
}
