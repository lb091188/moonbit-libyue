// 复刻自 yue-sample-apps/browser：工具栏 + Entry 地址栏 + 内嵌浏览器。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.set_content_size(500.0, 500.0)
  win.on_close(fn(_window) { @yue.quit() })

  let content = @yue.Container::new()
  win.set_content(content)

  let toolbar = @yue.Container::new()
  toolbar.set_style_str("flexDirection", "row")
  toolbar.set_style("padding", 5.0)
  content.add_child(toolbar)

  let back = @yue.Button::new("<")
  back.set_enabled(false)
  toolbar.add_child(back)

  let forward = @yue.Button::new(">")
  forward.set_enabled(false)
  forward.set_style("marginRight", 5.0)
  toolbar.add_child(forward)

  let refresh = @yue.Button::new("R")
  refresh.set_style("width", 20.0)
  refresh.set_style("marginRight", 5.0)
  toolbar.add_child(refresh)

  let addressbar = @yue.Entry::new()
  addressbar.set_style("flex", 1.0)
  toolbar.add_child(addressbar)

  let go = @yue.Button::new("GO")
  go.set_style("marginLeft", 5.0)
  toolbar.add_child(go)

  let browser = @yue.Browser::new()
  browser.set_style("flex", 1.0)
  content.add_child(browser)

  // 工具栏动作
  back.on_click(fn() { browser.go_back() })
  forward.on_click(fn() { browser.go_forward() })
  refresh.on_click(fn() { browser.reload() })
  go.on_click(fn() {
    let url = addressbar.get_text()
    let full = if url.contains("://") { url } else { "https://\{url}" }
    browser.load_url(full)
  })

  // 浏览器事件联动工具栏
  browser.on_change_loading(fn() {
    refresh.set_title(if browser.is_loading() { "S" } else { "R" })
  })
  browser.on_update_command(fn() {
    back.set_enabled(browser.can_go_back())
    forward.set_enabled(browser.can_go_forward())
    addressbar.set_text(browser.get_url())
  })
  browser.on_update_title(fn(title) { win.set_title(title) })
  browser.on_commit_navigation(fn(url) { addressbar.set_text(url) })
  browser.on_finish_navigation(fn(_url) { browser.focus() })

  addressbar.set_text("https://libyue.com")
  browser.load_url("https://libyue.com")
  win.center()
  win.activate()
  @yue.run()
}
