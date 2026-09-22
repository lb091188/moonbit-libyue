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
/// 表单控件统一高度(按钮/输入框/下拉/数字器/日期选择字段等):
/// 32px(EP 规格),混排成行时基线对齐。自定义控件与覆盖场景一律
/// 引用本常量,不写死字面量;多行文本域等非单行控件不受此约束。
pub let control_height : Double = 32.0

///|
/// 组件库自绘容器:Container::make + 主题切换时自动重绘
/// (draw 回调现取 theme_* 色,重绘即跟随新主题)。
fn themed_container(
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Container {
  let c = Container::make(style~, style_str~)
  on_theme_change(fn() { ViewLike::schedule_paint(c) })
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
/// 弹层底色跟随主题:Windows 替代弹层是独立裸窗口(默认白底,应用内
/// 全局接管 CSS 罩不到,深色主题下白底浅字不可读),显式设主题面板色
/// 并订阅切换重设;其余平台弹层在应用窗口体系内由 CSS 覆盖,空操作。
fn bind_popover_bg(p : Popover) -> Unit {
  fn apply() -> Unit {
    p.set_background_color(theme_bg_panel())
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
/// 用于挂载期 set_color 定死的文字;主题切换时按表达式重取。
/// set_color 后必须同文 set_text 一次:set_color 改的 Pango 前景属性
/// 不触发布局缓存失效,不同文重排则重绘仍用旧色(点击路径实测)。
fn bind_fg(v : Label, color_of : () -> String) -> Unit {
  fn apply() -> Unit {
    ViewLike::set_color(v, color_of())
    v.set_text(v.get_text())
  }

  apply()
  on_theme_change(apply)
}

///|
/// 自定义组件的文字颜色接入主题(公开版 bind_fg):挂载即设色,
/// theme_apply 切换深浅时自动重设并重排。自定义组件里给 Label
/// 设主题色一律用它,别裸 set_color(不跟主题)也别自己订阅
/// (漏同文重排会残留旧色)。
pub fn theme_bind_fg(l : Label, color_of : () -> String) -> Unit {
  bind_fg(l, color_of)
}

///|
/// 自定义组件的背景色接入主题(公开版 bind_bg):挂载即设色,
/// theme_apply 切换深浅时自动重设(set_background_color 定死的底色
/// 不会因重绘更新,必须重设)。
pub fn[T : ViewLike] theme_bind_bg(v : T, color_of : () -> String) -> Unit {
  bind_bg(v, color_of)
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
/// 由单个主色调公式派生整套主题色板(EP 主题工作台的思路):
///   - 主色:保持色相,仅按深浅模式钳制明度(浅 0.34..0.52 / 深
///     0.55..0.72)与最低饱和度,保证白字/浅底上的可读性;
///   - primary_hover = 主色明度 ∓8%(浅加深/深提亮);
///   - primary_light = 主色向面板底混色(浅色混白 88%,深色混面板
///     底),Soft 按钮/选中行底色即此;
///   - 语义色(success/warning/danger/info)取固定色相轮
///     (142/36/4/210),饱和度假借主色(≥0.4)、明度随深浅模式,
///     浅底变体同理推出;
///   - 中性色(文字/边框/悬停/斑马纹/背景)取内置深浅基准盘,
///     不随主色偏移,保持排版稳定。
/// accent 非法时回落内置基准主题。
pub fn theme_from_accent(accent : String, dark? : Bool = false) -> Theme {
  let base = if dark {
    dark_theme()
  } else {
    default_theme()
  }
  let (r, g, b) = match parse_hex(accent) {
    Some(rgb) => rgb
    None => return base
  }
  let (h, s0, l0) = rgb_to_hsl(r, g, b)
  // 主色:饱和度保底 0.45,明度按模式钳到可担纲强调色的区间
  let ps = if s0 < 0.45 { 0.45 } else { s0 }
  let pl = if dark {
    if l0 > 0.72 {
      0.72
    } else if l0 < 0.55 {
      0.55
    } else {
      l0
    }
  } else if l0 > 0.52 {
    0.52
  } else if l0 < 0.34 {
    0.34
  } else {
    l0
  }
  let primary = from_hsl(h, ps, pl)
  let primary_hover = if dark {
    from_hsl(h, ps, pl + 0.08)
  } else {
    from_hsl(h, ps, pl - 0.09)
  }
  // 浅底变体:浅色模式取 12% 主色混白(接近内置盘 #E8F0FB 的淡度),
  // 深色模式取 30% 主色混面板底(内置盘 #1E3A5F 的淡度)。注意 mix_hex
  // 的 t 是取「前者」的比例,别写反
  let primary_light = if dark {
    mix_hex(primary, base.bg_panel, 0.30)
  } else {
    mix_hex(primary, "#FFFFFF", 0.12)
  }
  // 语义色:固定色相轮,饱和度假借主色、明度随模式
  let ss = if ps * 0.8 < 0.4 { 0.4 } else { ps * 0.8 }
  let sl = if dark { 0.62 } else { 0.38 }
  let semantic = fn(hue : Double) -> String { from_hsl(hue, ss, sl) }
  let success = semantic(142.0)
  let warning = semantic(36.0)
  let danger = semantic(4.0)
  let info = semantic(210.0)
  let light_of = fn(c : String) -> String {
    if dark {
      mix_hex(c, base.bg_panel, 0.28)
    } else {
      mix_hex(c, "#FFFFFF", 0.14)
    }
  }

  {
    primary,
    primary_light,
    primary_hover,
    danger_hover: if dark { lighten_hex(danger, 0.08) } else { darken_hex(danger, 0.09) },
    success,
    success_light: light_of(success),
    warning,
    warning_light: light_of(warning),
    danger,
    danger_light: light_of(danger),
    info,
    info_light: light_of(info),
    text_primary: base.text_primary,
    text_regular: base.text_regular,
    text_secondary: base.text_secondary,
    border: base.border,
    fill_hover: base.fill_hover,
    fill_zebra: base.fill_zebra,
    bg_page: base.bg_page,
    bg_panel: base.bg_panel,
  }
}

///|
/// 跟随系统的整套主题:深浅取 [system_prefers_dark],主色取
/// [system_accent](系统无主色概念时为空串,回落内置 primary)。
/// 配合 on_system_theme_change 可在系统换主题时实时重算。
pub fn theme_from_system() -> Theme {
  let dark = system_prefers_dark()
  let accent = system_accent()
  if accent == "" {
    if dark {
      dark_theme()
    } else {
      default_theme()
    }
  } else {
    theme_from_accent(accent, dark~)
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
  buf.write_string("scrollbar.overlay-indicator:not(.dragging):not(.hovering) { background-color: transparent; }")
  buf.write_string("scrollbar.overlay-indicator:not(.dragging):not(.hovering) slider { min-width: 4px; min-height: 4px; margin: 3px; border-radius: 4px; background-color: \{t.border}; }")
  buf.write_string("scrollbar.overlay-indicator.dragging, scrollbar.overlay-indicator.hovering { background-color: \{t.primary_light}; }")
  buf.write_string("scrollbar.overlay-indicator.dragging slider, scrollbar.overlay-indicator.hovering slider { background-color: \{t.primary}; border-radius: 8px; }")
  buf.write_string("scrollbar slider:hover { background-color: \{t.primary}; border-radius: 8px; }")
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
    // 整体重绘兜底推迟一拍:按钮点击等输入事件回调里同步
    // process_updates 会被 GTK 吞掉(定时器路径实测有效、点击路径实测
    // 无效),脱离触发上下文后再逐窗口同步重绘;连刷两拍,第二拍兜住
    // 第一拍漏掉的子窗口
    post_task(fn() { ffi_repaint_all() })
    post_delayed_task(60, fn() { ffi_repaint_all() })
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
fn draw_clear_x(
  p : Painter,
  cx : Double,
  cy : Double,
  r? : Double = 4.0,
  color? : String = theme_text_secondary(),
) -> Unit {
  p.set_stroke_color(color)
  p.begin_path()
  p.move_to(cx - r, cy - r)
  p.line_to(cx + r, cy + r)
  p.move_to(cx + r, cy - r)
  p.line_to(cx - r, cy + r)
  p.stroke()
}

///|
/// 自绘小图标(矢量,不依赖字体字形——字形图标 Windows 渲染发虚且
/// 跨平台不一致,库内一律矢量;GTK 端 align=Center 无效,顺带解决
/// 字形居中问题)。中心 (cx,cy),s 为半径。

///| + 号(步进按钮)
fn draw_glyph_plus(p : Painter, cx : Double, cy : Double, s : Double, color : String) -> Unit {
  p.set_stroke_color(color)
  p.begin_path()
  p.move_to(cx - s, cy)
  p.line_to(cx + s, cy)
  p.move_to(cx, cy - s)
  p.line_to(cx, cy + s)
  p.stroke()
}

///| − 号(步进按钮)
fn draw_glyph_minus(p : Painter, cx : Double, cy : Double, s : Double, color : String) -> Unit {
  p.set_stroke_color(color)
  p.begin_path()
  p.move_to(cx - s, cy)
  p.line_to(cx + s, cy)
  p.stroke()
}

///| ‹ 朝左三角(实心)
fn draw_glyph_left(p : Painter, cx : Double, cy : Double, s : Double, color : String) -> Unit {
  p.set_fill_color(color)
  p.begin_path()
  p.move_to(cx + s / 2.0, cy - s)
  p.line_to(cx + s / 2.0, cy + s)
  p.line_to(cx - s / 2.0 - 1.0, cy)
  p.close_path()
  p.fill()
}

///| › 朝右三角(实心)
fn draw_glyph_right(p : Painter, cx : Double, cy : Double, s : Double, color : String) -> Unit {
  p.set_fill_color(color)
  p.begin_path()
  p.move_to(cx - s / 2.0, cy - s)
  p.line_to(cx - s / 2.0, cy + s)
  p.line_to(cx + s / 2.0 + 1.0, cy)
  p.close_path()
  p.fill()
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
  ViewLike::set_focusable(v, true)
  ViewLike::on_focus_in(v, fn() {
    focused.val = true
    repaint()
    false
  })
  ViewLike::on_focus_out(v, fn() {
    focused.val = false
    repaint()
    false
  })
  ViewLike::on_key_down(v, fn(e) {
    if e.code == VKEY_RETURN || e.code == VKEY_SPACE {
      on_activate()
      true
    } else {
      false
    }
  })
}

///|
/// 圆角矩形填充(bezier 控制点按圆率 0.5522 近似四角)。r 自动钳到
/// w/2、h/2 以内,窄条也不会画出负半径。
fn fill_round_rect(
  p : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  r : Double,
) -> Unit {
  let r = if r > w / 2.0 { w / 2.0 } else if r > h / 2.0 { h / 2.0 } else { r }
  let k = 0.5522847498
  p.begin_path()
  p.move_to(x + r, y)
  p.line_to(x + w - r, y)
  p.bezier_curve_to(x + w - r + k * r, y, x + w, y + r - k * r, x + w, y + r)
  p.line_to(x + w, y + h - r)
  p.bezier_curve_to(x + w, y + h - r + k * r, x + w - r + k * r, y + h, x + w - r, y + h)
  p.line_to(x + r, y + h)
  p.bezier_curve_to(x + r - k * r, y + h, x, y + h - r + k * r, x, y + h - r)
  p.line_to(x, y + r)
  p.bezier_curve_to(x, y + r - k * r, x + r - k * r, y, x + r, y)
  p.close_path()
  p.fill()
}

///|
/// 自绘交互项通用挂载器:背景色表达 hover/active,文字垂直居中。
/// bg_of(active, hover) 返回背景色(空串表示透明);fg_of(active) 返回文字色。
/// align_start=false 时文字水平居中(分段/分页),true 时左对齐(菜单)。
/// (GTK 端水平 align 未实现,居中一律手动:测文本宽、x=(w-文本宽)/2。)
/// icon 非空时画在 pad_x 起(16px,文字右移 24);accent 时选中态左缘
/// 画 3px 强调条(与文字同色);rounded 时背景画 4px 圆角。
fn stateful_item(
  text : String,
  style : Array[(String, Double)],
  selected : Store[String],
  bg_of : (Bool, Bool) -> String,
  fg_of : (Bool, Bool) -> String,
  pad_x? : Double = 0.0,
  align_start? : Bool = false,
  font_size? : Double = 13.0,
  icon? : IconKind? = None,
  accent? : Bool = false,
  rounded? : Bool = false,
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
        let b = ViewLike::get_bounds(v)
        let w = b.width
        let h = b.height
        let act = selected.get() == text
        let bg = bg_of(act, hover.val)
        if bg != "" {
          p.set_fill_color(bg)
          if rounded {
            fill_round_rect(p, 0.0, 0.0, w, h, 4.0)
          } else {
            p.fill_rect(0.0, 0.0, w, h)
          }
        }
        if accent && act {
          p.set_fill_color(fg_of(act, hover.val))
          p.fill_rect(0.0, 8.0, 3.0, h - 16.0)
        }
        // 图标在 pad_x 起(16px),文字右移;无图标按 align_start/居中排
        let text_x = match icon {
          Some(k) => {
            draw_icon(p, k, pad_x + 8.0, h / 2.0, 16.0 * 0.42, fg_of(act, hover.val))
            pad_x + 24.0
          }
          None =>
            if align_start {
              pad_x
            } else {
              (w - text_w) / 2.0
            }
        }
        // 文字:AttributedText 支持指定字号,垂直居中交给 valign=Center;
        // 水平位置手动计算(见函数注释)
        let at = AttributedText::new(text, valign=Center, wrap=false)
        at.set_font(font)
        at.set_color(fg_of(act, hover.val))
        p.draw_attributed_text(at, text_x, 0.0, w, h)
        if focused.val {
          draw_focus_ring(p, w, h)
        }
      }

      v.on_draw(draw_item)
      View::set_cursor(v, hand())
      ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 {
          ViewLike::focus(v)
          selected.set(text)
          true
        } else {
          false
        }
      })
      ViewLike::on_mouse_enter(v, fn(_e) {
        hover.val = true
        ViewLike::schedule_paint(v)
      })
      ViewLike::on_mouse_leave(v, fn(_e) {
        hover.val = false
        ViewLike::schedule_paint(v)
      })
      bind_focus(v, fn() { ViewLike::schedule_paint(v) }, focused, fn() {
        selected.set(text)
      })
      selected.subscribe(fn(_s) { ViewLike::schedule_paint(v) })
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
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
/// 侧边导航菜单(对应 EP Menu):hover 浅灰、选中主题浅蓝底 + 主题色
/// 文字 + 左侧 3px 强调条,4px 圆角,文字垂直居中。icons 给「项文本 →
/// 图标」(缺省不画);selected 为共享状态,主区页面可订阅同一 Store
/// 做 set_visible 联动。
pub fn side_menu(
  items : Array[String],
  selected : Store[String],
  width? : Double = 180.0,
  icons? : Array[(String, IconKind)] = [],
) -> Node {
  let nodes : Array[Node] = []
  for it in items {
    let mut kind : IconKind? = None
    for kv in icons {
      if kv.0 == it {
        kind = Some(kv.1)
      }
    }
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
        icon=kind,
        accent=true,
        rounded=true,
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
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
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
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
    },
  }
}

///|
/// 数字角标(对应 EP Badge 的数字形态):红底白字小块,宽度自适应。
/// 语义红 draw 现取跟随主题(不复用 tag——其 color 参数为固定色语义)。
pub fn badge_count(count : Int) -> Node {
  let text = count.to_string()
  {
    mount: fn(parent) {
      let font = Font::new("Sans", 12.0)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let w = text_w + 14.0
      let h = 18.0
      let c = themed_container(style=[
        ("width", w),
        ("height", h),
        ("marginRight", 8.0),
      ])
      c.on_draw(fn(p) {
        p.set_fill_color(theme_danger())
        p.fill_rect(0.0, 0.0, w, h)
        p.draw_text(
          text,
          (w - text_w) / 2.0,
          0.0,
          w,
          h,
          valign=Center,
          color="#FFFFFF",
        )
      })
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
    },
  }
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
        let b = ViewLike::get_bounds(v)
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
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
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
          let bd = ViewLike::get_bounds(b)
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
        ViewLike::on_mouse_down(b, fn(e) {
          if e.button == 1 {
            ViewLike::focus(b)
            activate()
            true
          } else {
            false
          }
        })
        bind_focus(b, fn() { ViewLike::schedule_paint(b) }, focused, activate)
        ViewLike::on_mouse_enter(b, fn(_e) {
          hover.val = true
          ViewLike::schedule_paint(b)
        })
        ViewLike::on_mouse_leave(b, fn(_e) {
          hover.val = false
          ViewLike::schedule_paint(b)
        })
        current.subscribe(fn(_v) { ViewLike::schedule_paint(b) })
        row.add_child(b)
      }

      add_btn("‹", -1, false)
      let mut i = 1
      while i <= pages {
        add_btn(i.to_string(), i, true)
        i = i + 1
      }
      add_btn("›", 1, false)
      attach(parent, ViewLike::view(row))
      ViewLike::view(row)
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
        let b = ViewLike::get_bounds(outer)
        let w = b.width
        let h = b.height
        // 边框
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.0, 0.0, w, h)
        // 标题栏底部分隔线
        p.set_fill_color(theme_border())
        p.fill_rect(0.0, head_h, w, 1.0)
      })
      // 标题(加粗,垂直居中,左内边距 16;文字为自绘,padding 样式
      // 只影响子项排列,起点须在 draw 坐标里给)
      let title_at = AttributedText::new(title, valign=Center, wrap=false)
      title_at.set_font(Font::new("Sans", 14.0, weight=Bold))
      title_at.set_color(theme_text_primary())
      let title = themed_container(style=[("height", head_h)])
      fn apply_title_color() -> Unit {
        title_at.set_color(theme_text_primary())
        title_at.set_text(title_at.get_text())
        ViewLike::schedule_paint(title)
      }

      apply_title_color()
      on_theme_change(apply_title_color)
      title.on_draw(fn(p) {
        let b = ViewLike::get_bounds(title)
        p.draw_attributed_text(title_at, 16.0, 0.0, b.width - 16.0, head_h)
      })
      outer.add_child(title)
      // 内容区
      let body = themed_container(style=[("padding", 14.0)], style_str=[
        ("flexDirection", "column"),
      ])
      for ch in children {
        ignore((ch.mount)(ViewLike::view(body)))
      }
      outer.add_child(body)
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
///|
/// ASCII 小写(关键字大小写不敏感比较用)。
fn ascii_lower(s : String) -> String {
  let out = Ref(StringBuilder())
  for ch in s {
    let c = ch.to_int()
    if c >= 65 && c <= 90 {
      out.val.write_char((c + 32).unsafe_to_char())
    } else {
      out.val.write_char(ch)
    }
  }
  out.val.to_string()
}

///|
/// 语言关键字集与行注释前缀(代码高亮通用参数表)。
fn lang_keywords(lang : String) -> (Array[String], String) {
  match lang {
    "js" | "ts" =>
      ([
        "function", "const", "let", "var", "if", "else", "return", "class",
        "extends", "import", "export", "new", "typeof", "await", "async",
        "for", "while", "switch", "case", "break", "default", "try", "catch",
        "throw", "this", "super", "null", "undefined", "true", "false",
        "static", "get", "set", "of", "in", "yield", "delete", "void",
      ], "//")
    "python" =>
      ([
        "def", "class", "import", "from", "if", "elif", "else", "for",
        "while", "in", "not", "and", "or", "lambda", "return", "None",
        "True", "False", "self", "pass", "with", "as", "try", "except",
        "finally", "raise", "yield", "global", "del", "assert", "break",
        "continue", "is",
      ], "#")
    "rust" =>
      ([
        "fn", "let", "mut", "pub", "struct", "enum", "impl", "trait", "use",
        "mod", "match", "if", "else", "loop", "while", "for", "in", "return",
        "Some", "None", "Ok", "Err", "self", "crate", "move", "ref", "where",
        "async", "await", "dyn", "as", "break", "const", "continue",
        "static", "type", "unsafe", "true", "false",
      ], "//")
    "c" =>
      ([
        "include", "define", "typedef", "struct", "union", "enum", "static",
        "const", "int", "void", "char", "float", "double", "return", "if",
        "else", "for", "while", "switch", "case", "break", "default",
        "sizeof", "long", "short", "unsigned", "signed", "extern", "goto",
        "do",
      ], "//")
    "go" =>
      ([
        "func", "package", "import", "var", "const", "type", "struct",
        "interface", "map", "chan", "go", "defer", "if", "else", "for",
        "range", "return", "nil", "break", "continue", "switch", "case",
        "default", "select", "fallthrough",
      ], "//")
    "bash" =>
      ([
        "echo", "if", "then", "else", "fi", "for", "do", "done", "while",
        "case", "esac", "function", "local", "export", "return", "exit",
        "read", "shift", "in",
      ], "#")
    "sql" =>
      ([
        "select", "from", "where", "insert", "into", "values", "update",
        "set", "delete", "create", "table", "join", "left", "right", "inner",
        "outer", "on", "group", "order", "by", "limit", "as", "and", "or",
        "not", "null", "distinct", "count", "sum", "avg", "primary", "key",
        "foreign", "references", "alter", "drop", "index", "view",
      ], "--")
    _ =>
      ([
        "fn", "let", "mut", "if", "else", "for", "while", "match", "return",
        "struct", "impl", "pub", "enum", "trait", "type", "true", "false",
        "using", "import", "test", "const", "view",
      ], "//")
  }
}

///|
/// 通用语言分词:字符串("…"/'…')、行注释(按语言)、关键字(大小写
/// 不敏感)、数字与默认文本。tokenize_moonbit 即本函数的 moonbit 特化。
pub fn tokenize_lang(line : String, lang : String) -> Array[Token] {
  let (keywords, comment_prefix) = lang_keywords(lang)
  let out : Array[Token] = []
  let cs : Array[Char] = []
  for ch in line {
    cs.push(ch)
  }
  let n = cs.length()
  let buf = Ref(StringBuilder())
  let in_string = Ref(false)
  let quote : Ref[Char] = Ref('"')
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
      if ch == quote.val {
        flush()
        in_string.val = false
      }
    } else if ch == '"' || ch == '\'' {
      flush()
      in_string.val = true
      quote.val = ch
      buf.val.write_char(ch)
    } else if ch == '/' && i + 1 < n && cs[i + 1] == '/' && comment_prefix == "//" {
      flush()
      let comment = StringBuilder()
      while i < n {
        comment.write_char(cs[i])
        i = i + 1
      }
      out.push({ text: comment.to_string(), color: "#5C6370", })
      break
    } else if ch == '#' && comment_prefix == "#" {
      flush()
      let comment = StringBuilder()
      while i < n {
        comment.write_char(cs[i])
        i = i + 1
      }
      out.push({ text: comment.to_string(), color: "#5C6370", })
      break
    } else if ch == '-' && i + 1 < n && cs[i + 1] == '-' && comment_prefix == "--" {
      flush()
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
  let lowered = ascii_lower(word)
  for k in keywords {
    if ascii_lower(k) == lowered {
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
  lang? : String = "moonbit",
  font_size? : Double = 13.0,
  width? : Double = 560.0,
  line_numbers? : Bool = false,
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
      // 行号区:等宽数字位宽 × 最大位数 + 间距
      let digit_probe = make_at("8", "#FFFFFF")
      let digit_w = digit_probe.get_bounds_for(10000.0, 100.0).width
      let digits = lines.length().to_string().length()
      let num_off = if line_numbers {
        digit_w * digits.to_double() + 24.0
      } else {
        0.0
      }
      let laid : Array[(Array[(AttributedText, Double)], Double)] = []
      let mut max_line_w = 0.0
      for idx, line in lines {
        let segs : Array[(AttributedText, Double)] = []
        let mut x = num_off
        if line_numbers {
          let num_txt = (idx + 1).to_string()
          let pad = Ref(StringBuilder())
          for _i in 0..<(digits - num_txt.length()) {
            pad.val.write_char(' ')
          }
          let at_num = make_at(pad.val.to_string() + num_txt, "#6B7280")
          segs.push((at_num, 16.0))
        }
        for tok in tokenize_lang(line, lang) {
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
      let content_w = max_line_w + num_off + 32.0
      let view_w = if width > content_w { width } else { content_w }
      let view_h = line_h * laid.length().to_double() + 28.0
      let c = themed_container(style=[("width", view_w), ("height", view_h)])
      ViewLike::set_background_color(c, "#282C34")
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
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
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
      ViewLike::set_background_color(c, color)
      // 字母水平居中:GTK 端 align 无效,mount 时测宽手动摆位
      let letter_probe = AttributedText::new(letter, wrap=false)
      letter_probe.set_font(Font::new("Sans", size / 2.2))
      let letter_w = letter_probe.get_bounds_for(10000.0, 1000.0).width
      c.on_draw(fn(p) {
        let b = ViewLike::get_bounds(c)
        p.draw_text(
          letter,
          (b.width - letter_w) / 2.0,
          0.0,
          b.width,
          b.height,
          valign=Center,
          color="#FFFFFF",
        )
      })
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
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
        ViewLike::set_visible(v, false)
      }

      close.on_draw(fn(p) {
        let b = ViewLike::get_bounds(close)
        let c = if hover.val { type_color(t) } else { theme_text_secondary() }
        draw_clear_x(p, b.width / 2.0, b.height / 2.0, color=c)
        if close_focused.val {
          draw_focus_ring(p, b.width, b.height)
        }
      })
      View::set_cursor(close, hand())
      ViewLike::on_mouse_down(close, fn(e) {
        if e.button == 1 {
          ViewLike::focus(close)
          close_it()
          true
        } else {
          false
        }
      })
      bind_focus(close, fn() { ViewLike::schedule_paint(close) }, close_focused, close_it)
      ViewLike::on_mouse_enter(close, fn(_e) {
        hover.val = true
        ViewLike::schedule_paint(close)
      })
      ViewLike::on_mouse_leave(close, fn(_e) {
        hover.val = false
        ViewLike::schedule_paint(close)
      })
      v.add_child(close)
      // 让关闭钮靠右:中间垫一个弹性空白
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
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
        // 数字水平居中:GTK 端 align 无效,构造期测宽存闭包
        let num_txt = (i + 1).to_string()
        let num_probe = AttributedText::new(num_txt, wrap=false)
        num_probe.set_font(Font::new("Sans", 12.0, weight=SemiBold))
        let num_w = num_probe.get_bounds_for(10000.0, 1000.0).width
        if i > 0 {
          let line = themed_container(style=[
            ("flex", 1.0),
            ("height", 2.0),
            ("marginRight", 6.0),
          ])
          let idx = i
          line.on_draw(fn(p) {
            let b = ViewLike::get_bounds(line)
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
          let b = ViewLike::get_bounds(bx)
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
            num_txt,
            (b.width - num_w) / 2.0,
            0.0,
            b.width,
            b.height,
            valign=Center,
            color=match st {
              0 => theme_primary()
              1 => "#FFFFFF"
              _ => theme_text_secondary()
            },
          )
        })
        current.subscribe(fn(_v) { ViewLike::schedule_paint(bx) })
        row.add_child(bx)
        boxes.push(bx)
      }
      for i in 0..<n {
        let l = Label::new(items[i])
        ViewLike::set_font(l, font)
        let cur_ref = current
        // 步骤文字色随「当前步」与主题双状态变化;set_color 后须同文
        // set_text 触发重排(否则重绘仍用旧色,见 adaptation.md)
        fn apply_step_label() -> Unit {
          ViewLike::set_color(l, 
            if i <= cur_ref.get() {
              theme_text_primary()
            } else {
              theme_text_secondary()
            },
          )
          l.set_text(l.get_text())
        }

        apply_step_label()
        on_theme_change(apply_step_label)
        cur_ref.subscribe(fn(_v) { apply_step_label() })
        row.add_child(l)
      }
      attach(parent, ViewLike::view(row))
      ViewLike::view(row)
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
            let b = ViewLike::get_bounds(head)
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
          ViewLike::set_color(title, theme_text_primary())
          title.set_text(title.get_text())
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
          ignore((ch.mount)(ViewLike::view(body)))
        }
        let apply = fn() -> Unit {
          ViewLike::set_visible(body, open.val)
          ViewLike::schedule_paint(arrow)
        }
        let toggle = fn() -> Unit {
          open.val = !open.val
          apply()
        }

        apply()
        View::set_cursor(head, hand())
        ViewLike::on_mouse_down(head, fn(e) {
          if e.button == 1 {
            ViewLike::focus(head)
            toggle()
            true
          } else {
            false
          }
        })
        bind_focus(head, fn() { ViewLike::schedule_paint(head) }, head_focused, toggle)
        let panel = themed_container(style=[("marginBottom", 6.0)], style_str=[
          ("flexDirection", "column"),
        ])
        panel.add_child(head)
        panel.add_child(body)
        outer.add_child(panel)
      }
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
          let b = ViewLike::get_bounds(node_col)
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
          ViewLike::set_color(title, theme_text_primary())
          title.set_text(title.get_text())
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
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
      symbol_at.set_color(type_color(t))
      let symbol_w = symbol_at.get_bounds_for(10000.0, 100.0).width

      bind_bg(icon, fn() { type_light_color(t) })
      // 符号色随主题:set_color 后同文重排(AT 属性变更不自动失效)
      fn apply_symbol_color() -> Unit {
        symbol_at.set_color(type_color(t))
        symbol_at.set_text(symbol_at.get_text())
        ViewLike::schedule_paint(icon)
      }

      apply_symbol_color()
      on_theme_change(apply_symbol_color)
      icon.on_draw(fn(p) {
        let b = ViewLike::get_bounds(icon)
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
      ViewLike::set_font(t1, Font::new("Sans", 18.0, weight=SemiBold))
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
        ignore((ch.mount)(ViewLike::view(btns)))
      }
      outer.add_child(icon)
      outer.add_child(big)
      outer.add_child(sub)
      outer.add_child(btns)
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
      ViewLike::set_font(num, Font::new("Sans", 24.0, weight=SemiBold))
      bind_fg(num, fn() { theme_text_primary() })
      let cap = Label::new(title)
      bind_fg(cap, fn() { theme_text_secondary() })
      value.subscribe(fn(v) { num.set_text(v) })
      outer.add_child(num)
      outer.add_child(cap)
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
        let b = ViewLike::get_bounds(v)
        let frac = value.get()
        if frac > 0.0 {
          p.set_fill_color(theme_primary())
          p.fill_rect(0.0, 0.0, b.width * frac, b.height)
        }
      })
      value.subscribe(fn(_x) { ViewLike::schedule_paint(v) })
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
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
      ViewLike::set_font(l, role_font(role))
      fn apply_color() -> Unit {
        ViewLike::set_color(l, role_color(role))
        // 同文重写一次:set_color 改的 Pango 前景属性在部分控件上不被
        // 下次绘制拾取,重排强制生效
        l.set_text(l.get_text())
      }

      apply_color()
      on_theme_change(apply_color)
      l.set_align(Start)
      apply_style(l, style~, style_str~)
      handle(l)
      attach(parent, ViewLike::view(l))
      ViewLike::view(l)
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
        ("height", control_height),
        ("marginRight", 8.0),
      ])
      v.on_draw(fn(p) {
        let b = ViewLike::get_bounds(v)
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
      ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 {
          ViewLike::focus(v)
          on_click()
          true
        } else {
          false
        }
      })
      bind_focus(v, fn() { ViewLike::schedule_paint(v) }, focused, on_click)
      ViewLike::on_mouse_enter(v, fn(_e) {
        hover.val = true
        ViewLike::schedule_paint(v)
      })
      ViewLike::on_mouse_leave(v, fn(_e) {
        hover.val = false
        ViewLike::schedule_paint(v)
      })
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
    },
  }
}

