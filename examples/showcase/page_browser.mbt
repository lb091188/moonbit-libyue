// 网页页：Browser 导航 / JS / 本地 HTML / UA / 自定义协议(仅 Linux)。

///|
fn page_browser() -> @yue.Node {
  let b : Ref[@yue.Browser?] = Ref(None)
  let url_bar : Ref[@yue.Entry?] = Ref(None)
  let go = fn() -> Unit {
    match (url_bar.val, b.val) {
      (Some(e), Some(x)) => x.load_url(e.get_text())
      (_, _) => ()
    }
  }
  let browser_desc = if is_windows() {
    "Windows 优先 WebView2（缺运行时回退 IE）。WebView2 走系统代理，代理失效可设环境变量 LIBYUE_WEBVIEW2_ARGS=--no-proxy-server 直连。地址栏回车或「转到」加载。"
  } else {
    "Linux 为 WebKitGTK。地址栏回车或「转到」加载；页面标题会联动窗口标题。"
  }
  let secs : Array[@yue.Node] = [
    section("内嵌浏览器", browser_desc, [
      @yue.hbox(
        [
          @yue.entry(
            text="https://www.moonbitlang.com",
            on_enter=fn(_s) { go() },
            handle=fn(e) { url_bar.val = Some(e) },
            style=[("flex", 1.0)],
          ),
          @yue.button("转到", on_click=fn() { go() }),
          @yue.button("←", on_click=fn() {
            when_some(b, fn(x) { x.go_back() })
          }),
          @yue.button("→", on_click=fn() {
            when_some(b, fn(x) { x.go_forward() })
          }),
        ],
        style=[("marginBottom", 8.0)],
      ),
      @yue.browser(
        handle=fn(x) {
          b.val = Some(x)
          x.load_url("https://www.moonbitlang.com")
          x.on_update_title(fn(_url) {
            when_some(main_win, fn(w) {
              w.set_title("Showcase — \{x.get_url()}")
            })
          })
        },
        style=[("height", 360.0)],
      ),
    ]),
    section(
      "JS / 本地 HTML / UA",
      "execute_javascript 改页面标题（生效即变 JS-OK）；load_html 免网络片段；set_user_agent 改请求标识。",
      [
        @yue.hbox([
          @yue.button("执行 JS", on_click=fn() {
            when_some(b, fn(x) {
              x.execute_javascript("document.title = 'JS-OK'")
            })
          }),
          @yue.button("本地 HTML", on_click=fn() {
            when_some(b, fn(x) {
              x.load_html(
                "<h3>load_html 本地片段</h3><p>不经过网络。</p>",
              )
            })
          }),
          @yue.button("切换 UA", on_click=fn() {
            when_some(b, fn(x) { x.set_user_agent("MoonBitShowcase/1.0") })
          }),
        ]),
      ],
    ),
  ]
  // 自定义协议在 Windows WebView2 下静默无效：非 Linux 平台不创建演示按钮
  if is_linux() {
    secs.push(
      section(
        "自定义协议 demo://（仅 Linux）",
        "register_protocol 注册 demo://，由 ProtocolStringJob 应答；其他平台整段不创建。",
        [
          @yue.button("加载 demo://hello", on_click=fn() {
            when_some(b, fn(x) { x.load_url("demo://hello") })
          }),
        ],
      ),
    )
  } else {
    secs.push(
      section(
        "自定义协议 demo://（仅 Linux）",
        "Windows WebView2 下自定义协议静默无效（IE 引擎可用），因此本段在非 Linux 平台不提供演示、只留说明。",
        [],
      ),
    )
  }
  scroll_page(secs)
}
