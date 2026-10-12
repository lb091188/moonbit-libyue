// 最小按键+输入法探针：建窗 → 泵消息 → 打印原始事件与 IME 的 preedit/commit。
// 配 PowerShell 的 AppActivate+SendKeys 做 Windows 键盘/输入法通路回证。
// 跑法：moon run experiment/key_probe（20 秒后自退）

fn main {
  if !@win.init_backend() {
    println("KEYPROBE SKIP (无显示服务)")
    return
  }
  let w = match @win.Window::new(420, 160, "KEYPROBE 窗口") {
    Some(w) => w
    None => {
      println("KEYPROBE FAIL (建窗失败)")
      return
    }
  }
  w.show()
  w.request_focus()
  // 报一个插入符位置（IME 组合/候选窗按它定位）
  w.set_im_cursor(20, 40, 2, 18)
  println("KEYPROBE READY")
  let t0 = @win.now_ms()
  while @win.now_ms() - t0 < 20000L {
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
    // IME 的 preedit（组合串）与 commit（提交串）：非空就报
    let pd = w.preedit()
    if pd.text.length() > 0 || pd.active {
      println("KEYPROBE preedit=[\{pd.text}] caret=\{pd.caret} active=\{pd.active}")
    }
    match w.take_commit() {
      Some(s) => println("KEYPROBE commit=[\{s}]")
      None => ()
    }
  }
  w.close()
  println("KEYPROBE DONE")
}
