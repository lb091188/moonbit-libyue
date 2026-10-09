// L2 声明式层：Node 树 + mount（Vue render 函数 / React 元素风格）。
// Node 是"未挂载的 UI 片段"：构造器只是建树，mount 时才实例化控件、
// 挂到父视图并注册回调。children 数组天然异构（Node 是函数字段的存在类型）。
// Node 协议（Node struct、attach、Node::mount_into）在核心包 node.mbt，本包经
// @yue. 使用——components / icons / markdown / charts 等包也直接引用 Node，
// 故 Node 不随本包拆分搬走。
// 自定义控件：用 node_of 包已有视图，或直接写 Node 字面量。
// bind_label / bind：Store / Signal 值驱动的文本节点（挂载即订阅，set 时自动更新文本）。

///|
/// 把已有视图包装成节点（可顺带应用样式）——命令式与声明式混用的桥。
pub fn[T : @yue.ViewLike] node_of(
  v : T,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  @yue.apply_style(v, style~)
  {
    mount: fn(parent) {
      @yue.attach(parent, v.view())
      v.view()
    },
  }
}

///|
fn container_node(
  direction : String,
  children : Array[@yue.Node],
  style : Array[(String, &@yue.StyVal)],
  handle~ : (@yue.Container) -> Unit,
) -> @yue.Node {
  let s = style.copy()
  s.push(("flexDirection", direction))
  // shrink 维持 yoga 默认 0:实测默认 1 会挤压全库固定宽自绘控件
  // (图标墙图标、输入框等,回归面过大已回退)。需要收缩/折行的
  // 容器(如 segmented 超宽换行)显式 style 给 1。
  {
    mount: fn(parent) {
      let c = @yue.Container::make(style=s)
      handle(c)
      @yue.attach(parent, @yue.ViewLike::view(c))
      for ch in children {
        ignore((ch.mount)(@yue.ViewLike::view(c)))
      }
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 垂直布局容器（flexDirection=column，libyue 默认即 column）。
pub fn vbox(
  children : Array[@yue.Node],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  container_node("column", children, style, handle~)
}

///|
/// 水平布局容器（flexDirection=row）。
pub fn hbox(
  children : Array[@yue.Node],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  container_node("row", children, style, handle~)
}

///|
/// 标签节点:文字默认跟随主题常规色(theme_apply 切换深浅即变色),
/// 无需调用方做任何颜色处理。需要自定义颜色时经 handle set_color,
/// 注意主题切换会重置回主题色;固定色场景请改用 label_t 的角色体系
/// 或自行订阅 on_theme_change。handle 在挂载时收到 Label 句柄，
/// 便于后续命令式补充。
pub fn label(
  text : String,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Label) -> Unit = fn(_l) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let l = @yue.Label::make(text, style~)
      @yue.bind_fg(l, fn() { @yue.theme_text_regular() })
      handle(l)
      @yue.attach(parent, @yue.ViewLike::view(l))
      @yue.ViewLike::view(l)
    },
  }
}

///|
/// 按钮节点：标题、点击回调一步到位。
pub fn button(
  title : String,
  on_click? : () -> Unit = fn() {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Button) -> Unit = fn(_b) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let b = @yue.Button::make(title, on_click~, style~)
      handle(b)
      @yue.attach(parent, @yue.ViewLike::view(b))
      @yue.ViewLike::view(b)
    },
  }
}

///|
/// 复选框节点：on_change 收到点击后的勾选状态。
pub fn checkbox(
  title : String,
  checked? : Bool = false,
  on_change? : (Bool) -> Unit = fn(_v) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Button) -> Unit = fn(_b) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let b = @yue.Button::make(title, button_type=@yue.Checkbox, checked~, style~)
      b.on_click(fn() { on_change(b.is_checked()) })
      handle(b)
      @yue.attach(parent, @yue.ViewLike::view(b))
      @yue.ViewLike::view(b)
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
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Entry) -> Unit = fn(_e) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      // Windows 上 height 不直接落到原生控件(文字贴顶),拆出包进
      // 外壳容器(值原样应用,百分比也支持),挂载后一帧读外壳实际
      // 高做 entry_vcenter 垂直居中
      let (make_style, height_kv) = if @yue.platform() == "windows" {
        take_style_height(style)
      } else {
        (style, None)
      }
      let e = @yue.Entry::make(
        text~,
        entry_type=if password { @yue.Password } else { @yue.Normal },
        style=make_style,
      )
      let target : @yue.View = if @yue.platform() == "windows" {
        // 与 entry_t 一致:字体先设(行高测量吻合),控件收窄到行高,
        // height 键值原样包进外壳容器 justifyContent=center 垂直居中
        @yue.ViewLike::set_font(e, @yue.Font::new("Sans", 13.0))
        @yue.ViewLike::set_style(e, "height", @yue.entry_ctrl_height(true))
        let shell_style : Array[(String, &@yue.StyVal)] = match height_kv {
          Some(kv) => [kv]
          None => [("height", @yue.control_height)]
        }
        shell_style.push(("justifyContent", "center"))
        let shell = @yue.themed_container(style=shell_style)
        @yue.attach(@yue.ViewLike::view(shell), @yue.ViewLike::view(e))
        @yue.bind_entry_theme(e)
        @yue.ViewLike::view(shell)
      } else {
        @yue.bind_entry_theme(e)
        @yue.ViewLike::view(e)
      }
      e.on_activate(fn() { on_enter(e.get_text()) })
      e.on_text_change(fn() { on_input(e.get_text()) })
      handle(e)
      @yue.attach(parent, target)
      target
    },
  }
}

