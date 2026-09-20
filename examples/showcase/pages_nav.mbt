// 导航组件页:Signal 驱动。页面切换状态 selected 本身是导航 Store
// (side_menu/segmented/breadcrumb 共享),页内演示状态用信号。

///|
fn page_nav(app : App) -> @yue.Node {
  let page_no = @yue.Signal::new(2)
  let step = @yue.Signal::new(1)
  scroll_page([
    section(
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
    ),
    section(
      "菜单(主题化 ContextMenu / DropdownMenu)",
      "context_menu_for 包右键原生菜单(悬停高亮 + 点击);DropdownMenu 点字段弹候选(两套用途不同:前者右键显隐,后者顶部展开)。",
      [
        @yue.hbox(
          [
            @yue.context_menu_for(
              @yue.tag("右键我", "#2D68C4"),
              [
                ("复制", fn() { app.picked_lang.set("已复制") }),
                ("重命名", fn() { app.picked_lang.set("重命名") }),
                ("-", fn() {  }),
                ("删除", fn() { app.picked_lang.set("已删除") }),
              ],
            ),
            @yue.dropdown_menu(
                  "操作",
                  ["打开", "保存", "-", "复制链接", "删除"],
                  fn(i) { app.picked_lang.set("菜单项 \{i}") },
              width=140.0,
            ),
            @yue.bind(app.picked_lang, fn(s) { "最近操作:\{s}" }),
          ],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
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
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "菜单栏(窗口顶部 MenuBar)",
      "窗口顶部原生菜单栏(文件/编辑/演示)由 main.mbt 挂载,此处仅示意结构:MenuItem 支持快捷键 + 角色项 + 分隔线,未注册项由系统自动省略。",
      [
        @yue.descriptions([
          ("快捷键", "about.set_accelerator(\"CmdOrCtrl+I\") 注册系统级加速键"),
          ("角色项", "edit.add_role_item(Copy/Cut/Paste/SelectAll) 取平台原生文案与图标"),
          ("分隔线", "add_separator() 插入不可点分隔线;演示菜单可遍历 item_count/item_at"),
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
                  let m = n + 2
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
        ),
      ],
    ),
  ])
}
