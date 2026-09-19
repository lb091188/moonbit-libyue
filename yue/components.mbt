// Element Plus 风格非表单组件（纯 MoonBit，构建在声明式层之上）。
// 样式约定：直角（无圆角）；hover/active 一律用背景色表达；
// 所有文字经 draw_text 对齐参数居中（水平 align / 垂直 valign），
// 勿用测宽手动摆位（Windows 的测量与绘制格式不一致会偏左，
// 见 docs/adaptation.md）。
//   - side_menu   侧边导航菜单（对应 EP Menu）
//   - segmented   分段控制器 / 顶栏导航（对应 EP Segmented）
//   - tag / tag_of_type  标签（对应 EP Tag）
//   - breadcrumb  面包屑（对应 EP Breadcrumb）
//   - pagination  分页（对应 EP Pagination）
//   - alert       提示横幅（对应 EP Alert）
//   - badge_count 数字角标（对应 EP Badge）
//   - card        卡片（对应 EP Card，标题栏 + 边框）
//   - code_view   代码高亮视图（逐 token 自绘，绕开 Windows 区间设色缺陷）
// 渲染模型：交互项 on_draw 自绘（背景色矩形 + 文字），状态（选中/hover）
// 变化经 schedule_paint 触发重绘。组件间状态协调统一走 Store，无平台代码。

///|
/// 主题色板。经 [theme_apply] 定制（initialize 之后、mount 之前调用最佳）；
/// 组件每次绘制/挂载经 getter 读取当前值。
///|
fn theme_primary() -> String { theme_box.t.primary }

///|
fn theme_primary_light() -> String { theme_box.t.primary_light }

///|
fn theme_primary_hover() -> String { theme_box.t.primary_hover }

///|
fn theme_danger_hover() -> String { theme_box.t.danger_hover }

///|
fn theme_success() -> String { theme_box.t.success }

///|
fn theme_success_light() -> String { theme_box.t.success_light }

///|
fn theme_warning() -> String { theme_box.t.warning }

///|
fn theme_warning_light() -> String { theme_box.t.warning_light }

///|
fn theme_danger() -> String { theme_box.t.danger }

///|
fn theme_danger_light() -> String { theme_box.t.danger_light }

///|
fn theme_info() -> String { theme_box.t.info }

///|
fn theme_info_light() -> String { theme_box.t.info_light }

///|
fn theme_text_primary() -> String { theme_box.t.text_primary }

///|
fn theme_text_regular() -> String { theme_box.t.text_regular }

///|
fn theme_text_secondary() -> String { theme_box.t.text_secondary }

///|
fn theme_border() -> String { theme_box.t.border }

///|
fn theme_fill_hover() -> String { theme_box.t.fill_hover }

///|
fn theme_fill_zebra() -> String { theme_box.t.fill_zebra }

///|
fn theme_bg_panel() -> String { theme_box.t.bg_panel }

///|
/// 焦点/激活反馈色:中性灰(取 text_secondary),不用主题色——
/// 主题蓝只用于主要按钮/选中态等强调语义,active 反馈不喧宾夺主。
/// 焦点环与字段聚焦边框共用。
fn theme_focus_accent() -> String { theme_text_secondary() }

