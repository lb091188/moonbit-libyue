// 统一样式值模型：单个 style 数组混装 Double（像素）与 String
// （枚举/百分比/auto/颜色）两类值，yue 内按值类型派发到 yoga 的
// float/string 两条底层通道（对应 C 侧 SetStyleProperty 两个重载，
// C ABI 无重载故 FFI 拆两条——拆分在此消化，不再暴露给调用方）。
// 注：impl 对 builtin 类型的实现每类型一块写全（本工具链下对外部
// 类型分块/覆盖默认的实现判定不完整，探针实测）。

///|
/// 样式值：Double 为像素数（width/margin/flex/...），String 为枚举
/// （"row"/"center"...）、百分比（"50%"）、auto 或颜色。
/// 开放 trait：下游可给自己的类型扩展实现。
pub(open) trait StyVal {
  /// 按值类型应用到视图句柄：Double 走数值通道，String 走字符串通道。
  fn apply_to(Self, View, String) -> Unit
}

///|
pub impl StyVal for Double with fn apply_to(self, v, name) -> Unit {
  ffi_view_set_style_prop_float(v, utf8_bytes(name), self)
}

///|
pub impl StyVal for String with fn apply_to(self, v, name) -> Unit {
  ffi_view_set_style_prop_str(v, utf8_bytes(name), utf8_bytes(self))
}

///|
/// 对裸视图句柄应用样式表（View 未实现 ViewLike，包装型组件
/// 把样式落到被包装节点 mount 出的根视图时用）。
fn apply_style_view(v : View, style : Array[(String, &StyVal)]) -> Unit {
  for (k, val) in style {
    val.apply_to(v, k)
  }
}
