// 浏览器页：WebView 全能力演示——加载（URL/本地 HTML/自定义协议/拒绝路径）、
// 导航与能力查询、事件流水（on_event 一族）、JS 执行与结果回传、JS↔原生
// raw binding、Cookie 查询、DOM 抓取、创建选项与平台差异。
//
// G7 迁移记档（与 master 旧页的差）：
// ① 五个导航回调（on_commit_navigation/on_finish_navigation/on_change_loading/
//    on_update_command/on_update_title）合一为 `on_event` 一条（WebEvent 族，
//    消费式取）；cookie 也从「回调参数」改成 `Cookies` 事件回包；
// ② 自定义协议从「页内 handler 返回 HTML」换成「文件根目录」形态
//    （register_protocol(scheme, root)），且 scheme 名要在建第一扇 webview
//    **之前**经 `webview_predeclare_schemes` 声明（三平台取严）；拒绝路径改为
//    「注销协议后重载同一 URL」，失败走 LoadFailed + nav_error_parse 结构化原因；
// ③ `execute_javascript_with_result` 的回包只剩结果串（请求序号门面自持配对）；
// ④ 新增 DOM 抓取段（capture_dom 四档：正文/链接/meta/结构，旧页没有）；
// ⑤ 引擎不在位时降级为自绘说明板（探测 + 降级，不静默）；
// ⑥ pane 在**挂载时**创建（页内容惰性挂载，挂载那一刻宿主才在）。

///|
/// 协议页根目录：走系统 TEMP（拿不到回落当前目录），不往仓库里写。
fn scheme_root() -> String {
  match @sys.envx_get("TEMP") {
    Some(t) => t + "/libyue-showcase-scheme"
    None => "libyue-showcase-scheme"
  }
}

///|
/// 本地协议页内容（走 yuedemo:// 读取的真文件：HTML + CSS 两份）。
const SCHEME_INDEX : String = "<!doctype html><html><head><meta charset=\"utf-8\"><title>本地协议页</title><link rel=\"stylesheet\" href=\"style.css\"></head><body><h1>来自 yuedemo:// 的标题</h1><p class=\"styled\">这段若带浅蓝底，说明 style.css 也是走协议取到的。</p><button onclick=\"demoBinding('来自协议页的调用')\">JS 调原生绑定</button><p id=r></p><script>function demoBinding(s){document.getElementById('r').textContent='已调用: '+s}</script></body></html>"

///|
const SCHEME_CSS : String = ".styled { background: #cde; padding: 6px; } h1 { font-size: 20px; }"

///|
/// 本地 HTML 片段（load_html 装的页面**不入历史**，段内说明）。
const LOCAL_HTML : String = "<html><body style='font-family:sans-serif;background:#fff;color:#222;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%'><h3>load_html 本地片段 ✓</h3><button onclick=\"demoBinding('来自网页的调用')\">JS 调原生绑定</button><p id=r></p><script>function demoBinding(s){document.getElementById('r').textContent='已调用: '+s}</script></body></html>"

