// 批 A 多窗宿主的 Windows 侧探针（AGENTS 规则 6：助手侧只做「进程存活 + 退出
// 行为 + 读数行」这类冒烟，两窗互相遮挡/拖动的观感留使用者复验）。
//
// 两件事，各自对应一处平台相关的坑：
//   ① **窗口槽复用**——建-拆 40 轮（超过桩里 WM_MAX_WINDOWS=32 的上限）仍建得出。
//      批 A 给 GTK 分支修掉了「只递增 wm_next_id，附窗反复开合吃光槽位、
//      open_window 静默返回 None」，`win/stub.c` 的 _WIN32 分支当时没同步，
//      本探针守的就是那条同步。建窗不 show，于是探针期间桌面不闪窗。
//   ② **两窗并存**——主窗 + 两轮附窗共用同一个循环与泵：新窗建好即当前窗、
//      关掉附窗不停宿主、计数与窗口数逐轮打印。注册表逻辑本身是纯 MoonBit，
//      无头侧由 `core/host_wbtest.mbt` 覆盖；这里验的是「真有两个 HWND 时
//      同一套派发还成不成立」。
//
// 无显示服务（如无 X11 的环境）打印 SKIP 后正常返回。
//
// 跑法：moon run experiment/multiwin_probe

///|
/// 建-拆若干轮窗口槽，返回（成功建出的轮数, 建不出的轮数）。
fn slot_reuse_rounds(rounds : Int) -> (Int, Int) {
  let mut opened = 0
  let mut failed = 0
  for _ in 0..<rounds {
    match @win.Window::new(64, 32, "multiwin-slot") {
      Some(w) => {
        opened = opened + 1
        w.close()
      }
      None => failed = failed + 1
    }
  }
  (opened, failed)
}

fn main {
  if !@win.init_backend() {
    println("MULTIWIN SKIP (无显示服务)")
    return
  }
  // 40 > 32：槽位若只递增不复用，第 32 轮起就建不出
  let (opened, failed) = slot_reuse_rounds(40)
  println("MULTIWIN-SLOT rounds=40 opened=\{opened} failed=\{failed}")

  let host = match @widget.App::new(280, 140, "multiwin 主窗") {
    Some(a) => a
    None => {
      println("MULTIWIN FAIL (主窗建不出)")
      return
    }
  }
  host.mount([])
  let opens = Ref(0)
  let closes = Ref(0)
  let main_wid = host.wid()
  // 一轮：开附窗 → 挂空树 → 60ms 后关掉它（关窗走的是宿主同一顺序：先停派发
  // 再拆对象），逐轮打印当前窗与在窗数
  let open_round = fn(round : Int) -> Unit {
    match host.open_window(220, 120, "multiwin 附窗") {
      Some(sub) => {
        sub.mount([])
        opens.val = opens.val + 1
        let active_is_sub = match host.active_window() {
          Some(a) => a.wid() == sub.wid()
          None => false
        }
        println(
          "MULTIWIN-OPEN r=\{round} sub_wid=\{sub.wid()} primary=\{sub.is_primary()} active_is_sub=\{active_is_sub} count=\{host.window_count()}",
        )
        let _ = host.timer(60, fn() {
          let before = host.window_count()
          sub.close_window()
          closes.val = closes.val + 1
          println(
            "MULTIWIN-CLOSE r=\{round} before=\{before} after=\{host.window_count()} main_running=\{host.is_running()}",
          )
        })
      }
      None => println("MULTIWIN FAIL 第 \{round} 轮附窗建不出")
    }
  }
  let _ = host.timer(60, fn() { open_round(1) })
  let _ = host.timer(240, fn() { open_round(2) })
  let _ = host.timer(420, fn() {
    println(
      "MULTIWIN-HOST opens=\{opens.val} closes=\{closes.val} count=\{host.window_count()} main_wid=\{main_wid} running=\{host.is_running()}",
    )
    host.quit()
  })
  host.run()
  host.shutdown()
  // 退出读数：opened 应为 40、failed 0、opens=closes=2（两窗并存）
  println(
    "MULTIWIN-DONE slot_opened=\{opened} slot_failed=\{failed} opens=\{opens.val} closes=\{closes.val}",
  )
}
