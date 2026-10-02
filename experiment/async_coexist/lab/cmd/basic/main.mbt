// 实验 1:async fn main 基础验证 —— sleep/spawn_bg/pause 由谁驱动
///|
async fn main {
  let t0 = @async.now()
  println("main start")
  @async.with_task_group(root => {
    root.spawn_bg() <| () => {
      for i in 1..=5 {
        @async.sleep(100)
        println("tick \{i} at +\{@async.now() - t0}ms")
      }
    }
    @async.pause()
    println("main resumed at +\{@async.now() - t0}ms")
  })
  println("main end")
}
