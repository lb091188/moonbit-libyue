// ListStore 与 keyed 差分回归：增删改只写 Store、差分四张表按新表下标定位、
// 重复 key 以新为准、不给 key 走下标对齐、订阅随回收袋退订。

///|
fn eq_str(a : String, b : String) -> Bool {
  a == b
}

///|
test "ListStore：push/remove/update/splice 的表内容与返回值" {
  let ls = ListStore::new()
  let _ = ls.push({ id: 1, name: "甲" })
  let _ = ls.push({ id: 2, name: "乙" })
  let _ = ls.push({ id: 3, name: "丙" })
  assert_eq(ls.length(), 3)
  assert_true(ls.remove(fn(t : Item) -> Bool { t.id == 2 }))
  assert_eq(ls.get().length(), 2)
  assert_false(ls.remove(fn(t : Item) -> Bool { t.id == 99 }))
  assert_true(ls.update(fn(t : Item) -> Bool { t.id == 1 }, fn(t : Item) -> Item {
    { id: t.id, name: "甲改" }
  }))
  assert_eq(ls.get()[0].name, "甲改")
  ls.splice(1, 0, [{ id: 9, name: "丁" }])
  assert_eq(ls.get().length(), 3)
  assert_eq(ls.get()[1].name, "丁")
  // 越界钳制：at 超长按末尾插，del 超长按剩余截断
  ls.splice(99, 99, [{ id: 10, name: "戊" }])
  assert_eq(ls.get()[ls.get().length() - 1].name, "戊")
}

///|
test "keyed_diff：新增/删除/就地变更/移动只报该报的" {
  let old = [
    { id: 1, name: "甲" },
    { id: 2, name: "乙" },
    { id: 3, name: "丙" },
  ]
  let new = [
    { id: 3, name: "丙" },
    { id: 2, name: "乙改" },
    { id: 4, name: "丁" },
  ]
  let d = keyed_diff(
    old,
    new,
    fn(t : Item) -> Int { t.id },
    fn(a : Item, b : Item) -> Bool { a.name == b.name },
  )
  assert_eq(d.removed.length(), 1)
  assert_eq(d.removed[0].id, 1)
  // 2 保留但内容变了
  assert_eq(d.changed.length(), 1)
  assert_eq(d.changed[0].0.name, "乙")
  assert_eq(d.changed[0].1.name, "乙改")
  // 新增落在下标 2
  assert_eq(d.added.length(), 1)
  assert_eq(d.added[0].0, 2)
  assert_eq(d.added[0].1.id, 4)
  // kept 给新落位：3→0，2→1（移动不报 changed）
  assert_eq(d.kept.length(), 2)
  assert_eq(d.kept[0].0, 0)
  assert_eq(d.kept[1].0, 1)
}

///|
test "keyed_diff：重复 key 以新为准；新表重复第二条按新增落位" {
  let old = [{ id: 1, name: "旧" }, { id: 1, name: "更旧" }]
  let new = [{ id: 1, name: "新" }, { id: 1, name: "又新" }]
  let d = keyed_diff(
    old,
    new,
    fn(t : Item) -> Int { t.id },
    fn(a : Item, b : Item) -> Bool { a.name == b.name },
  )
  // 旧表重复：索引按最后一条「更旧」比 → changed 一条；removed 空（seen 含 1）
  assert_eq(d.removed.length(), 0)
  assert_eq(d.changed.length(), 1)
  assert_eq(d.changed[0].0.name, "更旧")
  // 新表第二条同 key：按新增落位下标 1
  assert_eq(d.added.length(), 1)
  assert_eq(d.added[0].0, 1)
}

///|
test "index_diff：下标对齐，只报收缩与替换" {
  let d = index_diff([1, 2, 3], [1, 5], fn(a : Int, b : Int) -> Bool { a == b })
  assert_eq(d.removed.length(), 1)
  assert_eq(d.removed[0], 3)
  assert_eq(d.changed.length(), 1)
  assert_eq(d.added.length(), 0)
  assert_eq(d.kept.length(), 2)
}

///|
test "subscribe_diff：通知带差分，退订后不再唤醒" {
  let ls = ListStore::new(init=[{ id: 1, name: "甲" }])
  let mut hits = 0
  let mut last_added = -1
  sub_bag_begin()
  let _ = ls.subscribe_diff(
    fn(t : Item) -> Int { t.id },
    fn(a : Item, b : Item) -> Bool { a.name == b.name },
    fn(_old : Array[Item], _new : Array[Item], d : KeyDiff[Item]) -> Unit {
      hits += 1
      last_added = if d.added.length() > 0 { d.added[0].1.id } else { -1 }
    },
  )
  let offs = sub_bag_end()
  ls.push({ id: 2, name: "乙" })
  assert_eq(hits, 1)
  assert_eq(last_added, 2)
  ls.push({ id: 3, name: "丙" })
  assert_eq(hits, 2)
  assert_eq(last_added, 3)
  // 整袋退订后不再唤醒
  sub_bag_discard(offs)
  ls.push({ id: 4, name: "丁" })
  assert_eq(hits, 2)
}

///|
test "ListStore 共用同一份 Store：signal 派生与 batch 照旧" {
  let ls = ListStore::new(init=[{ id: 1, name: "甲" }])
  let names = ls.signal().map(fn(ts : Array[Item]) -> String {
    let mut acc = ""
    for t in ts {
      acc = acc + t.name
    }
    acc
  })
  let mut seen = ""
  let _ = names.subscribe(fn(s : String) -> Unit { seen = s })
  ls.push({ id: 2, name: "乙" })
  assert_eq(seen, "甲乙")
  assert_eq(ls.get().length(), 2)
}
