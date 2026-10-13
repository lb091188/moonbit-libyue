// Store 形态回归：自 master 线 `yue/store_test.mbt` 平移（同样只去包前缀）。

///|
test "store 读写与订阅顺序" {
  let s : Store[Int] = Store::new(1)
  let seen : Array[Int] = []
  s.subscribe(fn(v) { seen.push(v) })
  s.set(2)
  s.set(3)
  inspect(s.get(), content="3")
  inspect(seen.map(fn(v) { v.to_string() }).join(","), content="2,3")
}

///|
test "store update 派生 map 链式跟随" {
  let count : Store[Int] = Store::new(2)
  let doubled = count.map(fn(x) { x * 2 })
  let text = doubled.map(fn(x) { "n=\{x}" })
  count.update(fn(x) { x + 19 })
  inspect(count.get(), content="21")
  inspect(doubled.get(), content="42")
  inspect(text.get(), content="n=42")
}

///|
test "store 订阅者内再 set 安全(快照遍历)" {
  let a : Store[Int] = Store::new(0)
  let b : Store[Int] = Store::new(0)
  a.subscribe(fn(v) { b.set(v + 1) })
  a.set(10)
  inspect(b.get(), content="11")
}

///|
test "store 初始派生值在订阅前就绪" {
  let src : Store[String] = Store::new("x")
  let len = src.map(fn(s) { s.length() })
  inspect(len.get(), content="1")
}

///|
test "store subscribe_id/remove:按句柄精确退订,幂等" {
  let s : Store[Int] = Store::new(0)
  let seen : Array[String] = []
  let h1 = s.subscribe_id(fn(v) { seen.push("a\{v}") })
  let h2 = s.subscribe_id(fn(v) { seen.push("b\{v}") })
  s.set(1)
  inspect(seen.join(","), content="a1,b1")
  s.remove(h1)
  s.set(2)
  inspect(seen.join(","), content="a1,b1,b2")
  // 幂等:重复退订与未知句柄都安全,不影响其余订阅
  s.remove(h1)
  s.remove(999999)
  s.set(3)
  inspect(seen.join(","), content="a1,b1,b2,b3")
  s.remove(h2)
  s.set(4)
  inspect(seen.join(","), content="a1,b1,b2,b3")
}

///|
test "store signal().subscribe 句柄经 store.remove 退订" {
  let s : Store[Int] = Store::new(0)
  let seen : Array[Int] = []
  let h = s.signal().subscribe(fn(v) { seen.push(v) })
  s.set(1)
  s.remove(h)
  s.set(2)
  inspect(seen.map(fn(v) { v.to_string() }).join(","), content="1")
}

///|
test "Store 内建去重：T:Eq 相同值只存不发，异值照发；set_always 无条件发" {
  let s = Store::new(1)
  let mut hits = 0
  let mut last = -1
  let _ = s.subscribe_id(fn(v : Int) -> Unit {
    hits += 1
    last = v
  })
  s.set(1) // 同值：不通知，但值已在
  assert_eq(hits, 0)
  assert_eq(s.get(), 1)
  s.set(2) // 异值：通知一次
  assert_eq(hits, 1)
  assert_eq(last, 2)
  s.set(2) // 又同值：不通知
  assert_eq(hits, 1)
  s.set_always(2) // 逃生舱：相同值也重发
  assert_eq(hits, 2)
  // update 走 set 口径（结果值不同才发）
  s.update(fn(v : Int) -> Int { v })
  assert_eq(hits, 2)
  s.update(fn(v : Int) -> Int { v + 3 })
  assert_eq(hits, 3)
  assert_eq(s.get(), 5)
}
