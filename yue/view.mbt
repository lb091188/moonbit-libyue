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

///|
fn keep_alive(callback : () -> Unit) -> Unit {
  callbacks.val.push(callback)
}

///|
fn keep_alive_bytes(callback : (Bytes) -> Unit) -> Unit {
  bytes_callbacks.val.push(callback)
}

///|
fn keep_alive_draw(callback : (Painter) -> Unit) -> Unit {
  draw_callbacks.val.push(callback)
}

///|
/// 创建默认有边框的窗口。
pub fn Window::new() -> Window {
  { view: ffi_window_new_ex(1, 0, 0), }
}

///|
/// 创建指定外观的窗口（对照 Window::Options；show_traffic_lights 为 macOS 专属）。
/// no_activate=true 时窗口不抢焦点（浮层/面板类窗口）。
pub fn Window::new_with_options(
  frame? : Bool = true,
  transparent? : Bool = false,
  no_activate? : Bool = false,
) -> Window {
  {
    view: ffi_window_new_ex(
      if frame {
        1
      } else {
        0
      },
      if transparent {
        1
      } else {
        0
      },
      if no_activate {
        1
      } else {
        0
      },
    ),
  }
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
/// 内容区当前尺寸（逻辑像素）。
pub fn Window::get_content_size(self : Window) -> SizeF {
  {
    width: ffi_window_get_content_size_width(self.view),
    height: ffi_window_get_content_size_height(self.view),
  }
}

///|
/// 设置窗口内容视图。
pub fn[T : ViewLike] Window::set_content(self : Window, content : T) -> Unit {
  ffi_window_set_content(self.view, content.view())
}

///|
/// 设置内容区尺寸（逻辑像素）。
pub fn Window::set_content_size(
  self : Window,
  width : Double,
  height : Double,
) -> Unit {
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
  ffi_window_on_close(self.view, fn(f : () -> Unit) -> Unit { f() }, wrapped)
}

///|
/// 创建容器（可嵌套子视图、可自绘）。
pub fn Container::new() -> Container {
  { view: ffi_container_new(), }
}

///|
/// 添加子视图。
pub fn[T : ViewLike] Container::add_child(self : Container, child : T) -> Unit {
  ffi_container_add_child(self.view, child.view())
}

///|
/// 注册自绘回调。painter 仅回调期内有效。
pub fn Container::on_draw(
  self : Container,
  callback : (Painter) -> Unit,
) -> Unit {
  let wrapped : (Painter) -> Unit = fn(painter) { callback(painter) }
  keep_alive_draw(wrapped)
  ffi_container_on_draw(
    self.view,
    fn(f : (Painter) -> Unit, p : Painter) -> Unit { f(p) },
    wrapped,
  )
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
/// 设置视图显隐（隐藏的视图不参与布局）。
impl ViewLike with fn set_visible(self, visible : Bool) -> Unit {
  ffi_view_set_visible(self.view(), if visible { 1 } else { 0 })
}

///|
/// 设置视图字体（原生渲染，交互控件的文字样式首选此路）。
impl ViewLike with fn set_font(self, font : Font) -> Unit {
  ffi_view_set_font(self.view(), font)
}

///|
/// 设置视图前景/文字颜色。
impl ViewLike with fn set_color(self, hex : String) -> Unit {
  ffi_view_set_color(self.view(), utf8_bytes(hex))
}

///|
/// 设置 Label 文字水平对齐。
pub fn Label::set_align(self : Label, align : TextAlign) -> Unit {
  ffi_label_set_align(
    self.view,
    match align {
      Start => 0
      Center => 1
      End => 2
    },
  )
}

///|
/// 请求重绘整个视图（自绘组件状态变化后调用）。
impl ViewLike with fn schedule_paint(self) -> Unit {
  ffi_view_schedule_paint(self.view())
}

///|
/// 创建静态文本标签。
pub fn Label::new(text : String) -> Label {
  { view: ffi_label_new(utf8_bytes(text)), }
}

///|
/// 更新标签文本。
pub fn Label::set_text(self : Label, text : String) -> Unit {
  ffi_label_set_text(self.view, utf8_bytes(text))
}

///|
/// 拖拽数据种类。
pub(all) enum DataKind {
  Text
  Html
  Image
  FilePaths
}

///|
fn data_kind_id(k : DataKind) -> Int {
  match k {
    Text => 1
    Html => 2
    Image => 3
    FilePaths => 4
  }
}

///|
/// 拖拽会话中读取的数据。
pub(all) enum DragData {
  Text(String)
  Paths(Array[String])
  Img(Image)
}

///|
/// Image 值与注册表句柄互转（句柄即 Image 值的底层表示）。
#borrow(image)
extern "c" fn ffi_image_to_handle(image : Image) -> Int64 = "yue_mbt_image_to_handle"

///|
extern "c" fn ffi_image_from_handle(h : Int64) -> Image = "yue_mbt_image_from_handle"

///|
let drag_callbacks : Ref[Array[(DraggingInfo, Double, Double) -> Int]] = Ref([])

///|
fn keep_alive_drag(callback : (DraggingInfo, Double, Double) -> Int) -> Unit {
  drag_callbacks.val.push(callback)
}

///|
/// 拖拽会话中指定种类的数据是否可用（仅在拖拽回调内有效）。
pub fn DraggingInfo::is_data_available(
  self : DraggingInfo,
  kind : DataKind,
) -> Bool {
  ffi_dragging_is_available(self, data_kind_id(kind)) == 1
}

///|
/// 从拖拽会话读取指定种类的数据（仅在拖拽回调内有效）。
pub fn DraggingInfo::get_data(
  self : DraggingInfo,
  kind : DataKind,
) -> DragData? {
  let id = data_kind_id(kind)
  if ffi_dragging_is_available(self, id) != 1 {
    return None
  }
  decode_data(ffi_dragging_get_data(self, id))
}

///|
/// 解码 [kind:i32][payload] 编码（拖拽与剪贴板共用）。
fn decode_data(data : Bytes) -> DragData? {
  let pk = data[0].to_int() |
    (data[1].to_int() << 8) |
    (data[2].to_int() << 16) |
    (data[3].to_int() << 24)
  if pk == 3 {
    let mut h : Int64 = 0L
    for i = 0; i < 8; i = i + 1 {
      h = h | (data[4 + i].to_int().to_int64() << (i * 8))
    }
    if h == 0L {
      return None
    }
    Some(Img(ffi_image_from_handle(h)))
  } else {
    let text = @utf8.decode_lossy(data[4:data.length()])
    if pk == 4 {
      Some(Paths(text.split("\n").collect().map(fn(s) { s.to_owned() })))
    } else {
      Some(Text(text))
    }
  }
}

///|
impl ViewLike with fn register_dragged_types(self, kinds : Array[DataKind]) -> Unit {
  let buf = FixedArray::make(kinds.length() * 4, b'\x00')
  for i, k in kinds {
    let id = data_kind_id(k)
    buf[i * 4] = (id & 255).to_byte()
    buf[i * 4 + 1] = ((id >> 8) & 255).to_byte()
    buf[i * 4 + 2] = ((id >> 16) & 255).to_byte()
    buf[i * 4 + 3] = ((id >> 24) & 255).to_byte()
  }
  ffi_view_register_dragged_types(
    self.view(),
    Bytes::from_array(buf),
    kinds.length(),
  )
}

///|
/// 拖动操作位（对照 DragOperation，取 GTK 表值）。
pub const DRAG_OPERATION_COPY : Int = 2

///|
pub const DRAG_OPERATION_MOVE : Int = 4

///|
pub const DRAG_OPERATION_LINK : Int = 8

///|
impl ViewLike with fn do_drag_file_paths(
  self,
  paths : Array[String],
  drag_image : Image?,
) -> Int {
  let sb = StringBuilder()
  for i, p in paths {
    if i > 0 {
      sb.write_char('\n')
    }
    sb.write_string(p)
  }
  let img : Int64 = match drag_image {
    Some(image) => ffi_image_to_handle(image)
    None => 0L
  }
  ffi_view_do_drag_file_paths(
    self.view(),
    utf8_bytes(sb.to_string()),
    DRAG_OPERATION_COPY,
    img,
  )
}

///|
impl ViewLike with fn handle_drag_enter(
  self,
  callback : (DraggingInfo, Double, Double) -> Int,
) -> Unit {
  keep_alive_drag(callback)
  ffi_view_handle_drag_enter(
    self.view(),
    fn(f, info, x, y) { f(info, x, y) },
    callback,
  )
}

///|
impl ViewLike with fn handle_drag_update(
  self,
  callback : (DraggingInfo, Double, Double) -> Int,
) -> Unit {
  keep_alive_drag(callback)
  ffi_view_handle_drag_update(
    self.view(),
    fn(f, info, x, y) { f(info, x, y) },
    callback,
  )
}

///|
impl ViewLike with fn handle_drop(
  self,
  callback : (DraggingInfo, Double, Double) -> Bool,
) -> Unit {
  let wrapped : (DraggingInfo, Double, Double) -> Int = fn(info, x, y) {
    if callback(info, x, y) {
      1
    } else {
      0
    }
  }
  keep_alive_drag(wrapped)
  ffi_view_handle_drop(
    self.view(),
    fn(f, info, x, y) { f(info, x, y) },
    wrapped,
  )
}

///|
impl ViewLike with fn on_drag_leave(self, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_view_on_drag_leave(self.view(), fn(f) { f() }, callback)
}

///|

///|
impl ViewLike with fn get_bounds(self) -> RectF {
  {
    x: ffi_view_get_bounds_x(self.view()),
    y: ffi_view_get_bounds_y(self.view()),
    width: ffi_view_get_bounds_width(self.view()),
    height: ffi_view_get_bounds_height(self.view()),
  }
}

///|
/// 视图在屏幕坐标系中的包围盒（含窗口原点，popup_at 等屏幕坐标 API 的换算依据）。
impl ViewLike with fn get_bounds_in_screen(self) -> RectF {
  {
    x: ffi_view_get_bounds_in_screen_x(self.view()),
    y: ffi_view_get_bounds_in_screen_y(self.view()),
    width: ffi_view_get_bounds_in_screen_width(self.view()),
    height: ffi_view_get_bounds_in_screen_height(self.view()),
  }
}

///|
/// 设置绘制颜色（笔触/文本默认色）。
pub fn Painter::set_color(self : Painter, hex : String) -> Unit {
  ffi_painter_set_color(self, utf8_bytes(hex))
}

///|
/// 鼠标/键盘事件已迁至 events.mbt（对照 events_and_delegates 指南的完整封装）。

///|
/// 窗口阴影。
pub fn Window::set_has_shadow(self : Window, has : Bool) -> Unit {
  ffi_window_set_has_shadow(self.view, if has { 1 } else { 0 })
}

///|
pub fn Window::has_shadow(self : Window) -> Bool {
  ffi_window_has_shadow(self.view) == 1
}

///|
/// 是否允许用户调整大小。
pub fn Window::set_resizable(self : Window, resizable : Bool) -> Unit {
  ffi_window_set_resizable(self.view, if resizable { 1 } else { 0 })
}

///|
pub fn Window::is_resizable(self : Window) -> Bool {
  ffi_window_is_resizable(self.view) == 1
}

///|
pub fn Window::set_maximizable(self : Window, yes : Bool) -> Unit {
  ffi_window_set_maximizable(self.view, if yes { 1 } else { 0 })
}

///|
pub fn Window::set_minimizable(self : Window, yes : Bool) -> Unit {
  ffi_window_set_minimizable(self.view, if yes { 1 } else { 0 })
}

///|
pub fn Window::is_maximized(self : Window) -> Bool {
  ffi_window_is_maximized(self.view) == 1
}

///|
/// 关闭前询问：返回 false 阻止窗口关闭（对照 should_close 委托）。
pub fn Window::set_should_close(self : Window, callback : () -> Bool) -> Unit {
  let wrapped : () -> Int = fn() { if callback() { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_window_set_should_close(self.view, fn(f) { f() }, wrapped)
}
