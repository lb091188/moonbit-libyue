// 浏览器页:WebView 全能力演示——加载(URL/本地 HTML/自定义协议)、
// 导航与能力查询、五回调(四导航 + 标题)、JS 执行与结果回传、
// JS↔原生 raw binding 增删查、Cookie 查询。协议注册在页构建时执行
// 一次(Windows WebView2 下自定义协议静默无效,段内说明)。

///|
fn page_browser(_app : App) -> @yue.Node {
  let win = _app
  let web_ref : Ref[@browser.Browser?] = Ref(None)
  let nav_state : @yue.Store[String] = @yue.Store::new("(导航状态)")
  let nav_events : @yue.Store[String] = @yue.Store::new("(导航回调)")
  let bind_state : @yue.Store[String] = @yue.Store::new("(raw binding)")
  let js_state : @yue.Store[String] = @yue.Store::new("(JS 结果)")
  let cookie_state : @yue.Store[String] = @yue.Store::new("(Cookie)")
  let title_state : @yue.Store[String] = @yue.Store::new("(标题)")
  // 自定义协议(demo://;Windows 静默无效,页面自证跨平台差异)
  @browser.Browser::register_protocol("demo", fn(_url) {
    Some(
      (
        "text/html",
        "<html><body style='font-family:sans-serif;background:#fff;color:#222'><h2>demo:// 自定义协议 ✓</h2><p>由 register_protocol 注册,ProtocolStringJob 应答。</p></body></html>",
      ),
    )
  })
  scroll_page([
    section(
      "WebView 与加载",
      "load_url / demo:// 协议 / load_html 本地片段(内嵌 JS 按钮可调原生绑定)。",
      [
        @browser.browser(handle=fn(x) {
          web_ref.val = Some(x)
          x.load_html(
            "<html><body style='font-family:sans-serif;background:#fff;color:#222;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%'><h3>WebView 内嵌页 ✓</h3><button onclick=\"demoBinding('来自网页的调用')\">JS 调原生绑定</button><p id=r></p><script>function demoBinding(s){document.getElementById('r').textContent='已调用: '+s}</script></body></html>",
          )
          // 五回调:提交导航、完成导航、加载态、命令可用性、标题更新
          x.on_commit_navigation(fn(url) {
            nav_events.set("on_commit_navigation:\{url}")
          })
          x.on_finish_navigation(fn(_url) { nav_events.set("on_finish_navigation(导航完成)") })
          x.on_change_loading(fn() { nav_events.set("on_change_loading(加载态变化)") })
          x.on_update_command(fn() { nav_events.set("on_update_command(导航命令刷新)") })
          x.on_update_title(fn(t) { title_state.set(t) })
          // raw binding:网页 JS 调 demoBinding(...) 时原生侧收到 JSON 参数
          x.add_raw_binding("demoBinding", fn(json) {
            bind_state.set("收到网页调用:\{json}")
          })
        }, style=[("height", 190.0), ("marginBottom", 8.0)]),
        @yue.hbox([
          @yue.button_t("加载 example.com", on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.load_url("https://example.com")
                nav_state.set("加载 example.com(需外网)")
              }
              None => ()
            }
          }),
          @yue.button_t("demo:// 协议", on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.load_url("demo://hello")
                nav_state.set("加载 demo://hello")
              }
              None => ()
            }
          }),
          @yue.button_t("本地 HTML", variant=@yue.Solid, on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.load_html(
                  "<html><body style='font-family:sans-serif'><h3>load_html 本地片段</h3><button onclick=\"demoBinding('来自网页的调用')\">JS 调原生绑定</button><p id=r></p><script>function demoBinding(s){document.getElementById('r').textContent='已调用: '+s}</script></body></html>",
                )
                nav_state.set("load_html 完成")
              }
              None => ()
            }
          }),
        ]),
        @yue.bind_label(nav_state, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "导航与能力查询",
      "四导航按钮 + can_go_back/can_go_forward/is_loading 能力查询。",
      [
        @yue.hbox([
          @yue.button_t("← 后退", on_click=fn() {
            match web_ref.val {
              Some(b) => b.go_back()
              None => ()
            }
          }),
          @yue.button_t("前进 →", on_click=fn() {
            match web_ref.val {
              Some(b) => b.go_forward()
              None => ()
            }
          }),
          @yue.button_t("刷新", on_click=fn() {
            match web_ref.val {
              Some(b) => b.reload()
              None => ()
            }
          }),
          @yue.button_t("停止", on_click=fn() {
            match web_ref.val {
              Some(b) => b.stop()
              None => ()
            }
          }),
          @yue.button_t("能力查询", variant=@yue.Soft, on_click=fn() {
            match web_ref.val {
              Some(b) =>
                nav_state.set(
                  "可后退=\{b.can_go_back()} 可前进=\{b.can_go_forward()} 加载中=\{b.is_loading()}",
                )
              None => ()
            }
          }),
        ]),
        @yue.bind_label(nav_events, fn(s) { "回调:\{s}" }, style=[("marginTop", 8.0)]),
        @yue.bind_label(title_state, fn(s) { "标题:\{s}" }),
      ],
    ),
    section(
      "执行 JavaScript",
      "with_result 异步取回 JSON;无结果执行改页面。",
      [
        @yue.hbox([
          @yue.button_t("取结果 1+41", on_click=fn() {
            match web_ref.val {
              Some(b) =>
                b.execute_javascript_with_result(
                  "1 + 41",
                  fn(ok, json) {
                    js_state.set(
                      if ok {
                        "JS 结果:\{json}(get_title=\{b.get_title()})"
                      } else {
                        "JS 执行失败"
                      },
                    )
                  },
                )
              None => ()
            }
          }),
          @yue.button_t("读当前 URL", on_click=fn() {
            match web_ref.val {
              Some(b) =>
                b.execute_javascript_with_result(
                  "location.href",
                  fn(ok, json) { js_state.set(if ok { "location.href=\{json}" } else { "读取失败" }) },
                )
              None => ()
            }
          }),
          @yue.button_t("改页面标题", variant=@yue.Solid, on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.execute_javascript("document.title='由原生 JS 设置 ✓'")
                js_state.set("已执行:document.title 赋值(看上方标题回显)")
              }
              None => ()
            }
          }),
        ]),
        @yue.bind_label(js_state, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "JS ↔ 原生绑定",
      "注册 demoBinding(网页按钮调用)/移除/has_bindings 查询。",
      [
        @yue.hbox([
          @yue.button_t("重新注册绑定", on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.add_raw_binding("demoBinding", fn(json) {
                  bind_state.set("收到网页调用:\{json}")
                })
                bind_state.set(if b.has_bindings() { "已注册 demoBinding" } else { "注册未生效" })
              }
              None => ()
            }
          }),
          @yue.button_t("移除绑定", variant=@yue.Danger, on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.remove_binding("demoBinding")
                bind_state.set(
                  if b.has_bindings() { "仍有其他绑定" } else { "绑定已全部移除" },
                )
              }
              None => ()
            }
          }),
        ]),
        @yue.bind_label(bind_state, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "Cookie 查询",
      "异步查询 URL 的 Cookie(名称/值/域/路径/httpOnly/secure)。",
      [
        @yue.hbox([
          @yue.button_t("查 example.com", on_click=fn() {
            match web_ref.val {
              Some(b) =>
                b.get_cookies_for_url("https://example.com", fn(cookies) {
                  if cookies.length() == 0 {
                    cookie_state.set("无 Cookie(未访问过或已清空)")
                  } else {
                    let sb = StringBuilder()
                    for i, c in cookies {
                      if i > 0 {
                        sb.write_string("; ")
                      }
                      sb.write_string("\{c.name}=\{c.value}(域 \{c.domain})")
                    }
                    cookie_state.set("共 \{cookies.length()} 条:\{sb}")
                  }
                })
              None => ()
            }
          }),
          @yue.button_t("查 demo://hello", on_click=fn() {
            match web_ref.val {
              Some(b) =>
                b.get_cookies_for_url("demo://hello", fn(cookies) {
                  cookie_state.set("demo:// 查询返回 \{cookies.length()} 条(自定义协议无 Cookie 存储)")
                })
              None => ()
            }
          }),
        ]),
        @yue.bind_label(cookie_state, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "创建选项与平台差异",
      "BrowserOptions 四选项与平台差异速览(自定义协议 Windows 静默无效等)。",
      [
        @yue.descriptions([
          ("devtools", "默认关;开则右键可审查元素(Windows 需环境变量)"),
          ("context_menu", "默认关;开则显示 WebView 原生右键菜单"),
          ("allow_file_access_from_files", "file:// 页面访问其他 file:// 资源(Linux/macOS)"),
          ("自定义协议", "Linux 可用;Windows WebView2 静默无效"),
        ]),
        @yue.button_t("以 devtools 开启重建(下个窗口生效)", variant=@yue.Soft, on_click=fn() {
          win.toast_push("演示项:BrowserOptions 在 Browser::new_with_options 创建期生效,重建需换实例", @yue.Info)
        }),
      ],
    ),
  ])
}
