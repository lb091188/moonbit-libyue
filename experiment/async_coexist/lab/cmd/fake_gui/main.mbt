// 实验 2:ExternalEventLoop 共存验证 —— async 当家,模拟 GUI 循环作 poll 回调
///|
extern "C" fn fgl_init() -> Int = "fgl_init"

///|
extern "C" fn fgl_destroy() -> Unit = "fgl_destroy"

///|
extern "C" fn fgl_wait(timeout~ : Int) -> Int = "fgl_wait"

///|
extern "C" fn fgl_drain() -> Int = "fgl_drain"

///|
extern "C" fn fgl_post_event(ms : Int) -> Unit = "fgl_post_event"

///|
let t0 : Int64 = @async.now()

///|
fn stamp() -> String { "+\{@async.now() - t0}ms" }

///|
struct FakeGui {
  mut gui_events : Int
}

///|
using @external_loop_integration {trait ExternalEventLoop}

// 唤醒回调:在 async 的 waiter 专用线程被调用,只准纯 C FFI
///|
pub impl ExternalEventLoop for FakeGui with fn get_wakeup_callback_for_foreign_thread(
  _self,
) {
  () => fgl_wakeup_dummy()
}

///|
extern "C" fn fgl_wakeup_dummy() -> Unit = "fgl_wakeup"

///|
pub impl ExternalEventLoop for FakeGui with fn poll(self : FakeGui, timeout? : Int) {
  // 一次 GUI 循环迭代:等待(至多 timeout)→ 处理本轮 GUI 事件
  let r = fgl_wait(timeout=timeout.unwrap_or(-1))
  guard r >= 0 else {
    abort("fgl_wait failed")
  }
  let n = fgl_drain()
  if n > 0 {
    self.gui_events = self.gui_events + 1
    println("[gui] event #\{self.gui_events} handled in poll at \{stamp()}")
  }
}

///|
pub impl ExternalEventLoop for FakeGui with fn terminate(_self : FakeGui) {
  println("[gui] terminate at \{stamp()}")
  fgl_destroy()
}

///|
async fn main {
  guard fgl_init() >= 0 else {
    abort("fgl_init failed")
  }
  // 关键接线:必须在任何实际 async 代码前把 GUI 循环交给 runtime
  @async.set_external_event_loop(FakeGui::{ gui_events: 0 })
  @async.with_task_group(root => {
    // a) async 定时器:poll 的 timeout 路径
    root.spawn_bg() <| () => {
      @async.sleep(300)
      println("[async] sleep(300) fired at \{stamp()}")
    }
    // b) waiter 线程事件:TCP 连接就绪必须唤醒阻塞中的 poll
    root.spawn_bg() <| () => {
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      let addr = server.addr
      root.spawn_bg() <| () => {
        @async.sleep(100)
        println("[async] connecting at \{stamp()}")
        let conn = @socket.Tcp::connect(addr)
        println("[async] connected (waiter woke poll) at \{stamp()}")
        conn.close()
      }
      let (c2, _) = server.accept()
      println("[async] server accepted at \{stamp()}")
      c2.close()
      server.close()
    }
    // c) GUI 事件源:外部线程投递,应在 poll 内被处理
    root.spawn_bg() <| () => { fgl_post_event(150) }
    root.spawn_bg() <| () => { fgl_post_event(500) }
    @async.sleep(600)
  })
  println("[async] main end at \{stamp()}")
}
