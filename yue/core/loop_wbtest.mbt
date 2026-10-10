// 循环调度器的时序回归：所有断言只依赖调用次序，不读真实时钟。

///|
test "post_task 按提交次序同拍执行" {
  let log : Array[String] = []
  let l = Loop::new()
  l.post_task(fn() { log.push("a") })
  l.post_task(fn() { log.push("b") })
  assert_eq(l.advance(1000L), 2)
  assert_eq(log.join(","), "a,b")
  assert_eq(l.pending(), 0)
}

///|
test "回调里排的任务留到下一拍" {
  let mut log : Array[String] = []
  let l = Loop::new()
  l.post_task(fn() { log.push("outer") })
  // 内层任务在 advance 内部排入，本轮不得执行（推迟一拍的语义）
  l.post_task(fn() { log.push("mid") })
  let l2 = l
  let _ = l2.advance(0L)
  assert_eq(log.join(","), "outer,mid")
  log = []
  let mut nested_ran = 0
  l2.post_task(fn() {
    nested_ran = nested_ran + 1
    l2.post_task(fn() { log.push("nested-next-tick") })
  })
  assert_eq(l2.advance(10L), 1)
  assert_eq(nested_ran, 1)
  assert_eq(log.length(), 0)
  assert_eq(l2.advance(20L), 1)
  assert_eq(log.join(","), "nested-next-tick")
}

///|
test "定时器到期次序与延时相同者按提交次序" {
  let log : Array[String] = []
  let l = Loop::new()
  let _ = l.timer(30, fn() { log.push("t30") })
  let _ = l.timer(10, fn() { log.push("t10") })
  let _ = l.timer(10, fn() { log.push("t10b") })
  // 立即项先于任何定时器
  l.post_task(fn() { log.push("now") })
  assert_eq(l.advance(0L), 1)
  assert_eq(l.advance(15L), 2)
  assert_eq(log.join(","), "now,t10,t10b")
  assert_eq(l.advance(40L), 1)
  assert_eq(log.join(","), "now,t10,t10b,t30")
}

///|
test "负延时按 0 处理" {
  let l = Loop::new()
  let mut fired = false
  let _ = l.timer(-50, fn() { fired = true })
  assert_eq(l.advance(500L), 1)
  assert_eq(fired, true)
}

///|
test "cancel 只作用于未跑项" {
  let l = Loop::new()
  let mut hits = 0
  let id = l.timer(20, fn() { hits = hits + 1 })
  assert_eq(l.cancel(id), true)
  assert_eq(l.pending(), 0)
  assert_eq(l.advance(100L), 0)
  assert_eq(hits, 0)
  // 上一轮 advance 把 last_now 推到 100，delay 0 意为「下一拍」；时钟不能倒退着推
  let id2 = l.timer(0, fn() { hits = hits + 1 })
  assert_eq(l.advance(100L), 1)
  assert_eq(l.cancel(id2), false)
  assert_eq(hits, 1)
}

///|
test "wait_budget 三态" {
  let l = Loop::new()
  assert_eq(l.wait_budget(0L), None)
  let _ = l.timer(500, fn() {  })
  assert_eq(l.wait_budget(0L), Some(500))
  assert_eq(l.wait_budget(300L), Some(200))
  assert_eq(l.wait_budget(900L), Some(0))
  l.post_task(fn() {  })
  assert_eq(l.wait_budget(1000L), Some(0))
}

///|
test "wait_budget 钳上限不外抛超大值" {
  let l = Loop::new()
  let _ = l.timer(99999999, fn() {  })
  assert_eq(l.wait_budget(0L), Some(1000000))
}

///|
test "quit 后停止派发但保留待办" {
  let l = Loop::new()
  let mut fired = 0
  let _ = l.timer(1, fn() { fired = fired + 1 })
  l.quit()
  assert_eq(l.is_running(), false)
  assert_eq(l.advance(10L), 0)
  assert_eq(fired, 0)
  assert_eq(l.pending(), 1)
  // quit 后排的任务同样不执行
  l.post_task(fn() { fired = fired + 1 })
  assert_eq(l.advance(20L), 0)
  assert_eq(fired, 0)
}

test "时基未建立时相对延时按 0 起算，start 之后按平台时钟起算" {
  // 未 start：基准取 0，delay 相对 0，advance 到该刻度即到期（明确化的旧行为）
  let l = Loop::new()
  assert_eq(l.started(), false)
  let mut early = 0
  let _ = l.timer(100, fn() { early = early + 1 })
  assert_eq(l.advance(99L), 0)
  assert_eq(l.advance(120L), 1)
  assert_eq(early, 1)
  // start 之后：delay 相对平台时钟（CLOCK_MONOTONIC 是开机起算的大数，
  // 若仍按 0 起算会立刻到期——实测骨架动画只跑一拍就是这么来的）
  let l2 = Loop::new()
  l2.start(20000000L)
  assert_eq(l2.started(), true)
  let mut late = 0
  let _ = l2.timer(100, fn() { late = late + 1 })
  assert_eq(l2.advance(20000000L), 0)
  assert_eq(l2.advance(20000099L), 0)
  assert_eq(l2.advance(20000100L), 1)
  assert_eq(late, 1)
}
