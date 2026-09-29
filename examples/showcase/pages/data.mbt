// 数据展示页:Signal 驱动。访问量/进度条是 App.counter 的 computed
// 派生(基础页按钮触发);表格行数组等容器型状态仍走 Store(组件
// 参数类型),选中回显等标量走信号。

///|
/// 表格单元格的排序键(演示排序用:演示表格只有 CellText,其余取空串)。
fn cell_key(v : @yue.TableCell) -> String {
  match v {
    @yue.CellText(s) => s
    _ => ""
  }
}

///|
/// 演示用的无符号数字串比较(序号列):无前导零时「先比长度再比
/// 字典序」即数值序,省得为例子引 parse 依赖。
fn cmp_num_str(a : String, b : String) -> Int {
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
pub fn page_data(app : @ui.App) -> @yue.Node {
  // 语言表基础数据 + 排序显示数据(表头点击写 sort,订阅里重排)
  let lang_base = [
    @yue.TableRow::make(["MoonBit", "2023", "多范式,云 + 端"]),
    @yue.TableRow::make(["Rust", "2015", "系统编程"]),
    @yue.TableRow::make(["Go", "2012", "云原生后端"]),
    @yue.TableRow::make(["TypeScript", "2012", "前端大规模工程"]),
  ]
  let table_rows : @yue.Store[Array[@yue.TableRow]] = @yue.Store::new(lang_base)
  let table_sort : @yue.Store[@yue.TableSort] = @yue.Store::new(@yue.TableSort::{
    column: -1,
    asc: true,
  })
  fn reorder_langs() -> Unit {
    let st = table_sort.get()
    if st.column < 0 || st.column >= lang_base[0].cells.length() {
      table_rows.set(lang_base)
      return
    }
    let rows = lang_base.copy()
    rows
    .mut_view()
    .sort_by(fn(a, b) {
      let ka = cell_key(a.cells[st.column])
      let kb = cell_key(b.cells[st.column])
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
  let table_picked = @yue.Signal::new("未选中")
  let table_sel : @yue.Store[Array[Int]] = @yue.Store::new([])
  let rich_base : Array[@yue.TableRow] = [
    {
      cells: [
        @yue.CellText("MoonBit"),
        @yue.CellTag("编译型", @yue.Primary),
        @yue.CellColorBox("#2D68C4", "主题蓝"),
        @yue.CellLines(["多范式", "云 + 端"]),
      ],
    },
    {
      cells: [
        @yue.CellText("Rust"),
        @yue.CellTag("编译型", @yue.Primary),
        @yue.CellColorBox("#D9822B", "主题橙"),
        @yue.CellLines(["系统编程", "无 GC"]),
      ],
    },
    {
      cells: [
        @yue.CellText("Python"),
        @yue.CellTag("解释型", @yue.Warning),
        @yue.CellColorBox("#2E9E5B", "主题绿"),
        @yue.CellLines(["脚本", "AI 生态"]),
      ],
    },
  ]
  let rich_rows : @yue.Store[Array[@yue.TableRow]] = @yue.Store::new(rich_base)
  let rich_sort : @yue.Store[@yue.TableSort] = @yue.Store::new(@yue.TableSort::{
    column: -1,
    asc: true,
  })
  rich_sort.subscribe(fn(st) {
    if st.column != 0 {
      rich_rows.set(rich_base)
      return
    }
    let rows = rich_base.copy()
    rows
    .mut_view()
    .sort_by(fn(a, b) {
      let ka = match a.cells[0] {
        @yue.CellText(t) => t
        _ => ""
      }
      let kb = match b.cells[0] {
        @yue.CellText(t) => t
        _ => ""
      }
      let c = if ka < kb { -1 } else if ka > kb { 1 } else { 0 }
      if st.asc {
        c
      } else {
        -c
      }
    })
    rich_rows.set(rows)
  })
  let v_rows_data : Array[@yue.TableRow] = []
  for i in 0..<10000 {
    v_rows_data.push(
      @yue.TableRow::make([
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
  let v_rows : @yue.Store[Array[@yue.TableRow]] = @yue.Store::new(v_rows_data)
  // 虚拟表排序:序号列(0)按数值,其余按文本;表头点击写 Store,订阅里重排
  let v_sort : @yue.Store[@yue.TableSort] = @yue.Store::new(@yue.TableSort::{
    column: -1,
    asc: true,
  })
  v_sort.subscribe(fn(st) {
    if st.column < 0 || st.column >= 4 {
      v_rows.set(v_rows_data)
      return
    }
    let rows = v_rows_data.copy()
    rows
    .mut_view()
    .sort_by(fn(a, b) {
      let ka = cell_key(a.cells[st.column])
      let kb = cell_key(b.cells[st.column])
      let c = if st.column == 0 {
        cmp_num_str(ka, kb)
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
  let transfer_left : @yue.Store[Array[String]] = @yue.Store::new([
    "北京", "上海", "广州",
  ])
  let transfer_right : @yue.Store[Array[String]] = @yue.Store::new(["深圳"])
  @ui.page([
    @ui.section(
      "标签头像",
      "Tag 标签与 Avatar 头像",
      "五种语义 Tag(浅底深字)+ 自定义实底色,宽度自适应;Avatar 方形实底 + 白色字母,三种尺寸。",
      [
        @yue.hbox(
          [
            @yue.tag_of_type("Primary", @yue.Primary),
            @yue.tag_of_type("Success", @yue.Success),
            @yue.tag_of_type("Warning", @yue.Warning),
            @yue.tag_of_type("Danger", @yue.Danger),
            @yue.tag_of_type("Info", @yue.Info),
            @yue.tag("自定义实底", "#2D68C4"),
            @yue.tag("v1.0", "#2E9E5B"),
          ],
          style=[("alignItems", "center")],
        ),
        @yue.hbox(
          [
            @yue.avatar("M", "#2D68C4", size=44.0),
            @yue.avatar("N", "#2E9E5B", size=36.0),
            @yue.avatar("X", "#D64550", size=30.0),
            @yue.avatar("L", "#D9822B", size=26.0),
          ],
          style=[("marginTop", 10.0), ("alignItems", "center")],
        ),
      ],
      code=[
        "// 五种语义 Tag(浅底深字)+ 自定义实底色",
        "// tag_of_type(文本, 语义类型):类型浅底 + 同族深字,直角,宽度按文本自适应",
        "@yue.tag_of_type(\"Primary\", @yue.Primary)",
        "@yue.tag_of_type(\"Success\", @yue.Success)",
        "// tag(文本, 实底色, height?=24.0):自定色实底白字标签,宽度按文本自适应",
        "@yue.tag(\"自定义实底\", \"#2D68C4\")",
        "// Avatar:方形实底 + 白色字母,三种尺寸",
        "// avatar(字母, 实底色, size?=36.0):size 为方块边长,字母白色居中",
        "@yue.avatar(\"M\", \"#2D68C4\", size=44.0)",
        "@yue.avatar(\"X\", \"#D64550\", size=30.0)",
      ],
    ),
    @ui.section(
      "徽标",
      "Badge 徽标",
      "数字角标(红底白字,宽度自适应)与圆点两种形态。",
      [
        @yue.hbox(
          [
            @yue.badge_count(9),
            @yue.badge_count(128),
            @yue.label_t("消息", role=@yue.Body),
            @yue.label("      "),
            @yue.badge_dot(),
            @yue.label_t("在线", role=@yue.Body),
          ],
          style=[("alignItems", "center")],
        ),
      ],
      code=[
        "// 数字角标(红底白字,宽度自适应)与圆点两种形态",
        "// badge_count(数值:Int):数字转文本画红底白字角标,宽度随文本自适应",
        "@yue.badge_count(9)",
        "@yue.badge_count(128)",
        "// badge_dot(color?=\"\"):8×8 圆点;缺省语义红(跟随主题),传色则恒定",
        "@yue.badge_dot()",
      ],
    ),
    @ui.section(
      "统计进度",
      "Statistic 数值统计与 Progress 进度条",
      "大号数值经 computed 派生信号自动刷新;进度条主题色填充 + 浅灰轨道,随同一按钮联动。",
      [
        @yue.hbox(
          [
            @yue.statistic("访问量", app.visits.store()),
            @yue.statistic("任务数", @yue.Store::new("36")),
          ],
          style=[("alignItems", "center")],
        ),
        @yue.button_t(
          "刷新访问量",
          on_click=fn() { app.counter.update(fn(n) { n + 1 }) },
          variant=@yue.Solid,
        ),
        @yue.progress_line(app.ratio.store()),
        @yue.bind(
          app.ratio,
          fn(v) { "当前进度 \{((v * 100.0)).round()}%" },
          style=[("marginTop", 6.0)],
        ),
      ],
      code=[
        "// 大号数值与进度条都是 Store/Signal 驱动,源变自动刷新",
        "// Signal::new(初值):创建源信号;map(fn):派生只读信号,源变自动重算",
        "let counter = @yue.Signal::new(0)",
        "let visits = counter.map(fn(n) { (n * 1601).to_string() })",
        "let ratio = counter.map(fn(n) {",
        "  let r = 0.25 + n.to_double() * 0.1",
        "  if r > 1.0 { 1.0 } else { r }",
        "})",
        "// statistic(标题, Store[String]):大号数值+灰标题;store() 把信号转只读 Store 视图",
        "@yue.statistic(\"访问量\", visits.store())",
        "// progress_line(Store[Double], height?=8.0):值 0..1,主题色填充浅灰轨道,变化自动重绘",
        "@yue.progress_line(ratio.store())",
        "// bind(信号, fn(值) -> 文本):挂载建 Label 并订阅,值变自动更新文本",
        "@yue.bind(ratio, fn(v) { \"当前进度 \\{(v * 100.0).round()}%\" })",
      ],
    ),
    @ui.section(
      "卡片折叠",
      "Card 卡片与 Collapse 折叠面板",
      "标题栏 + 底部分隔线 + 边框;折叠面板点击标题展开/收起,各面板独立,初始第一个展开。",
      [
        @yue.card(
          "卡片标题",
          [
            @yue.label_t(
              "卡片内容:组件库全部用 theme_* 主题色着色。",
            ),
          ],
          style=[("height", 110.0)],
        ),
        @yue.collapse([
          (
            "如何使用组件库?",
            [
              @yue.label_t(
                "moon add NoahLiu/moonbit-libyue 后即可用 @yue.* 访问。",
              ),
            ],
          ),
          (
            "支持哪些平台?",
            [@yue.label_t("Linux(X11)/ Windows;macOS 进行中。")],
          ),
        ]),
      ],
      code=[
        "// card(标题, 子节点数组, height?=160.0):白底 + 边框,标题栏加粗带分隔线",
        "@yue.card(\"卡片标题\", [@yue.label_t(\"卡片内容\")], height=110.0)",
        "// 折叠面板:点击标题行切换,各面板独立,初始第一个展开",
        "// collapse(面板数组):每项为 (标题, 内容节点数组) 二元组",
        "@yue.collapse([",
        "  (\"如何使用组件库?\", [@yue.label_t(\"moon add 后即可用 @yue.*\")]),",
        "  (\"支持哪些平台?\", [@yue.label_t(\"Linux / Windows\")]),",
        "])",
      ],
    ),
    @ui.section(
      "描述",
      "Descriptions 描述列表与 Timeline 时间线",
      "键灰值深的键值网格;左侧色点 + 竖线,节点颜色跟随语义类型,末项无连线。",
      [
        @yue.descriptions([
          ("框架", "moonbit-libyue"),
          ("渲染", "GTK 3 (Linux) / Win32 (Windows)"),
          ("组件层", "纯 MoonBit,零平台代码"),
        ]),
        @yue.timeline([
          ("发布 1.0", "2026-01-01,首个稳定版。", @yue.Success),
          ("发布 1.1", "2026-05-01,新增组件库。", @yue.Primary),
          ("进行中", "2.0 规划:终端组件。", @yue.Warning),
        ]),
      ],
      code=[
        "// 键灰值深的键值网格",
        "// descriptions(键值对数组):每项为 (键, 值) 二元组",
        "@yue.descriptions([",
        "  (\"框架\", \"moonbit-libyue\"),",
        "  (\"渲染\", \"GTK 3 (Linux) / Win32 (Windows)\"),",
        "])",
        "// 左侧色点 + 竖线,节点颜色跟随语义类型",
        "// timeline(条目数组):每项为 (标题, 描述, 语义类型),行高固定 56",
        "@yue.timeline([",
        "  (\"发布 1.0\", \"2026-01-01,首个稳定版。\", @yue.Success),",
        "  (\"进行中\", \"2.0 规划:终端组件。\", @yue.Warning),",
        "])",
      ],
    ),
    @ui.section(
      "表格单选",
      "Table 表格(单选 + 排序 + 列宽拖动)",
      "表头 + 斑马纹 + 悬停底色,点击行单选;点击表头排序(升降序箭头,新列默认升序),拖动列边界调整列宽;Store 驱动「添加一行」整表重建,选中行信号回显。",
      [
        @yue.table_t(
          [
            @yue.TableColumn::make("语言", 140.0),
            @yue.TableColumn::make("首发", 90.0, align=@yue.Center),
            @yue.TableColumn::make("定位", 0.0),
          ],
          table_rows,
          width=440.0,
          sort=table_sort,
          on_row_click=fn(i, r) {
            let name = match r.cells[0] {
              @yue.CellText(s) => s
              _ => ""
            }
            table_picked.set("第 \{i + 1} 行:\{name}")
          },
        ),
        @yue.hbox(
          [
            @yue.button_t("添加一行", on_click=fn() {
              let n = lang_base.length() + 1
              lang_base.push(
                @yue.TableRow::make([
                  "新语言 \{n}",
                  "2026",
                  "演示 Store 驱动",
                ]),
              )
              reorder_langs()
            }),
            @yue.label("   "),
            @yue.bind(table_picked, fn(s) { s }),
          ],
          style=[("marginTop", 8.0), ("alignItems", "center")],
        ),
      ],
      code=[
        "// Store 驱动:rows 写新数组整表重建;sort 传 TableSort Store",
        "// Store::new(初值):可订阅容器,set 通知订阅者;TableRow::make(字符串数组) 造纯文本行",
        "let rows = @yue.Store::new([",
        "  @yue.TableRow::make([\"MoonBit\", \"2023\", \"多范式\"]),",
        "  @yue.TableRow::make([\"Rust\", \"2015\", \"系统编程\"]),",
        "])",
        "// TableSort:column=排序列号(<0 不排序),asc=升序;点表头由组件回写,数据排序自己订阅完成",
        "let sort = @yue.Store::new(@yue.TableSort::{ column: -1, asc: true })",
        "// table_t(列定义, 行 Store):width?=560 row_height?=36;sort 提供后表头画升降箭头",
        "@yue.table_t(",
        "  [",
        "    // TableColumn::make(标题, 宽度, align?=Start 左对齐, sortable?=true)",
        "    @yue.TableColumn::make(\"语言\", 140.0),",
        "    @yue.TableColumn::make(\"首发\", 90.0, align=@yue.Center),",
        "    @yue.TableColumn::make(\"定位\", 0.0),   // 0 = 占满剩余宽",
        "  ],",
        "  rows,",
        "  width=440.0,",
        "  sort=sort,",
        "  // on_row_click(行号, 行):不传 selection 时点行单选高亮",
        "  on_row_click=fn(i, _r) { println(\"点了第 \\{i + 1} 行\") },",
        ")",
      ],
    ),
    @ui.section(
      "表格多选",
      "Table 表格(多选 + 排序)",
      "复选框列:行点击勾选,表头全选/清空(部分选中画横条);表头排序箭头(灰 ↕ 可排 / 主题色当前排序),「语言」列可点排序,拖动列边界调宽。",
      [
        @yue.table_t(
          [
            @yue.TableColumn::make("语言", 120.0),
            @yue.TableColumn::make("类型", 100.0, sortable=false),
            @yue.TableColumn::make("色板", 110.0, sortable=false),
            @yue.TableColumn::make("特性", 0.0, sortable=false),
          ],
          rich_rows,
          selection=table_sel,
          width=460.0,
          sort=rich_sort,
        ),
        @yue.bind(table_sel.signal(), fn(s) { "已选 \{s.length()} 行" }),
      ],
      code=[
        "// selection 传 Array[Int] Store:启用复选框列,表头全选/清空,行点击勾选",
        "// 选中行号数组由组件回写 Store",
        "let sel : @yue.Store[Array[Int]] = @yue.Store::new([])",
        "@yue.table_t(",
        "  [",
        "    @yue.TableColumn::make(\"语言\", 120.0),",
        "    // sortable=false:该列表头点击不排序,不画箭头",
        "    @yue.TableColumn::make(\"类型\", 100.0, sortable=false),",
        "  ],",
        "  rows,",
        "  selection=sel,",
        "  width=460.0,",
        ")",
        "// bind(信号, fn) 做文本回显;signal() 以 Signal 形态使用同一 Store",
        "@yue.bind(sel.signal(), fn(s) { \"已选 \\{s.length()} 行\" })",
      ],
    ),
    @ui.section(
      "富单元格",
      "Table 表格(富单元格)",
      "单元格支持 Tag / 颜色块 / 多行文本(行自动撑高)。",
      [
        @yue.hbox(
          [
            @yue.table_t(
              [
                @yue.TableColumn::make("语言", 120.0),
                @yue.TableColumn::make("类型", 100.0),
                @yue.TableColumn::make("色板", 110.0),
                @yue.TableColumn::make("特性", 0.0),
              ],
              rich_rows,
              selection=table_sel,
              width=460.0,
            ),
            @yue.vbox(
              [
                @yue.label_t("CellTag:彩色语义标签", role=@yue.Secondary),
                @yue.label_t(
                  "CellColorBox:色块 + 说明",
                  role=@yue.Secondary,
                ),
                @yue.label_t(
                  "CellLines:多行文本自动撑高",
                  role=@yue.Secondary,
                ),
              ],
              style=[("marginLeft", 12.0)],
            ),
          ],
          style=[("alignItems", "start")],
        ),
      ],
      code=[
        "// 富单元格:Tag / 颜色块 / 多行文本(行自动撑高)",
        "// 行 = TableRow { cells },单元格按列顺序排列",
        "let rich : @yue.Store[Array[@yue.TableRow]] = @yue.Store::new([",
        "  {",
        "    cells: [",
        "      // CellText(纯文本)",
        "      @yue.CellText(\"MoonBit\"),",
        "      // CellTag(文本, 语义类型):彩色语义标签",
        "      @yue.CellTag(\"编译型\", @yue.Primary),",
        "      // CellColorBox(色值, 说明):色块 + 说明文字",
        "      @yue.CellColorBox(\"#2D68C4\", \"主题蓝\"),",
        "      // CellLines(行文本数组):多行,行高自动撑开",
        "      @yue.CellLines([\"多范式\", \"云 + 端\"]),",
        "    ],",
        "  },",
        "])",
        "@yue.table_t(columns, rich, width=460.0)",
      ],
    ),
    @ui.section(
      "虚拟滚动",
      "Table 虚拟滚动(排序 + 列宽拖动)",
      "整面自绘只画可见行,万行流畅;点击表头排序(序号列按数值),拖动列边界调整列宽;滚轮/拖右侧滚动条/键盘 ↑↓ PageUp PageDown 翻页。",
      [
        @yue.table_v_t(
          [
            @yue.TableColumn::make("序号", 90.0, align=@yue.End),
            @yue.TableColumn::make("名称", 160.0),
            @yue.TableColumn::make("分组", 110.0, align=@yue.Center),
            @yue.TableColumn::make("备注", 0.0),
          ],
          v_rows,
          height=220.0,
          sort=v_sort,
        ),
      ],
      code=[
        "// 虚拟滚动:整面自绘只画可见行,万行流畅;滚轮/滚动条/键盘自管滚动",
        "let data : Array[@yue.TableRow] = []",
        "for i in 0..<10000 {",
        "  data.push(@yue.TableRow::make([(i + 1).to_string(), \"条目 \\{i + 1}\"]))",
        "}",
        "// table_v_t(列定义, 行 Store):width?=560 height?=360 row_height?=32,sort?/selection? 同 table_t",
        "@yue.table_v_t(",
        "  [",
        "    // align:单元格文字对齐(Start/Center/End)",
        "    @yue.TableColumn::make(\"序号\", 90.0, align=@yue.End),",
        "    @yue.TableColumn::make(\"名称\", 160.0),",
        "  ],",
        "  @yue.Store::new(data),",
        "  height=220.0,",
        ")",
      ],
    ),
    @ui.section(
      "树形",
      "Tree 树形控件",
      "缩进层级 + 点击展开/折叠(▸/▾)。",
      [
        @yue.tree([
          {
            label: "src",
            children: [
              { label: "components.mbt", children: [], },
              {
                label: "examples",
                children: [{ label: "components", children: [], }],
              },
            ],
          },
          {
            label: "docs",
            children: [{ label: "components-ui.md", children: [], }],
          },
        ]),
      ],
      code=[
        "// 缩进层级 + 点击展开/折叠(▸/▾),初始全部收起",
        "// tree(节点数组):节点为 { label, children },层级越深缩进越多",
        "@yue.tree([",
        "  {",
        "    label: \"src\",",
        "    children: [",
        "      { label: \"components.mbt\", children: [] },",
        "      { label: \"examples\", children: [{ label: \"showcase\", children: [] }] },",
        "    ],",
        "  },",
        "])",
      ],
    ),
    @ui.section(
      "穿梭轮播",
      "Transfer 穿梭框与 Carousel 轮播",
      "穿梭框:点击行选中,中间 ›/‹ 移对侧;轮播:箭头/圆点手动切,3 秒自动切换(悬停暂停)。",
      [
        @yue.hbox([
          @yue.transfer(transfer_left, transfer_right),
          @yue.label("   "),
          @yue.carousel_t(
            [
              @yue.label_t(
                "第一屏:轮播内容可为任意 Node。",
                role=@yue.Body,
              ),
              @yue.label_t(
                "第二屏:自动轮播 3s 一切。",
                role=@yue.Body,
              ),
              @yue.label_t(
                "第三屏:悬停暂停,箭头/圆点手动切。",
                role=@yue.Body,
              ),
            ],
            width=320.0,
            height=80.0,
          ),
        ]),
      ],
      code=[
        "// 穿梭框:点击行选中,中间 ›/‹ 移对侧",
        "// transfer(左列 Store, 右列 Store, width?=160.0 单列宽):元素为字符串,移动即回写 Store",
        "let left = @yue.Store::new([\"北京\", \"上海\", \"广州\"])",
        "let right = @yue.Store::new([\"深圳\"])",
        "@yue.transfer(left, right)",
        "// 轮播:箭头/圆点手动切,3 秒自动切换(悬停暂停)",
        "// carousel_t(页面数组, width?=360.0, height?=180.0, interval_ms?=3000)",
        "@yue.carousel_t(",
        "  [",
        "    // label_t(文本, role?=Body):页面可为任意 Node",
        "    @yue.label_t(\"第一屏:任意 Node。\", role=@yue.Body),",
        "    @yue.label_t(\"第二屏:自动轮播 3s 一切。\", role=@yue.Body),",
        "  ],",
        "  width=320.0,",
        "  height=80.0,",
        "  // interval_ms=3000:自动轮播间隔毫秒,传 0 关闭自动",
        ")",
      ],
    ),
    @ui.section(
      "空状态",
      "Empty 空状态",
      "占位图 + 说明文字。",
      [@yue.empty("这里还没有内容")],
      code=[
        "// empty(说明文字):占位空箱图 + 居中说明,整体高 140",
        "@yue.empty(\"这里还没有内容\")",
      ],
    ),
  ])
}