///|
/// 组件库自绘容器:Container::make + 主题切换时自动重绘
/// (draw 回调现取 theme_* 色,重绘即跟随新主题)。
fn themed_container(
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Container {
  let c = Container::make(style~, style_str~)
  on_theme_change(fn() { c.schedule_paint() })
  c
}

///|
/// 面板底色(挂载即设 + 主题切换重设):set_background_color 定死的
/// 底色不经 draw,须订阅重设。
fn[T : ViewLike] set_panel_bg(v : T) -> Unit {
  fn apply() -> Unit {
    v.set_background_color(theme_bg_panel())
  }

  apply()
  on_theme_change(apply)
}

///|
/// 底色绑定:挂载即设 color_of() + 主题切换重设(语义浅底/禁用底等
/// 取自主题色板的静态底色)。
fn[T : ViewLike] bind_bg(v : T, color_of : () -> String) -> Unit {
  fn apply() -> Unit {
    v.set_background_color(color_of())
  }

  apply()
  on_theme_change(apply)
}

///|
/// 前景(文字)色绑定:挂载即设 color_of() + 主题切换重设。
/// 用于挂载期 set_color 定死的文字(Label);主题切换时按表达式重取。
fn[T : ViewLike] bind_fg(v : T, color_of : () -> String) -> Unit {
  fn apply() -> Unit {
    v.set_color(color_of())
  }

  apply()
  on_theme_change(apply)
}

///|
/// 可点击自绘控件统一手型光标。
fn hand() -> Cursor {
  Cursor::new(Hand)
}

///|
/// 主题色板快照。用结构体更新语法做局部定制：
///
/// ```moonbit
/// @yue.theme_apply(
///   @yue.Theme::{ primary: "#1E4FA3", primary_light: "#E3EDFA", ..@yue.default_theme() },
/// )
/// ```
pub struct Theme {
  primary : String
  primary_light : String
  primary_hover : String
  danger_hover : String
  success : String
  success_light : String
  warning : String
  warning_light : String
  danger : String
  danger_light : String
  info : String
  info_light : String
  text_primary : String
  text_regular : String
  text_secondary : String
  border : String
  fill_hover : String
  fill_zebra : String
  /// 页面底色(窗口/滚动区最底层)。
  bg_page : String
  /// 面板底色(卡片/侧栏/输入框/弹层等内容面板)。
  bg_panel : String
}

///|
/// 当前内置默认主题（深色高级变体）。
pub fn default_theme() -> Theme {
  {
    primary: "#2D68C4",
    primary_light: "#E8F0FB",
    primary_hover: "#2459A8",
    danger_hover: "#BC3440",
    success: "#2E9E5B",
    success_light: "#E9F5EE",
    warning: "#D9822B",
    warning_light: "#FBF3E8",
    danger: "#D64550",
    danger_light: "#FBEDED",
    info: "#6B7480",
    info_light: "#F0F2F4",
    text_primary: "#2A2F36",
    text_regular: "#4E5560",
    text_secondary: "#6B7480",
    border: "#D8DCE1",
    fill_hover: "#EFF1F3",
    fill_zebra: "#F5F7FA",
    bg_page: "#F5F6F7",
    bg_panel: "#FFFFFF",
  }
}

///|
/// 内置暗色主题变体：深底浅字，语义 light 变体取深色调。
/// theme_apply 切换后,常驻界面经主题订阅即时重着色(自绘重绘 /
/// 定死色重设 / Linux 原生控件 CSS 重建);弹层内容在下次刷新时跟随。
pub fn dark_theme() -> Theme {
  {
    primary: "#5B8DEF",
    primary_light: "#1E3A5F",
    primary_hover: "#7BA4F4",
    danger_hover: "#E9707A",
    success: "#4CB878",
    success_light: "#1D3B2A",
    warning: "#E5A04C",
    warning_light: "#43351F",
    danger: "#E5646E",
    danger_light: "#45242A",
    info: "#9AA0A6",
    info_light: "#2A2D31",
    text_primary: "#E8EAED",
    text_regular: "#BDC1C6",
    text_secondary: "#9AA0A6",
    border: "#3C4043",
    fill_hover: "#2A2D31",
    fill_zebra: "#232629",
    bg_page: "#141518",
    bg_panel: "#1E2126",
  }
}

///|
/// 主题存储：单个可变快照 + 主题变更订阅（theme_apply 整体替换并通知，
/// 已挂载组件借此即时重着色，暗/浅切换不需要重建界面）。
priv struct ThemeBox {
  mut t : Theme
  subs : Array[() -> Unit]
}

///|
let theme_box : ThemeBox = { t: default_theme(), subs: [] }

///|
/// 读取当前主题快照。
pub fn theme_current() -> Theme {
  theme_box.t
}

///|
/// 订阅主题变更（theme_apply 时回调，快照遍历）。组件在挂载时注册,
/// 用于重设挂载期定死的颜色（容器底色/Label 文字色等）；draw 回调
/// 现取 theme_* 的自绘组件只需在回调里 schedule_paint。
/// 订阅随应用存活,不退订。
pub fn on_theme_change(f : () -> Unit) -> Unit {
  theme_box.subs.push(f)
}

///|
/// 把主题色板生成 CSS 下发 Linux 原生控件(输入框文字/插入符/占位符/
/// 选区、多行输入、滚动条、窗口与弹层底色),使原生观感跟随本主题而非
/// 系统主题。其余平台原生控件已由组件全自绘,空操作。
fn apply_native_theme_css(t : Theme) -> Unit {
  let buf = StringBuilder()
  buf.write_string("label { color: \{t.text_primary}; }")
  buf.write_string("entry { color: \{t.text_primary}; caret-color: \{t.text_primary}; background-color: \{t.bg_panel}; background-image: none; outline-width: 0px; }")
  buf.write_string("entry:not(.yue-borderless) { border: 1px solid \{t.border}; }")
  buf.write_string("entry undershoot { background: none; }")
  buf.write_string("entry selection { background-color: \{t.primary_light}; color: \{t.text_primary}; }")
  buf.write_string("entry placeholder { color: \{t.text_secondary}; }")
  buf.write_string("textview { background-color: \{t.bg_panel}; color: \{t.text_primary}; }")
  buf.write_string("textview text { background-color: \{t.bg_panel}; color: \{t.text_primary}; }")
  buf.write_string("textview text selection { background-color: \{t.primary_light}; color: \{t.text_primary}; }")
  buf.write_string("scrollbar { background-color: transparent; }")
  buf.write_string("scrollbar slider { background-color: \{t.border}; border-radius: 0px; }")
  buf.write_string("scrollbar slider:hover { background-color: \{t.text_secondary}; }")
  buf.write_string("window { background-color: \{t.bg_page}; }")
  buf.write_string("scrolledwindow junction { background-color: \{t.bg_page}; }")
  // 原生 tooltip 恒深底白字(EP 语义,不随色板):系统主题的 tooltip
  // 底/字色来自两处配置,深色系统主题下常见深底深字不可读
  buf.write_string(
    "tooltip, tooltip.background, window.tooltip { background-color: #303133; border-radius: 3px; color: #FFFFFF; }",
  )
  buf.write_string(
    "tooltip label, tooltip.background label, window.tooltip label { color: #FFFFFF; }",
  )
  ffi_apply_native_theme_css(utf8_bytes(buf.to_string()))
}

///|
/// 应用主题:整体替换色板并通知全部订阅者(已挂载组件即时重着色),
/// Linux 端原生控件(输入框/多行/滚动条/窗口与弹层底)CSS 一并重建。
/// 自绘组件的 draw 现取色重绘即生效;挂载期定死的色(容器底色/
/// Label 文字色等)由组件经 on_theme_change 重设,无需重建界面。
pub fn theme_apply(t : Theme) -> Unit {
  theme_box.t = t
  let snapshot = theme_box.subs.copy()
  for f in snapshot {
    f()
  }
  if platform() == "linux" {
    apply_native_theme_css(t)
    // 整体重绘兜底:订阅回调覆盖库内组件,GTK 侧再对全部可见顶层窗口
    // queue_draw,杀掉个别「现取色但停留旧帧」的残留
    ffi_repaint_all()
  }
}

///|
/// 语义类型（EP Tag/Alert 的 type）。
pub(all) enum SemanticType {
  Primary
  Success
  Warning
  Danger
  Info
}

///|
fn type_color(t : SemanticType) -> String {
  match t {
    Primary => theme_primary()
    Success => theme_success()
    Warning => theme_warning()
    Danger => theme_danger()
    Info => theme_info()
  }
}

///|
fn type_light_color(t : SemanticType) -> String {
  match t {
    Primary => theme_primary_light()
    Success => theme_success_light()
    Warning => theme_warning_light()
    Danger => theme_danger_light()
    Info => theme_info_light()
  }
}

///|
/// 焦点环:单层 1px 淡主色描边(默认 40% 透明,不喧宾夺主;
/// 需在深色实底上使用时可传实底友好的颜色,如白色)。
fn draw_focus_ring(p : Painter, w : Double, h : Double, color? : String = theme_focus_accent()) -> Unit {
  p.set_stroke_color(color)
  p.stroke_rect(0.5, 0.5, w - 1.0, h - 1.0)
}

///|
/// 清空按钮 ✕(矢量自绘,不依赖字体字形):中心 (cx,cy),半径 r。
/// 供 clearable 形态的字段在「有值且悬停」时画在右侧清空带内。
fn draw_clear_x(p : Painter, cx : Double, cy : Double, r? : Double = 4.0) -> Unit {
  p.set_stroke_color(theme_text_secondary())
  p.begin_path()
  p.move_to(cx - r, cy - r)
  p.line_to(cx + r, cy + r)
  p.move_to(cx + r, cy - r)
  p.line_to(cx - r, cy + r)
  p.stroke()
}

///|
/// 自绘交互项的焦点接线:可聚焦(Tab 链由 GTK 按挂载顺序遍历)、
/// 聚焦变化时重绘、Enter/Space 触发激活。点击聚焦由各组件在
/// on_mouse_down 里调 focus()。
fn bind_focus(
  v : Container,
  repaint : () -> Unit,
  focused : Ref[Bool],
  on_activate : () -> Unit,
) -> Unit {
  v.set_focusable(true)
  v.on_focus_in(fn() {
    focused.val = true
    repaint()
    false
  })
  v.on_focus_out(fn() {
    focused.val = false
    repaint()
    false
  })
  v.on_key_down(fn(e) {
    if e.code == VKEY_RETURN || e.code == VKEY_SPACE {
      on_activate()
      true
    } else {
      false
    }
  })
}

///|
/// 自绘交互项通用挂载器:背景色表达 hover/active,文字垂直居中。
/// bg_of(active, hover) 返回背景色(空串表示透明);fg_of(active) 返回文字色。
/// align_start=false 时文字水平居中(分段/分页),true 时左对齐(菜单)。
/// (GTK 端水平 align 未实现,居中一律手动:测文本宽、x=(w-文本宽)/2。)
fn stateful_item(
  text : String,
  style : Array[(String, Double)],
  selected : Store[String],
  bg_of : (Bool, Bool) -> String,
  fg_of : (Bool, Bool) -> String,
  pad_x? : Double = 0.0,
  align_start? : Bool = false,
  font_size? : Double = 13.0,
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let focused = Ref(false)
      // 自绘文字不占布局空间:无显式 width 时按文本测宽自动定宽
      let font = Font::new("Sans", font_size)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let mut has_w = false
      for kv in style {
        if kv.0 == "width" {
          has_w = true
        }
      }
      let style2 = if has_w {
        style
      } else {
        let copy = style.copy()
        copy.push(("width", text_w + pad_x * 2.0))
        copy
      }
      let v = themed_container(style=style2)
      fn draw_item(p : Painter) -> Unit {
        let b = v.get_bounds()
        let w = b.width
        let h = b.height
        let act = selected.get() == text
        let bg = bg_of(act, hover.val)
        if bg != "" {
          p.set_fill_color(bg)
          p.fill_rect(0.0, 0.0, w, h)
        }
        // 文字:AttributedText 支持指定字号,垂直居中交给 valign=Center;
        // 水平位置手动计算(见函数注释)
        let at = AttributedText::new(text, valign=Center, wrap=false)
        at.set_font(font)
        at.set_color(fg_of(act, hover.val))
        p.draw_attributed_text(
          at,
          if align_start {
            pad_x
          } else {
            (w - text_w) / 2.0
          },
          0.0,
          w,
          h,
        )
        if focused.val {
          draw_focus_ring(p, w, h)
        }
      }

      v.on_draw(draw_item)
      View::set_cursor(v, hand())
      v.on_mouse_down(fn(e) {
        if e.button == 1 {
          v.focus()
          selected.set(text)
          true
        } else {
          false
        }
      })
      v.on_mouse_enter(fn(_e) {
        hover.val = true
        v.schedule_paint()
      })
      v.on_mouse_leave(fn(_e) {
        hover.val = false
        v.schedule_paint()
      })
      bind_focus(v, fn() { v.schedule_paint() }, focused, fn() {
        selected.set(text)
      })
      selected.subscribe(fn(_s) { v.schedule_paint() })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
fn side_menu_bg(act : Bool, hov : Bool) -> String {
  if act {
    theme_primary_light()
  } else if hov {
    theme_fill_hover()
  } else {
    ""
  }
}

///|
fn side_menu_fg(act : Bool, _hov : Bool) -> String {
  if act {
    theme_primary()
  } else {
    theme_text_primary()
  }
}

///|
/// 侧边导航菜单(对应 EP Menu):hover 浅蓝、选中浅蓝底 + 主题色文字,
/// 直角,文字垂直居中。selected 为共享状态,主区页面可订阅同一 Store
/// 做 set_visible 联动。
pub fn side_menu(
  items : Array[String],
  selected : Store[String],
  width? : Double = 180.0,
) -> Node {
  let nodes : Array[Node] = []
  for it in items {
    nodes.push(
      stateful_item(
        it,
        // 外层 vbox 有 padding 6,项宽 = 总宽 − 两侧 padding,防向右溢出
        [("width", width - 12.0), ("height", 40.0)],
        selected,
        side_menu_bg,
        side_menu_fg,
        pad_x=20.0,
        align_start=true,
      ),
    )
  }
  vbox(nodes, style=[("width", width), ("padding", 6.0)], handle=fn(c) {
    set_panel_bg(c)
  })
}

///|
fn segmented_bg(act : Bool, hov : Bool) -> String {
  if act {
    theme_bg_panel()
  } else if hov {
    theme_border()
  } else {
    ""
  }
}

///|
fn segmented_fg(act : Bool, _hov : Bool) -> String {
  if act {
    theme_primary()
  } else {
    theme_text_regular()
  }
}

///|
/// 分段控制器 / 顶栏导航(对应 EP Segmented):选中白底 + 主题色文字,
/// hover 灰底,直角,文字垂直居中。
pub fn segmented(options : Array[String], selected : Store[String]) -> Node {
  let items : Array[Node] = []
  for opt in options {
    items.push(
      stateful_item(
        opt,
        [("height", 30.0)],
        selected,
        segmented_bg,
        segmented_fg,
        pad_x=16.0,
      ),
    )
  }
  hbox(items, style=[("padding", 2.0)], style_str=[("alignItems", "center")], handle=fn(
    c,
  ) {
    bind_bg(c, fn() { theme_border() })
  })
}

///|
/// 标签(对应 EP Tag 的浅色变体):类型浅底 + 同族深字,直角,
/// 宽度按文本自适应,文字垂直居中。
pub fn tag_of_type(text : String, t : SemanticType) -> Node {
  {
    mount: fn(parent) {
      let font = Font::new("Sans", 12.0)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let w = text_w + 16.0
      let h = 24.0
      let c = themed_container(style=[
        ("width", w),
        ("height", h),
        ("marginRight", 8.0),
      ])
      c.on_draw(fn(p) {
        p.set_fill_color(type_light_color(t))
        p.fill_rect(0.0, 0.0, w, h)
        // 水平手动居中(GTK 端 DrawAttributedText 不实现水平 align)
        p.draw_text(
          text,
          (w - text_w) / 2.0,
          0.0,
          w,
          h,
          valign=Center,
          color=type_color(t),
        )
      })
      attach(parent, c.view())
      c.view()
    },
  }
}

///|
/// 兼容旧用法的彩色实底标签(自定颜色)。
pub fn tag(text : String, color : String, height? : Double = 24.0) -> Node {
  {
    mount: fn(parent) {
      let font = Font::new("Sans", 12.0)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let w = text_w + 16.0
      let c = themed_container(style=[
        ("width", w),
        ("height", height),
        ("marginRight", 8.0),
      ])
      c.on_draw(fn(p) {
        p.set_fill_color(color)
        p.fill_rect(0.0, 0.0, w, height)
        p.draw_text(
          text,
          (w - text_w) / 2.0,
          0.0,
          w,
          height,
          valign=Center,
          color="#FFFFFF",
        )
      })
      attach(parent, c.view())
      c.view()
    },
  }
}

///|
/// 数字角标(对应 EP Badge 的数字形态):红底白字小块,宽度自适应。
pub fn badge_count(count : Int) -> Node {
  tag(count.to_string(), theme_danger(), height=18.0)
}

///|
fn crumb_bg(_act : Bool, _hov : Bool) -> String {
  ""
}

///|
/// 面包屑(对应 EP Breadcrumb):层级随选中态联动——当前项深色不可点,
/// 其余灰色可点、hover 变主题色。
pub fn breadcrumb(items : Array[String], selected : Store[String]) -> Node {
  let nodes : Array[Node] = []
  let mut i = 0
  for it in items {
    if i > 0 {
      nodes.push(
        stateful_item(
          "/",
          [("height", 24.0), ("marginRight", 4.0)],
          Store::new(""),
          crumb_bg,
          crumb_fg_static,
          font_size=13.0,
        ),
      )
    }
    nodes.push(
      stateful_item(
        it,
        [("height", 24.0), ("marginRight", 4.0)],
        selected,
        crumb_bg,
        crumb_fg,
        pad_x=4.0,
        font_size=13.0,
      ),
    )
    i = i + 1
  }
  hbox(nodes, style_str=[("alignItems", "center")])
}

///|
fn crumb_fg(_act : Bool, hov : Bool) -> String {
  if hov {
    theme_primary()
  } else {
    theme_text_secondary()
  }
}

///|
fn crumb_fg_static(_act : Bool, _hov : Bool) -> String {
  theme_text_secondary()
}

///|
/// 提示横幅(对应 EP Alert):类型浅底 + 左侧 4px 色条 + 同族深字,
/// 全宽,文字垂直居中。
pub fn alert(text : String, t : SemanticType, height? : Double = 40.0) -> Node {
  {
    mount: fn(parent) {
      let v = themed_container(style=[("height", height), ("marginBottom", 10.0)])
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let w = b.width
        let h = b.height
        p.set_fill_color(type_light_color(t))
        p.fill_rect(0.0, 0.0, w, h)
        p.set_fill_color(type_color(t))
        p.fill_rect(0.0, 0.0, 4.0, h)
        p.draw_text(
          text,
          16.0,
          0.0,
          w,
          h,
          align=Start,
          valign=Center,
          color=type_color(t),
        )
      })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 分页(EP Pagination):‹ 页码 ›,当前页主题色实底白字,
/// 悬停浅蓝,28×28 直角,文字垂直居中。current 为共享状态(从 1 开始),
/// 点击直接写源 Store,全部按钮同步高亮。
pub fn pagination(current : Store[Int], pages : Int) -> Node {
  {
    mount: fn(parent) {
      let row = themed_container(style=[("height", 30.0)], style_str=[
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ])
      fn add_btn(label : String, target : Int, is_page : Bool) -> Unit {
        let hover = Ref(false)
        let focused = Ref(false)
        let probe = AttributedText::new(label, wrap=false)
        let label_w = probe.get_bounds_for(10000.0, 100.0).width
        let b = themed_container(style=[
          ("width", 28.0),
          ("height", 28.0),
          ("marginRight", 4.0),
        ])
        let activate = fn() -> Unit {
          if is_page {
            current.set(target)
          } else {
            current.update(fn(n) {
              let m = n + target
              if m < 1 {
                1
              } else if m > pages {
                pages
              } else {
                m
              }
            })
          }
        }

        b.on_draw(fn(p) {
          let bd = b.get_bounds()
          let cur = current.get()
          let act = is_page && cur == target
          if act {
            p.set_fill_color(theme_primary())
            p.fill_rect(0.0, 0.0, bd.width, bd.height)
          } else if hover.val {
            p.set_fill_color(theme_primary_light())
            p.fill_rect(0.0, 0.0, bd.width, bd.height)
          }
          p.draw_text(
            label,
            (bd.width - label_w) / 2.0,
            0.0,
            bd.width,
            bd.height,
            valign=Center,
            color=if act { "#FFFFFF" } else { theme_text_regular() },
          )
          if focused.val {
            draw_focus_ring(p, bd.width, bd.height, color="#FFFFFF")
          }
        })
        View::set_cursor(b, hand())
        b.on_mouse_down(fn(e) {
          if e.button == 1 {
            b.focus()
            activate()
            true
          } else {
            false
          }
        })
        bind_focus(b, fn() { b.schedule_paint() }, focused, activate)
        b.on_mouse_enter(fn(_e) {
          hover.val = true
          b.schedule_paint()
        })
        b.on_mouse_leave(fn(_e) {
          hover.val = false
          b.schedule_paint()
        })
        current.subscribe(fn(_v) { b.schedule_paint() })
        row.add_child(b)
      }

      add_btn("‹", -1, false)
      let mut i = 1
      while i <= pages {
        add_btn(i.to_string(), i, true)
        i = i + 1
      }
      add_btn("›", 1, false)
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 卡片(对应 EP Card):白底 + 边框,标题栏(加粗、底部分隔线),
/// 内容区从标题栏下方开始。children 经内层容器挂载,自动留出标题高度。
pub fn card(
  title : String,
  children : Array[Node],
  height? : Double = 160.0,
) -> Node {
  {
    mount: fn(parent) {
      let head_h = 40.0
      let outer = themed_container(style=[("height", height)])
      outer.on_draw(fn(p) {
        let b = outer.get_bounds()
        let w = b.width
        let h = b.height
        // 边框
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.0, 0.0, w, h)
        // 标题栏底部分隔线
        p.set_fill_color(theme_border())
        p.fill_rect(0.0, head_h, w, 1.0)
      })
      // 标题(加粗,垂直居中)
      let title_at = AttributedText::new(title, valign=Center, wrap=false)
      title_at.set_font(Font::new("Sans", 14.0, weight=Bold))
      title_at.set_color(theme_text_primary())
      let title = themed_container(style=[
        ("height", head_h),
        ("paddingLeft", 16.0),
      ])
      fn apply_title_color() -> Unit {
        title_at.set_color(theme_text_primary())
        title.schedule_paint()
      }

      apply_title_color()
      on_theme_change(apply_title_color)
      title.on_draw(fn(p) {
        let b = title.get_bounds()
        p.draw_attributed_text(title_at, 0.0, 0.0, b.width, head_h)
      })
      outer.add_child(title)
      // 内容区
      let body = themed_container(style=[("padding", 14.0)], style_str=[
        ("flexDirection", "column"),
      ])
      for ch in children {
        ignore((ch.mount)(body.view()))
      }
      outer.add_child(body)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 代码高亮的着色单元。
pub(all) struct Token {
  text : String
  color : String
}

///|
/// MoonBit 风格的极简着色器:关键字 / 数字 / 字符串 / 注释 / 普通文本。
/// 仅供演示;消费方可换成任意词法分析结果后直接用 code_view。
pub fn tokenize_moonbit(line : String) -> Array[Token] {
  let keywords = [
    "fn", "let", "mut", "if", "else", "for", "while", "match", "return", "struct",
    "impl", "pub", "enum", "trait", "true", "false",
  ]
  let out : Array[Token] = []
  let cs : Array[Char] = []
  for ch in line {
    cs.push(ch)
  }
  let n = cs.length()
  let buf = Ref(StringBuilder())
  let in_string = Ref(false)
  fn flush() -> Unit {
    let s = buf.val.to_string()
    buf.val = StringBuilder()
    if s.length() > 0 {
      if in_string.val {
        out.push({ text: s, color: "#98C379", })
      } else {
        out.push(classify_token(s, keywords))
      }
    }
  }

  let mut i = 0
  while i < n {
    let ch = cs[i]
    if in_string.val {
      buf.val.write_char(ch)
      if ch == '"' {
        flush()
        in_string.val = false
      }
    } else if ch == '"' {
      flush()
      in_string.val = true
      buf.val.write_char(ch)
    } else if ch == '/' && i + 1 < n && cs[i + 1] == '/' {
      flush()
      // 余下整行是注释
      let comment = StringBuilder()
      while i < n {
        comment.write_char(cs[i])
        i = i + 1
      }
      out.push({ text: comment.to_string(), color: "#5C6370", })
      break
    } else if ch == ' ' {
      flush()
      out.push({ text: " ", color: "#ABB2BF", })
    } else {
      buf.val.write_char(ch)
    }
    i = i + 1
  }
  flush()
  out
}

///|
fn classify_token(word : String, keywords : Array[String]) -> Token {
  for k in keywords {
    if k == word {
      return { text: word, color: "#C678DD", }
    }
  }
  let is_num = word.length() > 0
  for i in 0..<word.length() {
    let c = word.unsafe_get(i).to_int()
    if !((c >= 48 && c <= 57) || c == 46) {
      return { text: word, color: "#ABB2BF", }
    }
  }
  if is_num {
    return { text: word, color: "#D19A66", }
  }
  { text: word, color: "#ABB2BF", }
}

///|
/// 代码高亮视图:逐 token 建 AttributedText(整段设色)+ 测宽后自绘排版。
/// 等价于「区间设色」的视觉效果,但全平台行为一致——Windows 上
/// AttributedText 区间字体/颜色是上游缺陷(见 docs/adaptation.md),此法绕开。
pub fn code_view(
  lines : Array[String],
  font_size? : Double = 13.0,
  width? : Double = 560.0,
) -> Node {
  {
    mount: fn(parent) {
      let font = Font::new("Monospace", font_size)
      fn make_at(text : String, color : String) -> AttributedText {
        let at = AttributedText::new(text, wrap=false)
        at.set_font(font)
        at.set_color(color)
        at
      }

      // 挂载时预排版:逐 token 测宽,避免每次重绘重复分词/测量
      let line_h = make_at("Ag", "#FFFFFF").get_bounds_for(10000.0, 100.0).height +
        5.0
      let laid : Array[(Array[(AttributedText, Double)], Double)] = []
      let mut max_line_w = 0.0
      for line in lines {
        let segs : Array[(AttributedText, Double)] = []
        let mut x = 0.0
        for tok in tokenize_moonbit(line) {
          let at = make_at(tok.text, tok.color)
          let w = at.get_bounds_for(10000.0, 100.0).width
          segs.push((at, x))
          x = x + w
        }
        if x > max_line_w {
          max_line_w = x
        }
        laid.push((segs, x))
      }
      let content_w = max_line_w + 32.0
      let view_w = if width > content_w { width } else { content_w }
      let view_h = line_h * laid.length().to_double() + 28.0
      let c = themed_container(style=[("width", view_w), ("height", view_h)])
      c.set_background_color("#282C34")
      c.on_draw(fn(p) {
        let mut y = 14.0
        for entry in laid {
          for seg in entry.0 {
            let w = seg.0.get_bounds_for(10000.0, 100.0).width
            p.draw_attributed_text(seg.0, seg.1 + 16.0, y, w + 4.0, line_h)
          }
          y = y + line_h
        }
      })
      attach(parent, c.view())
      c.view()
    },
  }
}

///|
/// 头像:方形实底 + 白字居中(EP Avatar 的 square 形态)。
pub fn avatar(letter : String, color : String, size? : Double = 36.0) -> Node {
  {
    mount: fn(parent) {
      let c = themed_container(style=[
        ("width", size),
        ("height", size),
        ("marginRight", 8.0),
      ])
      c.set_background_color(color)
      c.on_draw(fn(p) {
        let b = c.get_bounds()
        p.draw_text(
          letter,
          0.0,
          0.0,
          b.width,
          b.height,
          align=Center,
          valign=Center,
          color="#FFFFFF",
        )
      })
      attach(parent, c.view())
      c.view()
    },
  }
}

///|
/// 圆点徽标(EP Badge 的 dot 形态):8×8 色点。
pub fn badge_dot(color? : String = "") -> Node {
  container(
    on_draw=fn(p) {
      // 空串=默认语义红,draw 现取跟随主题;显式传色则恒定
      p.set_fill_color(if color == "" { theme_danger() } else { color })
      p.fill_rect(0.0, 0.0, 10000.0, 10000.0)
    },
    style=[("width", 8.0), ("height", 8.0), ("marginRight", 6.0)],
  )
}

///|
/// 可关闭横幅:alert + 右侧关闭钮(点击整条隐藏)。
pub fn alert_closeable(text : String, t : SemanticType) -> Node {
  {
    mount: fn(parent) {
      let v = themed_container(
        style=[("height", 40.0), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      bind_bg(v, fn() { type_light_color(t) })
      let label = Label::new("  " + text)
      bind_fg(label, fn() { type_color(t) })
      v.add_child(label)
      // 弹性空白把关闭钮推到右端
      let spacer = themed_container(style=[("flex", 1.0), ("height", 1.0)])
      v.add_child(spacer)
      let close = themed_container(style=[("width", 32.0), ("height", 40.0)])
      let hover = Ref(false)
      let close_focused = Ref(false)
      let close_it = fn() -> Unit {
        v.set_visible(false)
      }

      close.on_draw(fn(p) {
        let b = close.get_bounds()
        p.draw_text(
          "✕",
          0.0,
          0.0,
          b.width,
          b.height,
          align=Center,
          valign=Center,
          color=if hover.val { type_color(t) } else { theme_text_secondary() },
        )
        if close_focused.val {
          draw_focus_ring(p, b.width, b.height)
        }
      })
      View::set_cursor(close, hand())
      close.on_mouse_down(fn(e) {
        if e.button == 1 {
          close.focus()
          close_it()
          true
        } else {
          false
        }
      })
      bind_focus(close, fn() { close.schedule_paint() }, close_focused, close_it)
      close.on_mouse_enter(fn(_e) {
        hover.val = true
        close.schedule_paint()
      })
      close.on_mouse_leave(fn(_e) {
        hover.val = false
        close.schedule_paint()
      })
      v.add_child(close)
      // 让关闭钮靠右:中间垫一个弹性空白
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 步骤条(EP Steps):数字方块(完成浅蓝/当前实底/待办灰)+ 文字 + 连线。
pub fn steps(items : Array[String], current : Store[Int]) -> Node {
  {
    mount: fn(parent) {
      let row = themed_container(
        style=[("height", 40.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let font = Font::new("Sans", 13.0)
      let n = items.length()
      // 数字方块们,重绘时按 current 着色
      let boxes : Array[Container] = []
      for i in 0..<n {
        if i > 0 {
          let line = themed_container(style=[
            ("flex", 1.0),
            ("height", 2.0),
            ("marginRight", 6.0),
          ])
          let idx = i
          line.on_draw(fn(p) {
            let b = line.get_bounds()
            p.set_fill_color(
              if current.get() >= idx {
                theme_primary()
              } else {
                theme_border()
              },
            )
            p.fill_rect(0.0, 0.0, b.width, b.height)
          })
          row.add_child(line)
        }
        let bx = themed_container(style=[
          ("width", 24.0),
          ("height", 24.0),
          ("marginRight", 6.0),
        ])
        bx.on_draw(fn(p) {
          let b = bx.get_bounds()
          let cur = current.get()
          let st = if i < cur {
            0 // done
          } else if i == cur {
            1 // active
          } else {
            2 // todo
          }
          p.set_fill_color(
            match st {
              0 => theme_primary_light()
              1 => theme_primary()
              _ => theme_info_light()
            },
          )
          p.fill_rect(0.0, 0.0, b.width, b.height)
          p.draw_text(
            (i + 1).to_string(),
            0.0,
            0.0,
            b.width,
            b.height,
            align=Center,
            valign=Center,
            color=match st {
              0 => theme_primary()
              1 => "#FFFFFF"
              _ => theme_text_secondary()
            },
          )
        })
        current.subscribe(fn(_v) { bx.schedule_paint() })
        row.add_child(bx)
        boxes.push(bx)
      }
      for i in 0..<n {
        let l = Label::new(items[i])
        l.set_font(font)
        let cur_ref = current
        cur_ref.subscribe(fn(v) {
          l.set_color(
            if i <= v {
              theme_text_primary()
            } else {
              theme_text_secondary()
            },
          )
        })
        l.set_color(
          if i <= current.get() {
            theme_text_primary()
          } else {
            theme_text_secondary()
          },
        )
        row.add_child(l)
      }
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 折叠面板(EP Collapse):点击标题行切换内容显隐,各面板独立开合,
/// 初始仅第一面板展开。
pub fn collapse(panels : Array[(String, Array[Node])]) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(style=[("marginBottom", 12.0)], style_str=[
        ("flexDirection", "column"),
      ])
      let mut first = true
      for entry in panels {
        let open = Ref(first)
        first = false
        let head = themed_container(
          style=[("height", 34.0), ("paddingLeft", 12.0)],
          style_str=[("flexDirection", "row"), ("alignItems", "center")],
        )
        bind_bg(head, fn() { theme_info_light() })
        let head_focused = Ref(false)
        head.on_draw(fn(p) {
          if head_focused.val {
            let b = head.get_bounds()
            draw_focus_ring(p, b.width, b.height)
          }
        })
        // 自绘折叠指示(V 形折线,不依赖字体字形)
        let arrow = themed_container(
          style=[("width", 12.0), ("height", 12.0), ("marginRight", 5.0)],
        )
        arrow.on_draw(fn(p) {
          p.set_stroke_color(theme_primary())
          for off in [0.0, 0.6] {
            p.begin_path()
            if open.val {
              p.move_to(1.5 + off, 4.0)
              p.line_to(6.0 + off, 8.0)
              p.line_to(10.5 + off, 4.0)
            } else {
              p.move_to(4.0, 1.5 + off)
              p.line_to(8.0, 6.0 + off)
              p.line_to(4.0, 10.5 + off)
            }
            p.stroke()
          }
        })
        let title = Label::new(entry.0)
        fn apply_title_color() -> Unit {
          title.set_color(theme_text_primary())
        }

        apply_title_color()
        on_theme_change(apply_title_color)
        head.add_child(arrow)
        head.add_child(title)
        let body = themed_container(style=[("padding", 10.0)], style_str=[
          ("flexDirection", "column"),
        ])
        set_panel_bg(body)
        for ch in entry.1 {
          ignore((ch.mount)(body.view()))
        }
        let apply = fn() -> Unit {
          body.set_visible(open.val)
          arrow.schedule_paint()
        }
        let toggle = fn() -> Unit {
          open.val = !open.val
          apply()
        }

        apply()
        View::set_cursor(head, hand())
        head.on_mouse_down(fn(e) {
          if e.button == 1 {
            head.focus()
            toggle()
            true
          } else {
            false
          }
        })
        bind_focus(head, fn() { head.schedule_paint() }, head_focused, toggle)
        let panel = themed_container(style=[("marginBottom", 6.0)], style_str=[
          ("flexDirection", "column"),
        ])
        panel.add_child(head)
        panel.add_child(body)
        outer.add_child(panel)
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 时间线(EP Timeline):左列色点+竖线,右列标题+描述。item 高固定 56。
pub fn timeline(items : Array[(String, String, SemanticType)]) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(style=[("marginBottom", 12.0)], style_str=[
        ("flexDirection", "column"),
      ])
      let n = items.length()
      let mut i = 0
      for entry in items {
        let is_last = i == n - 1
        let row = themed_container(style=[("height", 56.0)], style_str=[
          ("flexDirection", "row"),
        ])
        let node_col = themed_container(style=[("width", 20.0), ("height", 56.0)])
        let is_first = i == 0
        node_col.on_draw(fn(p) {
          // 竖线:首行从点心起、末行到点心止,中间整行贯通(节点色块居中)
          let b = node_col.get_bounds()
          let cy = b.height / 2.0
          let top = if is_first { cy } else { 0.0 }
          let bottom = if is_last { cy } else { b.height }
          if bottom > top {
            p.set_fill_color(theme_border())
            p.fill_rect(9.0, top, 2.0, bottom - top)
          }
          p.set_fill_color(type_color(entry.2))
          p.fill_rect(5.0, b.height / 2.0 - 5.0, 10.0, 10.0)
        })
        let text_col = themed_container(
          style=[("paddingLeft", 8.0), ("flex", 1.0)],
          style_str=[("flexDirection", "column")],
        )
        let title = Label::new(entry.0)
        fn apply_title_color() -> Unit {
          title.set_color(theme_text_primary())
        }

        apply_title_color()
        on_theme_change(apply_title_color)
        title.set_align(Start)
        let desc = Label::new(entry.1)
        bind_fg(desc, fn() { theme_text_secondary() })
        desc.set_align(Start)
        text_col.add_child(title)
        text_col.add_child(desc)
        row.add_child(node_col)
        row.add_child(text_col)
        outer.add_child(row)
        i = i + 1
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 描述列表(EP Descriptions):键灰值深的两列网格。
pub fn descriptions(pairs : Array[(String, String)]) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(style=[("marginBottom", 12.0)], style_str=[
        ("flexDirection", "column"),
      ])
      for kv in pairs {
        let row = themed_container(style=[("height", 26.0)], style_str=[
          ("flexDirection", "row"),
          ("alignItems", "center"),
        ])
        let k = Label::new(kv.0)
        bind_fg(k, fn() { theme_text_secondary() })
        k.set_align(Start)
        let v = Label::new(kv.1)
        bind_fg(v, fn() { theme_text_primary() })
        v.set_align(Start)
        let key_wrap = themed_container(style=[("width", 110.0)])
        key_wrap.add_child(k)
        row.add_child(key_wrap)
        row.add_child(v)
        outer.add_child(row)
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 结果页(EP Result):大色块符号 + 标题 + 描述 + 自定义按钮区。
pub fn result(
  t : SemanticType,
  title : String,
  desc : String,
  children : Array[Node],
) -> Node {
  {
    mount: fn(parent) {
      // 图标(76+16) + 标题 30 + 描述 24 + 按钮区(8+按钮高约 32)+ 底部留白
      let outer = themed_container(
        style=[("height", 208.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "column"), ("alignItems", "center")],
      )
      let icon = themed_container(style=[
        ("width", 76.0),
        ("height", 76.0),
        ("marginTop", 16.0),
      ])
      let color = type_color(t)
      let symbol = match t {
        Success => "✓"
        Danger => "✕"
        _ => "!"
      }
      // 水平居中交给平台布局引擎(align=Center):Windows 的测宽带内边距,
      // 手动按测量宽摆位必偏左(见 adaptation.md)
      // GTK 端 DrawAttributedText 水平 align 未实现,align=Center 无效,
      // mount 时测宽手动水平居中(库内惯例,见 adaptation)
      let symbol_at = AttributedText::new(symbol, valign=Center, wrap=false)
      symbol_at.set_font(Font::new("Sans", 38.0, weight=Bold))
      symbol_at.set_color(color)
      let symbol_w = symbol_at.get_bounds_for(10000.0, 100.0).width

      bind_bg(icon, fn() { type_light_color(t) })
      icon.on_draw(fn(p) {
        let b = icon.get_bounds()
        p.draw_attributed_text(
          symbol_at,
          (b.width - symbol_w) / 2.0,
          0.0,
          symbol_w,
          b.height,
        )
      })
      let big = themed_container(style=[("height", 30.0)], style_str=[
        ("alignItems", "center"),
      ])
      let t1 = Label::new(title)
      t1.set_font(Font::new("Sans", 18.0, weight=SemiBold))
      bind_fg(t1, fn() { theme_text_primary() })
      big.add_child(t1)
      let sub = themed_container(style=[("height", 24.0)], style_str=[
        ("alignItems", "center"),
      ])
      let t2 = Label::new(desc)
      bind_fg(t2, fn() { theme_text_secondary() })
      sub.add_child(t2)
      let btns = themed_container(style=[("marginTop", 8.0)], style_str=[
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ])
      for ch in children {
        ignore((ch.mount)(btns.view()))
      }
      outer.add_child(icon)
      outer.add_child(big)
      outer.add_child(sub)
      outer.add_child(btns)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 空状态(EP Empty):灰块占位 + 居中说明。
pub fn empty(desc : String) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(
        style=[("height", 140.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "column"), ("alignItems", "center")],
      )
      let box = themed_container(style=[
        ("width", 96.0),
        ("height", 88.0),
        ("marginTop", 12.0),
      ])
      // 自绘简约空箱:盖 + 盒体,不依赖字体符号
      box.on_draw(fn(p) {
        // 不读运行时 bounds:容器宽固定 96,首绘若布局未就绪 cx=0,
        // 图案画到负坐标被裁且无重绘时机("偶尔不显示"根因)
        let cx = 48.0
        // 盒体
        p.set_fill_color(theme_fill_hover())
        p.fill_rect(cx - 26.0, 36.0, 52.0, 34.0)
        p.set_stroke_color(theme_border())
        p.stroke_rect(cx - 26.0, 36.0, 52.0, 34.0)
        // 盖(比体宽,略上叠)
        p.set_fill_color(theme_info_light())
        p.fill_rect(cx - 34.0, 22.0, 68.0, 14.0)
        p.stroke_rect(cx - 34.0, 22.0, 68.0, 14.0)
      })
      let cap = themed_container(style=[("height", 26.0), ("marginTop", 6.0)], style_str=[
        ("alignItems", "center"),
      ])
      let l = Label::new(desc)
      bind_fg(l, fn() { theme_text_secondary() })
      cap.add_child(l)
      outer.add_child(box)
      outer.add_child(cap)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 数值统计(EP Statistic):大号数值(响应式)+ 灰色标题。
pub fn statistic(title : String, value : Store[String]) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(style=[("marginRight", 24.0)], style_str=[
        ("flexDirection", "column"),
      ])
      let num = Label::new(value.get())
      num.set_font(Font::new("Sans", 24.0, weight=SemiBold))
      bind_fg(num, fn() { theme_text_primary() })
      let cap = Label::new(title)
      bind_fg(cap, fn() { theme_text_secondary() })
      value.subscribe(fn(v) { num.set_text(v) })
      outer.add_child(num)
      outer.add_child(cap)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 线性进度条(EP Progress):背景浅灰轨道 + 主题色填充,
/// value 为 Store(0..1),变化自动重绘。
pub fn progress_line(value : Store[Double], height? : Double = 8.0) -> Node {
  {
    mount: fn(parent) {
      let v = themed_container(style=[("flex", 1.0), ("height", height)])
      bind_bg(v, fn() { theme_info_light() })
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let frac = value.get()
        if frac > 0.0 {
          p.set_fill_color(theme_primary())
          p.fill_rect(0.0, 0.0, b.width * frac, b.height)
        }
      })
      value.subscribe(fn(_x) { v.schedule_paint() })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 文字角色(主题排版体系):字号与颜色随角色统一。
pub(all) enum TextRole {
  Title
  Section
  Body
  Secondary
  Accent
}

///|
fn role_font(role : TextRole) -> Font {
  match role {
    Title => Font::new("Sans", 18.0, weight=SemiBold)
    Section => Font::new("Sans", 14.0, weight=SemiBold)
    Body => Font::new("Sans", 13.0)
    Secondary => Font::new("Sans", 12.0)
    Accent => Font::new("Sans", 13.0, weight=SemiBold)
  }
}

///|
fn role_color(role : TextRole) -> String {
  match role {
    Title => theme_text_primary()
    Section => theme_text_primary()
    Body => theme_text_regular()
    Secondary => theme_text_secondary()
    Accent => theme_primary()
  }
}

///|
/// 主题化标签:文字角色统一字号/颜色,左对齐;可叠加布局样式。
pub fn label_t(
  text : String,
  role? : TextRole = Body,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Label) -> Unit = fn(_l) {  },
) -> Node {
  {
    mount: fn(parent) {
      let l = Label::new(text)
      l.set_font(role_font(role))
      fn apply_color() -> Unit {
        l.set_color(role_color(role))
      }

      apply_color()
      on_theme_change(apply_color)
      l.set_align(Start)
      apply_style(l, style~, style_str~)
      handle(l)
      attach(parent, l.view())
      l.view()
    },
  }
}

///|
/// 按钮变体:Solid 主题色实底白字 / Soft 浅底主题色字 /
/// Text 透明底主题色字 / Danger 红色实底白字。
pub(all) enum ButtonVariant {
  Solid
  Soft
  Text
  Danger
}

///|
/// 主题化按钮(自绘,hover 全程收敛在主题内,不交给原生样式):
/// Solid hover 加深 / Soft hover 变实底白字 / Text hover 浅灰底 /
/// Danger hover 加深。
pub fn button_t(
  text : String,
  on_click? : () -> Unit = fn() {  },
  variant? : ButtonVariant = Soft,
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let focused = Ref(false)
      let font = Font::new("Sans", 13.0)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let w = text_w + 32.0
      let v = themed_container(style=[
        ("width", w),
        ("height", 32.0),
        ("marginRight", 8.0),
      ])
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let bg = match variant {
          Solid =>
            if hover.val {
              theme_primary_hover()
            } else {
              theme_primary()
            }
          Soft =>
            if hover.val {
              theme_primary()
            } else {
              theme_primary_light()
            }
          Text =>
            if hover.val {
              theme_fill_hover()
            } else {
              ""
            }
          Danger =>
            if hover.val {
              theme_danger_hover()
            } else {
              theme_danger()
            }
        }
        let fg = match variant {
          Solid => "#FFFFFF"
          Soft => if hover.val { "#FFFFFF" } else { theme_primary() }
          Text => theme_primary()
          Danger => "#FFFFFF"
        }
        if bg != "" {
          p.set_fill_color(bg)
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        // GTK 端 DrawAttributedText 只实现 valign,水平 align 无效——
        // 用 mount 时测的文本宽手动水平居中。
        let at = AttributedText::new(text, valign=Center, wrap=false)
        at.set_font(font)
        at.set_color(fg)
        p.draw_attributed_text(
          at,
          (b.width - text_w) / 2.0,
          0.0,
          b.width,
          b.height,
        )
        // 实底变体上主题色环不可见,焦点环用白色
        if focused.val {
          draw_focus_ring(
            p,
            b.width,
            b.height,
            color=match variant {
              Solid => "#FFFFFF"
              Danger => "#FFFFFF"
              _ => theme_primary()
            },
          )
        }
      })
      View::set_cursor(v, hand())
      v.on_mouse_down(fn(e) {
        if e.button == 1 {
          v.focus()
          on_click()
          true
        } else {
          false
        }
      })
      bind_focus(v, fn() { v.schedule_paint() }, focused, on_click)
      v.on_mouse_enter(fn(_e) {
        hover.val = true
        v.schedule_paint()
      })
      v.on_mouse_leave(fn(_e) {
        hover.val = false
        v.schedule_paint()
      })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 主题化单行输入:统一字体与前景色。
pub fn entry_t(
  text? : String = "",
  password? : Bool = false,
  on_input? : (String) -> Unit = fn(_s) {  },
) -> Node {
  {
    mount: fn(parent) {
      let e = match password {
        true => Entry::make(text~, entry_type=Password)
        false => Entry::make(text~, entry_type=Normal)
      }
      // 注:GTK Entry 上 set_color 会连带渲染背景变黑,故只统一字体
      e.set_font(Font::new("Sans", 13.0))
      // Linux 端 Entry 尺寸已归一化(min-height:0),裸 Entry 自然高只剩
      // 文字行高,补显式高度维持输入框观感
      if platform() == "linux" {
        e.set_style("height", 30.0)
      }
      e.on_text_change(fn() { on_input(e.get_text()) })
      attach(parent, e.view())
      e.view()
    },
  }
}

///|
/// 主题化复选框(自绘,替代原生控件:GTK 原生 Checkbox 的 hover 高亮圈
/// 与直角主题冲突):14x14 直角方框,选中实心主题色 + 白勾,
/// hover 边框变主题色,含禁用态。
pub fn checkbox_t(
  title : String,
  checked? : Bool = false,
  disabled? : Bool = false,
  on_change? : (Bool) -> Unit = fn(_v) {  },
) -> Node {
  {
    mount: fn(parent) {
      let state = Ref(checked)
      let hover = Ref(false)
      let focused = Ref(false)
      let font = Font::new("Sans", 13.0)
      let probe = AttributedText::new(title, wrap=false)
      probe.set_font(font)
      let w = probe.get_bounds_for(10000.0, 100.0).width + 30.0
      let v = themed_container(style=[
        ("width", w),
        ("height", 24.0),
        ("marginBottom", 6.0),
      ])
      let activate = fn() -> Unit {
        state.val = !state.val
        on_change(state.val)
        v.schedule_paint()
      }

      v.on_draw(fn(p) {
        let by = 5.0
        p.set_stroke_color(
          if disabled {
            theme_border()
          } else if state.val || hover.val {
            theme_primary()
          } else {
            theme_border()
          },
        )
        p.stroke_rect(3.5, by + 0.5, 13.0, 13.0)
        if state.val {
          p.set_fill_color(if disabled { theme_border() } else { theme_primary() })
          p.fill_rect(5.0, by + 2.0, 10.0, 10.0)
          // 白勾:折线两段,描两遍(错位 0.5px)近似 2px 线宽,不依赖字体
          p.set_stroke_color("#FFFFFF")
          for off in [0.0, 0.5] {
            p.begin_path()
            p.move_to(6.9 + off, by + 7.4)
            p.line_to(9.0 + off, by + 9.5)
            p.line_to(13.8 + off, by + 4.4)
            p.stroke()
          }
        }
        let at = AttributedText::new(title, valign=Center, wrap=false)
        at.set_font(font)
        at.set_color(if disabled { theme_border() } else { theme_text_regular() })
        p.draw_attributed_text(at, 25.0, 0.0, w, 24.0)
        if focused.val {
          draw_focus_ring(p, w, 24.0)
        }
      })
      let repaint = fn() -> Unit {
        if !disabled {
          v.schedule_paint()
        }
      }
      View::set_cursor(v, hand())
      v.on_mouse_down(fn(e) {
        if e.button == 1 && !disabled {
          v.focus()
          activate()
          true
        } else {
          false
        }
      })
      v.on_mouse_enter(fn(_e) {
        hover.val = true
        repaint()
      })
      v.on_mouse_leave(fn(_e) {
        hover.val = false
        repaint()
      })
      if !disabled {
        bind_focus(v, repaint, focused, activate)
      }
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 单选组:选中项实心方块 + 主题色文字,未选中空心方块,点击互斥。
/// 整行自绘(文字不挂子件,hover 全行生效);GTK 端原生 Radio 不共享组
/// 无法互斥,故自绘指示器。
pub fn radio_group(
  options : Array[String],
  selected : Store[String],
  disabled? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(style=[("marginBottom", 10.0)], style_str=[
        ("flexDirection", "column"),
      ])
      let font = Font::new("Sans", 13.0)
      let rows : Array[Container] = []
      let mut idx = 0
      for opt in options {
        let i = idx
        let probe = AttributedText::new(opt, wrap=false)
        probe.set_font(font)
        let w = probe.get_bounds_for(10000.0, 100.0).width + 30.0
        let hover = Ref(false)
        let focused = Ref(false)
        let row = themed_container(style=[("width", w), ("height", 28.0)])
        let activate = fn() -> Unit {
          selected.set(opt)
        }

        row.on_draw(fn(p) {
          let act = selected.get() == opt
          p.set_stroke_color(
            if disabled {
              theme_border()
            } else if act || hover.val {
              theme_primary()
            } else {
              theme_border()
            },
          )
          p.stroke_rect(3.5, 7.5, 13.0, 13.0)
          if act {
            p.set_fill_color(
              if disabled {
                theme_border()
              } else {
                theme_primary()
              },
            )
            p.fill_rect(7.0, 11.0, 6.0, 6.0)
          }
          let at = AttributedText::new(opt, valign=Center, wrap=false)
          at.set_font(font)
          at.set_color(
            if disabled {
              theme_border()
            } else if act {
              theme_text_primary()
            } else if hover.val {
              theme_primary()
            } else {
              theme_text_regular()
            },
          )
          p.draw_attributed_text(at, 25.0, 0.0, w, 28.0)
          if focused.val {
            draw_focus_ring(p, w, 28.0)
          }
        })
        let repaint = fn() -> Unit {
          if !disabled {
            row.schedule_paint()
          }
        }
        View::set_cursor(row, hand())
        row.on_mouse_down(fn(e) {
          if e.button == 1 && !disabled {
            row.focus()
            activate()
            true
          } else {
            false
          }
        })
        row.on_mouse_enter(fn(_e) {
          hover.val = true
          repaint()
        })
        row.on_mouse_leave(fn(_e) {
          hover.val = false
          repaint()
        })
        if !disabled {
          row.set_focusable(true)
          row.on_focus_in(fn() {
            focused.val = true
            repaint()
            false
          })
          row.on_focus_out(fn() {
            focused.val = false
            repaint()
            false
          })
          // Enter/Space 选中;方向键在组内移动选中并跟随焦点
          row.on_key_down(fn(e) {
            if e.code == VKEY_RETURN || e.code == VKEY_SPACE {
              activate()
              true
            } else if e.code == VKEY_DOWN || e.code == VKEY_RIGHT {
              if i + 1 < options.length() {
                selected.set(options[i + 1])
                rows[i + 1].focus()
                true
              } else {
                false
              }
            } else if e.code == VKEY_UP || e.code == VKEY_LEFT {
              if i > 0 {
                selected.set(options[i - 1])
                rows[i - 1].focus()
                true
              } else {
                false
              }
            } else {
              false
            }
          })
        }
        selected.subscribe(fn(_s) { repaint() })
        rows.push(row)
        outer.add_child(row)
        idx = idx + 1
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 开关(EP Switch 的直角形态):轨道 + 滑块,开=主题蓝轨道滑块靠右,
/// 关=浅灰轨道滑块靠左;点击切换,状态存于 Store[Bool]。
pub fn switch_t(checked : Store[Bool], disabled? : Bool = false) -> Node {
  {
    mount: fn(parent) {
      let v = themed_container(style=[("width", 40.0), ("height", 18.0)])
      let focused = Ref(false)
      let activate = fn() -> Unit {
        checked.set(!checked.get())
      }

      let slider_w = 14.0
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let on = checked.get()
        p.set_fill_color(if on { theme_primary() } else { theme_border() })
        p.fill_rect(0.0, 0.0, b.width, b.height)
        let sx = if on { b.width - slider_w - 2.0 } else { 2.0 }
        p.set_fill_color(if disabled { theme_info_light() } else { theme_bg_panel() })
        p.fill_rect(sx, 2.0, slider_w, b.height - 4.0)
        if focused.val {
          draw_focus_ring(p, b.width, b.height)
        }
      })
      View::set_cursor(v, hand())
      v.on_mouse_down(fn(e) {
        if e.button == 1 && !disabled {
          v.focus()
          activate()
          true
        } else {
          false
        }
      })
      checked.subscribe(fn(_v) { v.schedule_paint() })
      if !disabled {
        bind_focus(v, fn() { v.schedule_paint() }, focused, activate)
      }
      attach(parent, v.view())
      v.view()
    },
  }
}


///|
/// 边框输入框:外层自绘 1px 边框(聚焦变主题色)+ 白底,
/// 内部 Entry 去 native 边框只负责文字;margin 控制外边距,直角。
/// clearable=true 时字段悬停且非空,右侧显示 ✕,点击清空文本
/// (Entry 右侧恒定留出清空带——原生子窗口盖在自绘之上,带内不重叠)。
pub fn input_t(
  text? : String = "",
  password? : Bool = false,
  margin? : Double = 0.0,
  width? : Double = 280.0,
  height? : Double = 30.0,
  clearable? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      let hover = Ref(false)
      let has_text = Ref(text != "")
      let outer = themed_container(
        style=[
          ("width", width),
          ("height", height),
          ("marginTop", margin),
          ("marginBottom", margin),
        ],
      )
      set_panel_bg(outer)
      // 清空带宽 24(✕ 中心在带中央),不显示时也留白,避免 ✕ 被 Entry 盖住
      let clear_x = width - 12.0
      outer.on_draw(fn(p) {
        let b = outer.get_bounds()
        p.set_stroke_color(
          if focused.val { theme_focus_accent() } else { theme_border() },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        if clearable && hover.val && has_text.val {
          draw_clear_x(p, clear_x, b.height / 2.0)
        }
      })
      let entry = match password {
        true => Entry::make(text~, entry_type=Password)
        false => Entry::make(text~, entry_type=Normal)
      }
      entry.set_borderless(true)
      set_panel_bg(entry)
      entry.set_style("flex", 1.0)
      entry.set_style("marginLeft", 10.0)
      entry.set_style("marginRight", if clearable { 26.0 } else { 10.0 })
      // 原生子窗口绘制在自绘之上:上下留 2 让出边框线
      entry.set_style("marginTop", 2.0)
      entry.set_style("marginBottom", 2.0)
      entry.on_focus_in(fn() {
        focused.val = true
        outer.schedule_paint()
        false
      })
      entry.on_focus_out(fn() {
        focused.val = false
        outer.schedule_paint()
        // 光标归 0:文本滚回首端,溢出裁切固定发生在右缘,左侧不再出现
        // 随光标位置变化的余量
        entry.set_position(0)
        false
      })
      if clearable {
        entry.on_text_change(fn() {
          has_text.val = entry.get_text() != ""
          outer.schedule_paint()
        })
        outer.on_mouse_enter(fn(_e) {
          hover.val = true
          outer.schedule_paint()
        })
        outer.on_mouse_leave(fn(_e) {
          hover.val = false
          outer.schedule_paint()
        })
        // 清空带不与 Entry 重叠(其事件窗口只覆盖原生子窗口之外的区域),
        // 点击落在带上即清空
        outer.on_mouse_up(fn(e) {
          let b = outer.get_bounds()
          if e.button == 1 && has_text.val && e.view_x >= b.width - 24.0 {
            entry.set_text("")
            true
          } else {
            false
          }
        })
      }
      outer.add_child(entry)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 数字输入器(EP InputNumber):-/+ 按钮步进,范围钳制,状态存 Store[Double]。
pub fn input_number(
  value : Store[Double],
  min? : Double = 0.0,
  max? : Double = 100.0,
  step? : Double = 1.0,
) -> Node {
  {
    mount: fn(parent) {
      let row = themed_container(
        style=[("height", 30.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let font = Font::new("Sans", 13.0)
      fn step_btn(label : String, dir : Double) -> Unit {
        let b = themed_container(
          style=[("width", 28.0), ("height", 28.0)],
          style_str=[("alignItems", "center")],
        )
        bind_bg(b, fn() { theme_info_light() })
        let hover = Ref(false)
        b.on_draw(fn(p) {
          let bd = b.get_bounds()
          p.set_fill_color(if hover.val { theme_primary_light() } else { theme_info_light() })
          p.fill_rect(0.0, 0.0, bd.width, bd.height)
          p.draw_text(
            label,
            0.0,
            0.0,
            bd.width,
            bd.height,
            align=Center,
            valign=Center,
            color=theme_text_regular(),
          )
        })
        View::set_cursor(b, hand())
        b.on_mouse_down(fn(e) {
          if e.button == 1 {
            value.update(fn(n) {
              let m = n + dir * step
              if m < min {
                min
              } else if m > max {
                max
              } else {
                m
              }
            })
            true
          } else {
            false
          }
        })
        b.on_mouse_enter(fn(_e) {
          hover.val = true
          b.schedule_paint()
        })
        b.on_mouse_leave(fn(_e) {
          hover.val = false
          b.schedule_paint()
        })
        row.add_child(b)
      }

      step_btn("-", -1.0)
      // marginRight 0:EP InputNumber 的按钮与输入区紧贴
      let num = themed_container(
        style=[("width", 64.0), ("height", 28.0), ("marginRight", 0.0)],
        style_str=[("alignItems", "center")],
      )
      set_panel_bg(num)
      let t = AttributedText::new(
        value.get().to_string(),
        valign=Center,
        wrap=false,
      )
      t.set_font(font)
      t.set_color(theme_text_primary())
      num.on_draw(fn(p) {
        // GTK 端 DrawAttributedText 不实现水平 align,手动测宽居中
        let b = num.get_bounds()
        let tw = t.get_bounds_for(10000.0, 100.0).width
        p.draw_attributed_text(t, (b.width - tw) / 2.0, 0.0, b.width, b.height)
      })
      value.subscribe(fn(v) {
        t.set_text(v.to_string())
        num.schedule_paint()
      })
      row.add_child(num)
      step_btn("+", 1.0)
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 表单项:左侧标签(灰,定宽)+ 右侧控件区,垂直居中。
pub fn form_item(label : String, control : Node, label_width? : Double = 90.0) -> Node {
  {
    mount: fn(parent) {
      let row = themed_container(
        style=[("marginBottom", 10.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let k = Label::new(label)
      k.set_font(Font::new("Sans", 13.0))
      bind_fg(k, fn() { theme_text_secondary() })
      k.set_align(End)
      let kwrap = themed_container(style=[("width", label_width), ("marginRight", 12.0)])
      kwrap.add_child(k)
      row.add_child(kwrap)
      ignore((control.mount)(row.view()))
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 表单:分组标题 + 一组表单项。
pub fn form(title : String, items : Array[Node]) -> Node {
  let nodes : Array[Node] = [label_t(title, role=Section)]
  for it in items {
    nodes.push(it)
  }
  vbox(nodes, style=[("marginBottom", 14.0)])
}

///|
/// 链接文字:主题色,悬停加深并显示下划线色条,点击回调。
pub fn link(text : String, on_click : () -> Unit) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let row = themed_container(
        style=[("paddingRight", 6.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let l = Label::new(text)
      l.set_font(Font::new("Sans", 13.0))
      fn apply_color() -> Unit {
        l.set_color(theme_primary())
      }

      apply_color()
      on_theme_change(apply_color)
      row.add_child(l)
      let underline = themed_container(style=[("height", 1.0)])
      bind_bg(underline, fn() { theme_primary() })
      row.add_child(underline)
      fn apply() -> Unit {
        underline.set_visible(hover.val)
      }

      apply()
      row.on_mouse_enter(fn(_e) {
        hover.val = true
        apply()
      })
      row.on_mouse_leave(fn(_e) {
        hover.val = false
        apply()
      })
      View::set_cursor(row, hand())
      row.on_mouse_down(fn(e) {
        if e.button == 1 {
          on_click()
          true
        } else {
          false
        }
      })
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 页头(EP PageHeader):返回链接 + 标题 + 弹性空白 + 右侧操作区。
pub fn page_header(
  title : String,
  on_back : () -> Unit,
  actions? : Array[Node] = [],
) -> Node {
  {
    mount: fn(parent) {
      let row = themed_container(
        style=[("height", 40.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let back = themed_container(
        style=[("width", 56.0), ("height", 40.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let hover = Ref(false)
      back.on_draw(fn(p) {
        let b = back.get_bounds()
        p.draw_text(
          "‹ 返回",
          0.0,
          0.0,
          b.width,
          b.height,
          align=Start,
          valign=Center,
          color=if hover.val { theme_primary() } else { theme_text_regular() },
        )
      })
      View::set_cursor(back, hand())
      back.on_mouse_down(fn(e) {
        if e.button == 1 {
          on_back()
          true
        } else {
          false
        }
      })
      back.on_mouse_enter(fn(_e) {
        hover.val = true
        back.schedule_paint()
      })
      back.on_mouse_leave(fn(_e) {
        hover.val = false
        back.schedule_paint()
      })
      row.add_child(back)
      let t = Label::new(title)
      t.set_font(Font::new("Sans", 15.0, weight=SemiBold))
      bind_fg(t, fn() { theme_text_primary() })
      row.add_child(t)
      let spacer = themed_container(style=[("flex", 1.0), ("height", 1.0)])
      row.add_child(spacer)
      for a in actions {
        ignore((a.mount)(row.view()))
      }
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 树节点数据。
pub(all) struct TreeNode {
  label : String
  children : Array[TreeNode]
}

///|
/// 树形控件(EP Tree):缩进层级 + 点击展开/折叠(有子节点时箭头指示)。
pub fn tree(root : Array[TreeNode]) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(
        style=[("marginBottom", 10.0), ("paddingTop", 2.0)],
        style_str=[("flexDirection", "column")],
      )
      let font = Font::new("Sans", 13.0)
      // 实心小三角箭头(矢量自绘,不依赖字体字形,避免 Windows 端字符发虚)
      fn draw_caret(p : Painter, open : Bool) -> Unit {
        p.set_fill_color(theme_text_secondary())
        p.begin_path()
        if open {
          p.move_to(2.0, 3.5)
          p.line_to(8.0, 3.5)
          p.line_to(5.0, 7.5)
        } else {
          p.move_to(3.5, 2.0)
          p.line_to(7.5, 5.0)
          p.line_to(3.5, 8.0)
        }
        p.close_path()
        p.fill()
      }

      fn build(nodes : Array[TreeNode], level : Int, into : Container) -> Unit {
        for nd in nodes {
          let has_children = nd.children.length() > 0
          let open = Ref(false)
          let indent = level.to_double() * 18.0
          let row = themed_container(
            style=[("height", 32.0), ("marginLeft", indent)],
            style_str=[("flexDirection", "row"), ("alignItems", "center")],
          )
          let arrow = themed_container(
            style=[("width", 10.0), ("height", 10.0), ("marginRight", 3.0)],
          )
          arrow.on_draw(fn(p) {
            if has_children {
              draw_caret(p, open.val)
            }
          })
          let label = Label::new(" " + nd.label)
          label.set_font(font)
          bind_fg(label, fn() { theme_text_primary() })
          row.add_child(arrow)
          row.add_child(label)
          let kids = themed_container(
            style_str=[("flexDirection", "column")],
          )
          kids.set_visible(false)
          if has_children {
            build(nd.children, level + 1, kids)
          }
          View::set_cursor(row, hand())
          row.on_mouse_down(fn(e) {
            if e.button == 1 && has_children {
              open.val = !open.val
              arrow.schedule_paint()
              kids.set_visible(open.val)
              true
            } else {
              false
            }
          })
          into.add_child(row)
          into.add_child(kids)
        }
      }

      build(root, 0, outer)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 穿梭框(EP Transfer):左右两列,点击行选中(实心方块标记),
/// 中间 ›/‹ 按钮把选中项在两列间移动。数据经双 Store 驱动。
pub fn transfer(
  left_items : Store[Array[String]],
  right_items : Store[Array[String]],
  width? : Double = 160.0,
) -> Node {
  {
    mount: fn(parent) {
      let row = themed_container(
        style=[("marginBottom", 10.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let font = Font::new("Sans", 13.0)
      // 选中集合(按值),用 Ref 可变数组
      let left_sel : Ref[Array[String]] = Ref([])
      let right_sel : Ref[Array[String]] = Ref([])
      let left_box = themed_container(
        style=[("width", width)],
        style_str=[("flexDirection", "column")],
      )
      let right_box = themed_container(
        style=[("width", width)],
        style_str=[("flexDirection", "column")],
      )
      fn contains(arr : Array[String], s : String) -> Bool {
        for x in arr {
          if x == s {
            return true
          }
        }
        false
      }

      fn remove_one(arr : Array[String], s : String) -> Array[String] {
        let out : Array[String] = []
        let mut removed = false
        for x in arr {
          if !removed && x == s {
            removed = true
          } else {
            out.push(x)
          }
        }
        out
      }

      let left_rows : Ref[Array[View]] = Ref([])
      let right_rows : Ref[Array[View]] = Ref([])
      fn clear_list(box : Container, rows : Ref[Array[View]]) -> Unit {
        for v in rows.val {
          ignore(box.remove_child_view(v))
        }
        rows.val = []
      }

      fn build_list(
        box : Container,
        items : Store[Array[String]],
        sel : Ref[Array[String]],
        rows : Ref[Array[View]],
      ) -> Unit {
        for it in items.get() {
          let it_ref = it
          let row = themed_container(
            style=[("height", 26.0), ("paddingLeft", 8.0)],
            style_str=[("flexDirection", "row"), ("alignItems", "center")],
          )
          let mark = themed_container(
            style=[("width", 10.0), ("height", 10.0), ("marginRight", 6.0)],
          )
          mark.on_draw(fn(p) {
            let is_sel = contains(sel.val, it_ref)
            p.set_stroke_color(if is_sel { theme_primary() } else { theme_border() })
            p.stroke_rect(0.5, 0.5, 9.0, 9.0)
            if is_sel {
              p.set_fill_color(theme_primary())
              p.fill_rect(3.0, 3.0, 4.0, 4.0)
            }
          })
          let l = Label::new(it_ref)
          l.set_font(font)
          bind_fg(l, fn() { theme_text_regular() })
          row.add_child(mark)
          row.add_child(l)
          let mark_ref = mark
          View::set_cursor(row, hand())
          row.on_mouse_down(fn(e) {
            if e.button == 1 {
              if contains(sel.val, it_ref) {
                sel.val = remove_one(sel.val, it_ref)
              } else {
                let grown = sel.val.copy()
                grown.push(it_ref)
                sel.val = grown
              }
              mark_ref.schedule_paint()
              true
            } else {
              false
            }
          })
          box.add_child(row)
          rows.val.push(row.view())
        }
      }

      fn move_items(from : Store[Array[String]], to : Store[Array[String]], sel : Ref[Array[String]]) -> Unit {
        let moving = sel.val
        let remain : Array[String] = []
        for x in from.get() {
          if !contains(moving, x) {
            remain.push(x)
          }
        }
        let merged = to.get().copy()
        for x in moving {
          merged.push(x)
        }
        from.set(remain)
        to.set(merged)
        sel.val = []
      }

      fn render_all() -> Unit {
        clear_list(left_box, left_rows)
        clear_list(right_box, right_rows)
        build_list(left_box, left_items, left_sel, left_rows)
        build_list(right_box, right_items, right_sel, right_rows)
      }

      left_items.subscribe(fn(_v) { render_all() })
      right_items.subscribe(fn(_v) { render_all() })
      fn mid_btn(label : String, to_right : Bool) -> Unit {
        let b = themed_container(
          style=[("width", 32.0), ("height", 28.0), ("marginRight", 8.0)],
          style_str=[("alignItems", "center")],
        )
        bind_bg(b, fn() { theme_info_light() })
        b.on_draw(fn(p) {
          let bd = b.get_bounds()
          p.draw_text(
            label,
            0.0,
            0.0,
            bd.width,
            bd.height,
            align=Center,
            valign=Center,
            color=theme_text_regular(),
          )
        })
        View::set_cursor(b, hand())
        b.on_mouse_down(fn(e) {
          if e.button == 1 {
            if to_right {
              move_items(left_items, right_items, left_sel)
            } else {
              move_items(right_items, left_items, right_sel)
            }
            true
          } else {
            false
          }
        })
        row.add_child(b)
      }

      row.add_child(left_box)
      mid_btn("›", true)
      mid_btn("‹", false)
      row.add_child(right_box)
      render_all()
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 日期值(年月日,月/日按日常习惯 1 起始)。
pub(all) struct DateYMD {
  y : Int
  m : Int
  d : Int
}

///|
fn date_leap(y : Int) -> Bool {
  y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
}

///|
fn date_days_in_month(y : Int, m : Int) -> Int {
  let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  if m == 2 && date_leap(y) {
    29
  } else {
    days[m - 1]
  }
}

///|
/// 星期几(0 = 周日 .. 6 = 周六),Sakamoto 算法。
fn date_weekday(y : Int, m : Int, d : Int) -> Int {
  let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let yy = if m < 3 { y - 1 } else { y }
  (yy + yy / 4 - yy / 100 + yy / 400 + t[m - 1] + d) % 7
}

///|
/// 格式化为 YYYY-MM-DD(月/日不足两位补零)。
pub fn DateYMD::format(self : DateYMD) -> String {
  fn two(n : Int) -> String {
    if n < 10 {
      "0\{n}"
    } else {
      n.to_string()
    }
  }

  "\{self.y}-\{two(self.m)}-\{two(self.d)}"
}

///|
/// 本地时区的今天(日历"今天"高亮用)。
fn local_date() -> DateYMD {
  let v = ffi_local_date()
  {
    y: (v / 10000).to_int(),
    m: ((v % 10000) / 100).to_int(),
    d: (v % 100).to_int(),
  }
}

///|
/// 构建自绘日历面板(头部 ‹/› 导航 + 星期行 + 42 格月网格),calendar_t
/// 与 date_picker_t 共用。点击当月日期写入 sel 后回调 on_pick;返回面板
/// 与「按当前状态重建网格」函数(外部改 sel 后手动调用刷新)。
fn build_calendar(
  today : DateYMD,
  sel : Ref[DateYMD?],
  on_pick : (DateYMD) -> Unit,
) -> (Container, () -> Unit) {
  let cell_w = 36.0
  let cell_h = 30.0
  // 显式总高:PopoverRootView 按 content_size 硬分配,不读内容自然高度
  // (高 = 上下 padding 16 + 头 32+4 + 星期行 26 + 6 行 x 30)
  let panel = themed_container(
    style=[
      // yoga 的 width 是 border-box 语义(含 padding),须加 16;
      // 只给内容宽 252 会把最后一列(周六)裁掉 16px
      ("width", cell_w * 7.0 + 16.0),
      ("height", 16.0 + 32.0 + 4.0 + 26.0 + 6.0 * cell_h),
      ("padding", 8.0),
    ],
    style_str=[("flexDirection", "column")],
  )
  set_panel_bg(panel)
  panel.on_draw(fn(p) {
    let b = panel.get_bounds()
    p.set_stroke_color(theme_border())
    p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
  })
  let view_y = Ref(today.y)
  let view_m = Ref(today.m)
  // 文本水平居中走 draw_text 的 align 参数(平台布局引擎居中)
  fn draw_center(
    p : Painter,
    text : String,
    y : Double,
    h : Double,
    color : String,
  ) -> Unit {
    p.draw_text(text, 0.0, y, cell_w, h, align=Center, valign=Center, color=color)
  }

  let head_h = 32.0
  let head = themed_container(
    style=[("height", head_h), ("marginBottom", 4.0)],
    style_str=[("flexDirection", "row"), ("alignItems", "center")],
  )
  let title_text = Ref("")
  let title = themed_container(
    style=[("flex", 1.0), ("height", head_h)],
  )
  title.on_draw(fn(p) {
    let b = title.get_bounds()
    p.draw_text(
      title_text.val,
      0.0,
      0.0,
      b.width,
      b.height,
      align=Center,
      valign=Center,
      color=theme_text_primary(),
    )
  })
  fn nav_btn(glyph : String, on_click : () -> Unit) -> Container {
    let hover = Ref(false)
    let b = themed_container(style=[("width", 28.0), ("height", head_h)])
    b.on_draw(fn(p) {
      let bb = b.get_bounds()
      if hover.val {
        p.set_fill_color(theme_fill_hover())
        p.fill_rect(0.0, 0.0, bb.width, bb.height)
      }
      p.draw_text(
        glyph,
        0.0,
        0.0,
        bb.width,
        bb.height,
        align=Center,
        valign=Center,
        color=theme_text_regular(),
      )
    })
    b.on_mouse_enter(fn(_e) {
      hover.val = true
      b.schedule_paint()
    })
    b.on_mouse_leave(fn(_e) {
      hover.val = false
      b.schedule_paint()
    })
    View::set_cursor(b, hand())
    b.on_mouse_down(fn(e) {
      if e.button == 1 {
        on_click()
        true
      } else {
        false
      }
    })
    b
  }

  // 导航按钮先于网格创建,经 Ref 间接调用重建函数
  let rebuild_ref : Ref[() -> Unit] = Ref(fn() {  })
  fn nav(delta : Int) -> Unit {
    let mut m = view_m.val + delta
    let mut y = view_y.val
    if m < 1 {
      m = 12
      y = y - 1
    }
    if m > 12 {
      m = 1
      y = y + 1
    }
    view_y.val = y
    view_m.val = m
    (rebuild_ref.val)()
  }

  head.add_child(nav_btn("‹", fn() { nav(-1) }))
  head.add_child(title)
  head.add_child(nav_btn("›", fn() { nav(1) }))
  let week_h = 26.0
  let wk = themed_container(
    style=[("height", week_h)],
    style_str=[("flexDirection", "row")],
  )
  for name in ["日", "一", "二", "三", "四", "五", "六"] {
    let wref = name
    let c = themed_container(style=[("width", cell_w), ("height", week_h)])
    c.on_draw(fn(p) {
      let b = c.get_bounds()
      draw_center(p, wref, 0.0, b.height, theme_text_secondary())
    })
    wk.add_child(c)
  }
  let grid = themed_container(style_str=[("flexDirection", "column")])
  let cells : Ref[Array[Container]] = Ref([])
  let grid_rows : Ref[Array[Container]] = Ref([])

  fn rebuild_grid() -> Unit {
    for v in grid_rows.val {
      ignore(grid.remove_child_view(v.view()))
    }
    grid_rows.val = []
    cells.val = []
    let y = view_y.val
    let m = view_m.val
    title_text.val = "\{y} 年 \{m} 月"
    title.schedule_paint()
    let first_wd = date_weekday(y, m, 1)
    let dim = date_days_in_month(y, m)
    let dim_prev = date_days_in_month(
      if m == 1 { y - 1 } else { y },
      if m == 1 { 12 } else { m - 1 },
    )
    for row_i in 0..<6 {
      let r = themed_container(style_str=[("flexDirection", "row")])
      for col_i in 0..<7 {
        let idx = row_i * 7 + col_i
        let in_month = idx >= first_wd && idx < first_wd + dim
        let dd = if idx < first_wd {
          dim_prev - (first_wd - 1 - idx)
        } else if in_month {
          idx - first_wd + 1
        } else {
          idx - first_wd - dim + 1
        }
        let dy = if in_month || idx < first_wd {
          if idx < first_wd && m == 1 {
            y - 1
          } else {
            y
          }
        } else if m == 12 {
          y + 1
        } else {
          y
        }
        let dm = if idx < first_wd {
          if m == 1 {
            12
          } else {
            m - 1
          }
        } else if in_month {
          m
        } else if m == 12 {
          1
        } else {
          m + 1
        }
        let dymd : DateYMD = { y: dy, m: dm, d: dd }
        let in_m = in_month
        let hover = Ref(false)
        let c = themed_container(style=[("width", cell_w), ("height", cell_h)])
        c.on_draw(fn(p) {
          let b = c.get_bounds()
          let d = dymd
          let is_sel = match sel.val {
            Some(s) => s.y == d.y && s.m == d.m && s.d == d.d
            None => false
          }
          if hover.val && !is_sel {
            p.set_fill_color(theme_fill_hover())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
          if is_sel {
            p.set_fill_color(theme_primary())
            p.fill_rect(
              (b.width - 28.0) / 2.0,
              (b.height - 28.0) / 2.0,
              28.0,
              28.0,
            )
            draw_center(p, d.d.to_string(), 0.0, b.height, "#FFFFFF")
          } else {
            let color = if !in_m {
              theme_text_secondary()
            } else if today.y == d.y && today.m == d.m && today.d == d.d {
              theme_primary()
            } else {
              theme_text_primary()
            }
            draw_center(p, d.d.to_string(), 0.0, b.height, color)
          }
        })
        if in_m {
          View::set_cursor(c, hand())
          c.on_mouse_down(fn(e) {
            if e.button == 1 {
              sel.val = Some(dymd)
              for cc in cells.val {
                cc.schedule_paint()
              }
              on_pick(dymd)
              true
            } else {
              false
            }
          })
          c.on_mouse_enter(fn(_e) {
            hover.val = true
            c.schedule_paint()
          })
          c.on_mouse_leave(fn(_e) {
            hover.val = false
            c.schedule_paint()
          })
        }
        r.add_child(c)
        cells.val.push(c)
      }
      grid.add_child(r)
      grid_rows.val.push(r)
    }
  }

  rebuild_ref.val = rebuild_grid
  rebuild_grid()
  panel.add_child(head)
  panel.add_child(wk)
  panel.add_child(grid)
  (panel, rebuild_grid)
}

///|
/// 日历面板(EP DatePicker 的面板形态,全自绘):‹/› 切月 + 星期行 +
/// 42 格月网格,跨月日期灰显,「今天」主题色,选中日期实心主题色方块。
/// 点击当月日期回调 on_pick 并写入 value。
pub fn calendar_t(
  on_pick? : (DateYMD) -> Unit = fn(_d) {  },
  value? : Store[DateYMD?],
) -> Node {
  {
    mount: fn(parent) {
      let today = local_date()
      let sel : Ref[DateYMD?] = Ref(match value {
        Some(s) => s.get()
        None => None
      })
      let (panel, refresh) = build_calendar(today, sel, fn(d) {
        match value {
          Some(s) => s.set(Some(d))
          None => ()
        }
        on_pick(d)
      })
      match value {
        Some(s) => s.subscribe(fn(_v) { refresh() })
        None => ()
      }
      attach(parent, panel.view())
      panel.view()
    },
  }
}

///|
/// 日期选择器(EP DatePicker,全自绘):输入框样式字段,点击弹出
/// 自绘日历面板(Popover 承载,三平台弹层基座见 shim),点选回填并收起;
/// 点击其他区域(字段失焦)收起。选中间经 value 同步,回调收 DateYMD。
/// clearable=true 时字段悬停且有值,箭头左侧显示 ✕,点击清空
/// (value 置 None;on_change 签名不带空值,清空不触发回调)。
pub fn date_picker_t(
  value? : Store[DateYMD?],
  on_change? : (DateYMD) -> Unit = fn(_d) {  },
  width? : Double = 200.0,
  placeholder? : String = "请选择日期",
  clearable? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let today = local_date()
      let fnt = Font::new("Sans", 13.0)
      let hover = Ref(false)
      let sel : Ref[DateYMD?] = Ref(match value {
        Some(s) => s.get()
        None => None
      })
      let text = Ref(match sel.val {
        Some(d) => d.format()
        None => placeholder
      })
      let has_val = Ref(match sel.val {
        Some(_) => true
        None => false
      })
      let field = themed_container(
        style=[("width", width), ("height", 30.0), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      set_panel_bg(field)
      View::set_cursor(field, hand())
      let focused = Ref(false)
      field.on_draw(fn(p) {
        let b = field.get_bounds()
        p.set_stroke_color(
          if focused.val { theme_focus_accent() } else { theme_border() },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        let probe = AttributedText::new(text.val, wrap=false)
        probe.set_font(fnt)
        p.draw_text(
          text.val,
          10.0,
          0.0,
          b.width - 30.0,
          b.height,
          valign=Center,
          color=if has_val.val {
            theme_text_primary()
          } else {
            theme_text_secondary()
          },
        )
        // 右侧下拉小箭头(矢量自绘,不依赖字体字形)
        p.set_fill_color(theme_text_secondary())
        p.begin_path()
        p.move_to(b.width - 20.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 12.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 16.0, b.height / 2.0 + 3.0)
        p.close_path()
        p.fill()
        if clearable && hover.val && has_val.val {
          draw_clear_x(p, b.width - 30.0, b.height / 2.0)
        }
      })
      // 弹层与面板:首开时创建,面板重建函数挂入 grid_refresh 供外部同步
      let pop : Ref[Popover?] = Ref(None)
      let grid_refresh : Ref[() -> Unit] = Ref(fn() {  })
      fn apply_date(d : DateYMD) -> Unit {
        sel.val = Some(d)
        text.val = d.format()
        has_val.val = true
        field.schedule_paint()
        match value {
          Some(s) => s.set(Some(d))
          None => ()
        }
        on_change(d)
      }

      field.set_focusable(true)
      field.on_focus_in(fn() {
        focused.val = true
        field.schedule_paint()
        false
      })
      field.on_focus_out(fn() {
        focused.val = false
        field.schedule_paint()
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      field.on_mouse_enter(fn(_e) {
        hover.val = true
        field.schedule_paint()
      })
      field.on_mouse_leave(fn(_e) {
        hover.val = false
        field.schedule_paint()
      })
      field.on_mouse_up(fn(e) {
        if e.button == 1 {
          field.focus()
          // 清空带(箭头左侧)优先:清空日期,不弹日历
          let b = field.get_bounds()
          if clearable && has_val.val && e.view_x >= b.width - 40.0 && e.view_x <= b.width - 20.0 {
            sel.val = None
            text.val = placeholder
            has_val.val = false
            match value {
              Some(s) => s.set(None)
              None => ()
            }
            field.schedule_paint()
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              let (panel, refresh) = build_calendar(today, sel, fn(d) {
                apply_date(d)
                p.close()
              })
              ignore(refresh)
              grid_refresh.val = refresh
              p.set_content(panel)
              // 面板高:上下 padding 16 + 头 36 + 星期 26 + 6 行 x 30
              p.set_content_size(268.0, 262.0)
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      match value {
        Some(s) =>
          s.subscribe(fn(v) {
            sel.val = v
            match v {
              Some(d) => {
                text.val = d.format()
                has_val.val = true
              }
              None => {
                text.val = placeholder
                has_val.val = false
              }
            }
            field.schedule_paint()
            ((grid_refresh.val))()
          })
        None => ()
      }
      attach(parent, field.view())
      field.view()
    },
  }
}

///|
/// 返回顶部浮动按钮:配合 scroll 句柄使用,点击回滚到顶部。
/// 放置于 relative 容器内时经 absolute 定位悬浮右下。
pub fn backtop_t(on_click : () -> Unit, size? : Double = 36.0) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let b = themed_container(
        style=[("width", size), ("height", size)],
      )
      bind_bg(b, fn() { theme_primary() })
      b.on_draw(fn(p) {
        p.draw_text(
          "↑",
          0.0,
          0.0,
          size,
          size,
          align=Center,
          valign=Center,
          color="#FFFFFF",
        )
      })
      View::set_cursor(b, hand())
      b.on_mouse_down(fn(e) {
        if e.button == 1 {
          on_click()
          true
        } else {
          false
        }
      })
      b.on_mouse_enter(fn(_e) {
        hover.val = true
        b.set_background_color(theme_primary_hover())
      })
      b.on_mouse_leave(fn(_e) {
        hover.val = false
        b.set_background_color(theme_primary())
      })
      attach(parent, b.view())
      b.view()
    },
  }
}

///|
/// 表格列定义(EP Table):标题 + 宽度(<=0 为弹性列,均分剩余宽)
/// + 单元格文字对齐。
pub(all) struct TableColumn {
  title : String
  width : Double
  align : TextAlign
}

///|
/// 创建列定义(align 默认左对齐)。
pub fn TableColumn::make(
  title : String,
  width : Double,
  align? : TextAlign = Start,
) -> TableColumn {
  { title, width, align }
}

///|
/// 表格单元格内容(自定义单元格):纯文本 / 语义 tag / 颜色块 / 多行文本。
pub(all) enum TableCell {
  CellText(String)
  CellTag(String, SemanticType)
  CellColorBox(String, String)
  CellLines(Array[String])
}

///|
/// 表格行数据:单元格按列顺序排列,缺位补空文本。
pub(all) struct TableRow {
  cells : Array[TableCell]
}

///|
/// 用纯文本数组建行(全部 CellText 的快捷方式)。
pub fn TableRow::make(cells : Array[String]) -> TableRow {
  let out : Array[TableCell] = []
  for c in cells {
    out.push(CellText(c))
  }
  { cells: out }
}

///|
/// 表格复选框画法(同 checkbox_t):直角方框,选中实心主题色 + 白勾,
/// 部分选中画横条;(x, y) 为 14x14 方框左上角。
fn table_draw_check(
  p : Painter,
  x : Double,
  y : Double,
  checked : Bool,
  partial : Bool,
) -> Unit {
  p.set_stroke_color(
    if checked || partial { theme_primary() } else { theme_border() },
  )
  p.stroke_rect(x + 0.5, y + 0.5, 13.0, 13.0)
  if checked {
    p.set_fill_color(theme_primary())
    p.fill_rect(x + 2.0, y + 2.0, 10.0, 10.0)
    p.set_stroke_color("#FFFFFF")
    for off in [0.0, 0.5] {
      p.begin_path()
      p.move_to(x + 3.9 + off, y + 7.4)
      p.line_to(x + 6.0 + off, y + 9.5)
      p.line_to(x + 10.8 + off, y + 4.4)
      p.stroke()
    }
  } else if partial {
    p.set_fill_color(theme_primary())
    p.fill_rect(x + 4.0, y + 6.0, 6.0, 2.0)
  }
}

///|
/// 行底色:选中 > 悬停 > 斑马纹(奇数行) > 透明。
fn table_row_bg(i : Int, selected : Bool, hover : Bool) -> String {
  if selected {
    theme_primary_light()
  } else if hover {
    theme_fill_hover()
  } else if i % 2 == 1 {
    theme_fill_zebra()
  } else {
    ""
  }
}

///|
/// 表格(EP Table):表头 + 斑马纹 + 悬停底色 + Store 驱动(set 后整表
/// 重建行并清空选择)。不传 selection 时行点击单选高亮;传入
/// selection(Store[Array[Int]])启用复选框列:行点击勾选,表头全选/
/// 清空(部分选中画横条),选中行浅蓝底。单元格支持 CellText/CellTag/
/// CellColorBox/CellLines(多行文本的行自动撑高)。主题色在重绘时读取
/// 当前快照,theme_apply 即时生效。
pub fn table_t(
  columns : Array[TableColumn],
  rows : Store[Array[TableRow]],
  width? : Double = 560.0,
  row_height? : Double = 36.0,
  selection? : Store[Array[Int]],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i, _r) { },
) -> Node {
  {
    mount: fn(parent) {
      let font = Font::new("Sans", 13.0)
      let small_font = Font::new("Sans", 12.0)
      let head_font = Font::new("Sans", 13.0, weight=SemiBold)
      let sel = selection
      let selected_i = Ref(-1)
      let hover_i = Ref(-1)
      let row_cs : Ref[Array[Container]] = Ref([])
      let data_r : Ref[Array[TableRow]] = Ref([])
      let head_h = 40.0
      // 1px 内边距让外框描边落在 padding 环里,不被行/表头背景盖住
      let outer = themed_container(
        style=[("width", width), ("padding", 1.0), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "column")],
      )
      outer.on_draw(fn(p) {
        let b = outer.get_bounds()
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
      })

      fn sel_has(i : Int) -> Bool {
        match sel {
          Some(s) => {
            for x in s.get() {
              if x == i {
                return true
              }
            }
            false
          }
          None => false
        }
      }

      fn toggle_sel(i : Int) -> Unit {
        match sel {
          Some(s) => {
            let out : Array[Int] = []
            let mut had = false
            for x in s.get() {
              if x == i {
                had = true
              } else {
                out.push(x)
              }
            }
            if !had {
              out.push(i)
            }
            s.set(out)
          }
          None => ()
        }
      }

      // 单元格:定宽列给 width,弹性列给 flex,左右各留 12px 内边距
      fn cell_view(
        content : TableCell,
        col : TableColumn,
        fnt : Font,
        color_of : () -> String,
      ) -> Container {
        let base : Array[(String, Double)] = if col.width > 0.0 {
          [("width", col.width), ("paddingLeft", 12.0), ("paddingRight", 12.0)]
        } else {
          [("flex", 1.0), ("paddingLeft", 12.0), ("paddingRight", 12.0)]
        }
        let wrap = themed_container(
          style=base,
          style_str=[("flexDirection", "row"), ("alignItems", "center")],
        )
        match content {
          CellText(text) => {
            let l = Label::new(text)
            l.set_font(fnt)
            bind_fg(l, color_of)
            l.set_align(col.align)
            l.set_style("flex", 1.0)
            wrap.add_child(l)
          }
          CellTag(text, t) => {
            let probe = AttributedText::new(text, wrap=false)
            probe.set_font(small_font)
            let text_w = probe.get_bounds_for(10000.0, 100.0).width
            let w = text_w + 14.0
            let tg = themed_container(style=[("width", w), ("height", 20.0)])
            tg.on_draw(fn(p) {
              p.set_fill_color(type_light_color(t))
              p.fill_rect(0.0, 0.0, w, 20.0)
              p.draw_text(
                text,
                0.0,
                0.0,
                w,
                20.0,
                align=Center,
                valign=Center,
                color=type_color(t),
              )
            })
            wrap.add_child(tg)
          }
          CellColorBox(hex, name) => {
            let sw = themed_container(style=[("width", 14.0), ("height", 14.0)])
            sw.on_draw(fn(p) {
              p.set_fill_color(hex)
              p.fill_rect(0.0, 0.0, 14.0, 14.0)
              p.set_stroke_color(theme_border())
              p.stroke_rect(0.5, 0.5, 13.0, 13.0)
            })
            wrap.add_child(sw)
            let l = Label::new(name)
            l.set_font(small_font)
            bind_fg(l, color_of)
            l.set_align(col.align)
            l.set_style("flex", 1.0)
            l.set_style("marginLeft", 6.0)
            wrap.add_child(l)
          }
          CellLines(lines) => {
            let stack = themed_container(
              style=[("paddingTop", 6.0), ("paddingBottom", 6.0)],
              style_str=[("flexDirection", "column")],
            )
            for ln in lines {
              let l = Label::new(ln)
              l.set_font(small_font)
              bind_fg(l, fn() { theme_text_regular() })
              stack.add_child(l)
            }
            stack.set_style("flex", 1.0)
            wrap.add_child(stack)
          }
        }
        wrap
      }

      // 表头:主题斑马色打底 + 底边分隔线,次级色加粗文字
      let head = themed_container(
        style=[("height", head_h)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      head.on_draw(fn(p) {
        let b = head.get_bounds()
        p.set_fill_color(theme_fill_zebra())
        p.fill_rect(0.0, 0.0, b.width, b.height)
        p.set_stroke_color(theme_border())
        p.begin_path()
        p.move_to(0.0, b.height - 0.5)
        p.line_to(b.width, b.height - 0.5)
        p.stroke()
      })
      // 表头复选框(仅 selection 启用时):全选 / 清空,部分选中画横条
      let head_cb = themed_container(style=[("width", 36.0), ("height", head_h)])
      head_cb.on_draw(fn(p) {
        let b = head_cb.get_bounds()
        let n = data_r.val.length()
        let k = match sel {
          Some(s) => s.get().length()
          None => 0
        }
        table_draw_check(
          p,
          11.0,
          (b.height - 14.0) / 2.0,
          n > 0 && k == n,
          k > 0 && k < n,
        )
      })
      View::set_cursor(head_cb, hand())
      head_cb.on_mouse_down(fn(e) {
        if e.button == 1 {
          match sel {
            Some(s) => {
              let n = data_r.val.length()
              if n > 0 && s.get().length() == n {
                s.set([])
              } else {
                let all : Array[Int] = []
                for i in 0..<n {
                  all.push(i)
                }
                s.set(all)
              }
            }
            None => ()
          }
          true
        } else {
          false
        }
      })
      match sel {
        Some(_) => head.add_child(head_cb)
        None => ()
      }
      for col in columns {
        head.add_child(
          cell_view(
            CellText(col.title),
            col,
            head_font,
            fn() { theme_text_secondary() },
          ),
        )
      }
      let body = themed_container(style_str=[("flexDirection", "column")])

      fn refresh_row(i : Int) -> Unit {
        let cs = row_cs.val
        if i >= 0 && i < cs.length() {
          cs[i].schedule_paint()
        }
      }

      fn rebuild(data : Array[TableRow]) -> Unit {
        for v in row_cs.val {
          ignore(body.remove_child_view(v.view()))
        }
        row_cs.val = []
        data_r.val = data
        selected_i.val = -1
        hover_i.val = -1
        match sel {
          Some(s) => s.set([])
          None => ()
        }
        for i in 0..<data.length() {
          let r = data[i]
          let idx = i
          // minHeight:普通行 = row_height,含多行文本时自动撑高
          let row = themed_container(
            style=[("minHeight", row_height)],
            style_str=[("flexDirection", "row"), ("alignItems", "center")],
          )
          row.on_draw(fn(p) {
            let bg = table_row_bg(idx, sel_has(idx), hover_i.val == idx)
            if bg != "" {
              let b = row.get_bounds()
              p.set_fill_color(bg)
              p.fill_rect(0.0, 0.0, b.width, b.height)
            }
          })
          match sel {
            Some(_) => {
              let cb = themed_container(
                style=[("width", 36.0)],
                style_str=[("alignSelf", "stretch")],
              )
              cb.on_draw(fn(p) {
                let b = cb.get_bounds()
                table_draw_check(
                  p,
                  11.0,
                  (b.height - 14.0) / 2.0,
                  sel_has(idx),
                  false,
                )
              })
              row.add_child(cb)
            }
            None => ()
          }
          for j in 0..<columns.length() {
            let content = if j < r.cells.length() {
              r.cells[j]
            } else {
              CellText("")
            }
            row.add_child(
              cell_view(content, columns[j], font, fn() {
                theme_text_regular()
              }),
            )
          }
          row.on_mouse_enter(fn(_e) {
            hover_i.val = idx
            refresh_row(idx)
          })
          row.on_mouse_leave(fn(_e) {
            let prev = hover_i.val
            hover_i.val = -1
            refresh_row(prev)
          })
          View::set_cursor(row, hand())
          row.on_mouse_down(fn(e) {
            if e.button == 1 {
              match sel {
                Some(_) => toggle_sel(idx)
                None => {
                  let prev = selected_i.val
                  selected_i.val = idx
                  refresh_row(prev)
                  refresh_row(idx)
                }
              }
              on_row_click(idx, r)
              true
            } else {
              false
            }
          })
          body.add_child(row)
          row_cs.val.push(row)
        }
        head_cb.schedule_paint()
      }

      rebuild(rows.get())
      rows.subscribe(rebuild)
      match sel {
        Some(s) =>
          s.subscribe(fn(_v) {
            for c in row_cs.val {
              c.schedule_paint()
            }
            head_cb.schedule_paint()
          })
        None => ()
      }
      outer.add_child(head)
      outer.add_child(body)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 虚拟滚动表格(table_t 的 L3 万行级形态):整面 canvas 自绘、只画可见行,
/// 自管滚动——滚轮(Linux 经 shim scroll-event)/拖拽滚动条/键盘,不受原生
/// 滚动容器的内容高度上限约束(X11 子窗口高度 65535,万行内容放不进
/// GtkViewport)。单元格画法与 table_t 一致(CellLines 在行高内最多画
/// 两行);selection 语义同 table_t(复选框列 + 表头全选)。
pub fn table_v_t(
  columns : Array[TableColumn],
  rows : Store[Array[TableRow]],
  width? : Double = 560.0,
  height? : Double = 360.0,
  row_height? : Double = 32.0,
  selection? : Store[Array[Int]],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i, _r) { },
) -> Node {
  {
    mount: fn(parent) {
      let small_font = Font::new("Sans", 12.0)
      let sel = selection
      let data_r : Ref[Array[TableRow]] = Ref([])
      let selected_i = Ref(-1)
      let hover_i = Ref(-1)
      let offset = Ref(0.0)
      let dragging = Ref(false)
      let head_h = 40.0
      let bar_w = 10.0
      let body_w = width - bar_w
      let vis_h = height - head_h
      // 列几何:固定宽直接用,弹性列均分剩余宽度
      let mut fixed = 0.0
      let mut flex_count = 0
      for col in columns {
        if col.width > 0.0 {
          fixed = fixed + col.width
        } else {
          flex_count = flex_count + 1
        }
      }
      let flex_w = if flex_count > 0 {
        ((body_w - fixed) / flex_count.to_double()).max(0.0)
      } else {
        0.0
      }
      let col_x : Array[Double] = []
      let col_w : Array[Double] = []
      let mut acc = 0.0
      for col in columns {
        let w = if col.width > 0.0 {
          col.width
        } else {
          flex_w
        }
        col_x.push(acc)
        col_w.push(w)
        acc = acc + w
      }
      let cv = themed_container(
        style=[("width", width), ("height", height), ("marginBottom", 10.0)],
      )

      fn sel_has(i : Int) -> Bool {
        match sel {
          Some(s) => {
            for x in s.get() {
              if x == i {
                return true
              }
            }
            false
          }
          None => false
        }
      }

      fn toggle_sel(i : Int) -> Unit {
        match sel {
          Some(s) => {
            let out : Array[Int] = []
            let mut had = false
            for x in s.get() {
              if x == i {
                had = true
              } else {
                out.push(x)
              }
            }
            if !had {
              out.push(i)
            }
            s.set(out)
          }
          None => ()
        }
      }

      fn toggle_all() -> Unit {
        match sel {
          Some(s) => {
            let n = data_r.val.length()
            if n > 0 && s.get().length() == n {
              s.set([])
            } else {
              let all : Array[Int] = []
              for i in 0..<n {
                all.push(i)
              }
              s.set(all)
            }
          }
          None => ()
        }
      }

      fn total_h() -> Double {
        head_h + data_r.val.length().to_double() * row_height
      }

      fn max_offset() -> Double {
        (total_h() - vis_h).max(0.0)
      }

      fn clamp_offset() -> Unit {
        let m = max_offset()
        if offset.val > m {
          offset.val = m
        }
        if offset.val < 0.0 {
          offset.val = 0.0
        }
      }

      // 文本按列对齐交给平台布局引擎(align 参数):Windows 的测宽与绘制
      // 格式不一致,手动按测量宽摆位会偏左(见 adaptation.md)。水平方向
      // 两侧统一留 12px。
      fn draw_align_text(
        p : Painter,
        text : String,
        align : TextAlign,
        x : Double,
        w : Double,
        y : Double,
        h : Double,
        color : String,
      ) -> Unit {
        if text == "" {
          return
        }
        p.draw_text(
          text,
          x + 12.0,
          y,
          w - 24.0,
          h,
          align=align,
          valign=Center,
          color=color,
        )
      }

      cv.on_draw(fn(p) {
        let b = cv.get_bounds()
        let data = data_r.val
        let n = data.length()
        // 表头
        p.set_fill_color(theme_fill_zebra())
        p.fill_rect(0.0, 0.0, b.width, head_h)
        p.set_stroke_color(theme_border())
        p.begin_path()
        p.move_to(0.0, head_h - 0.5)
        p.line_to(b.width, head_h - 0.5)
        p.stroke()
        match sel {
          Some(s) => {
            let k = s.get().length()
            table_draw_check(
              p,
              11.0,
              (head_h - 14.0) / 2.0,
              n > 0 && k == n,
              k > 0 && k < n,
            )
          }
          None => ()
        }
        for j in 0..<columns.length() {
          draw_align_text(
            p,
            columns[j].title,
            columns[j].align,
            col_x[j],
            col_w[j],
            0.0,
            head_h,
            theme_text_secondary(),
          )
        }
        // 可见行窗口(裁剪到表头以下,行滚动经过时不遮盖表头)
        p.save()
        p.clip_rect(0.0, head_h, b.width, vis_h)
        let first = (offset.val / row_height).to_int()
        let mut last = ((offset.val + vis_h) / row_height).ceil().to_int() + 1
        if last > n {
          last = n
        }
        for i in first..<last {
          let row_y = head_h + i.to_double() * row_height - offset.val
          let bg = table_row_bg(i, sel_has(i), hover_i.val == i)
          if bg != "" {
            p.set_fill_color(bg)
            p.fill_rect(0.0, row_y, body_w, row_height)
          }
          if sel is Some(_) {
            table_draw_check(
              p,
              11.0,
              row_y + (row_height - 14.0) / 2.0,
              sel_has(i),
              false,
            )
          }
          let r = data[i]
          for j in 0..<columns.length() {
            let content = if j < r.cells.length() {
              r.cells[j]
            } else {
              CellText("")
            }
            let x = col_x[j]
            let w = col_w[j]
            match content {
              CellText(text) =>
                draw_align_text(
                  p,
                  text,
                  columns[j].align,
                  x,
                  w,
                  row_y,
                  row_height,
                  theme_text_regular(),
                )
              CellTag(text, t) => {
                let probe = AttributedText::new(text, wrap=false)
                probe.set_font(small_font)
                let tw = probe.get_bounds_for(10000.0, 100.0).width
                let tag_w = tw + 14.0
                let ty = row_y + (row_height - 20.0) / 2.0
                p.set_fill_color(type_light_color(t))
                p.fill_rect(x + 12.0, ty, tag_w, 20.0)
                p.draw_text(
                  text,
                  x + 12.0,
                  ty,
                  tag_w,
                  20.0,
                  align=Center,
                  valign=Center,
                  color=type_color(t),
                )
              }
              CellColorBox(hex, name) => {
                let sy = row_y + (row_height - 14.0) / 2.0
                p.set_fill_color(hex)
                p.fill_rect(x + 12.0, sy, 14.0, 14.0)
                p.set_stroke_color(theme_border())
                p.stroke_rect(x + 12.5, sy + 0.5, 13.0, 13.0)
                p.draw_text(
                  name,
                  x + 12.0 + 20.0,
                  row_y,
                  w - 32.0,
                  row_height,
                  valign=Center,
                  color=theme_text_regular(),
                )
              }
              CellLines(lines) => {
                // 行高内最多画两行,超出截断(虚拟滚动行高固定)
                let mut ly = row_y + (row_height - 28.0) / 2.0
                let limit = row_y + row_height - 2.0
                for ln in lines {
                  if ly > limit - 12.0 {
                    break
                  }
                  p.draw_text(
                    ln,
                    x + 12.0,
                    ly,
                    w,
                    14.0,
                    color=theme_text_regular(),
                  )
                  ly = ly + 14.0
                }
              }
            }
          }
        }
        p.restore()
        // 滚动条(细 thumb,可拖拽)
        let th = total_h()
        if th > vis_h {
          let thumb_h = (vis_h * vis_h / th).max(30.0)
          let t = if max_offset() > 0.0 {
            offset.val / max_offset()
          } else {
            0.0
          }
          let thumb_y = head_h + (vis_h - thumb_h) * t
          p.set_fill_color(theme_border())
          p.fill_rect(b.width - bar_w + 2.0, thumb_y, bar_w - 4.0, thumb_h)
        }
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
      })

      fn thumb_geo() -> (Double, Double) {
        let th = total_h()
        let thumb_h = (vis_h * vis_h / th).max(30.0)
        (thumb_h, th)
      }

      fn scroll_to_thumb(evy : Double) -> Unit {
        let (thumb_h, _) = thumb_geo()
        let t = ((evy - head_h - thumb_h / 2.0) / (vis_h - thumb_h))
          .max(0.0)
          .min(1.0)
        offset.val = t * max_offset()
        cv.schedule_paint()
      }

      View::set_cursor(cv, hand())
      cv.on_mouse_down(fn(e) {
        if e.button != 1 {
          return false
        }
        let n = data_r.val.length()
        if e.view_x >= body_w && max_offset() > 0.0 {
          scroll_to_thumb(e.view_y)
          dragging.val = true
          cv.set_capture()
          return true
        }
        if e.view_y < head_h {
          if e.view_x < 36.0 {
            match sel {
              Some(_) => toggle_all()
              None => ()
            }
          }
          cv.schedule_paint()
          return true
        }
        let idx = ((e.view_y - head_h + offset.val) / row_height).to_int()
        if idx >= 0 && idx < n {
          match sel {
            Some(_) => toggle_sel(idx)
            None => selected_i.val = idx
          }
          on_row_click(idx, data_r.val[idx])
        }
        cv.schedule_paint()
        true
      })
      cv.on_mouse_move(fn(e) {
        if dragging.val {
          scroll_to_thumb(e.view_y)
          return
        }
        let n = data_r.val.length()
        let idx = ((e.view_y - head_h + offset.val) / row_height).to_int()
        let inside = e.view_x < body_w && e.view_y >= head_h
        let new_hover = if inside && idx >= 0 && idx < n {
          idx
        } else {
          -1
        }
        if new_hover != hover_i.val {
          hover_i.val = new_hover
          cv.schedule_paint()
        }
      })
      cv.on_mouse_up(fn(_e) {
        if dragging.val {
          dragging.val = false
          cv.release_capture()
          true
        } else {
          false
        }
      })
      cv.on_mouse_leave(fn(_e) {
        if hover_i.val != -1 {
          hover_i.val = -1
          cv.schedule_paint()
        }
      })
      cv.on_wheel(fn(delta) {
        offset.val = offset.val + delta * 60.0
        clamp_offset()
        cv.schedule_paint()
      })
      cv.set_focusable(true)
      cv.on_key_down(fn(e) {
        let page = (vis_h - row_height).max(row_height)
        if e.code == VKEY_DOWN {
          offset.val = offset.val + row_height
        } else if e.code == VKEY_UP {
          offset.val = offset.val - row_height
        } else if e.code == VKEY_NEXT {
          offset.val = offset.val + page
        } else if e.code == VKEY_PRIOR {
          offset.val = offset.val - page
        } else if e.code == VKEY_END {
          offset.val = max_offset()
        } else if e.code == VKEY_HOME {
          offset.val = 0.0
        } else {
          return false
        }
        clamp_offset()
        cv.schedule_paint()
        true
      })

      fn load(data : Array[TableRow]) -> Unit {
        data_r.val = data
        selected_i.val = -1
        hover_i.val = -1
        offset.val = 0.0
        match sel {
          Some(s) => s.set([])
          None => ()
        }
        cv.schedule_paint()
      }

      load(rows.get())
      rows.subscribe(load)
      match sel {
        Some(s) => s.subscribe(fn(_v) { cv.schedule_paint() })
        None => ()
      }
      attach(parent, cv.view())
      cv.view()
    },
  }
}

///|
/// 分隔线(EP Divider):水平(默认,height 1px,宽 flex)或竖直(宽 1px,
/// 高随父容器);spacing 为两侧留白。底色挂载时读主题(重建界面生效)。
pub fn divider(vertical? : Bool = false, spacing? : Double = 10.0) -> Node {
  {
    mount: fn(parent) {
      let style : Array[(String, Double)] = if vertical {
        [("width", 1.0), ("marginLeft", spacing), ("marginRight", spacing)]
      } else {
        [("height", 1.0), ("marginTop", spacing), ("marginBottom", spacing)]
      }
      if !vertical {
        style.push(("flex", 1.0))
      }
      let c = themed_container(style=style)
      bind_bg(c, fn() { theme_border() })
      attach(parent, c.view())
      c.view()
    },
  }
}

///|
/// 多行输入(EP Input textarea 形态,input_t 同套路):外层自绘 1px 边框
/// (聚焦变主题色)+ 内边距,内部 TextEdit 去 native 边框只负责文字,
/// 内容超出按平台自身滚动(GTK TextView/RichEdit 滚轮)。文本变化经
/// on_input 回调。clearable=true 时字段悬停且非空,右侧显示 ✕,
/// 点击清空文本(on_input 收到空串)。
pub fn textarea_t(
  text? : String = "",
  width? : Double = 280.0,
  height? : Double = 110.0,
  margin? : Double = 0.0,
  on_input? : (String) -> Unit = fn(_s) {  },
  clearable? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      let hover = Ref(false)
      let has_text = Ref(text != "")
      let outer = themed_container(
        style=[
          ("width", width),
          ("height", height),
          ("padding", 10.0),
          ("marginTop", margin),
          ("marginBottom", margin),
        ],
      )
      set_panel_bg(outer)
      // 清空带在 padding 区右侧(TextEdit 恒定让出,防 ✕ 被原生子窗口盖住)
      let clear_x = width - 20.0
      outer.on_draw(fn(p) {
        let b = outer.get_bounds()
        p.set_stroke_color(
          if focused.val { theme_focus_accent() } else { theme_border() },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        if clearable && hover.val && has_text.val {
          draw_clear_x(p, clear_x, b.height / 2.0)
        }
      })
      let edit = TextEdit::new()
      edit.set_text(text)
      edit.set_font(Font::new("Sans", 13.0))
      edit.set_borderless(true)
      set_panel_bg(edit)
      edit.set_style("flex", 1.0)
      if clearable {
        edit.set_style("marginRight", 24.0)
      }
      edit.on_text_change(fn() {
        if clearable {
          has_text.val = edit.get_text() != ""
          outer.schedule_paint()
        }
        on_input(edit.get_text())
      })
      edit.on_focus_in(fn() {
        focused.val = true
        outer.schedule_paint()
        false
      })
      edit.on_focus_out(fn() {
        focused.val = false
        outer.schedule_paint()
        false
      })
      if clearable {
        outer.on_mouse_enter(fn(_e) {
          hover.val = true
          outer.schedule_paint()
        })
        outer.on_mouse_leave(fn(_e) {
          hover.val = false
          outer.schedule_paint()
        })
        outer.on_mouse_up(fn(e) {
          let b = outer.get_bounds()
          if e.button == 1 && has_text.val && e.view_x >= b.width - 32.0 {
            edit.set_text("")
            true
          } else {
            false
          }
        })
      }
      outer.add_child(edit)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 滑杆(EP Slider,自绘):浅灰轨道 + 主题色填充段 + 方形 thumb,支持
/// 点击轨道/拖拽 thumb 调值,值按 step 量化后写入 value(Store[Double]),
/// 外部 set 同样生效。on_change 在值变化时回调(含拖拽过程)。
pub fn slider_t(
  value : Store[Double],
  min? : Double = 0.0,
  max? : Double = 100.0,
  step? : Double = 1.0,
  width? : Double = 240.0,
  on_change? : (Double) -> Unit = fn(_v) {  },
) -> Node {
  {
    mount: fn(parent) {
      let h = 24.0
      let track_h = 4.0
      let thumb = 12.0
      let dragging = Ref(false)
      let hover = Ref(false)
      let v = themed_container(
        style=[("width", width), ("height", h), ("marginBottom", 10.0)],
      )
      fn clamp01(x : Double) -> Double {
        if x < 0.0 {
          0.0
        } else if x > 1.0 {
          1.0
        } else {
          x
        }
      }

      fn ratio_of(val : Double) -> Double {
        if max <= min {
          return 0.0
        }
        clamp01((val - min) / (max - min))
      }

      // 值按 step 量化(对齐到网格,再回钳范围)
      fn quantize(val : Double) -> Double {
        if step <= 0.0 {
          return val
        }
        let k = ((val - min) / step).round()
        let q = min + k * step
        if q < min {
          min
        } else if q > max {
          max
        } else {
          q
        }
      }

      fn set_from_x(x : Double) -> Unit {
        let r = clamp01((x - thumb / 2.0) / (width - thumb))
        value.set(quantize(min + r * (max - min)))
      }

      v.on_draw(fn(p) {
        let ratio = ratio_of(value.get())
        let ty = (h - track_h) / 2.0
        p.set_fill_color(theme_fill_zebra())
        p.fill_rect(0.0, ty, width, track_h)
        p.set_fill_color(theme_primary())
        p.fill_rect(0.0, ty, ratio * (width - thumb) + thumb / 2.0, track_h)
        // thumb:主题色实心方块,hover/拖拽加深
        let tx = ratio * (width - thumb)
        p.set_fill_color(
          if hover.val || dragging.val {
            theme_primary_hover()
          } else {
            theme_primary()
          },
        )
        p.fill_rect(tx, (h - thumb) / 2.0, thumb, thumb)
      })
      View::set_cursor(v, hand())
      v.on_mouse_down(fn(e) {
        if e.button == 1 {
          dragging.val = true
          v.set_capture()
          set_from_x(e.view_x)
          true
        } else {
          false
        }
      })
      v.on_mouse_move(fn(e) {
        if dragging.val {
          set_from_x(e.view_x)
        }
      })
      v.on_mouse_up(fn(_e) {
        if dragging.val {
          dragging.val = false
          v.release_capture()
          true
        } else {
          false
        }
      })
      v.on_mouse_enter(fn(_e) {
        hover.val = true
        v.schedule_paint()
      })
      v.on_mouse_leave(fn(_e) {
        hover.val = false
        v.schedule_paint()
      })
      v.on_focus_out(fn() {
        if dragging.val {
          dragging.val = false
          v.release_capture()
        }
        false
      })
      value.subscribe(fn(new_v) {
        on_change(new_v)
        v.schedule_paint()
      })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 页签(EP Tabs,顶部形态):页签头行(选中主题色文字 + 底部 2px 指示条,
/// 悬停变深)+ 内容区经 set_visible 切换。selected 为页序号 Store,默认
/// 内部建 0。
pub fn tabs_t(
  pages : Array[(String, Node)],
  selected? : Store[Int],
) -> Node {
  {
    mount: fn(parent) {
      let sel = match selected {
        Some(s) => s
        None => Store::new(0)
      }
      let fnt = Font::new("Sans", 13.0)
      let outer = themed_container(
        style=[("width", 360.0), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "column")],
      )
      let head = themed_container(
        style=[("height", 36.0)],
        style_str=[("flexDirection", "row")],
      )
      let contents : Array[Container] = []
      let cur = Ref(sel.get())
      for i in 0..<pages.length() {
        let (title, node) = pages[i]
        let idx = i
        // 页签头:宽度自适应(测字宽 + 两侧 14px)
        let probe = AttributedText::new(title, wrap=false)
        probe.set_font(fnt)
        let tw = probe.get_bounds_for(10000.0, 100.0).width
        let tab = themed_container(
          style=[("width", tw + 28.0), ("height", 36.0), ("marginRight", 8.0)],
        )
        let hover = Ref(false)
        tab.on_draw(fn(p) {
          let b = tab.get_bounds()
          let act = cur.val == idx
          let at = AttributedText::new(title, valign=Center, wrap=false)
          at.set_font(fnt)
          at.set_color(
            if act {
              theme_primary()
            } else if hover.val {
              theme_text_regular()
            } else {
              theme_text_secondary()
            },
          )
          p.draw_attributed_text(at, 14.0, 0.0, b.width - 14.0, 36.0)
          if act {
            p.set_fill_color(theme_primary())
            p.fill_rect(0.0, 34.0, b.width, 2.0)
          }
        })
        View::set_cursor(tab, hand())
        tab.on_mouse_down(fn(e) {
          if e.button == 1 {
            sel.set(idx)
            true
          } else {
            false
          }
        })
        tab.on_mouse_enter(fn(_e) {
          hover.val = true
          tab.schedule_paint()
        })
        tab.on_mouse_leave(fn(_e) {
          hover.val = false
          tab.schedule_paint()
        })
        head.add_child(tab)
        // 内容页:默认只显示当前页
        let page_c = themed_container(
          style_str=[("flexDirection", "column")],
        )
        page_c.set_visible(cur.val == idx)
        ignore((node.mount)(page_c.view()))
        contents.push(page_c)
      }
      outer.add_child(head)
      for c in contents {
        outer.add_child(c)
      }
      sel.subscribe(fn(i) {
        cur.val = i
        for j in 0..<contents.length() {
          contents[j].set_visible(j == i)
        }
        head.schedule_paint()
      })
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 下拉候选行(EP 样式,select_t 各平台共用):当前选中浅蓝底 + 主题色字 +
/// 右侧 ✓,hover/键盘高亮灰底。mark 为键盘高亮标记(非鼠标路径)。
fn select_row(
  opt : String,
  value : Store[String],
  on_pick : () -> Unit,
) -> Container {
  let row = themed_container(
    style=[("height", 28.0), ("paddingLeft", 8.0)],
    style_str=[("flexDirection", "row"), ("alignItems", "center")],
  )
  let hover = Ref(false)
  row.on_draw(fn(p) {
    let b = row.get_bounds()
    let act = value.get() == opt
    if act {
      p.set_fill_color(theme_primary_light())
      p.fill_rect(0.0, 0.0, b.width, b.height)
    } else if hover.val {
      p.set_fill_color(theme_fill_hover())
      p.fill_rect(0.0, 0.0, b.width, b.height)
    }
    p.draw_text(
      opt,
      8.0,
      0.0,
      b.width - 26.0,
      b.height,
      valign=Center,
      color=if act {
        theme_primary()
      } else {
        theme_text_regular()
      },
    )
    if act {
      // 选中项右侧 ✓(矢量小勾,不依赖字体)
      p.set_stroke_color(theme_primary())
      p.begin_path()
      p.move_to(b.width - 18.0, b.height / 2.0)
      p.line_to(b.width - 14.0, b.height / 2.0 + 4.0)
      p.line_to(b.width - 8.0, b.height / 2.0 - 4.0)
      p.stroke()
    }
  })
  row.on_mouse_enter(fn(_e) {
    hover.val = true
    row.schedule_paint()
  })
  row.on_mouse_leave(fn(_e) {
    hover.val = false
    row.schedule_paint()
  })
  View::set_cursor(row, hand())
  row.on_mouse_down(fn(e) {
    if e.button == 1 {
      on_pick()
      true
    } else {
      false
    }
  })
  row
}

///|
/// 下拉选择(EP Select,全自绘):点击弹候选列表(Popover 承载):悬停
/// 高亮、当前选中主题色 ✓,点选回填并收起,失焦收起;选中经
/// value(Store[String])同步。三平台同形态。clearable=true 时字段悬停
/// 且有值,箭头左侧显示 ✕,点击清空选择(value 置空串、on_change("")。
/// 选项本身为空串时 ✕ 判定与「无值」同义)。
/// (曾有 Linux 可过滤形态——字段可输入实时筛选 + ↑↓/回车键盘导航,
/// 真机两轮验证均折在 X11 弹层焦点语义上,已移除,见 adaptation.md。)
pub fn select_t(
  options : Array[String],
  value : Store[String],
  width? : Double = 200.0,
  on_change? : (String) -> Unit = fn(_s) {  },
  clearable? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      let hover = Ref(false)
      let field = themed_container(
        style=[("width", width), ("height", 30.0), ("marginBottom", 10.0)],
      )
      set_panel_bg(field)
      View::set_cursor(field, hand())
      fn apply(text : String) -> Unit {
        ignore(text)
        field.schedule_paint()
      }

      field.on_draw(fn(p) {
        let b = field.get_bounds()
        p.set_stroke_color(
          if focused.val { theme_focus_accent() } else { theme_border() },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        p.draw_text(
          value.get(),
          10.0,
          0.0,
          b.width - 30.0,
          b.height,
          valign=Center,
          color=theme_text_primary(),
        )
        p.set_fill_color(theme_text_secondary())
        p.begin_path()
        p.move_to(b.width - 20.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 12.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 16.0, b.height / 2.0 + 3.0)
        p.close_path()
        p.fill()
        if clearable && hover.val && value.get() != "" {
          draw_clear_x(p, b.width - 30.0, b.height / 2.0)
        }
      })
      let pop : Ref[Popover?] = Ref(None)
      fn pick(opt : String) -> Unit {
        value.set(opt)
        on_change(opt)
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
      }

      field.set_focusable(true)
      field.on_focus_in(fn() {
        focused.val = true
        field.schedule_paint()
        false
      })
      field.on_focus_out(fn() {
        focused.val = false
        field.schedule_paint()
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      field.on_mouse_enter(fn(_e) {
        hover.val = true
        field.schedule_paint()
      })
      field.on_mouse_leave(fn(_e) {
        hover.val = false
        field.schedule_paint()
      })
      field.on_mouse_up(fn(e) {
        if e.button == 1 {
          field.focus()
          // 清空带(箭头左侧)优先:清空选择,不弹列表
          let b = field.get_bounds()
          if clearable && value.get() != "" && e.view_x >= b.width - 40.0 && e.view_x <= b.width - 20.0 {
            value.set("")
            on_change("")
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              // 高度 = 项数 x 28 + padding 8,上限 300;根容器宽高必须
              // 创建期给定(事后 set_style 会被弹层分配时序吞掉),
              // 公式与 content_size 一致
              let mut rows_h = options.length().to_double() * 28.0 + 8.0
              if rows_h > 300.0 {
                rows_h = 300.0
              }
              let list = themed_container(
                style=[
                  ("width", width),
                  ("height", rows_h),
                  ("padding", 4.0),
                ],
                style_str=[("flexDirection", "column")],
              )
              set_panel_bg(list)
              for opt in options {
                let o = opt
                list.add_child(select_row(o, value, fn() { pick(o) }))
              }
              p.set_content(list)
              p.set_content_size(width, rows_h)
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      value.subscribe(fn(v) { apply(v) })
      attach(parent, field.view())
      field.view()
    },
  }
}

///|
/// 五角星路径(矢量自绘,不依赖字体字形):cx/cy 星心,R 外半径,
/// 内半径取 0.382R(正五角星比例)。
fn star_path(p : Painter, cx : Double, cy : Double, r_out : Double) -> Unit {
  let r_in = r_out * 0.382
  p.begin_path()
  for k in 0..<10 {
    let rad = if k % 2 == 0 { r_out } else { r_in }
    // 起点朝上(-90°),每步 36°
    let ang = (-90.0 + k.to_double() * 36.0) * 3.141592653589793 / 180.0
    let x = cx + rad * @math.cos(ang)
    let y = cy + rad * @math.sin(ang)
    if k == 0 {
      p.move_to(x, y)
    } else {
      p.line_to(x, y)
    }
  }
  p.close_path()
}

///|
/// 评分(EP Rate,自绘):五角星序列,选中实心主题色、未选中描边灰,
/// 悬停预亮(实心),点击写入 value(Store[Int],0..max)。
pub fn rate_t(
  value : Store[Int],
  max? : Int = 5,
  on_change? : (Int) -> Unit = fn(_v) {  },
) -> Node {
  {
    mount: fn(parent) {
      let size = 22.0
      let gap = 4.0
      let hover = Ref(0) // 0 = 无预览,否则预亮到第 N 颗
      let v = themed_container(
        style=[
          ("width", size * max.to_double() + gap * (max - 1).to_double()),
          ("height", size),
          ("marginBottom", 10.0),
        ],
      )
      fn star_at(x : Double) -> Int {
        let idx = ((x + gap / 2.0) / (size + gap)).to_int() + 1
        if idx < 1 {
          1
        } else if idx > max {
          max
        } else {
          idx
        }
      }

      v.on_draw(fn(p) {
        for i in 1..=max {
          let cx = (i - 1).to_double() * (size + gap) + size / 2.0
          let cy = size / 2.0
          let lit = if hover.val > 0 { i <= hover.val } else { i <= value.get() }
          if lit {
            p.set_fill_color(theme_primary())
            star_path(p, cx, cy, size / 2.0 - 1.0)
            p.fill()
          } else {
            p.set_stroke_color(theme_border())
            star_path(p, cx, cy, size / 2.0 - 1.0)
            p.stroke()
          }
        }
      })
      v.on_mouse_move(fn(e) {
        let h = star_at(e.view_x)
        if h != hover.val {
          hover.val = h
          v.schedule_paint()
        }
      })
      v.on_mouse_leave(fn(_e) {
        if hover.val != 0 {
          hover.val = 0
          v.schedule_paint()
        }
      })
      View::set_cursor(v, hand())
      v.on_mouse_down(fn(e) {
        if e.button == 1 {
          value.set(star_at(e.view_x))
          true
        } else {
          false
        }
      })
      value.subscribe(fn(new_v) {
        on_change(new_v)
        v.schedule_paint()
      })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 悬浮提示:给任意节点包原生 tooltip(系统样式,零成本;主题化气泡
/// 请用 popover_t)。
pub fn tooltip_t(content : Node, tip : String) -> Node {
  {
    mount: fn(parent) {
      let v = (content.mount)(parent)
      ffi_view_set_tooltip(v, utf8_bytes(tip))
      v
    },
  }
}

///|
/// 气泡弹层(EP Popover):trigger 点击后在自身下方弹出任意内容
/// (Node,Popover 承载,内容先挂进临时容器),再次点击切换收起。
pub fn popover_t(
  trigger : Node,
  content : Node,
  width : Double,
  height : Double,
) -> Node {
  {
    mount: fn(parent) {
      let tv = (trigger.mount)(parent)
      let pop : Ref[Popover?] = Ref(None)
      let open = Ref(false)
      let wrapped : (Int, Double, Double, Double, Double, Int, Int) -> Int = fn(
        button,
        _vx,
        _vy,
        _wx,
        _wy,
        _m,
        _t,
      ) {
        if button != 1 {
          return 0
        }
        match pop.val {
          None => {
            let p = Popover::new()
            let holder = themed_container(
              style=[("width", width), ("height", height)],
            )
            ignore((content.mount)(holder.view()))
            p.set_content(holder)
            p.set_content_size(width, height)
            // 点外关闭(Linux 系统行为)/显式关闭都同步状态,
            // 否则下次点击误走 close 分支,弹层再也打不开
            p.on_close(fn() { open.val = false })
            pop.val = Some(p)
            ffi_popover_show_relative_to(p, tv)
            open.val = true
          }
          Some(p) =>
            if open.val {
              p.close()
            } else {
              ffi_popover_show_relative_to(p, tv)
              open.val = true
            }
        }
        1
      }
      ffi_view_set_cursor(tv, hand())
      keep_alive(fn() { ignore(wrapped) })
      ffi_view_on_mouse_up(
        tv,
        fn(f, b, vx, vy, wx, wy, m, t) { f(b, vx, vy, wx, wy, m, t) },
        wrapped,
      )
      tv
    },
  }
}

///|
/// 下拉菜单(EP Dropdown):触发文字 + 下拉箭头,点击弹菜单项列表
/// (Popover 承载):悬停高亮,点击回调序号并收起;"-" 项画分隔线。
pub fn dropdown_menu(
  trigger : String,
  items : Array[String],
  on_select : (Int) -> Unit,
  width? : Double = 160.0,
) -> Node {
  {
    mount: fn(parent) {
      let fnt = Font::new("Sans", 13.0)
      let focused = Ref(false)
      let field = themed_container(
        style=[("width", width), ("height", 30.0), ("marginBottom", 10.0)],
      )
      set_panel_bg(field)
      View::set_cursor(field, hand())
      field.on_draw(fn(p) {
        let b = field.get_bounds()
        if focused.val {
          p.set_fill_color(theme_fill_hover())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        p.set_stroke_color(
          if focused.val { theme_focus_accent() } else { theme_border() },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        p.draw_text(
          trigger,
          10.0,
          0.0,
          b.width - 30.0,
          b.height,
          valign=Center,
          color=theme_text_primary(),
        )
        p.set_fill_color(theme_text_secondary())
        p.begin_path()
        p.move_to(b.width - 20.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 12.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 16.0, b.height / 2.0 + 3.0)
        p.close_path()
        p.fill()
      })
      let pop : Ref[Popover?] = Ref(None)
      field.set_focusable(true)
      field.on_focus_in(fn() {
        focused.val = true
        field.schedule_paint()
        false
      })
      field.on_focus_out(fn() {
        focused.val = false
        field.schedule_paint()
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      field.on_mouse_up(fn(e) {
        if e.button == 1 {
          field.focus()
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              // 根容器宽高创建期给定(事后 set_style 会被弹层时序吞掉),
              // 高度 = 项数 x 28 + padding 8,与 content_size 一致
              let list = themed_container(
                style=[
                  ("width", width),
                  ("height", items.length().to_double() * 28.0 + 8.0),
                  ("padding", 4.0),
                ],
                style_str=[("flexDirection", "column")],
              )
              set_panel_bg(list)
              for i in 0..<items.length() {
                let it = items[i]
                let idx = i
                if it == "-" {
                  let sep = themed_container(style=[("height", 9.0)])
                  sep.on_draw(fn(p2) {
                    let b = sep.get_bounds()
                    p2.set_stroke_color(theme_border())
                    p2.begin_path()
                    p2.move_to(8.0, 4.5)
                    p2.line_to(b.width - 8.0, 4.5)
                    p2.stroke()
                  })
                  list.add_child(sep)
                  continue
                }
                let hover = Ref(false)
                let row = themed_container(
                  style=[("height", 28.0), ("paddingLeft", 8.0)],
                  style_str=[("flexDirection", "row"), ("alignItems", "center")],
                )
                row.on_draw(fn(p2) {
                  let b = row.get_bounds()
                  if hover.val {
                    p2.set_fill_color(theme_fill_hover())
                    p2.fill_rect(0.0, 0.0, b.width, b.height)
                  }
                  let at = AttributedText::new(it, valign=Center, wrap=false)
                  at.set_font(fnt)
                  at.set_color(theme_text_regular())
                  p2.draw_attributed_text(at, 8.0, 0.0, b.width - 16.0, 28.0)
                })
                row.on_mouse_enter(fn(_e) {
                  hover.val = true
                  row.schedule_paint()
                })
                row.on_mouse_leave(fn(_e) {
                  hover.val = false
                  row.schedule_paint()
                })
                View::set_cursor(row, hand())
                row.on_mouse_down(fn(e2) {
                  if e2.button == 1 {
                    on_select(idx)
                    match pop.val {
                      Some(p3) => p3.close()
                      None => ()
                    }
                    true
                  } else {
                    false
                  }
                })
                list.add_child(row)
              }
              p.set_content(list)
              p.set_content_size(
                width,
                items.length().to_double() * 28.0 + 8.0,
              )
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      attach(parent, field.view())
      field.view()
    },
  }
}

///|
/// 轮播(EP Carousel):面板序列 + 左右箭头 + 底部指示点,自动轮播
/// (interval_ms > 0 时,interval 毫秒一切,悬停暂停),点击箭头/指示点
/// 手动切换。面板为任意 Node,统一按给定宽高展示。
pub fn carousel_t(
  pages : Array[Node],
  width? : Double = 360.0,
  height? : Double = 180.0,
  interval_ms? : Int = 3000,
) -> Node {
  {
    mount: fn(parent) {
      let n = pages.length()
      let cur = Ref(0)
      let paused = Ref(false)
      let dots : Array[Container] = []
      let panels : Array[Container] = []
      let outer = themed_container(
        style=[("width", width), ("height", height + 24.0), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "column")],
      )
      let stage = themed_container(
        style=[("width", width), ("height", height)],
        style_str=[("flexDirection", "column")],
      )
      // 切页:越界回绕
      fn do_switch(i : Int) -> Unit {
        let idx = if i < 0 {
          n - 1
        } else if i >= n {
          0
        } else {
          i
        }
        let prev = cur.val
        cur.val = idx
        if prev != idx {
          panels[prev].set_visible(false)
          dots[prev].schedule_paint()
          panels[idx].set_visible(true)
          dots[idx].schedule_paint()
        }
      }

      // 面板与指示点先建好,切换只动 set_visible
      for i in 0..<n {
        // 面板填满舞台(flex 拉高 + stretch 拉宽):固定宽会横向溢出
        // 舞台(两侧箭头各占 24px),盖住右侧切换箭头的事件窗口
        let pc = themed_container(
          style=[("flex", 1.0)],
          style_str=[("flexDirection", "column"), ("alignSelf", "stretch")],
        )
        pc.set_visible(i == 0)
        ignore((pages[i].mount)(pc.view()))
        stage.add_child(pc)
        panels.push(pc)
        let dot = themed_container(
          style=[
            ("width", 8.0),
            ("height", 8.0),
            ("marginLeft", 4.0),
            ("marginRight", 4.0),
            ("marginTop", 8.0),
          ],
        )
        let di = i
        dot.on_draw(fn(p) {
          p.set_fill_color(
            if cur.val == di { theme_primary() } else { theme_border() },
          )
          p.fill_rect(0.0, 0.0, 8.0, 8.0)
        })
        View::set_cursor(dot, hand())
        dot.on_mouse_down(fn(e) {
          if e.button == 1 {
            do_switch(di)
            true
          } else {
            false
          }
        })
        dots.push(dot)
      }
      // 左右箭头(矢量三角,悬浮在舞台两侧的窄热区)
      fn arrow(right : Bool) -> Container {
        let a = themed_container(style=[("width", 24.0), ("height", height)])
        let hover = Ref(false)
        a.on_draw(fn(p) {
          if hover.val {
            let b = a.get_bounds()
            p.set_fill_color(theme_fill_hover())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
          let cx = 12.0
          let cy = height / 2.0
          p.set_fill_color(theme_text_regular())
          p.begin_path()
          if right {
            p.move_to(cx - 4.0, cy - 5.0)
            p.line_to(cx + 4.0, cy)
            p.line_to(cx - 4.0, cy + 5.0)
          } else {
            p.move_to(cx + 4.0, cy - 5.0)
            p.line_to(cx - 4.0, cy)
            p.line_to(cx + 4.0, cy + 5.0)
          }
          p.close_path()
          p.fill()
        })
        a.on_mouse_enter(fn(_e) {
          hover.val = true
          a.schedule_paint()
        })
        a.on_mouse_leave(fn(_e) {
          hover.val = false
          a.schedule_paint()
        })
        View::set_cursor(a, hand())
        a.on_mouse_down(fn(e) {
          if e.button == 1 {
            do_switch(if right { cur.val + 1 } else { cur.val - 1 })
            true
          } else {
            false
          }
        })
        a
      }

      // 布局:舞台行 = 左箭头 + 舞台 + 右箭头;下行为指示点
      let stage_row = themed_container(style_str=[("flexDirection", "row")])
      stage_row.add_child(arrow(false))
      stage.set_style("flex", 1.0)
      stage_row.add_child(stage)
      stage_row.add_child(arrow(true))
      let dots_row = themed_container(style_str=[("flexDirection", "row")])
      for d in dots {
        dots_row.add_child(d)
      }
      outer.add_child(stage_row)
      outer.add_child(dots_row)
      // 悬停暂停自动轮播;set_timeout 一次性,回调里自排下一个
      outer.on_mouse_enter(fn(_e) { paused.val = true })
      outer.on_mouse_leave(fn(_e) { paused.val = false })
      if interval_ms > 0 && n > 1 {
        let tick : Ref[() -> Unit] = Ref(fn() {  })
        tick.val = fn() {
          ignore(set_timeout(interval_ms, fn() {
            if !paused.val {
              do_switch(cur.val + 1)
            }
            (tick.val)()
          }))
        }
        (tick.val)()
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}


///|
/// 取色器(EP ColorPicker,下拉形态):触发字段(当前色块 + hex + 箭头)
/// 点击弹出预设色板(Popover 承载):点击色块写入 value("#RRGGBB")并
/// 收起;选中色块主题色描边 + 白勾。失焦收起。
pub fn color_picker_t(
  value : Store[String],
  colors? : Array[String] = [
    "#2D68C4", "#2E9E5B", "#D9822B", "#D64550", "#6B7480",
    "#1E4FA3", "#3F6E9E", "#7A9E4E", "#B86E2B", "#9AA0A6",
    "#E8EAED", "#BDC1C6", "#4E5560", "#2A2F36", "#F5F7FA",
  ],
  width? : Double = 200.0,
) -> Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      let field = themed_container(
        style=[("width", width), ("height", 30.0), ("marginBottom", 10.0)],
      )
      set_panel_bg(field)
      View::set_cursor(field, hand())
      field.on_draw(fn(p) {
        let b = field.get_bounds()
        p.set_stroke_color(
          if focused.val { theme_focus_accent() } else { theme_border() },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        // 当前色块
        p.set_fill_color(value.get())
        p.fill_rect(10.0, 8.0, 14.0, 14.0)
        p.set_stroke_color(theme_border())
        p.stroke_rect(10.5, 8.5, 13.0, 13.0)
        p.draw_text(
          value.get(),
          32.0,
          0.0,
          b.width - 52.0,
          b.height,
          valign=Center,
          color=theme_text_primary(),
        )
        p.set_fill_color(theme_text_secondary())
        p.begin_path()
        p.move_to(b.width - 20.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 12.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 16.0, b.height / 2.0 + 3.0)
        p.close_path()
        p.fill()
      })
      let pop : Ref[Popover?] = Ref(None)
      fn pick(c : String) -> Unit {
        value.set(c)
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
      }

      field.set_focusable(true)
      field.on_focus_in(fn() {
        focused.val = true
        field.schedule_paint()
        false
      })
      field.on_focus_out(fn() {
        focused.val = false
        field.schedule_paint()
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      field.on_mouse_up(fn(e) {
        if e.button == 1 {
          field.focus()
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              // 色板网格:5 列布局,选中描边 + 白勾
              let swatch = 26.0
              let gap = 6.0
              let per_row = 5
              // 弹层根容器宽高必须创建期给定(公式与 content_size 一致):
              // 事后 set_style 会被弹层分配时序吞掉——实测色板整体不绘制
              // 但事件窗口仍在(能点击看不到)
              let rows_n0 = (colors.length() + per_row - 1) / per_row
              let grid_w0 = per_row.to_double() * (swatch + gap) + 16.0
              let grid_h0 = 16.0 + rows_n0.to_double() * (swatch + gap)
              let grid = themed_container(
                style=[
                  ("width", grid_w0),
                  ("height", grid_h0),
                  ("padding", 8.0),
                ],
                style_str=[("flexDirection", "column")],
              )
              set_panel_bg(grid)
              let rows : Array[(Container, Array[Container])] = []
              for i in 0..<colors.length() {
                if i % per_row == 0 {
                  rows.push((
                    themed_container(
                      style=[("height", swatch + gap)],
                      style_str=[("flexDirection", "row")],
                    ),
                    [],
                  ))
                }
                let (row, cells) = rows[rows.length() - 1]
                let c = colors[i]
                let cell = themed_container(
                  style=[
                    ("width", swatch),
                    ("height", swatch),
                    ("marginRight", gap),
                  ],
                )
                View::set_cursor(cell, hand())
                cell.on_draw(fn(p2) {
                  p2.set_fill_color(c)
                  p2.fill_rect(0.0, 0.0, swatch, swatch)
                  p2.set_stroke_color(theme_border())
                  p2.stroke_rect(0.5, 0.5, swatch - 1.0, swatch - 1.0)
                  if value.get() == c {
                    p2.set_stroke_color(theme_primary())
                    p2.stroke_rect(1.5, 1.5, swatch - 3.0, swatch - 3.0)
                    p2.set_stroke_color("#FFFFFF")
                    p2.begin_path()
                    p2.move_to(swatch / 2.0 - 5.0, swatch / 2.0)
                    p2.line_to(swatch / 2.0 - 1.0, swatch / 2.0 + 4.0)
                    p2.line_to(swatch / 2.0 + 6.0, swatch / 2.0 - 5.0)
                    p2.stroke()
                  }
                })
                cell.on_mouse_down(fn(e2) {
                  if e2.button == 1 {
                    pick(c)
                    true
                  } else {
                    false
                  }
                })
                row.add_child(cell)
                cells.push(cell)
              }
              for (row, _cells) in rows {
                grid.add_child(row)
              }
              value.subscribe(fn(_v) {
                for (_r, cells) in rows {
                  for cell in cells {
                    cell.schedule_paint()
                  }
                }
                field.schedule_paint()
              })
              // 高度 = padding 16 + 行数 x 32(色块 26 + 间距 6);
              // content_size 与创建期根容器尺寸公式一致
              p.set_content(grid)
              p.set_content_size(grid_w0, grid_h0)
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      attach(parent, field.view())
      field.view()
    },
  }
}

///|
/// 分组侧边菜单(side_menu 的分组形态):每组一段小标题(不可点,次要色
/// 小字)+ 组内菜单项(画法与 side_menu 一致,选中/悬停联动 selected)。
pub fn side_menu_sections(
  sections : Array[(String, Array[String])],
  selected : Store[String],
  width? : Double = 180.0,
) -> Node {
  let nodes : Array[Node] = []
  for (group, items) in sections {
    // 组标题:次要色小字,不可点,恒左对齐(label_t;普通 label 底层
    // 默认水平居中,满宽拉伸时文字会飘到中间);paddingLeft 与菜单项
    // 文字的 pad_x 一致(同一父容器的 padding 下两者左缘对齐)
    nodes.push(
      label_t(
        group,
        role=Secondary,
        style=[("paddingLeft", 20.0), ("paddingTop", 10.0), ("height", 24.0)],
      ),
    )
    for it in items {
      nodes.push(
        stateful_item(
          it,
          // 外层 vbox 有 padding 6,项宽 = 总宽 − 两侧 padding,防向右溢出
          [("width", width - 12.0), ("height", 36.0)],
          selected,
          side_menu_bg,
          side_menu_fg,
          pad_x=20.0,
          align_start=true,
        ),
      )
    }
  }
  vbox(nodes, style=[("width", width), ("padding", 6.0)], handle=fn(c) {
    set_panel_bg(c)
  })
}
