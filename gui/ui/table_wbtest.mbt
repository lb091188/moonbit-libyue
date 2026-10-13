// 表格回归：列宽分配、表头排序状态机、行选择、单元格类型出像素、
// 数据变更整表重建。

///|
fn table_rows(data : Array[Array[String]]) -> Array[TableRow] {
  let out : Array[TableRow] = []
  for r in data {
    out.push(TableRow::make(r))
  }
  out
}

///|
test "列宽：固定列按声明、弹性列均分剩余，总宽不够时弹性列取 0" {
  let cols = [
    TableColumn::make("名称", 120.0),
    TableColumn::make("说明", 0.0),
    TableColumn::make("操作", 0.0),
  ]
  let ws = table_widths(cols, 320.0)
  assert_eq((ws[0], ws[1], ws[2]), (120.0, 100.0, 100.0))
  let ws2 = table_widths(cols, 100.0)
  assert_eq((ws2[0], ws2[1], ws2[2]), (120.0, 0.0, 0.0))
  let all_fixed = [TableColumn::make("A", 60.0), TableColumn::make("B", 40.0)]
  assert_eq(table_widths(all_fixed, 500.0), [60.0, 40.0])
}

///|
test "表格：表头列数、斑马纹、行点选与取消、行回调带源下标" {
  let data = table_rows([["甲", "1"], ["乙", "2"], ["丙", "3"]])
  let rows = @core.Store::new(data)
  let sel : @core.Store[Array[Int]] = @core.Store::new([])
  let clicks : Array[Int] = []
  let (root, tb) = mounted(
    table_t(
      [TableColumn::make("名称", 120.0), TableColumn::make("值", 100.0)],
      rows,
      width=260.0,
      selection=sel,
      on_row_click=fn(i : Int, _r : TableRow) -> Unit { clicks.push(i) },
    ),
    360.0,
    300.0,
  )
  // 表头 + 表体
  assert_eq(tb.children().length(), 2)
  let head = tb.children()[0]
  let body = tb.children()[1]
  assert_eq(head.children().length(), 2)
  assert_eq(body.children().length(), 3)
  assert_eq((head.rect.h, body.children()[0].rect.h), (40.0, 36.0))
  // 斑马纹：偶数行不铺底、奇数行铺斑马色
  let bm = @render.Bitmap::new(360, 300)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let r0 = body.children()[0].rect
  let r1 = body.children()[1].rect
  assert_true(px(bm, (r0.x + 5.0).round().to_int(), (r0.y + 5.0).round().to_int()) != px(bm, (r1.x + 5.0).round().to_int(), (r1.y + 5.0).round().to_int()))
  // 点第 2 行：选中并回调源下标
  click_at(root, body.children()[1], 30.0, 18.0)
  assert_eq(clicks, [1])
  assert_eq(sel.get(), [1])
  let bm2 = @render.Bitmap::new(360, 300)
  let p2 = @render.Painter::new(bm2)
  root.paint(p2)
  p2.end()
  // 选中行底色变了，且左缘有 3px 强调条
  let before = px(bm, (r1.x + 5.0).round().to_int(), (r1.y + 5.0).round().to_int())
  let after = px(bm2, (r1.x + 5.0).round().to_int(), (r1.y + 5.0).round().to_int())
  assert_true(before != after)
  assert_true(px(bm2, (r1.x + 1.0).round().to_int(), (r1.y + 5.0).round().to_int()) != after)
  // 再点一次取消选中
  click_at(root, body.children()[1], 30.0, 18.0)
  assert_eq(sel.get(), [])
  assert_eq(clicks, [1, 1])
}

