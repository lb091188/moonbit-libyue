// 主题系统:Theme 色板(结构体、预设/系统/主色派生构造、getter)、
// 主题变更订阅与 theme_apply 整体应用(深浅切换不重建界面),
// 附 Linux 原生控件 CSS 下发与整体重绘。

///|
/// 主题色板。经 [theme_apply] 定制（initialize 之后、mount 之前调用最佳）；
/// 组件每次绘制/挂载经 getter 读取当前值。

///|
fn theme_primary() -> String {
  theme_box.t.primary
}

///|
fn theme_primary_light() -> String {
  theme_box.t.primary_light
}

///|
fn theme_primary_hover() -> String {
  theme_box.t.primary_hover
}

///|
fn theme_danger_hover() -> String {
  theme_box.t.danger_hover
}

///|
fn theme_success() -> String {
  theme_box.t.success
}

///|
fn theme_success_light() -> String {
  theme_box.t.success_light
}

///|
fn theme_warning() -> String {
  theme_box.t.warning
}

///|
fn theme_warning_light() -> String {
  theme_box.t.warning_light
}

///|
fn theme_danger() -> String {
  theme_box.t.danger
}

///|
fn theme_danger_light() -> String {
  theme_box.t.danger_light
}

///|
fn theme_info() -> String {
  theme_box.t.info
}

///|
fn theme_info_light() -> String {
  theme_box.t.info_light
}

///|
fn theme_text_primary() -> String {
  theme_box.t.text_primary
}

///|
fn theme_text_regular() -> String {
  theme_box.t.text_regular
}

///|
fn theme_text_secondary() -> String {
  theme_box.t.text_secondary
}

///|
pub fn theme_border() -> String {
  theme_box.t.border
}

///|
fn theme_fill_hover() -> String {
  theme_box.t.fill_hover
}

///|
fn theme_fill_zebra() -> String {
  theme_box.t.fill_zebra
}

///|
pub fn theme_bg_panel() -> String {
  theme_box.t.bg_panel
}

///|
/// 焦点/激活反馈色:中性灰(取 text_secondary),不用主题色——
/// 主题蓝只用于主要按钮/选中态等强调语义,active 反馈不喧宾夺主。
/// 焦点环与字段聚焦边框共用。
fn theme_focus_accent() -> String {
  theme_text_secondary()
}

///|
/// 表单控件统一高度(按钮/输入框/下拉/数字器/日期选择字段等):
/// 32px(EP 规格),混排成行时基线对齐。自定义控件与覆盖场景一律
/// 引用本常量,不写死字面量;多行文本域等非单行控件不受此约束。
pub let control_height : Double = 32.0

///|
/// 组件库自绘容器:Container::make + 主题切换时自动重绘
/// (draw 回调现取 theme_* 色,重绘即跟随新主题)。
pub fn themed_container(style? : Array[(String, &StyVal)] = []) -> Container {
  let c = Container::make(style~)
  ignore(on_theme_change(fn() { ViewLike::schedule_paint(c) }))
  c
}

///|
/// 面板底色(挂载即设 + 主题切换重设):set_background_color 定死的
/// 底色不经 draw,须订阅重设。随组件销毁的退订走订阅回收袋
/// ([sub_bag_begin]/[sub_bag_end])。
pub fn[T : ViewLike] set_panel_bg(v : T) -> Unit {
  fn apply() -> Unit {
    v.set_background_color(theme_bg_panel())
  }

  apply()
  ignore(on_theme_change(apply))
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
  ignore(on_theme_change(apply))
}

///|
/// 底色绑定:挂载即设 color_of() + 主题切换重设(语义浅底/禁用底等
/// 取自主题色板的静态底色)。随组件销毁的退订走订阅回收袋。
fn[T : ViewLike] bind_bg(v : T, color_of : () -> String) -> Unit {
  fn apply() -> Unit {
    v.set_background_color(color_of())
  }

  apply()
  ignore(on_theme_change(apply))
}

