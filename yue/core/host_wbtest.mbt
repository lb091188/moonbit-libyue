// 窗口注册表的无头回归：一宿主管 N 窗的那几条口径——主窗裁决、当前窗切换、
// 浮层跟当前窗、重绘广播、拆窗范围。
// 这里的 App 是**手搓的假窗**（句柄 id 取 900 这类越界值：桩里所有 wm_* 对
// 越界句柄早退，于是注册表与浮层逻辑可以完全不碰平台）。真窗的事件逐窗排空
// 与上屏仍由 examples/native-app 冒烟与用户目视负责（AGENTS 规则 6）。

///|
fn fake_app() -> App {
  let w : @win.Window = { id: 900L, width: 10, height: 10 }
  let root = Widget::new()
  {
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
  }
}

///|
/// 按生产口径登记一扇窗：注册表还空即主窗。
fn fake_open() -> App {
  let a = fake_app()
  host_add(a, host_window_count() == 0)
  a
}

///|
fn empty_node() -> Node {
  node_of_new(fn(p : Widget) -> Widget {
    let w = Widget::new()
    w.set_size(8.0, 8.0)
    p.append_child(w)
    w
  })
}

///|
/// 当前窗的窗号（无窗给 -1）；测试里反复要读，且 `App` 没有 Eq 可比。
fn active_wid() -> Int {
  match host_active() {
    Some(x) => x.wid
    None => -1
  }
}

///|
fn has_active() -> Bool {
  match host_active() {
    Some(_) => true
    None => false
  }
}

///|
test "共用循环：host_loop 两次拿到的是同一个 Loop" {
  host_reset()
  let a = host_loop()
  assert_eq(a.pending(), 0)
  let _ = a.timer(5000, fn() { () })
  // 第二次取回若是个新表，待办数会回到 0（时基那类属性证明不了同一对象，待办数能）
  assert_eq(host_loop().pending(), 1)
  host_reset()
  assert_eq(host_loop().pending(), 0)
}

///|
test "主窗与附窗：第一扇是主窗，摘掉附窗不动主窗" {
  host_reset()
  let a1 = fake_open()
  let a2 = fake_open()
  assert_true(a1.primary)
  assert_false(a2.primary)
  assert_eq(host_window_count(), 2)
  // 新建的窗即当前窗（它要过键盘焦点）
  assert_eq(active_wid(), a2.wid)
  host_deregister(a2)
  assert_eq(host_window_count(), 1)
  assert_eq(active_wid(), a1.wid)
  host_reset()
  assert_eq(host_window_count(), 0)
  assert_eq(has_active(), false)
}

///|
test "关窗裁决：主窗或最后一扇才整体退出" {
  assert_true(host_close_action(true, 3))
  assert_true(host_close_action(false, 0))
  assert_false(host_close_action(false, 1))
}

///|
test "close_window：附窗只摘自己，主窗停派发；重复调用幂等" {
  host_reset()
  let a1 = fake_open()
  let a2 = fake_open()
  a2.close_window()
  assert_eq(host_window_count(), 1)
  assert_true(a1.running)
  assert_false(a2.running)
  assert_true(a2.closed)
  // 句柄被回收成 -1，再调一次不重复摘表也不重复拆
  a2.close_window()
  assert_eq(host_window_count(), 1)
  assert_eq(a2.window.id, -1L)
  a1.close_window()
  assert_eq(host_window_count(), 0)
  assert_false(a1.is_running())
  host_reset()
}

///|
test "重绘广播：invalidate 让所有在窗置脏" {
  host_reset()
  let a1 = fake_open()
  let a2 = fake_open()
  a1.dirty = false
  a2.dirty = false
  install_host_hooks()
  invalidate()
  assert_true(a1.dirty)
  assert_true(a2.dirty)
  host_reset()
}

///|
test "浮层开在当前窗：切换当前窗后新层落进另一棵树的图层" {
  host_reset()
  let a1 = fake_open()
  let a2 = fake_open()
  install_host_hooks()
  assert_eq(overlay_count(), 0)
  let id1 = overlay_show_at(empty_node(), 10.0, 10.0)
  // 当前窗是后建的 a2，于是这一层开在 a2 的图层里、a1 的图层还不可见
  assert_eq(overlay_count(), 1)
  assert_eq(a2.host.items.length(), 1)
  assert_eq(a1.host.items.length(), 0)
  assert_true(a2.host.layer.visible)
  assert_false(a1.host.layer.visible)
  host_mark_active(a1)
  let id2 = overlay_show_at(empty_node(), 20.0, 20.0)
  assert_eq(a1.host.items.length(), 1)
  assert_eq(a2.host.items.length(), 1)
  // 两扇窗各持一套浮层栈与计数器，句柄互不覆盖
  assert_true(id1 != id2)
  assert_eq(
    match overlay_root_of(id2) {
      Some(w) => a1.host.layer.index_of(w) >= 0
      None => false
    },
    true,
  )
  // 换窗后关不到另一扇窗的层：查找只认当前窗的栈
  overlay_hide(id1)
  assert_eq(a1.host.items.length(), 1)
  assert_eq(a2.host.items.length(), 1)
  overlay_clear()
  assert_eq(a1.host.items.length(), 0)
  assert_eq(a2.host.items.length(), 1)
  host_reset()
}

///|
test "mount 升的是本窗图层，不动别的窗" {
  host_reset()
  let a1 = fake_open()
  let a2 = fake_open()
  install_host_hooks()
  host_mark_active(a1)
  let _ = overlay_show_at(empty_node(), 0.0, 0.0)
  // a1 挂内容：图层必须回到 a1 根控件的最后；a2 的图层位置不受影响
  let a2_layer_at = a2.root.index_of(a2.host.layer)
  a1.mount([empty_node(), empty_node()])
  assert_eq(a1.host.items.length(), 1)
  assert_eq(a1.root.index_of(a1.host.layer), a1.root.children().length() - 1)
  assert_eq(a2.root.index_of(a2.host.layer), a2_layer_at)
  assert_eq(a2.host.items.length(), 0)
  host_reset()
}

///|
test "shutdown 把所有还在的窗一起拆掉并复位注册表" {
  host_reset()
  let a1 = fake_open()
  let a2 = fake_open()
  a1.shutdown()
  assert_eq(host_window_count(), 0)
  assert_false(a1.running)
  assert_false(a2.running)
  assert_eq(a1.window.id, -1L)
  assert_eq(a2.window.id, -1L)
  // 复位后同进程再开一窗又是主窗
  let a3 = fake_open()
  assert_true(a3.primary)
  host_reset()
}
