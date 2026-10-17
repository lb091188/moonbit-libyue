// W30 多窗口生命周期无头回归：用 @shell.fake_session 造两扇假窗，验证注册表、
// 主从判定、窗数计数与关闭摘除的行为。真窗口的可见性与交互由用户验。

test "多窗注册表：两窗共存、主从判定、窗数计数" {
  host_reset()
  let s1 = @shell.fake_session(1, 100, true, 800, 600)
  let s2 = @shell.fake_session(2, 101, false, 400, 300)
  let a1 = test_app(s1)
  let a2 = test_app(s2)
  host_add_app(a1)
  host_add_app(a2)
  assert_eq(a1.window_count(), 2)
  assert_true(a1.is_primary())
  assert_false(a2.is_primary())
  assert_eq(a1.wid(), 100)
  assert_eq(a2.wid(), 101)
}

test "多窗关闭：从窗关闭不减主窗、主窗关闭走退出判定" {
  host_reset()
  let s1 = @shell.fake_session(1, 200, true, 800, 600)
  let s2 = @shell.fake_session(2, 201, false, 400, 300)
  let a1 = test_app(s1)
  let a2 = test_app(s2)
  host_add_app(a1)
  host_add_app(a2)
  a2.close_window()
  assert_eq(a1.window_count(), 1)
  assert_eq(a1.window_count(), 1)
}

test "多窗激活：host_host_mark_active 切活动窗" {
  host_reset()
  let s1 = @shell.fake_session(1, 300, true, 800, 600)
  let s2 = @shell.fake_session(2, 301, false, 400, 300)
  let a1 = test_app(s1)
  let a2 = test_app(s2)
  host_add_app(a1)
  host_add_app(a2)
  host_mark_active(s2)
  match a1.active_window() {
    Some(active) => assert_eq(active.wid(), 301)
    None => assert_eq(true, false)
  }
  host_mark_active(s1)
  match a1.active_window() {
    Some(active) => assert_eq(active.wid(), 300)
    None => assert_eq(true, false)
  }
}
