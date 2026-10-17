// 浏览器示例：「正常的浏览器」形态——顶部工具栏（后退/前进/重载/停止/地址栏/
// 进入/演示菜单）+ webview 主体 + 底部状态栏（常驻加载状态与 URL、事件流水、
// 结果区：长结果截断、可展开看全文、可复制）。能力演示入口全部收进「演示」
// 菜单（下拉组件，键盘可及：空格/回车/↓ 开、↑/↓ 移高亮、Esc 收起）。
//
// 要点（四条口径）：
// ① scheme 名要在建第一扇 webview **之前**经 `webview_predeclare_schemes`
//    声明（三平台取严）；自定义协议是「文件根目录」形态（register_protocol）；
// ② 绑定与策略要有句柄才生效（挂载发生在第一次绘制）：排期重试；
// ③ load_html 装的页面不入历史——此时后退/前进是空操作（如实回显）；
// ④ 引擎不在位时降级为自绘说明板（探测 + 降级，不静默）。

///|
/// 协议页根目录：Windows 走 TEMP（回落 TMP）；Linux/macOS 走 XDG_RUNTIME_DIR
/// （回落 /tmp）。不回落当前目录——示例跑完不能在使用者的工作目录里留垃圾。
fn scheme_root() -> String {
  match @sys.sys_platform() {
    "windows" =>
      match @sys.envx_get("TEMP") {
        Some(t) => t + "/native-gui-browser-scheme"
        None =>
          match @sys.envx_get("TMP") {
            Some(t) => t + "/native-gui-browser-scheme"
            None => "C:/Windows/Temp/native-gui-browser-scheme"
          }
      }
    _ =>
      match @sys.envx_get("XDG_RUNTIME_DIR") {
        Some(d) => d + "/native-gui-browser-scheme"
        None => "/tmp/native-gui-browser-scheme"
      }
  }
}

///|
/// 首页：走 yuedemo:// 读取的真文件（HTML + CSS 两份），无需外网。
const SCHEME_INDEX : String = "<!doctype html><html><head><meta charset=\"utf-8\"><title>本地协议首页</title><link rel=\"stylesheet\" href=\"style.css\"></head><body><h1>yuedemo:// 本地协议页</h1><p class=\"lead\">这一页和它的样式表都由 <code>yuedemo://local/</code> 协议供给，目录在系统临时区，不落在仓库里。</p><div class=\"card\"><button onclick=\"callNative()\">JS 调原生绑定</button><button onclick=\"location.href='page2.html'\">去第二页</button><p id=\"r\" class=\"note\">点了按钮，回包会出现在窗口底部状态栏。</p></div><script>function callNative(){var r=document.getElementById('r');try{demoBinding('来自协议页的调用');r.textContent='已调用原生绑定（看窗口底部状态栏）';}catch(e){r.textContent='原生绑定不在位：'+e.message;}}</script></body></html>"

///|
const SCHEME_PAGE2 : String = "<!doctype html><html><head><meta charset=\"utf-8\"><title>协议第二页</title><link rel=\"stylesheet\" href=\"style.css\"></head><body><h1>第二页</h1><p class=\"lead\">用来验证会话内历史：现在点「←」能回首页。</p><p><a href=\"index.html\">回首页</a></p></body></html>"

///|
const SCHEME_CSS : String = "body{font-family:sans-serif;margin:24px auto;max-width:560px;color:#222}h1{font-size:22px}.lead{color:#555;line-height:1.6}.card{border:1px solid #d5d9e0;border-radius:8px;padding:14px;margin-top:16px}button{font-size:14px;padding:6px 14px;margin-right:8px;border:1px solid #b0b6c0;border-radius:6px;background:#f5f7fa;cursor:pointer}button:hover{background:#e8ecf2}.note{color:#888;font-size:13px;margin-top:10px}a{color:#0366d6}"

///|
/// 本地 HTML 片段（load_html 装的页面**不入历史**）。
const LOCAL_HTML : String = "<html><head><meta charset=\"utf-8\"><title>本地片段</title></head><body style='font-family:sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%'><h3>load_html 本地片段 ✓</h3><button onclick=\"callNative()\">JS 调原生绑定</button><p id='r' style='color:#888'></p><script>function callNative(){var r=document.getElementById('r');try{demoBinding('来自网页的调用');r.textContent='已调用原生绑定（看窗口底部状态栏）';}catch(e){r.textContent='原生绑定不在位：'+e.message;}}</script></body></html>"

