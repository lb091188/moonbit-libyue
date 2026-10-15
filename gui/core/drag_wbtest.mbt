// W21c 拖放回归（core 侧）：种类编号、数据编码/解码、`DragData::kind`/`as_text`、
// 投放目标命中（最深的带 `on_drop` 的控件）、以及会话生命周期
// （begin → move → drop 投给命中最深者 / 无落点不接受 / cancel）。
//
// 观测一律走字符串/编号（仓库约定：给值类型 `derive(Eq)` 在本工具链里会把 impl
// 方法隐式升成普通方法并告警，零警告门禁下不划算）。

///|
/// `DataKind?` → 可读编号（`None` 记 0）：断言走它，避开对枚举做 `assert_eq`。
fn kind_id_of_opt(k : DataKind?) -> Int {
  match k {
    Some(x) => data_kind_id(x)
    None => 0
  }
}

///|
test "data_kind_id ↔ data_kind_of_id 往返，值固定为旧栈口径" {
  inspect(data_kind_id(Text), content="1")
  inspect(data_kind_id(Html), content="2")
  inspect(data_kind_id(Image), content="3")
  inspect(data_kind_id(FilePaths), content="4")
  inspect(kind_id_of_opt(data_kind_of_id(1)), content="1")
  inspect(kind_id_of_opt(data_kind_of_id(2)), content="2")
  inspect(kind_id_of_opt(data_kind_of_id(3)), content="3")
  inspect(kind_id_of_opt(data_kind_of_id(4)), content="4")
  // 认不出的编号给 None（不悄悄当文本）
  inspect(kind_id_of_opt(data_kind_of_id(0)), content="0")
  inspect(kind_id_of_opt(data_kind_of_id(9)), content="0")
}

///|
test "DragData::kind 与 as_text" {
  inspect(data_kind_id(DragData::Text("a").kind()), content="1")
  inspect(data_kind_id(DragData::Html("<p>").kind()), content="2")
  inspect(data_kind_id(DragData::Paths(["a", "b"]).kind()), content="4")
  inspect(data_kind_id(DragData::Img(b"\x89PNG").kind()), content="3")
  inspect(DragData::Text("a").as_text().unwrap_or("-"), content="a")
  // 多路径按旧栈口径用 \n 连接
  inspect(DragData::Paths(["a", "b"]).as_text().unwrap_or("-"), content="a\nb")
  // 图片没有文本形态
  assert_true(DragData::Img(b"\x89PNG").as_text() is None)
}

///|
test "编码/解码往返：文本 / HTML / 路径 / 图片；坏输入给 None" {
  let rt = fn(d : DragData) -> DragData? { drag_decode(drag_encode(d)) }
  match rt(DragData::Text("你好 world")) {
    Some(Text(t)) => assert_eq(t, "你好 world")
    _ => fail("文本往返失败")
  }
  match rt(DragData::Html("<b>x</b>")) {
    Some(Html(t)) => assert_eq(t, "<b>x</b>")
    _ => fail("HTML 往返失败")
  }
  match rt(DragData::Paths(["/a/b.txt", "/c/d.txt"])) {
    Some(Paths(ps)) => {
      assert_eq(ps.length(), 2)
      assert_eq(ps[0], "/a/b.txt")
      assert_eq(ps[1], "/c/d.txt")
    }
    _ => fail("路径往返失败")
  }
  match rt(DragData::Img(b"\x89PNG\r\n")) {
    Some(Img(b)) => assert_eq(b.length(), 6)
    _ => fail("图片往返失败")
  }
  // 空路径表也要能往返（空载荷不是「坏输入」）
  match rt(DragData::Paths([])) {
    Some(Paths(ps)) => assert_eq(ps.length(), 0)
    _ => fail("空路径表往返失败")
  }
  // 头 4 字节是种类号（小端）
  let enc = drag_encode(DragData::Text("x"))
  assert_eq(enc.length(), 5)
  assert_eq(enc[0].to_int(), 1)
  assert_eq(enc[1].to_int(), 0)
  // 不足 4 字节 / 认不出的种类号 → None
  assert_true(drag_decode(b"\x01\x00") is None)
  assert_true(drag_decode(b"\x63\x00\x00\x00x") is None)
}

