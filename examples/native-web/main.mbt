// examples/native-web —— webview 与媒体的**累积**验证示例（批 B 起建，同族不另开页）。
//
// 跑法：`moon run examples/native-web`（需显示服务）。45 秒后自动退出并打印
// `NATIVE-WEB-STAT` / `NATIVE-WEB-GEO` 两行，字段与屏上读数一一对应。
//
// 本批验的是**两种摆法同源**：整页（Tauri-like，单 pane 铺满）与左右分栏（原生
// 工具栏/侧栏 + 页面区）。页面区是窗口层的原生子件，不吃 `clip_rect`、恒覆盖在
// 自绘像素之上；两侧不重叠由布局保证。引擎不在位时（缺 webkit2gtk-4.1 或别的
// 平台）走**探测 + 降级**：画一块自绘面板说清原因，不静默。

///|
fn rect_str(r : @core.Rect) -> String {
  "\{r.x.round().to_int()},\{r.y.round().to_int()},\{r.w.round().to_int()}x\{r.h.round().to_int()}"
}

///|
fn main {
  let app = match @core.App::new(1100, 700, "MoonBit Webview (批 B)") {
    Some(a) => a
    None => {
      println("NATIVE-WEB-SKIP: 本平台无窗口后端或没有显示服务")
      return
    }
  }
  let root = app.root
  root.set_column()
  root.set_padding(12.0, 10.0)
  root.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
    p.set_fill_color(@theme.theme_bg_page())
    p.fill_rect(0.0, 0.0, r.w, r.h)
  })
  let supported = @web.webview_supported()
  let wv = if supported { @web.webview_new(app, "https://example.com/") } else { None }
  let addr = @core.Store::new("https://example.com/")
  let loads = Ref(0)
  let clicks = Ref(0)
  let mode_full = Ref(false)
  let sidebar_w : Ref[@core.Widget?] = Ref(None)
  let pane_w : Ref[@core.Widget?] = Ref(None)
  let _ = app.focus.register(31)

  // 顶部工具条（原生区）：地址 + 载入/重载/停止 + 摆法切换
  app.mount([
    @ui.label("webview pane（批 B）：一窗多区，每区一个 owner", size=15.0),
    @ui.container(
      [
        @ui.entry(addr, placeholder="地址", focus_id=31, width=420.0),
        @ui.button(
          "载入",
          on_click=fn() {
            match wv {
              Some(v) => {
                v.load_url(addr.get())
                loads.val = loads.val + 1
              }
              None => ()
            }
          },
          min_width=76.0,
        ),
        @ui.button(
          "重载",
          on_click=fn() {
            match wv {
              Some(v) => v.reload()
              None => ()
            }
          },
          min_width=76.0,
        ),
        @ui.button(
          "停止",
          on_click=fn() {
            match wv {
              Some(v) => v.stop()
              None => ()
            }
          },
          min_width=76.0,
        ),
        @ui.button(
          "整页 / 分栏",
          on_click=fn() {
            clicks.val = clicks.val + 1
            mode_full.val = !mode_full.val
            match sidebar_w.val {
              Some(w) => w.set_visible(!mode_full.val)
              None => ()
            }
          },
          min_width=120.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=8.0,
      padding=6.0,
      bg=@theme.theme_bg_panel(),
      border=@theme.theme_border(),
      align_items=@yoga.AlignItems::Center,
    ),
  ])

  // ---- 批 C：JS 桥 + DOM 抓取 + 导航面 ----
  // 另开一窗装一份**本地页**（load_html，不依赖网络），页面上有链接、新窗链接、
  // 权限请求、页面回话四类触发点；原生侧一排按钮逐条按。计数在退出行里回证。
  let js_evals = Ref(0)
  let js_dom_ok = Ref(0)
  let js_dom_bad = Ref(0)
  let js_links = Ref(0)
  let js_invokes = Ref(0)
  let js_navs = Ref(0)
  let js_perms = Ref(0)
  let js_wins = Ref(0)
  let js_crashes = Ref(0)
  let js_cookie_bytes = Ref(0)
  let js_text_bytes = Ref(0)
  let js_meta = Ref(0)
  let js_headings = Ref(0)
  let js_elements = Ref(0)
  let js_binding = Ref(false)
  let js_last = Ref("")
  let bridge_log : Ref[Array[String]] = Ref([])
  let bridge_lines_w : Ref[@core.Widget?] = Ref(None)
  let note = fn(t : String) -> Unit {
    let l = bridge_log.val
    l.push(t)
    while l.length() > 6 {
      let _ = l.remove(0)
    }
    bridge_log.val = l
  }
  let bridge_html =
    "<!doctype html><html><head>" +
    "<meta name=\"description\" content=\"本地桥接页\">" +
    "<title>本地桥接页</title></head><body>" +
    "<h1>桥接页大标题</h1><h2>二级标题</h2>" +
    "<p id=\"p\">第一段正文，用来验 innerText 真取到渲染后的内容。</p>" +
    "<a href=\"https://a.example/1\">链接甲</a>" +
    "<a href=\"https://b.example/2\" target=\"_blank\">新窗链接乙</a>" +
    "<a href=\"#x\">链接丙</a>" +
    "<p><button onclick=\"native_echo({msg:'来自页面',n:7})\">让页面回话</button>" +
    "<button onclick=\"if(navigator.geolocation){navigator.geolocation" +
    ".getCurrentPosition(function(){},function(){})}\">要定位权限</button></p>" +
    "</body></html>"

  let open_bridge = fn(a : @core.App) -> Unit {
    match a.open_window(1000, 700, "JS 桥与抓取（批 C）") {
      None => ()
      Some(win) => {
        win.root.set_column()
        win.root.set_padding(12.0, 10.0)
        win.root.on_draw = Some(fn(
          _w : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(@theme.theme_bg_page())
          p.fill_rect(0.0, 0.0, r.w, r.h)
        })
        match @web.webview_open(win, @web.webview_options("about:blank")) {
          None => win.mount([
            @ui.label("webview 引擎不在位：批 C 的桥接面需要 webkit2gtk-4.1", size=13.0),
          ])
          Some(v) => {
            v.on_event = Some(fn(e : @web.WebEvent) -> Unit {
              match e {
                @web.NavStarted(u) => {
                  js_navs.val = js_navs.val + 1
                  note("导航开始 " + u)
                }
                @web.TitleChanged(t) => js_last.val = "标题 " + t
                @web.Permission(cls) => {
                  js_perms.val = js_perms.val + 1
                  note("权限请求（默认拒绝）" + cls)
                }
                @web.NewWindow(u) => {
                  js_wins.val = js_wins.val + 1
                  note("新窗请求已拦下 " + u)
                }
                @web.Download(u) => note("下载 " + u)
                @web.ProcessTerminated(why) => {
                  js_crashes.val = js_crashes.val + 1
                  note("web 进程终止 " + why)
                }
                @web.Cookies(j) => {
                  js_cookie_bytes.val = j.length()
                  note("cookie 回包 " + j)
                }
                _ => ()
              }
            })
            v.on_invoke = Some(fn(payload : String) -> Unit {
              js_invokes.val = js_invokes.val + 1
              js_last.val = "invoke " + payload
              note("页面回话 " + payload)
            })
            let snap = fn(k : @web.DomKind, tag : String) -> Unit {
              let _ = v.capture_dom(k, fn(s : @web.DomSnapshot) -> Unit {
                if s.ok {
                  js_dom_ok.val = js_dom_ok.val + 1
                } else {
                  js_dom_bad.val = js_dom_bad.val + 1
                }
                // 各档抓到的量取峰值：最后一档（结构）没有正文与链接，覆盖会把
                // 前面几档的回证冲掉
                if s.text.length() > js_text_bytes.val {
                  js_text_bytes.val = s.text.length()
                }
                if s.links.length() > js_links.val {
                  js_links.val = s.links.length()
                }
                if s.meta.length() > js_meta.val {
                  js_meta.val = s.meta.length()
                }
                if s.headings.length() > js_headings.val {
                  js_headings.val = s.headings.length()
                }
                if s.elements > js_elements.val {
                  js_elements.val = s.elements
                }
                note(
                  tag +
                    " ok=" +
                    (if s.ok { "1" } else { "0" }) +
                    " title=" +
                    s.title +
                    " 链接=" +
                    s.links.length().to_string() +
                    " 元素=" +
                    s.elements.to_string(),
                )
              })
            }
            win.mount([
              @ui.container(
                [
                  @ui.button(
                    "抓正文",
                    on_click=fn() { snap(@web.PageText, "抓正文") },
                    min_width=72.0,
                  ),
                  @ui.button(
                    "抓链接",
                    on_click=fn() { snap(@web.Links, "抓链接") },
                    min_width=72.0,
                  ),
                  @ui.button(
                    "抓 meta",
                    on_click=fn() { snap(@web.Meta, "抓 meta") },
                    min_width=72.0,
                  ),
                  @ui.button(
                    "抓结构",
                    on_click=fn() { snap(@web.Structure, "抓结构") },
                    min_width=72.0,
                  ),
                  @ui.button(
                    "求值标题",
                    on_click=fn() {
                      let _ = v.execute_javascript_with_result(
                        "document.title",
                        fn(r : String) -> Unit {
                          js_evals.val = js_evals.val + 1
                          js_last.val = "eval " + r
                          note("求值回包 " + r)
                        },
                      )
                    },
                    min_width=84.0,
                  ),
                  @ui.button(
                    "原生改文本",
                    on_click=fn() {
                      v.execute_javascript(
                        "document.getElementById('p').textContent='已被原生改过'",
                      )
                      note("已下发改文本的 JS")
                    },
                    min_width=96.0,
                  ),
                  @ui.button(
                    "读 cookie",
                    on_click=fn() {
                      v.get_cookies_for_url("https://local.test/")
                      note("已请求 cookie")
                    },
                    min_width=84.0,
                  ),
                  @ui.button(
                    "后退",
                    on_click=fn() {
                      note("can_go_back=" + (if v.can_go_back() { "1" } else { "0" }))
                      v.go_back()
                    },
                    min_width=64.0,
                  ),
                  @ui.button(
                    "前进",
                    on_click=fn() { v.go_forward() },
                    min_width=64.0,
                  ),
                ],
                direction=@yoga.Row,
                column_gap=6.0,
                padding=6.0,
                bg=@theme.theme_bg_panel(),
                border=@theme.theme_border(),
              ),
              @ui.container(
                [v.node(grow=1.0)],
                grow=1.0,
                bg=@theme.theme_bg_panel(),
                border=@theme.theme_border(),
              ),
            ])
            v.load_html(bridge_html, base_uri="https://local.test/")
            // 绑定与策略要有句柄才生效（挂载发生在第一次绘制），排期重试
            let tries = Ref(0)
            let tick : Ref[() -> Unit] = Ref(fn() { () })
            tick.val = fn() -> Unit {
              if !win.is_running() || js_binding.val {
                return
              }
              if v.add_raw_binding("native_echo") {
                v.set_new_window_policy(false)
                v.set_permission_mode(false)
                js_binding.val = true
                note("native_echo 已注册")
              } else {
                tries.val = tries.val + 1
              }
              if tries.val < 60 {
                let _ = win.timer(80, tick.val)
              }
            }
            let _ = win.timer(80, tick.val)
          }
        }
        // 事件流水（自绘那一条区，owner=Painter）
        let lines = @core.Widget::new()
        lines.node.set_height(@yoga.fixed(112.0))
        lines.on_draw = Some(fn(
          _w : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(@theme.theme_bg_page())
          p.fill_rect(0.0, 0.0, r.w, r.h)
          p.flush()
          let items = bridge_log.val
          let n = if items.length() > 6 { 6 } else { items.length() }
          for i = 0; i < n; i = i + 1 {
            let _ = @text.draw_text_at(
              p,
              6.0,
              (i.to_double() * 17.0),
              items[items.length() - n + i],
              12.0,
              @theme.theme_text_primary(),
            )
          }
        })
        bridge_lines_w.val = Some(lines)
        win.mount([@core.node_of(lines)])
      }
    }
  }
  app.mount([
    @ui.container(
      [
        @ui.label("批 C：JS 桥 / DOM 抓取 / 导航面（另开一窗，装本地页）", size=13.0),
        @ui.button(
          "开一扇桥接窗",
          on_click=fn() { open_bridge(app) },
          min_width=140.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      padding=6.0,
      bg=@theme.theme_bg_panel(),
      border=@theme.theme_border(),
      align_items=@yoga.AlignItems::Center,
    ),
  ])
  match wv {
    None => {
      // 探测不到引擎：自绘一块说明板（降级不静默）
      app.mount([
        @ui.container(
          [
            @ui.label("webview 引擎不在位", size=14.0),
            @ui.label(
              "本机缺 webkit2gtk-4.1（或非 Linux 平台）。pane 通道本身可用，" +
                "页面区改画自绘内容；装上引擎后本页自动走 webview 分支。",
              size=12.0,
            ),
          ],
          padding=12.0,
          grow=1.0,
          bg=@theme.theme_bg_panel(),
          border=@theme.theme_border(),
        ),
      ])
    }
    Some(v) => {
      app.mount([
        @ui.container(
          [
            @ui.container(
              [
                @ui.label("原生侧栏", size=13.0),
                @ui.label("owner = 自绘 Painter", size=12.0),
                @ui.label("这一侧的矩形与页面区不重叠", size=12.0),
              ],
              width=240.0,
              padding=10.0,
              row_gap=6.0,
              bg=@theme.theme_bg_page(),
              border=@theme.theme_border(),
              handle=fn(w : @core.Widget) -> Unit { sidebar_w.val = Some(w) },
            ),
            @ui.container(
              [v.node(grow=1.0)],
              grow=1.0,
              padding=0.0,
              bg=@theme.theme_bg_panel(),
              border=@theme.theme_border(),
              handle=fn(w : @core.Widget) -> Unit { pane_w.val = Some(w) },
            ),
          ],
          direction=@yoga.Row,
          column_gap=10.0,
          grow=1.0,
        ),
      ])
    }
  }

  // 状态行：每帧现读（页面标题/地址/是否还在加载 + 两个计数）
  let status = @core.Widget::new()
  status.node.set_height(@yoga.fixed(24.0))
  status.on_draw = Some(fn(
    _w : @core.Widget,
    p : @render.Painter,
    _r : @core.Rect,
  ) -> Unit {
    p.flush()
    let line = match wv {
      None => "supported=0"
      Some(v) =>
        "supported=1 loading=" +
        (if v.is_loading() { "1" } else { "0" }) +
        " title='" +
        v.get_title() +
        "' url='" +
        v.current_url() +
        "'"
    }
    let _ = @text.draw_text_at(
      p,
      0.0,
      0.0,
      line +
        " loads=" +
        loads.val.to_string() +
        " toggles=" +
        clicks.val.to_string() +
        " mode=" +
        (if mode_full.val { "整页" } else { "分栏" }),
      13.0,
      @theme.theme_text_primary(),
    )
  })
  root.append_child(status)

  let ticker : Ref[() -> Unit] = Ref(fn() { () })
  ticker.val = fn() -> Unit {
    if app.is_running() {
      app.schedule_paint()
      let _ = app.timer(120, ticker.val)
    }
  }
  let _ = app.timer(120, ticker.val)
  // 冒烟自杀点：批 C 要开第二窗、等绑定注册、再逐条按抓取/回话/权限/新窗，
  // 20 秒走不完一轮，放宽到 45 秒（仍是无人值守冒烟）
  let _ = app.timer(45000, fn() { app.quit() })
  app.run()

  let pane_rect = match pane_w.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let side_rect = match sidebar_w.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let (loading, title, url) = match wv {
    None => (false, "", "")
    Some(v) => (v.is_loading(), v.get_title(), v.current_url())
  }
  match wv {
    Some(v) => v.close()
    None => ()
  }
  println(
    "NATIVE-WEB-STAT supported=" +
      (if supported { "1" } else { "0" }) +
      " loads=" +
      loads.val.to_string() +
      " toggles=" +
      clicks.val.to_string() +
      " mode=" +
      (if mode_full.val { "full" } else { "split" }) +
      " loading=" +
      (if loading { "1" } else { "0" }) +
      " title='" +
      title +
      "' url='" +
      url +
      "'",
  )
  println("NATIVE-WEB-GEO pane=" + pane_rect + " sidebar=" + side_rect)
  println(
    "NATIVE-WEB-JS binding=" +
      (if js_binding.val { "1" } else { "0" }) +
      " evals=" +
      js_evals.val.to_string() +
      " dom_ok=" +
      js_dom_ok.val.to_string() +
      " dom_bad=" +
      js_dom_bad.val.to_string() +
      " links=" +
      js_links.val.to_string() +
      " text_bytes=" +
      js_text_bytes.val.to_string() +
      " meta=" +
      js_meta.val.to_string() +
      " headings=" +
      js_headings.val.to_string() +
      " elements=" +
      js_elements.val.to_string() +
      " invokes=" +
      js_invokes.val.to_string() +
      " navs=" +
      js_navs.val.to_string() +
      " perms=" +
      js_perms.val.to_string() +
      " wins=" +
      js_wins.val.to_string() +
      " crashes=" +
      js_crashes.val.to_string() +
      " cookie_bytes=" +
      js_cookie_bytes.val.to_string() +
      " last='" +
      js_last.val +
      "'",
  )
  app.shutdown()
}
