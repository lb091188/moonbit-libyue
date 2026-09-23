// L1 构造器糖：各控件的 props 风格全参构造器（X::with）。
// 一次调用完成"创建 + 属性 + 回调"，全部建立在既有 setter 之上，
// 语义与对应 setter 完全一致；未涉及的属性仍用 setter 补充。

///|
/// 统一应用样式表：style 为数值型键值对（如 padding/marginBottom），
/// style_str 为字符串型键值对（如 flexDirection="row"）。
pub fn[V : ViewLike] apply_style(
  v : V,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Unit {
  for (k, n) in style {
    v.set_style(k, n)
  }
  for (k, s) in style_str {
    v.set_style_str(k, s)
  }
}

///|
/// 创建窗口（make）：标题、初始尺寸、关闭回调、居中一步到位。
pub fn Window::make(
  title? : String = "",
  size? : (Double, Double)? = None,
  on_close? : (Window) -> Unit = fn(_w) {  },
  center? : Bool = false,
) -> Window {
  let win = Window::new()
  if title != "" {
    win.set_title(title)
  }
  match size {
    Some((w, h)) => win.set_content_size(w, h)
    None => ()
  }
  win.on_close(on_close)
  if center {
    win.center()
  }
  win
}

///|
/// 创建容器并应用样式。
pub fn Container::make(
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Container {
  let c = Container::new()
  apply_style(c, style~, style_str~)
  c
}

///|
/// 创建标签并应用样式。
pub fn Label::make(
  text : String,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Label {
  let l = Label::new(text)
  apply_style(l, style~, style_str~)
  l
}

///|
/// 创建按钮：标题、点击回调、按钮类型、初始勾选一步到位。
pub fn Button::make(
  title : String,
  button_type? : ButtonType = Normal,
  on_click? : () -> Unit = fn() {  },
  checked? : Bool = false,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Button {
  let b = Button::new_of(button_type, title)
  b.on_click(on_click)
  if checked {
    b.set_checked(true)
  }
  apply_style(b, style~, style_str~)
  b
}

///|
/// 创建单行输入框：初始文本、类型（普通/密码）、回车与内容变化回调。
pub fn Entry::make(
  text? : String = "",
  entry_type? : EntryType = Normal,
  on_activate? : () -> Unit = fn() {  },
  on_text_change? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  width_chars? : Int = -1,
) -> Entry {
  let e = if width_chars == -1 {
    Entry::new_of(entry_type)
  } else {
    Entry::new_ex(entry_type, width_chars)
  }
  if text != "" {
    e.set_text(text)
  }
  e.on_activate(on_activate)
  e.on_text_change(on_text_change)
  apply_style(e, style~, style_str~)
  e
}

///|
/// 创建多行文本框：初始文本与内容变化回调。
pub fn TextEdit::make(
  text? : String = "",
  on_text_change? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> TextEdit {
  let t = TextEdit::new()
  if text != "" {
    t.set_text(text)
  }
  t.on_text_change(on_text_change)
  apply_style(t, style~, style_str~)
  t
}

///|
/// 创建滑块：初值、量程 (min, max)、步长、值变化回调。
pub fn Slider::make(
  value? : Double = 0.0,
  range? : (Double, Double)? = None,
  step? : Double? = None,
  on_value_change? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Slider {
  let s = Slider::new()
  match range {
    Some((lo, hi)) => s.set_range(lo, hi)
    None => ()
  }
  match step {
    Some(d) => s.set_step(d)
    None => ()
  }
  s.set_value(value)
  s.on_value_change(on_value_change)
  apply_style(s, style~, style_str~)
  s
}

///|
/// 创建进度条：初值（0..1）与不确定模式。
pub fn ProgressBar::make(
  value? : Double = 0.0,
  indeterminate? : Bool = false,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> ProgressBar {
  let p = ProgressBar::new()
  p.set_value(value)
  if indeterminate {
    p.set_indeterminate(true)
  }
  apply_style(p, style~, style_str~)
  p
}

///|
/// 创建下拉选择器：选项列表、初始选中下标、选择变化回调。
pub fn Picker::make(
  items? : Array[String] = [],
  selected? : Int = 0,
  on_selection_change? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Picker {
  let p = Picker::new()
  for it in items {
    p.add_item(it)
  }
  if selected > 0 && selected < items.length() {
    p.select_item_at(selected)
  }
  p.on_selection_change(on_selection_change)
  apply_style(p, style~, style_str~)
  p
}

///|
/// 创建可编辑组合框：选项列表、初始选中下标、两个变化回调。
pub fn ComboBox::make(
  items? : Array[String] = [],
  selected? : Int = 0,
  on_selection_change? : () -> Unit = fn() {  },
  on_text_change? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> ComboBox {
  let c = ComboBox::new()
  for it in items {
    c.add_item(it)
  }
  if selected > 0 && selected < items.length() {
    c.select_item_at(selected)
  }
  c.on_selection_change(on_selection_change)
  c.on_text_change(on_text_change)
  apply_style(c, style~, style_str~)
  c
}

///|
/// 创建分组框：标题 + 单个内容视图。
pub fn[T : ViewLike] Group::make(
  title : String,
  content : T,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Group {
  let g = Group::new(title)
  g.set_content(content)
  apply_style(g, style~, style_str~)
  g
}

///|
/// 创建滚动容器：内容视图必传，可带内容尺寸与滚动条策略。
pub fn[T : ViewLike] Scroll::make(
  content : T,
  content_size? : (Double, Double)? = None,
  policy? : (ScrollPolicy, ScrollPolicy)? = None,
  overlay? : Bool = true,
) -> Scroll {
  let s = Scroll::new()
  s.set_content(content)
  match content_size {
    Some((w, h)) => s.set_content_size(w, h)
    None => ()
  }
  match policy {
    Some((h, v)) => s.set_scrollbar_policy(h, v)
    None => ()
  }
  if overlay {
    s.set_overlay_scrollbar(true)
  }
  s
}

///|
/// 创建分隔线（默认水平）。
pub fn Separator::make(orientation? : Orientation = Horizontal) -> Separator {
  Separator::new(orientation)
}

///|
/// 创建页签控件：页标题与页内容（每页通常是一个 Container）。
pub fn Tab::make(
  pages? : Array[(String, Container)] = [],
  on_change? : () -> Unit = fn() {  },
) -> Tab {
  let t = Tab::new()
  for (title, page) in pages {
    t.add_page(title, page)
  }
  t.on_selected_page_change(on_change)
  t
}

///|
/// 创建日期选择器：初始日期（epoch 秒）与变化回调。
pub fn DatePicker::make(
  epoch? : Int64? = None,
  on_date_change? : () -> Unit = fn() {  },
) -> DatePicker {
  let d = DatePicker::new()
  match epoch {
    Some(v) => d.set_date(v)
    None => ()
  }
  d.on_date_change(on_date_change)
  d
}

///|
/// 创建 GIF 播放控件：图像与缩放模式。
pub fn GifPlayer::make(
  image? : Image? = None,
  scale? : ImageScale = Down,
) -> GifPlayer {
  let g = GifPlayer::new()
  g.set_scale(scale)
  match image {
    Some(img) => g.set_image(img)
    None => ()
  }
  g
}
