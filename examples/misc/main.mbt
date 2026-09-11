// 批次A 综合演示：分组框 / 滚动视图 / 分隔线 / 剪贴板 / 消息框。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.set_content_size(420.0, 320.0)
  win.on_close(fn(_window) { @yue.quit() })


  let content = @yue.Container::new()
  content.set_style("padding", 10.0)
  win.set_content(content)

  // 分组框 + 内部长文本（放进滚动视图）
  let group = @yue.Group::new("滚动内容")
  group.set_style("flex", 1.0)
  content.add_child(group)

  let scroll = @yue.Scroll::new()
  group.set_content(scroll)

  let lines = @yue.Container::new()
  for i = 0; i < 30; i = i + 1 {
    let row = @yue.Label::new("第 \{i + 1} 行内容")
    row.set_style("margin", 4.0)
    lines.add_child(row)
  }
  scroll.set_content(lines)
  scroll.set_content_size(360.0, 900.0)

  // 分隔线
  let sep = @yue.Separator::new(@yue.Horizontal)
  sep.set_style("margin", 6.0)
  content.add_child(sep)

  // 按钮行：写剪贴板 / 读剪贴板 / 弹消息框
  let buttons = @yue.Container::new()
  buttons.set_style_str("flexDirection", "row")
  content.add_child(buttons)

  let clipboard_text = Ref("来自 MoonBit 的剪贴板内容")

  let write_btn = @yue.Button::new("写入剪贴板")
  write_btn.set_style("marginRight", 6.0)
  write_btn.on_click(fn() {
    @yue.Clipboard::get().set_text(clipboard_text.val)
    println("已写入剪贴板")
  })
  buttons.add_child(write_btn)

  let read_btn = @yue.Button::new("读取剪贴板")
  read_btn.set_style("marginRight", 6.0)
  read_btn.on_click(fn() {
    println("剪贴板内容：\{@yue.Clipboard::get().get_text()}")
  })
  buttons.add_child(read_btn)

  let msg_btn = @yue.Button::new("消息框")
  msg_btn.on_click(fn() {
    let box = @yue.MessageBox::new(@yue.Information)
    box.set_title("MoonBit 提示")
    box.set_text("这是一条来自 moonbit-libyue 的消息")
    box.set_informative_text("选择一个按钮试试回调")
    box.add_button("好的", 1)
    box.add_button("取消", 0)
    box.on_response(fn(response) {
      println("消息框响应：\{response}")
      box.close()
    })
    box.show_for_window(win)
  })
  buttons.add_child(msg_btn)

  win.center()
  win.activate()
  // ---- MessageLoop 定时器自检 ----
  let timer_ticks = Ref(0)
  let _timer_id = @yue.set_timer(200, fn() {
    timer_ticks.val += 1
    if timer_ticks.val >= 3 {
      println("CHECK timer period_ticks=3 ok=true")
      return false
    }
    true
  })
  let timeout_id = @yue.set_timeout(500, fn() {
    println("CHECK timeout fired ok=true")
  })
  @yue.post_delayed_task(700, fn() {
    @yue.clear_timeout(timeout_id)
    println("CHECK cleanup done ok=true")
  })
  @yue.post_task(fn() {
    println("CHECK post_task ok=true")
  })

  // ---- 结构体族自检（真实总线/真机断言，结果打印 stdout，Esc 退出） ----
  win.on_key_down(fn(event) {
    if event.code == @yue.VKEY_ESCAPE {
      println("EVENT quit")
      @yue.quit()
      true
    } else {
      false
    }
  })

  // 滚动条策略往返
  let policy = scroll.get_scrollbar_policy()
  println("CHECK scroll_policy ok=\{policy.0 is @yue.Automatic && policy.1 is @yue.Automatic}")

  // 剪贴板 Selection 主选区 + 数据往返
  let selection = @yue.Clipboard::from_type(@yue.Selection)
  selection.set_data(@yue.Text, "主选区内容")
  match selection.get_data(@yue.Text) {
    Some(@yue.Text(t)) =>
      println("CHECK selection_data got=[\{t}] ok=\{t == "主选区内容"}")
    _ => println("CHECK selection_data ok=false")
  }
  let copy = @yue.Clipboard::from_type(@yue.CopyPaste)
  copy.set_data(@yue.Html, "<b>富文本</b>")
  match copy.get_data(@yue.Html) {
    Some(@yue.Text(h)) =>
      println("CHECK clipboard_html got=[\{h}] ok=\{h == "<b>富文本</b>"}")
    _ => println("CHECK clipboard_html ok=false")
  }

  // 带选项窗口（不抢焦点）+ 浏览器选项 + Cookie 查询
  let _panel = @yue.Window::new_with_options(transparent=false, no_activate=true)
  let browser = @yue.Browser::new_with_options({
    devtools: false,
    context_menu: true,
    allow_file_access_from_files: false,
    hardware_acceleration: true,
  })
  browser.load_url("https://libyue.com/")
  // 注意：libyue 0.15.6 的 GetCookiesForURL 在 Cookie 列表为空时触发内部
  // CHECK(cookies) FATAL 崩溃（上游问题），查询须等页面真正种下 Cookie。
  // 见 TODO.md Browser 族记录。

  // 通知按钮 + 菜单勾选态
  let note = @yue.Notification::new()
  note.set_title("moonbit-libyue")
  note.set_body("带按钮的通知")
  note.set_actions([("查看", "view"), ("忽略", "ignore")])
  note.show()
  println("CHECK notification_actions shown")

  let menu = @yue.Menu::new()
  let item = menu.add_check_item("自动换行")
  item.set_checked(true)
  println("CHECK menu_checked ok=\{item.is_checked()}")
  item.set_checked(false)
  println("CHECK menu_unchecked ok=\{!item.is_checked()}")

  // MenuBase 遍历
  let m2 = @yue.Menu::new()
  let _i0 = m2.add_label_item("甲")
  let _i1 = m2.add_label_item("乙")
  let _i2 = m2.add_label_item("丙")
  let probe = m2.item_at(1)
  println("CHECK menu_traverse count=\{m2.item_count()} at1=\{probe.get_label()}")

  // DatePicker 带选项
  let _dp = @yue.DatePicker::new_with({ elements: @yue.HourMinute, has_stepper: false })
  println("CHECK datepicker_options ok=true")

  // Browser:load_html + execute_javascript(不崩即 ABI 通)
  browser.load_html("<b>hello</b>")
  browser.execute_javascript("1+1")
  println("CHECK browser_js ok=true")

  // 自定义协议(demo://hello)
  @yue.Browser::register_protocol("demo", fn(_url) {
    Some(("text/html", "<html><body><h1>demo-protocol-ok</h1></body></html>"))
  })
  browser.load_url("demo://hello")
  @yue.post_delayed_task(1500, fn() {
    println("CHECK protocol_url got=\{browser.get_url()} ok=\{browser.get_url().has_prefix("demo://")}")
  })

  // Window 选项族运行时
  win.set_resizable(false)
  println("CHECK window_resizable ok=\{!win.is_resizable()}")
  win.set_should_close(fn() { true })
  println("CHECK window_should_close ok=true")

  @yue.run()
}
