// 导航组件页:Signal 驱动。页面切换状态 selected 本身是导航 Store
// (side_menu/segmented/breadcrumb 共享),页内演示状态用信号。

///|
pub fn page_nav(app : @ui.App) -> @yue.Node {
  let page_no = @yue.Signal::new(2)
  let step = @yue.Signal::new(1)
  @ui.page([
    @ui.section(
      "侧栏",
      "Side Menu 侧边导航",
      "窗口左侧即本组件;组标题可折叠收起,选中浅蓝底 + 主题色强调条。",
      [
        @yue.descriptions([
          ("悬停态", "浅灰底"),
          ("选中态", "主题浅蓝底 + 主题色文字 + 3px 强调条"),
          ("折叠", "组标题行点击收起/展开组内菜单项"),
          ("联动", "菜单项、面包屑共享同一导航状态"),
        ]),
      ],
      code=[
        "// 窗口左侧即本组件:组标题 + 菜单项,选中态自动管理",
        "// Store::new(初值):可订阅的共享状态;菜单项/面包屑点击都写它,即完成导航切换",
        "let selected = @yue.Store::new(\"基础组件\")",
        "// side_menu_sections(分组数组, selected):分组为 (组名, [项名...]) 两元素元组,",
        "// 项名点击写回 selected;icons= 项文本→图标,width?=180.0 列宽,foldable?=true 组可折叠",
        "@yue.side_menu_sections(",
        "  [(\"组件\", [\"基础组件\", \"表单组件\"]), (\"系统能力\", [\"系统集成\"])],",
        "  selected,",
        "  icons=[(\"基础组件\", @yue.Appstore), (\"系统集成\", @yue.Setting1)],",
        ")",
      ],
    ),
    @ui.section(
      "菜单",
      "菜单(主题化 ContextMenu / DropdownMenu)",
      "context_menu_for 包右键原生菜单(悬停高亮 + 点击);DropdownMenu 点字段弹候选(两套用途不同:前者右键显隐,后者顶部展开)。",
      [
        @yue.hbox(
          [
            @yue.context_menu_for(@yue.tag("右键我", "#2D68C4",style=[("width",140.0),("height",32.0)]), [
              ("复制", fn() { app.picked_lang.set("已复制") }),
              ("重命名", fn() { app.picked_lang.set("重命名") }),
              ("-", fn() {  }),
              ("删除", fn() { app.picked_lang.set("已删除") }),
            ]),
            @yue.dropdown_menu(
              "操作",
              ["打开", "保存", "-", "复制链接", "删除"],
              fn(i) { app.picked_lang.set("菜单项 \{i}") },
              style=[("width", 140.0),("marginBottom",0.0), ("marginRight", 10.0)],
            ),
            @yue.bind(app.picked_lang, fn(s) { "最近操作:\{s}" }),
          ],
          style=[("alignItems", "center")],
        ),
      ],
      code=[
        "// context_menu_for(内容节点, 菜单项):给任意节点包右键菜单;",
        "// 菜单项为 (文案, 回调) 数组,文案 \"-\" 画分隔线,弹出位置取右键事件的屏幕坐标",
        "@yue.context_menu_for(",
        "  // tag(文字, 颜色, height?=24.0):彩色实底标签(color 实底 + 白色文字),",
        "  // 示例任意节点都可包右键菜单",
        "  @yue.tag(\"右键我\", \"#2D68C4\"),",
        "  [",
        "    (\"复制\", fn() { println(\"复制\") }),", "    (\"-\", fn() { () }),",
        "    (\"删除\", fn() { println(\"删除\") }),", "  ],", ")",
        "// dropdown_menu(触发文字, 候选项, on_select):点字段在其下方弹候选列表;",
        "// on_select 收点击项下标(0 起),\"-\" 项画分隔线;width?=160.0 字段宽",
        "@yue.dropdown_menu(", "  \"操作\",", "  [\"打开\", \"保存\", \"-\", \"删除\"],",
        "  fn(i) { println(\"菜单项 \\{i}\") },", "  width=140.0,", ")",
      ],
    ),
    @ui.section(
      "原生菜单",
      "菜单(原生 Menu::popup_at)",
      "Menu::new + popup_at 弹原生右键菜单(系统主题外观),与上面主题化段对照。",
      [
        @yue.hbox(
          [
            @yue.button_t("点我弹原生菜单", on_click=fn() {
              let menu = @yue.Menu::new()
              let a = menu.add_label_item("第一项")
              a.on_click(fn() { app.picked_lang.set("原生菜单:第一项") })
              let b = menu.add_label_item("第二项")
              b.on_click(fn() { app.picked_lang.set("原生菜单:第二项") })
              let _ = menu.add_separator()
              let c = menu.add_label_item("关闭")
              c.on_click(fn() { () })
              let (mx, my) = @yue.mouse_location()
              menu.popup_at(mx, my)
            }),
            @yue.bind(app.picked_lang, fn(s) { s }),
          ],
          style=[("alignItems", "center")],
        ),
      ],
      code=[
        "// Menu::popup_at 弹原生右键菜单(系统主题外观)",
        "// button_t(文字, on_click?=空回调, variant?=Soft):主题化按钮,自绘悬停态",
        "@yue.button_t(\"点我弹原生菜单\", on_click=fn() {",
        "  // Menu::new():创建独立弹出菜单(也可挂托盘:Tray::set_menu)",
        "  let menu = @yue.Menu::new()",
        "  // add_label_item(文案):添加普通菜单项,返回 MenuItem",
        "  let a = menu.add_label_item(\"第一项\")",
        "  // on_click(回调):注册菜单项点击回调",
        "  a.on_click(fn() { println(\"第一项\") })",
        "  // add_separator():插入不可点的分隔线",
        "  let _ = menu.add_separator()",
        "  // mouse_location():全局鼠标位置(屏幕坐标),无需事件即可查询",
        "  let (mx, my) = @yue.mouse_location()",
        "  // popup_at(x, y):在屏幕坐标处弹出菜单",
        "  menu.popup_at(mx, my)",
        "})",
      ],
    ),
    @ui.section(
      "菜单栏",
      "菜单栏(窗口顶部 MenuBar)",
      "窗口顶部原生菜单栏(文件/编辑/演示)由 main.mbt 挂载,此处仅示意结构:MenuItem 支持快捷键 + 角色项 + 分隔线,未注册项由系统自动省略。",
      [
        @yue.descriptions([
          (
            "快捷键", "about.set_accelerator(\"CmdOrCtrl+I\") 注册系统级加速键",
          ),
          (
            "角色项", "edit.add_role_item(Copy/Cut/Paste/SelectAll) 取平台原生文案与图标",
          ),
          (
            "分隔线", "add_separator() 插入不可点分隔线;演示菜单可遍历 item_count/item_at",
          ),
        ]),
      ],
      code=[
        "// 窗口 handle 里挂菜单栏(w 为 Window 句柄)",
        "// MenuBar::new():创建顶栏菜单条",
        "let bar = @yue.MenuBar::new()",
        "// add_menu(标题):添加标题菜单,返回该 Menu 继续往里加项",
        "let file = bar.add_menu(\"文件\")",
        "// add_label_item(文案):添加普通菜单项",
        "let about = file.add_label_item(\"关于\")",
        "// set_accelerator(描述):设置快捷键,描述格式与官方一致,如 \"CmdOrCtrl+Q\"",
        "about.set_accelerator(\"CmdOrCtrl+I\")",
        "// add_separator():插入不可点的分隔线",
        "let _ = file.add_separator()",
        "let edit = bar.add_menu(\"编辑\")",
        "// add_role_item(角色):Copy/Cut/Paste/SelectAll/Undo/Redo,免实现取平台原生文案",
        "let _ = edit.add_role_item(@yue.Copy)",
        "// set_menubar(菜单条):把菜单栏挂到窗口顶部",
        "w.set_menubar(bar)",
      ],
    ),
    @ui.section(
      "分段",
      "Segmented 分段控制器",
      "顶栏导航形态:选中白底 + 主题色文字,悬停灰底过渡;与左侧菜单共享状态(此处演示切换)。",
      [
        @yue.segmented(
          [
            "基础组件", "表单组件", "导航组件", "数据展示", "反馈组件",
          ],
          app.selected,
        ),
      ],
      code=[
        "// 顶栏导航形态:选中白底 + 主题色文字,悬停灰底过渡",
        "// segmented(选项, selected):选项文本数组 + 选中项 Store[String];",
        "// 点击把该项文本写回 selected,共用同一 Store 的侧边菜单/面包屑同步联动",
        "@yue.segmented(", "  [\"基础组件\", \"表单组件\", \"导航组件\"],",
        "  selected,   // 与侧边菜单共享同一导航 Store", ")",
      ],
    ),
    @ui.section(
      "页签",
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
      code=[
        "// 顶部页签:选中主题色文字 + 底部指示条,内容区随选中显隐切换",
        "// tabs_t(页数组, selected?):页为 (页签标题, 内容节点);selected 为页序号",
        "// Store[Int](0 起),省略时内部自建初值 0",
        "@yue.tabs_t([",
        "  // label_t(文字, role?=Body):主题化标签,role 定字号/颜色,",
        "  // 可选 Title/Section/Body/Secondary/Accent",
        "  (\"概览\", @yue.label_t(\"这里是概览页内容。\", role=@yue.Body)),",
        "  (\"日志\", @yue.label_t(\"这里是日志页内容。\", role=@yue.Body)),",
        "])",
      ],
    ),
    @ui.section(
      "面包屑",
      "Breadcrumb 面包屑",
      "层级随选中态联动:当前项深色,其余灰色可点、悬停变主题色。项名即页面名,点击直达(面包屑与侧边菜单共享同一导航状态,写不存在的页面名会把所有页隐藏)。",
      [
        @yue.breadcrumb(
          ["数据展示", "导航组件", "基础组件"],
          app.selected,
        ),
      ],
      code=[
        "// 层级项统一灰字显示,悬停变主题色;当前项无特殊高亮",
        "// breadcrumb(项数组, selected):项文本需与导航页面名一致,",
        "// 点击任意项写回 selected(当前项也可点,点它即重写同值,无可见变化)",
        "@yue.breadcrumb([\"数据展示\", \"导航组件\", \"基础组件\"], selected)",
      ],
    ),
    @ui.section(
      "分页",
      "Pagination 分页",
      "当前页主题色实底白字,悬停浅蓝;点击页码切换。",
      [@yue.pagination(page_no.store(), 5)],
      code=[
        "// 当前页主题色实底白字,点击页码切换",
        "// Signal::new(初值):创建源信号",
        "let page_no = @yue.Signal::new(2)",
        "// store():以 Store 形态复用同一信号(共享值与订阅),当前页写入此 Store",
        "// pagination(current, pages):current 当前页 Store[Int](从 1 开始),pages 总页数;",
        "// 点击直接写回 Store,共享该 Store 的按钮同步高亮",
        "@yue.pagination(page_no.store(), 5)",
      ],
    ),
    @ui.section(
      "步骤条",
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
            @yue.button_t("下一步", variant=@yue.Solid, on_click=fn() {
              step.update(fn(n) {
                let m = n + 2
                if m > 2 {
                  2
                } else {
                  m
                }
              })
            }),
            @yue.label(" "),
            @yue.bind(step, fn(n) { "当前第 \{n + 1} 步" }),
          ],
          style=[("marginTop", 8.0)],
        ),
      ],
      code=[
        "// 完成/当前/待办三态:浅蓝、实底白字、灰",
        "// Signal::new(初值):创建源信号;步骤序号 0 起,初值 1 即停在第二步",
        "let step = @yue.Signal::new(1)",
        "// steps(步骤名数组, current):current 当前步 Store[Int],序号小于它为已完成",
        "// store():以 Store 形态复用同一信号(共享值与订阅),当前步写入此 Store",
        "@yue.steps([\"填写\", \"确认\", \"完成\"], step.store())",
        "// button_t(文字, on_click?=空回调, variant?=Soft):variant=Solid 主题色实底白字",
        "@yue.button_t(\"下一步\", variant=@yue.Solid, on_click=fn() {",
        "  // update(f):即 set(f(get())),用函数算新值",
        "  step.update(fn(n) { if n + 1 > 2 { 2 } else { n + 1 } })",
        "})",
      ],
    ),
  ])
}
