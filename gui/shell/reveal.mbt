// 「在文件管理器里显示」的跨层落点。命令线那一半住在 `@sys`（Linux 只能打开父
// 目录，选中态丢失）；freedesktop 桌面的「打开并选中」是会话总线上的
// `org.freedesktop.FileManager1.ShowItems`，住在 `@dbus`。`@dbus` 依赖 `@sys`，
// 两者只能在 core 会师——本文件就是那条会师线。

///|
/// 在文件管理器里打开并**选中**该路径（传目录也行：选中该目录本身）。
/// 相对路径按工作目录归一；路径不存在直接给 `Err(NotFound)`——系统侧在这条路
/// 上「默默成功」（explorer 会开别处、ShowItems 也可能照回成功），不判就是把
/// 打不开说成已交给系统。
/// 落点顺序：Linux 先试 FileManager1（Nautilus / Dolphin / Thunar 等提供），
/// 不在线或调用失败才退回 `@sys` 的命令行路径（打开父目录，选中态丢失）；
/// Windows 由 `@sys` 直调 `explorer /select`（分隔符统一成反斜杠才会选中）；
/// 其余平台给 `Unsupported`。
pub fn reveal_in_file_manager(
  path : String,
) -> Result[Unit, @sys.FileManagerError] {
  let cwd = @sys.current_dir()
  if path == "" || !@sys.sys_path_exists(@sys.launcher_abs_path(path, cwd)) {
    return Err(NotFound)
  }
  if @sys.sys_platform() == "linux" && @dbus.filemanager_available() {
    match @dbus.show_items([reveal_uri(path, cwd)], "") {
      Ok(_) => return Ok(())
      Err(_) => () // 总线在但这次没成：仍退回打开父目录，别什么都不做
    }
  }
  @sys.reveal_in_file_manager(path)
}

///|
/// 该路径的 `file://` URI（相对路径按 `cwd` 解析）。选中态成不成就看这一串：
/// 必须是绝对路径 + 百分号编码，给目录或给相对路径面板都只会退回开父目录。
pub fn reveal_uri(path : String, cwd : String) -> String {
  @dbus.file_uri(@sys.launcher_abs_path(path, cwd))
}
