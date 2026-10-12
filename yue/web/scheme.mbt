// 本地内容通道（自定义协议）与导航失败的结构化解析。
//
// 两条口径（方案 §4.4/§4.8）：
// ① 协议**按 context 注册**——profile 挂 pane 级之后，进程级静态注册的语义就不清了；
//    引擎没有真注销口，所以 `unregister_protocol` 做的是「把这条 scheme 的根目录
//    清空，之后一律回错误」，返回值表示顶替成功，不假装能撤销注册；
// ② 导航失败的载荷是 `uri|domain|code|message` 四段（错误文本里可能有 `|`，所以
//    前三段按位置取、剩下的全归 message），拆成结构再交给调用方。

///|
/// 一次导航失败的细粒度原因。
pub(all) struct NavError {
  uri : String
  domain : String
  code : Int
  message : String
}

///|
/// 本工具链没有 `String::to_int`，错误码按字符扫（可带负号，非数字即停）。
fn nav_parse_int(s : String) -> Int {
  let mut acc = 0
  let mut neg = false
  let mut seen = false
  let mut i = 0
  for ch in s.iter() {
    if i == 0 && ch == '-' {
      neg = true
    } else if ch >= '0' && ch <= '9' {
      acc = acc * 10 + (ch.to_int() - 48)
      seen = true
    } else {
      ()
    }
    i = i + 1
  }
  let _ = seen
  if neg {
    0 - acc
  } else {
    acc
  }
}

///|
/// 拆 `uri|domain|code|message`。段数不足或整体为空给 None（不猜字段）。
pub fn nav_error_parse(raw : String) -> NavError? {
  if raw.length() == 0 {
    return None
  }
  let parts : Array[String] = []
  let mut cur = ""
  let mut n = 0
  for ch in raw.iter() {
    if ch == '|' && n < 3 {
      parts.push(cur)
      cur = ""
      n = n + 1
    } else {
      cur = cur + ch.to_string()
    }
  }
  parts.push(cur)
  if parts.length() < 4 {
    return None
  }
  Some({
    uri: parts[0],
    domain: parts[1],
    code: nav_parse_int(parts[2]),
    message: parts[3],
  })
}

///|
/// 注册一条自定义协议，把 `scheme://<路径>` 映射到 `root` 目录下的文件。
/// 未挂载（没有 webkit 视图）返回 false；根目录里的路径含 `..` 会被拒（C 侧）。
pub fn Webview::register_protocol(
  self : Webview,
  scheme : String,
  root : String,
) -> Bool {
  self.handle != 0L &&
  wb_register_scheme(self.handle, @utf8.encode(scheme), @utf8.encode(root)) == 1
}

///|
/// 「注销」= 顶替成错误 handler（引擎没有真注销口，见文件头）。返回 false 只
/// 表示这条 scheme 本来就没注册过。
pub fn Webview::unregister_protocol(self : Webview, scheme : String) -> Bool {
  self.handle != 0L &&
  wb_unregister_scheme(self.handle, @utf8.encode(scheme)) == 1
}
