// W6 探针：IME 纯通道的 API 通路回证（真实组合串需要注入键入，归 W7）。
// 建窗 → 报插入符矩形 → reset → 读 commit/preedit（应为空）→ 泵消息 → 干净退出。
// 跑法：moon run experiment/ime_win_probe

fn name_of(c : String?) -> String {
  match c {
    Some(s) => s
    None => "none"
  }
}

fn main {
  if !@win.init_backend() {
    println("IMEWIN SKIP (无显示服务)")
    return
  }
  let w = match @win.Window::new(240, 120, "ime 探针") {
    Some(w) => w
    None => {
      println("IMEWIN FAIL (建窗失败)")
      return
    }
  }
  w.show()
  w.request_focus()
  // 插入符矩形（客户区坐标）：真实使用里由焦点控件的 caret 每动一次报一遍
  w.set_im_cursor(10, 20, 2, 18)
  w.im_reset()
  let p0 = w.preedit()
  println(
    "IMEWIN-INIT commit=\{name_of(w.take_commit())} preedit_len=\{p0.text.length()} preedit_active=\{p0.active} caret=\{p0.caret}",
  )
  // 泵几轮消息：IME 的 WM_IME_* 都会在泵里过一遍 WndProc
  for _ in 0..<30 {
    let _ = @win.pump()
  }
  w.set_im_cursor(12, 20, 2, 18)
  w.im_reset()
  println("IMEWIN-ROUND2 commit=\{name_of(w.take_commit())}")
  w.close()
  println("IMEWIN-DONE ok")
}
