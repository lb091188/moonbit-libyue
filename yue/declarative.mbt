// L2 声明式层：Node 树 + mount（Vue render 函数 / React 元素风格）。
// Node 是"未挂载的 UI 片段"：构造器只是建树，mount 时才实例化控件、
// 挂到父视图并注册回调。children 数组天然异构（Node 是函数字段的存在类型）。
// 自定义控件：用 node_of 包已有视图，或直接写 Node 字面量。

///|
/// 把子视图挂到父视图（父须为容器：Container/Group/Scroll/Tab 均可，
/// 错型由 shim 侧 dynamic_cast 校验拒绝）。
fn attach(parent : View, child : View) -> Unit {
  ffi_container_add_child(parent, child)
}

///|
/// 未挂载的 UI 片段：mount 把自己实例化并挂到 parent，返回自己的视图句柄。
pub(all) struct Node {
  mount : (View) -> View
}

///|
/// 把节点挂到 parent，返回该节点的视图句柄。
pub fn Node::mount_into(self : Node, parent : View) -> View {
  (self.mount)(parent)
}

///|
/// 把已有视图包装成节点（可顺带应用样式）——命令式与声明式混用的桥。
pub fn[T : ViewLike] node_of(
  v : T,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  apply_style(v, style~, style_str~)
  {
    mount: fn(parent) {
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
fn container_node(
  direction : String,
  children : Array[Node],
  style : Array[(String, Double)],
  style_str : Array[(String, String)],
  handle~ : (Container) -> Unit,
) -> Node {
  let sstr = style_str.copy()
  sstr.push(("flexDirection", direction))
  {
    mount: fn(parent) {
      let c = Container::make(style~, style_str=sstr)
      handle(c)
      attach(parent, ViewLike::view(c))
      for ch in children {
        ignore((ch.mount)(ViewLike::view(c)))
      }
      ViewLike::view(c)
    },
  }
}

///|
/// 垂直布局容器（flexDirection=column，libyue 默认即 column）。
pub fn vbox(
  children : Array[Node],
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  container_node("column", children, style, style_str, handle~)
}

///|
/// 水平布局容器（flexDirection=row）。
pub fn hbox(
  children : Array[Node],
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  container_node("row", children, style, style_str, handle~)
}

///|
/// 标签节点:文字默认跟随主题常规色(theme_apply 切换深浅即变色),
/// 无需调用方做任何颜色处理。需要自定义颜色时经 handle set_color,
/// 注意主题切换会重置回主题色;固定色场景请改用 label_t 的角色体系
/// 或自行订阅 on_theme_change。handle 在挂载时收到 Label 句柄，
/// 便于后续命令式补充。
pub fn label(
  text : String,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Label) -> Unit = fn(_l) {  },
) -> Node {
  {
    mount: fn(parent) {
      let l = Label::make(text, style~, style_str~)
      bind_fg(l, fn() { theme_text_regular() })
      handle(l)
      attach(parent, ViewLike::view(l))
      ViewLike::view(l)
    },
  }
}

///|
/// 按钮节点：标题、点击回调一步到位。
pub fn button(
  title : String,
  on_click? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Button) -> Unit = fn(_b) {  },
) -> Node {
  {
    mount: fn(parent) {
      let b = Button::make(title, on_click~, style~, style_str~)
      handle(b)
      attach(parent, ViewLike::view(b))
      ViewLike::view(b)
    },
  }
}

///|
/// 复选框节点：on_change 收到点击后的勾选状态。
pub fn checkbox(
  title : String,
  checked? : Bool = false,
  on_change? : (Bool) -> Unit = fn(_v) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Button) -> Unit = fn(_b) {  },
) -> Node {
  {
    mount: fn(parent) {
      let b = Button::make(
        title,
        button_type=Checkbox,
        checked~,
        style~,
        style_str~,
      )
      b.on_click(fn() { on_change(b.is_checked()) })
      handle(b)
      attach(parent, ViewLike::view(b))
      ViewLike::view(b)
    },
  }
}

///|
/// 单行输入框节点：on_enter 为回车回调、on_input 为内容变化回调，
/// 均携带当前文本。
pub fn entry(
  text? : String = "",
  password? : Bool = false,
  on_enter? : (String) -> Unit = fn(_s) {  },
  on_input? : (String) -> Unit = fn(_s) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Entry) -> Unit = fn(_e) {  },
) -> Node {
  {
    mount: fn(parent) {
      let e = Entry::make(
        text~,
        entry_type=if password { Password } else { Normal },
        style~,
        style_str~,
      )
      e.on_activate(fn() { on_enter(e.get_text()) })
      e.on_text_change(fn() { on_input(e.get_text()) })
      handle(e)
      attach(parent, ViewLike::view(e))
      ViewLike::view(e)
    },
  }
}

