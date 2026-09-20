// 基础组件页:Signal 驱动的主题组件演示。共享状态(counter 计数、
// picked_lang 最近操作)在 App;页内状态用源信号,展示端用 bind 直连,
// 无手动 subscribe 接线。

///|
fn page_basic(app : App) -> @yue.Node {
  let sync = @yue.Signal::new(false)
  let notify = @yue.Signal::new(true)
  scroll_page([
    section(
      "Icon 图标系统 / IconButton 图标按钮",
      "37 个内置矢量图标(draw_icon 统一入口,悬停看名称);icon_button_t 方形 hover 收敛按钮,工具栏排列右侧统一 6px 间距。",
      [
        @yue.hbox(
          (
            {
              let cells : Array[@yue.Node] = []
              let icons = @yue.all_icons()
              let rows = (icons.length() + 9) / 10
              for row in 0..<rows {
                let items : Array[@yue.Node] = []
                for col in 0..<10 {
                  let idx = row * 10 + col
                  if idx < icons.length() {
                    items.push(
                      @yue.tooltip_t(@yue.icon(icons[idx], size=18.0), @yue.icon_name(icons[idx])),
                    )
                  }
                }
                cells.push(@yue.hbox(items, style=[("gap", 10.0)]))
              }
              cells
            }
          ),
          style=[("gap", 10.0)],
        ),
        @yue.hbox([
          @yue.icon_button_t(@yue.IconKind::Refresh, tip="刷新"),
          @yue.icon_button_t(@yue.IconKind::Edit, tip="编辑"),
          @yue.icon_button_t(@yue.IconKind::Copy, tip="复制"),
          @yue.icon_button_t(@yue.IconKind::Save, tip="保存"),
          @yue.icon_button_t(@yue.IconKind::Trash, tip="删除"),
          @yue.icon_button_t(@yue.IconKind::Search, tip="搜索"),
          @yue.icon_button_t(@yue.IconKind::Ellipsis, tip="更多"),
        ]),
      ],
    ),
    section(
      "Button 按钮变体",
      "Solid 主题色实底 / Soft 浅底(hover 变实底白字) / Text 透明底(hover 浅灰) / Danger 红色实底,hover 全程主题内收敛。点击主要操作联动数据展示页的访问量/进度条(信号驱动)。",
      [
        @yue.hbox(
          [
            @yue.button_t(
              "主要操作",
              on_click=fn() { app.counter.update(fn(n) { n + 1 }) },
              variant=@yue.Solid,
            ),
            @yue.button_t("次要操作", variant=@yue.Soft),
            @yue.button_t("文字按钮", variant=@yue.Text),
            @yue.button_t("危险操作", variant=@yue.Danger),
          ],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "Label 文字角色",
      "Title / Section / Body / Secondary / Accent 五级排版,字号颜色随角色。",
      [
        @yue.label_t("标题文字(Title)", role=@yue.Title),
        @yue.label_t("小节标题(Section)", role=@yue.Section),
        @yue.label_t("正文文字(Body)", role=@yue.Body),
        @yue.label_t("辅助文字(Secondary)", role=@yue.Secondary),
        @yue.label_t("强调文字(Accent)", role=@yue.Accent),
      ],
    ),
    section(
      "Link 链接文字",
      "主题色文字,悬停显示下划线,点击回调;最近点击经信号自动回显。",
      [
        @yue.hbox([
          @yue.link("打开文档", fn() { app.picked_lang.set("docs") }),
          @yue.label("   "),
          @yue.link("帮助中心", fn() { app.picked_lang.set("help") }),
          @yue.label_t("最近点击:", role=@yue.Body),
          @yue.bind(app.picked_lang, fn(s) { s }),
        ]),
      ],
    ),
    section(
      "Divider 分隔线",
      "水平(默认)/竖直 1px 主题边框色,spacing 控制两侧留白。",
      [
        @yue.label_t("上方内容"),
        @yue.divider(spacing=6.0),
        @yue.label_t("下方内容"),
      ],
    ),
    section(
      "ContextMenu 右键菜单",
      "context_menu_for 给任意节点包右键原生菜单(\"-\" 分隔线),在下面色块上点右键试试。",
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
      ],
    ),
    section(
      "Checkbox 复选框(信号)",
      "自绘直角勾选框:选中实心主题色 + 白勾;勾选态存 Signal,勾选即回显。",
      [
        @yue.vbox([
          @yue.checkbox_t("启用自动同步", on_change=fn(v) { sync.set(v) }),
          @yue.checkbox_t("接收通知", checked=true, on_change=fn(v) {
            notify.set(v)
          }),
          @yue.hbox(
            [
              @yue.bind(sync, fn(v) { if v { "同步:开" } else { "同步:关" } }),
              @yue.label("   "),
              @yue.bind(notify, fn(v) { if v { "通知:开" } else { "通知:关" } }),
            ],
            style=[("marginTop", 8.0)],
          ),
        ]),
      ],
    ),
    section(
      "Tooltip 悬浮提示",
      "tooltip_t 给任意节点包原生悬浮提示(系统样式;主题化气泡见反馈页 Popover)。",
      [
        @yue.hbox(
          [
            @yue.tooltip_t(@yue.button_t("悬停看提示"), "原生 tooltip:系统样式"),
            @yue.tooltip_t(@yue.button_t("再来一个", variant=@yue.Soft), "第二个提示"),
          ],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
  ])
}