///|
test "表格：表头排序状态机（新列升序 / 同列翻转 / 同列第三次取消）" {
  let rows = @core.Store::new(table_rows([["甲", "1"], ["乙", "2"]]))
  let sort = @core.Store::new({ column: -1, asc: true })
  let (root, tb) = mounted(
    table_t(
      [
        TableColumn::make("名称", 120.0),
        TableColumn::make("值", 100.0, align=@text.End),
        TableColumn::make("备注", 80.0, sortable=false),
      ],
      rows,
      width=300.0,
      sort=sort,
    ),
    400.0,
    300.0,
  )
  let head = tb.children()[0]
  click_at(root, head.children()[0], 20.0, 20.0)
  assert_eq((sort.get().column, sort.get().asc), (0, true))
  click_at(root, head.children()[0], 20.0, 20.0)
  assert_eq((sort.get().column, sort.get().asc), (0, false))
  click_at(root, head.children()[0], 20.0, 20.0)
  assert_eq(sort.get().column, -1)
  // 换列：新列升序
  click_at(root, head.children()[1], 20.0, 20.0)
  assert_eq((sort.get().column, sort.get().asc), (1, true))
  // 不可排序列点了不动
  click_at(root, head.children()[2], 20.0, 20.0)
  assert_eq(sort.get().column, 1)
}

///|
test "表格：单元格类型（标签 / 色块 / 多行）都出像素，数据变更整表重建" {
  let rows = @core.Store::new([
    { cells: [CellText("行一"), CellTag("成功", Success), CellColorBox("#ff8800", "橙"), CellLines(["第一行", "第二行"])] },
  ])
  let (root, tb) = mounted(
    table_t(
      [
        TableColumn::make("名", 80.0, sortable=false),
        TableColumn::make("态", 80.0, sortable=false),
        TableColumn::make("色", 90.0, sortable=false),
        TableColumn::make("多行", 110.0, sortable=false),
      ],
      rows,
      width=360.0,
    ),
    420.0,
    300.0,
  )
  let body = tb.children()[1]
  assert_eq(body.children().length(), 1)
  let bm = @render.Bitmap::new(420, 300)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let cells = body.children()[0].children()
  assert_eq(cells.length(), 4)
  // 标签单元格里有浅底像素（与行底不同）
  let tag_rect = cells[1].rect
  let tag_px = px(bm, (tag_rect.x + 10.0).round().to_int(), (tag_rect.y + 10.0).round().to_int())
  let row_px = px(bm, (cells[0].rect.x + 40.0).round().to_int(), (tag_rect.y + 2.0).round().to_int())
  assert_true(tag_px != row_px)
  // 色块单元格里出现该颜色的像素
  let color_rect = cells[2].rect
  let mut found = false
  for x = (color_rect.x + 10.0).round().to_int(); x < (color_rect.x + 24.0).round().to_int(); x = x + 1 {
    for y = (color_rect.y + 8.0).round().to_int(); y < (color_rect.y + 24.0).round().to_int(); y = y + 1 {
      let c = px(bm, x, y)
      if c == (0xFF, 0x88, 0x00, 0xFF) {
        found = true
      }
    }
  }
  assert_eq(found, true)
  // 数据变更：整表重建
  rows.set(table_rows([["一"], ["二"], ["三"], ["四"]]))
  assert_eq(body.children().length(), 4)
}

