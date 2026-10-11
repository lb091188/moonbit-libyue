// 表格：`TableColumn`/`TableRow` 模型 + `table_t`（表头排序指示、斑马纹、悬停、
// 行选择、按列宽排布），列宽与排序状态都走 `Store`（组件只切状态与画箭头，
// **不替调用方排序**——排序口径由使用方决定，见 `TableSort` 注释）。
//
// 行是「重建式列表」（与 `transfer` 同款）：数据 Store 一变就清空子控件按新值再挂，
// 行级不持订阅，所以重建次数与订阅数量解耦；万行级形态见 `table_v_t`（虚拟滚动，
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
/// `rows`**（排序口径因业务而异：数字、字典序、自定义比较都归使用方）。
pub(all) struct TableSort {
  column : Int
  asc : Bool
}

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
/// 表格（EP Table）：表头（标题 + 排序指示，点击可排序列切「新列升序 / 同列升降
/// 序反转 / 同列第三次取消」）+ 斑马纹数据行；`selection` 给定时行可点选（按下
/// 抬起同一行才生效），选中行主题浅底 + 左缘强调条。
pub fn table_t(
  columns : Array[TableColumn],
  rows : @core.Store[Array[TableRow]],
  width? : Double = 560.0,
  row_height? : Double = 36.0,
  selection? : @core.Store[Array[Int]],
  sort? : @core.Store[TableSort],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i : Int, _r : TableRow) -> Unit { () },
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let head_h = 40.0
  let font = @text.Font::new("", 13.0)
  let head_font = @text.Font::new("", 13.0, weight=@text.SemiBold)
  let small_font = @text.Font::new("", 12.0)
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
    let cols_w = table_widths(columns, width - 2.0)
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
    // ---- 表头 ----
    let head = @core.Widget::new()
    head.node.set_flex_direction(@yoga.Row)
    head.node.set_height(@yoga.fixed(head_h))
    head.node.set_width(@yoga.percent(100.0))
    for j = 0; j < columns.length(); j = j + 1 {
      let col = columns[j]
      let idx = j
      let cell = @core.Widget::new()
      cell.node.set_width(@yoga.fixed(cols_w[j]))
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
        cell.on_pointer = Some(fn(
          _s : @core.Widget,
          ev : @core.PointerEvent,
        ) -> Bool {
          match ev.kind {
            @core.Down => true
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

    w.append_child(head)
    // ---- 数据行（重建式） ----
    let body = @core.Widget::new()
    body.node.set_flex_direction(@yoga.Column)
    body.node.set_width(@yoga.percent(100.0))
    w.append_child(body)
    let render_all = fn() -> Unit {
      body.clear_children()
      let data = rows.get()
      for i = 0; i < data.length(); i = i + 1 {
        let src = i
        let row = data[i]
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
        body.append_child(row_w)
      }
      @core.invalidate()
    }

    let sid = rows.signal().subscribe(fn(_v : Array[TableRow]) -> Unit {
      render_all()
    })
    @core.sub_bag_register(fn() { rows.signal().remove(sid) })
    render_all()
    handle(w)
    w
  })
}
