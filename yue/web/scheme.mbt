// 本地内容通道（自定义协议）与导航失败的结构化解析。
//
// 两条口径（方案 §4.4/§4.8）：
// ① 协议**名字必须先预声明**（`webview_predeclare_schemes`，第一扇 webview 之前），
//    名单之后可以换根目录、可以注销，但不能再新增名字——三家里最严的一家决定
//    契约：Windows 的名单挂在 environment 选项上（一进程一次），mac 挂在建视图前的
//    configuration 上，只有 Linux 允许随时按 context 注册（那份动态能力留在桩里，
//    不对外）。profile 挂 pane 级之后，注册本身也是**按 context** 生效的；
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
/// 本地内容通道的**预声明表**（进程级）。
///
/// 为什么公开面只给「预声明」而不给「随时注册」：三家里最严的一家决定契约——
/// Windows WebView2 的 scheme 名单挂在**环境选项**上（environment 一进程建一次、
/// 所有视图共用），macOS WKWebView 挂在**建视图之前**的 configuration 上，
/// 只有 Linux WebKitGTK 允许随时按 context 注册。把「运行时新增名字」暴露出来，
/// 等于写一份在 Windows/mac 上会失效的代码。Linux 那份动态能力仍在桩里，只是不对外。
let g_schemes : Ref[Array[String]] = Ref([])

///|
/// 本工具链的 `Array` 没有 `includes`，名单查重要么自己扫一遍。
fn schemes_has(list : Array[String], s : String) -> Bool {
  let mut hit = false
  for x in list {
    if x == s {
      hit = true
    }
  }
  hit
}

///|
let g_sealed : Ref[Bool] = Ref(false)

///|
/// 在建第一扇 webview 之前声明可用的自定义 scheme 名。
/// 返回 false 只有一个原因：名单已封（已有 webview 建起来了）。
/// 不调也行：封版时名单为空会自动放入缺省名 `"app"`，零配置就能用本地内容通道。
pub fn webview_predeclare_schemes(schemes : Array[String]) -> Bool {
  if g_sealed.val {
    return false
  }
  for s in schemes {
    if s.length() > 0 && !schemes_has(g_schemes.val, s) {
      g_schemes.val.push(s)
    }
  }
  true
}

///|
/// 当前已声明的 scheme 名单（只读快照，给界面与诊断用）。
pub fn webview_declared_schemes() -> Array[String] {
  g_schemes.val.copy()
}

///|
/// 名单封版：由 `webview_open` 在建视图前调用（Windows 正是拿这份表建 environment
/// 的时机）。空名单补一个缺省名，免得使用者没声明就发现通道「静默不可用」。
pub fn webview_seal_schemes() -> Unit {
  if g_sealed.val {
    return
  }
  if g_schemes.val.length() == 0 {
    g_schemes.val.push("app")
  }
  g_sealed.val = true
}

///|
/// 这条 scheme 是否已声明（`register_protocol` 的门）。
pub fn webview_scheme_declared(scheme : String) -> Bool {
  schemes_has(g_schemes.val, scheme)
}

///|
/// 注册一条自定义协议，把 `scheme://<路径>` 映射到 `root` 目录下的文件。
/// **名字没预声明返回 false**（见 `webview_predeclare_schemes`，三平台取严的结果）；
/// 视图还没挂载时照样受理，登记排队、挂载即应用（返回 true）。
/// 根目录里的路径含 `..` 会被拒（C 侧）；文本类响应的 MIME 带回 `charset=utf-8`
/// ——协议通道只给 MIME，不钉编码的话中文页会按 ISO-8859-1 解成乱码。
pub fn Webview::register_protocol(
  self : Webview,
  scheme : String,
  root : String,
) -> Bool {
  if !webview_scheme_declared(scheme) {
    return false
  }
  if self.handle == 0L {
    // 还没挂载（视图在第一次拿到真实矩形那一帧才建）：记下来、挂载即应用，
    // 与 load_html 的 pending 同源——调用方不必自己等挂载
    self.pending_protos.push((scheme, root))
    return true
  }
  wb_register_scheme(self.handle, @utf8.encode(scheme), @utf8.encode(root)) == 1
}

///|
/// 「注销」= 顶替成错误 handler（引擎没有真注销口，见文件头）。返回 false 只
/// 表示这条 scheme 本来就没注册过。
pub fn Webview::unregister_protocol(self : Webview, scheme : String) -> Bool {
  // 先撤掉「待挂载应用」的登记：撤到过就算登记过（返回 true）
  let kept : Array[(String, String)] = []
  let mut had = false
  for pr in self.pending_protos {
    if pr.0 == scheme {
      had = true
    } else {
      kept.push(pr)
    }
  }
  self.pending_protos = kept
  if self.handle == 0L {
    return had
  }
  wb_unregister_scheme(self.handle, @utf8.encode(scheme)) == 1
}
