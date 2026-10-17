// W32 多击派发接线：通过 dispatch_pointer 走完整路径，验 on_double_click
// 在最深命中档触发、on_triple_click 在三击档触发、on_pointer 与多击回调并存。

test "on_double_click 在 Down×2（400ms/4px 内）触发一次" {
  let root = Widget::new()
  root.rect = { x: 0.0, y: 0.0, w: 100.0, h: 50.0, }
  let hits : Array[Int] = []
  root.on_double_click = Some(fn(_w : Widget, _ev : PointerEvent) -> Unit {
    hits.push(1)
  })
  root.tracker.last_time = @shell.now_ms() - 100L
  root.tracker.last_x = 10.0
  root.tracker.last_y = 10.0
  root.tracker.click_count = 1
  let ev : PointerEvent = {
    kind: Down,
    x: 11.0,
    y: 11.0,
    button: 1,
    mods: 0,
  }
  let _ = root.dispatch_pointer(ev)
  assert_eq(hits, [1])
}

test "bind_combo：spec 命中调 cb、不命中放行" {
  host_reset()
  let a = fake_win_app()
  let fired : Array[Int] = []
  a.bind_combo("Ctrl+S", fn() -> Unit { fired.push(1) })
  // 命中：Ctrl+S 按下
  let _ = a.fire_key_fallthrough({
    press: true,
    keysym: 115,
    mods: @base.MOD_CTRL,
  })
  assert_eq(fired, [1])
  // 不命中：只按 S，无 Ctrl
  let _ = a.fire_key_fallthrough({
    press: true,
    keysym: 115,
    mods: 0,
  })
  assert_eq(fired, [1])
  host_reset()
}
