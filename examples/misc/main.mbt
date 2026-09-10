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
  @yue.run()
}
