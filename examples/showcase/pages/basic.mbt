// 基础组件页:Signal 驱动的主题组件演示。共享状态(counter 计数、
// picked_lang 最近操作)在 App;页内状态用源信号,展示端用 bind 直连,
// 无手动 subscribe 接线。勾选类在表单组件页,右键菜单在导航组件页。

///|
pub fn page_basic(app : @ui.App) -> @yue.Node {
  @ui.page([
    @ui.section(
      "主题",
      "主题色板(主色公式派生 + 系统主色)",
      "选一个主色,整套色板(hover/浅底/语义色)按 HSL 公式即时派生,切换深浅沿用当前主色;「跟随系统」读系统主色调,读不到回落内置。",
      [
        @yue.hbox(
          [
            @yue.button_t("跟随系统", variant=@yue.Solid, on_click=fn() {
              app.accent.set(@yue.system_accent())
            }),
            @yue.button_t("默认蓝", on_click=fn() { app.accent.set("") }),
            @yue.button_t("青", on_click=fn() { app.accent.set("#009688") }),
            @yue.button_t("绿", on_click=fn() { app.accent.set("#2E9E5B") }),
            @yue.button_t("紫", on_click=fn() { app.accent.set("#9141AC") }),
            @yue.button_t("红", on_click=fn() { app.accent.set("#D64550") }),
          ],
          style_str=[("alignItems", "center")],
        ),
        @yue.bind(
          app.accent.signal(),
          fn(s) {
            if s == "" {
              "当前主色:内置默认"
            } else {
              "当前主色:\{s}"
            }
          },
          style=[("marginTop", 8.0)],
        ),
      ],
      code=[
        "// theme_from_accent(主色, dark~ 深浅模式默认 false):由单个主色按 HSL 公式",
        "// 派生整套色盘(hover/浅底/语义色),深浅切换沿用主色色相;",
        "// 主色收 #RRGGBB/#RGB/#AARRGGBB,空串/非法回落内置基准盘",
        "let accent = \"#009688\"",
        "// theme_apply(theme):整体替换当前色板并通知订阅者,已挂载组件即时重着色",
        "@yue.theme_apply(@yue.theme_from_accent(accent, dark~))",
        "// dark_theme() / default_theme():内置暗色 / 默认基准盘,无参直接套用",
        "@yue.theme_apply(if dark { @yue.dark_theme() } else { @yue.default_theme() })",
        "// system_accent():系统强调色,ARGB hex(如 \"#ff009688\"),读不到返回空串",
        "let sys = @yue.system_accent()",
      ],
    ),
    @ui.section(
      "按钮",
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
      code=[
        "// hbox(children 子节点数组, style~/style_str~ 默认空, handle~ 拿 Container):水平排列",
        "@yue.hbox([",
        "// button_t(文字, on_click~ 点击回调默认空操作, variant~ 变体默认 Soft)",
        "// 四变体:Solid 主题色实底白字 / Soft 浅底主题色字 / Text 透明底主题色字 /",
        "// Danger 红色实底白字;hover 分别为加深 / 变实底白字 / 浅灰底 / 加深",
        "  @yue.button_t(\"主要操作\", variant=@yue.Solid, on_click=fn() { }),",
        "  @yue.button_t(\"次要操作\", variant=@yue.Soft),",
        "  @yue.button_t(\"文字按钮\", variant=@yue.Text),",
        "  @yue.button_t(\"危险操作\", variant=@yue.Danger),",
        "])",
      ],
    ),
    @ui.section(
      "文字链接",
      "Label 文字与 Link 链接",
      "五级排版角色,字号颜色随角色;Link 主题色文字悬停下划线,最近点击信号回显。",
      [
        @yue.label_t("标题文字(Title)", role=@yue.Title, style=[
          ("marginTop", 8.0),
        ]),
        @yue.label_t("小节标题(Section)", role=@yue.Section, style=[
          ("marginTop", 8.0),
        ]),
        @yue.label_t("正文文字(Body)", role=@yue.Body, style=[
          ("marginTop", 8.0),
        ]),
        @yue.label_t("辅助文字(Secondary)", role=@yue.Secondary, style=[
          ("marginTop", 8.0),
        ]),
        @yue.label_t("强调文字(Accent)", role=@yue.Accent, style=[
          ("marginTop", 8.0),
        ]),
        @yue.hbox(
          [
            @yue.link("打开文档", fn() { app.picked_lang.set("docs") }),
            @yue.label("   "),
            @yue.link("帮助中心", fn() { app.picked_lang.set("help") }),
            @yue.label_t("最近点击:", role=@yue.Body),
            @yue.bind(app.picked_lang, fn(s) { s }),
          ],
          style=[("marginTop", 8.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
      code=[
        "// label_t(文字, role~ 排版角色默认 Body, style~/style_str~, handle~ 拿 Label)",
        "// 五级角色字号颜色各异,主题切换自动跟随:",
        "// Title 18 半粗 / Section 14 半粗 / Body 13 常规 / Secondary 12 辅助灰 /",
        "// Accent 13 半粗主题色",
        "@yue.label_t(\"标题文字\", role=@yue.Title)",
        "@yue.label_t(\"小节标题\", role=@yue.Section)",
        "@yue.label_t(\"正文文字\", role=@yue.Body)",
        "@yue.label_t(\"辅助文字\", role=@yue.Secondary)",
        "@yue.label_t(\"强调文字\", role=@yue.Accent)",
        "// link(文字, on_click 点击回调):主题色文字,悬停显示下划线色条、光标变手型",
        "@yue.link(\"打开文档\", fn() { println(\"link clicked\") })",
      ],
    ),
    @ui.section(
      "分隔提示",
      "Divider 分隔线与 Tooltip 悬浮提示",
      "水平(默认)/竖直 1px 主题边框色;tooltip_t 给任意节点包原生悬浮提示(系统样式,主题化气泡见反馈页 Popover)。",
      [
        @yue.label_t("上方内容"),
        @yue.divider(spacing=6.0),
        @yue.label_t("下方内容"),
        @yue.hbox(
          [
            @yue.tooltip_t(
              @yue.button_t("悬停看提示"),
              "原生 tooltip:系统样式",
            ),
            @yue.tooltip_t(
              @yue.button_t("再来一个", variant=@yue.Soft),
              "第二个提示",
            ),
          ],
          style=[("marginTop", 10.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
      code=[
        "// divider(vertical~ 默认 false 水平, spacing~ 两侧留白默认 10.0):1px",
        "// 主题边框色;水平:高 1px、宽 flex,竖直:宽 1px、高随父",
        "@yue.divider(spacing=6.0)",
        "@yue.divider(vertical=true)",
        "// tooltip_t(content 被包裹的任意节点, tip 提示文本):悬停 content 显示",
        "// 原生 tooltip(系统样式;主题化气泡用 popover_t)",
        "@yue.tooltip_t(@yue.button_t(\"悬停看提示\"), \"原生 tooltip:系统样式\")",
      ],
    ),
    @ui.section(
      "悬停组",
      "HoverGroup 悬停组",
      "组内任意位置(含子控件)悬停即整组进入 hover 态:把指针移到卡片里的按钮或输入框上,整张卡片同样高亮且光标变手型——GTK 下子控件的事件窗口会独占指针事件,组件用指针位置轮询判定,不依赖 enter/leave,不闪烁。",
      [
        @yue.hover_group(
          @yue.vbox(
            [
              @yue.label_t(
                "组标题:悬停我,或下面的子控件",
                role=@yue.Section,
              ),
              @yue.hbox(
                [
                  @yue.input_t(text="组内输入框", width=200.0),
                  @yue.button_t("组内按钮"),
                ],
                style=[("marginTop", 10.0)],
                style_str=[("alignItems", "center")],
              ),
              @yue.label_t(
                "子控件触发的事件同样改变组的样式",
                role=@yue.Secondary,
                style=[("marginTop", 8.0)],
              ),
            ],
            style=[("padding", 14.0)],
          ),
          radius=8.0,
          on_change=fn(h, host) {
            @yue.View::set_cursor(
              host,
              @yue.Cursor::new(if h { @yue.Hand } else { @yue.Default }),
            )
          },
        ),
      ],
      code=[
        "// hover_group(child 组内容, hover_bg~ 悬停底色, base_bg~ 常态底色,",
        "// radius~ 圆角默认 0, on_change~ 翻转回调, style~/style_str~):底色默认取",
        "// 主题 fill_hover / 透明;指针位置轮询,不依赖 enter/leave——组内任意",
        "// 位置(含子控件)悬停即整组进入 hover 态",
        "@yue.hover_group(",
        "  // vbox(children 子节点数组, style~/style_str~ 默认空, handle~ 拿 Container):垂直布局",
        "  @yue.vbox(",
        "    [",
        "      @yue.label_t(\"组标题\", role=@yue.Section),",
        "      @yue.button_t(\"组内按钮\"),",
        "    ],",
        "    style=[(\"padding\", 14.0)],",
        "  ),",
        "  radius=8.0,",
        "  // on_change(hover 是否悬停, host 组容器句柄):仅在 hover 态翻转时回调",
        "  on_change=fn(hover, host) {",
        "    // set_cursor(视图, 光标) 设悬停光标;Cursor::new(类型) 新建光标",
        "    @yue.View::set_cursor(",
        "      host,",
        "      @yue.Cursor::new(if hover { @yue.Hand } else { @yue.Default }),",
        "    )",
        "  },",
        ")",
      ],
    ),
    @ui.section(
      "光标组",
      "CursorGroup 光标组",
      "父设子随:指针落在组内任意位置(含输入框、按钮等有独立窗口的子控件)都保持手型,移出恢复默认——与 hover_group 同机制的指针位置轮询,递归对组根+全部子孙设置。",
      [
        @yue.cursor_group(
          @yue.vbox(
            [
              @yue.label_t(
                "整组都是手型:移入试试,或移到子控件上",
                role=@yue.Section,
              ),
              @yue.hbox(
                [
                  @yue.input_t(text="组内输入框", width=200.0),
                  @yue.button_t("组内按钮"),
                ],
                style=[("marginTop", 10.0)],
                style_str=[("alignItems", "center")],
              ),
            ],
            style=[("padding", 14.0)],
          ),
        ),
      ],
      code=[
        "// cursor_group(child 组内容, cursor~ 组内光标默认手型, style~/style_str~):",
        "// 指针落在组内任意位置(含有独立窗口的子控件)都保持该光标,移出恢复默认",
        "// (非各子件原光标);组根+全部子孙递归设置(父设子随),机制同 hover_group",
        "@yue.cursor_group(",
        "  @yue.vbox(",
        "    [",
        "      @yue.label_t(\"整组都是手型\", role=@yue.Section),",
        "      // input_t(参数全可选:text~ 初始文本默认 \"\", password~ 密码态,",
        "      // margin~ 上下外边距 0, width~ 280, height~ 32, clearable~ 悬停且非空显 ✕ 清空,",
        "      // on_input~ 内容变化回调, invalid~ Store[Bool] 为 true 时边框变红)",
        "      @yue.input_t(text=\"组内输入框\", width=200.0),",
        "      @yue.button_t(\"组内按钮\"),",
        "    ],",
        "    style=[(\"padding\", 14.0)],",
        "  ),",
        ")",
      ],
    ),
  ])
}
