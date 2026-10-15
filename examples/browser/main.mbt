// 浏览器示例：WebView 全能力演示——原 showcase「浏览器」页独立成示例。
// 布局：地址栏 + 导航行、演示按钮两行、webview 主体、底部状态区。
//
// 覆盖：加载（URL / 本地 HTML / yuedemo:// 自定义协议 / 拒绝路径）、导航与
// 能力查询、事件流水（on_event 一族）、JS 执行与结果回传、JS↔原生 raw
// binding、Cookie 查询、DOM 抓取。
//
// 要点（与 showcase 旧页同口径）：
// ① scheme 名要在建第一扇 webview **之前**经 `webview_predeclare_schemes`
//    声明（三平台取严）；自定义协议是「文件根目录」形态（register_protocol）；
// ② 绑定与策略要有句柄才生效（挂载发生在第一次绘制）：排期重试；
// ③ load_html 装的页面不入历史——此时后退/前进是空操作（如实回显）；
// ④ 引擎不在位时降级为自绘说明板（探测 + 降级，不静默）。

///|
/// 协议页根目录：走系统 TEMP（拿不到回落当前目录），不往仓库里写。
fn scheme_root() -> String {
  match @sys.envx_get("TEMP") {
    Some(t) => t + "/libyue-browser-scheme"
    None => "libyue-browser-scheme"
  }
}

///|
/// 本地协议页内容（走 yuedemo:// 读取的真文件：HTML + CSS 两份）。
const SCHEME_INDEX : String = "<!doctype html><html><head><meta charset=\"utf-8\"><title>本地协议页</title><link rel=\"stylesheet\" href=\"style.css\"></head><body><h1>来自 yuedemo:// 的标题</h1><p class=\"styled\">这段若带浅蓝底，说明 style.css 也是走协议取到的。</p><button onclick=\"demoBinding('来自协议页的调用')\">JS 调原生绑定</button><p id=r></p><script>function demoBinding(s){document.getElementById('r').textContent='已调用: '+s}</script></body></html>"

///|
const SCHEME_CSS : String = ".styled { background: #cde; padding: 6px; } h1 { font-size: 20px; }"

///|
/// 本地 HTML 片段（load_html 装的页面**不入历史**）。
const LOCAL_HTML : String = "<html><body style='font-family:sans-serif;background:#fff;color:#222;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%'><h3>load_html 本地片段 ✓</h3><button onclick=\"demoBinding('来自网页的调用')\">JS 调原生绑定</button><p id=r></p><script>function demoBinding(s){document.getElementById('r').textContent='已调用: '+s}</script></body></html>"

