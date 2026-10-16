// 「声明即可聚焦」的无头回归：焦点栈由控件树喂（`Widget::focus_ids` →
// `FocusStack::sync`），调用方不必把焦点号逐个 `register`。
// 这条缺口在真机上的症状是「点进框里、光标也画出来了，打字却毫无反应」——
// 点击走指针链路（与焦点无关），键却只投给焦点栈里的那只控件。
// 假窗照 `host_wbtest.mbt`：句柄取越界值，桩里所有 wm_* 对越界句柄早退。

///|
fn fake_win_app() -> App {
  let w : @win.Window = { id: 900L, width: 200, height: 200, }
  let root = Widget::new()
  let a : App = {
    window: w,
    sched: host_loop(),
    root,
    focus: FocusStack::new(),
    host: make_overlay_host(root),
    wid: host_new_wid(),
    primary: false,
    closed: false,
    dirty: false,
    running: true,
    last_preedit: ("", 0),
    ime_focus: 0,
    hover_id: -1,
    capture: -1,
    cursor_kind: 0,
    canvas: None,
    key_fallthrough: [],
    dirty_rect: None,
    dirty_full: false,
  }
  host_add(a, host_window_count() == 0)
  a
}

///|
/// root 里竖排两只输入框（焦点号 7、9），各 200x30。
fn two_fields(a : App) -> (Widget, Widget) {
  let one = Widget::new()
  let two = Widget::new()
  one.focus_id = 7
  two.focus_id = 9
  one.set_size(200.0, 30.0)
  two.set_size(200.0, 30.0)
  a.root.set_column()
  a.root.append_child(one)
  a.root.append_child(two)
  a.root.relayout(200.0, 200.0)
  (one, two)
}

///|
fn down_at(a : App, x : Int, y : Int) -> Unit {
  a.route({ code: 2, keysym: 0, mods: 0, x, y, button: 1, axis: 0, })
}

///|
fn key_down(a : App, keysym : Int) -> Unit {
  a.route({ code: 0, keysym, mods: 0, x: 0, y: 0, button: 0, axis: 0, })
}

///|
test "focus_ids 按树序收集，跳过隐藏子树并去重" {
  let root = Widget::new()
  let a = Widget::new()
  let b = Widget::new()
  let inner = Widget::new()
  a.focus_id = 3
  b.focus_id = 1
  inner.focus_id = 3 // 与 a 同号：只留第一次出现
  let hidden = Widget::new()
  hidden.focus_id = 8
  hidden.set_visible(false)
  let zero = Widget::new() // 没声明焦点号
  root.append_child(a)
  root.append_child(b)
  root.append_child(hidden)
  root.append_child(zero)
  a.append_child(inner)
  assert_eq(root.focus_ids(), [3, 1])
  // 藏起来的整块不算可 Tab（隐藏页里的输入框不该挡在 Tab 次序里）
  hidden.set_visible(true)
  assert_eq(root.focus_ids(), [3, 1, 8])
}

///|
/// sync 只做「对齐」两件事：列表换成树给的、当前焦点按号保住。
/// 尤其不许在本来没焦点时抢一个（`drop_current` 把键让给网页子件之后，
/// 下一次对齐又抢回来就是把焦点还给自绘控件——那是用户没要的行为）。
test "sync 对齐列表、保住当前焦点，绝不无中生有" {
  let f = FocusStack::new()
  f.sync([7, 9])
  assert_eq(f.count(), 2)
  assert_eq(f.current(), None) // 本来没焦点：不许抢一个
  assert_eq(f.focus(42), false) // 掉出树的号依旧不可聚焦
  assert_eq(f.focus(9), true)
  assert_eq(f.current(), Some(9))
  f.sync([9, 7]) // 次序换了但号还在：焦点跟着号走
  assert_eq(f.current(), Some(9))
  f.sync([7]) // 9 掉出树：焦点随之清空
  assert_eq(f.current(), None)
  f.drop_current()
  f.sync([7, 11]) // 让位给网页子件期间不抢回来
  assert_eq(f.current(), None)
  assert_eq(f.count(), 2)
  // register 的「首项默认聚焦」口径不受 sync 影响
  let g = FocusStack::new()
  assert_eq(g.register(3), true)
  assert_eq(g.current(), Some(3))
  g.sync([3, 4])
  assert_eq(g.current(), Some(3))
}

///|
/// 端到端：点进输入框即拿到键盘焦点，键投给它，Tab 走到下一只。
/// 全程没有任何 `focus.register`——这正是缺口所在。
test "按下未注册的焦点号也能接管键盘，Tab 按树序环绕" {
  host_reset()
  let a = fake_win_app()
  let log : Array[String] = []
  let (one, two) = two_fields(a)
  one.on_key = Some(fn(ev : KeyEvent) -> Bool {
    log.push("one:\{ev.keysym}")
    true
  })
  two.on_key = Some(fn(ev : KeyEvent) -> Bool {
    log.push("two:\{ev.keysym}")
    true
  })
  assert_eq(a.focus.count(), 0)
  down_at(a, 100, 15)
  assert_eq(a.focus.current(), Some(7))
  assert_eq(one.focused, false) // 焦点标志由 paint_frame 同步，这里手动对一次
  a.root.set_focused_by_focus(7)
  assert_eq((one.focused, two.focused), (true, false))
  key_down(a, 97)
  assert_eq(log, ["one:97"])
  // Tab 到第二只
  a.move_focus(false)
  assert_eq(a.focus.current(), Some(9))
  key_down(a, 98)
  assert_eq(log, ["one:97", "two:98"])
  // 第二只被藏起来后，Tab 只在剩下那只上绕
  two.set_visible(false)
  a.move_focus(false)
  assert_eq(a.focus.current(), Some(7))
  host_reset()
}

///|
/// 点击不带焦点号的空白处不许改动当前焦点（与 Web 同：点空白不丢表单焦点）。
test "点空白与点到非焦点区不抢焦点、不改栈" {
  host_reset()
  let a = fake_win_app()
  let (_, two) = two_fields(a)
  down_at(a, 100, 150) // 两行之下的空白
  assert_eq(a.focus.current(), None)
  assert_eq(a.focus.count(), 2)
  down_at(a, 100, 45)
  assert_eq(a.focus.current(), Some(9))
  assert_eq(two.focused, false)
  host_reset()
}
