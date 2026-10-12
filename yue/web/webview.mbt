///|
/// webview 引擎在位探测：Linux 需要发行版提供 webkit2gtk-4.1（动态链），缺包或
/// 非 Linux 平台返回 false。调用方据此摆一块自绘的降级内容，而不是等加载失败——
/// 「探测 + 语义化降级」是本栈每条能力都走的形态（沿用 `yue/sys` 的范式）。
pub fn webview_supported() -> Bool {
  wb_available() == 1
}

///|
/// profile 持久化探测：Linux 恒可持久（引擎自己写磁盘）；macOS 的边界是 API 给的
/// ——持久 profile 需要 macOS 14+ 且进程有 bundle id（`.app` 包），任一不满足只有
/// nonPersistentDataStore：会话隔离成立，但重启掉登录。调用方据此在 UI 上说清楚，
/// 本层不静默替用户决定。
pub(all) enum ProfilePersistence {
  Persistent
  EphemeralOnly
}

///|
pub fn browser_profile_persistence() -> ProfilePersistence {
  if wb_persistence() == 1 {
    Persistent
  } else {
    EphemeralOnly
  }
}

///|
/// 引擎侧可选信号在位掩码：1 下载 / 2 web 进程终止 / 4 权限请求 / 8 新窗。
/// 缺哪条就少哪条回证（诊断读数，不是错误）。
pub fn webview_signal_mask() -> Int {
  wb_signal_mask()
}

///|
/// webview 的创建参数。**profile 挂在这一层**（pane 级），不是进程级：
/// 「多账号」= 多 pane / 多窗各给一份数据目录，键用可读规范（<bundle-id>.<profile>）。
pub(all) struct WebviewOptions {
  url : String
  profile : String
  user_agent : String
}

///|
/// 默认参数：只给地址，其余走引擎默认。
pub fn webview_options(url : String) -> WebviewOptions {
  { url, profile: "", user_agent: "" }
}

///|
/// 引擎侧送来的一条事件（消费式取，见 `Webview::pump`）。载荷都是**已解码的文本**，
/// 线协议/JSC 类型不外泄给调用方。
pub(all) enum WebEvent {
  TitleChanged(String)
  UrlChanged(String)
  NavStarted(String)
  NavCommitted(String)
  NavFinished(String)
  /// 被服务端重定向（细粒度：与「重新加载」区分开）
  NavRedirected(String)
  LoadFailed(String)
  Invoke(String)
  EvalResult(Int64, String)
  NewWindow(String)
  Permission(String)
  Download(String)
  ProcessTerminated(String)
  CloseRequested
  Cookies(String)
  Unknown(Int, String)
}

///|
fn wb_str(f : (Int64, Bytes, Int) -> Int, id : Int64) -> String {
  let cap = 256
  let buf = Bytes::new(cap)
  let n = f(id, buf, cap)
  if n <= 0 {
    ""
  } else {
    let keep = if n > cap - 1 { cap - 1 } else { n }
    @utf8.decode_lossy(buf[0:keep])
  }
}

const WB_TEXT_CAP = 768

///|
/// 一扇窗里的一个 webview 区（pane）。owner = 原生子件：它占一块由 yoga 算出的
/// 矩形，矩形内是 WebKit 自己画的，我们的 Painter 不参与，也不被 `clip_rect` 裁。
pub(all) struct Webview {
  app : @core.App
  mut surface : @win.ChildSurface?
  mut handle : Int64
  mut url : String
  /// 上一次同步给子件的矩形（相同就不重复走一遍 FFI）
  mut last_rect : (Double, Double, Double, Double)
  /// 创建参数（profile / UA 在挂载那一刻才用得上，所以留着）
  opts : WebviewOptions
  /// 页面 → 原生的回调（`add_raw_binding` 注册的名字都走这一条）
  mut on_invoke : ((String) -> Unit)?
  /// 所有事件的旁路回调（含 invoke，便于日志与测试观察）
  mut on_event : ((WebEvent) -> Unit)?
  /// 已排队的 JS 求值回调（按请求序号配对回包）
  mut eval_waiters : Array[(Int64, (String) -> Unit)]
  /// 挂载前排的 HTML（load_html 在未挂载时记下，挂载即应用；空串 = 没有）
  mut pending_html : (String, String)
  /// 泵是否在跑（close 之后不再排期）
  mut pumping : Bool
  /// 已注册的页面→原生通道数（引擎没有注销口，计数只增）
  mut binding_count : Int
}

