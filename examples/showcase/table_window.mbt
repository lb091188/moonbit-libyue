// 表格演示窗口：TableModel 模型-视图 + 三种列类型（Text/Checkbox/Edit）。
// 注：Linux(GTK) 下 Table 放进 Notebook 页签测量尺寸会触发崩溃，
// 因此保留独立子窗口形态；其他平台仅为保持演示一致。

///|
/// 表格模型：语言清单 + 勾选 + 可编辑星数。
struct LangModel {
  names : Array[String]
  stars : Array[Int]
  likes : Array[Bool]
}

///|
impl @yue.TableModel for LangModel with row_count(self) {
  self.names.length()
}

///|
impl @yue.TableModel for LangModel with get_value(self, column, row) {
  match column {
    0 => @yue.Str(self.names[row])
    1 => @yue.Flag(self.likes[row])
    2 => @yue.Str("\{self.stars[row]} ★")
    _ => @yue.Str("?")
  }
}

///|
impl @yue.TableModel for LangModel with set_value(self, column, row, value) {
  match (column, value) {
    (1, @yue.Flag(b)) => self.likes[row] = b
    (2, @yue.Str(s)) => {
      // 取前导数字（用户编辑星数列后回写）
      let mut n = 0
      let mut seen = false
      for i in 0..<s.length() {
        let c = s.unsafe_get(i).to_int()
        if c >= 48 && c <= 57 {
          n = n * 10 + (c - 48)
          seen = true
        } else if seen {
          break
        }
      }
      self.stars[row] = if seen { n } else { self.stars[row] }
    }
    (_, _) => ()
  }
}

///|
let table_events : @yue.Store[String] = @yue.Store::new("（行激活 / 勾选 / 编辑事件）")

///|
fn open_table_window() -> Unit {
  let win = @yue.Window::new()
  win.set_title("表格演示")
  win.set_content_size(520.0, 380.0)
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)
  let table = @yue.Table::new()
  table.add_column_with_options("语言", { column_type: @yue.Text, column: 0, width: 160 })
  table.add_column_with_options("喜欢", { column_type: @yue.Checkbox, column: -1, width: 80 })
  table.add_column_with_options("星数", { column_type: @yue.Edit, column: -1, width: 120 })
  table.set_has_border(true)
  table.set_style("flex", 1.0)
  table.set_model(
    LangModel::{
      names: ["MoonBit", "Rust", "Zig", "Go"],
      stars: [5, 5, 4, 3],
      likes: [true, true, true, false],
    },
    3,
  )
  table.on_row_activate(fn(row) { table_events.set("行激活：第 \{row} 行") })
  table.on_selection_change(fn() { table_events.set("选择变化") })
  page.add_child(table)
  let log = @yue.Label::new(table_events.get())
  log.set_style("marginTop", 8.0)
  table_events.subscribe(fn(s) { log.set_text(s) })
  page.add_child(log)
  win.set_content(page)
  win.center()
  win.activate()
}
