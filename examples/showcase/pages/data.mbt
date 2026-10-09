// 数据展示页:Signal 驱动。访问量/进度条是 App.counter 的 computed
// 派生(基础页按钮触发);表格行数组等容器型状态仍走 Store(组件
// 参数类型),选中回显等标量走信号。

///|
/// 表格单元格的排序键(演示排序用:演示表格只有 CellText,其余取空串)。
fn cell_key(v : @components.TableCell) -> String {
  match v {
    @components.CellText(s) => s
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
    @components.TableRow::make(["MoonBit", "2023", "多范式,云 + 端"]),
    @components.TableRow::make(["Rust", "2015", "系统编程"]),
    @components.TableRow::make(["Go", "2012", "云原生后端"]),
    @components.TableRow::make(["TypeScript", "2012", "前端大规模工程"]),
  ]
  let table_rows : @yue.Store[Array[@components.TableRow]] = @yue.Store::new(lang_base)
  let table_sort : @yue.Store[@components.TableSort] = @yue.Store::new(@components.TableSort::{
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
  let rich_base : Array[@components.TableRow] = [
    {
      cells: [
        @components.CellText("MoonBit"),
        @components.CellTag("编译型", @components.Primary),
        @components.CellColorBox("#2D68C4", "主题蓝"),
        @components.CellLines(["多范式", "云 + 端"]),
      ],
    },
    {
      cells: [
        @components.CellText("Rust"),
        @components.CellTag("编译型", @components.Primary),
        @components.CellColorBox("#D9822B", "主题橙"),
        @components.CellLines(["系统编程", "无 GC"]),
      ],
    },
    {
      cells: [
        @components.CellText("Python"),
        @components.CellTag("解释型", @components.Warning),
        @components.CellColorBox("#2E9E5B", "主题绿"),
        @components.CellLines(["脚本", "AI 生态"]),
      ],
    },
  ]
  let rich_rows : @yue.Store[Array[@components.TableRow]] = @yue.Store::new(rich_base)
  let rich_sort : @yue.Store[@components.TableSort] = @yue.Store::new(@components.TableSort::{
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
        @components.CellText(t) => t
        _ => ""
      }
      let kb = match b.cells[0] {
        @components.CellText(t) => t
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
  let v_rows_data : Array[@components.TableRow] = []
  for i in 0..<10000 {
    v_rows_data.push(
      @components.TableRow::make([
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
  let v_rows : @yue.Store[Array[@components.TableRow]] = @yue.Store::new(v_rows_data)
  // 虚拟表排序:序号列(0)按数值,其余按文本;表头点击写 Store,订阅里重排
  let v_sort : @yue.Store[@components.TableSort] = @yue.Store::new(@components.TableSort::{
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
            @components.tag_of_type("Primary", @components.Primary),
            @components.tag_of_type("Success", @components.Success),
            @components.tag_of_type("Warning", @components.Warning),
            @components.tag_of_type("Danger", @components.Danger),
            @components.tag_of_type("Info", @components.Info),
            @components.tag("自定义实底", "#2D68C4"),
            @components.tag("v1.0", "#2E9E5B"),
          ],
          style=[("alignItems", "center")],
        ),
        @yue.hbox(
          [
            @components.avatar("M", "#2D68C4", size=44.0),
            @components.avatar("N", "#2E9E5B", size=36.0),
            @components.avatar("X", "#D64550", size=30.0),
            @components.avatar("L", "#D9822B", size=26.0),
          ],
          style=[("marginTop", 10.0), ("alignItems", "center")],
        ),
      ],
      code=[
        "@components.tag_of_type(\"Primary\", @components.Primary)", "@components.tag_of_type(\"Success\", @components.Success)",
        "@components.tag(\"自定义实底\", \"#2D68C4\")", "@components.avatar(\"M\", \"#2D68C4\", size=44.0)",
        "@components.avatar(\"X\", \"#D64550\", size=30.0)",
      ],
    ),
    @ui.section(
      "徽标",
      "Badge 徽标",
      "数字角标(红底白字,宽度自适应)与圆点两种形态。",
      [
        @yue.hbox(
          [
            @components.badge_count(9),
            @components.badge_count(128),
            @components.label_t("消息", role=@components.Body),
            @yue.label("      "),
            @components.badge_dot(),
            @components.label_t("在线", role=@components.Body),
          ],
          style=[("alignItems", "center")],
        ),
      ],
      code=["@components.badge_count(9)", "@components.badge_count(128)", "@components.badge_dot()"],
    ),
    @ui.section(
      "统计进度",
      "Statistic 数值统计与 Progress 进度条",
      "大号数值经 computed 派生信号自动刷新;进度条主题色填充 + 浅灰轨道,随同一按钮联动。",
      [
        @yue.hbox(
          [
            @components.statistic("访问量", app.visits.store()),
            @components.statistic("任务数", @yue.Store::new("36")),
          ],
          style=[("alignItems", "center"), ("marginBottom", 10.0)],
        ),
        @components.button_t(
          "刷新访问量",
          on_click=fn() { app.counter.update(fn(n) { n + 1 }) },
          variant=@components.Solid,
          style=[("marginBottom", 10.0)],
        ),
        @components.progress_line(app.ratio.store()),
        @yue.bind(
          app.ratio,
          fn(v) { "当前进度 \{((v * 100.0)).round()}%" },
          style=[("marginTop", 10.0)],
        ),
      ],
      code=[
        "let counter = @yue.Signal::new(0)", "let visits = counter.map(fn(n) { (n * 1601).to_string() })",
        "let ratio = counter.map(fn(n) {", "  let r = 0.25 + n.to_double() * 0.1",
        "  if r > 1.0 { 1.0 } else { r }", "})", "@components.statistic(\"访问量\", visits.store())",
        "@components.progress_line(ratio.store())", "@yue.bind(ratio, fn(v) { \"当前进度 \\{(v * 100.0).round()}%\" })",
      ],
    ),
    @ui.section(
      "卡片折叠",
      "Card 卡片与 Collapse 折叠面板",
      "标题栏 + 底部分隔线 + 边框;折叠面板点击标题展开/收起,各面板独立,初始第一个展开。",
      [
        @components.card(
          "卡片标题",
          [
            @components.label_t(
              "卡片内容:组件库全部用 theme_* 主题色着色。",
            ),
          ],
          style=[("height", 110.0), ("marginBottom", 10.0)],
        ),
        @components.collapse([
          (
            "如何使用组件库?",
            [
              @components.label_t(
                "moon add NoahLiu/moonbit-libyue 后即可用 @yue.* 访问。",
              ),
            ],
          ),
          (
            "支持哪些平台?",
            [@components.label_t("Linux(X11)/ Windows;macOS 进行中。")],
          ),
        ]),
      ],
      code=[
        "@components.card(\"卡片标题\", [@components.label_t(\"卡片内容\")], style=[(\"height\", 110.0)])",
        "@components.collapse([", "  (\"如何使用组件库?\", [@components.label_t(\"moon add 后即可用 @yue.*\")]),",
        "  (\"支持哪些平台?\", [@components.label_t(\"Linux / Windows\")]),", "])",
      ],
    ),
    @ui.section(
      "描述",
      "Descriptions 描述列表与 Timeline 时间线",
      "键灰值深的键值网格;左侧色点 + 竖线,节点颜色跟随语义类型,末项无连线。",
      [
        @components.descriptions([
          ("框架", "moonbit-libyue"),
          ("渲染", "GTK 3 (Linux) / Win32 (Windows)"),
          ("组件层", "纯 MoonBit,零平台代码"),
        ]),
        @components.timeline([
          ("发布 1.0", "2026-01-01,首个稳定版。", @components.Success),
          ("发布 1.1", "2026-05-01,新增组件库。", @components.Primary),
          ("进行中", "2.0 规划:终端组件。", @components.Warning),
        ]),
      ],
      code=[
        "@components.descriptions([", "  (\"框架\", \"moonbit-libyue\"),", "  (\"渲染\", \"GTK 3 (Linux) / Win32 (Windows)\"),",
        "])", "@components.timeline([", "  (\"发布 1.0\", \"2026-01-01,首个稳定版。\", @components.Success),",
        "  (\"进行中\", \"2.0 规划:终端组件。\", @components.Warning),", "])",
      ],
    ),
    @ui.section(
      "表格单选",
      "Table 表格(单选)",
      "表头 + 斑马纹 + 悬停底色,点击行单选;点击表头排序(升降序箭头,新列默认升序),拖动列边界调整列宽;Store 驱动「添加一行」整表重建,选中行信号回显。",
      [
        @components.table_t(
          [
            @components.TableColumn::make("语言", 140.0),
            @components.TableColumn::make("首发", 90.0, align=@yue.Center),
            @components.TableColumn::make("定位", 0.0),
          ],
          table_rows,
          width=440.0,
          sort=table_sort,
          on_row_click=fn(i, r) {
            let name = match r.cells[0] {
              @components.CellText(s) => s
              _ => ""
            }
            table_picked.set("第 \{i + 1} 行:\{name}")
          },
        ),
        @yue.hbox(
          [
            @components.button_t("添加一行", on_click=fn() {
              let n = lang_base.length() + 1
              lang_base.push(
                @components.TableRow::make([
                  "新语言 \{n}",
                  "2026",
                  "演示 Store 驱动",
                ]),
              )
              reorder_langs()
            }),
            @yue.bind(table_picked, fn(s) { s }, style=[("marginLeft", 12.0)]),
          ],
          style=[("marginTop", 8.0), ("alignItems", "center")],
        ),
      ],
      code=[
        "let rows = @yue.Store::new([", "  @components.TableRow::make([\"MoonBit\", \"2023\", \"多范式\"]),",
        "  @components.TableRow::make([\"Rust\", \"2015\", \"系统编程\"]),", "])", "let sort = @yue.Store::new(@components.TableSort::{ column: -1, asc: true })",
        "@components.table_t(", "  [", "    @components.TableColumn::make(\"语言\", 140.0),",
        "    @components.TableColumn::make(\"首发\", 90.0, align=@yue.Center),", "    @components.TableColumn::make(\"定位\", 0.0),   // 0 = 占满剩余宽",
        "  ],", "  rows,", "  width=440.0,", "  sort=sort,", "  on_row_click=fn(i, _r) { println(\"点了第 \\{i + 1} 行\") },",
        ")",
      ],
    ),
    @ui.section(
      "表格多选",
      "Table 表格(多选)",
      "复选框列:行点击勾选,表头全选/清空(部分选中画横条);表头排序箭头(灰 ↕ 可排 / 主题色当前排序),「语言」列可点排序,拖动列边界调宽。",
      [
        @components.table_t(
          [
            @components.TableColumn::make("语言", 120.0),
            @components.TableColumn::make("类型", 100.0, sortable=false),
            @components.TableColumn::make("色板", 110.0, sortable=false),
            @components.TableColumn::make("特性", 0.0, sortable=false),
          ],
          rich_rows,
          selection=table_sel,
          width=460.0,
          sort=rich_sort,
        ),
        @yue.bind(table_sel.signal(), fn(s) { "已选 \{s.length()} 行" }),
      ],
      code=[
        "let sel : @yue.Store[Array[Int]] = @yue.Store::new([])", "@components.table_t(",
        "  [", "    @components.TableColumn::make(\"语言\", 120.0),", "    @components.TableColumn::make(\"类型\", 100.0, sortable=false),",
        "  ],", "  rows,", "  selection=sel,", "  width=460.0,", ")", "@yue.bind(sel.signal(), fn(s) { \"已选 \\{s.length()} 行\" })",
      ],
    ),
    @ui.section(
      "富单元格",
      "Table 表格(富单元格)",
      "单元格支持 Tag / 颜色块 / 多行文本(行自动撑高)。",
      [
        @yue.hbox(
          [
            @components.table_t(
              [
                @components.TableColumn::make("语言", 120.0),
                @components.TableColumn::make("类型", 100.0),
                @components.TableColumn::make("色板", 110.0),
                @components.TableColumn::make("特性", 0.0),
              ],
              rich_rows,
              selection=table_sel,
              width=460.0,
            ),
            @yue.vbox(
              [
                @components.label_t("CellTag:彩色语义标签", role=@components.Secondary),
                @components.label_t(
                  "CellColorBox:色块 + 说明",
                  role=@components.Secondary,
                ),
                @components.label_t(
                  "CellLines:多行文本自动撑高",
                  role=@components.Secondary,
                ),
              ],
              style=[("marginLeft", 12.0)],
            ),
          ],
          style=[("alignItems", "start")],
        ),
      ],
      code=[
        "let rich : @yue.Store[Array[@components.TableRow]] = @yue.Store::new([", "  {",
        "    cells: [", "      @components.CellText(\"MoonBit\"),", "      @components.CellTag(\"编译型\", @components.Primary),",
        "      @components.CellColorBox(\"#2D68C4\", \"主题蓝\"),", "      @components.CellLines([\"多范式\", \"云 + 端\"]),",
        "    ],", "  },", "])", "@components.table_t(", "  [", "    @components.TableColumn::make(\"语言\", 120.0),",
        "    @components.TableColumn::make(\"类型\", 100.0),", "    @components.TableColumn::make(\"色板\", 110.0),",
        "    @components.TableColumn::make(\"特性\", 0.0),", "  ],", "  rich,", "  width=460.0,",
        ")",
      ],
    ),
    @ui.section(
      "虚拟滚动",
      "Table 虚拟滚动",
      "整面自绘只画可见行,万行流畅;点击表头排序(序号列按数值),拖动列边界调整列宽;滚轮/拖右侧滚动条/键盘 ↑↓ PageUp PageDown 翻页。",
      [
        @components.table_v_t(
          [
            @components.TableColumn::make("序号", 90.0, align=@yue.End),
            @components.TableColumn::make("名称", 160.0),
            @components.TableColumn::make("分组", 110.0, align=@yue.Center),
            @components.TableColumn::make("备注", 0.0),
          ],
          v_rows,
          height=220.0,
          sort=v_sort,
        ),
      ],
      code=[
        "let data : Array[@components.TableRow] = []", "for i in 0..<10000 {", "  data.push(@components.TableRow::make([(i + 1).to_string(), \"条目 \\{i + 1}\"]))",
        "}", "@components.table_v_t(", "  [", "    @components.TableColumn::make(\"序号\", 90.0, align=@yue.End),",
        "    @components.TableColumn::make(\"名称\", 160.0),", "  ],", "  @yue.Store::new(data),",
        "  height=220.0,", ")",
      ],
    ),
    @ui.section(
      "树形",
      "Tree 树形控件",
      "缩进层级 + 点击展开/折叠(▸/▾)。",
      [
        @components.tree([
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
        "@components.tree([", "  {", "    label: \"src\",", "    children: [", "      { label: \"components.mbt\", children: [] },",
        "      { label: \"examples\", children: [{ label: \"showcase\", children: [] }] },",
        "    ],", "  },", "])",
      ],
    ),
    @ui.section(
      "穿梭轮播",
      "Transfer 穿梭框与 Carousel 轮播",
      "穿梭框:点击行选中,中间 ›/‹ 移对侧;轮播:箭头/圆点手动切,3 秒自动切换(悬停暂停)。",
      [
        @yue.hbox([
          @components.transfer(transfer_left, transfer_right),
          @components.carousel_t(
            [
              @components.label_t(
                "第一屏:轮播内容可为任意 Node。",
                role=@components.Body,
              ),
              @components.label_t(
                "第二屏:自动轮播 3s 一切。",
                role=@components.Body,
              ),
              @components.label_t(
                "第三屏:悬停暂停,箭头/圆点手动切。",
                role=@components.Body,
              ),
            ],
            style=[("width", 320.0), ("marginLeft", 20.0)],
            height=80.0,
          ),
        ]),
      ],
      code=[
        "let left = @yue.Store::new([\"北京\", \"上海\", \"广州\"])", "let right = @yue.Store::new([\"深圳\"])",
        "@components.transfer(left, right)", "@components.carousel_t(", "  [", "    @components.label_t(\"第一屏:任意 Node。\", role=@components.Body),",
        "    @components.label_t(\"第二屏:自动轮播 3s 一切。\", role=@components.Body),",
        "  ],", "  style=[(\"width\", 320.0), (\"height\", 80.0)],", ")",
      ],
    ),
    @ui.section(
      "空状态",
      "Empty 空状态",
      "占位图 + 说明文字。",
      [@components.empty("这里还没有内容")],
      code=["@components.empty(\"这里还没有内容\")"],
    ),
  ])
}
