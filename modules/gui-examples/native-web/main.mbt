// modules/gui-examples/native-web —— webview 与媒体的**累积**验证示例（批 B 起建，同族不另开页）。
//
// 跑法：`moon run modules/gui-examples/native-web`（需显示服务）。45 秒后自动退出并打印
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
  root.set_padding(top=10.0, left=12.0)
  root.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
    p.set_fill_color(@theme.theme_bg_page())
    p.fill_rect(0.0, 0.0, r.w, r.h)
  })
  let supported = @web.webview_supported()
  // 本地内容通道的 scheme 名要在建第一扇 webview 之前声明（三平台取严：
  // Windows 的名单挂在 environment 上、mac 挂在建视图前的 configuration 上）
  let _ = @web.webview_predeclare_schemes(["yuedemo"])
  let wv = if supported { @web.webview_new(app, "https://example.com/") } else { None }
  // 导航失败的细粒度原因（批 C 余项）：把 load-failed 载荷拆成结构再记账。
  // 「注销协议后重载同一 URL」就是这条通道的回证，所以两个计数分开——
  // 拆不出结构（sc_raw）与真的失败（sc_fail）不能混成一个数。
  let sc_fail = Ref(0)
  let sc_raw = Ref(0)
  let sc_fail_code = Ref(0)
  let sc_fail_domain = Ref("")
  let sc_fail_uri = Ref("")
  match wv {
    None => ()
    Some(v) =>
      v.on_event = Some(fn(e : @web.WebEvent) -> Unit {
        match e {
          @web.LoadFailed(raw) =>
            match @web.nav_error_parse(raw) {
              None => sc_raw.val = sc_raw.val + 1
              Some(ne) => {
                sc_fail.val = sc_fail.val + 1
                sc_fail_code.val = ne.code
                sc_fail_domain.val = ne.domain
                sc_fail_uri.val = ne.uri
              }
            }
          _ => ()
        }
      })
  }
  let addr = @core.Store::new("https://example.com/")
  let loads = Ref(0)
  let clicks = Ref(0)
  let mode_full = Ref(false)
  let sidebar_w : Ref[@core.Widget?] = Ref(None)
  let pane_w : Ref[@core.Widget?] = Ref(None)
  let _ = app.focus.register(31)

  // 顶部工具条（原生区）：地址 + 载入/重载/停止 + 摆法切换
  app.mount([
    @ui.text("webview pane（批 B）：一窗多区，每区一个 owner", font_size=15.0),
    @ui.view(
      [
        @ui.input(addr, placeholder="地址", focus_id=31, width=420.0),
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
      background_color="bg_panel",
      border_color="border",
      align_items=@yoga.AlignItems::Center,
    ),
  ])

  // ---- 批 C：JS 桥 + DOM 抓取 + 导航面 ----
  // 另开一窗装一份**本地页**（走自定义协议，不依赖网络）：页面上有链接、新窗链接、
  // 权限请求、页面回话四类触发点；原生侧一排按钮逐条按。计数在退出行里回证。
  // 本地页给它一条**真 URL**（协议页入历史），前进/后退才有意义——`load_html`
  // 装的页面不入历史，那时「后退」按钮只能是空操作（真机踩过）。
  // 协议根目录两处共用（桥接页 + 下面「批 C 余项」那行），所以定义放在这里。
  let sc_root = "/tmp/native-web-scheme"
  let js_evals = Ref(0)
  let js_dom_ok = Ref(0)
  let js_dom_bad = Ref(0)
  let js_links = Ref(0)
  let js_invokes = Ref(0)
  let js_navs = Ref(0)
  let js_perms = Ref(0)
  let js_wins = Ref(0)
  let js_crashes = Ref(0)
  let js_fails = Ref(0)
  let js_fail_last = Ref("")
  let js_cookie_bytes = Ref(0)
  let js_text_bytes = Ref(0)
  let js_meta = Ref(0)
  let js_headings = Ref(0)
  let js_elements = Ref(0)
  let js_binding = Ref(false)
  let js_last = Ref("")
  let bridge_log : Ref[Array[String]] = Ref([])
  let ov_opens = Ref(0)
  let ov_native = Ref(0)
  let ov_hides = Ref(0)
  let ov_layer = Ref(0)
  let ov_tier = Ref(0)
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
    "<meta charset=\"utf-8\">" +
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
        win.root.set_padding(top=10.0, left=12.0)
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
            @ui.text("webview 引擎不在位：批 C 的桥接面需要 webkit2gtk-4.1", font_size=13.0),
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
                // 失败要给结构化原因（不是只让网页画一张错误页）：点测试页里
                // 指向 a.example / b.example 的链接就会走这条——.example 是保留
                // 域名，DNS 必然失败，正好当这条通道的回证。
                @web.LoadFailed(raw) =>
                  match @web.nav_error_parse(raw) {
                    None => note("加载失败 " + raw)
                    Some(ne) => {
                      js_fails.val = js_fails.val + 1
                      js_fail_last.val =
                        ne.domain + "/" + ne.code.to_string() + " " + ne.uri
                      note(
                        "加载失败 " +
                        ne.domain +
                        "/" +
                        ne.code.to_string() +
                        " " +
                        ne.uri,
                      )
                    }
                  }
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
              @ui.view(
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
                      // 如实说话：load_html 装进来的页面**不入历史**，失败导航
                      // 也不入历史，所以桥接页上 can_go_back 恒 0——这时
                      // go_back() 是空操作。不写清原因，按钮看着就像坏了。
                      if v.can_go_back() {
                        v.go_back()
                        note("后退 → " + v.current_url())
                      } else {
                        note("后退：无处可退（can_go_back=0；load_html 不入历史）")
                      }
                    },
                    min_width=64.0,
                  ),
                  @ui.button(
                    "前进",
                    on_click=fn() {
                      if v.can_go_forward() {
                        v.go_forward()
                        note("前进 → " + v.current_url())
                      } else {
                        note("前进：无可前进项（can_go_forward=0）")
                      }
                    },
                    min_width=64.0,
                  ),
                  @core.node_of(@core.Widget::new()),
                  @ui.button(
                    "浮层盖网页",
                    on_click=fn() {
                      ov_opens.val = ov_opens.val + 1
                      ov_tier.val = if @core.overlay_native_tier() { 1 } else { 0 }
                      let mine = Ref(0)
                      let menu = @core.node_of_new(fn(parent : @core.Widget) -> @core.Widget {
                        let box = @core.Widget::new()
                        box.node.set_position(@yoga.Absolute)
                        box.node.set_width(@yoga.fixed(180.0))
                        box.set_padding(top=6.0, left=6.0)
                        box.node.set_flex_direction(@yoga.Column)
                        box.on_draw = Some(fn(
                          _b : @core.Widget,
                          bp : @render.Painter,
                          br : @core.Rect,
                        ) -> Unit {
                          bp.set_fill_color(@theme.theme_bg_panel())
                          bp.fill_rect(0.0, 0.0, br.w, br.h)
                          bp.set_stroke_color(@theme.theme_border())
                          bp.set_line_width(1.0)
                          bp.stroke_rect(0.0, 0.0, br.w - 1.0, br.h - 1.0)
                        })
                        let _ = @ui
                          .view(
                            [
                              @ui.text("原生档浮层", font_size=12.0),
                              @ui.button(
                                "收起",
                                on_click=fn() {
                                  ov_hides.val = ov_hides.val + 1
                                  @core.overlay_hide(mine.val)
                                },
                                min_width=150.0,
                              ),
                            ],
                            direction=@yoga.Column,
                            row_gap=6.0,
                          )
                          .mount_into(box)
                        parent.append_child(box)
                        box
                      })
                      let cid = @core.overlay_show_at(menu, 240.0, 120.0)
                      mine.val = cid
                      ov_native.val = @core.overlay_native_count()
                      ov_layer.val = if cid > 0 && @core.overlay_native_count() == 0 {
                        1
                      } else {
                        0
                      }
                      note("浮层 cid=" + cid.to_string() + " 原生档=" + (if @core.overlay_native_count() > 0 { "1" } else { "0" }))
                    },
                    min_width=110.0,
                  ),
                ],
                direction=@yoga.Row,
                column_gap=6.0,
                padding=6.0,
                background_color="bg_panel",
                border_color="border",
              ),
              @ui.view(
                [v.node(grow=1.0)],
                grow=1.0,
                background_color="bg_panel",
                border_color="border",
              ),
            ])
            let _ = @sys.sys_make_dirs(sc_root)
            let _ = @sys.sys_write_text_file(sc_root + "/bridge.html", bridge_html)
            // 协议按 context 生效：两扇窗没各给数据目录时共用同一个 context，
            // 主窗那行「注销该协议」会把这里的根目录一并清空（重新注册即恢复）
            if v.register_protocol("yuedemo", sc_root) {
              v.load_url("yuedemo://local/bridge.html")
            } else {
              // 协议没就绪（名字没预声明 / 引擎不在位）：明确降级并写在事件区，
              // 不静默——这条页面上「后退」会退不动，原因得看得见
              note("协议未就绪，退回 load_html（此页不入历史）")
              v.load_html(bridge_html, base_uri="https://local.test/")
            }
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
    @ui.view(
      [
        @ui.text("批 C：JS 桥 / DOM 抓取 / 导航面（另开一窗，装本地页）", font_size=13.0),
        @ui.button(
          "开一扇桥接窗",
          on_click=fn() { open_bridge(app) },
          min_width=140.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      padding=6.0,
      background_color="bg_panel",
      border_color="border",
      align_items=@yoga.AlignItems::Center,
    ),
  ])
  // ---- 批 D：播放器（CPU 回灌 + 软解，帧走 Painter 合成）----
  let md_frames = Ref(0)
  let md_pos = Ref(0.0)
  let md_playing = Ref(0)
  let md_err = Ref("")
  let md_full = Ref(false)
  let md_speed = Ref(1.0)
  let md_subs_n = Ref(0)
  let md_subs_emb = Ref(0)
  let lv_subs_n = Ref(0)
  let md_subs =
    "1\n00:00:00,200 --> 00:00:00,600\n第一条字幕（0.2~0.6 秒）\n\n" +
    "2\n00:00:00,600 --> 00:00:01,000\n第二条字幕（0.6~1.0 秒）\n"
  // `embedded=false` 走外挂字幕文本（调用方喂 SRT）；`embedded=true` 什么都不喂，
  // 组件自己去容器里读内嵌轨——两扇窗同一条渲染路，只差字幕来源
  let open_player = fn(a : @core.App, embedded : Bool) -> Unit {
    let md_path =
      if embedded {
        "modules/ffmpeg-mbt/src/testdata/av_1s_subs.mp4"
      } else {
        "modules/ffmpeg-mbt/src/testdata/av_1s.mp4"
      }
    match a.open_window(720, 480, if embedded {
      "播放器：内嵌字幕轨（批 D2c）"
    } else {
      "播放器（批 D）"
    }) {
      None => ()
      Some(win) => {
        win.root.set_column()
        win.root.set_padding(top=10.0, left=12.0)
        win.root.on_draw = Some(fn(
          _w : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(@theme.theme_bg_page())
          p.fill_rect(0.0, 0.0, r.w, r.h)
        })
        win.mount([
          @ui.text(
            "播放器：ffmpeg 软解出 RGBA → Bitmap → Painter 合成（字幕来源：" +
              (if embedded { "内嵌轨" } else { "外挂文本" }) +
              "）",
            font_size=13.0,
          ),
          @media.player_t(
            md_path,
            subtitle=if embedded { "" } else { md_subs },
            width=680.0,
            height=380.0,
            auto_play=true,
            on_tick=fn(t : Double, frames : Int, playing : Bool) -> Unit {
              if frames > md_frames.val {
                md_frames.val = frames
              }
              if t > md_pos.val {
                md_pos.val = t
              }
              md_playing.val = if playing { 1 } else { 0 }
            },
            on_error=fn(e : String) -> Unit { md_err.val = e },
            on_speed=fn(v : Double) -> Unit { md_speed.val = v },
            on_subtitle=fn(n : Int, emb : Bool) -> Unit {
              md_subs_n.val = n
              md_subs_emb.val = if emb { 1 } else { 0 }
            },
          ),
          // 全屏是窗口级动作：控件层拿不到窗口，由宿主把请求转给 App。
          // 逐帧与音量在控制条里（|< 与 >| 两个键、右侧音量条）。
          @ui.view(
            [
              @ui.button(
                "全屏 / 退出全屏",
                on_click=fn() {
                  md_full.val = !md_full.val
                  win.set_fullscreen(md_full.val)
                },
                min_width=150.0,
              ),
            ],
            direction=@yoga.Row,
            column_gap=10.0,
            padding=6.0,
          ),
        ])
      }
    }
  }
  app.mount([
    @ui.view(
      [
        @ui.text("批 D：媒体播放器（另开一窗，播 ffmpeg 测试片 + 字幕叠加）", font_size=13.0),
        @ui.button(
          "开一扇播放器窗",
          on_click=fn() { open_player(app, false) },
          min_width=140.0,
        ),
        @ui.button(
          "开一扇内嵌字幕窗",
          on_click=fn() { open_player(app, true) },
          min_width=150.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      padding=6.0,
      background_color="bg_panel",
      border_color="border",
      align_items=@yoga.AlignItems::Center,
    ),
  ])

  // ---- 批 D 长素材：本机真视频（存在才开，不存在只报「没素材」不假装能播）----
  // 1 秒测试片只证明得了「链路通」，证明不了连续解码不漂、深跳 seek 追关键帧、
  // 倍速下音画同轴——那些要一支真片子（使用者给的 23 分钟素材）。
  let lv_dir = "/home/lkyh/下载"
  let lv_name = "001.mp4"
  let lv_path = lv_dir + "/" + lv_name
  let lv_present = match @sys.fsx_list_dir(lv_dir) {
    Ok(names) => {
      let mut hit = false
      for n in names {
        if n == lv_name {
          hit = true
        }
      }
      hit
    }
    Err(_) => false
  }
  let lv_frames = Ref(0)
  let lv_pos = Ref(0.0)
  let lv_speed = Ref(1.0)
  let lv_err = Ref("")
  let open_local = fn(a : @core.App) -> Unit {
    match a.open_window(1000, 620, "本地视频（长素材）") {
      None => ()
      Some(win) => {
        win.root.set_column()
        win.root.set_padding(top=10.0, left=12.0)
        win.root.on_draw = Some(fn(
          _w : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(@theme.theme_bg_page())
          p.fill_rect(0.0, 0.0, r.w, r.h)
        })
        win.mount([
          @ui.text("长素材回证：真片子看连续解码 / 深跳 seek / 倍速同轴", font_size=13.0),
          @media.player_t(
            lv_path,
            width=960.0,
            height=500.0,
            auto_play=true,
            on_tick=fn(t : Double, frames : Int, _playing : Bool) -> Unit {
              if frames > lv_frames.val {
                lv_frames.val = frames
              }
              if t > lv_pos.val {
                lv_pos.val = t
              }
            },
            on_speed=fn(v : Double) -> Unit { lv_speed.val = v },
            on_error=fn(e : String) -> Unit { lv_err.val = e },
            on_subtitle=fn(n : Int, _emb : Bool) -> Unit { lv_subs_n.val = n },
          ),
        ])
      }
    }
  }
  app.mount([
    @ui.view(
      [
        @ui.text(
          if lv_present { "批 D 长素材：/home/lkyh/下载/001.mp4（23 分钟）" } else {
            "批 D 长素材：这台机器没有 /home/lkyh/下载/001.mp4"
          },
          font_size=13.0,
        ),
        @ui.button(
          "开一扇本地视频窗",
          on_click=fn() { open_local(app) },
          min_width=150.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      padding=6.0,
      background_color="bg_panel",
      border_color="border",
      align_items=@yoga.AlignItems::Center,
    ),
  ])

  // ---- 批 E：原生弹层窗口（浮层要盖住 webview，只能是真顶层窗）----
  let pop_opens = Ref(0)
  let pop_closed = Ref(0)
  let pop_choice = Ref("")
  let open_menu = fn(a : @core.App) -> Unit {
    // 摆在页面区上方（窗口内 420,300 → 屏幕约 422,334），截图就能看出它压住了网页
    match a.open_popup(420, 300, 240, 150) {
      None => ()
      Some(pop) => {
        pop_opens.val = pop_opens.val + 1
        pop.root.set_column()
        pop.root.set_padding(top=8.0, left=8.0)
        pop.root.on_draw = Some(fn(
          _w : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(@theme.theme_bg_panel())
          p.fill_rect(0.0, 0.0, r.w, r.h)
          p.set_stroke_color(@theme.theme_border())
          p.set_line_width(1.0)
          p.stroke_rect(0.0, 0.0, r.w - 1.0, r.h - 1.0)
        })
        pop.mount([
          @ui.text("原生弹层：真窗口，能盖住网页区", font_size=12.0),
          @ui.button(
            "菜单项甲",
            on_click=fn() {
              pop_choice.val = "甲"
              pop_closed.val = pop_closed.val + 1
              pop.close_window()
            },
            min_width=200.0,
          ),
          @ui.button(
            "菜单项乙",
            on_click=fn() {
              pop_choice.val = "乙"
              pop_closed.val = pop_closed.val + 1
              pop.close_window()
            },
            min_width=200.0,
          ),
        ])
      }
    }
  }
  app.mount([
    @ui.view(
      [
        @ui.text("批 E：原生弹层（开在网页区之上，选完即关）", font_size=13.0),
        @ui.button(
          "开原生弹层菜单",
          on_click=fn() { open_menu(app) },
          min_width=140.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      padding=6.0,
      background_color="bg_panel",
      border_color="border",
      align_items=@yoga.AlignItems::Center,
    ),
  ])

  // ---- 批 C 余项：本地内容通道（自定义协议按 context 注册）----
  // 往临时目录写一份真文件，注册成 yuedemo:// 后让页面区直接加载它——
  // 「本地内容不经磁盘缓存、不经网络层」这条能力就完整了。
  let sc_index =
    "<!doctype html><html><head><meta charset=\"utf-8\">" +
    "<title>本地协议页</title><link rel=\"stylesheet\" href=\"style.css\">" +
    "</head><body><h1 id=\"h\">来自 yuedemo:// 的标题</h1>" +
    "<p class=\"styled\">这一段若带蓝色底色，说明 style.css 也是走协议取到的。</p>" +
    "</body></html>"
  let sc_css = ".styled { background: #cde; padding: 6px; } h1 { font-size: 20px; }"
  let sc_reg = Ref(0)
  let sc_loads = Ref(0)
  let sc_unreg = Ref(0)
  let sc_files = Ref(0)
  let load_local_page = fn() -> Unit {
    // 写文件不会顺手建父目录：目录不在时两份写都失败，页面那边只回一句
    // not found，看着像协议没通。先建目录，再把「文件到底在不在」报出来。
    let _ = @sys.sys_make_dirs(sc_root)
    let a = @sys.sys_write_text_file(sc_root + "/index.html", sc_index)
    let b = @sys.sys_write_text_file(sc_root + "/style.css", sc_css)
    if a && b {
      sc_files.val = 2
    }
    match wv {
      None => ()
      Some(v) => {
        if v.register_protocol("yuedemo", sc_root) {
          sc_reg.val = 1
          v.load_url("yuedemo://local/index.html")
          sc_loads.val = sc_loads.val + 1
        }
      }
    }
  }
  app.mount([
    @ui.view(
      [
        @ui.text("批 C 余项：本地协议（yuedemo:// 读临时目录里的真文件）", font_size=13.0),
        @ui.button(
          "加载本地协议页",
          on_click=fn() { load_local_page() },
          min_width=150.0,
        ),
        @ui.button(
          "注销该协议",
          on_click=fn() {
            match wv {
              None => ()
              Some(v) =>
                if v.unregister_protocol("yuedemo") {
                  sc_unreg.val = 1
                }
            }
          },
          min_width=120.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      padding=6.0,
      background_color="bg_panel",
      border_color="border",
      align_items=@yoga.AlignItems::Center,
    ),
  ])

  match wv {
    None => {
      // 探测不到引擎：自绘一块说明板（降级不静默）
      app.mount([
        @ui.view(
          [
            @ui.text("webview 引擎不在位", font_size=14.0),
            @ui.text(
              "本机缺 webkit2gtk-4.1（或非 Linux 平台）。pane 通道本身可用，" +
                "页面区改画自绘内容；装上引擎后本页自动走 webview 分支。",
              font_size=12.0,
            ),
          ],
          padding=12.0,
          grow=1.0,
          background_color="bg_panel",
          border_color="border",
        ),
      ])
    }
    Some(v) => {
      app.mount([
        @ui.view(
          [
            @ui.view(
              [
                @ui.text("原生侧栏", font_size=13.0),
                @ui.text("owner = 自绘 Painter", font_size=12.0),
                @ui.text("这一侧的矩形与页面区不重叠", font_size=12.0),
              ],
              width=240.0,
              padding=10.0,
              row_gap=6.0,
              background_color="bg_page",
              border_color="border",
              handle=fn(w : @core.Widget) -> Unit { sidebar_w.val = Some(w) },
            ),
            @ui.view(
              [v.node(grow=1.0)],
              grow=1.0,
              padding=0.0,
              background_color="bg_panel",
              border_color="border",
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
  // 不设自杀点：这个示例的人工验收要开好几扇窗、逐项点过去，自动退出只会打断
  // 使用者。无人值守的自动化跑法自行按 PID 收尾（不起依赖计时器的兜底）。
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
  // close 之后 get_title 回空串，所以标题复用上面关闭前读到的那一份
  let sc_title = title
  println(
    "NATIVE-WEB-SCHEME reg=" +
      sc_reg.val.to_string() +
      " loads=" +
      sc_loads.val.to_string() +
      " files=" +
      sc_files.val.to_string() +
      " unreg=" +
      sc_unreg.val.to_string() +
      " fails=" +
      sc_fail.val.to_string() +
      " raw=" +
      sc_raw.val.to_string() +
      " fail='" +
      sc_fail_domain.val +
      "/" +
      sc_fail_code.val.to_string() +
      " " +
      sc_fail_uri.val +
      "' title='" +
      sc_title +
      "'",
  )
  println(
    "NATIVE-WEB-OVL opens=" +
      ov_opens.val.to_string() +
      " tier=" +
      ov_tier.val.to_string() +
      " native=" +
      ov_native.val.to_string() +
      " layer=" +
      ov_layer.val.to_string() +
      " hides=" +
      ov_hides.val.to_string(),
  )
  println(
    "NATIVE-WEB-POP opens=" +
      pop_opens.val.to_string() +
      " closed=" +
      pop_closed.val.to_string() +
      " choice='" +
      pop_choice.val +
      "' wins=" +
      app.window_count().to_string() +
      " owner_origin=" +
      (fn() -> String {
        let o = app.window.origin()
        o.0.to_string() + "," + o.1.to_string()
      })() +
      " win_size=" +
      (fn() -> String {
        let z = app.window.size()
        z.0.to_string() + "x" + z.1.to_string()
      })(),
  )
  println(
    "NATIVE-WEB-MEDIA frames=" +
      md_frames.val.to_string() +
      " pos_ms=" +
      (md_pos.val * 1000.0).round().to_int().to_string() +
      " playing=" +
      md_playing.val.to_string() +
      " speed=" +
      @media.vp_fmt_speed(md_speed.val) +
      " subs=" +
      md_subs_n.val.to_string() +
      " emb=" +
      md_subs_emb.val.to_string() +
      " err='" +
      md_err.val +
      "'",
  )
  println(
    "NATIVE-WEB-LOCAL present=" +
      (if lv_present { "1" } else { "0" }) +
      " frames=" +
      lv_frames.val.to_string() +
      " pos_ms=" +
      (lv_pos.val * 1000.0).round().to_int().to_string() +
      " speed=" +
      @media.vp_fmt_speed(lv_speed.val) +
      " subs=" +
      lv_subs_n.val.to_string() +
      " err='" +
      lv_err.val +
      "'",
  )
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
      " fails=" +
      js_fails.val.to_string() +
      " fail_last='" +
      js_fail_last.val +
      "' cookie_bytes=" +
      js_cookie_bytes.val.to_string() +
      " last='" +
      js_last.val +
      "'",
  )
  app.shutdown()
}
