// 数据展示页:Signal 驱动。访问量/进度条是 App.counter 的 computed
// 派生(基础页按钮触发);表格行数组等容器型状态仍走 Store(组件
// 参数类型),选中回显等标量走信号。

///|
fn page_data(app : App) -> @yue.Node {
  let table_rows : @yue.Store[Array[@yue.TableRow]] = @yue.Store::new([
    @yue.TableRow::make(["MoonBit", "2023", "多范式,云 + 端"]),
    @yue.TableRow::make(["Rust", "2015", "系统编程"]),
    @yue.TableRow::make(["Go", "2012", "云原生后端"]),
    @yue.TableRow::make(["TypeScript", "2012", "前端大规模工程"]),
  ])
  let table_picked = @yue.Signal::new("未选中")
  let table_sel : @yue.Store[Array[Int]] = @yue.Store::new([])
  let rich_rows : @yue.Store[Array[@yue.TableRow]] = @yue.Store::new([
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
  ])
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
  let transfer_left : @yue.Store[Array[String]] = @yue.Store::new([
    "北京", "上海", "广州",
  ])
  let transfer_right : @yue.Store[Array[String]] = @yue.Store::new(["深圳"])
  // ---- 图表族：折线(滚动窗口 + 定时推点)/ 柱状 / 环形 / 仪表 / 散点 ----
  // 折线：3 序列定长窗口(max_points=120)，500ms 定时推点(三角波模拟
  // 监控曲线)；折线与面积两形态并列演示(面积半透明填充可选)
  let line_series : @yue.Store[Array[@yue.LineSeries]] = @yue.Store::new([
    @yue.LineSeries::make("CPU", max_points=120),
    @yue.LineSeries::make("内存", max_points=120),
    @yue.LineSeries::make("磁盘", max_points=120),
  ])
  let line_tick = @yue.Signal::new(0)
  fn triangle(t : Int, period : Int, base : Double, amp : Double) -> Double {
    let phase = t % period
    let half = period / 2
    base +
    (if phase < half {
      phase.to_double() / half.to_double() * amp
    } else {
      (period - phase).to_double() / half.to_double() * amp
    })
  }

  ignore(
    @yue.set_timer(500, fn() {
      let t = line_tick.get() + 1
      line_tick.set(t)
      @yue.series_push(line_series, 0, triangle(t, 60, 35.0, 40.0))
      @yue.series_push(line_series, 1, triangle(t, 90, 45.0, 20.0))
      @yue.series_push(line_series, 2, triangle(t, 120, 20.0, 30.0))
      true
    }),
  )
  // 柱状：月度净值(含负值，演示正负基线)；横向条为 Top 5 语言
  let bar_data : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("1月", 12.0),
    @yue.BarItem::make("2月", -8.0),
    @yue.BarItem::make("3月", 25.0),
    @yue.BarItem::make("4月", 18.0),
    @yue.BarItem::make("5月", -14.0),
    @yue.BarItem::make("6月", 32.0),
    @yue.BarItem::make("7月", 22.0),
    @yue.BarItem::make("8月", 9.0),
  ])
  let bar_h_data : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("MoonBit", 92.0),
    @yue.BarItem::make("Rust", 78.0),
    @yue.BarItem::make("Go", 65.0),
    @yue.BarItem::make("TS", 58.0),
    @yue.BarItem::make("Python", 41.0),
  ])
  // 环形：流量来源占比(中心汇总 + 图例 + hover 外扩)
  let donut_data : @yue.Store[Array[@yue.DonutSlice]] = @yue.Store::new([
    @yue.DonutSlice::make("直接访问", 335.0),
    @yue.DonutSlice::make("搜索引擎", 510.0),
    @yue.DonutSlice::make("社交媒体", 234.0),
    @yue.DonutSlice::make("外部链接", 148.0),
    @yue.DonutSlice::make("邮件", 96.0),
  ])
  // 仪表盘：2Hz 三角波 0..1，演示阈值分段着色 + 插值平滑
  let gauge_value : @yue.Store[Double] = @yue.Store::new(0.0)
  let gauge_tick = @yue.Signal::new(0)
  ignore(
    @yue.set_timer(500, fn() {
      let t = gauge_tick.get() + 1
      gauge_tick.set(t)
      gauge_value.set(triangle(t, 100, 0.05, 0.9))
      true
    }),
  )
  // 散点：2000 点确定性伪随机(LCG)，趋势线可选
  let scatter_data : Array[(Double, Double)] = []
  let mut scatter_seed = 42
  for _i in 0..<2000 {
    scatter_seed = (scatter_seed * 1103515245 + 12345) % 2147483647
    let x = scatter_seed.to_double() / 2147483647.0 * 100.0
    scatter_seed = (scatter_seed * 1103515245 + 12345) % 2147483647
    let y = x * 0.6 +
      20.0 +
      (scatter_seed.to_double() / 2147483647.0 - 0.5) * 40.0
    scatter_data.push((x, y))
  }
  let scatter_pts : @yue.Store[Array[(Double, Double)]] = @yue.Store::new(
    scatter_data,
  )
  scroll_page([
    section(
      "Line 折线图(滚动窗口 + 实时推点)",
      "定长滚动窗口(max_points=120,超出丢最旧),500ms 定时推点;多序列主题色循环,y 轴自适应 + 网格 + 最新值右端标注;右侧为面积形态(半透明填充)。推点只重绘画布,不重建视图树。",
      [
        @yue.hbox(
          [
            @yue.line_chart_t(line_series, width=380.0, height=220.0),
            @yue.label("  "),
            @yue.line_chart_t(line_series, width=380.0, height=220.0, area=true),
          ],
          style_str=[("alignItems", "start")],
        ),
      ],
    ),
    section(
      "Bar 柱状图 / 条形图",
      "纵向柱(默认)以 0 为基线支持正负值(正主题色、负红色);横向条(horizontal)适配长类目名。悬停高亮 + 行内数值标注,移动只重绘画布。",
      [
        @yue.hbox(
          [
            @yue.bar_chart_t(bar_data, width=380.0, height=220.0),
            @yue.label("  "),
            @yue.bar_chart_t(
              bar_h_data,
              width=380.0,
              height=220.0,
              horizontal=true,
            ),
          ],
          style_str=[("alignItems", "start")],
        ),
      ],
    ),
    section(
      "Donut 环形图与 Gauge 仪表盘",
      "环形图:占比扇区 + 中心汇总 + 图例,悬停扇区外扩;仪表盘:单值百分比环 + 中心大数字,阈值分段着色(≤60% 绿 / ≤85% 橙 / 红),2Hz 更新经定时器插值平滑无跳变。",
      [
        @yue.hbox(
          [
            @yue.donut_chart_t(donut_data, width=420.0, height=220.0),
            @yue.label("  "),
            @yue.gauge_t(gauge_value, width=240.0, height=170.0, thresholds=[
              (0.6, @yue.theme_current().success),
              (0.85, @yue.theme_current().warning),
              (1.0, @yue.theme_current().danger),
            ]),
          ],
          style_str=[("alignItems", "start")],
        ),
      ],
    ),
    section(
      "Scatter 散点图",
      "2000 点 x/y 点列(小方点),双轴自适应刻度;右侧叠加最小二乘趋势线。",
      [
        @yue.hbox(
          [
            @yue.scatter_t(scatter_pts, width=380.0, height=240.0),
            @yue.label("  "),
            @yue.scatter_t(scatter_pts, width=380.0, height=240.0, trend=true),
          ],
          style_str=[("alignItems", "start")],
        ),
      ],
    ),
    section(
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
          style_str=[("alignItems", "center")],
        ),
        @yue.hbox(
          [
            @yue.avatar("M", "#2D68C4", size=44.0),
            @yue.avatar("N", "#2E9E5B", size=36.0),
            @yue.avatar("X", "#D64550", size=30.0),
            @yue.avatar("L", "#D9822B", size=26.0),
          ],
          style=[("marginTop", 10.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
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
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "Statistic 数值统计与 Progress 进度条",
      "大号数值经 computed 派生信号自动刷新;进度条主题色填充 + 浅灰轨道,随同一按钮联动。",
      [
        @yue.hbox(
          [
            @yue.statistic("访问量", app.visits.store()),
            @yue.statistic("任务数", @yue.Store::new("36")),
          ],
          style_str=[("alignItems", "center")],
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
    ),
    section(
      "Card 卡片与 Collapse 折叠面板",
      "标题栏 + 底部分隔线 + 边框;折叠面板点击标题展开/收起,各面板独立,初始第一个展开。",
      [
        @yue.card(
          "卡片标题",
          [
            @yue.label_t("卡片内容:组件库全部用 theme_* 主题色着色。"),
          ],
          height=110.0,
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
    ),
    section(
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
    ),
    section(
      "Table 表格(单选)",
      "表头 + 斑马纹 + 悬停底色,点击行单选;Store 驱动「添加一行」整表重建,选中行信号回显。",
      [
        @yue.table_t(
          [
            @yue.TableColumn::make("语言", 140.0),
            @yue.TableColumn::make("首发", 90.0, align=@yue.Center),
            @yue.TableColumn::make("定位", 0.0),
          ],
          table_rows,
          width=440.0,
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
              let n = table_rows.get().length() + 1
              let grown = table_rows.get().copy()
              grown.push(
                @yue.TableRow::make(["新语言 \{n}", "2026", "演示 Store 驱动"]),
              )
              table_rows.set(grown)
            }),
            @yue.label("   "),
            @yue.bind(table_picked, fn(s) { s }),
          ],
          style=[("marginTop", 8.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "Table 表格(多选)",
      "复选框列:行点击勾选,表头全选/清空(部分选中画横条)。",
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
        @yue.bind(table_sel.signal(), fn(s) { "已选 \{s.length()} 行" }),
      ],
    ),
    section(
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
            @yue.vbox([
              @yue.label_t("CellTag:彩色语义标签", role=@yue.Secondary),
              @yue.label_t("CellColorBox:色块 + 说明", role=@yue.Secondary),
              @yue.label_t("CellLines:多行文本自动撑高", role=@yue.Secondary),
            ], style=[("marginLeft", 12.0)]),
          ],
          style_str=[("alignItems", "start")],
        ),
      ],
    ),
    section(
      "Table 虚拟滚动",
      "整面自绘只画可见行,万行流畅;滚轮/拖右侧滚动条/键盘 ↑↓ PageUp PageDown 翻页。",
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
        ),
      ],
    ),
    section(
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
    ),
    section(
      "Transfer 穿梭框与 Carousel 轮播",
      "穿梭框:点击行选中,中间 ›/‹ 移对侧;轮播:箭头/圆点手动切,3 秒自动切换(悬停暂停)。",
      [
        @yue.hbox([
          @yue.transfer(transfer_left, transfer_right),
          @yue.label("   "),
          @yue.carousel_t(
            [
              @yue.label_t("第一屏:轮播内容可为任意 Node。", role=@yue.Body),
              @yue.label_t("第二屏:自动轮播 3s 一切。", role=@yue.Body),
              @yue.label_t("第三屏:悬停暂停,箭头/圆点手动切。", role=@yue.Body),
            ],
            width=320.0,
            height=80.0,
          ),
        ]),
      ],
    ),
    section("Empty 空状态", "占位图 + 说明文字。", [
      @yue.empty("这里还没有内容"),
    ]),
  ])
}
