// 声明式地基回归：Node 挂载、bind_node 原位重挂、订阅不累积、swap_node
// 显隐、invalidate 走重绘钩子。全程无头（不建窗口，重绘钩子自己装计数器）。

///|
/// 记下重绘请求次数的钩子（测试结束务必还原成空操作，别污染别的用例）。
fn counting_hook(counter : Ref[Int]) -> (() -> Unit) {
  fn() { counter.val = counter.val + 1 }
}

///|
test "node_of / mount_children：按顺序成为 parent 的直接子项" {
  let parent = Widget::new()
  parent.set_column()
  let a = node_of(sized(Widget::new(), 40.0, 10.0))
  let b = node_of_new(fn(w : Widget) { sized(w, 40.0, 20.0) })
  let c = node_of(sized(Widget::new(), 40.0, 30.0))
  mount_children(parent, [a, b, c])
  parent.relayout(40.0, 60.0)
  let kids = parent.children()
  assert_eq(kids.length(), 3)
  assert_eq((kids[0].rect.h, kids[1].rect.h, kids[2].rect.h), (10.0, 20.0, 30.0))
  assert_eq((kids[0].rect.y, kids[1].rect.y, kids[2].rect.y), (0.0, 10.0, 30.0))
}

///|
test "bind_node：信号变化后**原位**换掉那一棵，兄弟项不受影响" {
  let counter = Ref(0)
  set_repaint_hook(counting_hook(counter))
  let sig = Signal::new(10.0)
  let parent = Widget::new()
  parent.set_column()
  let wa = sized(Widget::new(), 40.0, 8.0)
  let wc = sized(Widget::new(), 40.0, 8.0)
  let bn = bind_node(sig, fn(h : Double) -> Node {
    node_of(sized(Widget::new(), 40.0, h))
  })
  mount_children(parent, [node_of(wa), bn, node_of(wc)])
  parent.relayout(40.0, 100.0)
  let first_mid = parent.children()[1].id
  assert_eq(parent.children()[1].rect.h, 10.0)
  assert_eq(wc.rect.y, 18.0)
  let base_calls = counter.val
  assert_true(base_calls > 0)

  sig.set(20.0)
  parent.relayout(40.0, 100.0)
  let kids = parent.children()
  // 棵数没变、位置没变，只有中间那棵换成了新的
  assert_eq(kids.length(), 3)
  assert_eq((kids[0].id, kids[2].id), (wa.id, wc.id))
  assert_true(kids[1].id != first_mid)
  assert_eq(kids[1].rect.h, 20.0)
  assert_eq(kids[1].rect.y, 8.0)
  // 兄弟项坐标跟着新的高度走（说明布局树里的位置也换对了）
  assert_eq(wc.rect.y, 28.0)
  assert_true(counter.val > base_calls)
  set_repaint_hook(fn() { () })
}

///|
test "bind_node：旧代子树的订阅整袋退订，不随重建次数累积" {
  let sig = Signal::new(0)
  let source = Signal::new(1)
  let parent = Widget::new()
  let bn = bind_node(sig, fn(_v : Int) -> Node {
    node_of_new(fn(w : Widget) {
      // 每一代都往 source 上挂一条订阅（不写句柄，全靠回收袋退订）
      ignore(source.subscribe(fn(_x : Int) { () }))
      w
    })
  })
  let _ = (bn.mount)(parent)
  assert_eq(source.sub_count(), 1)
  let mut i = 1
  while i < 6 {
    sig.set(i)
    i = i + 1
  }
  // 重建了 5 次，订阅仍然只有当前一代那一条
  assert_eq(source.sub_count(), 1)
}

///|
test "bind_node：挂载失败不留半棵（重挂后 parent 里始终只有一棵）" {
  let sig = Signal::new(1)
  let parent = Widget::new()
  let bn = bind_node(sig, fn(v : Int) -> Node {
    node_of(sized(Widget::new(), (v.to_double() * 10.0), 10.0))
  })
  let w0 = (bn.mount)(parent)
  assert_eq(parent.children().length(), 1)
  sig.set(2)
  assert_eq(parent.children().length(), 1)
  assert_eq(parent.children()[0].rect.w, 0.0)
  parent.relayout(100.0, 100.0)
  assert_eq(parent.children()[0].rect.w, 20.0)
  // 返回的是第一代控件（挂载当时的句柄），不是重挂后的
  assert_true(w0.id != parent.children()[0].id)
}

///|
test "swap_node：两棵预建，切换只改显隐、隐藏那棵坐标清零" {
  let sig = Signal::new(false)
  let counter = Ref(0)
  set_repaint_hook(counting_hook(counter))
  let parent = Widget::new()
  parent.set_column()
  let a = sized(Widget::new(), 40.0, 10.0)
  let b = sized(Widget::new(), 40.0, 20.0)
  let sw = swap_node(sig, node_of(a), node_of(b))
  let returned = (sw.mount)(parent)
  parent.relayout(40.0, 60.0)
  // 初始 false：a 隐藏、b 显示；返回值是 a
  assert_eq(returned.id, a.id)
  assert_eq((a.visible, b.visible), (true, false))
  // a 可见时占位 10，b 隐藏 → 矩形被整棵清零
  assert_eq(a.rect.h, 10.0)
  assert_eq(b.rect.h, 0.0)

  sig.set(true)
  parent.relayout(40.0, 60.0)
  assert_eq((a.visible, b.visible), (false, true))
  assert_eq(a.rect.h, 0.0)
  assert_eq(b.rect.h, 20.0)
  // 显隐不重建：两棵控件自始至终是同一批句柄
  assert_eq(parent.children().length(), 2)
  assert_true(counter.val > 0)
  set_repaint_hook(fn() { () })
}

///|
test "invalidate：没装钩子时是空操作，重挂照常完成" {
  set_repaint_hook(fn() { () })
  invalidate()
  let sig = Signal::new(1)
  let parent = Widget::new()
  let bn = bind_node(sig, fn(v : Int) -> Node {
    node_of(sized(Widget::new(), v.to_double(), 1.0))
  })
  let _ = (bn.mount)(parent)
  sig.set(2)
  assert_eq(parent.children().length(), 1)
}

///|
test "on_mount：构造期不跑、mount_into 时在挂载之后跑" {
  // view 的 handle 在 node_of_new 里构造期就执行（早于宿主建好）——需要推迟
  // 到真·挂载时机的回调一律包 on_mount
  let ran : Ref[Bool] = Ref(false)
  let kids_at_fire : Ref[Int] = Ref(-1)
  let parent = Widget::new()
  let n = node_of_new(fn(w : Widget) -> Widget {
        w.set_size(10.0, 10.0)
        w
      })
      .on_mount(fn() -> Unit {
        ran.val = true
        kids_at_fire.val = parent.children().length()
      })
  // 构造完还没挂：回调不许跑
  assert_false(ran.val)
  let _ = (n.mount)(parent)
  // 挂载回调跑在本体已挂进父之后
  assert_true(ran.val)
  assert_eq(kids_at_fire.val, 1)
}
