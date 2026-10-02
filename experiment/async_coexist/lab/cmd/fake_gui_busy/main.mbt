// 实验 2b:poll 内干重活 → async 定时器漂移(官方文档"poll 不应做重活"的实证)
///|
extern "C" fn fgl_init() -> Int = "fgl_init"

///|
extern "C" fn fgl_destroy() -> Unit = "fgl_destroy"

///|
extern "C" fn fgl_wait(timeout~ : Int) -> Int = "fgl_wait"

///|
extern "C" fn fgl_drain() -> Int = "fgl_drain"

///|
extern "C" fn fgl_busy(ms : Int) -> Unit = "fgl_busy"

///|
let t0 : Int64 = @async.now()

///|
fn stamp() -> String { "+\{@async.now() - t0}ms" }

///|
struct BusyGui {}

///|
using @external_loop_integration {trait ExternalEventLoop}

///|
extern "C" fn fgl_wakeup_dummy() -> Unit = "fgl_wakeup"

///|
pub impl ExternalEventLoop for BusyGui with fn get_wakeup_callback_for_foreign_thread(
  _self,
) {
  () => fgl_wakeup_dummy()
}

///|
pub impl ExternalEventLoop for BusyGui with fn poll(_self : BusyGui, timeout? : Int) {
  let r = fgl_wait(timeout=timeout.unwrap_or(-1))
  guard r >= 0 else {
    abort("fgl_wait failed")
  }
  // 每轮 poll 假装处理 GUI 事件耗时 200ms(模拟重活:大布局/同步 IO/同步脚本)
  if fgl_drain() > 0 || true {
    fgl_busy(200)
  }
}

///|
pub impl ExternalEventLoop for BusyGui with fn terminate(_self : BusyGui) {
  fgl_destroy()
}

///|
async fn main {
  guard fgl_init() >= 0 else {
    abort("fgl_init failed")
  }
  @async.set_external_event_loop(BusyGui::{})
  @async.with_task_group(root => {
    for i in 1..=5 {
      root.spawn_bg() <| () => {
        @async.sleep(100 * i)
        println("[async] sleep(\{100 * i}) fired at \{stamp()} (expect +\{100 * i}ms)")
      }
    }
    @async.sleep(800)
  })
}
