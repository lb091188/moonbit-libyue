// 表格：`TableColumn`/`TableRow` 模型 + `table`（表头排序指示、斑马纹、悬停、
// 行选择、按列宽排布），列宽与排序状态都走 `Store`（组件只切状态与画箭头，
// **不替调用方排序**——排序口径由使用方决定，见 `TableSort` 注释）。
//
// 行是「重建式列表」（与 `transfer` 同款）：数据 Store 一变就清空子控件按新值再挂，
// 行级不持订阅，所以重建次数与订阅数量解耦；万行级形态见 `table_v`（虚拟滚动，
// 随「虚拟列表」一批落地）。

///|
/// 表格列定义（EP Table）：标题 + 宽度（`<= 0` 为弹性列，均分剩余宽）+
/// 单元格对齐 + 是否可排序。
pub(all) struct TableColumn {
  title : String
  width : Double
  align : @text.TextAlign
  sortable : Bool
}

///|
/// 建列定义（对齐默认左、默认可排序）。
pub fn TableColumn::make(
  title : String,
  width : Double,
  align? : @text.TextAlign = @text.Start,
  sortable? : Bool = true,
) -> TableColumn {
  { title, width, align, sortable }
}

///|
/// 排序状态：`column` 是列下标（`< 0` 表示不排序），`asc` 为升序。
/// 组件在表头点击时切换它并画箭头；**数据由使用方订阅本 Store 后自行排序并写回
/// `rows`**（排序口径因业务而异：数字、字典序、自定义比较都归使用方）——
/// 参考实现见 `sort_rows`（数值优先的稳定排序），两三行接线即可。
pub(all) struct TableSort {
  column : Int
  asc : Bool
}

///|
pub impl Eq for TableSort with fn equal(self, other) {
  self.column == other.column && self.asc == other.asc
}

///|
pub extend TableSort with Eq::{not_equal, equal}

///|
pub impl Eq for TableCell with fn equal(self, other) {
  match (self, other) {
    (CellText(a), CellText(b)) => a == b
    (CellTag(a, ta), CellTag(b, tb)) => a == b && ta == tb
    (CellColorBox(a, ca), CellColorBox(b, cb)) => a == b && ca == cb
    (CellLines(a), CellLines(b)) => a == b
    _ => false
  }
}

///|
pub extend TableCell with Eq::{not_equal, equal}

///|
pub impl Eq for TableRow with fn equal(self, other) {
  self.cells == other.cells
}

///|
pub extend TableRow with Eq::{not_equal, equal}

///|
/// 单元格内容：纯文本 / 语义标签 / 颜色块 / 多行文本。
pub(all) enum TableCell {
  CellText(String)
  CellTag(String, SemanticType)
  CellColorBox(String, String)
  CellLines(Array[String])
}

///|
/// 一行数据：单元格按列顺序排列，缺位补空。
pub(all) struct TableRow {
  cells : Array[TableCell]
}

///|
/// 用纯文本建一行（全 `CellText` 的快捷方式）。
pub fn TableRow::make(cells : Array[String]) -> TableRow {
  let out : Array[TableCell] = []
  for c in cells {
    out.push(CellText(c))
  }
  { cells: out }
}

///|
/// 列宽拖动时的最小列宽。
const MIN_COL_W : Double = 40.0

///|
/// 按列定义把总宽分给各列：固定列按声明宽，弹性列（`<= 0`）均分剩余宽；
/// 剩余为负时弹性列取下限 0（总宽不够就溢出，不压缩固定列）。
fn table_widths(columns : Array[TableColumn], total : Double) -> Array[Double] {
  let mut fixed_sum = 0.0
  let mut flex_n = 0
  for c in columns {
    if c.width > 0.0 {
      fixed_sum = fixed_sum + c.width
    } else {
      flex_n = flex_n + 1
    }
  }
  let share = if flex_n > 0 {
    ((total - fixed_sum) / flex_n.to_double()).max(0.0)
  } else {
    0.0
  }
  let out : Array[Double] = []
  for c in columns {
    out.push(if c.width > 0.0 { c.width } else { share })
  }
  out
}

///|
/// 单元格取值（缺位给空文本）。
fn cell_of(row : TableRow, i : Int) -> TableCell {
  if i < row.cells.length() {
    row.cells[i]
  } else {
    CellText("")
  }
}

