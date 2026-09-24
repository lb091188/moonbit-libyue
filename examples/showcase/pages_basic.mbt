// 基础组件页:Signal 驱动的主题组件演示。共享状态(counter 计数、
// picked_lang 最近操作)在 App;页内状态用源信号,展示端用 bind 直连,
// 无手动 subscribe 接线。勾选类在表单组件页,右键菜单在导航组件页。

///|
fn page_basic(app : App) -> @yue.Node {
  scroll_page([
    section(
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
        @yue.bind(app.accent.signal(), fn(s) {
          if s == "" {
            "当前主色:内置默认"
          } else {
            "当前主色:\{s}"
          }
        }, style=[("marginTop", 8.0)]),
      ],
    ),
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
      "Label 文字与 Link 链接",
      "五级排版角色,字号颜色随角色;Link 主题色文字悬停下划线,最近点击信号回显。",
      [
        @yue.label_t("标题文字(Title)", role=@yue.Title, style=[("marginTop", 8.0)]),
        @yue.label_t("小节标题(Section)", role=@yue.Section, style=[("marginTop", 8.0)]),
        @yue.label_t("正文文字(Body)", role=@yue.Body, style=[("marginTop", 8.0)]),
        @yue.label_t("辅助文字(Secondary)", role=@yue.Secondary, style=[("marginTop", 8.0)]),
        @yue.label_t("强调文字(Accent)", role=@yue.Accent, style=[("marginTop", 8.0)]),
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
    ),
    section(
      "Divider 分隔线与 Tooltip 悬浮提示",
      "水平(默认)/竖直 1px 主题边框色;tooltip_t 给任意节点包原生悬浮提示(系统样式,主题化气泡见反馈页 Popover)。",
      [
        @yue.label_t("上方内容"),
        @yue.divider(spacing=6.0),
        @yue.label_t("下方内容"),
        @yue.hbox(
          [
            @yue.tooltip_t(@yue.button_t("悬停看提示"), "原生 tooltip:系统样式"),
            @yue.tooltip_t(@yue.button_t("再来一个", variant=@yue.Soft), "第二个提示"),
          ],
          style=[("marginTop", 10.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "OverlayScroll 悬浮滚动条",
      "滚动/悬停右缘浮现主题色细条,停顿渐隐,可拖拽;平台原生滚动条隐藏(Windows 经典条常驻占位,悬浮形态由组件统一)。滚动或拖拽右缘体验。",
      [
        @yue.overlay_scroll(
          @yue.vbox(
            [
              @yue.label_t("滚动内容区(悬浮滚动条演示)", role=@yue.Section),
              @yue.label("第 1 行:滚动或拖动右缘细条"),
              @yue.label("第 2 行:停顿约一秒细条渐隐"),
              @yue.label("第 3 行:悬停细条保持显示"),
              @yue.label("第 4 行:按住可拖拽"),
              @yue.label("第 5 行"),
              @yue.label("第 6 行"),
              @yue.label("第 7 行"),
              @yue.label("第 8 行"),
              @yue.label("第 9 行"),
              @yue.label("第 10 行:到底部了"),
            ],
            style=[("padding", 10.0)],
          ),
          style=[("height", 180.0)],
        ),
      ],
    ),
    section(
      "HoverGroup 悬停组",
      "组内任意位置(含子控件)悬停即整组进入 hover 态:把指针移到卡片里的按钮或输入框上,整张卡片同样高亮且光标变手型——GTK 下子控件的事件窗口会独占指针事件,组件用指针位置轮询判定,不依赖 enter/leave,不闪烁。",
      [
        @yue.hover_group(
          @yue.vbox(
            [
              @yue.label_t("组标题:悬停我,或下面的子控件", role=@yue.Section),
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
    ),
    section(
      "CursorGroup 光标组",
      "父设子随:指针落在组内任意位置(含输入框、按钮等有独立窗口的子控件)都保持手型,移出恢复默认——与 hover_group 同机制的指针位置轮询,递归对组根+全部子孙设置。",
      [
        @yue.cursor_group(
          @yue.vbox(
            [
              @yue.label_t("整组都是手型:移入试试,或移到子控件上", role=@yue.Section),
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
    ),
  ])
}
