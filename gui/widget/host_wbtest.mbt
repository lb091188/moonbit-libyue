// 窗口注册表的无头回归：一宿主管 N 窗的那几条口径——主窗裁决、当前窗切换、
// 浮层跟当前窗、重绘广播、拆窗范围。
// 这里的 App 是**手搓的假窗**（句柄 id 取 900 这类越界值：桩里所有 wm_* 对
// 越界句柄早退，于是注册表与浮层逻辑可以完全不碰平台）。真窗的事件逐窗排空
// 与上屏仍由 examples/native-app 冒烟与用户目视负责（AGENTS 规则 6）。

///|
fn fake_app() -> App {
  let root = Widget::new()
  {
    session: @shell.fake_session(900, @shell.host_new_wid(), false, 10, 10),
    root,
    focus: FocusStack::new(),
    host: make_overlay_host(root),
    closed: false,
    canvas: None,
    key_fallthrough: [],
    dirty_rect: None,
    dirty_full: false,
  }
}

///|
/// 按生产口径登记一扇窗：注册表还空即主窗。
fn fake_open() -> App {
  let a = fake_app()
  host_add_app(a)
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
    Some(x) => x.wid()
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
  assert_true(a1.session.primary)
  assert_false(a2.session.primary)
  assert_eq(host_window_count(), 2)
  // 新建的窗即当前窗（它要过键盘焦点）
  assert_eq(active_wid(), a2.session.wid)
  host_deregister(a2.session)
  assert_eq(host_window_count(), 1)
  assert_eq(active_wid(), a1.session.wid)
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
  assert_true(a1.session.running)
  assert_false(a2.session.running)
  assert_true(a2.closed)
  // 句柄被回收成 -1，再调一次不重复摘表也不重复拆
  a2.close_window()
  assert_eq(host_window_count(), 1)
  assert_eq(a2.session.window.id, -1L)
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
  a1.session.dirty = false
  a2.session.dirty = false
  install_host_hooks()
  invalidate()
  assert_true(a1.session.dirty)
  assert_true(a2.session.dirty)
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
  host_mark_active(a1.session)
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
/// 图层档浮层可以移动（轻提示后来更宽的一条要按窗口宽重新居中）。
test "overlay_set_pos 按窗口坐标搬动浮层，未知句柄返回 false" {
  host_reset()
  let a1 = fake_open()
  install_host_hooks()
  let id = overlay_show_at(empty_node(), 30.0, 12.0)
  a1.root.relayout(200.0, 100.0)
  match overlay_rect_of(id) {
    Some(r) => assert_eq((r.x, r.y), (30.0, 12.0))
    None => assert_true(false)
  }
  assert_true(overlay_set_pos(id, 55.0, 20.0))
  a1.root.relayout(200.0, 100.0)
  match overlay_rect_of(id) {
    Some(r) => assert_eq((r.x, r.y), (55.0, 20.0))
    None => assert_true(false)
  }
  // 不在当前窗浮层栈里的句柄：不动任何东西
  assert_false(overlay_set_pos(id + 1, 0.0, 0.0))
  overlay_clear()
  host_reset()
}

///|
test "mount 升的是本窗图层，不动别的窗" {
  host_reset()
  let a1 = fake_open()
  let a2 = fake_open()
  install_host_hooks()
  host_mark_active(a1.session)
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
  assert_false(a1.session.running)
  assert_false(a2.session.running)
  assert_eq(a1.session.window.id, -1L)
  assert_eq(a2.session.window.id, -1L)
  // 复位后同进程再开一窗又是主窗
  let a3 = fake_open()
  assert_true(a3.session.primary)
  host_reset()
}

///|
test "弹层摆位：贴着屏幕边翻到锚点另一侧，未知屏幕只钳不翻" {
  // 常规：owner 在 (100,50)，锚点在窗口内 (20,30) → (120,80)
  assert_eq(popup_place(100, 50, 20, 30, 160, 100, 1920, 1080), (120, 80))
  // 越过右边界：向左展开（1900+160 > 1920 → 翻到锚点左侧）
  assert_eq(popup_place(1880, 10, 20, 30, 160, 100, 1920, 1080), (1740, 40))
  // 越过下边界：向上展开
  assert_eq(popup_place(10, 980, 20, 30, 160, 100, 1920, 1080), (30, 910))
  // 两侧同时越界：都翻
  assert_eq(popup_place(1880, 980, 20, 30, 160, 100, 1920, 1080), (1740, 910))
  // 翻到另一侧仍在屏内 → 就用翻转位（不是钳 0）
  assert_eq(popup_place(10, 10, 500, 500, 160, 100, 520, 560), (350, 410))
  // 翻转后仍为负 → 钳回 0（小屏幕上的极端情况）
  assert_eq(popup_place(10, 10, 20, 20, 160, 100, 100, 80), (0, 0))
  // 屏幕尺寸未知（0）：只钳不翻
  assert_eq(popup_place(1880, 980, 20, 30, 160, 100, 0, 0), (1900, 1010))
  // 负的原点（窗口被拖到屏幕外）不产生负坐标
  assert_eq(popup_place(-40, -20, 10, 10, 80, 40, 1920, 1080), (0, 0))
}

///|
/// 按控件 id 局部置脏：只标命中那扇窗的脏区，别的窗不沾；找不到才整窗兜底。
test "invalidate_id 只标命中窗的局部脏区" {
  host_reset()
  let a1 = fake_open()
  let a2 = fake_open()
  let kid = Widget::new()
  kid.set_size(20.0, 12.0)
  a1.root.append_child(kid)
  invalidate_id(kid.id)
  assert_true(a1.session.dirty)
  assert_false(a1.dirty_full)
  match a1.dirty_rect {
    Some(_) => ()
    None => fail("命中控件应当落下局部脏区")
  }
  // 另一扇窗没被牵连（广播式 invalidate 会给它整窗脏）
  assert_false(a2.session.dirty)
  assert_true(a2.dirty_rect is None)
  // 所有窗都没有这个 id：回退整窗广播
  invalidate_id(987_654)
  assert_true(a1.dirty_full)
  assert_true(a2.dirty_full)
  assert_true(a1.dirty_rect is None)
  host_reset()
}

///|
/// 整窗置脏（`full=true`）在同批内不可被局部置脏收窄成小矩形。
test "整窗置脏之后同批的局部置脏不许收窄脏区" {
  let r1 : Rect = { x: 10.0, y: 10.0, w: 20.0, h: 20.0 }
  let r2 : Rect = { x: 40.0, y: 40.0, w: 8.0, h: 8.0 }
  // 没请求整窗：局部置脏照常累积
  let acc = accept_widget_rect(false, Some(r1), r2)
  match acc {
    Some(r) => {
      assert_eq((r.x, r.y), (10.0, 10.0))
      assert_eq((r.w, r.h), (38.0, 38.0))
    }
    None => fail("未请求整窗时应累积成矩形脏区")
  }
  // 已经请求整窗：局部置脏只能维持整窗（None），不得写成小矩形
  assert_true(accept_widget_rect(true, None, r1) is None)
  // 这一帧的裁剪框：整窗请求优先于累积的局部矩形
  match dirty_clip(true, Some(r1)) {
    Some(_) => fail("整窗请求不该带裁剪框")
    None => ()
  }
  match dirty_clip(false, Some(r1)) {
    Some(r) => assert_eq((r.w, r.h), (20.0, 20.0))
    None => fail("未请求整窗时该用累积脏区")
  }
}

///|
/// 焦点变化标脏必须按**焦点 id** 查树：焦点栈记的是使用者给的序号，与控件实例
/// id 是两个空间，混用会把脏区标到另一个控件上（新焦点格当帧不重画）。
test "mark_focus_rect 按焦点 id 命中，不拿它当实例 id 用" {
  host_reset()
  let a = fake_open()
  let decoy = Widget::new()
  a.root.append_child(decoy)
  let field = Widget::new()
  field.focus_id = 9
  a.root.append_child(field)
  field.set_size(120.0, 28.0)
  decoy.set_size(10.0, 10.0)
  a.root.relayout(200.0, 200.0)
  // 实例 id 撞上焦点号的那个控件（decoy 的实例 id 可能恰为 9）不该被标脏
  a.mark_focus_rect(Some(9))
  match a.dirty_rect {
    Some(r) => {
      assert_true(
        r.w >= 120.0,
        msg="脏区没落在焦点 id=9 的控件上（w=\{r.w}）：把焦点 id 当实例 id 用了",
      )
    }
    None => fail("焦点标脏丢了脏区")
  }
  // 树里没有这个焦点号：整窗兜底（宁可多画不可漏画）
  a.dirty_rect = None
  a.session.dirty = false
  a.mark_focus_rect(Some(4444))
  assert_true(a.dirty_full, msg="未知焦点号应回退整窗置脏")
  host_reset()
}

///|
/// 悬停标脏必须覆盖「自绘状态的祖先」：表格行的整行底色就是被漏掉的那类
/// （行画了底，脏区却只有鼠标那一格 → 真机「悬停不是整行」）。
test "mark_state_chain 只把带状态桶的祖先并进脏区" {
  host_reset()
  let a = fake_open()
  let row = Widget::new()
  row.set_size(200.0, 30.0)
  row.paints_state = true
  let cell = Widget::new()
  cell.set_size(50.0, 30.0)
  row.append_child(cell)
  a.root.append_child(row)
  a.root.relayout(200.0, 200.0)
  a.mark_state_chain(cell.id)
  match a.dirty_rect {
    Some(r) => assert_true(
      r.w >= 200.0,
      msg="只标了鼠标那一格（宽 \{r.w}），整行悬停底色不会重画",
    )
    None => fail("悬停标脏丢了脏区")
  }
  // 链上没有状态祖先：代价仍只是最深那颗控件的矩形
  let b = fake_open()
  let plain_row = Widget::new()
  plain_row.set_size(200.0, 30.0)
  let leaf = Widget::new()
  leaf.set_size(50.0, 30.0)
  plain_row.append_child(leaf)
  b.root.append_child(plain_row)
  b.root.relayout(200.0, 200.0)
  b.mark_state_chain(leaf.id)
  match b.dirty_rect {
    Some(r) => assert_true(
      r.w <= 50.5,
      msg="没有状态祖先却把整行并进了脏区（宽 \{r.w}）",
    )
    None => fail("悬停标脏丢了脏区")
  }
  host_reset()
}