///|
/// 单元格的文本投影（缺位给空串）：标签取文字、色块取色值、多行取首行。
/// 给使用方写排序比较用——组件自己不做排序，但要能拿到「这一格是什么字」。
pub fn cell_text(row : TableRow, i : Int) -> String {
  match cell_of(row, i) {
    CellText(s) => s
    CellTag(s, _) => s
    CellColorBox(s, _) => s
    CellLines(ls) => if ls.length() > 0 { ls[0] } else { "" }
  }
}

///|
/// 摘出字符串开头的（可带负号的）十进制整数；没有数字给 `None`。
fn leading_int(c : String) -> Int? {
  let cs = c.to_array()
  let n = cs.length()
  let mut i = 0
  let mut neg = false
  if n > 0 && cs[0] == '-' {
    neg = true
    i = 1
  }
  let mut v = 0
  let mut any = false
  while i < n && cs[i] >= '0' && cs[i] <= '9' {
    v = v * 10 + (cs[i].to_int() - 48)
    any = true
    i = i + 1
  }
  if !any {
    None
  } else if neg {
    Some(0 - v)
  } else {
    Some(v)
  }
}

///|
/// 两格文本比较：**都能摘出前导整数就按数值比**，否则按字典序（数值相等也回落
/// 字典序，保证全序）。演示数据是「数字 + 单位」混排（`12 处` / `6 处`、
/// `虚拟行 3`），纯字典序会把 `12` 排在 `6` 前面、看着像没排序，故先试数值。
pub fn compare_cells(a : String, b : String) -> Int {
  let c = match (leading_int(a), leading_int(b)) {
    (Some(x), Some(y)) =>
      if x < y {
        -1
      } else if x > y {
        1
      } else {
        0
      }
    _ => 0
  }
  if c != 0 {
    c
  } else {
    a.lexical_compare(b)
  }
}

///|
/// 按 `TableSort` 排一份数据行（**纯函数**，不改入参，返回新表）。
///
/// 组件本身仍不替调用方排序（口径见 `TableSort` 注释），这里是给使用方的参考
/// 实现：订阅 `sort` Store、把结果 `set` 回 `rows` 即可，两三行就能让表头点击
/// 真的改变行序。
/// - `column < 0`（表头第三次点击的「取消排序」）或越界 → 原样返回；
/// - 比较走 `compare_cells`（数值优先，再字典序）；
/// - **稳定**：同键保持原相对顺序（下标做次键——标准库的 `sort_by` 不保证稳定，
///   而「按状态列排」这种同键成片的场景不稳定会看着乱跳）。
pub fn sort_rows(rows : Array[TableRow], sort : TableSort) -> Array[TableRow] {
  let out = rows.copy()
  let j = sort.column
  if j < 0 {
    return out
  }
  let order : Array[Int] = []
  for i = 0; i < out.length(); i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(a : Int, b : Int) -> Int {
    let mut c = compare_cells(cell_text(out[a], j), cell_text(out[b], j))
    if !sort.asc {
      c = 0 - c
    }
    if c != 0 {
      c
    } else {
      a - b
    }
  })
  let res : Array[TableRow] = []
  for i in order {
    res.push(out[i])
  }
  res
}

///|
/// 把一个单元格画在自己的盒子里（对齐按列定义；标签/色块自带内边距）。
fn draw_cell(
  p : @render.Painter,
  cell : TableCell,
  r : @core.Rect,
  align : @text.TextAlign,
  font : @text.Font,
  small_font : @text.Font,
) -> Unit {
  match cell {
    CellText(t) =>
      {
        let _ = @text.draw_box_at(
          p,
          10.0,
          0.0,
          (r.w - 12.0).max(1.0),
          r.h,
          t,
          font,
          @theme.theme_text_regular(),
          align=align,
          valign=@text.Center,
        )
      }
    CellTag(t, kind) => {
      let tw = 0.0
      let _ = tw
      let chip_w = 0.0
      let _ = chip_w
      // 标签形态与显示族的 tag_of_type 一致（浅底 + 主色字）
      p.set_fill_color(type_light_color(kind))
      let box_w = (r.w - 16.0).max(20.0)
      fill_round_rect(p, 8.0, (r.h - 22.0) / 2.0, box_w.min(r.w - 16.0), 22.0, 4.0)
      let _ = @text.draw_box_at(
        p,
        8.0,
        (r.h - 22.0) / 2.0,
        box_w.min(r.w - 16.0),
        22.0,
        t,
        small_font,
        type_color(kind),
        align=@text.Center,
        valign=@text.Center,
      )
    }
    CellColorBox(color, label) => {
      p.set_fill_color(color)
      fill_round_rect(p, 10.0, (r.h - 14.0) / 2.0, 14.0, 14.0, 3.0)
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(10.5, (r.h - 14.0) / 2.0 + 0.5, 13.0, 13.0)
      let _ = @text.draw_box_at(
        p,
        30.0,
        0.0,
        (r.w - 34.0).max(1.0),
        r.h,
        label,
        font,
        @theme.theme_text_regular(),
        align=@text.Start,
        valign=@text.Center,
      )
    }
    CellLines(lines) => {
      // 行高内最多画两行（第一行贴中上、第二行贴中下）
      let lh = 16.0
      for i = 0; i < lines.length().min(2); i = i + 1 {
        let _ = @text.draw_box_at(
          p,
          10.0,
          (r.h - lh * 2.0) / 2.0 + lh * i.to_double(),
          (r.w - 12.0).max(1.0),
          lh,
          lines[i],
          small_font,
          @theme.theme_text_regular(),
          align=@text.Start,
          valign=@text.Center,
        )
      }
    }
  }
}

