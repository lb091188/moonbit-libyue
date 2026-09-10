// 组合控件：滑块 / 下拉选择器 / 可编辑下拉框 / 进度条 / 弹出层。

///|
/// 创建滑块（默认范围 0.0 ~ 1.0）。
pub fn Slider::new() -> Slider {
  { view: ffi_slider_new() }
}

///|
/// 设置当前值。
pub fn Slider::set_value(self : Slider, value : Double) -> Unit {
  ffi_slider_set_value(self, value)
}

///|
/// 读取当前值。
pub fn Slider::get_value(self : Slider) -> Double {
  ffi_slider_get_value(self)
}

///|
/// 设置步进（0 表示连续）。
pub fn Slider::set_step(self : Slider, step : Double) -> Unit {
  ffi_slider_set_step(self, step)
}

///|
/// 设置取值范围。
pub fn Slider::set_range(self : Slider, min : Double, max : Double) -> Unit {
  ffi_slider_set_range(self, min, max)
}

///|
/// 注册值变化回调（拖动过程中持续触发）。
pub fn Slider::on_value_change(self : Slider, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_slider_on_value_change(self, fn(f) { f() }, callback)
}

///|
/// 注册拖动结束回调。
pub fn Slider::on_sliding_complete(self : Slider, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_slider_on_sliding_complete(self, fn(f) { f() }, callback)
}

///|
/// 创建下拉选择器。
pub fn Picker::new() -> Picker {
  { view: ffi_picker_new() }
}

///|
/// 添加选项。
pub fn Picker::add_item(self : Picker, text : String) -> Unit {
  ffi_picker_add_item(self.view(), utf8_bytes(text))
}

///|
/// 移除指定位置的选项。
pub fn Picker::remove_item_at(self : Picker, index : Int) -> Unit {
  ffi_picker_remove_item_at(self.view(), index)
}

///|
/// 清空全部选项。
pub fn Picker::clear(self : Picker) -> Unit {
  ffi_picker_clear(self.view())
}

///|
/// 选中指定位置的选项。
pub fn Picker::select_item_at(self : Picker, index : Int) -> Unit {
  ffi_picker_select_item_at(self.view(), index)
}

///|
/// 当前选中的选项文本。
pub fn Picker::get_selected_item(self : Picker) -> String {
  from_utf8_bytes(ffi_picker_get_selected_item(self.view()))
}

///|
/// 当前选中项下标（无选中为 -1）。
pub fn Picker::get_selected_item_index(self : Picker) -> Int {
  ffi_picker_get_selected_item_index(self.view())
}

///|
/// 注册选择变化回调。
pub fn Picker::on_selection_change(self : Picker, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_picker_on_selection_change(self.view(), fn(f) { f() }, callback)
}

///|
/// 创建可编辑下拉框。
pub fn ComboBox::new() -> ComboBox {
  { view: ffi_combo_box_new() }
}

///|
/// 设置文本。
pub fn ComboBox::set_text(self : ComboBox, text : String) -> Unit {
  ffi_combo_box_set_text(self, utf8_bytes(text))
}

///|
/// 读取文本。
pub fn ComboBox::get_text(self : ComboBox) -> String {
  from_utf8_bytes(ffi_combo_box_get_text(self))
}

///|
/// 注册文本变化回调。
pub fn ComboBox::on_text_change(self : ComboBox, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_combo_box_on_text_change(self, fn(f) { f() }, callback)
}

///|
/// 创建进度条。
pub fn ProgressBar::new() -> ProgressBar {
  { view: ffi_progress_bar_new() }
}

///|
/// 设置进度值（0.0 ~ 1.0；-1 与不定态配合）。
pub fn ProgressBar::set_value(self : ProgressBar, value : Double) -> Unit {
  ffi_progress_bar_set_value(self, value)
}

///|
/// 设置不定态（如加载中的来回动画）。
pub fn ProgressBar::set_indeterminate(self : ProgressBar, yes : Bool) -> Unit {
  ffi_progress_bar_set_indeterminate(self, if yes { 1 } else { 0 })
}

///|
/// 创建弹出层。
pub fn Popover::new() -> Popover {
  ffi_popover_new()
}

///|
/// 设置弹出层内容视图。
pub fn[T : ViewLike] Popover::set_content(self : Popover, content : T) -> Unit {
  ffi_popover_set_content(self, content.view())
}

///|
/// 设置内容区尺寸。
pub fn Popover::set_content_size(self : Popover, width : Double, height : Double) -> Unit {
  ffi_popover_set_content_size(self, width, height)
}

///|
/// 在指定视图附近弹出。
pub fn[T : ViewLike] Popover::show_relative_to(self : Popover, view : T) -> Unit {
  ffi_popover_show_relative_to(self, view.view())
}

///|
/// 关闭弹出层。
pub fn Popover::close(self : Popover) -> Unit {
  ffi_popover_close(self)
}

///|
/// 注册弹出层关闭回调。
pub fn Popover::on_close(self : Popover, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_popover_on_close(self, fn(f) { f() }, callback)
}

///|
/// ComboBox 继承 Picker 的选项操作（MoonBit 侧显式委托）。
pub fn ComboBox::add_item(self : ComboBox, text : String) -> Unit {
  ffi_picker_add_item(self.view(), utf8_bytes(text))
}

///|
pub fn ComboBox::select_item_at(self : ComboBox, index : Int) -> Unit {
  ffi_picker_select_item_at(self.view(), index)
}

///|
pub fn ComboBox::get_selected_item(self : ComboBox) -> String {
  from_utf8_bytes(ffi_picker_get_selected_item(self.view()))
}

///|
pub fn ComboBox::on_selection_change(self : ComboBox, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_picker_on_selection_change(self.view(), fn(f) { f() }, callback)
}