///|
fn main {
  let url_in : @core.Store[String] = @core.Store::new("https://example.com")
  let nav_state : @core.Store[String] = @core.Store::new("(导航状态)")
  let nav_events : @core.Store[String] = @core.Store::new("(事件流水)")
  let bind_state : @core.Store[String] = @core.Store::new("(raw binding)")
  let js_state : @core.Store[String] = @core.Store::new("(JS 结果)")
  let cookie_state : @core.Store[String] = @core.Store::new("(Cookie)")
  let title_state : @core.Store[String] = @core.Store::new("(标题)")
  let dom_state : @core.Store[String] = @core.Store::new("(DOM 快照)")
  let wv : Ref[@web.Webview?] = Ref(None)
  // webview 主体挂进这个占位（handle 阶段捕获，webview 建好后 mount）
  let holder : Ref[@core.Widget?] = Ref(None)

  fn nav_to(u : String, note : String) -> Unit {
    match wv.val {
      Some(v) => {
        v.load_url(u)
        nav_state.set(note)
      }
      None => ()
    }
  }

  fn load_current() -> Unit {
    let u = url_in.get()
    nav_to(u, "加载 \{u}")
  }

  // scheme 预声明：建第一扇 webview 前的最后声明机会（三平台取严）
  let _ = @web.webview_predeclare_schemes(["yuedemo"])

  let body = @ui.col(
    [
      // 工具区：地址栏 + 导航 / 演示按钮两行
      @ui.col(
        [
          @ui.row(
            [
              @ui.button("←", on_click=fn() {
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
              @ui.button("→", variant=@ui.Soft, on_click=fn() {
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
              @ui.input(
                url_in,
                placeholder="输入 URL 回车加载",
                on_enter=load_current,
                handle=fn(w) { w.node.set_flex_grow(1.0) },
              ),
              @ui.button("加载", variant=@ui.Solid, on_click=load_current),
            ],
            column_gap=6.0,
          ),
          @ui.row(
            [
              @ui.button("example.com", on_click=fn() {
                nav_to("https://example.com", "加载 example.com（需外网）")
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
                    nav_state.set("已注销协议并重载（事件区应见加载失败）")
                  }
                  None => ()
                }
              }),
              @ui.button("注册绑定", on_click=fn() {
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
            column_gap=6.0,
          ),
          @ui.row(
            [
              @ui.button("JS 1+41", on_click=fn() {
                match wv.val {
                  Some(v) =>
                    ignore(
                      v.execute_javascript_with_result(
                        "1 + 41",
                        fn(r : String) -> Unit { js_state.set("JS 结果：\{r}") },
                      ),
                    )
                  None => ()
                }
              }),
              @ui.button("JS 读标题", variant=@ui.Soft, on_click=fn() {
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
              @ui.button("JS 改标题", variant=@ui.Solid, on_click=fn() {
                match wv.val {
                  Some(v) => {
                    v.execute_javascript("document.title='由原生 JS 设置 ✓'")
                    js_state.set("已执行 document.title 赋值（看标题回显）")
                  }
                  None => ()
                }
              }),
              @ui.button("查 Cookie", on_click=fn() {
                match wv.val {
                  Some(v) => {
                    let u = v.current_url()
                    v.get_cookies_for_url(u)
                    cookie_state.set("已请求 \{u} 的 cookie（回包走事件区）")
                  }
                  None => ()
                }
              }),
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
            column_gap=6.0,
          ),
        ],
        padding=8.0,
        row_gap=6.0,
      ),
      // webview 主体（建好后 mount 进来；引擎不在位则降级说明板）
      @ui.col([], grow=1.0, handle=fn(c) { holder.val = Some(c) }),
      // 底部状态区
      @ui.col(
        [
          @ui.bind_label(title_state, fn(s) { "标题：\{s}" }),
          @ui.bind_label(nav_events, fn(s) { "事件：\{s}" }),
          @ui.bind_label(nav_state, fn(s) { "导航：\{s}" }),
          @ui.bind_label(bind_state, fn(s) { "绑定：\{s}" }),
          @ui.bind_label(js_state, fn(s) { "JS：\{s}" }),
          @ui.bind_label(cookie_state, fn(s) { "Cookie：\{s}" }),
          @ui.bind_label(dom_state, fn(s) { "DOM：\{s}" }),
        ],
        padding=8.0,
        row_gap=2.0,
      ),
    ],
    grow=1.0,
  )
  let mounted = @ui.mount_window(
    [body],
    title="浏览器示例",
    width=1100,
    height=760,
    handle=fn(a : @core.App) {
      // webview 建在首帧之后（宿主循环已跑、窗口已上屏，与 showcase 旧页
      // 「选中页才建」的时机同口径）
      let _ = a.timer(0, fn() -> Unit {
        match @web.webview_new(a, "about:blank") {
          Some(v) => {
            wv.val = Some(v)
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
                      nav_events.set("加载失败：\{ne.domain}/\{ne.code} \{ne.uri}")
                  }
                @web.NewWindow(u) => nav_events.set("新窗请求（默认拦下）：\{u}")
                @web.Permission(c) => nav_events.set("权限请求（默认拒绝）：\{c}")
                @web.Cookies(j) =>
                  cookie_state.set("回包（\{j.length()} 字节）：\{j}")
                _ => ()
              }
            })
            v.on_invoke = Some(fn(payload : String) -> Unit {
              bind_state.set("收到网页调用：\{payload}")
            })
            match holder.val {
              Some(c) => { let _ = v.node(grow=1.0).mount_into(c) }
              None => ()
            }
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
                  let _ = a.timer(80, tick.val)
                }
              }
            }
            let _ = a.timer(80, tick.val)
          }
          None => {
            // 探测不到引擎：降级不静默
            match holder.val {
              Some(c) => {
                let _ = @ui
                  .view(
                    [
                      @ui.text("webview 引擎不在位", role=@ui.Body),
                      @ui.text(
                        "本机缺 WebView2 运行时 / webkit2gtk-4.1。装上后重启本示例自动走 webview 分支。",
                        role=@ui.Secondary,
                      ),
                    ],
                    padding=12.0,
                    grow=1.0,
                    background_color="bg_panel",
                    border_color="border",
                  )
                  .mount_into(c)
              }
              None => ()
            }
            println("BROWSER-NOENGINE: webview 引擎不在位，已降级说明板")
          }
        }
      })
    },
  )
  match mounted {
    None => {
      println("BROWSER-SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(host) => {
      println("BROWSER-READY")
      host.run()
    }
  }
}
