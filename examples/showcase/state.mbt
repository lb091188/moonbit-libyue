// 跨页共享状态：响应式 Store（各页 bind_label 订阅显示）与 Ref（可变开关）。
// 全部是纯 MoonBit 对象，不触碰 GUI，顶层初始化安全。

///|
/// 主窗口句柄（mount_window 的 handle 写入；对话框 run_for_window、
/// 窗口操作按钮、浏览器标题联动都用它）。
let main_win : Ref[@yue.Window?] = Ref(None)

///|
/// 关闭拦截开关（系统页勾选）与最近一次拦截提示。
let close_veto : Ref[Bool] = Ref(false)
let veto_info : @yue.Store[String] = @yue.Store::new("（未开启拦截）")

///|
/// 托盘状态与点击计数（托盘页显示，setup_tray 更新）。
let tray_info : @yue.Store[String] = @yue.Store::new("（初始化中）")
let tray_clicks : @yue.Store[Int] = @yue.Store::new(0)
let tray_ref : Ref[@yue.Tray?] = Ref(None)

///|
/// 键盘 / 拖拽 / 菜单 / 快捷键的联动显示（事件页、菜单页订阅）。
let key_info : @yue.Store[String] = @yue.Store::new("（在窗口内按键显示到这里）")
let drag_info : @yue.Store[String] = @yue.Store::new("（把文件或文本拖进右侧色块）")
let menu_info : @yue.Store[String] = @yue.Store::new("（菜单事件显示到这里）")
let shortcut_info : @yue.Store[String] = @yue.Store::new("（快捷键状态显示到这里）")
