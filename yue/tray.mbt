// 系统托盘：平台差异收敛的实现。
//
// 后端选择（按优先级）：
// - Linux：优先纯 MoonBit 实现的 StatusNotifierItem（yue/traybus 包，
//   会话总线直连面板，不依赖 AppIndicator 运行库）；watcher 不在线时
//   回退 nativeui 的 AppIndicator；两者皆无 → 结构化报错。
//   桌面表现：XFCE/KDE/MATE/Cinnamon/Budgie/LXQt 及装了 AppIndicator
//   扩展的 GNOME 可用；纯净 GNOME 无托盘协议，不可用。
// - Windows / macOS：nativeui 原生托盘。
// 消费方代码在三大平台完全一致，缺失后端拿到结构化错误而非静默失效。

///|
/// 托盘后端。
pub enum TrayBackend {
  Native(NativeTray)
  Sni(@traybus.Item)
}

///|
/// 托盘句柄。
pub struct Tray {
  backend : TrayBackend
}

///|
/// 当前桌面环境名（如 "XFCE"、"GNOME"；无法识别返回 "unknown"）。
pub fn desktop_environment() -> String {
  @traybus.desktop_name()
}

///|
/// 托盘后端是否可用。消费方可据此决定是否展示托盘相关功能。
pub fn Tray::is_supported() -> Bool {
  @traybus.sni_available() || ffi_tray_supported()
}

///|
/// 用图片文件创建托盘图标。失败返回结构化错误：
/// 后端缺失（Linux 无 SNI watcher 且无 AppIndicator）或图标读取失败。
/// Linux SNI 后端的图标由程序内置生成（位图直供面板）；
/// PNG 像素解码尚未内置，主题图标名可用 set_icon_name 指定。
pub fn Tray::new(icon_path : String) -> Result[Tray, TrayError] {
  if @traybus.sni_available() {
    match @traybus.Item::create(basename_no_ext(icon_path), icon_path) {
      Ok(item) => return Ok({ backend: Sni(item) })
      Err(_) => () // watcher 不在线等，继续回退
    }
  }
  if ffi_tray_supported() {
    let ok = Ref(0)
    let tray = ffi_tray_new(utf8_bytes(icon_path), ok)
    if ok.val == 1 {
      return Ok({ backend: Native(tray) })
    }
    return Err(IconLoadFailed)
  }
  Err(Unsupported)
}

///|
/// 从路径取不含扩展名的文件名，作托盘 Id。
fn basename_no_ext(path : String) -> String {
  let name = match path.rev_find("/") {
    Some(i) => path[i + 1:].to_owned()
    None => path
  }
  match name.rev_find(".") {
    Some(i) => name[0:i].to_owned()
    None => name
  }
}

///|
/// 设置托盘标题（部分面板不渲染，属平台表现差异，接口不变）。
pub fn Tray::set_title(self : Tray, title : String) -> Unit {
  match self.backend {
    Native(t) => ffi_tray_set_title(t, utf8_bytes(title))
    Sni(item) => item.set_title(title)
  }
}

///|
/// 更换托盘图标（图片文件）。
/// Linux SNI 后端暂不支持 PNG 像素解码，此调用为空操作（保持现有图标）。
pub fn Tray::set_icon(self : Tray, icon_path : String) -> Unit {
  match self.backend {
    Native(t) => {
      let image = ffi_image_new_from_file(utf8_bytes(icon_path))
      ffi_tray_set_image(t, image)
    }
    Sni(_) => ()
  }
}

///|
/// 按图标主题名更换图标（如 "utilities-terminal"），跟随系统主题。
/// 仅 Linux SNI 后端支持；其余平台为空操作。
pub fn Tray::set_icon_name(self : Tray, name : String) -> Unit {
  match self.backend {
    Sni(item) => item.set_icon_name(name)
    Native(_) => ()
  }
}

///|
/// 设置悬浮提示（鼠标悬停图标时显示）。
/// 仅 Linux SNI 后端支持；其余平台为空操作。
pub fn Tray::set_tooltip(self : Tray, title : String, body : String) -> Unit {
  match self.backend {
    Sni(item) => item.set_tooltip(title, body)
    Native(_) => ()
  }
}

///|
/// 注册托盘图标激活回调（Linux 为面板 Activate；Windows/macOS 为图标点击）。
pub fn Tray::on_click(self : Tray, callback : () -> Unit) -> Unit {
  match self.backend {
    Native(t) => {
      keep_alive(callback)
      ffi_tray_on_click(t, fn(f : (() -> Unit)) -> Unit { f() }, callback)
    }
    Sni(item) => {
      keep_alive(callback)
      item.set_click_handler(callback)
    }
  }
}

///|
/// 给托盘挂右键菜单（统一用 Menu 模型）。
/// Linux SNI 后端：遍历菜单构建 DBusMenu（一级项与分隔线；子菜单暂不支持）；
/// 点击菜单项经 MenuItem::Click 触发原回调。Windows/macOS：原生 SetMenu。
pub fn Tray::set_menu(self : Tray, menu : Menu) -> Unit {
  match self.backend {
    Native(t) => ffi_tray_set_menu(t, menu)
    Sni(item) => {
      // XFCE 等面板右键 → ContextMenu(x,y) → 应用自绘菜单（Qt 模式）
      item.set_context_menu_handler(fn(x, y) { menu.popup_at(x, y) })
      let count = menu.item_count()
      for i in 0..<count {
        match menu.item_at(i) {
          Some(h) => {
            let kind = ffi_menu_item_get_type(h)
            if kind == 3 {
              item.add_menu_separator()
            } else if kind == 0 || kind == 1 || kind == 2 {
              let buf = Bytes::make(256, 0)
              let n = ffi_menu_item_get_label(h, buf, 256)
              let label = if n < 0 { "" } else { from_utf8_bytes(buf[0:n].to_owned()) }
              let enabled = ffi_menu_item_is_enabled(h) == 1
              item.add_menu_entry(label, enabled, fn() { ffi_menu_item_click(h) })
            }
            // kind == 4 子菜单暂不支持，跳过
          }
          None => ()
        }
      }
    }
  }
}

///|
/// 移除托盘图标。之后对象不可再用。
pub fn Tray::remove(self : Tray) -> Unit {
  match self.backend {
    Native(t) => ffi_tray_remove(t)
    Sni(item) => item.unregister()
  }
}
