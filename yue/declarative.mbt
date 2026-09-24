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
      // Windows 上 height 不直接落到原生控件(文字贴顶),拆成
      // 「行高控件 + 均分边距」由 entry_vcenter 垂直居中
      let (make_style, box_height) = if platform() == "windows" {
        let (h, rest) = take_style_height(style)
        (rest, h)
      } else {
        (style, None)
      }
      let e = Entry::make(
        text~,
        entry_type=if password { Password } else { Normal },
        style=make_style,
        style_str~,
      )
      if platform() == "windows" {
        // 与 entry_t 一致的字体,保证行高测量与控件实际字体吻合
        ViewLike::set_font(e, Font::new("Sans", 13.0))
        match box_height {
          Some(h) => entry_vcenter(e, h, true)
          None => entry_vcenter(e, control_height, true)
        }
        bind_entry_theme(e)
      }
      e.on_activate(fn() { on_enter(e.get_text()) })
      e.on_text_change(fn() { on_input(e.get_text()) })
      handle(e)
      attach(parent, ViewLike::view(e))
      ViewLike::view(e)
    },
  }
}

///|
/// 从数值样式表取出 height(重复出现以最后一个为准),返回剩余样式。
fn take_style_height(
  style : Array[(String, Double)],
) -> (Double?, Array[(String, Double)]) {
  let mut h : Double? = None
  let rest : Array[(String, Double)] = []
  for pair in style {
    if pair.0 == "height" {
      h = Some(pair.1)
    } else {
      rest.push(pair)
    }
  }
  (h, rest)
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
/// 滚动条形态按平台分化(overlay=true 默认且未显式 policy 时):
/// Windows 走悬浮细条形态——host 容器套原生 Scroll(平台条置 Never 完全
/// 隐藏)+ 自绘主题色 thumb(absolute 占右缘,滚动浮现/停顿渐隐/悬停保持/
/// 拖拽/滚轮转发;thumb 是普通自绘视图,Windows 上事件直接可达,无 GTK
/// 子窗口独占指针事件的透传问题);其余平台走 set_overlay_scrollbar
/// (GTK 原生悬浮形态,Linux 由 app_init 的 GTK_OVERLAY_SCROLLING 环境
/// 保底,macOS 为 NSScroller overlay)。overlay=false 或显式 policy 仍走
/// 平台原生条。
pub fn scroll(
  content : Node,
  content_size? : (Double, Double)? = None,
  policy? : (ScrollPolicy, ScrollPolicy)? = None,
  overlay? : Bool = true,
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
      let holder = Container::new()
      ignore((content.mount)(ViewLike::view(holder)))
      s.set_content(holder)
      // Windows 上滚动平移只更新 content 容器自身的绝对坐标,其子孙里的
      // 原生子控件(Entry/TextEdit 等 HWND)不会跟随——滚轮/拖拽把内容画
      // 走了,原生框仍停在旧屏幕位置,盖住视口外的区域。on_scroll 触发于
      // Scroll 重摆 content 之前,须以 0ms 定时器延到滚动布局完成后的下一
      // 个消息循环拍,再对 content 容器强制重摆子树
      if platform() == "windows" {
        s.on_scroll(fn() {
          let _ = set_timeout(0, fn() { holder.update_child_bounds() })
          false
        })
      }
      // flex:1 的 basis 默认 auto,按内容自然高度测量——内容挂载期
      // (holder 尚无父)的 0×0 yoga 计算会把测量缓存污染成 0,scroll
      // 视口高度塌陷(实测 356→0),原生子控件(Entry 等)的裁剪区随之
      // 恒空、HWND 永不摆位;显式 basis 0(CSS 的 flex:1 1 0 语义)让
      // 高度只由 flex 分配决定,不随内容测量波动。
      // 但 basis 0 只该给参与 flex 分配的 scroll:flex-basis 非 auto 时
      // yoga 走 flex 算法定主轴尺寸,style 的 width/height 不再参与——
      // 靠 width 定尺寸的 scroll(sysmonitor 左栏 292 宽、无 flex)会被
      // 塌成 0,整列消失(真机实测)。有 grow 才有分配,才需要 basis 0。
      for kv in style {
        if (kv.0 == "flex" || kv.0 == "flexgrow") && kv.1 > 0.0 {
          ViewLike::set_style(s, "flexbasis", 0.0)
          break
        }
      }
      if overlay && policy is None && platform() == "windows" {
        // Windows 悬浮细条:style 挪给 host(thumb 的 absolute 定位以
        // host 为基准,直接挂页面容器会被 padding/margin 带偏),Scroll
        // 在内撑满,attach_overlay_thumb 置平台条 Never 并挂自绘 thumb
        let host = themed_container(style~, style_str~)
        attach(parent, ViewLike::view(host))
        // Scroll 自身撑满 host:style 已挪给 host,这里补 flex(配 basis 0
        // 即 CSS 的 flex:1 1 0——高度只由 flex 分配决定;上面按 style 扫描
        // 未必触发,host 场景固定补齐)
        ViewLike::set_style(s, "flex", 1.0)
        ViewLike::set_style(s, "flexbasis", 0.0)
        attach(ViewLike::view(host), ViewLike::view(s))
        attach_overlay_thumb(ViewLike::view(host), s)
        ViewLike::view(host)
      } else {
        if overlay {
          s.set_overlay_scrollbar(true)
        } else {
          s.set_overlay_scrollbar(false)
        }
        apply_style(s, style~, style_str~)
        attach(parent, ViewLike::view(s))
        ViewLike::view(s)
      }
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
      for (title, page) in pages {
        let holder = Container::new()
        ignore((page.mount)(ViewLike::view(holder)))
        t.add_page(title, holder)
      }
      // 登记放在加页之后:原生添加首页会内部选中一次并回调,那不是
      // 用户切换,先登记会让 on_change 在挂载期空触发(计数类演示
      // 凭空起跳)
      t.on_selected_page_change(on_change)
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
/// handle 补挂菜单栏/托盘等非视图资产，随后激活显示——返回后直接
/// run 即可，无需再手动 activate；需抢在显示前调整窗口，写进 handle。
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
  win.activate()
  win
}