///|
/// 从样式表拆出 height 键（重复出现以最后一个为准，按键拆不解析值），
/// 返回剩余样式与被拆出的键值对。
fn take_style_height(
  style : Array[(String, &@yue.StyVal)],
) -> (Array[(String, &@yue.StyVal)], (String, &@yue.StyVal)?) {
  let mut kv : (String, &@yue.StyVal)? = None
  let rest : Array[(String, &@yue.StyVal)] = []
  for pair in style {
    if pair.0 == "height" {
      kv = Some(pair)
    } else {
      rest.push(pair)
    }
  }
  (rest, kv)
}

///|
/// 多行文本框节点：on_input 携带当前文本。
pub fn text_edit(
  text? : String = "",
  on_input? : (String) -> Unit = fn(_s) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.TextEdit) -> Unit = fn(_t) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let t = @yue.TextEdit::make(text~, style~)
      t.on_text_change(fn() { on_input(t.get_text()) })
      handle(t)
      @yue.attach(parent, @yue.ViewLike::view(t))
      @yue.ViewLike::view(t)
    },
  }
}

///|
/// 单选框节点：同一父容器内的单选框自动互斥（libyue 行为）。
pub fn radio(
  title : String,
  checked? : Bool = false,
  on_change? : (Bool) -> Unit = fn(_v) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Button) -> Unit = fn(_b) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let b = @yue.Button::make(title, button_type=@yue.Radio, checked~, style~)
      b.on_click(fn() { on_change(b.is_checked()) })
      handle(b)
      @yue.attach(parent, @yue.ViewLike::view(b))
      @yue.ViewLike::view(b)
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
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Slider) -> Unit = fn(_s) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let s = @yue.Slider::make(value~, range~, step~, style~)
      s.on_value_change(fn() { on_change(s.get_value()) })
      handle(s)
      @yue.attach(parent, @yue.ViewLike::view(s))
      @yue.ViewLike::view(s)
    },
  }
}

///|
/// 进度条节点（value 取 0..1）。
pub fn progress(
  value? : Double = 0.0,
  indeterminate? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.ProgressBar) -> Unit = fn(_p) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let p = @yue.ProgressBar::make(value~, indeterminate~, style~)
      handle(p)
      @yue.attach(parent, @yue.ViewLike::view(p))
      @yue.ViewLike::view(p)
    },
  }
}

///|
/// 下拉选择器节点（选项挂载时填充）。
pub fn picker(
  items? : Array[String] = [],
  selected? : Int = 0,
  on_change? : () -> Unit = fn() {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Picker) -> Unit = fn(_p) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let p = @yue.Picker::make(
        items~,
        selected~,
        on_selection_change=on_change,
        style~,
      )
      handle(p)
      @yue.attach(parent, @yue.ViewLike::view(p))
      @yue.ViewLike::view(p)
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
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.ComboBox) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let c = @yue.ComboBox::make(
        items~,
        selected~,
        on_selection_change=on_select,
        on_text_change=on_input,
        style~,
      )
      handle(c)
      @yue.attach(parent, @yue.ViewLike::view(c))
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 分组框节点：标题 + 内容（内容是任意 Node）。Group 是 View 不是
/// Container,内容必须走 SetContentView（AddChild 会被 shim 类型校验拒绝）,
/// 故先把内容挂进一个容器再整块设为 Group 内容。
pub fn group(
  title : String,
  content : @yue.Node,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let g = @yue.Group::new(title)
      @yue.apply_style(g, style~)
      @yue.attach(parent, @yue.ViewLike::view(g))
      let holder = @yue.Container::new()
      ignore((content.mount)(@yue.ViewLike::view(holder)))
      g.set_content(holder)
      @yue.ViewLike::view(g)
    },
  }
}