///|
/// 建一个 webview pane 并给出起始 URL。引擎不可用返回 None（调用方降级）。
/// 此刻还没有矩形（要等布局），页面在第一次绘制时随子件槽一起挂上。
pub fn webview_new(app : @core.App, url : String) -> Webview? {
  webview_open(app, webview_options(url))
}

///|
/// 带参数地建 pane（profile / UA 这类引擎原生开关走这里）。
pub fn webview_open(app : @core.App, opts : WebviewOptions) -> Webview? {
  if !webview_supported() {
    return None
  }
  // 建视图之前是 scheme 名单最后的声明机会（Windows 的 environment、mac 的
  // configuration 都只认这一步之前的名单），此处封版
  webview_seal_schemes()
  Some({
    app,
    surface: None,
    handle: 0L,
    url: opts.url,
    last_rect: (0.0, 0.0, 0.0, 0.0),
    opts,
    on_invoke: None,
    on_event: None,
    eval_waiters: [],
    pending_html: ("", ""),
    pumping: false,
    binding_count: 0,
  })
}

///|
/// 矩形同步的纯规则：布局给的是 Double，子件槽要的是整数像素，**四舍五入**
/// （截断会让 0.6px 的漂移每帧都算「变了」，每帧多走一遍 FFI 与一次重排）。
pub fn webview_rect_key(
  rect : (Double, Double, Double, Double),
) -> (Int, Int, Int, Int) {
  (
    rect.0.round().to_int(),
    rect.1.round().to_int(),
    rect.2.round().to_int(),
    rect.3.round().to_int(),
  )
}

///|
/// 把布局算出的矩形同步给子件（窗口内容坐标）。每帧调用，位置没动不重复走 FFI。
fn Webview::sync_rect(self : Webview, rect : (Double, Double, Double, Double)) -> Unit {
  let same = {
    let a = webview_rect_key(self.last_rect)
    let b = webview_rect_key(rect)
    a == b
  }
  if same {
    return
  }
  self.last_rect = rect
  match self.surface {
    None => ()
    Some(s) => {
      s.set_rect(rect)
      let k = webview_rect_key(rect)
      wb_set_size(self.handle, k.2, k.3)
    }
  }
}

///|
/// 挂进布局的节点：`grow` > 0 时吃掉父容器的剩余空间（Tauri-like 的整页形态），
/// 否则按 `width`/`height` 定尺寸（左右分栏里页面区通常也是 grow 的那一侧）。
pub fn Webview::node(
  self : Webview,
  width? : Double = 0.0,
  height? : Double = 0.0,
  grow? : Double = 0.0,
) -> @core.Node {
  @core.node_of_new(fn(parent : @core.Widget) -> @core.Widget {
    let w = @core.Widget::new()
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    }
    if height > 0.0 {
      w.node.set_height(@yoga.fixed(height))
    }
    if grow > 0.0 {
      w.node.set_flex_grow(grow)
    }
    w.on_draw = Some(fn(
      self_w : @core.Widget,
      _p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let r = (self_w.rect.x, self_w.rect.y, self_w.rect.w, self_w.rect.h)
      if self.surface is None && r.2 > 1.0 && r.3 > 1.0 {
        self.mount_at(r)
      } else {
        self.sync_rect(r)
      }
    })
    parent.append_child(w)
    w
  })
}

