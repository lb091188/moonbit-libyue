// 宿主层的无头回归：原始事件翻译表 + 输入法四签名的投递语义。
// App 本体（建窗/上屏）不进单测——按 AGENTS 规则 6，那部分由 examples/native-app
// 冒烟与用户目视负责。

///|
/// PointerKind 比不了 `==`（无载荷枚举在本工具链不自动派生 Eq，derive 又触发
/// implicit_impl_as_method 弃用警告），这里按 match 归一。
fn kind_is_down(k : PointerKind) -> Bool {
  match k {
    Down => true
    _ => false
  }
}

///|
/// 同一个 `kind` 是否为 Up（只用于区分 Down 之外的分支）
fn kind_is_up(k : PointerKind) -> Bool {
  match k {
    Up => true
    _ => false
  }
}

///|
fn kind_is_move(k : PointerKind) -> Bool {
  match k {
    Move => true
    _ => false
  }
}

///|
test "原始事件翻译：键/按钮/移动/滚轮/未知" {
  match raw_to_event(0, 97, 0, 1, 2, 0, 0) {
    Key(k) => {
      assert_eq(k.press, true)
      assert_eq(k.keysym, 97)
      assert_eq(k.mods, 0)
    }
    _ => assert_eq(true, false)
  }
  match raw_to_event(1, 97, 2, 0, 0, 0, 0) {
    Key(k) => {
      assert_eq(k.press, false)
      assert_eq(k.mods, 2)
    }
    _ => assert_eq(true, false)
  }
  match raw_to_event(2, 0, 0, 10, 20, 1, 0) {
    Pointer(p) => {
      assert_eq(kind_is_down(p.kind), true)
      assert_eq((p.x, p.y), (10.0, 20.0))
      assert_eq(p.button, 1)
    }
    _ => assert_eq(true, false)
  }
  match raw_to_event(3, 0, 0, 10, 20, 1, 0) {
    Pointer(p) => assert_eq(kind_is_up(p.kind), true)
    _ => assert_eq(true, false)
  }
  match raw_to_event(4, 0, 0, 7, 8, 0, 0) {
    Pointer(p) => assert_eq(kind_is_move(p.kind), true)
    _ => assert_eq(true, false)
  }
  // 滚轮：button 槽是横向、axis 槽是纵向（正=上滚）
  match raw_to_event(5, 0, 0, 3, 4, -1, 1) {
    Scroll(s) => {
      assert_eq((s.dx, s.dy), (-1.0, 1.0))
      assert_eq((s.x, s.y), (3.0, 4.0))
    }
    _ => assert_eq(true, false)
  }
  match raw_to_event(9, 0, 0, 0, 0, 0, 0) {
    Ignored => ()
    _ => assert_eq(true, false)
  }
}

///|
/// 一棵带输入法回调的小树：root > mid > field
fn ime_tree(
  log : Array[String],
  commits : Bool,
) -> (Widget, Widget, Widget) {
  let root = Widget::new()
  let mid = Widget::new()
  let field = Widget::new()
  root.append_child(mid)
  mid.append_child(field)
  field.focus_id = 5
  field.im_context = Some(fn() -> (String, Int)? { Some(("已提交", 6)) })
  field.im_cursor = Some(fn() -> Rect? {
    Some({ x: 12.0, y: 3.0, w: 1.0, h: 16.0 })
  })
  field.on_commit = Some(fn(t : String) -> Bool {
    log.push("field:" + t)
    commits
  })
  mid.on_commit = Some(fn(t : String) -> Bool {
    log.push("mid:" + t)
    true
  })
  field.on_preedit = Some(fn(t : String, caret : Int) -> Unit {
    log.push("preedit:\{t}@\{caret}")
  })
  (root, mid, field)
}

///|
test "commit 沿祖先链冒泡；消费即停" {
  let log : Array[String] = []
  // field 不消费 → 上传到 mid
  let (root, _, _) = ime_tree(log, false)
  assert_eq(root.dispatch_commit(5, "你"), true)
  assert_eq(log.length(), 2)
  assert_eq(log[0], "field:你")
  assert_eq(log[1], "mid:你")

  // field 消费 → mid 收不到
  let log2 : Array[String] = []
  let (root2, _, _) = ime_tree(log2, true)
  assert_eq(root2.dispatch_commit(5, "好"), true)
  assert_eq(log2.length(), 1)
  assert_eq(log2[0], "field:好")
}

///|
test "preedit 只投焦点控件，不冒泡、错 id 无副作用" {
  let log : Array[String] = []
  let (root, _, _) = ime_tree(log, true)
  root.dispatch_preedit(5, "nihao", 5)
  assert_eq(log.length(), 1)
  assert_eq(log[0], "preedit:nihao@5")
  // 焦点 id 不在树里：什么都不发生
  root.dispatch_preedit(42, "x", 1)
  assert_eq(log.length(), 1)
}

///|
test "im_context / im_cursor 只在焦点控件声明时可得，隐藏后不可达" {
  let log : Array[String] = []
  let (root, _, field) = ime_tree(log, true)
  match root.im_context_of(5) {
    Some((text, caret)) => {
      assert_eq(text, "已提交")
      assert_eq(caret, 6)
    }
    None => assert_eq(true, false)
  }
  match root.im_cursor_of(5) {
    Some(r) => assert_eq((r.x, r.y, r.w, r.h), (12.0, 3.0, 1.0, 16.0))
    None => assert_eq(true, false)
  }
  // 焦点在别的控件（id 不匹配）→ 宿主本轮不喂输入法
  assert_eq(
    match root.im_context_of(9) {
      None => true
      Some(_) => false
    },
    true,
  )
  // 隐藏后不可达（焦点栈仍可能留着它的 id）
  field.set_visible(false)
  assert_eq(
    match root.im_context_of(5) {
      None => true
      Some(_) => false
    },
    true,
  )
}

///|
test "无 im_context 声明的控件不参与输入法轮次" {
  let root = Widget::new()
  let plain = Widget::new()
  root.append_child(plain)
  plain.focus_id = 3
  assert_eq(
    match root.im_context_of(3) {
      None => true
      Some(_) => false
    },
    true,
  )
  assert_eq(root.dispatch_commit(3, "a"), false)
}
