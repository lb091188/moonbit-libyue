// 焦点栈的次序与环绕语义回归（与 Web 的 Tab 行为一致）。

test "第一个注册项默认聚焦" {
  let f = FocusStack::new()
  assert_eq(f.current(), None)
  assert_eq(f.register(10), true)
  assert_eq(f.current(), Some(10))
  assert_eq(f.register(20), true)
  assert_eq(f.current(), Some(10)) // 后来者不抢焦点
  assert_eq(f.count(), 2)
}

test "Tab 环绕与 Shift+Tab 反向环绕" {
  let f = FocusStack::new()
  let _ = f.register(1)
  let _ = f.register(2)
  let _ = f.register(3)
  assert_eq(f.move_focus(false), Some(2))
  assert_eq(f.move_focus(false), Some(3))
  assert_eq(f.move_focus(false), Some(1)) // 末尾回第一个
  assert_eq(f.move_focus(true), Some(3)) // 首位回最后一个
  assert_eq(f.current(), Some(3))
}

test "重复注册忽略，显式 focus 可跳转" {
  let f = FocusStack::new()
  let _ = f.register(7)
  let _ = f.register(8)
  assert_eq(f.register(7), false)
  assert_eq(f.count(), 2)
  assert_eq(f.focus(8), true)
  assert_eq(f.current(), Some(8))
  assert_eq(f.focus(99), false)
}

test "注销当前项时焦点交给后继，注销空栈置空" {
  let f = FocusStack::new()
  let _ = f.register(1)
  let _ = f.register(2)
  let _ = f.register(3)
  assert_eq(f.focus(2), true)
  f.unregister(2)
  assert_eq(f.current(), Some(3)) // 焦点前移一位（原 3 变第 2 个）
  f.unregister(1)
  assert_eq(f.current(), Some(3))
  f.unregister(3)
  assert_eq(f.current(), None)
  assert_eq(f.count(), 0)
  // 注销不在栈里的 id 不动状态
  let _ = f.register(5)
  f.unregister(6)
  assert_eq(f.current(), Some(5))
}

test "空栈 move_focus 返回 None 且 clear 复位" {
  let f = FocusStack::new()
  assert_eq(f.move_focus(false), None)
  assert_eq(f.current(), None)
  let _ = f.register(1)
  let _ = f.register(2)
  f.clear()
  assert_eq(f.count(), 0)
  assert_eq(f.current(), None)
  // clear 后重新注册又拿到默认焦点
  assert_eq(f.register(9), true)
  assert_eq(f.current(), Some(9))
}
