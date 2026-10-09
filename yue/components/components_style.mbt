// 组件样式基础:语义类型取色、文本角色字体与颜色;包级样式约定同此。
// 包级约定:直角(无圆角);hover/active 一律用背景色表达;
// 所有文字经 draw_text 对齐参数居中(水平 align / 垂直 valign),
// 勿用测宽手动摆位(Windows 的测量与绘制格式不一致会偏左,
// 见 docs/adaptation.md)。
// 渲染模型:交互项 on_draw 自绘(背景色矩形 + 文字),状态(选中/hover)
// 变化经 schedule_paint 触发重绘。组件间状态协调统一走 Store,无平台代码。

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
    Primary => @yue.theme_primary()
    Success => @yue.theme_success()
    Warning => @yue.theme_warning()
    Danger => @yue.theme_danger()
    Info => @yue.theme_info()
  }
}

///|
fn type_light_color(t : SemanticType) -> String {
  match t {
    Primary => @yue.theme_primary_light()
    Success => @yue.theme_success_light()
    Warning => @yue.theme_warning_light()
    Danger => @yue.theme_danger_light()
    Info => @yue.theme_info_light()
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
fn role_font(role : TextRole) -> @yue.Font {
  match role {
    Title => @yue.Font::new("Sans", 18.0, weight=@yue.SemiBold)
    Section => @yue.Font::new("Sans", 14.0, weight=@yue.SemiBold)
    Body => @yue.Font::new("Sans", 13.0)
    Secondary => @yue.Font::new("Sans", 12.0)
    Accent => @yue.Font::new("Sans", 13.0, weight=@yue.SemiBold)
  }
}

///|
fn role_color(role : TextRole) -> String {
  match role {
    Title => @yue.theme_text_primary()
    Section => @yue.theme_text_primary()
    Body => @yue.theme_text_regular()
    Secondary => @yue.theme_text_secondary()
    Accent => @yue.theme_primary()
  }
}