///|
test "表格：表头边界拖动改列宽，相邻两列此消彼长且有最小列宽" {
  let rows = @core.Store::new(table_rows([["甲", "1"], ["乙", "2"]]))
  let (root, tb) = mounted(
    table_t(
      [
        // 可排序列：单元格会消费按下，边界那 3px 必须让给表头才拖得动
        TableColumn::make("名", 120.0),
        TableColumn::make("值", 100.0),
        TableColumn::make("备注", 0.0),
      ],
      rows,
      width=320.0,
    ),
    400.0,
    300.0,
  )
  let head = tb.children()[0]
  let body = tb.children()[1]
  assert_eq(head.children()[0].rect.w, 120.0)
  // 第一列右缘在 head.x+120：按下命中边界
  let boundary_x = head.rect.x + 120.0
  let _ = root.dispatch_pointer({
    kind: @core.Down,
    x: boundary_x,
    y: head.rect.y + 20.0,
    button: 1,
    mods: 0,
  })
  // 往右拖 40：第一列 160、第二列 60（被拖的两列此消彼长）
  let _ = root.dispatch_pointer_to(head.id, {
    kind: @core.Move,
    x: boundary_x + 40.0,
    y: head.rect.y + 20.0,
    button: 1,
    mods: 0,
  })
  root.relayout(400.0, 300.0)
  assert_eq(head.children()[0].rect.w, 160.0)
  assert_eq(head.children()[1].rect.w, 60.0)
  // 数据行的单元格跟着改宽（不重建树）
  assert_eq(body.children()[0].children()[0].rect.w, 160.0)
  assert_eq(body.children()[0].children()[1].rect.w, 60.0)
  // 继续往右拖到越界：第二列夹在最小列宽 40
  let _ = root.dispatch_pointer_to(head.id, {
    kind: @core.Move,
    x: boundary_x + 500.0,
    y: head.rect.y + 20.0,
    button: 1,
    mods: 0,
  })
  root.relayout(400.0, 300.0)
  assert_eq(head.children()[1].rect.w, 40.0)
  assert_eq(head.children()[0].rect.w, 180.0)
  // 松手后再移动不再改
  let _ = root.dispatch_pointer_to(head.id, {
    kind: @core.Up,
    x: boundary_x + 500.0,
    y: head.rect.y + 20.0,
    button: 1,
    mods: 0,
  })
  let _ = root.dispatch_pointer_to(head.id, {
    kind: @core.Move,
    x: boundary_x + 120.0,
    y: head.rect.y + 20.0,
    button: 1,
    mods: 0,
  })
  root.relayout(400.0, 300.0)
  assert_eq(head.children()[0].rect.w, 180.0)
}

///|
test "排序口径：数值优先（12 排在 6 之后）、字典序兜底、升降序与取消" {
  // 数值优先：纯字典序会把 "12 处" 排到 "6 处" 前面
  assert_true(compare_cells("12 处", "6 处") > 0)
  assert_true(compare_cells("6 处", "12 处") < 0)
  // 数字与单位混排、带符号
  assert_true(compare_cells("虚拟行 3", "虚拟行 12") < 0)
  assert_true(compare_cells("-4", "2") < 0)
  // 摘不出数字的按字典序
  assert_true(compare_cells("待修", "通过") < 0)
  // 数值相等回落字典序（全序，不会因相等键乱序）
  assert_true(compare_cells("3", "3 处") < 0)
  assert_eq(compare_cells("同一个", "同一个"), 0)

  let rows = table_rows([["丙", "12 处"], ["甲", "6 处"], ["乙", "24 处"]])
  let names = fn(rs : Array[TableRow]) -> Array[String] {
    let out : Array[String] = []
    for r in rs {
      out.push(cell_text(r, 0))
    }
    out
  }
  // 升序：6 < 12 < 24 → 甲/丙/乙
  assert_eq(names(sort_rows(rows, { column: 1, asc: true })), ["甲", "丙", "乙"])
  // 降序翻转
  assert_eq(names(sort_rows(rows, { column: 1, asc: false })), ["乙", "丙", "甲"])
  // column < 0 = 取消排序：原样（且入参未被改动）
  assert_eq(names(sort_rows(rows, { column: -1, asc: true })), ["丙", "甲", "乙"])
  assert_eq(names(rows), ["丙", "甲", "乙"])
  // 列越界（比列数大）不越界读：全空键 → 保持原序
  assert_eq(names(sort_rows(rows, { column: 9, asc: true })), ["丙", "甲", "乙"])
}

///|
test "排序稳定性：同键保持原相对顺序" {
  let rows = table_rows([["甲", "就绪"], ["乙", "排队"], ["丙", "就绪"], ["丁", "排队"]])
  let names = fn(rs : Array[TableRow]) -> Array[String] {
    let out : Array[String] = []
    for r in rs {
      out.push(cell_text(r, 0))
    }
    out
  }
  // 状态列同键成片：升序后两组内部仍是原顺序（就绪 < 排队）
  assert_eq(names(sort_rows(rows, { column: 1, asc: true })), ["甲", "丙", "乙", "丁"])
  assert_eq(names(sort_rows(rows, { column: 1, asc: false })), ["乙", "丁", "甲", "丙"])
}
