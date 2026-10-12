// 最小按键探针：建窗 → 泵消息 → 打印收到的原始事件（键码/修饰），配
// PowerShell 的 SendKeys/AppActivate 做 Windows 键盘通路回证。
// 跑法：moon run experiment/key_probe（12 秒后自退）

fn main {
  if !@win.init_backend() {
    println("KEYPROBE SKIP (无显示服务)")
    return
  }
  let w = match @win.Window::new(360, 160, "KEYPROBE 窗口") {
    Some(w) => w
    None => {
      println("KEYPROBE FAIL (建窗失败)")
      return
    }
  }
  w.show()
  w.request_focus()
  println("KEYPROBE READY")
  let t0 = @win.now_ms()
  while @win.now_ms() - t0 < 12000L {
    let _ = @win.wait(50)
    let mut keep = true
    while keep {
      match w.poll_event() {
        @win.NoEvent => keep = false
        @win.Input => {
          match w.take_input() {
            Some(ev) =>
              println(
                "KEYPROBE ev code=\{ev.code} keysym=\{ev.keysym} mods=\{ev.mods}",
              )
            None => ()
          }
        }
        _ => ()
      }
    }
  }
  w.close()
  println("KEYPROBE DONE")
}
