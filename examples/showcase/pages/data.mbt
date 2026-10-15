// 数据展示页：展示族 + 表格族。访问量/进度条是 App.counter 的 computed 派生
// （基础页按钮与「统计进度」段按钮同源触发）；表格行数组走 Store（组件参数
// 类型），选中回显等标量走本地 Store。
//
// G7 迁移记档（与 master 的差异）：
// ① `statistic` 在本栈吃 String 快照（不是 Store 驱动）——「访问量」的联动
//    改用 `bind_label` 展示派生信号，statistic 只做静态形态演示；
// ② `card(title, children, style=[height])` → `card(children, title=)`，
//    高度交给内容（旧 CSS 高度通道不存在）；
// ③ 表头对齐从 `@yue.Center/End` → `@text.TextAlign`；
// ④ 富单元格结构 `TableRow`/`TableCell` 是 pub(all)，跨包字面量直接可用。
fn data_cell_key(v : @ui.TableCell) -> String {
  match v {
    @ui.CellText(s) => s
    _ => ""
  }
}

///|
/// 演示用的无符号数字串比较（序号列）：无前导零时「先比长度再比字典序」
/// 即数值序，省得为例子引 parse 依赖。
fn data_cmp_num_str(a : String, b : String) -> Int {
  if a.length() != b.length() {
    if a.length() < b.length() {
      -1
    } else {
      1
    }
  } else if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|

///|
/// 粘性列表演示行：每组四行普通文本行。
fn sticky_rows(g : Int) -> Array[@core.Node] {
  let rows : Array[@core.Node] = []
  for i = 0; i < 4; i = i + 1 {
    let label = "第 \{g} 组 · 第 \{i + 1} 行（滚动时看顶部吸顶条）"
    rows.push(@ui.text(label, role=@ui.Body))
  }
  rows
}

pub fn page_data(app : @shared.App) -> @core.Node {
  // 语言表基础数据 + 排序显示数据（表头点击写 sort，订阅里重排）
  let lang_base : Array[@ui.TableRow] = [
    @ui.TableRow::make(["MoonBit", "2023", "多范式,云 + 端"]),
    @ui.TableRow::make(["Rust", "2015", "系统编程"]),
    @ui.TableRow::make(["Go", "2012", "云原生后端"]),
    @ui.TableRow::make(["TypeScript", "2012", "前端大规模工程"]),
  ]
  // 初值给一份**快照**：Store 的内建去重按值比，若存的就是 `lang_base` 这个对象，
  // 「添加一行」原地 push 之后再 set，新旧值是同一个数组 ⇒ 通知被吞、整表不重建
  let table_rows : @core.Store[Array[@ui.TableRow]] = @core.Store::new(
    lang_base.copy(),
  )
  let table_sort : @core.Store[@ui.TableSort] = @core.Store::new({ column: -1, asc: true })
  fn reorder_langs() -> Unit {
    let st = table_sort.get()
    if st.column < 0 || st.column >= lang_base[0].cells.length() {
      // 必须给快照：把 lang_base 本体 set 进去的话，之后原地 push 再 set
      // 新旧是同一个数组，Store 去重把通知吞掉，「添加一行」只在第一次生效
      table_rows.set(lang_base.copy())
      return
    }
    let rows = lang_base.copy()
    rows
    .mut_view()
    .sort_by(fn(a, b) {
      let ka = data_cell_key(a.cells[st.column])
      let kb = data_cell_key(b.cells[st.column])
      let c = if ka < kb { -1 } else if ka > kb { 1 } else { 0 }
      if st.asc {
        c
      } else {
        -c
      }
    })
    table_rows.set(rows)
  }

  table_sort.subscribe(fn(_st) { reorder_langs() })
  let table_picked : @core.Store[String] = @core.Store::new("未选中")
  let table_sel : @core.Store[Array[Int]] = @core.Store::new([])
  let rich_base : Array[@ui.TableRow] = [
    {
      cells: [
        @ui.CellText("MoonBit"),
        @ui.CellTag("编译型", @ui.Primary),
        @ui.CellColorBox("#2D68C4", "主题蓝"),
        @ui.CellLines(["多范式", "云 + 端"]),
      ],
    },
    {
      cells: [
        @ui.CellText("Rust"),
        @ui.CellTag("编译型", @ui.Primary),
        @ui.CellColorBox("#D9822B", "主题橙"),
        @ui.CellLines(["系统编程", "无 GC"]),
      ],
    },
    {
      cells: [
        @ui.CellText("Python"),
        @ui.CellTag("解释型", @ui.Warning),
        @ui.CellColorBox("#2E9E5B", "主题绿"),
        @ui.CellLines(["脚本", "AI 生态"]),
      ],
    },
  ]
  let rich_rows : @core.Store[Array[@ui.TableRow]] = @core.Store::new(rich_base)
  let rich_sort : @core.Store[@ui.TableSort] = @core.Store::new({ column: -1, asc: true })
  rich_sort.subscribe(fn(st) {
    if st.column != 0 {
      rich_rows.set(rich_base)
      return
    }
    let rows = rich_base.copy()
    rows
    .mut_view()
    .sort_by(fn(a, b) {
      let ka = data_cell_key(a.cells[0])
      let kb = data_cell_key(b.cells[0])
      let c = if ka < kb { -1 } else if ka > kb { 1 } else { 0 }
      if st.asc {
        c
      } else {
        -c
      }
    })
    rich_rows.set(rows)
  })
  let v_rows_data : Array[@ui.TableRow] = []
  for i in 0..<10000 {
    v_rows_data.push(
      @ui.TableRow::make([
        (i + 1).to_string(),
        "条目 \{i + 1}",
        if i % 3 == 0 {
          "甲组"
        } else if i % 3 == 1 {
          "乙组"
        } else {
          "丙组"
        },
        "虚拟滚动演示行",
      ]),
    )
  }
  let v_rows : @core.Store[Array[@ui.TableRow]] = @core.Store::new(v_rows_data)
  let v_sort : @core.Store[@ui.TableSort] = @core.Store::new({ column: -1, asc: true })
  v_sort.subscribe(fn(st) {
    if st.column < 0 || st.column >= 4 {
      v_rows.set(v_rows_data)
      return
    }
    let rows = v_rows_data.copy()
    rows
    .mut_view()
    .sort_by(fn(a, b) {
      let ka = data_cell_key(a.cells[st.column])
      let kb = data_cell_key(b.cells[st.column])
      let c = if st.column == 0 {
        data_cmp_num_str(ka, kb)
      } else if ka < kb {
        -1
      } else if ka > kb {
        1
      } else {
        0
      }
      if st.asc {
        c
      } else {
        -c
      }
    })
    v_rows.set(rows)
  })
  let transfer_left : @core.Store[Array[String]] = @core.Store::new(["北京", "上海", "广州"])
  let transfer_right : @core.Store[Array[String]] = @core.Store::new(["深圳"])
  @shared.page([
    @shared.section(
      "标签徽标",
      "Tag 标签、Avatar 头像与 Badge 徽标",
      "五种语义 Tag（浅底深字）+ 自定义实底色；Avatar 方形实底 + 白色字母，四种尺寸；徽标有数字角标（红底白字，99+ 封顶）与圆点两种形态。",
      [
        @ui.row(
          [
            @ui.tag_of_type("Primary", @ui.Primary),
            @ui.tag_of_type("Success", @ui.Success),
            @ui.tag_of_type("Warning", @ui.Warning),
            @ui.tag_of_type("Danger", @ui.Danger),
            @ui.tag_of_type("Info", @ui.Info),
            @ui.tag("自定义实底", "#2D68C4"),
            @ui.tag("v0.1.0", "#2E9E5B"),
          ],
          column_gap=6.0,
        ),
        @ui.row(
          [
            @ui.avatar("M", size=44.0, background_color="#2D68C4"),
            @ui.avatar("N", size=36.0, background_color="#2E9E5B"),
            @ui.avatar("X", size=30.0, background_color="#D64550"),
            @ui.avatar("L", size=26.0, background_color="#D9822B"),
          ],
          column_gap=10.0,
        ),
        @ui.row(
          [
            @ui.badge_count(9),
            @ui.badge_count(128),
            @ui.text("消息", role=@ui.Body),
            @ui.badge_dot(),
            @ui.text("在线", role=@ui.Body),
          ],
          column_gap=16.0,
        ),
      ],
      code=[
        "@ui.tag_of_type(\"Primary\", @ui.Primary)",
        "@ui.tag(\"自定义实底\", \"#2D68C4\")",
        "@ui.avatar(\"M\", size=44.0, background_color=\"#2D68C4\")",
        "@ui.badge_count(9)",
        "@ui.badge_dot()",
      ],
    ),
    @shared.section(
      "统计进度",
      "Statistic 数值统计与 Progress 进度条",
      "statistic 是静态快照形态（联动展示走 bind_label）；进度条主题色填充 + 浅灰轨道，与基础页按钮同源联动。",
      [
        @ui.row(
          [
            @ui.statistic("任务数", "36"),
            @ui.statistic("版本", "0.1.0"),
            @ui.col(
              [
                @ui.bind(app.visits, fn(s) { "访问量 \{s}" }),
                @ui.text("由基础页与下方按钮联动", role=@ui.Secondary),
              ],
              row_gap=2.0,
            ),
          ],
          column_gap=40.0,
        ),
        @ui.row(
          [
            @ui.button("刷新访问量", variant=@ui.Solid, on_click=fn() {
              app.counter.update(fn(n) { n + 1 })
            }),
            @ui.progress_line(app.ratio.store()),
            @ui.bind(app.ratio, fn(v) { "当前进度 \{(v * 100.0).round()}%" }),
          ],
          column_gap=16.0,
        ),
      ],
      code=[
        "@ui.statistic(\"任务数\", \"36\")",
        "@ui.progress_line(ratio.store())",
        "@ui.bind_label(ratio, fn(v) { \"当前进度 \\{(v * 100.0).round()}%\" })",
      ],
    ),
    @shared.section(
      "卡片折叠",
      "Card 卡片与 Collapse 折叠面板",
      "标题栏 + 底部分隔线 + 边框；折叠面板点击标题展开/收起，各面板独立，初始第一个展开。",
      [
        @ui.col(
          [
            @ui.card([@ui.text("卡片内容：组件库全部用 theme_* 主题色着色。", role=Body)], title="卡片标题"),
            @ui.collapse([
              ("如何使用组件库？", [@ui.text("moon add NoahLiu/native-gui 后即可用 @ui.* 访问。", role=Body)]),
              ("支持哪些平台？", [@ui.text("Linux (X11) / Windows；macOS 进行中。", role=Body)]),
            ]),
          ],
          row_gap=10.0,
        ),
      ],
      code=[
        "@ui.card([@ui.text(\"卡片内容\")], title=\"卡片标题\")",
        "@ui.collapse([",
        "  (\"如何使用组件库？\", [@ui.text(\"moon add 后即可用 @ui.*\")]),",
        "  (\"支持哪些平台？\", [@ui.text(\"Linux / Windows\")]),",
        "])",
      ],
    ),
    @shared.section(
      "描述时间线",
      "Descriptions 与 Timeline",
      "键灰值深的键值网格；左侧色点 + 竖线，节点颜色跟随语义类型，末项无连线。",
      [
        @ui.col(
          [
            @ui.descriptions([
              ("框架", "native-gui"),
              ("渲染", "Cairo (Linux) / D2D (Windows)"),
              ("组件层", "纯 MoonBit，零平台代码"),
            ]),
            @ui.timeline([
              ("发布 0.1.0", "自绘栈占位上架。", @ui.Success),
              ("G7 进行中", "组件库演示板迁移。", @ui.Primary),
              ("规划中", "菜单/托盘/媒体线收口。", @ui.Warning),
            ]),
          ],
          row_gap=12.0,
        ),
      ],
      code=[
        "@ui.descriptions([(\"框架\", \"native-gui\"), (\"渲染\", \"Cairo / D2D\")])",
        "@ui.timeline([(\"发布 0.1.0\", \"自绘栈占位上架。\", @ui.Success)])",
      ],
    ),
    @shared.section(
      "表格",
      "Table 表格（单选与多选）",
      "表头 + 斑马纹 + 悬停底色，拖动列边界调整列宽，点击表头排序（升降序箭头，新列默认升序）。上表单选：点击行单选，Store 驱动「添加一行」整表重建，选中行回显；下表多选：复选框列，行点击勾选，表头全选/清空（部分选中画横条）。",
      [
        @ui.col(
          [
            @ui.table(
              [
                @ui.TableColumn::make("语言", 140.0),
                @ui.TableColumn::make("首发", 90.0, align=@text.Center),
                @ui.TableColumn::make("定位", 0.0),
              ],
              table_rows,
              width=440.0,
              sort=table_sort,
              on_row_click=fn(i, r) {
                let name = match r.cells[0] {
                  @ui.CellText(s) => s
                  _ => ""
                }
                table_picked.set("第 \{i + 1} 行：\{name}")
              },
            ),
            @ui.row(
              [
                @ui.button("添加一行", on_click=fn() {
                  let n = lang_base.length() + 1
                  lang_base.push(
                    @ui.TableRow::make(["新语言 \{n}", "2026", "演示 Store 驱动"]),
                  )
                  reorder_langs()
                }),
                @ui.bind_label(table_picked, fn(s) { s }),
              ],
              column_gap=12.0,
            ),
          ],
          row_gap=8.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
        @ui.col(
          [
            @ui.table(
              [
                @ui.TableColumn::make("语言", 120.0),
                @ui.TableColumn::make("类型", 100.0, sortable=false),
                @ui.TableColumn::make("色板", 110.0, sortable=false),
                @ui.TableColumn::make("特性", 0.0, sortable=false),
              ],
              rich_rows,
              selection=table_sel,
              width=460.0,
              sort=rich_sort,
            ),
            @ui.bind(table_sel.signal(), fn(s) { "已选 \{s.length()} 行" }),
          ],
          row_gap=8.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "// 单选：点击行回显（on_row_click）",
        "let rows = @core.Store::new([",
        "  @ui.TableRow::make([\"MoonBit\", \"2023\", \"多范式\"]),",
        "])",
        "let sort = @core.Store::new({ column: -1, asc: true })",
        "@ui.table(",
        "  [",
        "    @ui.TableColumn::make(\"语言\", 140.0),",
        "    @ui.TableColumn::make(\"首发\", 90.0, align=@text.Center),",
        "    @ui.TableColumn::make(\"定位\", 0.0),  // 0 = 占满剩余宽",
        "  ],",
        "  rows, width=440.0, sort=sort,",
        "  on_row_click=fn(i, _r) { () },",
        ")",
        "// 多选：复选框列（selection）",
        "let sel : @core.Store[Array[Int]] = @core.Store::new([])",
        "@ui.table(columns, rows, selection=sel, width=460.0)",
        "@ui.bind(sel.signal(), fn(s) { \"已选 \\{s.length()} 行\" })",
      ],
    ),
    @shared.section(
      "虚拟滚动",
      "Table 虚拟滚动",
      "整面自绘只画可见行，万行流畅；点击表头排序（序号列按数值），拖动列边界调整列宽；滚轮/拖右侧滚动条/键盘翻页。",
      [
        @ui.table_v(
          [
            @ui.TableColumn::make("序号", 90.0, align=@text.End),
            @ui.TableColumn::make("名称", 160.0),
            @ui.TableColumn::make("分组", 110.0, align=@text.Center),
            @ui.TableColumn::make("备注", 0.0),
          ],
          v_rows,
          width=520.0,
          height=220.0,
          sort=v_sort,
        ),
      ],
      code=[
        "let data : Array[@ui.TableRow] = []",
        "for i in 0..<10000 { data.push(@ui.TableRow::make([(i + 1).to_string(), \"条目 \\{i + 1}\"])) }",
        "@ui.table_v(columns, @core.Store::new(data), width=520.0, height=220.0)",
      ],
    ),
    @shared.section(
      "树形",
      "Tree 树形控件",
      "缩进层级 + 点击展开/折叠（▸/▾）。",
      [
        @ui.tree([
          {
            label: "src",
            children: [
              { label: "table.mbt", children: [] },
              { label: "nav", children: [{ label: "nav.mbt", children: [] }] },
            ],
          },
          { label: "docs", children: [{ label: "components.md", children: [] }] },
        ]),
      ],
      code=[
        "@ui.tree([",
        "  { label: \"src\", children: [{ label: \"table.mbt\", children: [] }] },",
        "  { label: \"docs\", children: [] },",
        "])",
      ],
    ),
    @shared.section(
      "穿梭轮播",
      "Transfer 穿梭框与 Carousel 轮播",
      "穿梭框：点击行选中，中间 ›/‹ 移对侧；轮播：箭头/圆点手动切，3 秒自动切换（悬停暂停）。",
      [
        @ui.row(
          [
            @ui.transfer(transfer_left, transfer_right),
            @ui.carousel(
              [
                @ui.text("第一屏：轮播内容可为任意 Node。", role=@ui.Body),
                @ui.text("第二屏：自动轮播 3s 一切。", role=@ui.Body),
                @ui.text("第三屏：悬停暂停，箭头/圆点手动切。", role=@ui.Body),
              ],
              width=320.0,
              height=80.0,
            ),
          ],
          column_gap=20.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "let left = @core.Store::new([\"北京\", \"上海\", \"广州\"])",
        "let right = @core.Store::new([\"深圳\"])",
        "@ui.transfer(left, right)",
        "@ui.carousel([@ui.text(\"第一屏\")], width=320.0, height=80.0)",
      ],
    ),
    @shared.section(
      "空状态",
      "Empty 空状态",
      "占位图 + 说明文字。",
      [@ui.empty(description="这里还没有内容")],
      code=["@ui.empty(\"这里还没有内容\")"],
    ),

    @shared.section(
      "粘性列表",
      "吸顶分组列表",
      "分组标题在滚动时吸顶——悬浮在视口顶部的那条始终显示「当前组」，滚过组边界就换文字；组高由内容决定，当前组是每帧读布局结果反推的，不是事先累加高度。",
      [
        @ui.sticky_list(
          [
            ("第一组 · 概览", sticky_rows(1)),
            ("第二组 · 明细", sticky_rows(2)),
            ("第三组 · 汇总", sticky_rows(3)),
          ],
          @ui.StickyList::new(),
          width=520.0,
          height=240.0,
        ),
      ],
      code=[
        "@ui.sticky_list(",
        "  [(\"第一组\", rows_1), (\"第二组\", rows_2)],",
        "  @ui.StickyList::new(),",
        "  width=520.0,",
        "  height=240.0,",
        ")",
      ],
    ),
  ])
}