///|
/// 首页地址。
const HOME_URL : String = "yuedemo://local/index.html"

///|
/// 按码点截断到前 n 个字符（超出补省略号），状态栏单行用。
fn clip(s : String, n : Int) -> String {
  if s.length() <= n {
    return s
  }
  let buf = StringBuilder()
  let mut i = 0
  for ch in s {
    if i >= n {
      break
    }
    buf.write_char(ch)
    i = i + 1
  }
  buf.write_string("…")
  buf.to_string()
}

///|
/// 加载状态（决定状态栏标签的语义色）：0 就绪 / 1 加载中 / 2 完成 / 3 失败。
priv enum LoadKind {
  Ready
  Loading
  Done
  Failed
}

///|
fn main {
  let toast = @ui.toast_layer(duration_ms=2200)
  // 状态区四条线：加载标签（编码「kind|文本」，bind_node 重建换语义色）、
  // 常驻 URL 与标题、事件流水、能力结果（截断 + 可展开）
  let url_in : @base.Store[String] = @base.Store::new(HOME_URL)
  let status : @base.Store[String] = @base.Store::new("0|就绪")
  let cur_url : @base.Store[String] = @base.Store::new(HOME_URL)
  let title_st : @base.Store[String] = @base.Store::new("（无标题）")
  let ev_count : @base.Store[Int] = @base.Store::new(0)
  let ev_line : @base.Store[String] = @base.Store::new("（事件流水显示在此）")
  let result_full : @base.Store[String] = @base.Store::new("（能力结果显示在此）")
  let result_open : @base.Store[Bool] = @base.Store::new(false)
  let result_view : @base.Store[String] = @base.Store::new("（能力结果显示在此）")
  let wv : Ref[@web.Webview?] = Ref(None)
  let holder : Ref[@widget.Widget?] = Ref(None)
  // 三类策略的当前档（false = 拦截；启动排期重试时统一落到拦截）
  let pol_newwin : Ref[Bool] = Ref(false)
  let pol_perm : Ref[Bool] = Ref(false)
  let pol_dl : Ref[Bool] = Ref(false)
  let ev_no : Ref[Int] = Ref(0)
  fn set_status(k : LoadKind, text : String) -> Unit {
    let tag = match k {
      Ready => "0"
      Loading => "1"
      Done => "2"
      Failed => "3"
    }
    status.set(tag + "|" + text)
  }
  fn ev(text : String) -> Unit {
    ev_no.val = ev_no.val + 1
    ev_count.set(ev_no.val)
    ev_line.set(clip(text, 150))
  }
  fn sync_result_view() -> Unit {
    let full = result_full.get()
    result_view.set(
      if result_open.get() || full.length() <= 150 { full } else { clip(full, 150) },
    )
  }
  result_full.subscribe(fn(_s) { sync_result_view() })
  result_open.subscribe(fn(_b) { sync_result_view() })
  fn show_result(full : String) -> Unit {
    result_open.set(false)
    result_full.set(full)
  }
  fn nav_to(u : String) -> Unit {
    match wv.val {
      Some(v) => {
        v.load_url(u)
        set_status(Loading, "加载中")
        ev("导航开始 \{u}")
      }
      None => ()
    }
  }
  fn load_current() -> Unit {
    let u = url_in.get()
    if u.length() == 0 {
      return
    }
    nav_to(u)
  }
  /// 写协议页文件并注册协议；返回是否就绪。
  fn prepare_scheme(v : @web.Webview) -> Bool {
    let root = scheme_root()
    let _ = @sys.sys_make_dirs(root)
    let a = @sys.sys_write_text_file(root + "/index.html", SCHEME_INDEX)
    let b = @sys.sys_write_text_file(root + "/page2.html", SCHEME_PAGE2)
    let c = @sys.sys_write_text_file(root + "/style.css", SCHEME_CSS)
    a && b && c && v.register_protocol("yuedemo", root)
  }
  /// 三档策略当前态的可读串（策略切换后整组回显）。
  fn policy_text() -> String {
    let nw = if pol_newwin.val { "放行" } else { "拦截" }
    let pm = if pol_perm.val { "放行" } else { "拦截" }
    let dl = if pol_dl.val { "放行" } else { "拦截" }
    "新窗：\{nw}\n权限：\{pm}\n下载：\{dl}"
  }

  // scheme 预声明：建第一扇 webview 前的最后声明机会（三平台取严）
  let _ = @web.webview_predeclare_schemes(["yuedemo"])

  let body = @ui.col(
    [
      // 工具栏：导航键 + 地址栏 + 进入 + 演示菜单
      @ui.row(
        [
          @ui.button("←", on_click=fn() {
            match wv.val {
              Some(v) =>
                if v.can_go_back() {
                  v.go_back()
                  ev("后退 → \{clip(v.current_url(), 90)}")
                } else {
                  ev("后退：无处可退（can_go_back=0；load_html 的页面不入历史）")
                }
              None => ()
            }
          }),
          @ui.button("→", variant=@ui.Soft, on_click=fn() {
            match wv.val {
              Some(v) =>
                if v.can_go_forward() {
                  v.go_forward()
                  ev("前进 → \{clip(v.current_url(), 90)}")
                } else {
                  ev("前进：无可前进项（can_go_forward=0）")
                }
              None => ()
            }
          }),
          @ui.button("⟳ 重载", variant=@ui.Soft, on_click=fn() {
            match wv.val {
              Some(v) => {
                v.reload()
                set_status(Loading, "加载中")
              }
              None => ()
            }
          }),
          @ui.button("✕ 停止", variant=@ui.Text, on_click=fn() {
            match wv.val {
              Some(v) => {
                v.stop()
                set_status(Ready, "已停止")
              }
              None => ()
            }
          }),
          @ui.input(
            url_in,
            placeholder="输入 URL，回车或点「进入」加载",
            on_enter=load_current,
            handle=fn(w) { w.node.set_flex_grow(1.0) },
          ),
          @ui.button("进入", variant=@ui.Solid, on_click=load_current),
          @ui.dropdown(
            "演示 ▾",
            [
              "example.com（需外网）",
              "本地协议页 yuedemo://",
              "本地 HTML 片段",
              "拒绝路径演示",
              "-",
              "JS 互操作三连",
              "DOM 抓取·正文",
              "DOM 抓取·链接",
              "DOM 抓取·meta",
              "DOM 抓取·结构",
              "Cookie 查询",
              "原生绑定 注册/移除",
              "-",
              "策略·新窗切换",
              "策略·权限切换",
              "策略·下载切换",
            ],
            on_select=fn(i : Int) {
              match wv.val {
                Some(v) =>
                  if i == 0 {
                    nav_to("https://example.com")
                  } else if i == 1 {
                    if prepare_scheme(v) {
                      nav_to(HOME_URL)
                      show_result("已注册 yuedemo:// 并加载首页（HTML+CSS+第二页都走协议）")
                    } else {
                      show_result("协议未就绪（文件写失败或引擎不支持）")
                    }
                  } else if i == 2 {
                    v.load_html(LOCAL_HTML)
                    set_status(Ready, "本地片段")
                    ev("load_html 完成（此页不入历史，后退无效）")
                  } else if i == 3 {
                    let _ = v.unregister_protocol("yuedemo")
                    v.load_url(HOME_URL)
                    ev("已注销协议并重载（等加载失败事件）")
                  } else if i == 5 {
                    // JS 互操作三连：回包顺序不定，逐条累积进结果区
                    let lines : Array[String] = ["JS 互操作三连："]
                    let add = fn(tag : String, r : String) -> Unit {
                      lines.push(tag + r)
                      show_result(lines.join("\n"))
                    }
                    let _ = v
                      .execute_javascript_with_result(
                        "1 + 41",
                        fn(r : String) -> Unit { add("1+41 回包：", r) },
                      )
                    let _ = v
                      .execute_javascript_with_result(
                        "document.title",
                        fn(r : String) -> Unit { add("document.title：", r) },
                      )
                    v.execute_javascript("document.title='由原生改写 ✓'")
                    add("已执行：", "document.title='由原生改写 ✓'（看标题回显）")
                  } else if i == 6 {
                    let _ = v
                      .capture_dom(@web.PageText, fn(s : @web.DomSnapshot) -> Unit {
                        show_result(
                          "正文 ok=\{s.ok} 标题=\{s.title}，正文 \{s.text.length()} 字符\n\n\{s.text}",
                        )
                      })
                  } else if i == 7 {
                    let _ = v
                      .capture_dom(@web.Links, fn(s : @web.DomSnapshot) -> Unit {
                        let buf = StringBuilder()
                        buf.write_string("链接 ok=\{s.ok} 共 \{s.links.length()} 条\n")
                        for l in s.links {
                          buf.write_string("· \{clip(l.text, 40)} → \{l.href}\n")
                        }
                        show_result(buf.to_string())
                      })
                  } else if i == 8 {
                    let _ = v
                      .capture_dom(@web.Meta, fn(s : @web.DomSnapshot) -> Unit {
                        let buf = StringBuilder()
                        buf.write_string("meta ok=\{s.ok} 共 \{s.meta.length()} 条\n")
                        for kv in s.meta {
                          buf.write_string("· \{kv.0} = \{clip(kv.1, 80)}\n")
                        }
                        show_result(buf.to_string())
                      })
                  } else if i == 9 {
                    let _ = v
                      .capture_dom(@web.Structure, fn(s : @web.DomSnapshot) -> Unit {
                        show_result(
                          "结构 ok=\{s.ok} 元素=\{s.elements} 标题=\{s.title} 链接=\{s.links.length()} meta=\{s.meta.length()}",
                        )
                      })
                  } else if i == 10 {
                    let u = v.current_url()
                    v.get_cookies_for_url(u)
                    show_result("已请求 \{u} 的 Cookie（回包走事件通道，到达后显示在这里）")
                  } else if i == 11 {
                    if v.has_bindings() {
                      show_result(
                        if v.remove_binding("demoBinding") {
                          "已移除 demoBinding（has_bindings=\{v.has_bindings()}）；网页里点「JS 调原生绑定」会走 JS 兜底提示"
                        } else {
                          "移除未生效"
                        },
                      )
                    } else {
                      show_result(
                        if v.add_raw_binding("demoBinding") {
                          "已注册 demoBinding；网页里点「JS 调原生绑定」，回包进结果区"
                        } else {
                          "注册未生效（pane 未挂载？）"
                        },
                      )
                    }
                  } else if i == 13 {
                    pol_newwin.val = !pol_newwin.val
                    v.set_new_window_policy(pol_newwin.val)
                    show_result("策略切换完成\n\{policy_text()}")
                  } else if i == 14 {
                    pol_perm.val = !pol_perm.val
                    v.set_permission_mode(pol_perm.val)
                    show_result("策略切换完成\n\{policy_text()}")
                  } else if i == 15 {
                    pol_dl.val = !pol_dl.val
                    v.set_download_mode(pol_dl.val)
                    show_result("策略切换完成\n\{policy_text()}")
                  } else {
                    ()
                  }
                None => show_result("webview 未就绪，演示不可用（引擎不在位？）")
              }
            },
            width=208.0,
          ),
        ],
        column_gap=6.0,
        padding=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
      // webview 主体（建好后 mount 进来；引擎不在位则降级说明板）
      @ui.col([], grow=1.0, handle=fn(c) { holder.val = Some(c) }),
      // 状态栏：常驻加载状态与 URL / 事件流水 / 结果区（截断 + 展开 + 复制）
      @ui.col(
        [
          @ui.row(
            [
              @widget.bind_node(
                status.signal(),
                fn(s : String) -> @widget.Node {
                  // 编码形如「k|文本」：首字符是状态档，其余是文本
                  let tag = s[:1]
                  let text = s[2:].to_owned()
                  let t : @ui.SemanticType = if tag == "1" {
                    @ui.Primary
                  } else if tag == "2" {
                    @ui.Success
                  } else if tag == "3" {
                    @ui.Danger
                  } else {
                    @ui.Info
                  }
                  @ui.tag_of_type(
                    if tag == "1" { "加载中" } else { text },
                    t,
                  )
                },
              ),
              @ui.bind_label(cur_url, fn(s) { clip(s, 96) }, handle=fn(w) {
                w.node.set_flex_grow(1.0)
              }),
              @ui.bind_label(title_st, fn(s) { clip(s, 40) }, font_size=12.0, color="text_secondary"),
            ],
            column_gap=8.0,
            align_items=@yoga.AlignItems::Center,
          ),
          @ui.row(
            [
              @ui.bind_label(ev_count, fn(n) { "事件\{n}" }, font_size=12.0, color="text_secondary"),
              @ui.bind_label(ev_line, fn(s) { s }, font_size=12.0),
            ],
            column_gap=8.0,
            align_items=@yoga.AlignItems::Center,
          ),
          @ui.row(
            [
              @ui.text("结果", role=@ui.Secondary, font_size=12.0),
              @ui.text_dyn(
                result_view.signal(),
                font_size=12.0,
                wrap=true,
                max_width=820.0,
                handle=fn(w) { w.node.set_flex_grow(1.0) },
              ),
              @widget.bind_node(
                result_open.signal(),
                fn(open : Bool) -> @widget.Node {
                  @ui.button(
                    if open { "收起" } else { "展开" },
                    variant=@ui.Text,
                    on_click=fn() { result_open.set(!result_open.get()) },
                  )
                },
              ),
              @ui.button("复制", variant=@ui.Text, on_click=fn() {
                let _ = @sys.clipboard_set_text(result_full.get())
                toast("结果已复制 ✓", @ui.Success)
              }),
            ],
            column_gap=8.0,
            align_items=@yoga.AlignItems::Center,
          ),
        ],
        padding=8.0,
        row_gap=4.0,
      ),
    ],
    grow=1.0,
  )
  let mounted = @ui.mount_window(
    [body],
    title="浏览器示例",
    width=1120,
    height=780,
    handle=fn(a : @widget.App) {
      // webview 建在首帧之后（宿主循环已跑、窗口已上屏，与 showcase 旧页
      // 「选中页才建」的时机同口径）
      let _ = a.timer(0, fn() -> Unit {
        match @web.webview_new(a, "about:blank") {
          Some(v) => {
            wv.val = Some(v)
            v.on_event = Some(fn(e : @web.WebEvent) -> Unit {
              match e {
                @web.TitleChanged(t) => title_st.set(t)
                @web.UrlChanged(u) => cur_url.set(u)
                @web.NavStarted(u) => {
                  set_status(Loading, "加载中")
                  ev("导航开始 \{clip(u, 100)}")
                }
                @web.NavCommitted(u) => {
                  cur_url.set(u)
                  url_in.set(u)
                  ev("导航提交 \{clip(u, 100)}")
                }
                @web.NavRedirected(u) => ev("重定向 \{clip(u, 100)}")
                @web.NavFinished(u) => {
                  set_status(Done, "完成")
                  ev("导航完成 \{clip(u, 100)}")
                }
                @web.LoadFailed(raw) => {
                  set_status(Failed, "加载失败")
                  let reason = match @web.nav_error_parse(raw) {
                    None => raw
                    Some(ne) => "\{ne.domain}/\{ne.code} \{ne.uri}"
                  }
                  ev("加载失败 \{clip(raw, 100)}")
                  show_result("加载失败（结构化原因）\n\{reason}\n\n原始载荷：\n\{raw}")
                }
                @web.NewWindow(u) => {
                  ev("新窗请求被策略拦下")
                  show_result("新窗请求（默认拦下）：\n\{u}\n\n当前策略：\n\{policy_text()}")
                }
                @web.Permission(c) => {
                  ev("权限请求被策略拒绝")
                  show_result("权限请求（默认拒绝）：\{c}\n\n当前策略：\n\{policy_text()}")
                }
                @web.Download(d) => {
                  ev("下载被策略拦下")
                  show_result("下载请求（默认拦下）：\{d}\n\n当前策略：\n\{policy_text()}")
                }
                @web.Cookies(j) =>
                  show_result("Cookie 回包（\{j.length()} 字节）\n\{j}")
                @web.ProcessTerminated(r) => {
                  set_status(Failed, "渲染进程退出")
                  ev("渲染进程退出 \{clip(r, 100)}")
                }
                _ => ()
              }
            })
            v.on_invoke = Some(fn(payload : String) -> Unit {
              show_result("网页 → 原生（raw binding demoBinding）\n\{payload}")
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
                v.set_new_window_policy(pol_newwin.val)
                v.set_permission_mode(pol_perm.val)
                v.set_download_mode(pol_dl.val)
              } else {
                tries.val = tries.val + 1
                if tries.val < 60 {
                  let _ = a.timer(80, tick.val)
                }
              }
            }
            let _ = a.timer(80, tick.val)
            // 首页：本地协议页（无需外网）；协议就绪失败则停在 about:blank
            if prepare_scheme(v) {
              v.load_url(HOME_URL)
              set_status(Loading, "加载中")
            } else {
              set_status(Ready, "协议注册失败，请在演示菜单重试或输入 URL")
              ev("协议注册失败（prepare_scheme=0）")
            }
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
