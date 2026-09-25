// 内嵌浏览器（WebView）。

///|
/// 创建浏览器视图。
pub fn Browser::new() -> Browser {
  { view: ffi_browser_new(), }
}

///|
/// 浏览器选项（对照 Browser::Options；webview2_* 为 Windows 专属）。
pub(all) struct BrowserOptions {
  devtools : Bool
  context_menu : Bool
  /// Linux/macOS：允许 file:// 页面访问其他 file:// 资源
  allow_file_access_from_files : Bool
  /// Linux：硬件加速（默认开）
  hardware_acceleration : Bool
}

///|
/// 默认选项（devtools/右键菜单关，硬件加速开）。
pub fn BrowserOptions::new() -> BrowserOptions {
  {
    devtools: false,
    context_menu: false,
    allow_file_access_from_files: false,
    hardware_acceleration: true,
  }
}

///|
/// 按选项创建浏览器。
pub fn Browser::new_with_options(options : BrowserOptions) -> Browser {
  {
    view: ffi_browser_new_ex(
      if options.devtools {
        1
      } else {
        0
      },
      if options.context_menu {
        1
      } else {
        0
      },
      if options.allow_file_access_from_files {
        1
      } else {
        0
      },
      if options.hardware_acceleration {
        1
      } else {
        0
      },
    ),
  }
}

///|
/// Cookie（对照 nu::Cookie）。
pub(all) struct Cookie {
  name : String
  value : String
  domain : String
  path : String
  http_only : Bool
  secure : Bool
}

///|
/// 查询指定 URL 的 Cookie（异步回调，字段经 shim 扁平文本编码）。
pub fn Browser::get_cookies_for_url(
  self : Browser,
  url : String,
  callback : (Array[Cookie]) -> Unit,
) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(flat) {
    let cookies : Array[Cookie] = []
    let text = from_utf8_bytes(flat)
    for line in text.split("\n").collect() {
      if line.length() == 0 {
        continue
      }
      let f = line.split("\u{1f}").collect()
      if f.length() >= 6 {
        cookies.push({
          name: f[0].to_owned(),
          value: f[1].to_owned(),
          domain: f[2].to_owned(),
          path: f[3].to_owned(),
          http_only: f[4].to_owned() == "1",
          secure: f[5].to_owned() == "1",
        })
      }
    }
    callback(cookies)
  }
  keep_alive_bytes(wrapped)
  ffi_browser_get_cookies_for_url(
    self.view,
    utf8_bytes(url),
    fn(f, b) { f(b) },
    wrapped,
  )
}

///|
/// 加载 URL。
pub fn Browser::load_url(self : Browser, url : String) -> Unit {
  ffi_browser_load_url(self.view, utf8_bytes(url))
}

///|
/// 当前 URL。
pub fn Browser::get_url(self : Browser) -> String {
  from_utf8_bytes(ffi_browser_get_url(self.view))
}

///|
/// 重新加载。
pub fn Browser::reload(self : Browser) -> Unit {
  ffi_browser_reload(self.view)
}

///|
/// 后退。
pub fn Browser::go_back(self : Browser) -> Unit {
  ffi_browser_go_back(self.view)
}

///|
/// 前进。
pub fn Browser::go_forward(self : Browser) -> Unit {
  ffi_browser_go_forward(self.view)
}

///|
/// 能否后退。
pub fn Browser::can_go_back(self : Browser) -> Bool {
  ffi_browser_can_go_back(self.view) == 1
}

///|
/// 能否前进。
pub fn Browser::can_go_forward(self : Browser) -> Bool {
  ffi_browser_can_go_forward(self.view) == 1
}

///|
/// 是否正在加载。
pub fn Browser::is_loading(self : Browser) -> Bool {
  ffi_browser_is_loading(self.view) == 1
}

///|
/// 加载 HTML 片段（可指定 base URL）。
pub fn Browser::load_html(
  self : Browser,
  html : String,
  base_url? : String = "about:blank",
) -> Unit {
  ffi_browser_load_html(self.view, utf8_bytes(html), utf8_bytes(base_url))
}

