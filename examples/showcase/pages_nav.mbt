// 导航组件页:Signal 驱动。页面切换状态 selected 本身是导航 Store
// (side_menu/segmented/breadcrumb 共享),页内演示状态用信号。

///|
fn page_nav(app : App) -> @yue.Node {
  let page_no = @yue.Signal::new(2)
  let step = @yue.Signal::new(1)
  scroll_page([
    section(
      "Side Menu 侧边导航",
      "窗口左侧即本组件(分组形态 side_menu_sections):组标题不可点,菜单项悬停灰底、选中浅蓝底 + 主题色文字 + 左侧强调条,点击切换页面;底部展示包版本号。",
      [
        @yue.descriptions([
          ("悬停态", "浅灰底"),
          ("选中态", "主题浅蓝底 + 主题色文字 + 3px 强调条"),
          ("联动", "菜单项、面包屑共享同一导航状态"),
        ]),
      ],
    ),
    section(
      "Segmented 分段控制器",
      "顶栏导航形态:选中白底 + 主题色文字,悬停灰底过渡;与左侧菜单共享状态(此处演示切换)。",
      [
        @yue.segmented(
          ["基础组件", "表单组件", "导航组件", "数据展示", "反馈组件"],
          app.selected,
        ),
      ],
    ),
    section(
      "Tabs 页签",
      "顶部页签形态:选中主题色文字 + 底部指示条,内容区切换。",
      [
        @yue.tabs_t([
          (
            "概览",
            @yue.label_t("这里是概览页内容。", role=@yue.Body),
          ),
          (
            "配置",
            @yue.label_t("这里是配置页内容。", role=@yue.Body),
          ),
          (
            "日志",
            @yue.label_t("这里是日志页内容。", role=@yue.Body),
          ),
        ]),
      ],
    ),
    section(
      "Breadcrumb 面包屑",
      "层级随选中态联动:当前项深色,其余灰色可点、悬停变主题色。",
      [@yue.breadcrumb(["MoonShell", "控制台", "基础组件"], app.selected)],
    ),
    section(
      "Pagination 分页",
      "当前页主题色实底白字,悬停浅蓝;点击页码切换。",
      [@yue.pagination(page_no.store(), 5)],
    ),
    section(
      "Steps 步骤条",
      "完成/当前/待办三态:浅蓝、实底白字、灰;点按钮推进或回退。",
      [
        @yue.steps(["填写", "确认", "完成"], step.store()),
        @yue.hbox(
          [
            @yue.button_t("上一步", variant=@yue.Soft, on_click=fn() {
              step.update(fn(n) {
                let m = n - 1
                if m < 0 {
                  0
                } else {
                  m
                }
              })
            }),
            @yue.label(" "),
            @yue.button_t(
              "下一步",
              variant=@yue.Solid,
              on_click=fn() {
                step.update(fn(n) {
                  let m = n + 1
                  if m > 2 {
                    2
                  } else {
                    m
                  }
                })
              },
            ),
            @yue.label(" "),
            @yue.bind(step, fn(n) { "当前第 \{n + 1} 步" }),
          ],
          style=[("marginTop", 8.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "PageHeader 页头",
      "‹ 返回(悬停变主题色)+ 标题 + 右侧操作区;点返回回到基础组件页。",
      [
        @yue.page_header(
          "进阶组件",
          fn() { app.selected.set("基础组件") },
          actions=[@yue.button_t("页面操作", variant=@yue.Soft)],
        ),
      ],
    ),
    section(
      "DropdownMenu 下拉菜单",
      "触发字段弹菜单项列表(\"-\" 为分隔线),悬停高亮,点击回调序号。",
      [
        @yue.dropdown_menu(
              "操作",
              ["打开", "保存", "-", "复制链接", "删除"],
              fn(i) { app.picked_lang.set("菜单项 \{i}") },
          width=140.0,
        ),
        @yue.bind(app.picked_lang, fn(s) { "最近操作:\{s}" }),
      ],
    ),
    section(
      "Splitter 可拖动分隔",
      "桌面多栏布局标配件:6px 把手悬停浅灰、拖动中主题色,拖动经鼠标捕获(拖出范围不丢事件);min 钳制两栏下限。左例 hsplit 左树右详情,右例 vsplit 上下分栏。",
      [
        @yue.vbox(
          [
            @yue.hsplit(
              @yue.tree([
                {
                  label: "组件",
                  children: [
                    {
                      label: "基础",
                      children: [{ label: "图标", children: [] }, { label: "分隔", children: [] }],
                    },
                    { label: "导航", children: [{ label: "分栏", children: [] }] },
                  ],
                },
              ]),
              @yue.vbox([@yue.label_t("右侧详情区:拖动中间把手调整占比", role=@yue.Body)], style=[("padding", 12.0)]),
              min_first=120.0,
            ),
          ],
          style=[("height", 200.0), ("width", 520.0), ("marginBottom", 10.0)],
        ),
        @yue.vbox(
          [
            @yue.vsplit(
              @yue.vbox(
                [@yue.label_t("上栏:列表区(可放 table / 列表)", role=@yue.Body)],
                style=[("padding", 10.0)],
              ),
              @yue.vbox(
                [@yue.label_t("下栏:详情/说明区", role=@yue.Secondary)],
                style=[("padding", 10.0)],
              ),
            ),
          ],
          style=[("height", 160.0), ("width", 520.0)],
        ),
      ],
    ),
  ])
}
