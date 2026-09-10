// 组合控件演示：滑块联动进度条、下拉选择器、可编辑下拉框、弹出层按钮。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.set_content_size(360.0, 260.0)
  win.on_close(fn(_window) { @yue.quit() })

  let content = @yue.Container::new()
  content.set_style("padding", 12.0)
  win.set_content(content)

  // 滑块（0~100，步进 1）联动进度条与标题
  let label = @yue.Label::new("滑块值：0")
  label.set_style("marginBottom", 8.0)
  content.add_child(label)

  let slider = @yue.Slider::new()
  slider.set_range(0.0, 100.0)
  slider.set_step(1.0)
  slider.set_style("marginBottom", 8.0)
  content.add_child(slider)

  let progress = @yue.ProgressBar::new()
  progress.set_style("marginBottom", 8.0)
  content.add_child(progress)

  slider.on_value_change(fn() {
    let v = slider.get_value()
    progress.set_value(v / 100.0)
    label.set_text("滑块值：\{v.round()}")
  })
  slider.on_sliding_complete(fn() {
    println("拖动结束：\{slider.get_value().round()}")
  })

  // 下拉选择器
  let picker = @yue.Picker::new()
  picker.add_item("红色")
  picker.add_item("绿色")
  picker.add_item("蓝色")
  picker.select_item_at(0)
  picker.set_style("marginBottom", 8.0)
  content.add_child(picker)

  let color_label = @yue.Label::new("颜色：红色")
  content.add_child(color_label)
  picker.on_selection_change(fn() {
    color_label.set_text("颜色：\{picker.get_selected_item()}")
  })

  // 可编辑下拉框
  let combobox = @yue.ComboBox::new()
  combobox.add_item("https://libyue.com")
  combobox.add_item("https://github.com/moonbitlang")
  combobox.set_style("marginBottom", 8.0)
  content.add_child(combobox)

  // 弹出层按钮
  let popover_btn = @yue.Button::new("弹出菜单")
  popover_btn.set_style("marginBottom", 8.0)
  content.add_child(popover_btn)
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

  // 定时推进进度条演示（借用不定态展示）
  progress.set_value(0.0)

  win.center()
  win.activate()
  @yue.run()
}