///|
/// 第一次拿到真实矩形时挂子件槽并把页面装进去，同时起事件泵。
fn Webview::mount_at(self : Webview, rect : (Double, Double, Double, Double)) -> Unit {
  let k = webview_rect_key(rect)
  match self.app.window.mount_child_surface(@win.Webview, rect) {
    None => ()
    Some(s) => {
      self.surface = Some(s)
      self.handle = wb_create(
        s.handle(),
        k.2,
        k.3,
        @utf8.encode(self.url),
        @utf8.encode(self.opts.profile),
        @utf8.encode(self.opts.user_agent),
      )
      self.last_rect = rect
      let ph = self.pending_html
      if ph.0.length() > 0 {
        self.pending_html = ("", "")
        wb_load_html(self.handle, @utf8.encode(ph.0), @utf8.encode(ph.1))
      }
      self.start_pump()
    }
  }
}

///|
/// 事件泵：每 30 毫秒排一期，把引擎侧队列取空。**不挂在绘制里**——回调可能在
/// 装载/卸载控件，绘制遍历中途改树是本栈明令避免的形态（见 adaptation 的 G 系列条）。
fn Webview::start_pump(self : Webview) -> Unit {
  if self.pumping || self.handle == 0L {
    return
  }
  self.pumping = true
  let tick : Ref[() -> Unit] = Ref(fn() { () })
  tick.val = fn() -> Unit {
    if !self.pumping {
      return
    }
    self.pump()
    let _ = @core.set_timeout(30, tick.val)
  }
  let _ = @core.set_timeout(30, tick.val)
}

///|
/// 取空引擎队列并派发。宿主每帧调一次即可（本包自己在排期通道里调）。
pub fn Webview::pump(self : Webview) -> Unit {
  if self.handle == 0L {
    return
  }
  let mut rounds = 0
  while rounds < 64 {
    rounds = rounds + 1
    let kind = wb_next_event(self.handle)
    if kind < 0 {
      break
    }
    let num = wb_event_num(self.handle)
    let buf = Bytes::new(WB_TEXT_CAP)
    let n = wb_event_text(self.handle, buf, WB_TEXT_CAP)
    let text =
      if n <= 0 {
        ""
      } else {
        let keep = if n > WB_TEXT_CAP - 1 { WB_TEXT_CAP - 1 } else { n }
        @utf8.decode_lossy(buf[0:keep])
      }
    self.dispatch(kind, num, text)
  }
}

///|
fn Webview::dispatch(self : Webview, kind : Int, num : Int64, text : String) -> Unit {
  let ev = match kind {
    1 => TitleChanged(text)
    2 => UrlChanged(text)
    3 => NavStarted(text)
    4 => NavCommitted(text)
    5 => NavFinished(text)
    15 => NavRedirected(text)
    14 => LoadFailed(text)
    6 => Invoke(text)
    7 => EvalResult(num, text)
    8 => NewWindow(text)
    9 => Permission(text)
    10 => Download(text)
    11 => ProcessTerminated(text)
    12 => CloseRequested
    13 => Cookies(text)
    _ => Unknown(kind, text)
  }
  match ev {
    EvalResult(seq, value) => {
      let kept : Array[(Int64, (String) -> Unit)] = []
      for it in self.eval_waiters {
        if it.0 == seq {
          it.1(value)
        } else {
          kept.push(it)
        }
      }
      self.eval_waiters = kept
    }
    Invoke(payload) => match self.on_invoke {
      None => ()
      Some(f) => f(payload)
    }
    _ => ()
  }
  match self.on_event {
    None => ()
    Some(f) => f(ev)
  }
}

///|
/// 导航到新地址（未挂载时先记下，挂载即加载）。
pub fn Webview::load_url(self : Webview, url : String) -> Unit {
  self.url = url
  match self.surface {
    None => ()
    Some(_) => wb_load_uri(self.handle, @utf8.encode(url))
  }
}