///|
/// 多行文本框节点：on_input 携带当前文本。
pub fn text_edit(
  text? : String = "",
  on_input? : (String) -> Unit = fn(_s) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (TextEdit) -> Unit = fn(_t) {  },
) -> Node {
  {
    mount: fn(parent) {
      let t = TextEdit::make(text~, style~, style_str~)
      t.on_text_change(fn() { on_input(t.get_text()) })
      handle(t)
      attach(parent, ViewLike::view(t))
      ViewLike::view(t)
    },
  }
}

///|
/// 单选框节点：同一父容器内的单选框自动互斥（libyue 行为）。
pub fn radio(
  title : String,
  checked? : Bool = false,
  on_change? : (Bool) -> Unit = fn(_v) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Button) -> Unit = fn(_b) {  },
) -> Node {
  {
    mount: fn(parent) {
      let b = Button::make(
        title,
        button_type=Radio,
        checked~,
        style~,
        style_str~,
      )
      b.on_click(fn() { on_change(b.is_checked()) })
      handle(b)
      attach(parent, ViewLike::view(b))
      ViewLike::view(b)
    },
  }
}

///|
/// 滑块节点：on_change 收到当前值。
pub fn slider(
  value? : Double = 0.0,
  range? : (Double, Double)? = None,
  step? : Double? = None,
  on_change? : (Double) -> Unit = fn(_v) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Slider) -> Unit = fn(_s) {  },
) -> Node {
  {
    mount: fn(parent) {
      let s = Slider::make(value~, range~, step~, style~, style_str~)
      s.on_value_change(fn() { on_change(s.get_value()) })
      handle(s)
      attach(parent, ViewLike::view(s))
      ViewLike::view(s)
    },
  }
}

///|
/// 进度条节点（value 取 0..1）。
pub fn progress(
  value? : Double = 0.0,
  indeterminate? : Bool = false,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (ProgressBar) -> Unit = fn(_p) {  },
) -> Node {
  {
    mount: fn(parent) {
      let p = ProgressBar::make(value~, indeterminate~, style~, style_str~)
      handle(p)
      attach(parent, ViewLike::view(p))
      ViewLike::view(p)
    },
  }
}

///|
/// 下拉选择器节点（选项挂载时填充）。
pub fn picker(
  items? : Array[String] = [],
  selected? : Int = 0,
  on_change? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Picker) -> Unit = fn(_p) {  },
) -> Node {
  {
    mount: fn(parent) {
      let p = Picker::make(
        items~,
        selected~,
        on_selection_change=on_change,
        style~,
        style_str~,
      )
      handle(p)
      attach(parent, ViewLike::view(p))
      ViewLike::view(p)
    },
  }
}

///|
/// 可编辑组合框节点。
pub fn combo(
  items? : Array[String] = [],
  selected? : Int = 0,
  on_select? : () -> Unit = fn() {  },
  on_input? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (ComboBox) -> Unit = fn(_c) {  },
) -> Node {
  {
    mount: fn(parent) {
      let c = ComboBox::make(
        items~,
        selected~,
        on_selection_change=on_select,
        on_text_change=on_input,
        style~,
        style_str~,
      )
      handle(c)
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
    },
  }
}

///|
/// 分组框节点：标题 + 内容（内容是任意 Node）。Group 是 View 不是
/// Container,内容必须走 SetContentView（AddChild 会被 shim 类型校验拒绝）,
/// 故先把内容挂进一个容器再整块设为 Group 内容。
pub fn group(
  title : String,
  content : Node,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let g = Group::new(title)
      apply_style(g, style~, style_str~)
      attach(parent, ViewLike::view(g))
      let holder = Container::new()
      ignore((content.mount)(ViewLike::view(holder)))
      g.set_content(holder)
      ViewLike::view(g)
    },
  }
}

