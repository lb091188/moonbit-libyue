// effect / watch 回归：依赖自动收集、变化重跑、手工退订幂等、回收袋整代退订。

///|
test "effect：读谁就盯谁，set 谁重跑谁" {
  let a = Store::new(1)
  let b = Store::new(10)
  let mut hits = 0
  let mut seen_ab = (0, 0)
  let off = effect(fn() -> Unit {
    hits += 1
    seen_ab = (a.get(), b.get())
  })
  // 建立即跑一遍，依赖两个 store
  assert_eq(hits, 1)
  assert_eq(seen_ab, (1, 10))
  a.set(2)
  assert_eq(hits, 2)
  assert_eq(seen_ab, (2, 10))
  b.set(20)
  assert_eq(hits, 3)
  // 同值 set 经 Store 内建去重不唤醒
  a.set(2)
  assert_eq(hits, 3)
  off()
  a.set(3)
  assert_eq(hits, 3)
  // 幂等
  off()
}

///|
test "effect：重跑时依赖重收集——闭包换读的信号，旧信号不再触发行" {
  let flag = Store::new(false)
  let x = Store::new(1)
  let y = Store::new(100)
  let mut hits = 0
  let _off = effect(fn() -> Unit {
    hits += 1
    if flag.get() {
      let _ = y.get()
    } else {
      let _ = x.get()
    }
  })
  assert_eq(hits, 1)
  x.set(2) // 第一遍读的是 x
  assert_eq(hits, 2)
  flag.set(true) // 重跑后改读 y
  assert_eq(hits, 3)
  x.set(3) // x 已不在依赖里
  assert_eq(hits, 3)
  y.set(4) // y 在依赖里
  assert_eq(hits, 4)
}

///|
test "watch：初值不发，变化给 (新, 旧)；immediate 补发一次" {
  let s = Store::new("甲")
  let got : Array[(String, String)] = []
  let off = watch(s.signal(), fn(v : String, old : String) -> Unit {
    let _ = got.push((v, old))
  })
  assert_eq(got.length(), 0)
  s.set("乙")
  s.set("丙")
  assert_eq(got.length(), 2)
  assert_eq(got[0], ("乙", "甲"))
  assert_eq(got[1], ("丙", "乙"))
  off()
  s.set("丁")
  assert_eq(got.length(), 2)

  let mut fired = 0
  let off2 = watch(s.signal(), fn(_v : String, _o : String) -> Unit { fired += 1 }, immediate=true)
  assert_eq(fired, 1)
  s.set("戊")
  assert_eq(fired, 2)
  off2()
}

///|
test "watch_store：Store 形态与回收袋整代退订" {
  let n = Store::new(0)
  sub_bag_begin()
  let mut hits = 0
  let _off = watch_store(n, fn(_v : Int, _o : Int) -> Unit { hits += 1 })
  let offs = sub_bag_end()
  n.set(1)
  assert_eq(hits, 1)
  sub_bag_discard(offs)
  n.set(2)
  assert_eq(hits, 1)
}