///|
/// Windows 原生单行输入文字贴顶(Win32 EDIT 自客户区顶部绘制,无垂直
/// 居中样式):按字体行高把原生控件收窄到「行高(带原生边框时 +1px×2)」,
/// 剩余高度均分为上下 margin,视觉垂直居中;其余平台原生居中,不动。
fn entry_vcenter(e : Entry, box_height : Double, bordered : Bool) -> Unit {
  if platform() != "windows" {
    return
  }
  let probe = AttributedText::new("Ag", wrap=false)
  probe.set_font(Font::new("Sans", 13.0))
  let line = probe.get_bounds_for(10000.0, 1000.0).height
  let ctrl = line + (if bordered { 2.0 } else { 0.0 })
  ViewLike::set_style(e, "height", ctrl)
  let rest = (box_height - ctrl) / 2.0
  if rest > 0.0 {
    ViewLike::set_style(e, "marginTop", rest)
    ViewLike::set_style(e, "marginBottom", rest)
  }
}

///|
/// 输入框文字色跟随主题:Linux 由全局接管 CSS 负责,不逐控件设;其余
/// 平台显式设当前主题前景/背景并订阅主题切换重设(Windows 原生
/// RichEdit 恒黑字不随主题,是此函数存在的原因)。
fn bind_entry_theme(e : Entry) -> Unit {
  if platform() == "linux" {
    return
  }
  fn apply() -> Unit {
    e.set_colors(fg=theme_text_regular(), bg=theme_bg_panel())
  }

  apply()
  on_theme_change(apply)
}

