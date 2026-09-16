// 组件库演示板(showcase 风格):侧边导航切换分页,每页内多个
// 「标题 + 描述 + 全状态演示」分段。覆盖组件:
//   tag/tag_of_type · avatar · badge · statistic · alert(四类型/可关闭)
//   side_menu · segmented · breadcrumb · pagination · steps
//   descriptions · timeline · collapse · card · code_view
//   result · empty
// 配色为深色高级变体主题(theme_* 常量)。

///|
let title_color : String = "#356AA0"

///|
let desc_color : String = "#8A9199"

///|
/// 一段演示:标题 + 一句说明 + 演示区 + 分隔留白。
fn section(
  title : String,
  desc : String,
  content : Array[@yue.Node],
) -> @yue.Node {
  let t = @yue.label(
    title,
    style_str=[("color", title_color)],
    style=[("marginBottom", 4.0)],
    handle=fn(l) { l.set_align(@yue.Start) },
  )
  let d = @yue.label(
    desc,
    style_str=[("color", desc_color)],
    style=[("marginBottom", 10.0)],
    handle=fn(l) { l.set_align(@yue.Start) },
  )
  let nodes : Array[@yue.Node] = [t, d]
  for c in content {
    nodes.push(c)
  }
  nodes.push(@yue.separator(style=[("marginTop", 4.0), ("marginBottom", 20.0)]))
  @yue.vbox(nodes, style=[("marginBottom", 6.0)])
}

///|
/// 一页 = 整页滚动区包住全部分段。
fn scroll_page(sections : Array[@yue.Node]) -> @yue.Node {
  @yue.scroll(@yue.vbox(sections, style=[("padding", 14.0)]), style=[
    ("flex", 1.0),
  ])
}

