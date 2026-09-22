// 打开外部：URL 与文件管理器选中，单入口 + 单错误枚举。
// Linux:xdg-open(glib spawn 直传 argv 不经 shell)+ FileManager1.ShowItems
// (服务不在线或调用失败回退打开父目录);Windows:ShellExecuteW 与
// explorer /select。Ok 只表示「已交给系统」,系统侧能否打开由平台负责。

///|
/// 打开 URL 交给系统默认处理(http/https/mailto 等一律透传,不做校验)。
pub fn open_url(url : String) -> Result[Unit, OpenUrlError] {
  match platform() {
    "linux" =>
      match @traybus.spawn_detached("xdg-open", url) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
    "windows" => {
      let ok = Ref(0)
      let _ = ffi_open_url(utf8_bytes(url), ok)
      if ok.val == 1 {
        Ok(())
      } else {
        Err(SpawnFailed)
      }
    }
    _ => Err(Unsupported)
  }
}

///|
/// 在文件管理器中打开并选中路径(相对路径按工作目录解析)。Linux 的
/// FileManager1 不在线或调用失败时,回退打开父目录(选中态丢失)。
pub fn reveal_in_file_manager(
  path : String,
) -> Result[Unit, FileManagerError] {
  match platform() {
    "linux" => {
      let abs = if path.has_prefix("/") {
        path
      } else {
        @traybus.current_dir() + "/" + path
      }
      if @traybus.filemanager_available() {
        match @traybus.show_items([@traybus.file_uri(abs)], "") {
          Ok(_) => return Ok(())
          // 服务中途失联等:落回退
          Err(_) => ()
        }
      }
      match @traybus.spawn_detached("xdg-open", parent_dir(abs)) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
    }
    "windows" => {
      let ok = Ref(0)
      let _ = ffi_win_reveal_file(utf8_bytes(path), ok)
      if ok.val == 1 {
        Ok(())
      } else {
        Err(SpawnFailed)
      }
    }
    _ => Err(Unsupported)
  }
}

///|
/// 父目录:"/a/b/c" → "/a/b";"/c" → "/";无斜杠回 "."。
fn parent_dir(path : String) -> String {
  if path.length() == 0 {
    return "."
  }
  let mut i = path.length() - 1
  while i > 0 {
    if path.unsafe_get(i).to_int() == 47 {
      // '/'
      return if i == 0 { "/" } else { path[0:i].to_owned() }
    }
    i -= 1
  }
  if path.unsafe_get(0).to_int() == 47 {
    return "/"
  }
  "."
}