///|
test "投放目标命中：取子树里最深的带 on_drop 的控件" {
  let root = Widget::new()
  root.set_size(300.0, 200.0)
  root.set_column()
  let outer = Widget::new()
  outer.set_size(200.0, 100.0)
  let inner = Widget::new()
  inner.set_size(80.0, 40.0)
  outer.set_on_drop(fn(_d : DragData, _x : Double, _y : Double) -> Bool { true })
  inner.set_on_drop(fn(_d : DragData, _x : Double, _y : Double) -> Bool { true })
  root.append_child(outer)
  outer.append_child(inner)
  root.relayout(300.0, 200.0)
  // 内层范围内 → 命中内层（最深优先）
  assert_eq(root.drop_target_at(10.0, 10.0), inner.id)
  // 内层之外、外层之内 → 命中外层
  assert_eq(root.drop_target_at(120.0, 60.0), outer.id)
  // 都之外 → 0
  assert_eq(root.drop_target_at(280.0, 180.0), 0)
  // 没标 on_drop 的控件不算投放目标
  let plain = Widget::new()
  plain.set_size(100.0, 50.0)
  let root2 = Widget::new()
  root2.set_size(200.0, 100.0)
  root2.append_child(plain)
  root2.relayout(200.0, 100.0)
  assert_eq(root2.drop_target_at(10.0, 10.0), 0)
}

///|
test "会话：begin → move 重算落点 → drop 投给命中最深者并结束" {
  let root = Widget::new()
  root.set_size(300.0, 200.0)
  root.set_column()
  let outer = Widget::new()
  outer.set_size(200.0, 100.0)
  let inner = Widget::new()
  inner.set_size(80.0, 40.0)
  let got : Ref[String] = Ref("-")
  outer.set_on_drop(fn(_d : DragData, _x : Double, _y : Double) -> Bool {
    got.val = "outer"
    true
  })
  inner.set_on_drop(fn(d : DragData, _x : Double, _y : Double) -> Bool {
    got.val = match d.as_text() {
      Some(t) => "inner:" + t
      None => "inner:非文本"
    }
    true
  })
  root.append_child(outer)
  outer.append_child(inner)
  root.relayout(300.0, 200.0)
  set_drag_root(root)
  assert_false(drag_active())
  assert_eq(drag_source(), 0)
  assert_eq(drag_hover(), 0)
  // 开拖：起点在外层空白处，落点随即算出来
  assert_true(drag_begin(DragData::Text("载荷"), 0, 120.0, 60.0))
  assert_true(drag_active())
  assert_eq(drag_source(), 0)
  assert_eq(drag_hover(), outer.id)
  // 叠一个会话给 false（不叠）
  assert_false(drag_begin(DragData::Text("第二份"), 0, 0.0, 0.0))
  // 移到内层：落点变（返回 true），并换到内层
  assert_true(drag_move(10.0, 10.0))
  assert_eq(drag_hover(), inner.id)
  // 落点没变时返回 false（不值得重绘）
  assert_false(drag_move(12.0, 12.0))
  assert_eq(drag_position(), (12.0, 12.0))
  // 松手：投给内层，拿到数据，会话结束
  assert_true(drag_drop(12.0, 12.0))
  assert_eq(got.val, "inner:载荷")
  assert_false(drag_active())
  assert_true(drag_data() is None)
  clear_drag_root()
}

///|
test "会话：无落点不接受、cancel 直接结束、投给拒绝的目标算拒绝" {
  let root = Widget::new()
  root.set_size(300.0, 200.0)
  let no = Widget::new()
  no.set_size(100.0, 50.0)
  let asked = Ref(0)
  no.set_on_drop(fn(_d : DragData, _x : Double, _y : Double) -> Bool {
    asked.val = asked.val + 1
    false // 明确拒绝
  })
  root.append_child(no)
  root.relayout(300.0, 200.0)
  set_drag_root(root)
  // 无落点（点在控件外）：不接受，但会话照样结束
  assert_true(drag_begin(DragData::Text("x"), 0, 250.0, 150.0))
  assert_eq(drag_hover(), 0)
  assert_false(drag_move(250.0, 150.0))
  assert_false(drag_drop(250.0, 150.0))
  assert_false(drag_active())
  // 目标拒绝：回调被调到一次，返回 false
  assert_true(drag_begin(DragData::Text("x"), 0, 10.0, 10.0))
  assert_eq(drag_hover(), no.id)
  assert_false(drag_drop(10.0, 10.0))
  assert_eq(asked.val, 1)
  assert_false(drag_active())
  // cancel：不投递就结束（目标不再被问第二次）
  assert_true(drag_begin(DragData::Text("x"), 0, 10.0, 10.0))
  drag_cancel()
  assert_false(drag_active())
  assert_eq(asked.val, 1)
  // 空会话上的 cancel / drop / move 都不崩
  drag_cancel()
  assert_false(drag_drop(0.0, 0.0))
  assert_false(drag_move(0.0, 0.0))
  clear_drag_root()
}