///|
/// 滚动容器节点：内容是任意 Node。Scroll 是 View 不是 Container,内容必须
/// 走 SetContentView（AddChild 会被 shim 类型校验拒绝）,故先把内容挂进
/// 一个容器再整块设为滚动内容。
/// 滚动条形态按平台分化(overlay=true 默认且未显式 policy 时):Windows 走
/// 悬浮细条形态——host 容器套原生 Scroll(平台条置 Never 完全隐藏)+ 自绘
/// 主题色 thumb(absolute 占右缘,滚动浮现/停顿渐隐/悬停保持/拖拽/滚轮
/// 转发);其余平台走 set_overlay_scrollbar(Linux 由 app_init 的
/// GTK_OVERLAY_SCROLLING 环境保底,macOS 为 NSScroller overlay)。
/// overlay=false 或显式 policy 仍走平台原生条。
/// 内容在挂载之后才挂进 content(惰性挂载)或明显长高时,经 handle 拿
/// Scroll 调 refresh_content_size 刷新滚动范围。
/// 布局提示：Scroll 视口高度来自弹性分配,作为窗口根或需占满父容器时
/// 要自带 style flex(如 [("flex", 1.0)]),否则视口塌陷为 0(空白)。
pub fn scroll(
  content : @yue.Node,
  content_size? : (Double, Double)? = None,
  policy? : (@yue.ScrollPolicy, @yue.ScrollPolicy)? = None,
  overlay? : Bool = true,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Scroll) -> Unit = fn(_s) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let s = @yue.Scroll::new()
      handle(s)
      match content_size {
        Some((w, h)) => s.set_content_size(w, h)
        None => ()
      }
      match policy {
        Some((h, v)) => s.set_scrollbar_policy(h, v)
        None => ()
      }
      // Windows 上原生子控件(Entry 等)的 HWND 不随容器滚动实时移动,
      // 会浮在滚动内容之上遮挡其它组件;每次滚动后强制重摆一次布局。
      let holder = @yue.Container::new()
      ignore((content.mount)(@yue.ViewLike::view(holder)))
      s.set_content(holder)
      let mounted : @yue.View = if overlay &&
        policy is None &&
        @yue.platform() == "windows" {
        // Windows 悬浮细条:style 挪给 host(thumb 的 absolute 定位以
        // host 为基准,直接挂页面容器会被 padding/margin 带偏),Scroll
        // 在内撑满(flex 配 basis 0 即 CSS flex:1 1 0,高度只由 flex 分配
        // 决定,防内容测量污染致视口塌陷),attach_overlay_thumb 置平台
        // 条 Never 并挂自绘 thumb
        let host = @yue.themed_container(style~)
        @yue.attach(parent, @yue.ViewLike::view(host))
        @yue.ViewLike::set_style(s, "flex", 1.0)
        @yue.ViewLike::set_style(s, "flexbasis", 0.0)
        @yue.attach(@yue.ViewLike::view(host), @yue.ViewLike::view(s))
        attach_overlay_thumb(@yue.ViewLike::view(host), s)
        @yue.ViewLike::view(host)
      } else {
        if overlay {
          s.set_overlay_scrollbar(true)
        } else {
          s.set_overlay_scrollbar(false)
        }
        @yue.apply_style(s, style~)
        @yue.attach(parent, @yue.ViewLike::view(s))
        @yue.ViewLike::view(s)
      }
      if @yue.platform() == "windows" {
        s.on_scroll(fn() {
          @yue.ViewLike::update_layout(holder)
          false
        })
      }
      mounted
    },
  }
}

///|
/// 分隔线节点。
pub fn separator(
  orientation? : @yue.Orientation = @yue.Horizontal,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let s = @yue.Separator::new(orientation)
      @yue.apply_style(s, style~)
      @yue.attach(parent, @yue.ViewLike::view(s))
      @yue.ViewLike::view(s)
    },
  }
}

///|
/// 页签节点：每页自动包一层容器挂载；页内容异构无限制。
pub fn tab(
  pages : Array[(String, @yue.Node)],
  on_change? : () -> Unit = fn() {  },
  handle? : (@yue.Tab) -> Unit = fn(_t) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let t = @yue.Tab::new()
      @yue.apply_style(t, style~)
      for (title, page) in pages {
        let holder = @yue.Container::new()
        ignore((page.mount)(@yue.ViewLike::view(holder)))
        t.add_page(title, holder)
      }
      // 登记放在加页之后:原生添加首页会内部选中一次并回调,那不是
      // 用户切换,先登记会让 on_change 在挂载期空触发(计数类演示
      // 凭空起跳)
      t.on_selected_page_change(on_change)
      handle(t)
      @yue.attach(parent, @yue.ViewLike::view(t))
      @yue.ViewLike::view(t)
    },
  }
}

