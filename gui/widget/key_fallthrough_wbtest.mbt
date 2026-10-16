// 窗口级按键兜底通道（`App::add_key_fallthrough`）的无头回归，三条判据：没有
// 焦点也吃到键、抬起事件不进通道、焦点链消费时不抢且多处理器按注册序截断。
// 假窗与投递 helper 复用 `focus_route_wbtest.mbt` 的 `fake_win_app` / `two_fields`
// / `down_at` / `key_down`。

///|
test "无焦点也吃到键，抬起事件不进通道" {
  host_reset()
  let a = fake_win_app()
  let seen : Array[Int] = []
  a.add_key_fallthrough(fn(ev : KeyEvent) -> Bool {
    seen.push(ev.keysym)
    ev.keysym == @base.KS_SPACE
  })
  key_down(a, @base.KS_SPACE)
  assert_eq(seen, [@base.KS_SPACE])
  // 抬起（code=1）在 Key 分支开头就被拦下，不该问处理器
  let up : @win.InputEvent = {
    code: 1,
    keysym: @base.KS_SPACE,
    mods: 0,
    x: 0,
    y: 0,
    button: 0,
    axis: 0,
  }
  a.route(up)
  assert_eq(seen, [@base.KS_SPACE])
  host_reset()
}

///|
/// 焦点控件消费掉的键不会外溢到兜底通道（输入框打字因此天然不被播放器抢走）；
/// 焦点控件不吃的才轮到通道，通道内按注册序、第一个吃掉的截断。
test "焦点链消费就不抢，多处理器按序截断" {
  host_reset()
  let a = fake_win_app()
  let (one, _) = two_fields(a)
  let order : Array[String] = []
  one.on_key = Some(fn(_ev : KeyEvent) -> Bool { true })
  down_at(a, 100, 15)
  assert_eq(a.focus.current(), Some(7))
  a.add_key_fallthrough(fn(ev : KeyEvent) -> Bool {
    order.push("first")
    ev.keysym == @base.KS_SPACE
  })
  key_down(a, @base.KS_SPACE)
  assert_eq(order, [])
  // 焦点控件放手：同一条键改由通道接手
  one.on_key = Some(fn(_ev : KeyEvent) -> Bool { false })
  key_down(a, @base.KS_SPACE)
  assert_eq(order, ["first"])
  // 第二个处理器：第一个不吃才轮到它
  a.add_key_fallthrough(fn(_ev : KeyEvent) -> Bool {
    order.push("second")
    true
  })
  key_down(a, KS_RIGHT)
  assert_eq(order, ["first", "first", "second"])
  host_reset()
}
