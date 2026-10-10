// 节点样式：属性与默认值对齐 Web Flexbox 标准。

///|
pub struct Style {
  mut display : Display
  mut direction : Direction
  mut position : PositionType
  mut top : Value
  mut right : Value
  mut bottom : Value
  mut left : Value
  mut flex_direction : FlexDirection
  mut flex_wrap : FlexWrap
  mut flex_grow : Double
  mut flex_shrink : Double
  mut flex_basis : Value
  mut justify_content : JustifyContent
  mut align_items : AlignItems
  mut align_self : Option[AlignItems]
  mut align_content : AlignContent
  mut width : Value
  mut height : Value
  mut min_width : Value
  mut min_height : Value
  mut max_width : Value
  mut max_height : Value
  mut aspect_ratio : Option[Double]
  margin : Edges
  padding : Edges
  border : Edges
  mut row_gap : Double
  mut column_gap : Double
}

///|
/// web 标准默认样式：row / nowrap / shrink 1 / basis auto /
/// justify flex-start / align-items stretch / align-content stretch。
pub fn Style::new() -> Style {
  {
    display : Flex,
    direction : Ltr,
    position : Relative,
    top : Auto,
    right : Auto,
    bottom : Auto,
    left : Auto,
    flex_direction : Row,
    flex_wrap : NoWrap,
    flex_grow : 0.0,
    flex_shrink : 1.0,
    flex_basis : Auto,
    justify_content : FlexStart,
    align_items : Stretch,
    align_self : None,
    align_content : Stretch,
    width : Undefined,
    height : Undefined,
    min_width : Undefined,
    min_height : Undefined,
    max_width : Undefined,
    max_height : Undefined,
    aspect_ratio : None,
    margin : Edges::zero(),
    padding : Edges::zero(),
    border : Edges::zero(),
    row_gap : 0.0,
    column_gap : 0.0,
  }
}

///|
/// 取某一边的值，padding/border 的 Auto 视同 Undefined。
fn edge_value(e : Edges, which : Int) -> Value {
  let v = match which {
    0 => e.left
    1 => e.right
    2 => e.top
    _ => e.bottom
  }
  match v {
    Auto => Undefined
    other => other
  }
}

///|
/// 按「参照尺寸」解析一个值；Undefined/Auto、内在关键词与无参照的 Percent
/// 均给 0（关键词只在尺寸类属性上有意义，解析需要节点上下文，走
/// `algorithm.mbt` 的 `axis_size`）。
fn resolve_value(v : Value, owner : Option[Double]) -> Double {
  match v {
    Undefined => 0.0
    Auto => 0.0
    MinContent => 0.0
    MaxContent => 0.0
    FitContent => 0.0
    Fixed(x) => x
    Percent(p) =>
      match owner {
        Some(base) => base * p / 100.0
        None => 0.0
      }
  }
}

///|
/// 把尺寸类取值解析为确定值；不可确定（Undefined/Auto/内在关键词/无参照
/// Percent）给 None。内在关键词由 `axis_size` 带节点上下文另行解析。
fn definite_size(v : Value, owner : Option[Double]) -> Option[Double] {
  match v {
    Fixed(x) => Some(x)
    Percent(p) =>
      match owner {
        Some(base) => Some(base * p / 100.0)
        None => None
      }
    _ => None
  }
}