///|
test "没装拖拽根时：会话能开能关，落点恒为无（不静默出错）" {
  clear_drag_root()
  assert_true(drag_begin(DragData::Text("x"), 7, 1.0, 2.0))
  assert_eq(drag_source(), 7)
  assert_eq(drag_hover(), 0)
  assert_false(drag_drop(1.0, 2.0))
  assert_false(drag_active())
}

///|
/// 系统级拖入回归：直接喂 `drag_external_feed`（不经真后端的 OLE 队列，那半截由
/// `experiment/drag_probe` 在 C 侧钉住），验「进入开会话 → 移动换落点 → 按落点的
/// accept 答效果 → 松手投递 → 会话与效果一起收掉」，以及认不出的格式不开会话、
/// 离开即取消、应用内拖拽不被外部事件劫持。
test "系统级拖入：喂事件驱动会话，效果按落点的收不收答" {
  let root = Widget::new()
  root.set_size(300.0, 200.0)
  root.set_column()
  let got : Ref[String] = Ref("-")
  let yes = Widget::new()
  yes.set_size(100.0, 60.0)
  yes.set_on_drop(fn(d : DragData, _x : Double, _y : Double) -> Bool {
    got.val = d.as_text().unwrap_or("非文本")
    true
  })
  yes.set_drag_accept(fn(d : DragData) -> Bool { d.is_kind(FilePaths) })
  let no = Widget::new()
  no.set_size(100.0, 60.0)
  no.set_on_drop(fn(_d : DragData, _x : Double, _y : Double) -> Bool { false })
  // 这一只什么都不收：悬停时系统光标要显示禁止
  no.set_drag_accept(fn(_d : DragData) -> Bool { false })
  root.append_child(yes)
  root.append_child(no)
  root.relayout(300.0, 200.0)
  set_drag_root(root)
  let files = DragData::Paths(["/a.txt", "/b.txt"])
  let slot = 7
  // 进入「收」的那只：开会话、落点命中、答 COPY
  drag_external_feed(slot, @win.DRAGDND_ENTER, 10.0, 10.0, Some(files))
  assert_true(drag_active())
  assert_eq(drag_source(), 0)
  assert_eq(drag_hover(), yes.id)
  assert_eq(drag_external_effect(), 1)
  // 移到「不收」的那只：落点变了，效果跟着变 NONE（系统光标显示禁止）
  drag_external_feed(slot, @win.DRAGDND_OVER, 10.0, 90.0, Some(files))
  assert_eq(drag_hover(), no.id)
  assert_eq(drag_external_effect(), 0)
  // 移回来：又答 COPY
  drag_external_feed(slot, @win.DRAGDND_OVER, 12.0, 12.0, Some(files))
  assert_eq(drag_hover(), yes.id)
  assert_eq(drag_external_effect(), 1)
  // 认不出的格式（载荷解不出来）：不开新会话、不动现有会话
  drag_external_feed(slot, @win.DRAGDND_ENTER, 10.0, 10.0, None)
  assert_eq(drag_hover(), yes.id)
  // 松手：投给落点、拿到数据、会话与效果一起收掉
  drag_external_feed(slot, @win.DRAGDND_DROP, 10.0, 10.0, None)
  assert_eq(got.val, "/a.txt\n/b.txt")
  assert_false(drag_active())
  assert_eq(drag_external_effect(), 0)
  // 离开：会话取消，不投递
  got.val = "-"
  drag_external_feed(slot, @win.DRAGDND_ENTER, 10.0, 10.0, Some(files))
  assert_true(drag_active())
  drag_external_feed(slot, @win.DRAGDND_LEAVE, 0.0, 0.0, None)
  assert_false(drag_active())
  assert_eq(got.val, "-")
  assert_eq(drag_external_effect(), 0)
  // 别的窗的事件不抢会话（会话只认开头那一扇窗）
  drag_external_feed(slot, @win.DRAGDND_ENTER, 10.0, 10.0, Some(files))
  drag_external_feed(slot + 1, @win.DRAGDND_OVER, 10.0, 90.0, Some(files))
  assert_eq(drag_hover(), yes.id)
  // 应用内拖拽正在跑时，外部进入事件不劫持
  drag_external_feed(slot, @win.DRAGDND_LEAVE, 0.0, 0.0, None)
  assert_true(drag_begin(DragData::Text("内部"), 42, 10.0, 90.0))
  drag_external_feed(slot, @win.DRAGDND_ENTER, 10.0, 10.0, Some(files))
  assert_eq(drag_source(), 42)
  assert_eq(drag_hover(), no.id)
  drag_cancel()
  clear_drag_root()
}
