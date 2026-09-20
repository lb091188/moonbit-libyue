// signals.mbt 单测:源信号订阅、computed 自动依赖收集、批处理、
// Store 互转。语义对照 store_test.mbt 的既有约定。

///|
test "Signal 源:get/set/update/subscribe" {
  let s : Signal[Int] = Signal::new(1)
  let seen : Array[Int] = []
  s.subscribe(fn(v) { seen.push(v) })
  inspect(seen.length(), content="0") // 注册不回调
  s.set(2)
  debug_inspect(seen, content="[2]")
  s.update(fn(n) { n * 10 })
  debug_inspect(seen, content="[2, 20]")
  inspect(s.get(), content="20")
}

///|
test "computed:依赖自动收集,依赖变自动失效" {
  let a = Signal::new(1)
  let b = Signal::new(2)
  let mut runs = 0
  let c = Signal::computed(fn() {
    runs += 1
    a.get() + b.get()
  })
  inspect(c.get(), content="3")
  inspect(runs, content="2") // 创建时预热求值,首 get 命中缓存
  a.set(10)
  inspect(runs, content="2") // 惰性:set 只标脏
  inspect(c.get(), content="12")
  inspect(runs, content="3")
  inspect(c.get(), content="12")
  inspect(runs, content="3") // 无变化不再重算
  b.set(3)
  inspect(c.get(), content="13")
  inspect(runs, content="4")
}

///|
test "computed:订阅者收到的值已重算" {
  let a = Signal::new("x")
  let c = Signal::computed(fn() { "v=\{a.get()}" })
  let seen : Array[String] = []
  c.subscribe(fn(v) { seen.push(v) })
  a.set("y")
  inspect(seen.map(fn(v) { v }).join(","), content="v=y") // 源未 get 前变化,通知链不断
}

///|
test "computed:条件分支只依赖实际读到的信号" {
  let flag = Signal::new(true)
  let x = Signal::new(1)
  let y = Signal::new(100)
  let c = Signal::computed(fn() { if flag.get() { x.get() } else { y.get() } })
  inspect(c.get(), content="1")
  y.set(200)
  inspect(c.get(), content="1") // y 不是当前依赖
  flag.set(false)
  inspect(c.get(), content="200") // 依赖切换为 y
  x.set(2)
  inspect(c.get(), content="200") // x 已解除依赖
}

///|
test "computed:钻石依赖收敛到正确终值" {
  let a = Signal::new(1)
  let b = Signal::computed(fn() { a.get() * 2 })
  let c = Signal::computed(fn() { a.get() + 10 })
  let d = Signal::computed(fn() { b.get() + c.get() })
  inspect(d.get(), content="13") // 1*2 + (1+10)
  a.set(2)
  inspect(d.get(), content="16") // 2*2 + (2+10)
}

///|
test "batch:多次 set 合并为一次通知" {
  let a = Signal::new(0)
  let mut calls = 0
  a.subscribe(fn(_v) { calls += 1 })
  batch(fn() {
    a.set(1)
    a.set(2)
    a.set(3)
  })
  inspect(calls, content="1")
  inspect(a.get(), content="3")
  // 嵌套 batch:最外层结束才冲刷
  calls = 0
  let mut inner_flushed = true
  batch(fn() {
    batch(fn() { a.set(4) })
    inner_flushed = calls == 0
    a.set(5)
  })
  inspect(inner_flushed, content="true")
  inspect(calls, content="1")
  inspect(a.get(), content="5")
}

///|
test "map:派生只读信号" {
  let a = Signal::new(3)
  let b = a.map(fn(n) { n * 2 })
  inspect(b.get(), content="6")
  a.set(5)
  inspect(b.get(), content="10")
}

///|
test "Store 与 Signal 互转:共享同一状态" {
  let s : Store[Int] = Store::new(7)
  let sig = s.signal()
  sig.set(9)
  inspect(s.get(), content="9")
  let back = sig.store()
  s.set(11)
  inspect(back.get(), content="11")
  // 订阅互通
  let seen : Array[Int] = []
  back.subscribe(fn(v) { seen.push(v) })
  s.set(12)
  debug_inspect(seen, content="[12]")
}

///|
test "Store 语义回归:get/set/update/subscribe/map 与旧实现一致" {
  let s : Store[Int] = Store::new(1)
  let seen : Array[Int] = []
  s.subscribe(fn(v) { seen.push(v) })
  s.set(2)
  s.update(fn(n) { n + 1 })
  debug_inspect(seen, content="[2, 3]")
  let derived = s.map(fn(n) { n * 100 })
  inspect(derived.get(), content="300")
  s.set(4)
  inspect(derived.get(), content="400") // map 派生自动跟随
}

///|
test "信号驱动 Store 参数组件形态:computed 经 store() 只读接入" {
  let count = Signal::new(2)
  let label = count.map(fn(n) { "共 \{n} 项" }).store()
  inspect(label.get(), content="共 2 项")
  count.set(5)
  inspect(label.get(), content="共 5 项")
}
