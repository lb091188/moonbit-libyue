// View 通用能力：所有控件句柄统一为 View 类型。
// 类型安全由 shim 侧 dynamic_cast 运行时校验兜底（错型调用被拒绝并记日志），
// 换取 Container::add_child / 布局 / 绘制等多态 API 的自然表达。

///|
/// 回调注册表：持有所有已注册闭包的强引用，保证 C 侧保存的函数指针
/// 在对象存活期内不被 GC 回收。带参与不带参回调分表存放。
let callbacks : Ref[Array[() -> Unit]] = Ref([])

///|
let bytes_callbacks : Ref[Array[(Bytes) -> Unit]] = Ref([])

///|
let draw_callbacks : Ref[Array[(Painter) -> Unit]] = Ref([])

fn keep_alive(callback : () -> Unit) -> Unit {
  callbacks.val.push(callback)
}

fn keep_alive_bytes(callback : (Bytes) -> Unit) -> Unit {
  bytes_callbacks.val.push(callback)
}

fn keep_alive_draw(callback : (Painter) -> Unit) -> Unit {
  draw_callbacks.val.push(callback)
}

///|
/// 创建默认有边框的窗口。
pub fn Window::new() -> Window {
  { view: ffi_window_new_ex(1, 0) }
}

///|
/// 创建指定外观的窗口（frame=false 为无边框，transparent=true 透明背景）。
pub fn Window::new_with_options(frame : Bool, transparent : Bool) -> Window {
  { view: ffi_window_new_ex(if frame { 1 } else { 0 }, if transparent { 1 } else { 0 }) }
}

///|
/// 设置窗口标题。
pub fn Window::set_title(self : Window, title : String) -> Unit {
  ffi_window_set_title(self.view, utf8_bytes(title))
}

///|
/// 窗口是否置顶。
pub fn Window::set_always_on_top(self : Window, top : Bool) -> Unit {
  ffi_window_set_always_on_top(self.view, if top { 1 } else { 0 })
}

///|
/// 内容区当前宽度（逻辑像素）。
pub fn Window::get_content_size_width(self : Window) -> Double {
  ffi_window_get_content_size_width(self.view)
}

///|
/// 内容区当前高度（逻辑像素）。
pub fn Window::get_content_size_height(self : Window) -> Double {
  ffi_window_get_content_size_height(self.view)
}

///|
/// 设置窗口内容视图。
pub fn[T : ViewLike] Window::set_content(self : Window, content : T) -> Unit {
  ffi_window_set_content(self.view, content.view())
}

///|
/// 设置内容区尺寸（逻辑像素）。
pub fn Window::set_content_size(self : Window, width : Double, height : Double) -> Unit {
  ffi_window_set_content_size(self.view, width, height)
}

///|
/// 居中到所在屏幕。
pub fn Window::center(self : Window) -> Unit {
  ffi_window_center(self.view)
}

///|
/// 激活并获得焦点。
pub fn Window::activate(self : Window) -> Unit {
  ffi_window_activate(self.view)
}

///|
/// 挂载顶栏菜单条。
pub fn Window::set_menubar(self : Window, menubar : MenuBar) -> Unit {
  ffi_window_set_menubar(self.view, menubar)
}

///|
/// 注册窗口关闭回调。
pub fn Window::on_close(self : Window, callback : (Window) -> Unit) -> Unit {
  let win = self
  let wrapped : () -> Unit = fn() { callback(win) }
  keep_alive(wrapped)
  ffi_window_on_close(self.view, fn(f : (() -> Unit)) -> Unit { f() }, wrapped)
}

///|
/// 创建容器（可嵌套子视图、可自绘）。
pub fn Container::new() -> Container {
  { view: ffi_container_new() }
}

///|
/// 添加子视图。
pub fn[T : ViewLike] Container::add_child(self : Container, child : T) -> Unit {
  ffi_container_add_child(self.view, child.view())
}

///|
/// 注册自绘回调。painter 仅回调期内有效。
pub fn Container::on_draw(self : Container, callback : (Painter) -> Unit) -> Unit {
  let wrapped : (Painter) -> Unit = fn(painter) { callback(painter) }
  keep_alive_draw(wrapped)
  ffi_container_on_draw(self.view, fn(f : ((Painter) -> Unit), p : Painter) -> Unit { f(p) }, wrapped)
}

///|
/// 视图获得输入焦点。
impl ViewLike with fn focus(self) -> Unit {
  ffi_view_focus(self.view())
}

///|
/// 启用/禁用视图。
impl ViewLike with fn set_enabled(self, enable) -> Unit {
  ffi_view_set_enabled(self.view(), if enable { 1 } else { 0 })
}

///|
/// 允许按住鼠标拖动窗口（无边框窗口必备）。
impl ViewLike with fn set_mouse_down_can_move_window(self, yes) -> Unit {
  ffi_view_set_mouse_down_can_move_window(self.view(), if yes { 1 } else { 0 })
}

///|
/// 设置布局属性（数值型，键名与官方一致：flex/flexGrow/padding/width/...）。
impl ViewLike with fn set_style(self, name, value) -> Unit {
  ffi_view_set_style_prop_float(self.view(), utf8_bytes(name), value)
}

///|
/// 设置布局属性（字符串型，如 flexDirection="row"）。
impl ViewLike with fn set_style_str(self, name, value) -> Unit {
  ffi_view_set_style_prop_str(self.view(), utf8_bytes(name), utf8_bytes(value))
}

///|
/// 设置背景色（hex：#RGB/#RGBA/#RRGGBB/#RRGGBBAA）。
impl ViewLike with fn set_background_color(self, hex) -> Unit {
  ffi_view_set_background_color(self.view(), utf8_bytes(hex))
}

///|
/// 创建静态文本标签。
pub fn Label::new(text : String) -> Label {
  { view: ffi_label_new(utf8_bytes(text)) }
}

///|
/// 更新标签文本。
pub fn Label::set_text(self : Label, text : String) -> Unit {
  ffi_label_set_text(self.view, utf8_bytes(text))
}