///|
/// 浏览器页。页内私有状态（回显六个 Store + webview 句柄）不进共享 App。
pub fn page_browser(app : @shared.App) -> @core.Node {
  let nav_state : @core.Store[String] = @core.Store::new("(导航状态)")
  let nav_events : @core.Store[String] = @core.Store::new("(事件流水)")
  let bind_state : @core.Store[String] = @core.Store::new("(raw binding)")
  let js_state : @core.Store[String] = @core.Store::new("(JS 结果)")
  let cookie_state : @core.Store[String] = @core.Store::new("(Cookie)")
  let title_state : @core.Store[String] = @core.Store::new("(标题)")
  let dom_state : @core.Store[String] = @core.Store::new("(DOM 快照)")
  let wv : Ref[@web.Webview?] = Ref(None)
  @shared.page([
    @shared.section(
      "加载",
      "WebView 与加载",
      "load_url / 本地 HTML / yuedemo:// 自定义协议（读 TEMP 下的真文件）/ 拒绝路径（注销协议后重载，应见加载失败 + 结构化原因）。",
      [
        // pane：挂载时建 webview（页内容惰性挂载，挂载那一刻宿主才在）
        @core.node_of_new(fn(holder : @core.Widget) -> @core.Widget {
          match app.host.val {
            Some(host) => {
              // scheme 预声明要在建第一扇 webview 之前（三平台取严）
              let _ = @web.webview_predeclare_schemes(["yuedemo"])
              match @web.webview_new(host, "about:blank") {
                Some(v) => {
                  wv.val = Some(v)
                  // 事件流水：五个旧回调合一 + 结构化失败 + cookie 回包
                  v.on_event = Some(fn(e : @web.WebEvent) -> Unit {
                    match e {
                      @web.TitleChanged(t) => title_state.set(t)
                      @web.NavStarted(u) => nav_events.set("导航开始：\{u}")
                      @web.NavCommitted(u) => nav_events.set("导航提交：\{u}")
                      @web.NavFinished(u) => nav_events.set("导航完成：\{u}")
                      @web.LoadFailed(raw) =>
                        match @web.nav_error_parse(raw) {
                          None => nav_events.set("加载失败：\{raw}")
                          Some(ne) =>
                            nav_events.set(
                              "加载失败：\{ne.domain}/\{ne.code} \{ne.uri}",
                            )
                        }
                      @web.NewWindow(u) => nav_events.set("新窗请求（默认拦下）：\{u}")
                      @web.Permission(c) =>
                        nav_events.set("权限请求（默认拒绝）：\{c}")
                      @web.Cookies(j) =>
                        cookie_state.set("Cookie 回包（\{j.length()} 字节）：\{j}")
                      _ => ()
                    }
                  })
                  v.on_invoke = Some(fn(payload : String) -> Unit {
                    bind_state.set("收到网页调用：\{payload}")
                  })
                  let _ = v.node(grow=1.0).mount_into(holder)
                  // 绑定与策略要有句柄才生效（挂载发生在第一次绘制）：排期重试
                  let tries : Ref[Int] = Ref(0)
                  let tick : Ref[() -> Unit] = Ref(fn() { () })
                  tick.val = fn() -> Unit {
                    if v.add_raw_binding("demoBinding") {
                      v.set_new_window_policy(false)
                      v.set_permission_mode(false)
                    } else {
                      tries.val = tries.val + 1
                      if tries.val < 60 {
                        let _ = host.timer(80, tick.val)
                      }
                    }
                  }
                  let _ = host.timer(80, tick.val)
                }
                None => {
                  // 探测不到引擎：降级不静默
                  let _ = @ui
                    .view(
                      [
                        @ui.text("webview 引擎不在位", role=@ui.Body),
                        @ui.text(
                          "本机缺 WebView2 运行时 / webkit2gtk-4.1。装上后本页自动走 webview 分支。",
                          role=@ui.Secondary,
                        ),
                      ],
                      padding=12.0,
                      grow=1.0,
                      background_color=@theme.theme_bg_panel(),
                      border_color=@theme.theme_border(),
                    )
                    .mount_into(holder)
                }
              }
            }
            None => ()
          }
          holder
        }),
        @ui.row(
          [
            @ui.button("加载 example.com", on_click=fn() {
              match wv.val {
                Some(v) => {
                  v.load_url("https://example.com")
                  nav_state.set("加载 example.com（需外网）")
                }
                None => ()
              }
            }),
            @ui.button("本地 HTML", variant=@ui.Soft, on_click=fn() {
              match wv.val {
                Some(v) => {
                  v.load_html(LOCAL_HTML)
                  nav_state.set("load_html 完成（此页不入历史，后退无效）")
                }
                None => ()
              }
            }),
            @ui.button("协议页", variant=@ui.Solid, on_click=fn() {
              match wv.val {
                Some(v) => {
                  let root = scheme_root()
                  let _ = @sys.sys_make_dirs(root)
                  let a = @sys.sys_write_text_file(root + "/index.html", SCHEME_INDEX)
                  let b = @sys.sys_write_text_file(root + "/style.css", SCHEME_CSS)
                  if a && b && v.register_protocol("yuedemo", root) {
                    v.load_url("yuedemo://local/index.html")
                    nav_state.set("已注册 yuedemo:// 并加载（HTML+CSS 走协议）")
                  } else {
                    nav_state.set("协议未就绪（文件写失败或引擎不支持）")
                  }
                }
                None => ()
              }
            }),
            @ui.button("拒绝路径", variant=@ui.Danger, on_click=fn() {
              match wv.val {
                Some(v) => {
                  let _ = v.unregister_protocol("yuedemo")
                  v.load_url("yuedemo://local/index.html")
                  nav_state.set("已注销协议并重载（事件流水应见加载失败）")
                }
                None => ()
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(nav_state, fn(s) { s }),
      ],
      code=[
        "// pane：挂载时建（宿主彼时才在）",
        "let _ = @web.webview_predeclare_schemes([\"yuedemo\"])",
        "match @web.webview_new(host, \"about:blank\") {",
        "  Some(v) => {",
        "    v.on_event = Some(fn(e) { match e {",
        "      @web.TitleChanged(t) => ...",
        "      @web.LoadFailed(raw) => // nav_error_parse 拆结构化原因",
        "      _ => ()",
        "    } })",
        "    let _ = v.node(grow=1.0).mount_into(holder)",
        "  }",
        "  None => // 引擎不在位：降级自绘说明板",
        "}",
        "v.load_url(\"https://example.com\")",
        "v.load_html(\"<h3>本地片段</h3>\")",
        "v.register_protocol(\"yuedemo\", root) // 文件根目录形态",
        "v.unregister_protocol(\"yuedemo\") // 注销后重载即拒绝路径",
      ],
    ),
    @shared.section(
      "导航",
      "导航与能力查询",
      "四导航按钮 + can_go_back/can_go_forward/is_loading 能力查询。注意：load_html 装的页面不入历史，此时后退是空操作（如实回显，不装坏）。",
      [
        @ui.row(
          [
            @ui.button("← 后退", on_click=fn() {
              match wv.val {
                Some(v) =>
                  if v.can_go_back() {
                    v.go_back()
                    nav_state.set("后退 → \{v.current_url()}")
                  } else {
                    nav_state.set("后退：无处可退（can_go_back=0）")
                  }
                None => ()
              }
            }),
            @ui.button("前进 →", variant=@ui.Soft, on_click=fn() {
              match wv.val {
                Some(v) =>
                  if v.can_go_forward() {
                    v.go_forward()
                    nav_state.set("前进 → \{v.current_url()}")
                  } else {
                    nav_state.set("前进：无可前进项（can_go_forward=0）")
                  }
                None => ()
              }
            }),
            @ui.button("刷新", on_click=fn() {
              match wv.val {
                Some(v) => v.reload()
                None => ()
              }
            }),
            @ui.button("停止", variant=@ui.Text, on_click=fn() {
              match wv.val {
                Some(v) => v.stop()
                None => ()
              }
            }),
            @ui.button("能力查询", variant=@ui.Soft, on_click=fn() {
              match wv.val {
                Some(v) =>
                  nav_state.set(
                    "可后退=\{v.can_go_back()} 可前进=\{v.can_go_forward()} 加载中=\{v.is_loading()}",
                  )
                None => ()
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(nav_state, fn(s) { s }),
        @ui.bind_label(nav_events, fn(s) { "事件：\{s}" }),
        @ui.bind_label(title_state, fn(s) { "标题：\{s}" }),
      ],
      code=[
        "v.go_back()", "v.go_forward()", "v.reload()", "v.stop()",
        "println(v.can_go_back())", "println(v.can_go_forward())",
        "println(v.is_loading())", "// 事件一族（on_event，消费式取）",
        "@web.TitleChanged(t) => ...", "@web.NavStarted(u) => ...",
        "@web.LoadFailed(raw) => match @web.nav_error_parse(raw) { ... }",
      ],
    ),
    @shared.section(
      "JS",
      "执行 JavaScript",
      "execute_javascript 改页面（无结果）；execute_javascript_with_result 异步取回结果（请求序号门面自持配对，回包只剩结果串）。",
      [
        @ui.row(
          [
            @ui.button("取结果 1+41", on_click=fn() {
              match wv.val {
                Some(v) =>
                  ignore(
                    v.execute_javascript_with_result("1 + 41", fn(r : String) -> Unit {
                      js_state.set("JS 结果：\{r}")
                    }),
                  )
                None => ()
              }
            }),
            @ui.button("读 document.title", variant=@ui.Soft, on_click=fn() {
              match wv.val {
                Some(v) =>
                  ignore(
                    v.execute_javascript_with_result(
                      "document.title",
                      fn(r : String) -> Unit { js_state.set("title=\{r}") },
                    ),
                  )
                None => ()
              }
            }),
            @ui.button("改页面标题", variant=@ui.Solid, on_click=fn() {
              match wv.val {
                Some(v) => {
                  v.execute_javascript("document.title='由原生 JS 设置 ✓'")
                  js_state.set("已执行 document.title 赋值（看上方标题回显）")
                }
                None => ()
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(js_state, fn(s) { s }),
      ],
      code=[
        "v.execute_javascript(\"document.title='由原生设置'\")",
        "ignore(v.execute_javascript_with_result(\"1 + 41\", fn(r) {",
        "  println(\"JS 结果: \\{r}\")",
        "}))",
      ],
    ),
    @shared.section(
      "绑定",
      "JS ↔ 原生绑定",
      "注册 demoBinding（加载段里的网页按钮调它）/ 移除 / has_bindings 查询。页面调用经 on_invoke 回原生。",
      [
        @ui.row(
          [
            @ui.button("重新注册绑定", on_click=fn() {
              match wv.val {
                Some(v) =>
                  bind_state.set(
                    if v.add_raw_binding("demoBinding") {
                      "已注册 demoBinding"
                    } else {
                      "注册未生效（pane 未挂载？）"
                    },
                  )
                None => ()
              }
            }),
            @ui.button("移除绑定", variant=@ui.Danger, on_click=fn() {
              match wv.val {
                Some(v) =>
                  bind_state.set(
                    if v.remove_binding("demoBinding") {
                      "已移除 demoBinding（has_bindings=\{v.has_bindings()}）"
                    } else {
                      "移除未生效"
                    },
                  )
                None => ()
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(bind_state, fn(s) { s }),
      ],
      code=[
        "v.add_raw_binding(\"demoBinding\")",
        "v.on_invoke = Some(fn(payload) {",
        "  println(\"收到网页调用: \\{payload}\")",
        "})",
        "v.remove_binding(\"demoBinding\")",
        "println(v.has_bindings())",
        "// 网页侧:<button onclick=\"demoBinding('来自页面')\">",
      ],
    ),
    @shared.section(
      "Cookie",
      "Cookie 查询",
      "异步查询 URL 的 Cookie：请求发出后结果以 Cookies(json) 事件回包（旧链路的回调参数形态没有了）。先访问个带 cookie 的站点再查。",
      [
        @ui.row(
          [
            @ui.button("查当前 URL", on_click=fn() {
              match wv.val {
                Some(v) => {
                  v.get_cookies_for_url(v.current_url())
                  cookie_state.set("已请求 \{v.current_url()} 的 cookie（回包走事件流水）")
                }
                None => ()
              }
            }),
            @ui.button("查 example.com", variant=@ui.Soft, on_click=fn() {
              match wv.val {
                Some(v) => {
                  v.get_cookies_for_url("https://example.com")
                  cookie_state.set("已请求 example.com 的 cookie（回包走事件流水）")
                }
                None => ()
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(cookie_state, fn(s) { s }),
      ],
      code=[
        "v.get_cookies_for_url(\"https://example.com\")",
        "// 回包在 on_event 里：",
        "@web.Cookies(j) => println(\"cookie 回包: \\{j}\")",
      ],
    ),
    @shared.section(
      "DOM",
      "DOM 抓取",
      "capture_dom 四档快照（正文/链接/meta/结构）：执行内建脚本取回 JSON，解析成 DomSnapshot。旧页没有这一段。",
      [
        @ui.row(
          [
            @ui.button("抓正文", on_click=fn() {
              match wv.val {
                Some(v) =>
                  ignore(
                    v.capture_dom(@web.PageText, fn(s : @web.DomSnapshot) -> Unit {
                      dom_state.set(
                        "正文 ok=\{s.ok} 标题=\{s.title} \{s.text.length()} 字符",
                      )
                    }),
                  )
                None => ()
              }
            }),
            @ui.button("抓链接", variant=@ui.Soft, on_click=fn() {
              match wv.val {
                Some(v) =>
                  ignore(
                    v.capture_dom(@web.Links, fn(s : @web.DomSnapshot) -> Unit {
                      dom_state.set("链接 ok=\{s.ok} 共 \{s.links.length()} 条")
                    }),
                  )
                None => ()
              }
            }),
            @ui.button("抓 meta", variant=@ui.Soft, on_click=fn() {
              match wv.val {
                Some(v) =>
                  ignore(
                    v.capture_dom(@web.Meta, fn(s : @web.DomSnapshot) -> Unit {
                      dom_state.set("meta ok=\{s.ok} 共 \{s.meta.length()} 条")
                    }),
                  )
                None => ()
              }
            }),
            @ui.button("抓结构", variant=@ui.Text, on_click=fn() {
              match wv.val {
                Some(v) =>
                  ignore(
                    v.capture_dom(@web.Structure, fn(s : @web.DomSnapshot) -> Unit {
                      dom_state.set(
                        "结构 ok=\{s.ok} 元素=\{s.elements} 标题=\{s.title}",
                      )
                    }),
                  )
                None => ()
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(dom_state, fn(s) { s }),
      ],
      code=[
        "v.capture_dom(@web.PageText, fn(s : @web.DomSnapshot) {",
        "  // s.ok / s.title / s.url / s.text / s.links / s.meta / s.elements",
        "  println(\"正文 \\{s.text.length()} 字符\")",
        "})",
        "// 四档：PageText / Links / Meta / Structure",
      ],
    ),
    @shared.section(
      "选项",
      "创建选项与平台差异",
      "创建期参数与几条平台差异速览。",
      [
        @ui.descriptions(
          [
            (
              "profile",
              "用户数据目录名（cookie/存储按它隔离）；建后即定，换目录要换实例",
            ),
            (
              "user_agent",
              "建时设定；运行期 set_user_agent 可改",
            ),
            (
              "自定义协议",
              "文件根目录形态；scheme 名须在建第一扇 webview 前经 webview_predeclare_schemes 声明（Windows 挂 environment、mac 挂 configuration，三平台取严）",
            ),
            (
              "load_html",
              "装的页面不入历史——此时后退/前进是空操作（can_go_back 恒 0）",
            ),
            (
              "引擎不在位",
              "探测 + 降级：pane 区改画自绘说明板，不静默失败",
            ),
          ],
          title="WebviewOptions 与平台口径",
        ),
      ],
      code=[
        "let opts = @web.webview_options(\"about:blank\")",
        "// opts.profile / opts.user_agent（建时即定）",
        "match @web.webview_open(host, opts) {",
        "  Some(v) => ...",
        "  None => // 引擎不在位，降级",
        "}",
      ],
    ),
  ])
}