///|
/// 直接加载一段 HTML（本地内容、离线页、注入测试页都用它，不必落盘）。
///
/// **跨平台口径：这一段 HTML 不进前进/后退历史。** Linux 实测 `load_html` 之后
/// `can_go_back()` 仍为 false；Windows 的 WebView2 文档对 `NavigateToString` 明写
/// 「the back or forward history will not be modified」，两家一致。macOS 的
/// `loadHTMLString:baseURL:` Apple 未作承诺，待真机验。
/// 要给本地页一条**真历史**（能后退、能被链接跳走再退回来），走
/// `register_protocol` 给它一个真 URL 再 `load_url`，而不是 `load_html`。
pub fn Webview::load_html(
  self : Webview,
  html : String,
  base_uri? : String = "",
) -> Unit {
  if self.handle == 0L {
    // 还没挂载（挂载发生在第一次拿到真实矩形的那一帧）：先记下，别丢
    self.pending_html = (html, base_uri)
  } else {
    wb_load_html(self.handle, @utf8.encode(html), @utf8.encode(base_uri))
  }
}

///|
pub fn Webview::reload(self : Webview) -> Unit {
  if self.handle != 0L {
    wb_reload(self.handle)
  }
}

///|
pub fn Webview::stop(self : Webview) -> Unit {
  if self.handle != 0L {
    wb_stop(self.handle)
  }
}

///|
/// 历史前进/后退（引擎自己维护列表）。
pub fn Webview::go_back(self : Webview) -> Unit {
  if self.handle != 0L {
    wb_go_back(self.handle)
  }
}

///|
pub fn Webview::go_forward(self : Webview) -> Unit {
  if self.handle != 0L {
    wb_go_forward(self.handle)
  }
}

///|
pub fn Webview::can_go_back(self : Webview) -> Bool {
  self.handle != 0L && wb_can_go_back(self.handle) == 1
}

///|
pub fn Webview::can_go_forward(self : Webview) -> Bool {
  self.handle != 0L && wb_can_go_forward(self.handle) == 1
}

///|
/// 当前地址 / 标题 / 是否在加载 / web 进程是否已崩（崩了要重建 pane）。
pub fn Webview::get_url(self : Webview) -> String {
  if self.handle == 0L {
    ""
  } else {
    wb_str(wb_uri, self.handle)
  }
}

///|
pub fn Webview::get_title(self : Webview) -> String {
  if self.handle == 0L {
    ""
  } else {
    wb_str(wb_title, self.handle)
  }
}

///|
pub fn Webview::is_loading(self : Webview) -> Bool {
  self.handle != 0L && wb_is_loading(self.handle) == 1
}

///|
pub fn Webview::is_crashed(self : Webview) -> Bool {
  self.handle != 0L && wb_is_crashed(self.handle) == 1
}

///|
/// 旧链同名方法：本栈把 `current_url` 作为 `get_url` 的别名保留，迁移期少改调用点。
pub fn Webview::current_url(self : Webview) -> String {
  self.get_url()
}

///|
/// UA 改写（引擎原生开关，不是拦截改写）。
pub fn Webview::set_user_agent(self : Webview, agent : String) -> Unit {
  if self.handle != 0L {
    wb_set_user_agent(self.handle, @utf8.encode(agent))
  }
}

///|
/// 注入一段常驻脚本（每个 frame 的 document start）。挂载前调用会攒着？不会——
/// 未挂载时返回 false，调用方在 `on_event` 的 NavStarted 之后再注。
pub fn Webview::add_user_script(self : Webview, source : String) -> Bool {
  if self.handle == 0L {
    false
  } else {
    wb_add_user_script(self.handle, @utf8.encode(source))
    true
  }
}

///|
/// 注册「页面 → 原生」通道：注册后页面里可以直接调 `name(payload)`，载荷会被
/// JSON 序列化送到 `on_invoke`。名字必须是合法 JS 标识符。
pub fn Webview::add_raw_binding(self : Webview, name : String) -> Bool {
  if self.handle == 0L {
    false
  } else if wb_add_binding(self.handle, @utf8.encode(name)) != 1 {
    false
  } else {
    self.binding_count = self.binding_count + 1
    true
  }
}

