// 系统剪贴板接线（W16）：默认**关**——测试里的 Ctrl+X/C 不该动使用者的
// 剪贴板，所以由应用在启动时显式打开（示例里 `@ui.use_system_clipboard(true)`
// 一行），此后新建的输入框/多行框才会装内核的剪贴板槽。探测不可用
// （Linux 没装 xclip 等）时自动保持内部剪贴板，属语义化降级。

///|
let g_sys_clipboard : Ref[Bool] = Ref(false)

///|
/// 打开/关闭「输入框的 Ctrl+C/X/V 接系统剪贴板」。只影响**此后新建**的
/// 输入框（已建好的保持原槽位，换槽留给需要显式重装的场景）。
pub fn use_system_clipboard(enable : Bool) -> Unit {
  g_sys_clipboard.val = enable
}

///|
/// 按开关与探测结果给内核装槽（input/textarea 构造时调；包内函数）。
fn attach_system_clipboard(ed : @input.Editor) -> Unit {
  if g_sys_clipboard.val && @sys.clipboard_available() {
    ed.set_clipboard(
      @sys.clipboard_get_text,
      fn(t) {
        let _ = @sys.clipboard_set_text(t)
      },
    )
  }
}