///|
/// 前景(文字)色绑定:挂载即设 color_of() + 主题切换重设。
/// 用于挂载期 set_color 定死的文字;主题切换时按表达式重取。
/// set_color 后必须同文 set_text 一次:set_color 改的 Pango 前景属性
/// 不触发布局缓存失效,不同文重排则重绘仍用旧色(点击路径实测)。
/// 随组件销毁的退订走订阅回收袋。
fn bind_fg(v : Label, color_of : () -> String) -> Unit {
  fn apply() -> Unit {
    ViewLike::set_color(v, color_of())
    v.set_text(v.get_text())
  }

  apply()
  ignore(on_theme_change(apply))
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
/// 主题色板快照。用结构体更新语法做局部定制：
///
/// ```moonbit nocheck
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
  let base = if dark { dark_theme() } else { default_theme() }
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
    danger_hover: if dark {
      lighten_hex(danger, 0.08)
    } else {
      darken_hex(danger, 0.09)
    },
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
/// subs 为 (句柄, 回调) 对:on_theme_change 返回的句柄即退订 id
/// (见 off_theme_change),重建式组件经订阅回收袋整代退订。
priv struct ThemeBox {
  mut t : Theme
  mut subs : Array[(Int, () -> Unit)]
}

///|
let theme_box : ThemeBox = { t: default_theme(), subs: [], }

///|
/// 主题订阅 id 计数器:on_theme_change 的返回值即退订句柄。
let theme_sub_next_id : Ref[Int] = Ref(0)

///|
/// 读取当前主题快照。
pub fn theme_current() -> Theme {
  theme_box.t
}

///|
/// 订阅主题变更（theme_apply 时回调，快照遍历）。组件在挂载时注册,
/// 用于重设挂载期定死的颜色（容器底色/Label 文字色等）；draw 回调
/// 现取 theme_* 的自绘组件只需在回调里 schedule_paint。
/// 返回退订句柄:组件随子视图一起销毁时(重建式组件重建行、旧行
/// remove_child_view 之后)必须经 [off_theme_change] 退订,否则旧行
/// 仍留在订阅表里被逐帧回调;批量场景把重建包进
/// [sub_bag_begin]/[sub_bag_end] 可整代一次性退订。
pub fn on_theme_change(f : () -> Unit) -> Int {
  theme_sub_next_id.val += 1
  let h = theme_sub_next_id.val
  theme_box.subs.push((h, f))
  sub_bag_register(fn() { off_theme_change(h) })
  h
}

///|
/// 退订主题变更（句柄来自 on_theme_change / bind_* 系列返回值；
/// 幂等，未知句柄空操作）。
pub fn off_theme_change(handle : Int) -> Unit {
  theme_box.subs = theme_box.subs.filter(fn(e) { e.0 != handle })
}

///|
/// 把主题色板生成 CSS 下发 Linux 原生控件(输入框文字/插入符/占位符/
/// 选区、多行输入、滚动条、窗口与弹层底色),使原生观感跟随本主题而非
/// 系统主题。其余平台原生控件已由组件全自绘,空操作。
fn apply_native_theme_css(t : Theme) -> Unit {
  let buf = StringBuilder()
  buf.write_string("label { color: \{t.text_primary}; }")
  buf.write_string(
    "entry { color: \{t.text_primary}; caret-color: \{t.text_primary}; background-color: \{t.bg_panel}; background-image: none; outline-width: 0px; }",
  )
  buf.write_string(
    "entry:not(.yue-borderless) { border: 1px solid \{t.border}; }",
  )
  buf.write_string("entry undershoot { background: none; }")
  buf.write_string(
    "entry selection { background-color: \{t.primary_light}; color: \{t.text_primary}; }",
  )
  buf.write_string("entry placeholder { color: \{t.text_secondary}; }")
  buf.write_string(
    "textview { background-color: \{t.bg_panel}; color: \{t.text_primary}; }",
  )
  buf.write_string(
    "textview text { background-color: \{t.bg_panel}; color: \{t.text_primary}; }",
  )
  buf.write_string(
    "textview text selection { background-color: \{t.primary_light}; color: \{t.text_primary}; }",
  )
  buf.write_string("scrollbar { background-color: transparent; }")
  buf.write_string(
    "scrollbar.overlay-indicator:not(.dragging):not(.hovering) { background-color: transparent; }",
  )
  buf.write_string(
    "scrollbar.overlay-indicator:not(.dragging):not(.hovering) slider { min-width: 4px; min-height: 4px; margin: 3px; border-radius: 4px; background-color: \{t.border}; }",
  )
  buf.write_string(
    "scrollbar.overlay-indicator.dragging, scrollbar.overlay-indicator.hovering { background-color: \{t.primary_light}; }",
  )
  buf.write_string(
    "scrollbar.overlay-indicator.dragging slider, scrollbar.overlay-indicator.hovering slider { background-color: \{t.primary}; border-radius: 8px; }",
  )
  buf.write_string(
    "scrollbar slider:hover { background-color: \{t.primary}; border-radius: 8px; }",
  )
  buf.write_string("window { background-color: \{t.bg_page}; }")
  buf.write_string(
    "scrolledwindow junction { background-color: \{t.bg_page}; }",
  )
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
  for entry in snapshot {
    (entry.1)()
  }
  if platform() == "linux" {
    apply_native_theme_css(t)
    // 整体重绘兜底推迟一拍:按钮点击等输入事件回调里同步
    // process_updates 会被 GTK 吞掉(定时器路径实测有效、点击路径实测
    // 无效),脱离触发上下文后再逐窗口同步重绘;连刷两拍,第二拍兜住
    // 第一拍漏掉的子窗口
    post_task(fn() { ffi_repaint_all() })
    post_delayed_task(60, fn() { ffi_repaint_all() })
  } else if platform() == "windows" {
    // Windows 端切主题只有订阅主题的视图会重绘,其余区域残留旧像素
    // (深浅切换后"重影",鼠标划过局部失效才消失);整体失效+擦除,
    // 连带原生子窗口(输入框背景等)一并刷新。保持同步:曾试与 Linux
    // 同款推迟一拍,黑盒测试进程退出时延迟任务对已销毁窗口重绘直接
    // 崩(exit -1,Windows CI 实证);点击劫持真凶是 bind_node 重挂的
    // remove+add(探针定案),与重绘时机无关,勿再动此处
    ffi_repaint_all()
  }
}
