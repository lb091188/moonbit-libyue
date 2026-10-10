// 主题系统（新栈首批）：`Theme` 色板 + 预设/主色派生构造 + 变更订阅与
// `theme_apply`。与 master 线的差别记在这里：
// - **没有原生控件 CSS 下发**（旧 `apply_native_theme_css`）——新栈控件全部
//   自绘，色板就是绘制时读取的唯一来源，深浅切换不需要重建原生控件样式；
// - **没有 `ffi_repaint_all` 整体重绘兜底**——重绘由窗口层与各控件自己的
//   订阅路径负责（随组件批次一起接）；
// - `theme_from_system`（跟随系统深浅与主色）依赖系统集成层，本批未接。

///|
pub(all) struct Theme {
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
  /// 页面底色（窗口/滚动区最底层）
  bg_page : String
  /// 面板底色（卡片/侧栏/输入框/弹层等内容面板）
  bg_panel : String
}

///|
/// 内置默认主题（浅底）。
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
/// 由单个主色调公式派生整套色板（EP 主题工作台思路，公式与 master 线一致）：
///   - 主色：保持色相，饱和度保底 0.45，明度按深浅模式钳制（浅 0.34..0.52 /
///     深 0.55..0.72），保证白字/浅底上的可读性；
///   - `primary_hover` = 主色明度 ∓（浅 -0.09 / 深 +0.08）；
///   - `primary_light` = 主色向面板底混色（浅混白 12%、深混面板底 30%）；
///   - 语义色取固定色相轮（142/36/4/210），饱和度假借主色（≥0.4）、
///     明度随模式（浅 0.38 / 深 0.62），浅底变体再混白 14% / 混面板底 28%；
///   - 中性色（文字/边框/悬停/斑马纹/背景）取内置基准盘，不随主色偏移。
/// accent 非法时回落内置基准主题。
pub fn theme_from_accent(accent : String, dark? : Bool = false) -> Theme {
  let base = if dark { dark_theme() } else { default_theme() }
  let (r, g, b) = match parse_hex(accent) {
    Some(rgb) => rgb
    None => return base
  }
  let (h, s0, l0) = rgb_to_hsl(r, g, b)
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
  // mix_hex 的 t 是取「前者」的比例，别写反
  let primary_light = if dark {
    mix_hex(primary, base.bg_panel, 0.30)
  } else {
    mix_hex(primary, "#FFFFFF", 0.12)
  }
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
/// 主题存储：单个可变快照 + 变更订阅表（`theme_apply` 整体替换并通知，
/// 深浅切换不重建界面）。`on_theme_change` 返回的句柄即退订 id。
priv struct ThemeBox {
  mut t : Theme
  mut subs : Array[(Int, () -> Unit)]
}

///|
let theme_box : ThemeBox = { t: default_theme(), subs: [], }

///|
/// 主题订阅 id 计数器。
let theme_sub_next_id : Ref[Int] = Ref(0)

///|
/// 读取当前主题快照。
pub fn theme_current() -> Theme {
  theme_box.t
}

///|
/// 订阅主题变更（`theme_apply` 时回调）。返回退订句柄。
pub fn on_theme_change(f : () -> Unit) -> Int {
  theme_sub_next_id.val += 1
  let h = theme_sub_next_id.val
  theme_box.subs.push((h, f))
  h
}

///|
/// 退订主题变更（幂等，未知句柄空操作）。
pub fn off_theme_change(handle : Int) -> Unit {
  theme_box.subs = theme_box.subs.filter(fn(e) { e.0 != handle })
}

///|
/// 应用整套主题：替换快照并通知订阅者。旧链路在此还要给 Linux 原生控件
/// 下发 CSS 并整体重绘，新栈全部自绘，这两步都不需要（重绘由订阅方各自
/// 触发，整体重绘兜底随组件批次接）。
pub fn theme_apply(t : Theme) -> Unit {
  theme_box.t = t
  let snapshot = theme_box.subs.copy()
  for entry in snapshot {
    (entry.1)()
  }
}

///|
pub fn theme_primary() -> String {
  theme_box.t.primary
}

///|
pub fn theme_primary_light() -> String {
  theme_box.t.primary_light
}

///|
pub fn theme_primary_hover() -> String {
  theme_box.t.primary_hover
}

///|
pub fn theme_danger_hover() -> String {
  theme_box.t.danger_hover
}

///|
pub fn theme_success() -> String {
  theme_box.t.success
}

///|
pub fn theme_success_light() -> String {
  theme_box.t.success_light
}

///|
pub fn theme_warning() -> String {
  theme_box.t.warning
}

///|
pub fn theme_warning_light() -> String {
  theme_box.t.warning_light
}

///|
pub fn theme_danger() -> String {
  theme_box.t.danger
}

///|
pub fn theme_danger_light() -> String {
  theme_box.t.danger_light
}

///|
pub fn theme_info() -> String {
  theme_box.t.info
}

///|
pub fn theme_info_light() -> String {
  theme_box.t.info_light
}

///|
pub fn theme_text_primary() -> String {
  theme_box.t.text_primary
}

///|
pub fn theme_text_regular() -> String {
  theme_box.t.text_regular
}

///|
pub fn theme_text_secondary() -> String {
  theme_box.t.text_secondary
}

///|
pub fn theme_border() -> String {
  theme_box.t.border
}

///|
pub fn theme_fill_hover() -> String {
  theme_box.t.fill_hover
}

///|
pub fn theme_fill_zebra() -> String {
  theme_box.t.fill_zebra
}

///|
/// 页面底色（窗口/滚动区最底层）。
pub fn theme_bg_page() -> String {
  theme_box.t.bg_page
}

///|
/// 面板底色。
pub fn theme_bg_panel() -> String {
  theme_box.t.bg_panel
}

///|
/// 焦点/激活反馈色：中性灰（取 text_secondary），不用主题色——主题蓝只用于
/// 主要按钮/选中态等强调语义，active 反馈不喧宾夺主。焦点环与字段聚焦边框共用。
pub fn theme_focus_accent() -> String {
  theme_text_secondary()
}

///|
/// 表单控件统一高度（按钮/输入框/下拉/数字器/日期选择字段等）：32px（EP 规格），
/// 混排成行时基线对齐。自定义控件与覆盖场景一律引用本常量，不写死字面量。
pub let control_height : Double = 32.0

///|
/// 输入类控件的行高基准：13px Sans 的「Ag」包围盒高 + 有边框时 2px 边框。
pub fn entry_ctrl_height(bordered : Bool) -> Double {
  let probe = @text.AttributedText::new("Ag", wrap=false)
  probe.set_font(@text.Font::new("Sans", 13.0))
  probe.get_bounds_for(10000.0, 1000.0).height + (if bordered { 2.0 } else { 0.0 })
}