///|
/// 滚动容器节点：内容是任意 Node。Scroll 是 View 不是 Container,内容必须
/// 走 SetContentView（AddChild 会被 shim 类型校验拒绝）,故先把内容挂进
/// 一个容器再整块设为滚动内容。
pub fn scroll(
  content : Node,
  content_size? : (Double, Double)? = None,
  policy? : (ScrollPolicy, ScrollPolicy)? = None,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Scroll) -> Unit = fn(_s) {  },
) -> Node {
  {
    mount: fn(parent) {
      let s = Scroll::new()
      handle(s)
      match content_size {
        Some((w, h)) => s.set_content_size(w, h)
        None => ()
      }
      match policy {
        Some((h, v)) => s.set_scrollbar_policy(h, v)
        None => ()
      }
      apply_style(s, style~, style_str~)
      attach(parent, ViewLike::view(s))
      let holder = Container::new()
      ignore((content.mount)(ViewLike::view(holder)))
      s.set_content(holder)
      // Windows 上原生子控件(Entry 等)的 HWND 不随容器滚动实时移动,
      // 会浮在滚动内容之上遮挡其它组件;每次滚动后强制重摆一次布局。
      if platform() == "windows" {
        s.on_scroll(fn() {
          ViewLike::update_layout(holder)
          false
        })
      }
      ViewLike::view(s)
    },
  }
}

///|
/// 分隔线节点。
pub fn separator(
  orientation? : Orientation = Horizontal,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let s = Separator::new(orientation)
      apply_style(s, style~, style_str~)
      attach(parent, ViewLike::view(s))
      ViewLike::view(s)
    },
  }
}

///|
/// 页签节点：每页自动包一层容器挂载；页内容异构无限制。
pub fn tab(
  pages : Array[(String, Node)],
  on_change? : () -> Unit = fn() {  },
  handle? : (Tab) -> Unit = fn(_t) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let t = Tab::new()
      apply_style(t, style~, style_str~)
      t.on_selected_page_change(on_change)
      for (title, page) in pages {
        let holder = Container::new()
        ignore((page.mount)(ViewLike::view(holder)))
        t.add_page(title, holder)
      }
      handle(t)
      attach(parent, ViewLike::view(t))
      ViewLike::view(t)
    },
  }
}

///|
/// 日期选择器节点。
pub fn date_picker(
  epoch? : Int64? = None,
  on_change? : () -> Unit = fn() {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let d = DatePicker::make(epoch~, on_date_change=on_change)
      apply_style(d, style~, style_str~)
      attach(parent, ViewLike::view(d))
      ViewLike::view(d)
    },
  }
}

///|
/// GIF 播放节点。
pub fn gif(
  image? : Image? = None,
  scale? : ImageScale = Down,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let g = GifPlayer::make(image~, scale~)
      apply_style(g, style~, style_str~)
      attach(parent, ViewLike::view(g))
      ViewLike::view(g)
    },
  }
}

///|
/// 内嵌浏览器节点（html 与 url 二选一，都给时以 url 为准）。
pub fn browser(
  url? : String = "",
  html? : String = "",
  handle? : (Browser) -> Unit = fn(_b) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let b = Browser::make(url~, html~)
      apply_style(b, style~, style_str~)
      handle(b)
      attach(parent, ViewLike::view(b))
      ViewLike::view(b)
    },
  }
}

///|
/// 容器节点：需要自绘（on_draw）或要拿 Container 句柄时用；纯布局用
/// vbox/hbox。
pub fn container(
  on_draw? : (Painter) -> Unit = fn(_p) {  },
  handle? : (Container) -> Unit = fn(_c) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let c = Container::make(style~, style_str~)
      c.on_draw(on_draw)
      handle(c)
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
    },
  }
}

///|
/// 声明一棵 UI 树的根：创建容器、挂载全部子节点，返回根容器
/// （直接传给 Window::set_content 或作为更外层的孩子）。
pub fn mount(
  children : Array[Node],
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Container {
  let root = Container::make(style~, style_str~)
  for ch in children {
    ignore((ch.mount)(ViewLike::view(root)))
  }
  root
}

///|
/// 声明一棵 UI 树并装进窗口：窗口是声明式树的根（Window 无父视图，
/// 故不做 Node，而作为挂载入口）。创建窗口、挂载全部子节点为内容，
/// 返回窗口；菜单栏、托盘、全局快捷键等非视图资产经 handle 回调补挂。
pub fn mount_window(
  children : Array[Node],
  title? : String = "",
  size? : (Double, Double)? = None,
  center? : Bool = false,
  on_close? : (Window) -> Unit = fn(_w) {  },
  handle? : (Window) -> Unit = fn(_w) {  },
) -> Window {
  let win = Window::make(title~, size~, on_close~, center~)
  win.set_content(mount(children))
  handle(win)
  win
}
