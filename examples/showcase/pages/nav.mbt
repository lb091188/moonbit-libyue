// 导航组件页：页面切换状态 selected 本身是导航 Store（侧栏菜单/分段/面包屑
// 共享），页内演示状态用本地 Store。
//
// G7 迁移记档（与 master 的差异）：
// ① `tag("右键我", "#2D68C4", style=[...])` 的 CSS 宽高换命名参数（本栈 `tag`
//    只有 `size` 字号参数，定宽包一层 `@ui.view`）；
// ② 「原生弹出菜单」段跳过——本栈 `Menu` 尚无 `popup_at` 右键弹出形态
//    （菜单栏形态已在 `examples/native-app` 演示，弹出形态随窗口页接线批补）；
// ③ `radio_group` 同页级 Store 的口径与 master 一致：菜单项/面包屑写**存在**
//    的页面名会直接切换页面（共享同一导航 Store 是刻意的联动演示）。
pub fn page_nav(app : @shared.App) -> @core.Node {
  let page_no : @core.Store[Int] = @core.Store::new(2)
  let step : @core.Store[Int] = @core.Store::new(1)
  let last_op : @core.Store[String] = @core.Store::new("（尚未操作）")
  @shared.page([
    @shared.section(
      "侧栏",
      "Side Menu 侧边导航",
      "窗口左侧即本组件；组标题可折叠收起，选中浅蓝底 + 主题色强调条。",
      [
        @ui.descriptions([
          ("悬停态", "浅灰底"),
          ("选中态", "主题浅蓝底 + 主题色文字 + 3px 强调条"),
          ("折叠", "组标题行点击收起/展开组内菜单项"),
          ("联动", "菜单项、面包屑、分段共享同一导航状态"),
        ]),
      ],
      code=[
        "let selected = @core.Store::new(\"基础组件\")",
        "@ui.menu_sections(",
        "  [(\"组件\", [\"基础组件\", \"表单组件\"]), (\"系统能力\", [\"系统集成\"])],",
        "  selected,",
        "  icons=[(\"基础组件\", @icons.Appstore), (\"系统集成\", @icons.Setting1)],",
        ")",
      ],
    ),
    @shared.section(
      "菜单",
      "右键菜单与下拉菜单",
      "context_menu_for 包右键弹出主题化菜单（悬停高亮 + 点击）；dropdown 点字段顶部展开候选——两套用途不同：前者右键显隐，后者顶部展开。",
      [
        @ui.row(
          [
            @ui.context_menu_for(
              @ui.view([@ui.tag("右键我", "#2D68C4")], width=140.0, height=32.0, align_items=@yoga.AlignItems::Center),
              [
                ("复制", fn() { last_op.set("已复制") }),
                ("重命名", fn() { last_op.set("重命名") }),
                ("-", fn() { () }),
                ("删除", fn() { last_op.set("已删除") }),
              ],
            ),
            @ui.dropdown(
              "操作",
              ["打开", "保存", "-", "复制链接", "删除"],
              on_select=fn(_i) { last_op.set("菜单项已选") },
            ),
            @ui.bind_label(last_op, fn(s) { "最近操作：\{s}" }),
          ],
          column_gap=16.0,
        ),
      ],
      code=[
        "@ui.context_menu_for(",
        "  @ui.tag(\"右键我\", \"#2D68C4\"),",
        "  [",
        "    (\"复制\", fn() { last_op.set(\"已复制\") }),",
        "    (\"-\", fn() { () }),",
        "    (\"删除\", fn() { last_op.set(\"已删除\") }),",
        "  ],",
        ")",
        "@ui.dropdown(\"操作\", [\"打开\", \"保存\", \"-\", \"删除\"], on_select=fn(_i) { () })",
      ],
    ),
    @shared.section(
      "原生菜单栏",
      "窗口菜单栏",
      "窗口顶部原生菜单栏（文件/编辑/演示）已在 `examples/native-app` 接线演示（Win32 原生外观 + 状态行回证），此处示意结构：MenuItem 支持快捷键 + 角色项 + 分隔线。",
      [
        @ui.descriptions([
          ("快捷键", "item.set_accelerator(\"CmdOrCtrl+I\") 注册系统级加速键"),
          ("角色项", "menu.add_role_item(role) 取平台原生文案"),
          ("分隔线", "menu.add_separator() 插入不可点分隔线"),
          ("挂载", "窗口由 main 经宿主菜单栏通道挂载（示例见 native-app 的菜单区块）"),
        ]),
      ],
      code=[
        "let bar = @core.MenuBar::new()",
        "let file = bar.add_menu(\"文件\")",
        "let about = file.add_item(\"关于\")",
        "about.set_accelerator(\"CmdOrCtrl+I\")",
        "let _ = file.add_separator()",
        "let edit = bar.add_menu(\"编辑\")",
        "let _ = edit.add_role_item(@core.MenuRole::Copy)",
      ],
    ),
    @shared.section(
      "分段",
      "Segmented 分段控制器",
      "顶栏导航形态：选中白底 + 主题色文字，悬停灰底过渡。这里与左侧菜单共享同一导航 Store——点一个页面名，窗口整页真的会切过去。",
      [
        @ui.segmented(
          ["基础组件", "表单组件", "导航组件", "反馈组件"],
          app.selected,
        ),
      ],
      code=[
        "@ui.segmented([\"基础组件\", \"表单组件\", \"导航组件\"], selected)",
      ],
    ),
    @shared.section(
      "页签",
      "Tabs 页签",
      "顶部页签形态：选中主题色文字 + 底部指示条，内容区切换（子区预建 + 显隐，不重建）。",
      [
        @ui.tabs([
          ("概览", @ui.text("这里是概览页内容。", role=@ui.Body)),
          ("配置", @ui.text("这里是配置页内容。", role=@ui.Body)),
          ("日志", @ui.text("这里是日志页内容。", role=@ui.Body)),
        ]),
      ],
      code=[
        "@ui.tabs([",
        "  (\"概览\", @ui.text(\"这里是概览页内容。\", role=@ui.Body)),",
        "  (\"配置\", @ui.text(\"这里是配置页内容。\", role=@ui.Body)),",
        "])",
      ],
    ),
    @shared.section(
      "面包屑",
      "Breadcrumb 面包屑",
      "层级项统一灰字、悬停变主题色，当前项无特殊高亮。项名即页面名，点击直达（与侧边菜单共享同一导航状态）。",
      [
        @ui.breadcrumb(["数据展示", "导航组件", "基础组件"], app.selected),
      ],
      code=[
        "@ui.breadcrumb([\"数据展示\", \"导航组件\", \"基础组件\"], selected)",
      ],
    ),
    @shared.section(
      "分页",
      "Pagination 分页",
      "当前页主题色实底白字，悬停浅蓝；点击页码切换。",
      [@ui.pagination(page_no, 5)],
      code=[
        "let page_no : @core.Store[Int] = @core.Store::new(2)",
        "@ui.pagination(page_no, 5)",
      ],
    ),
    @shared.section(
      "步骤条",
      "Steps 步骤条",
      "完成/当前/待办三态：浅蓝、实底白字、灰；点按钮推进或回退。",
      [
        @ui.steps(["填写", "确认", "完成"], step),
        @ui.row(
          [
            @ui.button_t("上一步", variant=@ui.Soft, on_click=fn() {
              step.update(fn(n) {
                let m = n - 1
                if m < 0 {
                  0
                } else {
                  m
                }
              })
            }),
            @ui.button_t("下一步", variant=@ui.Solid, on_click=fn() {
              step.update(fn(n) {
                let m = n + 2
                if m > 2 {
                  2
                } else {
                  m
                }
              })
            }),
            @ui.bind_label(step, fn(n) { "当前第 \{n + 1} 步" }),
          ],
          column_gap=8.0,
        ),
      ],
      code=[
        "let step : @core.Store[Int] = @core.Store::new(1)",
        "@ui.steps([\"填写\", \"确认\", \"完成\"], step)",
        "@ui.button_t(\"下一步\", variant=@ui.Solid, on_click=fn() { step.update(fn(n) { if n + 1 > 2 { 2 } else { n + 1 } }) })",
      ],
    ),
  ])
}