///|
/// 主区页面:挂载后订阅导航状态做 set_visible 切换。
fn page(
  name : String,
  selected : @yue.Store[String],
  content : @yue.Node,
) -> @yue.Node {
  @yue.vbox([content], style=[("flex", 1.0)], handle=fn(c) {
    fn apply(s : String) -> Unit {
      c.set_visible(s == name)
    }

    apply(selected.get())
    selected.subscribe(apply)
  })
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let selected : @yue.Store[String] = @yue.Store::new("基础组件")
  // 演示用状态
  let page_no : @yue.Store[Int] = @yue.Store::new(2)
  let step : @yue.Store[Int] = @yue.Store::new(1)
  let visits : @yue.Store[String] = @yue.Store::new("12,804")
  let counter : @yue.Store[Int] = @yue.Store::new(0)
  counter.subscribe(fn(n) { visits.set((n * 1601 + 12804).to_string()) })
  let ratio : @yue.Store[Double] = @yue.Store::new(0.25)
  let sync : @yue.Store[Bool] = @yue.Store::new(false)
  let notify : @yue.Store[Bool] = @yue.Store::new(true)
  let theme_mode : @yue.Store[String] = @yue.Store::new("深色")
  let radio_disabled : @yue.Store[String] = @yue.Store::new("选项一")
  let wifi_on : @yue.Store[Bool] = @yue.Store::new(true)
  let locked : @yue.Store[Bool] = @yue.Store::new(false)
  sync.subscribe(fn(_v) { ignore(sync) })
  notify.subscribe(fn(_v) { ignore(notify) })
  counter.subscribe(fn(n) {
    let r = 0.25 + n.to_double() * 0.1
    ratio.set(if r > 1.0 { 1.0 } else { r })
  })
  // ---------- 基础组件 ----------
  let p_basic = scroll_page([
    section(
      "Button 按钮变体",
      "Solid 主题色实底 / Soft 浅底(hover 变实底白字) / Text 透明底(hover 浅灰) / Danger 红色实底,hover 全程主题内收敛。",
      [
        @yue.hbox(
          [
            @yue.button_t(
              "主要操作",
              on_click=fn() { counter.update(fn(n) { n + 1 }) },
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
      "Entry 输入框",
      "普通与密码输入,字体统一走主题(前景色保留系统样式)。",
      [
        @yue.vbox([
          @yue.entry_t(text="输入点什么…"),
          @yue.label(""),
          @yue.entry_t(text="密码", password=true),
        ]),
      ],
    ),
    section(
      "Checkbox 复选框",
      "自绘直角勾选框:选中实心主题色 + 白勾,hover 边框变主题色;第三项为禁用态。",
      [
        @yue.vbox([
          @yue.checkbox_t("启用自动同步", on_change=fn(v) { sync.set(v) }),
          @yue.checkbox_t("接收通知", checked=true, on_change=fn(v) {
            notify.set(v)
          }),
          @yue.checkbox_t("禁用项(不可点)", disabled=true),
        ]),
      ],
    ),
    section(
      "Radio 单选组",
      "选中项实心方块 + 主题色文字,整行悬停变色,点击互斥;第二组为禁用态。",
      [
        @yue.hbox([
          @yue.vbox([
            @yue.radio_group(["浅色", "深色", "跟随系统"], theme_mode),
          ]),
          @yue.label("        "),
          @yue.vbox([
            @yue.radio_group(
              ["选项一", "选项二"],
              radio_disabled,
              disabled=true,
            ),
          ]),
        ]),
      ],
    ),
    section(
      "Switch 开关",
      "开=主题蓝轨道滑块靠右,关=浅灰轨道滑块靠左;点击切换,含禁用态。",
      [
        @yue.hbox(
          [
            @yue.switch_t(wifi_on),
            @yue.bind_label(wifi_on, fn(v) {
              if v {
                "已开启"
              } else {
                "已关闭"
              }
            }),
            @yue.label("     "),
            @yue.switch_t(locked, disabled=true),
            @yue.label(" 禁用"),
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
      "Tag 标签",
      "五种语义类型(浅底深字)+ 自定义实底色;宽度按文本自适应,文字垂直居中。",
      [
        @yue.hbox(
          [
            @yue.tag_of_type("Primary", @yue.Primary),
            @yue.tag_of_type("Success", @yue.Success),
            @yue.tag_of_type("Warning", @yue.Warning),
            @yue.tag_of_type("Danger", @yue.Danger),
            @yue.tag_of_type("Info", @yue.Info),
          ],
          style_str=[("alignItems", "center")],
        ),
        @yue.hbox(
          [@yue.tag("自定义实底", "#2D68C4"), @yue.tag("v1.0", "#2E9E5B")],
          style=[("marginTop", 8.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "Avatar 头像",
      "方形实底色块 + 白色字母,三种尺寸。",
      [
        @yue.hbox(
          [
            @yue.avatar("M", "#2D68C4", size=44.0),
            @yue.avatar("N", "#2E9E5B", size=36.0),
            @yue.avatar("X", "#D64550", size=30.0),
            @yue.avatar("L", "#D9822B", size=26.0),
          ],
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
            @yue.label("   消息"),
            @yue.label("      "),
            @yue.badge_dot(),
            @yue.label(" 在线"),
          ],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "Alert 提示横幅",
      "四种语义类型:左侧色条 + 类型浅底 + 同族深字,文字垂直居中。",
      [
        @yue.alert("成功提示:配置已保存。", @yue.Success),
        @yue.alert("信息提示:有新版本可用。", @yue.Info),
        @yue.alert("警告提示:磁盘剩余空间不足。", @yue.Warning),
        @yue.alert("错误提示:网络连接已断开。", @yue.Danger),
      ],
    ),
    section("Alert 可关闭", "点击右侧 ✕ 关闭整条横幅。", [
      @yue.alert_closeable(
        "可关闭横幅:点我右侧的 ✕ 试试。",
        @yue.Warning,
      ),
    ]),
    section(
      "Statistic 数值统计",
      "大号数值响应式:点下面的按钮,数值经 Store 自动刷新。",
      [
        @yue.hbox(
          [
            @yue.statistic("访问量", visits),
            @yue.statistic("任务数", @yue.Store::new("36")),
          ],
          style_str=[("alignItems", "center")],
        ),
        @yue.button_t(
          "刷新访问量",
          on_click=fn() { counter.update(fn(n) { n + 1 }) },
          variant=@yue.Solid,
        ),
      ],
    ),
    section(
      "Progress 线性进度条",
      "主题色填充 + 浅灰轨道,数值响应式(随上面的刷新按钮联动变化)。",
      [
        @yue.progress_line(ratio),
        @yue.bind_label(
          ratio,
          fn(v) { "当前进度 \{((v * 100.0)).round()}%" },
          style=[("marginTop", 6.0)],
        ),
      ],
    ),
  ])
  // ---------- 导航 ----------
  let p_nav = scroll_page([
    section(
      "Segmented 分段控制器",
      "顶栏导航:选中白底 + 主题色文字,悬停灰底过渡;与左侧菜单共享状态。",
      [
        @yue.segmented(
          ["基础组件", "导航", "数据展示", "反馈"],
          selected,
        ),
      ],
    ),
    section(
      "Breadcrumb 面包屑",
      "层级随选中态联动:当前项深色,其余灰色可点、悬停变主题色。",
      [@yue.breadcrumb(["MoonShell", "控制台", "基础组件"], selected)],
    ),
    section(
      "Steps 步骤条",
      "完成/当前/待办三态:浅蓝、实底白字、灰;点按钮推进或回退。",
      [
        @yue.steps(["填写", "确认", "完成"], step),
        @yue.hbox(
          [
            @yue.button("上一步", on_click=fn() {
              step.update(fn(n) {
                let m = n - 1
                if m < 0 {
                  0
                } else {
                  m
                }
              })
            }),
            @yue.button(
              "下一步",
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
              style=[("marginLeft", 8.0)],
            ),
          ],
          style=[("marginTop", 8.0)],
        ),
      ],
    ),
    section(
      "Pagination 分页",
      "当前页主题色实底白字,悬停浅蓝;点击页码切换。",
      [@yue.pagination(page_no, 5)],
    ),
    section(
      "Side Menu 侧边导航",
      "窗口左侧即本组件:悬停灰底、选中浅蓝底 + 主题色文字 + 左侧强调条,点击切换页面。",
      [
        @yue.descriptions([
          ("悬停态", "浅灰底"),
          ("选中态", "主题浅蓝底 + 主题色文字 + 3px 强调条"),
          ("联动", "与分段控制器、面包屑共享同一 Store"),
        ]),
      ],
    ),
  ])
  // ---------- 数据展示 ----------
  let p_data = scroll_page([
    section("Descriptions 描述列表", "键灰值深的键值网格。", [
      @yue.descriptions([
        ("框架", "moonbit-libyue"),
        ("渲染", "GTK 3 (Linux) / Win32 (Windows)"),
        ("组件层", "纯 MoonBit,零平台代码"),
      ]),
    ]),
    section(
      "Timeline 时间线",
      "左侧色点 + 竖线,节点颜色跟随语义类型;末项无连线。",
      [
        @yue.timeline([
          ("发布 1.0", "2026-01-01,首个稳定版。", @yue.Success),
          ("发布 1.1", "2026-05-01,新增组件库。", @yue.Primary),
          ("进行中", "2.0 规划:终端组件。", @yue.Warning),
        ]),
      ],
    ),
    section(
      "Collapse 折叠面板",
      "点击标题展开/收起,各面板独立;初始第一个展开。",
      [
        @yue.collapse([
          (
            "如何使用组件库?",
            [
              @yue.label(
                "moon add NoahLiu/moonbit-libyue 后即可用 @yue.* 访问。",
              ),
            ],
          ),
          (
            "支持哪些平台?",
            [@yue.label("Linux(X11)/ Windows;macOS 进行中。")],
          ),
        ]),
      ],
    ),
    section(
      "Card 卡片",
      "标题栏 + 底部分隔线 + 边框,内容区自动留出标题高度。",
      [
        @yue.card(
          "卡片标题",
          [
            @yue.label(
              "卡片内容:组件库全部用 theme_* 常量着色。",
            ),
          ],
          height=110.0,
        ),
      ],
    ),
    section(
      "Code View 代码高亮",
      "逐 token 整段设色 + 测宽自绘,全平台一致(绕开 Windows 区间设色缺陷)。",
      [
        @yue.code_view(
          [
            "// 深色主题 · 关键字/字符串/数字/注释", "fn main {",
            "  let msg = \"hello 组件库\"", "  println(msg + \"!\" )  // 2026",
            "}",
          ],
          width=430.0,
        ),
      ],
    ),
  ])
  // ---------- 反馈 ----------
  let p_feedback = scroll_page([
    section(
      "Result 结果页",
      "大色块符号 + 标题 + 描述 + 操作区;四种语义类型。",
      [
        @yue.result(
          @yue.Success,
          "操作成功",
          "配置已写入并生效。",
          [@yue.button("返回首页")],
        ),
        @yue.result(
          @yue.Danger,
          "操作失败",
          "网络异常,请稍后重试。",
          [@yue.button("重新加载")],
        ),
      ],
    ),
    section("Empty 空状态", "占位图 + 说明文字。", [
      @yue.empty("这里还没有内容"),
    ]),
    section("Statistic 复习", "统计数值也是响应式组件。", [
      @yue.hbox([@yue.statistic("在线用户", @yue.Store::new("1,024"))], style_str=[
        ("alignItems", "center"),
      ]),
    ]),
  ])
  let window = @yue.mount_window(
    [
      @yue.hbox(style=[("flex", 1.0)], style_str=[("alignItems", "stretch")], [
        @yue.side_menu(
          ["基础组件", "导航", "数据展示", "反馈"],
          selected,
        ),
        @yue.vbox(
          [
            @yue.hbox(
              [
                @yue.segmented(
                  ["基础组件", "导航", "数据展示", "反馈"],
                  selected,
                ),
                @yue.label("      "),
                @yue.tag("MoonShell", "#2D68C4"),
                @yue.tag("v0.2", "#2E9E5B"),
              ],
              style=[("padding", 10.0)],
              style_str=[("alignItems", "center")],
              handle=fn(c) { c.set_background_color("#FFFFFF") },
            ),
            page("基础组件", selected, p_basic),
            page("导航", selected, p_nav),
            page("数据展示", selected, p_data),
            page("反馈", selected, p_feedback),
          ],
          style=[("flex", 1.0)],
          handle=fn(c) { c.set_background_color("#F5F6F7") },
        ),
      ]),
    ],
    title="组件库演示板",
    size=Some((880.0, 720.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  window.activate()
  @yue.run()
}
