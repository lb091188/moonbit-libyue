///|
test "store 读写与订阅顺序" {
  let s : @yue.Store[Int] = @yue.Store::new(1)
  let seen : Array[Int] = []
  s.subscribe(fn(v) { seen.push(v) })
  s.set(2)
  s.set(3)
  inspect(s.get(), content="3")
  inspect(seen.map(fn(v) { v.to_string() }).join(","), content="2,3")
}

///|
test "store update 派生 map 链式跟随" {
  let count : @yue.Store[Int] = @yue.Store::new(2)
  let doubled = count.map(fn(x) { x * 2 })
  let text = doubled.map(fn(x) { "n=\{x}" })
  count.update(fn(x) { x + 19 })
  inspect(count.get(), content="21")
  inspect(doubled.get(), content="42")
  inspect(text.get(), content="n=42")
}

///|
test "store 订阅者内再 set 安全(快照遍历)" {
  let a : @yue.Store[Int] = @yue.Store::new(0)
  let b : @yue.Store[Int] = @yue.Store::new(0)
  a.subscribe(fn(v) { b.set(v + 1) })
  a.set(10)
  inspect(b.get(), content="11")
}

///|
test "store 初始派生值在订阅前就绪" {
  let src : @yue.Store[String] = @yue.Store::new("x")
  let len = src.map(fn(s) { s.length() })
  inspect(len.get(), content="1")
}
