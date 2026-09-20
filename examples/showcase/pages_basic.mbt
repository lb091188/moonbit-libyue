// 基础组件页:Signal 驱动的主题组件演示。共享状态(counter 计数、
// picked_lang 最近操作)在 App;页内状态用源信号,展示端用 bind 直连,
// 无手动 subscribe 接线。

///|
fn page_basic(app : App) -> @yue.Node {
  let sync = @yue.Signal::new(false)
  let notify = @yue.Signal::new(true)
  scroll_page([
    section(
      "Button 按钮变体",
      "四变体;「主要操作」联动数据页访问量/进度条(信号)。",
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
      "五级排版,字号颜色随角色。",
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
      "主题色文字,悬停下划线;最近点击信号回显。",
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
      "水平(默认)/竖直 1px 主题边框色。",
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
      "勾选态存 Signal,勾选即回显。",
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
