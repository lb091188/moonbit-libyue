// 样式层的枚举与对外类型名（design.md §1.1 / §1.5）。
//
// 本工具链没有 `abbrev` 关键字（实测 [3002]，见 design.md §1.6），类型短名一律
// 走 `pub using`：`using @pkg {type X}` 把外部类型引进来当本名用，`pub` 后
// 本包各文件与外部调用点都能直接写 `TextAlign` / `Display` 这类短名。

///|
pub using @text {type TextAlign, type FontWeight}

///|
pub using @yoga {
  type Display,
  type PositionType,
  type FlexDirection,
  type JustifyContent,
  type AlignItems,
}

///|
/// 下划线形态：CSS `text-decoration` 在本栈只有画得出的一条线，故只有两档。
pub(all) enum TextDecoration {
  Underline
  None
}

///|
/// 换行形态：CSS `white-space` 的两档（`nowrap` 即不折行）。
pub(all) enum WhiteSpace {
  Normal
  NoWrap
}

///|
/// 可见性：`visibility` 只两档（折叠占位一类没有对应绘制语义，不设）。
/// `hidden` 落宿主 `Widget::set_visible(false)`（仍参与布局，与 CSS 同义）。
pub(all) enum Visibility {
  Visible
  Hidden
}