///|
/// 设置 User-Agent。
pub fn Browser::set_user_agent(self : Browser, agent : String) -> Unit {
  ffi_browser_set_user_agent(self.view, utf8_bytes(agent))
}

///|
/// 执行 JavaScript（不取回结果；结果回传需异步链，后补）。
pub fn Browser::execute_javascript(self : Browser, code : String) -> Unit {
  ffi_browser_execute_javascript(self.view, utf8_bytes(code))
}

///|
/// 加载状态变化。
pub fn Browser::on_change_loading(
  self : Browser,
  callback : () -> Unit,
) -> Unit {
  keep_alive(callback)
  ffi_browser_on_change_loading(
    self.view,
    fn(f : () -> Unit) -> Unit { f() },
    callback,
  )
}

///|
/// 命令状态更新（后退/前进可用性等）。
pub fn Browser::on_update_command(
  self : Browser,
  callback : () -> Unit,
) -> Unit {
  keep_alive(callback)
  ffi_browser_on_update_command(
    self.view,
    fn(f : () -> Unit) -> Unit { f() },
    callback,
  )
}

///|
/// 页面标题更新。
pub fn Browser::on_update_title(
  self : Browser,
  callback : (String) -> Unit,
) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(title) { callback(from_utf8_bytes(title)) }
  keep_alive_bytes(wrapped)
  ffi_browser_on_update_title(
    self.view,
    fn(f : (Bytes) -> Unit, b : Bytes) -> Unit { f(b) },
    wrapped,
  )
}

///|
/// 导航提交（开始加载目标 URL）。
pub fn Browser::on_commit_navigation(
  self : Browser,
  callback : (String) -> Unit,
) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(url) { callback(from_utf8_bytes(url)) }
  keep_alive_bytes(wrapped)
  ffi_browser_on_commit_navigation(
    self.view,
    fn(f : (Bytes) -> Unit, b : Bytes) -> Unit { f(b) },
    wrapped,
  )
}

///|
/// 导航完成。
pub fn Browser::on_finish_navigation(
  self : Browser,
  callback : (String) -> Unit,
) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(url) { callback(from_utf8_bytes(url)) }
  keep_alive_bytes(wrapped)
  ffi_browser_on_finish_navigation(
    self.view,
    fn(f : (Bytes) -> Unit, b : Bytes) -> Unit { f(b) },
    wrapped,
  )
}

///|
/// 注册自定义协议：回调收完整 URL，返回 (mime_type, 内容) 或 None 表示拒绝。
/// 内部以 ProtocolStringJob 承载；FileJob/AsarJob 场景暂不支持。
pub fn Browser::register_protocol(
  scheme : String,
  handler : (String) -> (String, String)?,
) -> Unit {
  let reject : Bytes = Bytes::from_array([1, 0, 0, 0])
  let wrapped : (Bytes) -> Bytes = fn(url) {
    match handler(from_utf8_bytes(url)) {
      Some((mime, content)) => {
        let mb = utf8_bytes(mime)
        let cb = utf8_bytes(content)
        let buf = FixedArray::make(12 + mb.length() + cb.length(), b'\x00')
        buf[0] = 1
        let put_len = fn(off : Int, v : Int) -> Unit {
          buf[off] = (v & 255).to_byte()
          buf[off + 1] = ((v >> 8) & 255).to_byte()
          buf[off + 2] = ((v >> 16) & 255).to_byte()
          buf[off + 3] = ((v >> 24) & 255).to_byte()
        }
        put_len(4, mb.length())
        for j = 0; j < mb.length(); j = j + 1 {
          buf[8 + j] = mb[j]
        }
        put_len(8 + mb.length(), cb.length())
        for j = 0; j < cb.length(); j = j + 1 {
          buf[12 + mb.length() + j] = cb[j]
        }
        Bytes::from_array(buf)
      }
      None => reject
    }
  }
  keep_alive_bytes(fn(b : Bytes) { ignore(wrapped(b)) })
  ffi_browser_register_protocol(utf8_bytes(scheme), fn(f, b) { f(b) }, wrapped)
}

///|
/// 注销自定义协议。
pub fn Browser::unregister_protocol(scheme : String) -> Unit {
  ffi_browser_unregister_protocol(utf8_bytes(scheme))
}
