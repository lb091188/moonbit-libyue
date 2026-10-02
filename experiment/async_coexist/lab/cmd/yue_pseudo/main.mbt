// 实验 3:yue 阻塞 run() 与 async 的"伪共存"验证(无外部循环集成时)
// 预期:run() 阻塞期间 async 调度器冻结(timer 不触发);yue 自己的
// set_timeout 走 GLib 照常;quit() 返回后 async 恢复补跑。
///|
let t0 : Int64 = @async.now()

///|
fn stamp() -> String { "+\{@async.now() - t0}ms" }

///|
async fn main {
  println("[async] main start \{stamp()}")
  guard @yue.initialize() else {
    abort("yue init failed")
  }
  // async 侧任务:想在 GUI 运行期间周期打点
  @async.with_task_group(root => {
    root.spawn_bg() <| () => {
      for i in 1..=6 {
        @async.sleep(200)
        println("[async] tick \{i} at \{stamp()}")
      }
    }
    // yue 侧定时器:GUI 循环内照常
    ignore(@yue.set_timeout(300, () => {
      println("[yue]  set_timeout fired at \{stamp()}")
    }))
    // 1.2s 后请求退出 GUI(经 MessageLoop::PostTask 抛回主循环)
    ignore(@yue.set_timeout(1200, () => {
      println("[yue]  quitting at \{stamp()}")
      @yue.quit()
    }))
    println("[async] entering yue.run() \{stamp()}")
    @yue.run() // 同步阻塞:async 调度器在此冻结
    println("[async] yue.run() returned \{stamp()}")
    // run() 返回后 async 恢复:冻结的 tick 会补跑
    @async.sleep(50)
  })
  println("[async] main end \{stamp()}")
}
