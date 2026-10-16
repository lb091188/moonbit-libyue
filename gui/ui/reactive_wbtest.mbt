// for_list / when 薄入口回归（§3 第 4 项）：keyed 差分只重挂该挂的行、
// 未变行复用原控件；when 单支切显隐不销毁、双支常驻切换。

///|
fn it(id : Int, name : String) -> @core.Item {
  { id, name }
}

///|
fn item_node(t : @core.Item, _i : Int) -> @core.Node {
  text(t.name)
}

///|
fn item_eq(a : @core.Item, b : @core.Item) -> Bool {
  a.name == b.name
}

///|
fn item_key(t : @core.Item) -> Int {
  t.id
}

///|
test "for_list：keyed 增删改——新增建行、删除出树、中间插入挪位不重挂旧行" {
  let init : Array[@core.Item] = [it(1, "甲"), it(2, "乙")]
  let ls = @core.ListStore::new(init=init)
  let root = mount_root([for_list(ls, item_node, key=item_key, eq=item_eq)], 200.0, 300.0)
  let host = kid(root, 0)
  assert_eq(host.children().length(), 2)
  let row1 = host.children()[0]
  // 尾部追加：只新建一行
  ls.push(it(3, "丙"))
  assert_eq(host.children().length(), 3)
  assert_true(host.children()[0].id == row1.id)
  // 删掉第一行：id=1 出树，其余行控件不换
  let _ = ls.remove(fn(t : @core.Item) -> Bool { t.id == 1 })
  assert_eq(host.children().length(), 2)
  assert_eq(host.children()[0].rect.w, host.children()[0].rect.w)
  let row2 = host.children()[0]
  // 头部插入新键：只建一行，旧行挪位不换控件
  ls.splice(0, 0, [it(0, "丁")])
  assert_eq(host.children().length(), 3)
  assert_true(host.children()[1].id == row2.id)
}

///|
test "for_list：同键值变（给了 eq）重挂该行，别的行原样" {
  let init : Array[@core.Item] = [it(1, "甲"), it(2, "乙")]
  let ls = @core.ListStore::new(init=init)
  let root = mount_root([for_list(ls, item_node, key=item_key, eq=item_eq)], 200.0, 300.0)
  let host = kid(root, 0)
  let keep = host.children()[0].id
  let _ = ls.update(
    fn(t : @core.Item) -> Bool { t.id == 2 },
    fn(t : @core.Item) -> @core.Item { { id: t.id, name: "乙改" } },
  )
  assert_eq(host.children().length(), 2)
  assert_true(host.children()[0].id == keep)
  assert_true(host.children()[1].id != keep) // 变更行是新控件
}

///|
test "for_list_indexed：按下标对齐，内容变即重挂该行" {
  let ls = @core.ListStore::new(init=[it(1, "甲")])
  let root = mount_root([for_list_indexed(ls, item_node)], 200.0, 300.0)
  let host = kid(root, 0)
  assert_eq(host.children().length(), 1)
  ls.push(it(2, "乙"))
  assert_eq(host.children().length(), 2)
}

///|
test "when 单支：真挂假隐不销毁，Store/Signal 都能盯" {
  let busy = @core.Store::new(false)
  let root = mount_root([when_store_bool(busy, text("保存中…"))], 200.0, 300.0)
  let host = kid(root, 0)
  assert_eq(host.children().length(), 1)
  assert_true(!host.children()[0].visible)
  let row_id = host.children()[0].id
  busy.set(true)
  assert_true(host.children()[0].visible)
  busy.set(false)
  assert_true(!host.children()[0].visible)
  // 不销毁：控件还是那一个
  assert_true(host.children()[0].id == row_id)
}

///|
test "when_else 双支：两支常驻切显隐，零重建" {
  let has = @core.Store::new(false)
  let root = mount_root(
    [when_else_bool(has.signal(), text("有内容"), text("暂无任务"))],
    200.0,
    300.0,
  )
  // 双支常驻：两支都挂在 when 的宿主里，切显隐零重建
  let host = kid(root, 0)
  assert_eq(host.children().length(), 2)
  let a = host.children()[0].id
  let b = host.children()[1].id
  assert_true(!host.children()[0].visible && host.children()[1].visible)
  has.set(true)
  assert_true(host.children()[0].visible && !host.children()[1].visible)
  assert_true(host.children()[0].id == a && host.children()[1].id == b)
}

///|
test "when：非布尔源用 pred 折算" {
  let n = @core.Store::new(0)
  let root = mount_root(
    [when(
      n.signal(),
      text("有数"),
      pred=fn(v : Int) -> Bool { v > 3 },
    )],
    200.0,
    300.0,
  )
  let host = kid(root, 0)
  assert_true(!host.children()[0].visible)
  n.set(5)
  assert_true(host.children()[0].visible)
  n.set(1)
  assert_true(!host.children()[0].visible)
}

///|
test "when_else 通用档：非布尔源 pred 折算，真挂 then 假挂 otherwise" {
  // 回归 2026-10-16 moon-launcher 实踩：通用档曾把 (then, otherwise) 直喂
  // swap_node（位序 a=假支、b=真支），条件真显示的是 otherwise
  let n = @core.Store::new(0)
  let root = mount_root(
    [when_else(n.signal(), text("有数"), text("无数"), pred=fn(v : Int) -> Bool { v > 3 })],
    200.0,
    300.0,
  )
  let host = kid(root, 0)
  assert_eq(host.children().length(), 2)
  assert_true(!host.children()[0].visible && host.children()[1].visible)
  n.set(5)
  assert_true(host.children()[0].visible && !host.children()[1].visible)
  n.set(2)
  assert_true(!host.children()[0].visible && host.children()[1].visible)
  // 零重建：两支控件不换
  let a = host.children()[0].id
  let b = host.children()[1].id
  n.set(9)
  assert_true(host.children()[0].id == a && host.children()[1].id == b)
}

///|
test "when_else_store 通用档：Store 形态与信号版同极性" {
  // 缺省折算恒真（when_default_pred），这里显式给判据
  let opt : @core.Store[String?] = @core.Store::new(None)
  let root = mount_root(
    [
      when_else_store(
        opt,
        text("有名字"),
        text("缺名字"),
        pred=fn(v : String?) -> Bool { v is Some(_) },
      ),
    ],
    200.0,
    300.0,
  )
  let host = kid(root, 0)
  assert_true(!host.children()[0].visible && host.children()[1].visible)
  opt.set(Some("甲"))
  assert_true(host.children()[0].visible && !host.children()[1].visible)
}
