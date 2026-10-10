// 尺寸与边距值类型：布局属性统一取值。
//
// 对齐 Web Flexbox 标准（CSS Flexible Box Layout Module Level 1），
// 不保留 Yoga 的「yoga 默认值 / web 默认值」双标准——本包一律使用
// web 默认：flex-direction: row、flex-shrink: 1、flex-basis: auto、
// align-items: stretch、min-width/height: auto。

///|
/// 布局属性取值。
///
/// - `Undefined`：未设置（padding/border 视同 0）
/// - `Fixed(v)`：固定值（逻辑像素）
/// - `Percent(p)`：相对父容器对应轴内容区尺寸的百分比（p 取 0~100）
/// - `Auto`：自动（尺寸交给布局算法；margin 的 Auto 有特殊语义：
///   在主轴吸收剩余空间，优先级高于 justify-content）
pub enum Value {
  Undefined
  Fixed(Double)
  Percent(Double)
  Auto
}

///|
/// 盒模型四边（物理方向：left/right/top/bottom）。
pub struct Edges {
  mut left : Value
  mut right : Value
  mut top : Value
  mut bottom : Value
}

///|
/// 四边全 Undefined。
pub fn Edges::zero() -> Edges {
  { left : Undefined, right : Undefined, top : Undefined, bottom : Undefined }
}

///|
pub enum Display {
  Flex
  None
}

///|
/// 定位方式。`Absolute` 的子项脱离文档流，包含块为本节点 padding box。
pub enum PositionType {
  Relative
  Absolute
}

///|
pub enum FlexDirection {
  Row
  RowReverse
  Column
  ColumnReverse
}

///|
pub enum FlexWrap {
  NoWrap
  Wrap
  WrapReverse
}

///|
pub enum JustifyContent {
  FlexStart
  FlexEnd
  Center
  SpaceBetween
  SpaceAround
  SpaceEvenly
}

///|
/// 交叉轴对齐。`Baseline` 当前按 `FlexStart` 处理（首版未实现基线对齐）。
pub enum AlignItems {
  Stretch
  FlexStart
  FlexEnd
  Center
  Baseline
}

///|
/// 多行容器的整行分布对齐（align-content）。
pub enum AlignContent {
  Stretch
  FlexStart
  FlexEnd
  Center
  SpaceBetween
  SpaceAround
  SpaceEvenly
}