///|
/// 表头行：每列一个格（底色 + 底边线 + 标题按列对齐 + 排序指示）。
/// `sort` 为 None 时不画箭头、点击无效；`table` 与 `table_v` 共用。
fn table_header(
  columns : Array[TableColumn],
  widths : Ref[Array[Double]],
  sort : @core.Store[TableSort]?,
  head_h : Double,
  on_resize? : ((Int, Double) -> Unit)? = None,
) -> @core.Widget {
  let head_font = @text.Font::new("", 13.0, weight=@text.SemiBold)
      let head = @core.Widget::new()
      head.node.set_flex_direction(@yoga.Row)
      head.node.set_height(@yoga.fixed(head_h))
      head.node.set_width(@yoga.percent(100.0))
      for j = 0; j < columns.length(); j = j + 1 {
        let col = columns[j]
        let idx = j
        let cell = @core.Widget::new()
        cell.node.set_width(@yoga.fixed(widths.val[j]))
        cell.node.set_height(@yoga.fixed(head_h))
        cell.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(@theme.theme_fill_zebra())
          p.fill_rect(0.0, 0.0, r.w, r.h)
          p.set_fill_color(@theme.theme_border())
          p.fill_rect(0.0, r.h - 1.0, r.w, 1.0)
          let pad_r = if col.sortable { 22.0 } else { 12.0 }
          let _ = @text.draw_box_at(
            p,
            10.0,
            0.0,
            (r.w - pad_r - 10.0).max(1.0),
            r.h,
            col.title,
            head_font,
            @theme.theme_text_primary(),
            align=col.align,
            valign=@text.Center,
          )

          if col.sortable {
            match sort {
              Some(s) => {
                let st = s.get()
                let cx = r.w - 14.0
                let cy = r.h / 2.0
                if st.column == idx {
                  // 实心三角：升序朝上、降序朝下
                  p.set_fill_color(@theme.theme_primary())
                  p.begin_path()
                  if st.asc {
                    p.move_to(cx - 5.0, cy + 2.0)
                    p.line_to(cx + 5.0, cy + 2.0)
                    p.line_to(cx, cy - 4.0)
                  } else {
                    p.move_to(cx - 5.0, cy - 2.0)
                    p.line_to(cx + 5.0, cy - 2.0)
                    p.line_to(cx, cy + 4.0)
                  }
                  p.close_path()
                  p.fill()
                } else if self.hovered {
                  // 灰色 ↕ 提示
                  p.set_fill_color(@theme.theme_text_secondary())
                  p.begin_path()
                  p.move_to(cx - 4.0, cy - 1.0)
                  p.line_to(cx + 4.0, cy - 1.0)
                  p.line_to(cx, cy - 5.0)
                  p.close_path()
                  p.fill()
                  p.begin_path()
                  p.move_to(cx - 4.0, cy + 1.0)
                  p.line_to(cx + 4.0, cy + 1.0)
                  p.line_to(cx, cy + 5.0)
                  p.close_path()
                  p.fill()
                }
              }
              None => ()
            }
          }
        })
        if col.sortable {
          cell.cursor = @core.CURSOR_HAND
          cell.on_pointer = Some(fn(
            self : @core.Widget,
            ev : @core.PointerEvent,
          ) -> Bool {
            match ev.kind {
              // 贴列边界那 3px 的按下让给表头（列宽拖动）：单元格自己吃下按下就
              // 轮不到父控件，可排序列的边界拖动会整个失效（真窗口实测）
              @core.Down =>
                !((idx > 0 && ev.x <= 3.0) ||
                  (idx < columns.length() - 1 && ev.x >= self.rect.w - 3.0))
              @core.Up => {
                match sort {
                  Some(s) => {
                    let st = s.get()
                    if st.column == idx {
                      if st.asc {
                        s.set({ column: idx, asc: false })
                      } else {
                        // 同列第三次：取消排序（使用方按 column < 0 恢复原始顺序）
                        s.set({ column: -1, asc: true })
                      }
                    } else {
                      s.set({ column: idx, asc: true })
                    }
                    @core.invalidate()
                  }
                  None => ()
                }
                false
              }
              _ => false
            }
          })
        }
        head.append_child(cell)
      }
  // ---- 列宽拖动：表头边界 ±3px 命中，按住拖动让相邻两列此消彼长 ----
  let drag : Ref[Int] = Ref(-1)
  let drag_start_x : Ref[Double] = Ref(0.0)
  let drag_left0 : Ref[Double] = Ref(0.0)
  let drag_right0 : Ref[Double] = Ref(0.0)
  head.on_pointer = Some(fn(
    self : @core.Widget,
    ev : @core.PointerEvent,
  ) -> Bool {
    match ev.kind {
      @core.Down => {
        let mut acc = 0.0
        let mut hit = -1
        for j = 0; j < widths.val.length() - 1; j = j + 1 {
          acc = acc + widths.val[j]
          if (ev.x - acc).abs() <= 3.0 {
            hit = j
          }
        }
        if hit >= 0 {
          drag.val = hit
          drag_start_x.val = ev.x
          drag_left0.val = widths.val[hit]
          drag_right0.val = widths.val[hit + 1]
          true
        } else {
          false
        }
      }
      @core.Move => {
        if drag.val >= 0 {
          let dx = ev.x - drag_start_x.val
          let total = drag_left0.val + drag_right0.val
          let nw = (drag_left0.val + dx).clamp(min=MIN_COL_W, max=total - MIN_COL_W)
          widths.val[drag.val] = nw
          widths.val[drag.val + 1] = total - nw
          self.kids[drag.val].node.set_width(@yoga.fixed(nw))
          self.kids[drag.val + 1].node.set_width(@yoga.fixed(total - nw))
          match on_resize {
            Some(f) => f(drag.val, nw)
            None => ()
          }
          @core.invalidate()
          true
        } else {
          false
        }
      }
      @core.Up => {
        if drag.val >= 0 {
          drag.val = -1
          true
        } else {
          false
        }
      }
      @core.Leave => false
    }
  })

  head
}
///|
/// 数据行控件（共用构造，注释见函数体上方）
///|
/// 数据行控件：斑马纹 / 悬停 / 选中（选中行主题浅底 + 左缘强调条），
/// 单元格按列宽排布，抬起且仍在本行内才切换选中并回调源下标。
fn table_row_widget(
  columns : Array[TableColumn],
  cols_w : Array[Double],
  row : TableRow,
  src : Int,
  row_height : Double,
  selection : @core.Store[Array[Int]]?,
  on_row_click : (Int, TableRow) -> Unit,
) -> @core.Widget {
  let font = @text.Font::new("", 13.0)
  let small_font = @text.Font::new("", 12.0)
          let row_w = @core.Widget::new()
          row_w.node.set_flex_direction(@yoga.Row)
          row_w.node.set_width(@yoga.percent(100.0))
          row_w.node.set_height(@yoga.fixed(row_height))
          row_w.on_draw = Some(fn(
            self : @core.Widget,
            p : @render.Painter,
            r : @core.Rect,
          ) -> Unit {
            let mut bg = if src % 2 == 0 {
              ""
            } else {
              @theme.theme_fill_zebra()
            }
            let mut selected = false
            match selection {
              Some(s) =>
                for k in s.get() {
                  if k == src {
                    selected = true
                  }
                }
              None => ()
            }
            if selected {
              bg = @theme.theme_primary_light()
            } else if self.hovered {
              bg = @theme.theme_fill_hover()
            }
            if bg.length() > 0 {
              p.set_fill_color(bg)
              p.fill_rect(0.0, 0.0, r.w, r.h)
            }
            if selected {
              p.set_fill_color(@theme.theme_primary())
              p.fill_rect(0.0, 0.0, 3.0, r.h)
            }
            p.set_fill_color(@theme.theme_border())
            p.fill_rect(0.0, r.h - 1.0, r.w, 1.0)
          })
          for j = 0; j < columns.length(); j = j + 1 {
            let col = columns[j]
            let cell = @core.Widget::new()
            cell.node.set_width(@yoga.fixed(cols_w[j]))
            cell.node.set_height(@yoga.fixed(row_height))
            let content = cell_of(row, j)
            cell.on_draw = Some(fn(
              _s : @core.Widget,
              p : @render.Painter,
              r : @core.Rect,
            ) -> Unit {
              draw_cell(p, content, r, col.align, font, small_font)
            })
            row_w.append_child(cell)
          }
          row_w.cursor = @core.CURSOR_HAND
          row_w.on_pointer = Some(fn(
            _s : @core.Widget,
            ev : @core.PointerEvent,
          ) -> Bool {
            match ev.kind {
              @core.Down => true
              @core.Up => {
                match selection {
                  Some(s) => {
                    let cur = s.get()
                    let next : Array[Int] = []
                    let mut found = false
                    for k in cur {
                      if k == src {
                        found = true
                      } else {
                        next.push(k)
                      }
                    }
                    if !found {
                      next.push(src)
                    }
                    s.set(next)
                  }
                  None => ()
                }
                on_row_click(src, row)
                @core.invalidate()
                false
              }
              _ => false
            }
          })
  row_w
}
///|
/// 表格（EP Table）：表头（标题 + 排序指示，点击可排序列切「新列升序 / 同列升降
/// 序反转 / 同列第三次取消」）+ 斑马纹数据行；`selection` 给定时行可点选（按下
/// 抬起同一行才生效），选中行主题浅底 + 左缘强调条。
pub fn table(
  columns : Array[TableColumn],
  rows : @core.Store[Array[TableRow]],
  width? : Double = 560.0,
  row_height? : Double = 36.0,
  selection? : @core.Store[Array[Int]],
  sort? : @core.Store[TableSort],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i : Int, _r : TableRow) -> Unit { () },
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let head_h = 40.0
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    match selection {
      Some(s) => follow_store(s)
      None => ()
    }
    match sort {
      Some(s) => follow_store(s)
      None => ()
    }

    w.node.set_flex_direction(@yoga.Column)
    w.node.set_width(@yoga.fixed(width))
    // 列宽是活的：表头拖动时改它，行内单元格跟着改宽（不重建树）
    let widths : Ref[Array[Double]] = Ref(table_widths(columns, width - 2.0))
    let body_cells : Ref[Array[Array[@core.Widget]]] = Ref([])
    w.on_draw = Some(fn(
      _s : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
    })
    // ---- 表头（共用构造） ----
    w.append_child(
      table_header(
        columns,
        widths,
        sort,
        head_h,
        on_resize=Some(fn(j : Int, nw : Double) -> Unit {
          for row_cells in body_cells.val {
            if j + 1 < row_cells.length() {
              row_cells[j].node.set_width(@yoga.fixed(nw))
              row_cells[j + 1].node.set_width(@yoga.fixed(widths.val[j + 1]))
            }
          }
        }),
      ),
    )
    // ---- 数据行（重建式） ----
    let body = @core.Widget::new()
    body.node.set_flex_direction(@yoga.Column)
    body.node.set_width(@yoga.percent(100.0))
    w.append_child(body)
    let render_all = fn() -> Unit {
      body.clear_children()
      body_cells.val = []
      let data = rows.get()
      for i = 0; i < data.length(); i = i + 1 {
        let src = i
        let row = data[i]
        let row_w = table_row_widget(
          columns,
          widths.val,
          row,
          src,
          row_height,
          selection,
          on_row_click,
        )

        body.append_child(row_w)
        body_cells.val.push(row_w.children())
      }
      @core.invalidate()
    }

    let sid = rows.signal().subscribe(fn(_v : Array[TableRow]) -> Unit {
      render_all()
    })
    @core.sub_bag_register(fn() { rows.signal().remove(sid) })
    render_all()
    fold_style(w, @style.empty_style(), class)
    handle(w)
    w
  })
}
