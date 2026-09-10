// 表格：Table + 可挂 MoonBit trait 的数据模型桥。
// 模型桥把 trait 回调转调为 C 函数指针，数据以 [kind:i32le][payload]
// 的 Bytes 编码跨 ABI 传递（kind 0=文本 1=布尔 2=文本+颜色）。

///|
/// 单元格值：列类型决定合法变体（Text/Edit 用 Str，Checkbox 用 Flag，
/// Custom 用 ColorText）。
pub(all) enum TableValue {
  Str(String)
  Flag(Bool)
  ColorText(String, String)
}

///|
/// 表格数据模型。行数与取值由消费方实现，100 万行也只按需取数。
pub(open) trait TableModel {
  row_count(Self) -> Int
  get_value(Self, column : Int, row : Int) -> TableValue
  set_value(Self, column : Int, row : Int, value : TableValue) -> Unit
}

///|
/// 模型对象包装：C 侧闭包参数（注册表保活）。
priv struct ModelBox {
  row_count : () -> Int
  get_value : (Int, Int) -> TableValue
  set_value : (Int, Int, TableValue) -> Unit
}

///|
fn encode_table_value(v : TableValue) -> Bytes {
  let (kind, p1, p2) = match v {
    Str(s) => (0, utf8_bytes(s), Bytes::make(0, 0))
    Flag(b) => (1, Bytes::make(1, if b { 1 } else { 0 }), Bytes::make(0, 0))
    ColorText(text, color) => (2, utf8_bytes(text), utf8_bytes(color))
  }
  let len = 4 + p1.length() + 1 + p2.length()
  Bytes::makei(len, fn(i) {
    if i < 4 {
      ((kind >> (i * 8)) & 255).to_byte()
    } else if i < 4 + p1.length() {
      p1[i - 4]
    } else if i == 4 + p1.length() {
      0
    } else {
      p2[i - 5 - p1.length()]
    }
  })
}

///|
fn decode_table_value(kind : Int, data : Bytes, flag : Int) -> TableValue {
  match kind {
    1 => Flag(flag == 1)
    _ => Str(from_utf8_bytes(data))
  }
}

///|
/// 创建表格。
pub fn Table::new() -> Table {
  { view: ffi_table_new() }
}

///|
/// 添加文本列（宽度 -1 为自动）。
pub fn Table::add_column_text(self : Table, title : String, width : Int) -> Unit {
  ffi_table_add_column_text(self.view, utf8_bytes(title), width)
}

///|
/// 添加可编辑文本列（编辑结果经 set_value 回写模型）。
pub fn Table::add_column_edit(self : Table, title : String, width : Int) -> Unit {
  ffi_table_add_column_edit(self.view, utf8_bytes(title), width)
}

///|
/// 添加复选框列（切换经 set_value 回写模型）。
pub fn Table::add_column_checkbox(self : Table, title : String, width : Int) -> Unit {
  ffi_table_add_column_checkbox(self.view, utf8_bytes(title), width)
}

///|
/// 添加自绘列：draw 在每个单元格重绘时调用，name/color 来自模型的
/// ColorText 值。
pub fn Table::add_column_custom(
  self : Table,
  title : String,
  width : Int,
  draw : (Painter, Double, Double, Double, Double, String, String) -> Unit,
) -> Unit {
  let wrapped : (Painter, Double, Double, Double, Double, Bytes, Bytes) -> Unit =
    fn(painter, x, y, w, h, name, color) {
      draw(painter, x, y, w, h, from_utf8_bytes(name), from_utf8_bytes(color))
    }
  keep_alive_draw(fn(painter) { wrapped(painter, 0.0, 0.0, 0.0, 0.0, Bytes::make(0, 0), Bytes::make(0, 0)) })
  ffi_table_add_column_custom(
    self.view,
    utf8_bytes(title),
    width,
    fn(f, painter, x, y, w, h, name, color) { f(painter, x, y, w, h, name, color) },
    wrapped,
  )
}

///|
/// 是否显示边框。
pub fn Table::set_has_border(self : Table, yes : Bool) -> Unit {
  ffi_table_set_has_border(self.view, if yes { 1 } else { 0 })
}

///|
/// 挂载数据模型（column_count 为列数）。
pub fn[M : TableModel] Table::set_model(self : Table, model : M, column_count : Int) -> Unit {
  let box = ModelBox::{
    row_count: fn() { model.row_count() },
    get_value: fn(c, r) { model.get_value(c, r) },
    set_value: fn(c, r, v) { model.set_value(c, r, v) },
  }
  keep_alive(fn() { ignore(box) })
  ffi_table_bind_model(
    self.view,
    column_count,
    box,
    fn(b : ModelBox) -> Int { (b.row_count)() },
    fn(f : ((ModelBox, Int, Int) -> TableValue), b : ModelBox, c : Int, r : Int) -> Bytes {
      encode_table_value(f(b, c, r))
    },
    fn(f : ((ModelBox, Int, Int, TableValue) -> Unit), b : ModelBox, c : Int, r : Int, kind : Int, data : Bytes, flag : Int) -> Unit {
      f(b, c, r, decode_table_value(kind, data, flag))
    },
  )
}
