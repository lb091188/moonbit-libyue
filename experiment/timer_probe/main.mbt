// 定时器自排链探针：验证 `@shell.set_timeout` 的任务在真实宿主泵下会不会被
// `advance` 跑到（showcase 折线推点链同款机制，第一拍挂节点挂载回调，最小化
// 复现）。读数不写 stdout（进程被强杀时缓冲会吞掉），逐拍覆盖写
// C:/tmp/timerprobe.log：ARMED=挂载回调已跑并排上首拍；step i / ticks t /
// pending p 每步一行；DONE=有界循环正常结束。
// 跑法：moon run experiment/timer_probe

///|
fn dump(s : String) -> Unit {
  // 追加：强杀后留下完整时序而不是只剩最后一拍
  let old = match @sys.sys_read_text_file("C:/tmp/timerprobe.log") {
    Some(t) => t
    None => ""
  }
  let _ = @sys.sys_write_text_file("C:/tmp/timerprobe.log", old + s + "\n")
}

///|
fn main {
  let app_ref : Ref[@widget.App?] = Ref(None)
  let tick : Ref[() -> Unit] = Ref(fn() { () })
  let n : Ref[Int] = Ref(0)
  tick.val = fn() -> Unit {
    n.val = n.val + 1
    if n.val < 100 {
      let _ = @shell.set_timeout(200, (tick.val))
    }
  }
  let app = match @ui.mount_window(
    [
      @ui.col(
        [@ui.text("timer probe")],
        handle=fn(_w : @widget.Widget) -> Unit {
          // 与 showcase 折线段同口径：第一拍挂在挂载回调上
          (tick.val)()
          // 看门狗：3 秒后退窗。它若响，说明单次 set_timeout 是通的
          let _ = @shell.set_timeout(3000, fn() -> Unit {
            dump("WATCHDOG fired ticks=" + n.val.to_string())
            match app_ref.val {
              Some(a) => a.close_window()
              None => ()
            }
          })
          dump("ARMED pending=" + (@shell.host_loop().pending()).to_string())
        },
      ),
    ],
    title="timer-probe",
    width=300,
    height=200,
  ) {
    None => {
      dump("SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(a) => a
  }
  app_ref.val = Some(app)
  // 分辨实验：App::new 返回之后（钩子按契约必已装好）再排一个定时器
  let _ = @shell.set_timeout(400, fn() -> Unit { dump("POST-TIMER fired") })
  dump("POST-ARM pending=" + (@shell.host_loop().pending()).to_string())
  // 手动驱动：约 6 秒上限（每步 wait 受 wait_budget 钳 1s），必然正常退出
  let t0 = @win.now_ms()
  let mut steps = 0
  while app.is_running() && @win.now_ms() - t0 < 6000L {
    let _ = app.step()
    steps = steps + 1
    dump(
      "step=" + steps.to_string() + " ticks=" + n.val.to_string() +
      " pending=" + (@shell.host_loop().pending()).to_string() +
      " now=" + (@win.now_ms() - t0).to_string(),
    )
  }
  dump(
    "DONE steps=" + steps.to_string() + " ticks=" + n.val.to_string() +
    " elapsed=" + (@win.now_ms() - t0).to_string(),
  )
}
