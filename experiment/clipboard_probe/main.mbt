// 剪贴板**跨进程**探针：证明「本进程写进去的东西，别的程序读得到」。
//
// 为什么需要它：`moon test sys` 那条剪贴板回归是**同进程**写后读回，证明不了
// 外部可见性——X11 的 CLIPBOARD 选区由主人进程负责应答请求，主人一退出（且会话
// 里没有剪贴板管理器接管）外部就再也读不到。所以本探针写完不退出，保持存活
// 若干秒，期间由**另一个进程**读回。
//
// 跑法（两条一起看，第二条是外部读者）：
//   moon run experiment/clipboard_probe &
//   sleep 2 && python3 -c "import gi;gi.require_version('Gtk','3.0');\
//   from gi.repository import Gtk,Gdk;\
//   print(Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).wait_for_text())"
//   # 或直接在任意图形程序里 Ctrl+V
//
// 反向（外部写、本进程读）：先在任意程序里复制一段文字，再跑本探针，看
// `PROBE-OWN-READ` 是不是那段文字。
//
// 纯命令行进程（没调过 `@win.init_backend()`）会读到 `available=false` 并退回
// 命令线 xclip——那是正确降级，不是缺陷；本探针先初始化后端，与真实图形应用同形态。

///|
/// 保持存活的秒数（够外部起一条读回命令）。
fn hold() -> Unit {
  let _ = @sys.pr_run("sleep", ["6"], timeout_ms=9000)
}

///|
fn read_back(label : String) -> Unit {
  match @sys.clipboard_get_text() {
    Some(s) => println(label + "=[" + s + "]")
    None => println(label + "=(none)")
  }
}

///|
/// 与演示页「复制」按钮同形态的载荷：多行 + 中文 + 代码符号 + 引号与反斜杠。
/// 只用单行 ASCII 过一遍不算数。
fn payload() -> String {
  let head = "@ui.button(\"复制\", on_click=fn() {\n"
  let mid = "  // 中文注释 · “引号” 与反斜杠 \\\\ 与制表\t\n"
  let tail = "  println(100.0 / 3.0)\n})\n"
  head + mid + tail + "t=" + (@win.now_ms()).to_string()
}

fn main {
  println("backend=" + @win.init_backend().to_string())
  println("available=" + @sys.clipboard_available().to_string())
  let text = payload()
  println("set_ok=" + @sys.clipboard_set_text(text).to_string())
  read_back("PROBE-OWN-READ")
  hold()
  read_back("PROBE-AFTER-HOLD")
  println("PROBE done")
}