///|
/// 注销绑定：WebKit 没有注销口，本条恒返回 false（要换语义就换名字并自行分派）。
/// 记在这里是为了不让调用方以为「注册了却摘不掉」是实现缺陷。
pub fn Webview::remove_binding(self : Webview, name : String) -> Bool {
  let _ = (self, name)
  false
}

///|
/// 有没有注册过任何绑定（`remove_all_user_scripts` 同理不支持，见上）。
pub fn Webview::has_bindings(self : Webview) -> Bool {
  self.binding_count > 0
}

///|
/// 回调挂载是**直接给字段赋值**（`v.on_invoke = Some(fn(p) { ... })`、
/// `v.on_event = Some(fn(e) { ... })`）——本栈的回调面一律是这个形态，
/// 不再包一层同名 setter，否则字段与方法重名会让赋值和调用互相看不清。

///|
/// 原生 → 网页：不等结果。
pub fn Webview::execute_javascript(self : Webview, code : String) -> Unit {
  if self.handle != 0L {
    let _ = wb_evaluate(self.handle, @utf8.encode(code))
  }
}

///|
/// 原生 → 网页并取回结果（异步：回包按请求序号配对，走 `on_event` 之前的排期泵）。
/// 未挂载返回 -1（没有句柄可挂）。
pub fn Webview::execute_javascript_with_result(
  self : Webview,
  code : String,
  done : (String) -> Unit,
) -> Int64 {
  if self.handle == 0L {
    return -1L
  }
  let seq = wb_evaluate(self.handle, @utf8.encode(code))
  if seq > 0L {
    self.eval_waiters.push((seq, done))
  }
  seq
}

///|
/// 旧链名 `evaluate_javascript` 的别名（本栈锁定的调用面用它）。
pub fn Webview::evaluate_javascript(
  self : Webview,
  code : String,
  done : (String) -> Unit,
) -> Int64 {
  self.execute_javascript_with_result(code, done)
}

///|
/// cookie 读取（异步回包成 `Cookies(json)` 事件）。
pub fn Webview::get_cookies_for_url(self : Webview, url : String) -> Unit {
  if self.handle != 0L {
    wb_get_cookies(self.handle, @utf8.encode(url))
  }
}

///|
/// 新窗（`window.open`）策略：默认丢弃并回报事件；`in_place=true` 时改为在当前
/// pane 里导航过去。本栈不做「一窗多 webview」。
pub fn Webview::set_new_window_policy(self : Webview, in_place : Bool) -> Unit {
  if self.handle != 0L {
    wb_set_new_window_policy(self.handle, if in_place { 1 } else { 0 })
  }
}

///|
/// 权限请求：默认拒绝（事件照报，调用方可弹原生提示后改成允许再重试）。
pub fn Webview::set_permission_mode(self : Webview, allow : Bool) -> Unit {
  if self.handle != 0L {
    wb_set_permission_mode(self.handle, if allow { 1 } else { 0 })
  }
}

///|
/// 下载：默认交给引擎（回报目标地址），可改成拦下。
pub fn Webview::set_download_mode(self : Webview, allow : Bool) -> Unit {
  if self.handle != 0L {
    wb_set_download_mode(self.handle, if allow { 1 } else { 0 })
  }
}

///|
/// pane 级可见性开关（爬虫后台要的「不可见 webview」）。整窗不可见属窗口层，
/// 本批只做这一区。
pub fn Webview::set_visible(self : Webview, visible : Bool) -> Unit {
  if self.handle != 0L {
    wb_set_visible(self.handle, if visible { 1 } else { 0 })
  }
}

///|
/// 拆掉页面与子件槽（幂等）。窗口拆除时子件槽由窗口层一并回收，这里只保证
/// 自己先摘，不留悬垂句柄。
pub fn Webview::close(self : Webview) -> Unit {
  self.pumping = false
  if self.handle != 0L {
    wb_destroy(self.handle)
    self.handle = 0L
  }
  match self.surface {
    Some(s) => s.unmount()
    None => ()
  }
  self.surface = None
  self.eval_waiters = []
}
