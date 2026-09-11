// 复刻自 yue-sample-apps/table：10000 行虚拟数据 + 可编辑列 + 自绘颜色列。
// 数据模型以 trait 实现，仅在被问到时取数（虚拟滚动友好）。

///|
/// 官方示例的模型：10000 行 3 列，第 2 列可编辑，第 3 列自绘色块。
struct DemoModel {
  edited_text : Ref[Map[Int, String]]
}

///|
impl @yue.TableModel for DemoModel with fn row_count(_self) {
  10000
}

///|
impl @yue.TableModel for DemoModel with fn get_value(self, column, row) {
  match column {
    0 => @yue.Str("\{row}")
    1 => match self.edited_text.val.get(row) {
      Some(text) => @yue.Str(text)
      None => @yue.Str("Edit Me \{row}")
    }
    _ => {
      let r = (row % 5) * 40 + (row % 55) * 1
      let g = (row % 4) * 40 + (row % 20) * 4
      let b = (row % 3) * 40 + (row % 10) * 13
      @yue.ColorText("rgb(\{r}, \{g}, \{b})", "#\{hex2(r)}\{hex2(g)}\{hex2(b)}")
    }
  }
}

///|
impl @yue.TableModel for DemoModel with fn set_value(self, column, row, value) {
  match (column, value) {
    (1, @yue.Str(text)) => self.edited_text.val.set(row, text)
    _ => ()
  }
}

///|
fn hex2(v : Int) -> String {
  let hi = (v / 16) % 16
  let lo = v % 16
  "\{digit(hi)}\{digit(lo)}"
}

///|
fn digit(v : Int) -> String {
  if v < 10 {
    "\{v}"
  } else {
    match v {
      10 => "a"
      11 => "b"
      12 => "c"
      13 => "d"
      14 => "e"
      _ => "f"
    }
  }
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.set_content_size(400.0, 400.0)
  win.on_close(fn(_window) { @yue.quit() })

  let table = @yue.Table::new()
  table.add_column_with_options("ID", { column_type: @yue.Text, column: 0, width: 40 })
  table.add_column_with_options("Editable Text", { column_type: @yue.Edit, column: -1, width: 100 })
  table.add_column_custom("Custom Color", -1, fn(painter, x, y, w, h, name, color) {
    painter.set_fill_color(color)
    painter.fill_rect(x, y, w, h)
    painter.draw_text(name, x, y, w, h, color="#FFF")
  })
  table.set_model(DemoModel::{ edited_text: Ref(Map([])) }, 3)
  table.set_has_border(true)
  table.set_style("margin", 10.0)
  table.set_style("flex", 1.0)

  let content = @yue.Container::new()
  content.add_child(table)
  win.set_content(content)
  win.center()
  win.activate()
  @yue.run()
}