///|
/// 日期选择器节点。
pub fn date_picker(
  epoch? : Int64? = None,
  on_change? : () -> Unit = fn() {  },
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let d = @yue.DatePicker::make(epoch~, on_date_change=on_change)
      @yue.apply_style(d, style~)
      @yue.attach(parent, @yue.ViewLike::view(d))
      @yue.ViewLike::view(d)
    },
  }
}

///|
/// GIF 播放节点。
pub fn gif(
  image? : @yue.Image? = None,
  scale? : @yue.ImageScale = @yue.Down,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let g = @yue.GifPlayer::make(image~, scale~)
      @yue.apply_style(g, style~)
      @yue.attach(parent, @yue.ViewLike::view(g))
      @yue.ViewLike::view(g)
    },
  }
}

///|
/// 容器节点：需要自绘（on_draw）或要拿 Container 句柄时用；纯布局用
/// vbox/hbox。
pub fn container(
  on_draw? : (@yue.Painter) -> Unit = fn(_p) {  },
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let c = @yue.Container::make(style~)
      c.on_draw(on_draw)
      handle(c)
      @yue.attach(parent, @yue.ViewLike::view(c))
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 声明一棵 UI 树的根：创建容器、挂载全部子节点，返回根容器
/// （直接传给 Window::set_content 或作为更外层的孩子）。
pub fn mount(
  children : Array[@yue.Node],
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Container {
  let root = @yue.Container::make(style~)
  for ch in children {
    ignore((ch.mount)(@yue.ViewLike::view(root)))
  }
  root
}

///|
/// 声明一棵 UI 树并装进窗口：窗口是声明式树的根（Window 无父视图，
/// 故不做 Node，而作为挂载入口）。创建窗口、挂载全部子节点为内容，
/// handle 补挂菜单栏/托盘等非视图资产，随后激活显示——返回后直接
/// run 即可，无需再手动 activate；需抢在显示前调整窗口，写进 handle。
pub fn mount_window(
  children : Array[@yue.Node],
  title? : String = "",
  size? : (Double, Double)? = None,
  center? : Bool = false,
  on_close? : (@yue.Window) -> Unit = fn(_w) {  },
  handle? : (@yue.Window) -> Unit = fn(_w) {  },
) -> @yue.Window {
  let win = @yue.Window::make(title~, size~, on_close~, center~)
  // 根容器默认撑满窗口：scroll 等依赖弹性高度的子节点若不加自己的
  // flex,视口会塌陷为 0(空白窗口),因此根默认 flex=1,子节点按需再给
  win.set_content(mount(children, style=[("flex", 1.0)]))
  handle(win)
  win.activate()
  win
}

///|
/// 声明式文本绑定:节点挂载时创建 Label(初值 f(get))并订阅,
/// 之后每次 set 自动更新文本。Store[A] 通常来自 map 派生。
/// 文本恒单行:默认富文本自动换行,在 hbox 里剩余宽度不足时回显会被
/// 压成两行;这里替换为 wrap=false 的富文本(之后的 set_text 仍在
/// 同一富文本上改写,单行测宽持续生效),并显式钉主题常规文字色
/// (富文本路径不走系统文字色)。
/// 标签宽度跟随文本:set_text 后强制重排一次,变长/变短即时生效
/// (不补则停在挂载时的宽度,长文本截断,详见 adaptation.md)。
pub fn[A] bind_label(
  store : @yue.Store[A],
  f : (A) -> String,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let init = f(store.get())
      let l = @yue.Label::make(init, style~)
      let at = @yue.AttributedText::new(init, valign=@yue.Center, wrap=false)
      at.set_font(@yue.Font::new("Sans", 13.0))
      fn apply_color() -> Unit {
        at.set_color(@yue.theme_text_regular())
        at.set_text(at.get_text())
        @yue.ViewLike::schedule_paint(l)
      }

      apply_color()
      ignore(@yue.on_theme_change(apply_color))
      l.set_attributed_text(at)
      // set_text 只标脏 yoga + 按旧尺寸重绘,不触发布局下发(标签宽度
      // 不会跟随文本变化,变长即截断),须补一次强制重排
      store.subscribe(fn(v) {
        l.set_text(f(v))
        @yue.ViewLike::update_layout(l)
      })
      @yue.attach(parent, @yue.ViewLike::view(l))
      @yue.ViewLike::view(l)
    },
  }
}

///|
/// 声明式文本绑定(信号版):节点挂载时创建 Label(初值 f(get))并
/// 订阅,之后信号变化自动更新文本。与 bind_label(Store) 同一实现内核,
/// 接受源信号或 computed 派生信号。
pub fn[A] bind(
  sig : @yue.Signal[A],
  f : (A) -> String,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  // Store 的字段跨包不可见,Struct 字面量 { sig, } 在包外编译不过,
  // 改用 Signal::store(与 { sig: self, } 等价)完成同包内到跨包的转换
  bind_label(sig.store(), f, style~)
}