///|
/// 主题化单行输入:统一字体与行高;文字色经主题通道跟随色板。
pub fn entry_t(
  text? : String = "",
  password? : Bool = false,
  height? : Double = control_height,
  on_input? : (String) -> Unit = fn(_s) {  },
) -> Node {
  {
    mount: fn(parent) {
      let e = match password {
        true => Entry::make(text~, entry_type=Password)
        false => Entry::make(text~, entry_type=Normal)
      }
      ViewLike::set_font(e, Font::new("Sans", 13.0))
      // Linux 端 Entry 尺寸已归一化(min-height:0),裸 Entry 自然高只剩
      // 文字行高,补显式高度维持输入框观感;Windows 文字贴顶,按行高
      // 收窄控件 + 均分边距实现垂直居中
      if platform() == "linux" {
        ViewLike::set_style(e, "height", height)
      } else {
        entry_vcenter(e, height, true)
      }
      bind_entry_theme(e)
      e.on_text_change(fn() { on_input(e.get_text()) })
      attach(parent, ViewLike::view(e))
      ViewLike::view(e)
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
        ViewLike::schedule_paint(v)
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
          ViewLike::schedule_paint(v)
        }
      }
      View::set_cursor(v, hand())
      ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 && !disabled {
          ViewLike::focus(v)
          activate()
          true
        } else {
          false
        }
      })
      ViewLike::on_mouse_enter(v, fn(_e) {
        hover.val = true
        repaint()
      })
      ViewLike::on_mouse_leave(v, fn(_e) {
        hover.val = false
        repaint()
      })
      if !disabled {
        bind_focus(v, repaint, focused, activate)
      }
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
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
            ViewLike::schedule_paint(row)
          }
        }
        View::set_cursor(row, hand())
        ViewLike::on_mouse_down(row, fn(e) {
          if e.button == 1 && !disabled {
            ViewLike::focus(row)
            activate()
            true
          } else {
            false
          }
        })
        ViewLike::on_mouse_enter(row, fn(_e) {
          hover.val = true
          repaint()
        })
        ViewLike::on_mouse_leave(row, fn(_e) {
          hover.val = false
          repaint()
        })
        if !disabled {
          ViewLike::set_focusable(row, true)
          ViewLike::on_focus_in(row, fn() {
            focused.val = true
            repaint()
            false
          })
          ViewLike::on_focus_out(row, fn() {
            focused.val = false
            repaint()
            false
          })
          // Enter/Space 选中;方向键在组内移动选中并跟随焦点
          ViewLike::on_key_down(row, fn(e) {
            if e.code == VKEY_RETURN || e.code == VKEY_SPACE {
              activate()
              true
            } else if e.code == VKEY_DOWN || e.code == VKEY_RIGHT {
              if i + 1 < options.length() {
                selected.set(options[i + 1])
                ViewLike::focus(rows[i + 1])
                true
              } else {
                false
              }
            } else if e.code == VKEY_UP || e.code == VKEY_LEFT {
              if i > 0 {
                selected.set(options[i - 1])
                ViewLike::focus(rows[i - 1])
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
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
        let b = ViewLike::get_bounds(v)
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
      ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 && !disabled {
          ViewLike::focus(v)
          activate()
          true
        } else {
          false
        }
      })
      checked.subscribe(fn(_v) { ViewLike::schedule_paint(v) })
      if !disabled {
        bind_focus(v, fn() { ViewLike::schedule_paint(v) }, focused, activate)
      }
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
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
  height? : Double = control_height,
  clearable? : Bool = false,
  on_input? : (String) -> Unit = fn(_s) {  },
  invalid? : Store[Bool] = Store::new(false),
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
        let b = ViewLike::get_bounds(outer)
        p.set_stroke_color(
          if invalid.get() {
            theme_danger()
          } else if focused.val {
            theme_focus_accent()
          } else {
            theme_border()
          },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        if clearable && hover.val && has_text.val {
          draw_clear_x(p, clear_x, b.height / 2.0)
        }
      })
      invalid.subscribe(fn(_v) { ViewLike::schedule_paint(outer) })
      let entry = match password {
        true => Entry::make(text~, entry_type=Password)
        false => Entry::make(text~, entry_type=Normal)
      }
      ViewLike::set_borderless(entry, true)
      set_panel_bg(entry)
      ViewLike::set_style(entry, "flex", 1.0)
      ViewLike::set_style(entry, "marginLeft", 10.0)
      ViewLike::set_style(entry, "marginRight", if clearable { 26.0 } else { 10.0 })
      if platform() == "windows" {
        // 文字贴顶:按行高收窄控件并垂直居中(外框线 1px×2 从可用高扣)
        entry_vcenter(entry, height - 2.0, false)
      } else {
        // 原生子窗口绘制在自绘之上:上下留 2 让出边框线
        ViewLike::set_style(entry, "marginTop", 2.0)
        ViewLike::set_style(entry, "marginBottom", 2.0)
      }
      bind_entry_theme(entry)
      ViewLike::on_focus_in(entry, fn() {
        focused.val = true
        ViewLike::schedule_paint(outer)
        false
      })
      ViewLike::on_focus_out(entry, fn() {
        focused.val = false
        ViewLike::schedule_paint(outer)
        // 光标归 0:文本滚回首端,溢出裁切固定发生在右缘,左侧不再出现
        // 随光标位置变化的余量
        entry.set_position(0)
        false
      })
      entry.on_text_change(fn() {
        let cur = entry.get_text()
        has_text.val = cur != ""
        on_input(cur)
        ViewLike::schedule_paint(outer)
      })
      if clearable {
        ViewLike::on_mouse_enter(outer, fn(_e) {
          hover.val = true
          ViewLike::schedule_paint(outer)
        })
        ViewLike::on_mouse_leave(outer, fn(_e) {
          hover.val = false
          ViewLike::schedule_paint(outer)
        })
        // 清空带不与 Entry 重叠(其事件窗口只覆盖原生子窗口之外的区域),
        // 点击落在带上即清空
        ViewLike::on_mouse_up(outer, fn(e) {
          let b = ViewLike::get_bounds(outer)
          if e.button == 1 && has_text.val && e.view_x >= b.width - 24.0 {
            entry.set_text("")
            has_text.val = false
            // SetText 不触发 on_text_change(fork 的 is-editing 守卫吞掉
            // changed 信号,防编程式设置回环):清空后必须显式补一次回调,
            // 否则使用方的过滤条件不更新(文本没了列表不变)
            on_input("")
            ViewLike::schedule_paint(outer)
            true
          } else {
            false
          }
        })
      }
      outer.add_child(entry)
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
  num_width? : Double = 64.0,
) -> Node {
  {
    mount: fn(parent) {
      let row = themed_container(
        style=[("height", control_height)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let font = Font::new("Sans", 13.0)
      fn step_btn(dir : Double) -> Unit {
        let b = themed_container(
          style=[("width", 28.0), ("height", control_height)],
          style_str=[("alignItems", "center")],
        )
        bind_bg(b, fn() { theme_info_light() })
        let hover = Ref(false)
        b.on_draw(fn(p) {
          let bd = ViewLike::get_bounds(b)
          p.set_fill_color(if hover.val { theme_primary_light() } else { theme_info_light() })
          p.fill_rect(0.0, 0.0, bd.width, bd.height)
          // +/− 矢量自绘(字形图标跨平台发虚,GTK align 亦无效)
          if dir > 0.0 {
            draw_glyph_plus(p, bd.width / 2.0, bd.height / 2.0, 4.0, theme_text_regular())
          } else {
            draw_glyph_minus(p, bd.width / 2.0, bd.height / 2.0, 4.0, theme_text_regular())
          }
        })
        View::set_cursor(b, hand())
        ViewLike::on_mouse_down(b, fn(e) {
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
        ViewLike::on_mouse_enter(b, fn(_e) {
          hover.val = true
          ViewLike::schedule_paint(b)
        })
        ViewLike::on_mouse_leave(b, fn(_e) {
          hover.val = false
          ViewLike::schedule_paint(b)
        })
        row.add_child(b)
      }

      step_btn(-1.0)
      // marginRight 0:EP InputNumber 的按钮与输入区紧贴
      let num = themed_container(
        style=[("width", num_width), ("height", control_height), ("marginRight", 0.0)],
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
        let b = ViewLike::get_bounds(num)
        let tw = t.get_bounds_for(10000.0, 100.0).width
        p.draw_attributed_text(t, (b.width - tw) / 2.0, 0.0, b.width, b.height)
      })
      value.subscribe(fn(v) {
        t.set_text(v.to_string())
        ViewLike::schedule_paint(num)
      })
      row.add_child(num)
      step_btn(1.0)
      attach(parent, ViewLike::view(row))
      ViewLike::view(row)
    },
  }
}

///|
/// 表单项:左侧标签(灰,定宽)+ 右侧控件区,垂直居中。error 为校验
/// 错误文案 Store:非空时控件行下方显示 danger 红字;行高固定预留,
/// 错误出现/消失不引起布局跳动。
pub fn form_item(
  label : String,
  control : Node,
  label_width? : Double = 90.0,
  error? : Store[String] = Store::new(""),
) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(style_str=[("flexDirection", "column")])
      let row = themed_container(
        style=[("marginBottom", 2.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let k = Label::new(label)
      ViewLike::set_font(k, Font::new("Sans", 13.0))
      bind_fg(k, fn() { theme_text_secondary() })
      k.set_align(End)
      let kwrap = themed_container(style=[("width", label_width), ("marginRight", 12.0)])
      kwrap.add_child(k)
      row.add_child(kwrap)
      ignore((control.mount)(ViewLike::view(row)))
      outer.add_child(row)
      let err = Label::new(error.get())
      ViewLike::set_font(err, Font::new("Sans", 12.0))
      bind_fg(err, fn() { theme_danger() })
      ViewLike::set_style(err, "height", 18.0)
      ViewLike::set_style(err, "marginLeft", label_width + 12.0)
      outer.add_child(err)
      error.subscribe(fn(msg) {
        // set_text 新文本本身触发 GTK 重排,重排取 bind_fg 已设的 danger
        // 颜色属性;红字色固定由 bind_fg 管,此处 set_color 反而错(参数
        // 是颜色不是文本)
        err.set_text(msg)
      })
      let spacer = themed_container(style=[("height", 8.0)])
      outer.add_child(spacer)
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
      ViewLike::set_font(l, Font::new("Sans", 13.0))
      fn apply_color() -> Unit {
        ViewLike::set_color(l, theme_primary())
        l.set_text(l.get_text())
      }

      apply_color()
      on_theme_change(apply_color)
      row.add_child(l)
      let underline = themed_container(style=[("height", 1.0)])
      bind_bg(underline, fn() { theme_primary() })
      row.add_child(underline)
      fn apply() -> Unit {
        ViewLike::set_visible(underline, hover.val)
      }

      apply()
      ViewLike::on_mouse_enter(row, fn(_e) {
        hover.val = true
        apply()
      })
      ViewLike::on_mouse_leave(row, fn(_e) {
        hover.val = false
        apply()
      })
      View::set_cursor(row, hand())
      ViewLike::on_mouse_down(row, fn(e) {
        if e.button == 1 {
          on_click()
          true
        } else {
          false
        }
      })
      attach(parent, ViewLike::view(row))
      ViewLike::view(row)
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
          ViewLike::set_font(label, font)
          bind_fg(label, fn() { theme_text_primary() })
          row.add_child(arrow)
          row.add_child(label)
          let kids = themed_container(
            style_str=[("flexDirection", "column")],
          )
          ViewLike::set_visible(kids, false)
          if has_children {
            build(nd.children, level + 1, kids)
          }
          View::set_cursor(row, hand())
          ViewLike::on_mouse_down(row, fn(e) {
            if e.button == 1 && has_children {
              open.val = !open.val
              ViewLike::schedule_paint(arrow)
              ViewLike::set_visible(kids, open.val)
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
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
          ViewLike::set_font(l, font)
          bind_fg(l, fn() { theme_text_regular() })
          row.add_child(mark)
          row.add_child(l)
          let mark_ref = mark
          View::set_cursor(row, hand())
          ViewLike::on_mouse_down(row, fn(e) {
            if e.button == 1 {
              if contains(sel.val, it_ref) {
                sel.val = remove_one(sel.val, it_ref)
              } else {
                let grown = sel.val.copy()
                grown.push(it_ref)
                sel.val = grown
              }
              ViewLike::schedule_paint(mark_ref)
              true
            } else {
              false
            }
          })
          box.add_child(row)
          rows.val.push(ViewLike::view(row))
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
      fn mid_btn(to_right : Bool) -> Unit {
        let b = themed_container(
          style=[("width", 32.0), ("height", 28.0), ("marginRight", 8.0)],
          style_str=[("alignItems", "center")],
        )
        bind_bg(b, fn() { theme_info_light() })
        b.on_draw(fn(p) {
          let bd = ViewLike::get_bounds(b)
          // ‹/› 矢量三角(字形图标跨平台发虚,GTK align 亦无效)
          if to_right {
            draw_glyph_right(p, bd.width / 2.0, bd.height / 2.0, 4.0, theme_text_regular())
          } else {
            draw_glyph_left(p, bd.width / 2.0, bd.height / 2.0, 4.0, theme_text_regular())
          }
        })
        View::set_cursor(b, hand())
        ViewLike::on_mouse_down(b, fn(e) {
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
      mid_btn(true)
      mid_btn(false)
      row.add_child(right_box)
      render_all()
      attach(parent, ViewLike::view(row))
      ViewLike::view(row)
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
/// 日期比较:负 = a 早于 b,0 = 同一天,正 = a 晚于 b。
fn date_cmp(a : DateYMD, b : DateYMD) -> Int {
  if a.y != b.y {
    a.y - b.y
  } else if a.m != b.m {
    a.m - b.m
  } else {
    a.d - b.d
  }
}

///|
fn date_eq(a : DateYMD, b : DateYMD) -> Bool {
  date_cmp(a, b) == 0
}

///|
/// d 是否落在 [s, e] 闭区间内(s/e 顺序不限,内部归一)。
fn date_in_range(d : DateYMD, s : DateYMD, e : DateYMD) -> Bool {
  let (lo, hi) = if date_cmp(s, e) <= 0 { (s, e) } else { (e, s) }
  date_cmp(d, lo) >= 0 && date_cmp(d, hi) <= 0
}

///|
/// 时间值(时 0-23 / 分 0-59;区间/日期时间选择的组成部分)。
pub(all) struct TimeHM {
  h : Int
  m : Int
}

///|
/// 时间比较:负 = a 早于 b,0 = 相同,正 = a 晚于 b。
pub fn TimeHM::compare(a : TimeHM, b : TimeHM) -> Int {
  a.h * 60 + a.m - (b.h * 60 + b.m)
}

///|
/// 格式化为 HH:MM(不足两位补零)。
pub fn TimeHM::format(self : TimeHM) -> String {
  fn two(n : Int) -> String {
    if n < 10 {
      "0\{n}"
    } else {
      n.to_string()
    }
  }

  "\{two(self.h)}:\{two(self.m)}"
}

///|
/// 钳制到合法时间(h 0-23 / m 0-59)。
fn time_clamp(h : Int, m : Int) -> TimeHM {
  let hc = if h < 0 { 0 } else if h > 23 { 23 } else { h }
  let mc = if m < 0 { 0 } else if m > 59 { 59 } else { m }
  { h: hc, m: mc }
}

///|
/// 日期区间值(起点/终点各自可为空:选择过程的中间态)。
pub(all) struct DateRange {
  start : DateYMD?
  end : DateYMD?
}

///|
/// 时间区间值。
pub(all) struct TimeRange {
  start : TimeHM?
  end : TimeHM?
}

///|
/// 日期时间区间值(日期对 + 各自时:分)。
pub(all) struct DateTimeRange {
  start : (DateYMD, TimeHM)?
  end : (DateYMD, TimeHM)?
}

///|
/// 格子状态:普通 / 单选选中 / 区间端点 / 区间中间(浅蓝底)。
priv enum CalCell {
  Plain
  Selected
  RangeEdge
  InRange
}

///|
/// 构建自绘日历面板(头部 ‹/› 导航 + 星期行 + 42 格月网格),日历家族
/// (calendar_t / date_picker_t / 区间选择器)共用。选中语义外置:
/// state_of 决定每格画法(单选方块/区间端点/区间中浅底),on_cell 收
/// 点击;on_cell 返回后全格重绘。返回面板与「按当前状态重建网格」函数
/// (外部改状态后手动调用刷新)。
fn build_calendar(
  today : DateYMD,
  state_of : (DateYMD) -> CalCell,
  on_cell : (DateYMD) -> Unit,
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
    let b = ViewLike::get_bounds(panel)
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
  // 月标题水平居中:GTK 端 align 无效,绘制时测宽手动摆位
  title.on_draw(fn(p) {
    let b = ViewLike::get_bounds(title)
    let probe = AttributedText::new(title_text.val, wrap=false)
    probe.set_font(Font::new("Sans", 14.0, weight=SemiBold))
    let tw = probe.get_bounds_for(10000.0, 1000.0).width
    p.draw_text(
      title_text.val,
      (b.width - tw) / 2.0,
      0.0,
      b.width,
      b.height,
      valign=Center,
      color=theme_text_primary(),
    )
  })
  fn nav_btn(glyph : String, on_click : () -> Unit) -> Container {
    let hover = Ref(false)
    let b = themed_container(style=[("width", 28.0), ("height", head_h)])
    let to_left = glyph == "‹"
    b.on_draw(fn(p) {
      let bb = ViewLike::get_bounds(b)
      if hover.val {
        p.set_fill_color(theme_fill_hover())
        p.fill_rect(0.0, 0.0, bb.width, bb.height)
      }
      // ‹/› 矢量三角(字形图标跨平台发虚,GTK align 亦无效)
      if to_left {
        draw_glyph_left(p, bb.width / 2.0, bb.height / 2.0, 4.0, theme_text_regular())
      } else {
        draw_glyph_right(p, bb.width / 2.0, bb.height / 2.0, 4.0, theme_text_regular())
      }
    })
    ViewLike::on_mouse_enter(b, fn(_e) {
      hover.val = true
      ViewLike::schedule_paint(b)
    })
    ViewLike::on_mouse_leave(b, fn(_e) {
      hover.val = false
      ViewLike::schedule_paint(b)
    })
    View::set_cursor(b, hand())
    ViewLike::on_mouse_down(b, fn(e) {
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
      let b = ViewLike::get_bounds(c)
      draw_center(p, wref, 0.0, b.height, theme_text_secondary())
    })
    wk.add_child(c)
  }
  let grid = themed_container(style_str=[("flexDirection", "column")])
  // 42 格一次性创建、永不增删:实测弹层窗口 map 过之后再加进来的行
  // 不会被绘制(同面板一次创建的标题/星期行始终正常,增删过的格子
  // 消失且导航重建也不恢复)——rebuild 只改每格数据+重绘
  let cells : Ref[Array[Container]] = Ref([])
  let cell_date : Ref[Array[Ref[DateYMD]]] = Ref([])
  let cell_inm : Ref[Array[Ref[Bool]]] = Ref([])
  {
    for _row in 0..<6 {
      let r = themed_container(style_str=[("flexDirection", "row")])
      for _col in 0..<7 {
        let dref : Ref[DateYMD] = Ref({ y: 0, m: 1, d: 1 })
        let inm : Ref[Bool] = Ref(false)
        let hover = Ref(false)
        let c = themed_container(style=[("width", cell_w), ("height", cell_h)])
        c.on_draw(fn(p) {
          let b = ViewLike::get_bounds(c)
          let d = dref.val
          let in_m = inm.val
          let st = state_of(d)
          let solid = match st {
            Selected | RangeEdge => true
            Plain | InRange => false
          }
          if hover.val && !solid {
            p.set_fill_color(theme_fill_hover())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
          match st {
            InRange => {
              p.set_fill_color(theme_primary_light())
              p.fill_rect(0.0, 0.0, b.width, b.height)
            }
            Plain | Selected | RangeEdge => ()
          }
          if solid {
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
            } else if st is InRange {
              theme_primary()
            } else {
              theme_text_primary()
            }
            draw_center(p, d.d.to_string(), 0.0, b.height, color)
          }
        })
        View::set_cursor(c, hand())
        // release 才选中:弹层内点项一律 release 防穿透;
        // calendar_t 内联面板同语义无副作用(松开选中,标准按钮感)。
        // 跨月格不可选(inm 校验在回调内,格子稳定不随月重建)
        ViewLike::on_mouse_up(c, fn(e) {
          if e.button == 1 && inm.val {
            on_cell(dref.val)
            for cc in cells.val {
              ViewLike::schedule_paint(cc)
            }
            true
          } else {
            false
          }
        })
        ViewLike::on_mouse_enter(c, fn(_e) {
          hover.val = true
          ViewLike::schedule_paint(c)
        })
        ViewLike::on_mouse_leave(c, fn(_e) {
          hover.val = false
          ViewLike::schedule_paint(c)
        })
        r.add_child(c)
        cells.val.push(c)
        cell_date.val.push(dref)
        cell_inm.val.push(inm)
      }
      grid.add_child(r)
    }
  }

  fn rebuild_grid() -> Unit {
    let y = view_y.val
    let m = view_m.val
    title_text.val = "\{y} 年 \{m} 月"
    ViewLike::schedule_paint(title)
    let first_wd = date_weekday(y, m, 1)
    let dim = date_days_in_month(y, m)
    let dim_prev = date_days_in_month(
      if m == 1 { y - 1 } else { y },
      if m == 1 { 12 } else { m - 1 },
    )
    for idx in 0..<42 {
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
      cell_date.val[idx].val = { y: dy, m: dm, d: dd }
      cell_inm.val[idx].val = in_month
      ViewLike::schedule_paint(cells.val[idx])
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
      let (panel, refresh) = build_calendar(today, fn(d) {
        match sel.val {
          Some(s) => if date_eq(s, d) { Selected } else { Plain }
          None => Plain
        }
      }, fn(d) {
        sel.val = Some(d)
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
      attach(parent, ViewLike::view(panel))
      ViewLike::view(panel)
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
      // 弹层与面板:首开时创建,面板重建函数挂入 grid_refresh 供外部同步
      let pop : Ref[Popover?] = Ref(None)
      let grid_refresh : Ref[() -> Unit] = Ref(fn() {  })
      let field = build_picker_field(width, text, has_val, clearable, on_focus_changed=fn(f) {
        if !f {
          match pop.val {
            Some(p) => p.close()
            None => ()
          }
        }
      })
      fn apply_date(d : DateYMD) -> Unit {
        sel.val = Some(d)
        text.val = d.format()
        has_val.val = true
        ViewLike::schedule_paint(field)
        match value {
          Some(s) => s.set(Some(d))
          None => ()
        }
        on_change(d)
      }

      ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          ViewLike::focus(field)
          // 清空带(箭头左侧)优先:清空日期,不弹日历
          if picker_clear_hit(field, e, clearable, has_val.val) {
            sel.val = None
            text.val = placeholder
            has_val.val = false
            match value {
              Some(s) => s.set(None)
              None => ()
            }
            ViewLike::schedule_paint(field)
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              bind_popover_bg(p)
              let (panel, refresh) = build_calendar(today, fn(d) {
                match sel.val {
                  Some(s) => if date_eq(s, d) { Selected } else { Plain }
                  None => Plain
                }
              }, fn(d) {
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
            ViewLike::schedule_paint(field)
            ((grid_refresh.val))()
          })
        None => ()
      }
      attach(parent, ViewLike::view(field))
      ViewLike::view(field)
    },
  }
}

///|
/// 选择器家族共用的输入框样式字段(date_picker_t 与区间选择器):
/// 边框(聚焦变主题色)+ 文本(有值主色/无值次色)+ 右侧下拉小箭头,
/// clearable=true 悬停且有值时箭头左侧显示 ✕。焦点/悬停态内部管理;
/// 聚焦变化回调 on_focus_changed(弹层随失焦关闭挂这里),点击行为
/// (弹层与清空)由调用方注册 on_mouse_up。
fn build_picker_field(
  width : Double,
  text : Ref[String],
  has_val : Ref[Bool],
  clearable : Bool,
  on_focus_changed? : (Bool) -> Unit = fn(_f) {  },
) -> Container {
  let fnt = Font::new("Sans", 13.0)
  let hover = Ref(false)
  let focused = Ref(false)
  let field = themed_container(
    style=[("width", width), ("height", control_height), ("marginBottom", 10.0)],
    style_str=[("flexDirection", "row"), ("alignItems", "center")],
  )
  set_panel_bg(field)
  View::set_cursor(field, hand())
  field.on_draw(fn(p) {
    let b = ViewLike::get_bounds(field)
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
  ViewLike::set_focusable(field, true)
  ViewLike::on_focus_in(field, fn() {
    focused.val = true
    ViewLike::schedule_paint(field)
    on_focus_changed(true)
    false
  })
  ViewLike::on_focus_out(field, fn() {
    focused.val = false
    ViewLike::schedule_paint(field)
    on_focus_changed(false)
    false
  })
  ViewLike::on_mouse_enter(field, fn(_e) {
    hover.val = true
    ViewLike::schedule_paint(field)
  })
  ViewLike::on_mouse_leave(field, fn(_e) {
    hover.val = false
    ViewLike::schedule_paint(field)
  })
  field
}

///|
/// 点击是否落在字段清空带(下拉箭头左侧的 ✕ 区域)。
fn picker_clear_hit(
  field : Container,
  e : MouseEvent,
  clearable : Bool,
  has_val : Bool,
) -> Bool {
  if !(clearable && has_val) {
    return false
  }
  let b = ViewLike::get_bounds(field)
  e.view_x >= b.width - 40.0 && e.view_x <= b.width - 20.0
}

///|
/// 区间日历的格子状态映射:两端点实心方块,闭区间内浅蓝底。
fn range_state_of(
  start : Ref[DateYMD?],
  end : Ref[DateYMD?],
) -> (DateYMD) -> CalCell {
  fn state_of(d : DateYMD) -> CalCell {
    match (start.val, end.val) {
      (Some(s), Some(e)) => {
        if date_eq(d, s) || date_eq(d, e) {
          RangeEdge
        } else if date_in_range(d, s, e) {
          InRange
        } else {
          Plain
        }
      }
      (Some(s), None) => if date_eq(d, s) { RangeEdge } else { Plain }
      (None, None) | (None, Some(_)) => Plain
    }
  }

  state_of
}

///|
/// 区间两段式点击:尚无区间 → 写起点;只有起点 → 写终点(终点早于起点
/// 自动对调)并回调 on_done;已有完整区间再点 → 重新从新起点开始。
fn range_cell_click(
  start : Ref[DateYMD?],
  end : Ref[DateYMD?],
  d : DateYMD,
  on_done : (DateYMD, DateYMD) -> Unit,
) -> Unit {
  match (start.val, end.val) {
    (Some(_), Some(_)) => {
      start.val = Some(d)
      end.val = None
    }
    (Some(s), None) => {
      let (a, b) = if date_cmp(d, s) < 0 { (d, s) } else { (s, d) }
      start.val = Some(a)
      end.val = Some(b)
      on_done(a, b)
    }
    (None, None) | (None, Some(_)) => {
      start.val = Some(d)
      end.val = None
    }
  }
}

///|
/// 一行「时:分」编辑器(标签 + 时 0-23 / 分 0-59 两个 input_number):
/// 任一步进写回 hm 并回调 on_change;sync 供外部值变化时回填步进器
/// 显示,回填期间置 mute=true 避免回环触发 on_change。
fn build_time_row(
  label : String,
  hm : Ref[TimeHM],
  mute : Ref[Bool],
  on_change : () -> Unit,
) -> (Node, (TimeHM) -> Unit) {
  let hs : Store[Double] = Store::new(hm.val.h.to_double())
  let ms : Store[Double] = Store::new(hm.val.m.to_double())
  hs.subscribe(fn(v) {
    hm.val = time_clamp(v.round().to_int(), hm.val.m)
    if !mute.val {
      on_change()
    }
  })
  ms.subscribe(fn(v) {
    hm.val = time_clamp(hm.val.h, v.round().to_int())
    if !mute.val {
      on_change()
    }
  })
  let row = hbox(
    [
      label_t(label, role=Body, style=[("width", 28.0), ("marginRight", 6.0)]),
      input_number(hs, min=0.0, max=23.0, step=1.0, num_width=40.0),
      label_t(":", role=Body),
      input_number(ms, min=0.0, max=59.0, step=1.0, num_width=40.0),
    ],
    style=[("marginBottom", 6.0)],
    style_str=[("alignItems", "center")],
  )
  fn sync(t : TimeHM) -> Unit {
    mute.val = true
    hs.set(t.h.to_double())
    ms.set(t.m.to_double())
    mute.val = false
  }

  (row, sync)
}

///|
/// 弹层内的起/止两行时间编辑面板;sync(起, 止) 回填两行显示(mute
/// 包裹,不触发 on_change),mute 供调用方在程序化写值期间整体静音。
fn build_time_panel(
  start_hm : Ref[TimeHM],
  end_hm : Ref[TimeHM],
  on_change : () -> Unit,
) -> (Container, (TimeHM, TimeHM) -> Unit, Ref[Bool]) {
  let mute = Ref(false)
  let (row1, sync1) = build_time_row("起", start_hm, mute, on_change)
  let (row2, sync2) = build_time_row("止", end_hm, mute, on_change)
  let panel = themed_container(
    style=[
      // 显式总高:PopoverRootView 按 content_size 硬分配,不读内容自然
      // 高度,漏显式高度会把两行压塌(高 = 上下 padding 16 + 两行 x 36)
      ("padding", 8.0),
      ("width", 268.0),
      ("height", 16.0 + 2.0 * 36.0),
    ],
    style_str=[("flexDirection", "column")],
  )
  set_panel_bg(panel)
  let _ = row1.mount_into(panel.view())
  let _ = row2.mount_into(panel.view())
  fn sync(s : TimeHM, e : TimeHM) -> Unit {
    sync1(s)
    sync2(e)
  }

  (panel, sync, mute)
}

///|
/// 日期区间选择器(EP DateRangePicker,全自绘):字段显示「起 ~ 止」,
/// 点击弹区间日历——第一次点选起点,第二次点选终点(终点早于起点自动
/// 对调)后收起,回调 on_change(起, 止);再点字段重新开始新区间。
/// clearable=true 清空两端(value 置全空,on_change 不因清空触发)。
pub fn date_range_picker_t(
  value? : Store[DateRange],
  on_change? : (DateYMD, DateYMD) -> Unit = fn(_s, _e) {  },
  width? : Double = 260.0,
  placeholder? : String = "请选择日期区间",
  clearable? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let today = local_date()
      let pop : Ref[Popover?] = Ref(None)
      let start : Ref[DateYMD?] = Ref(match value {
        Some(v) => v.get().start
        None => None
      })
      let end : Ref[DateYMD?] = Ref(match value {
        Some(v) => v.get().end
        None => None
      })
      let text = Ref("")
      let has_val = Ref(false)
      let grid_refresh : Ref[() -> Unit] = Ref(fn() {  })
      let field = build_picker_field(width, text, has_val, clearable, on_focus_changed=fn(f) {
        if !f {
          match pop.val {
            Some(p) => p.close()
            None => ()
          }
        }
      })
      fn refresh_text() -> Unit {
        match (start.val, end.val) {
          (Some(s), Some(e)) => {
            text.val = "\{s.format()} ~ \{e.format()}"
            has_val.val = true
          }
          (Some(s), None) => {
            text.val = "\{s.format()} ~"
            has_val.val = true
          }
          (None, None) | (None, Some(_)) => {
            text.val = placeholder
            has_val.val = false
          }
        }
        ViewLike::schedule_paint(field)
      }

      fn write_value(s : DateYMD?, e : DateYMD?) -> Unit {
        match value {
          Some(v) => v.set({ start: s, end: e })
          None => ()
        }
      }

      ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          ViewLike::focus(field)
          if picker_clear_hit(field, e, clearable, has_val.val) {
            start.val = None
            end.val = None
            write_value(None, None)
            refresh_text()
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              bind_popover_bg(p)
              let (panel, refresh) = build_calendar(today, range_state_of(start, end), fn(d) {
                range_cell_click(start, end, d, fn(a, b) {
                  refresh_text()
                  write_value(Some(a), Some(b))
                  on_change(a, b)
                  p.close()
                })
                refresh_text()
              })
              grid_refresh.val = refresh
              refresh()
              p.set_content(panel)
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
        Some(v) =>
          v.subscribe(fn(r) {
            start.val = r.start
            end.val = r.end
            refresh_text()
            ((grid_refresh.val))()
          })
        None => ()
      }
      refresh_text()
      attach(parent, ViewLike::view(field))
      ViewLike::view(field)
    },
  }
}

///|
/// 时间区间选择器(EP TimeRangePicker,全自绘):字段显示「起:止」
/// 时:分,点击弹起/止两行步进编辑器(时 0-23 / 分 0-59),步进即改
/// 即回调 on_change;起止默认 00:00,弹层随字段失焦收起。clearable
/// 清空两端(重开弹层后步进即重新写入)。
pub fn time_range_picker_t(
  value? : Store[TimeRange],
  on_change? : (TimeHM, TimeHM) -> Unit = fn(_s, _e) {  },
  width? : Double = 180.0,
  placeholder? : String = "请选择时间区间",
  clearable? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let pop : Ref[Popover?] = Ref(None)
      let start = Ref(time_clamp(0, 0))
      let end = Ref(time_clamp(0, 0))
      let touched = Ref(false) // 弹层内动过步进才视为有值
      let text = Ref("")
      let has_val = Ref(false)
      let field = build_picker_field(width, text, has_val, clearable, on_focus_changed=fn(f) {
        if !f {
          match pop.val {
            Some(p) => p.close()
            None => ()
          }
        }
      })
      fn refresh_text() -> Unit {
        if has_val.val {
          text.val = "\{start.val.format()} ~ \{end.val.format()}"
        } else {
          text.val = placeholder
        }
        ViewLike::schedule_paint(field)
      }

      fn write_value(s : TimeHM, e : TimeHM) -> Unit {
        match value {
          Some(v) => v.set({ start: Some(s), end: Some(e) })
          None => ()
        }
      }

      ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          ViewLike::focus(field)
          if picker_clear_hit(field, e, clearable, has_val.val) {
            touched.val = false
            has_val.val = false
            match value {
              Some(v) => v.set({ start: None, end: None })
              None => ()
            }
            refresh_text()
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              bind_popover_bg(p)
              let (panel, _sync, _mute) = build_time_panel(start, end, fn() {
                if !touched.val {
                  touched.val = true
                  has_val.val = true
                }
                refresh_text()
                write_value(start.val, end.val)
                on_change(start.val, end.val)
              })
              p.set_content(panel)
              // 高 = 时间面板 88(+4 余量)
              p.set_content_size(268.0, 92.0)
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
        Some(v) =>
          v.subscribe(fn(r) {
            match (r.start, r.end) {
              (Some(s), Some(e)) => {
                start.val = s
                end.val = e
                touched.val = true
                has_val.val = true
              }
              (_, _) => {
                touched.val = false
                has_val.val = false
              }
            }
            refresh_text()
          })
        None => ()
      }
      refresh_text()
      attach(parent, ViewLike::view(field))
      ViewLike::view(field)
    },
  }
}

///|
/// 日期时间区间选择器(EP DateTimeRangePicker,全自绘):字段显示
/// 「起日期 起:分 ~ 止日期 止:分」,点击弹区间日历 + 底部起/止两行
/// 时间步进;日期两段式选完或时间步进后,区间完整即回调 on_change
/// (起日期, 起时间, 止日期, 止时间);「完成」按钮或字段失焦收起。
pub fn datetime_range_picker_t(
  value? : Store[DateTimeRange],
  on_change? : (DateYMD, TimeHM, DateYMD, TimeHM) -> Unit = fn(_sd, _st, _ed, _et) {  },
  width? : Double = 340.0,
  placeholder? : String = "请选择日期时间区间",
  clearable? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let today = local_date()
      let pop : Ref[Popover?] = Ref(None)
      let start_d : Ref[DateYMD?] = Ref(match value {
        Some(v) =>
          match v.get().start {
            Some((d, _t)) => Some(d)
            None => None
          }
        None => None
      })
      let end_d : Ref[DateYMD?] = Ref(match value {
        Some(v) =>
          match v.get().end {
            Some((d, _t)) => Some(d)
            None => None
          }
        None => None
      })
      let start_t = Ref(match value {
        Some(v) =>
          match v.get().start {
            Some((_d, t)) => t
            None => time_clamp(0, 0)
          }
        None => time_clamp(0, 0)
      })
      let end_t = Ref(match value {
        Some(v) =>
          match v.get().end {
            Some((_d, t)) => t
            None => time_clamp(0, 0)
          }
        None => time_clamp(0, 0)
      })
      let text = Ref("")
      let has_val = Ref(false)
      let time_sync : Ref[(TimeHM, TimeHM) -> Unit] = Ref(fn(_st, _et) {  })
      let grid_refresh_d : Ref[() -> Unit] = Ref(fn() {  })
      let field = build_picker_field(width, text, has_val, clearable, on_focus_changed=fn(f) {
        if !f {
          match pop.val {
            Some(p) => p.close()
            None => ()
          }
        }
      })
      fn refresh_text() -> Unit {
        match (start_d.val, end_d.val) {
          (Some(sd), Some(ed)) => {
            text.val = "\{sd.format()} \{start_t.val.format()} ~ \{ed.format()} \{end_t.val.format()}"
            has_val.val = true
          }
          (Some(sd), None) => {
            text.val = "\{sd.format()} \{start_t.val.format()} ~"
            has_val.val = true
          }
          (None, None) | (None, Some(_)) => {
            text.val = placeholder
            has_val.val = false
          }
        }
        ViewLike::schedule_paint(field)
      }

      fn write_value() -> Unit {
        match value {
          Some(v) => {
            let s : (DateYMD, TimeHM)? = match start_d.val {
              Some(d) => Some((d, start_t.val))
              None => None
            }
            let e : (DateYMD, TimeHM)? = match end_d.val {
              Some(d) => Some((d, end_t.val))
              None => None
            }
            v.set({ start: s, end: e })
          }
          None => ()
        }
      }

      fn emit() -> Unit {
        // 区间完整才对外回调;不完整只反映在 value 的中间态
        match (start_d.val, end_d.val) {
          (Some(sd), Some(ed)) => {
            write_value()
            on_change(sd, start_t.val, ed, end_t.val)
          }
          _ => write_value()
        }
      }

      ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          ViewLike::focus(field)
          if picker_clear_hit(field, e, clearable, has_val.val) {
            start_d.val = None
            end_d.val = None
            write_value()
            refresh_text()
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              bind_popover_bg(p)
              let (cal, refresh) = build_calendar(today, range_state_of(start_d, end_d), fn(d) {
                range_cell_click(start_d, end_d, d, fn(_a, _b) {
                  emit()
                })
                refresh_text()
              })
              let (tpanel, sync, _mute) = build_time_panel(start_t, end_t, fn() {
                emit()
                refresh_text()
              })
              time_sync.val = sync
              grid_refresh_d.val = refresh
              // 显式总宽高:PopoverRootView 按 content_size 硬分配,漏显式
              // 高度会把时间面板/完成行压塌
              let body = themed_container(
                style=[("width", 268.0), ("height", 258.0 + 1.0 + 88.0 + 32.0)],
                style_str=[("flexDirection", "column")],
              )
              body.add_child(cal)
              let sep = themed_container(style=[("height", 1.0)])
              sep.on_draw(fn(p2) {
                let b2 = ViewLike::get_bounds(sep)
                p2.set_stroke_color(theme_border())
                p2.stroke_rect(0.5, 0.5, b2.width - 1.0, 0.0)
              })
              body.add_child(sep)
              body.add_child(tpanel)
              let done_row = themed_container(
                style=[("height", 32.0), ("padding", 6.0)],
                style_str=[("flexDirection", "row"), ("alignItems", "center"), ("justifyContent", "flex-end")],
              )
              let _ = button_t("完成", variant=Solid, on_click=fn() {
                p.close()
              }).mount_into(done_row.view())
              body.add_child(done_row)
              p.set_content(body)
              // 高 = 日历面板 258 + 分隔 1 + 时间面板 88 + 完成行 32 = 379(+5 余量)
              p.set_content_size(268.0, 384.0)
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
        Some(v) =>
          v.subscribe(fn(r) {
            match r.start {
              Some((d, t)) => {
                start_d.val = Some(d)
                start_t.val = t
              }
              None => start_d.val = None
            }
            match r.end {
              Some((d, t)) => {
                end_d.val = Some(d)
                end_t.val = t
              }
              None => end_d.val = None
            }
            (time_sync.val)(start_t.val, end_t.val)
            refresh_text()
            ((grid_refresh_d.val))()
          })
        None => ()
      }
      refresh_text()
      attach(parent, ViewLike::view(field))
      ViewLike::view(field)
    },
  }
}

///|
/// 表格列定义(EP Table):标题 + 宽度(<=0 为弹性列,均分剩余宽)
/// + 单元格文字对齐 + 是否可排序(表头点击切换升降序)。
pub(all) struct TableColumn {
  title : String
  width : Double
  align : TextAlign
  sortable : Bool
}

///|
/// 创建列定义(align 默认左对齐,sortable 默认可排序)。
pub fn TableColumn::make(
  title : String,
  width : Double,
  align? : TextAlign = Start,
  sortable? : Bool = true,
) -> TableColumn {
  { title, width, align, sortable }
}

///|
/// 表格排序状态(表头点击后写入):column 为参与排序的列号(列定义
/// 下标,与复选框列无关),<0 表示不排序;asc 为升序。经 [table_t] /
/// [table_v_t] 的 sort 参数传入——组件内切换状态并画箭头,使用方
/// 订阅 Store 自行排序数据后回写 rows。
pub(all) struct TableSort {
  column : Int
  asc : Bool
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
/// 排序箭头(表头):cx/cy 为中心,asc 升序尖端朝上;active=false 画
/// 浅色(可排序列的 hover 提示,不表示当前排序)。8x7 矢量三角,
/// 不依赖字体。
///|
/// 排序箭头(表头,实心三角):cx/cy 为中心,asc 升序尖端朝上;
/// active=false 画灰色(未排序列的常驻 ↕ 提示,不表示当前方向)。
/// 8x7 矢量三角,fill_rect 拼不出圆润边角时保留路径版——表头容器
/// (单一绘制器)路径填充实测正常,小单元格容器反而不渲染(见
/// adaptation.md),故表格表头装饰一律画在表头容器上。
fn draw_sort_triangle(
  p : Painter,
  cx : Double,
  cy : Double,
  asc : Bool,
  active : Bool,
) -> Unit {
  p.set_fill_color(if active { theme_primary() } else { theme_border() })
  p.begin_path()
  if asc {
    p.move_to(cx - 4.0, cy + 2.0)
    p.line_to(cx + 4.0, cy + 2.0)
    p.line_to(cx, cy - 2.5)
  } else {
    p.move_to(cx - 4.0, cy - 2.0)
    p.line_to(cx + 4.0, cy - 2.0)
    p.line_to(cx, cy + 2.5)
  }
  p.close_path()
  p.fill()
}

///|
/// 排序提示(表头,未排序列):上下双三角(↕),灰色,常驻显示——
/// 用户看到就知道这列可点排序;排序列换实心主题色单向箭头。
fn draw_sort_hint(p : Painter, cx : Double, cy : Double) -> Unit {
  p.set_fill_color(theme_border())
  // 上三角(中心 cy-3)
  p.begin_path()
  p.move_to(cx - 3.5, cy - 0.5)
  p.line_to(cx + 3.5, cy - 0.5)
  p.line_to(cx, cy - 5.0)
  p.close_path()
  p.fill()
  // 下三角(中心 cy+3):底边在上、顶点朝下
  p.begin_path()
  p.move_to(cx - 3.5, cy + 1.0)
  p.line_to(cx + 3.5, cy + 1.0)
  p.line_to(cx, cy + 5.5)
  p.close_path()
  p.fill()
}

///|
/// 表格最小列宽(拖动钳制下限):再窄标题/数值不可读。
let min_col_width : Double = 56.0

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
/// 表头:sort(Store[TableSort])提供后排序列显示升降箭头,点击可排序
/// 列切换「新列升序 / 同列升降序」;列边界(表头右缘 4px)按住拖动
/// 调整列宽,相邻两列此消彼长(最小 min_col_width)。
pub fn table_t(
  columns : Array[TableColumn],
  rows : Store[Array[TableRow]],
  width? : Double = 560.0,
  row_height? : Double = 36.0,
  selection? : Store[Array[Int]],
  sort? : Store[TableSort],
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
      // 行内列单元格按 [行][列] 存(拖动列宽时逐行改样式,不重建树)
      let row_cols : Ref[Array[Array[Container]]] = Ref([])
      let data_r : Ref[Array[TableRow]] = Ref([])
      let head_h = 40.0
      // 1px 内边距让外框描边落在 padding 环里,不被行/表头背景盖住
      let outer = themed_container(
        style=[("width", width), ("padding", 1.0), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "column")],
      )
      // 列几何(含复选框列偏移):初值=定义宽,弹性列均分剩余宽;
      // 拖动改写本数组并回写各处 cell 样式
      let body_w = width - 2.0 - (if sel is Some(_) { 36.0 } else { 0.0 })
      let col_w : Array[Double] = []
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
      for col in columns {
        col_w.push(if col.width > 0.0 { col.width } else { flex_w })
      }
      // 排序/列宽拖动态:表头单元格(见 head_cell)点击排序,列边界
      // (单元格左/右缘 4px,两侧都认——对准可见边界按下,事件落左列
      // 右缘或右列左缘都能起拖)按住拖列宽。sort 缺省不画箭头、点击
      // 无效。表头装饰(箭头/边界线/高亮)统一画在 head 容器上:小
      // 单元格容器的路径填充在 GTK 上不渲染(实测,见 adaptation.md),
      // 表头容器单一绘制器正常,与 table_v_t 画布同模型。
      let head_cs : Ref[Array[Container]] = Ref([])
      let resizing = Ref(-1)
      let resize_start_x = Ref(0.0)
      let resize_w0 = Ref(0.0)
      let resize_w1 = Ref(0.0)
      // 悬停的列边界(左列号,-1 无):表头画高亮线 + 光标反馈用
      let boundary_hover = Ref(-1)
      // 列 x 偏移(含复选框列 36px):表头装饰定位用,与 col_w 同步
      let col_x : Array[Double] = []
      let mut acc_x = if sel is Some(_) { 36.0 } else { 0.0 }
      for j in 0..<col_w.length() {
        col_x.push(acc_x)
        acc_x = acc_x + col_w[j]
      }

      fn sort_cur_col() -> Int {
        match sort {
          Some(s) => s.get().column
          None => -1
        }
      }

      fn sort_cur_asc() -> Bool {
        match sort {
          Some(s) => s.get().asc
          None => true
        }
      }

      outer.on_draw(fn(p) {
        let b = ViewLike::get_bounds(outer)
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

      // 单元格:列宽一律读 col_w[j](弹性列的均分宽也在挂载时算入),
      // 左右各留 12px 内边距;拖动列宽后重建行即按新宽,行不重建时
      // 由 apply_col_widths 统一回写
      fn cell_view(
        content : TableCell,
        j : Int,
        fnt : Font,
        color_of : () -> String,
      ) -> Container {
        let col = columns[j]
        let base : Array[(String, Double)] = [
          ("width", col_w[j]), ("paddingLeft", 12.0), ("paddingRight", 12.0),
        ]
        let wrap = themed_container(
          style=base,
          style_str=[("flexDirection", "row"), ("alignItems", "center")],
        )
        match content {
          CellText(text) => {
            let l = Label::new(text)
            ViewLike::set_font(l, fnt)
            bind_fg(l, color_of)
            l.set_align(col.align)
            ViewLike::set_style(l, "flex", 1.0)
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
            ViewLike::set_font(l, small_font)
            bind_fg(l, color_of)
            l.set_align(col.align)
            ViewLike::set_style(l, "flex", 1.0)
            ViewLike::set_style(l, "marginLeft", 6.0)
            wrap.add_child(l)
          }
          CellLines(lines) => {
            let stack = themed_container(
              style=[("paddingTop", 6.0), ("paddingBottom", 6.0)],
              style_str=[("flexDirection", "column")],
            )
            for ln in lines {
              let l = Label::new(ln)
              ViewLike::set_font(l, small_font)
              bind_fg(l, fn() { theme_text_regular() })
              stack.add_child(l)
            }
            ViewLike::set_style(stack, "flex", 1.0)
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
        let b = ViewLike::get_bounds(head)
        p.set_fill_color(theme_fill_zebra())
        p.fill_rect(0.0, 0.0, b.width, b.height)
        p.set_stroke_color(theme_border())
        p.begin_path()
        p.move_to(0.0, b.height - 0.5)
        p.line_to(b.width, b.height - 0.5)
        p.stroke()
        // 列边界线(常驻浅色,悬停/拖动变主题色):拖动位置一眼可辨
        for j in 0..<(columns.length() - 1) {
          let hot = resizing.val == j || boundary_hover.val == j
          p.set_stroke_color(if hot { theme_primary() } else { theme_border() })
          let ex = col_x[j] + col_w[j]
          p.begin_path()
          p.move_to(ex, 6.0)
          p.line_to(ex, b.height - 6.0)
          p.stroke()
        }
        // 排序箭头:排序列实心主题色单向箭头;可排序列未排序时常驻
        // 灰色 ↕ 提示(用户看得知可点);sort 缺省全不画
        if sort is Some(_) {
          for j in 0..<columns.length() {
            if !columns[j].sortable {
              continue
            }
            let cx = col_x[j] + col_w[j] - 11.0
            if sort_cur_col() == j {
              draw_sort_triangle(p, cx, head_h / 2.0, sort_cur_asc(), true)
            } else {
              draw_sort_hint(p, cx, head_h / 2.0)
            }
          }
        }
      })
      // 表头复选框(仅 selection 启用时):全选 / 清空,部分选中画横条
      let head_cb = themed_container(style=[("width", 36.0), ("height", head_h)])
      head_cb.on_draw(fn(p) {
        let b = ViewLike::get_bounds(head_cb)
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
      ViewLike::on_mouse_down(head_cb, fn(e) {
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
      // 表头点击三态循环:新列默认升序 → 同列翻转 → 再击取消排序
      // (column 置 -1,使用方订阅里恢复原始顺序);sort 缺省点击无效
      fn toggle_sort(j : Int) -> Unit {
        match sort {
          Some(s) => {
            let cur = s.get()
            if cur.column == j {
              if cur.asc {
                s.set({ column: j, asc: false })
              } else {
                s.set({ column: -1, asc: true })
              }
            } else {
              s.set({ column: j, asc: true })
            }
          }
          None => ()
        }
      }

      // 起拖:记录起点窗口坐标与相邻两列宽,捕获鼠标
      fn begin_resize(j : Int, wx : Double) -> Unit {
        resizing.val = j
        resize_start_x.val = wx
        resize_w0.val = col_w[j]
        resize_w1.val = col_w[j + 1]
      }

      // 列宽回写:相邻两列此消彼长(总宽不变),表头 + 全部行单元格
      // 同步改样式后重排,并重算 col_x 供表头装饰定位;行本身不重建,
      // 选择/hover 状态不丢。
      // GTK 上 update_layout 只重排「调用节点及其父下的兄弟」:对根
      // 调用子树不刷新(探针实测 bounds 不变),对单个叶子调用只影响
      // 其所在行——被改样式的容器必须逐个调用(splitter 对唯一包装
      // 容器调,等价于此处的逐容器)。
      fn apply_col_widths(j : Int) -> Unit {
        ViewLike::set_style(head_cs.val[j], "width", col_w[j])
        ViewLike::set_style(head_cs.val[j + 1], "width", col_w[j + 1])
        for cells in row_cols.val {
          ViewLike::set_style(cells[j], "width", col_w[j])
          ViewLike::set_style(cells[j + 1], "width", col_w[j + 1])
        }
        let mut a = if sel is Some(_) { 36.0 } else { 0.0 }
        for k in 0..<col_w.length() {
          col_x[k] = a
          a = a + col_w[k]
        }
        ViewLike::update_layout(head_cs.val[j])
        ViewLike::update_layout(head_cs.val[j + 1])
        for cells in row_cols.val {
          ViewLike::update_layout(cells[j])
          ViewLike::update_layout(cells[j + 1])
        }
      }

      // 表头单元格:只放文字 Label(平台布局对齐,勿手动摆位)与事件;
      // 箭头 / 边界线 / 高亮一律画在 head 容器(见 head.on_draw),
      // 小单元格容器路径填充在 GTK 不渲染(实测,见 adaptation.md)。
      // 排序点击与列宽拖动共用本容器:右缘 4px 拖 (j, j+1) 边界,
      // 左缘 4px 拖 (j-1, j) 边界——对准可见边界按下,事件落左列
      // 右缘或右列左缘都能起拖(此前只认右缘,对准边界按常落到下一
      // 列左缘变成排序,拖不动)。
      fn head_cell(j : Int) -> Container {
        let col = columns[j]
        // 可排序列右侧留 22px 箭头区(标题不跳动)
        let pad_r = if col.sortable { 22.0 } else { 12.0 }
        let cell = themed_container(
          style=[
            ("width", col_w[j]), ("paddingLeft", 12.0), ("paddingRight", pad_r),
          ],
          style_str=[("flexDirection", "row"), ("alignItems", "center")],
        )
        let l = Label::new(col.title)
        ViewLike::set_font(l, head_font)
        bind_fg(l, fn() { theme_text_secondary() })
        l.set_align(col.align)
        ViewLike::set_style(l, "flex", 1.0)
        cell.add_child(l)
        let near_edge = Ref(false)
        View::set_cursor(cell, hand())
        // 悬停:靠近任一边界给 ResizeEW 光标 + 表头画高亮线
        ViewLike::on_mouse_move(cell, fn(e) {
          if resizing.val >= 0 {
            let jr = resizing.val
            let d = e.window_x - resize_start_x.val
            let total = resize_w0.val + resize_w1.val
            let mut w0 = resize_w0.val + d
            let mut w1 = resize_w1.val - d
            if w0 < min_col_width {
              w0 = min_col_width
              w1 = total - w0
            }
            if w1 < min_col_width {
              w1 = min_col_width
              w0 = total - w1
            }
            col_w[jr] = w0
            col_w[jr + 1] = w1
            apply_col_widths(jr)
          } else {
            let b = ViewLike::get_bounds(cell)
            // 右缘 → (j, j+1) 边界;左缘 → (j-1, j) 边界;末列右缘不设
            let edge = if j + 1 < columns.length() && e.view_x >= b.width - 4.0 {
              j
            } else if j - 1 >= 0 && e.view_x <= 4.0 {
              j - 1
            } else {
              -1
            }
            if edge != boundary_hover.val {
              boundary_hover.val = edge
              ViewLike::schedule_paint(head)
            }
            let near = edge >= 0
            if near != near_edge.val {
              near_edge.val = near
              View::set_cursor(cell, Cursor::new(if near { ResizeEW } else { Hand }))
            }
          }
        })
        ViewLike::on_mouse_down(cell, fn(e) {
          if e.button != 1 {
            return false
          }
          let b = ViewLike::get_bounds(cell)
          let edge = if j + 1 < columns.length() && e.view_x >= b.width - 4.0 {
            j
          } else if j - 1 >= 0 && e.view_x <= 4.0 {
            j - 1
          } else {
            -1
          }
          if edge >= 0 {
            begin_resize(edge, e.window_x)
            ViewLike::set_capture(cell)
            true
          } else {
            if col.sortable {
              toggle_sort(j)
              ViewLike::schedule_paint(head)
            }
            false
          }
        })
        ViewLike::on_mouse_up(cell, fn(_e) {
          if resizing.val >= 0 {
            resizing.val = -1
            ViewLike::release_capture(cell)
            ViewLike::schedule_paint(head)
            true
          } else {
            false
          }
        })
        // 光标离开边界区:复位光标与高亮
        ViewLike::on_mouse_leave(cell, fn(_e) {
          if boundary_hover.val != -1 {
            boundary_hover.val = -1
            ViewLike::schedule_paint(head)
          }
          if near_edge.val {
            near_edge.val = false
            View::set_cursor(cell, hand())
          }
        })
        cell
      }

      match sel {
        Some(_) => head.add_child(head_cb)
        None => ()
      }
      for j in 0..<columns.length() {
        let hc = head_cell(j)
        head_cs.val.push(hc)
        head.add_child(hc)
      }
      let body = themed_container(style_str=[("flexDirection", "column")])

      fn refresh_row(i : Int) -> Unit {
        let cs = row_cs.val
        if i >= 0 && i < cs.length() {
          ViewLike::schedule_paint(cs[i])
        }
      }

      fn rebuild(data : Array[TableRow]) -> Unit {
        for v in row_cs.val {
          ignore(body.remove_child_view(ViewLike::view(v)))
        }
        row_cs.val = []
        row_cols.val = []
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
              let b = ViewLike::get_bounds(row)
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
                let b = ViewLike::get_bounds(cb)
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
          let cells : Array[Container] = []
          for j in 0..<columns.length() {
            let content = if j < r.cells.length() {
              r.cells[j]
            } else {
              CellText("")
            }
            let cv = cell_view(content, j, font, fn() {
              theme_text_regular()
            })
            cells.push(cv)
            row.add_child(cv)
          }
          row_cols.val.push(cells)
          ViewLike::on_mouse_enter(row, fn(_e) {
            hover_i.val = idx
            refresh_row(idx)
          })
          ViewLike::on_mouse_leave(row, fn(_e) {
            let prev = hover_i.val
            hover_i.val = -1
            refresh_row(prev)
          })
          View::set_cursor(row, hand())
          ViewLike::on_mouse_down(row, fn(e) {
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
        ViewLike::schedule_paint(head_cb)
      }

      rebuild(rows.get())
      rows.subscribe(rebuild)
      match sel {
        Some(s) =>
          s.subscribe(fn(_v) {
            for c in row_cs.val {
              ViewLike::schedule_paint(c)
            }
            ViewLike::schedule_paint(head_cb)
          })
        None => ()
      }
      // 排序状态变化:表头箭头重绘(数据排序由使用方订阅 Store 完成)
      match sort {
        Some(s) => s.subscribe(fn(_v) { ViewLike::schedule_paint(head) })
        None => ()
      }
      outer.add_child(head)
      outer.add_child(body)
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
    },
  }
}

///|
/// 虚拟滚动表格(table_t 的 L3 万行级形态):整面 canvas 自绘、只画可见行,
/// 自管滚动——滚轮(Linux 经 shim scroll-event)/拖拽滚动条/键盘,不受原生
/// 滚动容器的内容高度上限约束(X11 子窗口高度 65535,万行内容放不进
/// GtkViewport)。单元格画法与 table_t 一致(CellLines 在行高内最多画
/// 两行);selection 语义同 table_t(复选框列 + 表头全选)。
/// 表头:sort(Store[TableSort])提供后排序列显示升降箭头,点击可排序列
/// 切换「新列升序 / 同列升降序」;列边界(表头,±3px 命中)按住拖动调整
/// 列宽,相邻两列此消彼长(最小 min_col_width,末列边界不设把手)。
pub fn table_v_t(
  columns : Array[TableColumn],
  rows : Store[Array[TableRow]],
  width? : Double = 560.0,
  height? : Double = 360.0,
  row_height? : Double = 32.0,
  selection? : Store[Array[Int]],
  sort? : Store[TableSort],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i, _r) { },
  fill? : Bool = false,
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
      // 排序/列宽拖动态:resizing 为边界左列号,-1 无;head_hover 为
      // 悬停表头列号(-1 无);near_edge 光标是否已是 ResizeEW;
      // boundary_hover 为悬停列边界(左列号,-1 无),表头画高亮线
      let head_hover = Ref(-1)
      let near_edge = Ref(false)
      let boundary_hover = Ref(-1)
      let resizing = Ref(-1)
      let resize_start_x = Ref(0.0)
      let resize_w0 = Ref(0.0)
      let resize_w1 = Ref(0.0)
      let head_h = 40.0
      let bar_w = 10.0
      // 表体宽随实际视口宽(fill 模式跟随窗口伸缩),绘制与命中共用
      let body_w = Ref(width - bar_w)
      let vis_h = height - head_h
      // 复选框列占 36px(selection 启用时),列几何整体右移
      let col_x0 = if sel is Some(_) { 36.0 } else { 0.0 }
      // 列几何:固定宽直接用,弹性列均分剩余宽度;col_x 含复选框列偏移
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
        ((body_w.val - col_x0 - fixed) / flex_count.to_double()).max(0.0)
      } else {
        0.0
      }
      let col_x : Array[Double] = []
      let col_w : Array[Double] = []
      // 手动拖过宽度的列(含弹性列):此后退出弹性均分,按拖定的宽走,
      // 窗口伸缩也不再摊薄——否则每次 on_draw 的 relayout_body 会把
      // 弹性列重置回均分宽,拖动结果被当场抹掉(拖了没效果)
      let manual : Array[Bool] = []
      for _col in columns {
        manual.push(false)
      }
      let mut acc = col_x0
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

      fn relayout_cols() -> Unit {
        let mut a = col_x0
        for j in 0..<col_w.length() {
          col_x[j] = a
          a = a + col_w[j]
        }
      }

      // 列几何随实际宽度重排:固定列保留(可能被拖宽改过的)宽度,弹性
      // 列分摊剩余宽度。拖列宽两列此消彼长守恒,与弹性列重排不冲突。
      // 手动拖过的列(manual)视同固定列:计入 fixed_w、不参与均分,
      // 否则每次绘制都把弹性列重置回均分宽、拖动结果被抹掉。
      fn relayout_body(bw : Double) -> Unit {
        body_w.val = bw - bar_w
        if flex_count > 0 {
          let mut fixed_w = col_x0
          let mut flex_left = 0
          for j in 0..<col_w.length() {
            if columns[j].width > 0.0 || manual[j] {
              fixed_w = fixed_w + col_w[j]
            } else {
              flex_left = flex_left + 1
            }
          }
          let fw = if flex_left > 0 {
            ((body_w.val - fixed_w) / flex_left.to_double()).max(0.0)
          } else {
            0.0
          }
          for j in 0..<col_w.length() {
            if columns[j].width <= 0.0 && !manual[j] {
              col_w[j] = fw
            }
          }
        }
        relayout_cols()
      }

      // 列边界命中:x(画布坐标)距某条数据列右边界 3px 内返回左列号
      fn boundary_at(vx : Double) -> Int {
        for j in 0..<(col_w.length() - 1) {
          let edge = col_x[j] + col_w[j]
          if vx >= edge - 3.0 && vx <= edge + 3.0 {
            return j
          }
        }
        -1
      }

      // 命中列号:数据列(不含复选框列),越界 -1
      fn col_at(vx : Double) -> Int {
        for j in 0..<col_w.length() {
          if vx >= col_x[j] && vx < col_x[j] + col_w[j] {
            return j
          }
        }
        -1
      }

      fn sort_cur_col() -> Int {
        match sort {
          Some(s) => s.get().column
          None => -1
        }
      }

      fn sort_cur_asc() -> Bool {
        match sort {
          Some(s) => s.get().asc
          None => true
        }
      }

      // 表头点击三态循环:新列默认升序 → 同列翻转 → 再击取消排序
      // (column 置 -1,使用方订阅里恢复原始顺序);sort 缺省点击无效
      fn toggle_sort(j : Int) -> Unit {
        match sort {
          Some(s) => {
            let cur = s.get()
            if cur.column == j {
              if cur.asc {
                s.set({ column: j, asc: false })
              } else {
                s.set({ column: -1, asc: true })
              }
            } else {
              s.set({ column: j, asc: true })
            }
          }
          None => ()
        }
      }

      let size_style = if fill {
        [("height", height), ("marginBottom", 10.0)]
      } else {
        [("width", width), ("height", height), ("marginBottom", 10.0)]
      }
      let cv = themed_container(style=size_style)

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
      // 两侧统一留 12px。单行 + 超宽省略:默认换行会让长文本穿透定高
      // 行界(命令行动辄上百字符),排版截断由平台完成,不逐格测宽。
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
          wrap=false,
          ellipsis=true,
        )
      }

      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        relayout_body(b.width)
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
        // 列标题与箭头(边界线在行之后画,避免被斑马纹盖住)
        for j in 0..<columns.length() {
          // 可排序列右侧留 14px 箭头区(标题右界同步内收,排序切换时
          // 标题不跳动;数据行无箭头保持原样)
          let w_eff = col_w[j] - (if columns[j].sortable { 14.0 } else { 0.0 })
          draw_align_text(
            p,
            columns[j].title,
            columns[j].align,
            col_x[j],
            w_eff,
            0.0,
            head_h,
            theme_text_secondary(),
          )
          // 排序箭头:排列表实心主题色单向;可排序列未排序时常驻灰色 ↕
          if sort is Some(_) && columns[j].sortable {
            let cx = col_x[j] + col_w[j] - 14.0
            if sort_cur_col() == j {
              draw_sort_triangle(p, cx, head_h / 2.0, sort_cur_asc(), true)
            } else {
              draw_sort_hint(p, cx, head_h / 2.0)
            }
          }
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
            p.fill_rect(0.0, row_y, body_w.val, row_height)
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
                  x + 12.0 + (tag_w - tw) / 2.0,
                  ty,
                  tag_w,
                  20.0,
                  valign=Center,
                  color=type_color(t),
                  wrap=false,
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
                  wrap=false,
                )
              }
              CellLines(lines) => {
                // 行高内最多画两行,超出截断(虚拟滚动行高固定);
                // 单行不换行,超宽平台省略
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
                    wrap=false,
                    ellipsis=true,
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
        // 列边界线(常驻浅色,悬停/拖动变主题色):拖动位置一眼可辨。
        // 画在行之后——先前画在行之前,偶数行斑马纹 fill_rect 把线盖住,
        // 体感上「列分割线时有时无」
        for j in 0..<(columns.length() - 1) {
          let hot = resizing.val == j || boundary_hover.val == j
          p.set_stroke_color(if hot { theme_primary() } else { theme_border() })
          let ex = col_x[j] + col_w[j]
          p.begin_path()
          p.move_to(ex, 6.0)
          p.line_to(ex, head_h + vis_h - 6.0)
          p.stroke()
        }
        // 列宽拖动中的边界高亮线(表头到底,主题色 1px)
        if resizing.val >= 0 {
          let edge = col_x[resizing.val] + col_w[resizing.val]
          p.set_stroke_color(theme_primary())
          p.begin_path()
          p.move_to(edge, head_h)
          p.line_to(edge, b.height)
          p.stroke()
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
        ViewLike::schedule_paint(cv)
      }

      View::set_cursor(cv, hand())
      ViewLike::on_mouse_down(cv, fn(e) {
        if e.button != 1 {
          return false
        }
        let n = data_r.val.length()
        if e.view_x >= body_w.val && max_offset() > 0.0 {
          scroll_to_thumb(e.view_y)
          dragging.val = true
          ViewLike::set_capture(cv)
          return true
        }
        if e.view_y < head_h {
          // 列边界把手(表头 ±3px):按住拖列宽,不与排序点击冲突
          if e.view_x >= col_x0 {
            let jb = boundary_at(e.view_x)
            if jb >= 0 {
              resizing.val = jb
              resize_start_x.val = e.window_x
              resize_w0.val = col_w[jb]
              resize_w1.val = col_w[jb + 1]
              // 拖过即转固定:退出弹性均分,后续绘制/窗口伸缩保留拖定宽
              manual[jb] = true
              manual[jb + 1] = true
              ViewLike::set_capture(cv)
              ViewLike::schedule_paint(cv)
              return true
            }
          }
          if e.view_x < col_x0 {
            match sel {
              Some(_) => toggle_all()
              None => ()
            }
          } else {
            // 表头点击(把手外):可排序列切换升降序,组件内更新 sort
            let j = col_at(e.view_x)
            if j >= 0 && columns[j].sortable {
              toggle_sort(j)
            }
          }
          ViewLike::schedule_paint(cv)
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
        ViewLike::schedule_paint(cv)
        true
      })
      ViewLike::on_mouse_move(cv, fn(e) {
        if dragging.val {
          scroll_to_thumb(e.view_y)
          return
        }
        if resizing.val >= 0 {
          // 列宽拖动:相邻两列此消彼长,总宽不变,钳制最小宽
          let j = resizing.val
          let d = e.window_x - resize_start_x.val
          let total = resize_w0.val + resize_w1.val
          let mut w0 = resize_w0.val + d
          let mut w1 = resize_w1.val - d
          if w0 < min_col_width {
            w0 = min_col_width
            w1 = total - w0
          }
          if w1 < min_col_width {
            w1 = min_col_width
            w0 = total - w1
          }
          col_w[j] = w0
          col_w[j + 1] = w1
          relayout_cols()
          ViewLike::schedule_paint(cv)
          return
        }
        // 表头区:悬停列记录 + 边界把手光标 + 边界高亮线
        if e.view_y < head_h && e.view_x >= col_x0 {
          let bh = boundary_at(e.view_x)
          let near = bh >= 0
          if near != near_edge.val {
            near_edge.val = near
            View::set_cursor(cv, Cursor::new(if near { ResizeEW } else { Hand }))
          }
          if bh != boundary_hover.val {
            boundary_hover.val = bh
            ViewLike::schedule_paint(cv)
          }
          let hc = col_at(e.view_x)
          if hc != head_hover.val {
            head_hover.val = hc
            ViewLike::schedule_paint(cv)
          }
        } else {
          if near_edge.val {
            near_edge.val = false
            View::set_cursor(cv, hand())
          }
          if boundary_hover.val != -1 {
            boundary_hover.val = -1
            ViewLike::schedule_paint(cv)
          }
          if head_hover.val != -1 {
            head_hover.val = -1
            ViewLike::schedule_paint(cv)
          }
        }
        let n = data_r.val.length()
        let idx = ((e.view_y - head_h + offset.val) / row_height).to_int()
        let inside = e.view_x < body_w.val && e.view_y >= head_h
        let new_hover = if inside && idx >= 0 && idx < n {
          idx
        } else {
          -1
        }
        if new_hover != hover_i.val {
          hover_i.val = new_hover
          ViewLike::schedule_paint(cv)
        }
      })
      ViewLike::on_mouse_up(cv, fn(_e) {
        if dragging.val {
          dragging.val = false
          ViewLike::release_capture(cv)
          true
        } else if resizing.val >= 0 {
          resizing.val = -1
          ViewLike::release_capture(cv)
          true
        } else {
          false
        }
      })
      ViewLike::on_mouse_leave(cv, fn(_e) {
        if hover_i.val != -1 {
          hover_i.val = -1
          ViewLike::schedule_paint(cv)
        }
        if head_hover.val != -1 {
          head_hover.val = -1
          ViewLike::schedule_paint(cv)
        }
        if boundary_hover.val != -1 {
          boundary_hover.val = -1
          ViewLike::schedule_paint(cv)
        }
        if near_edge.val {
          near_edge.val = false
          View::set_cursor(cv, hand())
        }
      })
      ViewLike::on_wheel(cv, fn(delta) {
        offset.val = offset.val + delta * 60.0
        clamp_offset()
        ViewLike::schedule_paint(cv)
      })
      ViewLike::set_focusable(cv, true)
      ViewLike::on_key_down(cv, fn(e) {
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
        ViewLike::schedule_paint(cv)
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
        ViewLike::schedule_paint(cv)
      }

      load(rows.get())
      rows.subscribe(load)
      match sel {
        Some(s) => s.subscribe(fn(_v) { ViewLike::schedule_paint(cv) })
        None => ()
      }
      // 排序状态变化:表头箭头重绘(数据排序由使用方订阅 Store 完成)
      match sort {
        Some(s) => s.subscribe(fn(_v) { ViewLike::schedule_paint(cv) })
        None => ()
      }
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
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
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
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
  invalid? : Store[Bool] = Store::new(false),
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
        let b = ViewLike::get_bounds(outer)
        p.set_stroke_color(
          if invalid.get() {
            theme_danger()
          } else if focused.val {
            theme_focus_accent()
          } else {
            theme_border()
          },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        if clearable && hover.val && has_text.val {
          draw_clear_x(p, clear_x, b.height / 2.0)
        }
      })
      invalid.subscribe(fn(_v) { ViewLike::schedule_paint(outer) })
      let edit = TextEdit::new()
      edit.set_text(text)
      ViewLike::set_font(edit, Font::new("Sans", 13.0))
      ViewLike::set_borderless(edit, true)
      set_panel_bg(edit)
      ViewLike::set_style(edit, "flex", 1.0)
      if clearable {
        ViewLike::set_style(edit, "marginRight", 24.0)
      }
      edit.on_text_change(fn() {
        if clearable {
          has_text.val = edit.get_text() != ""
          ViewLike::schedule_paint(outer)
        }
        on_input(edit.get_text())
      })
      ViewLike::on_focus_in(edit, fn() {
        focused.val = true
        ViewLike::schedule_paint(outer)
        false
      })
      ViewLike::on_focus_out(edit, fn() {
        focused.val = false
        ViewLike::schedule_paint(outer)
        false
      })
      if clearable {
        ViewLike::on_mouse_enter(outer, fn(_e) {
          hover.val = true
          ViewLike::schedule_paint(outer)
        })
        ViewLike::on_mouse_leave(outer, fn(_e) {
          hover.val = false
          ViewLike::schedule_paint(outer)
        })
        ViewLike::on_mouse_up(outer, fn(e) {
          let b = ViewLike::get_bounds(outer)
          if e.button == 1 && has_text.val && e.view_x >= b.width - 32.0 {
            edit.set_text("")
            true
          } else {
            false
          }
        })
      }
      outer.add_child(edit)
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
  width? : Double = 0.0,
  on_change? : (Double) -> Unit = fn(_v) {  },
) -> Node {
  {
    mount: fn(parent) {
      let h = 24.0
      let track_h = 4.0
      let thumb = 12.0
      let dragging = Ref(false)
      let hover = Ref(false)
      // width<=0(缺省)flex 自适应父容器宽;显式正宽则定宽
      let size_style : Array[(String, Double)] = if width > 0.0 {
        [("width", width)]
      } else {
        [("flex", 1.0)]
      }
      size_style.push(("height", h))
      size_style.push(("marginBottom", 10.0))
      let v = themed_container(style=size_style)
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
        let w = ViewLike::get_bounds(v).width
        let r = clamp01((x - thumb / 2.0) / (w - thumb))
        value.set(quantize(min + r * (max - min)))
      }

      v.on_draw(fn(p) {
        let b = ViewLike::get_bounds(v)
        let w = b.width
        let ratio = ratio_of(value.get())
        let ty = (h - track_h) / 2.0
        // 轨道底用 border 灰:白底上的浅斑马纹几乎不可见,
        // 轨道必须整条可见才能读出滑杆长度
        p.set_fill_color(theme_border())
        p.fill_rect(0.0, ty, w, track_h)
        p.set_fill_color(theme_primary())
        p.fill_rect(0.0, ty, ratio * (w - thumb) + thumb / 2.0, track_h)
        // thumb:主题色实心方块,hover/拖拽加深
        let tx = ratio * (w - thumb)
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
      ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 {
          dragging.val = true
          ViewLike::set_capture(v)
          set_from_x(e.view_x)
          true
        } else {
          false
        }
      })
      ViewLike::on_mouse_move(v, fn(e) {
        if dragging.val {
          set_from_x(e.view_x)
        }
      })
      ViewLike::on_mouse_up(v, fn(_e) {
        if dragging.val {
          dragging.val = false
          ViewLike::release_capture(v)
          true
        } else {
          false
        }
      })
      ViewLike::on_mouse_enter(v, fn(_e) {
        hover.val = true
        ViewLike::schedule_paint(v)
      })
      ViewLike::on_mouse_leave(v, fn(_e) {
        hover.val = false
        ViewLike::schedule_paint(v)
      })
      ViewLike::on_focus_out(v, fn() {
        if dragging.val {
          dragging.val = false
          ViewLike::release_capture(v)
        }
        false
      })
      value.subscribe(fn(new_v) {
        on_change(new_v)
        ViewLike::schedule_paint(v)
      })
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
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
      // 宽度随父容器拉伸(列容器默认 stretch),不写死:概览页要放
      // 全宽图表;flex 让页区在父容器有确定高度时填充(Scroll 等无
      // measure 的叶节点靠这个拿到确定高度,否则塌缩归零)
      let outer = themed_container(
        style=[("flex", 1.0), ("marginBottom", 10.0)],
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
          let b = ViewLike::get_bounds(tab)
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
        ViewLike::on_mouse_down(tab, fn(e) {
          if e.button == 1 {
            sel.set(idx)
            true
          } else {
            false
          }
        })
        ViewLike::on_mouse_enter(tab, fn(_e) {
          hover.val = true
          ViewLike::schedule_paint(tab)
        })
        ViewLike::on_mouse_leave(tab, fn(_e) {
          hover.val = false
          ViewLike::schedule_paint(tab)
        })
        head.add_child(tab)
        // 内容页:默认只显示当前页;flex 让页区填充 outer 的确定高度
        // (Scroll / Table 等无 measure 叶节点依赖父级确定高度)
        let page_c = themed_container(
          style=[("flex", 1.0)],
          style_str=[("flexDirection", "column")],
        )
        ViewLike::set_visible(page_c, cur.val == idx)
        ignore((node.mount)(ViewLike::view(page_c)))
        contents.push(page_c)
      }
      outer.add_child(head)
      for c in contents {
        outer.add_child(c)
      }
      sel.subscribe(fn(i) {
        cur.val = i
        for j in 0..<contents.length() {
          ViewLike::set_visible(contents[j], j == i)
        }
        ViewLike::schedule_paint(head)
      })
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
    let b = ViewLike::get_bounds(row)
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
  ViewLike::on_mouse_enter(row, fn(_e) {
    hover.val = true
    ViewLike::schedule_paint(row)
  })
  ViewLike::on_mouse_leave(row, fn(_e) {
    hover.val = false
    ViewLike::schedule_paint(row)
  })
  View::set_cursor(row, hand())
  // release 才选中:press 时刻 pick+关层会解除弹层指针抓取,悬着的
  // release 穿透到弹层下方控件;release 由弹层抓取派发给行,无待决事件
  ViewLike::on_mouse_up(row, fn(e) {
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
        style=[("width", width), ("height", control_height), ("marginBottom", 10.0)],
      )
      set_panel_bg(field)
      View::set_cursor(field, hand())
      fn apply(text : String) -> Unit {
        ignore(text)
        ViewLike::schedule_paint(field)
      }

      field.on_draw(fn(p) {
        let b = ViewLike::get_bounds(field)
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

      ViewLike::set_focusable(field, true)
      ViewLike::on_focus_in(field, fn() {
        focused.val = true
        ViewLike::schedule_paint(field)
        false
      })
      ViewLike::on_focus_out(field, fn() {
        focused.val = false
        ViewLike::schedule_paint(field)
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      ViewLike::on_mouse_enter(field, fn(_e) {
        hover.val = true
        ViewLike::schedule_paint(field)
      })
      ViewLike::on_mouse_leave(field, fn(_e) {
        hover.val = false
        ViewLike::schedule_paint(field)
      })
      ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          ViewLike::focus(field)
          // 清空带(箭头左侧)优先:清空选择,不弹列表
          let b = ViewLike::get_bounds(field)
          if clearable && value.get() != "" && e.view_x >= b.width - 40.0 && e.view_x <= b.width - 20.0 {
            value.set("")
            on_change("")
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              bind_popover_bg(p)
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
      attach(parent, ViewLike::view(field))
      ViewLike::view(field)
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
      ViewLike::on_mouse_move(v, fn(e) {
        let h = star_at(e.view_x)
        if h != hover.val {
          hover.val = h
          ViewLike::schedule_paint(v)
        }
      })
      ViewLike::on_mouse_leave(v, fn(_e) {
        if hover.val != 0 {
          hover.val = 0
          ViewLike::schedule_paint(v)
        }
      })
      View::set_cursor(v, hand())
      ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 {
          value.set(star_at(e.view_x))
          true
        } else {
          false
        }
      })
      value.subscribe(fn(new_v) {
        on_change(new_v)
        ViewLike::schedule_paint(v)
      })
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
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
      let wrapped : (
        Int,
        Double,
        Double,
        Double,
        Double,
        Double,
        Double,
        Int,
        Int,
      ) -> Int = fn(
        button,
        _vx,
        _vy,
        _wx,
        _wy,
        _sx,
        _sy,
        _m,
        _t,
      ) {
        if button != 1 {
          return 0
        }
        match pop.val {
          None => {
            let p = Popover::new()
            bind_popover_bg(p)
            let holder = themed_container(
              style=[("width", width), ("height", height)],
            )
            ignore((content.mount)(ViewLike::view(holder)))
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
        fn(f, b, vx, vy, wx, wy, sx, sy, m, t) {
          f(b, vx, vy, wx, wy, sx, sy, m, t)
        },
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
        style=[("width", width), ("height", control_height), ("marginBottom", 10.0)],
      )
      set_panel_bg(field)
      View::set_cursor(field, hand())
      field.on_draw(fn(p) {
        let b = ViewLike::get_bounds(field)
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
      ViewLike::set_focusable(field, true)
      ViewLike::on_focus_in(field, fn() {
        focused.val = true
        ViewLike::schedule_paint(field)
        false
      })
      ViewLike::on_focus_out(field, fn() {
        focused.val = false
        ViewLike::schedule_paint(field)
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          ViewLike::focus(field)
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              bind_popover_bg(p)
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
                    let b = ViewLike::get_bounds(sep)
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
                  let b = ViewLike::get_bounds(row)
                  if hover.val {
                    p2.set_fill_color(theme_fill_hover())
                    p2.fill_rect(0.0, 0.0, b.width, b.height)
                  }
                  let at = AttributedText::new(it, valign=Center, wrap=false)
                  at.set_font(fnt)
                  at.set_color(theme_text_regular())
                  p2.draw_attributed_text(at, 8.0, 0.0, b.width - 16.0, 28.0)
                })
                ViewLike::on_mouse_enter(row, fn(_e) {
                  hover.val = true
                  ViewLike::schedule_paint(row)
                })
                ViewLike::on_mouse_leave(row, fn(_e) {
                  hover.val = false
                  ViewLike::schedule_paint(row)
                })
                View::set_cursor(row, hand())
                // release 才选中+关层:防 press 关层后悬着的 release
                // 穿透到弹层下方控件(弹层点项一律 release,见
                // adaptation.md)
                ViewLike::on_mouse_up(row, fn(e2) {
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
      attach(parent, ViewLike::view(field))
      ViewLike::view(field)
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
          ViewLike::set_visible(panels[prev], false)
          ViewLike::schedule_paint(dots[prev])
          ViewLike::set_visible(panels[idx], true)
          ViewLike::schedule_paint(dots[idx])
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
        ViewLike::set_visible(pc, i == 0)
        ignore((pages[i].mount)(ViewLike::view(pc)))
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
        ViewLike::on_mouse_down(dot, fn(e) {
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
            let b = ViewLike::get_bounds(a)
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
        ViewLike::on_mouse_enter(a, fn(_e) {
          hover.val = true
          ViewLike::schedule_paint(a)
        })
        ViewLike::on_mouse_leave(a, fn(_e) {
          hover.val = false
          ViewLike::schedule_paint(a)
        })
        View::set_cursor(a, hand())
        ViewLike::on_mouse_down(a, fn(e) {
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
      ViewLike::set_style(stage, "flex", 1.0)
      stage_row.add_child(stage)
      stage_row.add_child(arrow(true))
      let dots_row = themed_container(style_str=[("flexDirection", "row")])
      for d in dots {
        dots_row.add_child(d)
      }
      outer.add_child(stage_row)
      outer.add_child(dots_row)
      // 悬停暂停自动轮播;set_timeout 一次性,回调里自排下一个
      ViewLike::on_mouse_enter(outer, fn(_e) { paused.val = true })
      ViewLike::on_mouse_leave(outer, fn(_e) { paused.val = false })
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
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
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
        style=[("width", width), ("height", control_height), ("marginBottom", 10.0)],
      )
      set_panel_bg(field)
      View::set_cursor(field, hand())
      field.on_draw(fn(p) {
        let b = ViewLike::get_bounds(field)
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

      ViewLike::set_focusable(field, true)
      ViewLike::on_focus_in(field, fn() {
        focused.val = true
        ViewLike::schedule_paint(field)
        false
      })
      ViewLike::on_focus_out(field, fn() {
        focused.val = false
        ViewLike::schedule_paint(field)
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          ViewLike::focus(field)
          match pop.val {
            Some(_) => ()
            None => {
              let p = Popover::new()
              bind_popover_bg(p)
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
                // release 才选中:弹层点项一律 release,防穿透
                ViewLike::on_mouse_up(cell, fn(e2) {
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
                    ViewLike::schedule_paint(cell)
                  }
                }
                ViewLike::schedule_paint(field)
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
      attach(parent, ViewLike::view(field))
      ViewLike::view(field)
    },
  }
}

///|
/// 分组侧边菜单(side_menu 的分组形态):组标题行自绘(次要色小字 +
/// 右侧折叠箭头),foldable 时可点收起/展开组内项(默认全展开,键盘
/// Enter/Space 同效);组内菜单项画法与 side_menu 一致(图标/强调条/
/// 圆角,选中/悬停联动 selected)。icons 给「项文本 → 图标」。
pub fn side_menu_sections(
  sections : Array[(String, Array[String])],
  selected : Store[String],
  width? : Double = 180.0,
  icons? : Array[(String, IconKind)] = [],
  foldable? : Bool = true,
) -> Node {
  {
    mount: fn(parent) {
      let outer = themed_container(style=[("width", width), ("padding", 6.0)], style_str=[
        ("flexDirection", "column"),
      ])
      set_panel_bg(outer)
      let gfont = Font::new("Sans", 12.0)
      for (group, items) in sections {
        let open = Ref(true)
        // 组标题行:自绘(组名 + 右侧折叠箭头),不挂子件保证 hover 全区域
        let head = themed_container(
          style=[("height", 30.0), ("width", width - 12.0)],
        )
        let head_hover = Ref(false)
        let head_focused = Ref(false)
        head.on_draw(fn(p) {
          let b = ViewLike::get_bounds(head)
          if foldable && head_hover.val {
            p.set_fill_color(theme_fill_hover())
            fill_round_rect(p, 0.0, 0.0, b.width, b.height, 4.0)
          }
          let at = AttributedText::new(group, valign=Center, wrap=false)
          at.set_font(gfont)
          at.set_color(theme_text_secondary())
          p.draw_attributed_text(at, 14.0, 0.0, b.width, b.height)
          if foldable {
            draw_icon(
              p,
              if open.val {
                ChevronDown
              } else {
                ChevronRight
              },
              b.width - 14.0,
              b.height / 2.0,
              5.0,
              theme_text_secondary(),
            )
          }
          if head_focused.val {
            draw_focus_ring(p, b.width, b.height)
          }
        })
        // 组内项容器 + 项(收起即整容器隐藏,不占布局)
        let body = themed_container(style_str=[("flexDirection", "column")])
        for it in items {
          let mut kind : IconKind? = None
          for kv in icons {
            if kv.0 == it {
              kind = Some(kv.1)
            }
          }
          let item = stateful_item(
            it,
            // 项宽 = 总宽 − 两侧 padding,与标题行同宽防溢出
            [("width", width - 12.0), ("height", 36.0)],
            selected,
            side_menu_bg,
            side_menu_fg,
            pad_x=14.0,
            align_start=true,
            icon=kind,
            accent=true,
            rounded=true,
          )
          ignore((item.mount)(ViewLike::view(body)))
        }
        fn apply_fold() -> Unit {
          ViewLike::set_visible(body, open.val)
          ViewLike::schedule_paint(head)
        }

        if foldable {
          let toggle = fn() -> Unit {
            open.val = !open.val
            apply_fold()
          }

          apply_fold()
          View::set_cursor(head, hand())
          ViewLike::on_mouse_enter(head, fn(_e) {
            head_hover.val = true
            ViewLike::schedule_paint(head)
          })
          ViewLike::on_mouse_leave(head, fn(_e) {
            head_hover.val = false
            ViewLike::schedule_paint(head)
          })
          ViewLike::on_mouse_down(head, fn(e) {
            if e.button == 1 {
              ViewLike::focus(head)
              toggle()
              true
            } else {
              false
            }
          })
          bind_focus(head, fn() { ViewLike::schedule_paint(head) }, head_focused, toggle)
        }
        outer.add_child(head)
        outer.add_child(body)
      }
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
    },
  }
}
