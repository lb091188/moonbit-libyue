// 组合控件演示：页签切换、滑块联动进度条、下拉选择器、可编辑下拉框、
// 输入框回车激活、文本编辑框撤销/选区/插入等操作。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.set_content_size(420.0, 320.0)
  win.on_close(fn(_window) { @yue.quit() })

  // 页签：两页分别展示基础控件与文本编辑
  let tabs = @yue.Tab::new()
  tabs.set_style("padding", 8.0)
  win.set_content(tabs)

  // ---- 页 1：滑块 / 进度条 / 下拉 ----
  let page1 = @yue.Container::new()
  page1.set_style("padding", 12.0)

  let label = @yue.Label::new("滑块值：0")
  label.set_style("marginBottom", 8.0)
  page1.add_child(label)

  let slider = @yue.Slider::new()
  slider.set_range(0.0, 100.0)
  slider.set_step(1.0)
  slider.set_style("marginBottom", 8.0)
  page1.add_child(slider)

  let progress = @yue.ProgressBar::new()
  progress.set_style("marginBottom", 8.0)
  page1.add_child(progress)

  slider.on_value_change(fn() {
    let v = slider.get_value()
    progress.set_value(v / 100.0)
    label.set_text("滑块值：\{v.round()}")
  })
  slider.on_sliding_complete(fn() {
    println("拖动结束：\{slider.get_value().round()}")
  })

  let picker = @yue.Picker::new()
  picker.add_item("红色")
  picker.add_item("绿色")
  picker.add_item("蓝色")
  picker.select_item_at(0)
  picker.set_style("marginBottom", 8.0)
  page1.add_child(picker)

  let color_label = @yue.Label::new("颜色：红色")
  color_label.set_style("marginBottom", 8.0)
  page1.add_child(color_label)
  picker.on_selection_change(fn() {
    color_label.set_text("颜色：\{picker.get_selected_item()}")
  })

  let combobox = @yue.ComboBox::new()
  combobox.add_item("https://libyue.com")
  combobox.add_item("https://github.com/moonbitlang")
  combobox.set_style("marginBottom", 8.0)
  page1.add_child(combobox)
  combobox.on_text_change(fn() {
    println("下拉框文本：\{combobox.get_text()}")
  })

  // 复选/单选按钮（Button::Type）
  let check = @yue.Button::new_of(@yue.Checkbox, "启用")
  check.set_style("marginBottom", 8.0)
  page1.add_child(check)
  check.on_click(fn() {
    println("复选：\{check.is_checked()}")
  })
  let radio_row = @yue.Container::new()
  radio_row.set_style_str("flexDirection", "row")
  radio_row.set_style("marginBottom", 8.0)
  page1.add_child(radio_row)
  let radio_a = @yue.Button::new_of(@yue.Radio, "甲")
  let radio_b = @yue.Button::new_of(@yue.Radio, "乙")
  radio_b.set_checked(true)
  radio_a.set_style("marginRight", 12.0)
  radio_row.add_child(radio_a)
  radio_row.add_child(radio_b)

  // 弹出层按钮
  let popover_btn = @yue.Button::new("弹出菜单")
  page1.add_child(popover_btn)
  popover_btn.on_click(fn() {
    let popover = @yue.Popover::new()
    let panel = @yue.Container::new()
    panel.set_background_color("#EEE")
    let tip = @yue.Label::new("来自弹出层")
    panel.add_child(tip)
    popover.set_content(panel)
    popover.set_content_size(160.0, 60.0)
    popover.on_close(fn() { println("弹出层已关闭") })
    popover.show_relative_to(popover_btn)
  })

  // ---- 页 2：输入框回车 + 文本编辑操作 ----
  let page2 = @yue.Container::new()
  page2.set_style("padding", 12.0)

  let entry = @yue.Entry::new()
  entry.set_text("输入后按回车")
  entry.set_style("marginBottom", 8.0)
  page2.add_child(entry)
  entry.on_text_change(fn() {
    println("输入框变化：\{entry.get_text()}")
  })
  entry.on_activate(fn() {
    println("回车提交：\{entry.get_text()}")
  })

  // 密码输入框（Entry::Type::Password）
  let password = @yue.Entry::new_of(@yue.Password)
  password.set_text("口令")
  password.set_style("marginBottom", 8.0)
  page2.add_child(password)
  password.on_activate(fn() {
    println("密码长度：\{password.get_text().length()}")
  })

  let edit = @yue.TextEdit::new()
  edit.set_text("TextEdit 撤销/选区/插入演示。\n可在此输入多行文本。")
  edit.set_style("flex", 1.0)
  edit.set_style("marginBottom", 8.0)
  page2.add_child(edit)
  edit.on_text_change(fn() {
    println("编辑区变化，可撤销：\{edit.can_undo()}")
  })

  let ops = @yue.Container::new()
  ops.set_style_str("flexDirection", "row")
  page2.add_child(ops)

  let btn_select = @yue.Button::new("全选")
  ops.add_child(btn_select)
  btn_select.on_click(fn() { edit.select_all() })

  let btn_insert = @yue.Button::new("插入")
  btn_insert.set_style("marginLeft", 8.0)
  ops.add_child(btn_insert)
  btn_insert.on_click(fn() { edit.insert_text("[插入] ") })

  let btn_range = @yue.Button::new("前 5 字符")
  btn_range.set_style("marginLeft", 8.0)
  ops.add_child(btn_range)
  btn_range.on_click(fn() {
    edit.select_range(0, 5)
    println("前 5 字符：\{edit.get_text_in_range(0, 5)}")
  })

  let btn_undo = @yue.Button::new("撤销")
  btn_undo.set_style("marginLeft", 8.0)
  ops.add_child(btn_undo)
  btn_undo.on_click(fn() { edit.undo() })

  tabs.add_page("控件", page1)
  tabs.add_page("文本", page2)
  tabs.on_selected_page_change(fn() {
    println("切到第 \{tabs.get_selected_page_index()} 页（共 \{tabs.page_count()} 页）")
  })

  progress.set_value(0.0)

  // 系统信息
  @yue.App::set_name("moonbit-libyue-widgets")
  println("应用名：\{@yue.App::get_name()}")
  println("系统区域：\{@yue.locale()}")
  println("深色主题：\{@yue.Appearance::is_dark()}")
  let (sw, sh) = @yue.Screen::primary_size()
  println("主屏：\{sw}x\{sh}（缩放 \{@yue.Screen::scale_factor()}）")

  win.center()
  win.activate()
  @yue.run()
}
