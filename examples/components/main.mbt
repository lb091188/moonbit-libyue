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
  let qty : @yue.Store[Double] = @yue.Store::new(3.0)
  let qty2 : @yue.Store[Double] = @yue.Store::new(1.0)
  let picked_lang : @yue.Store[String] = @yue.Store::new("")
  let transfer_left : @yue.Store[Array[String]] = @yue.Store::new([
    "北京", "上海", "广州",
  ])
  let transfer_right : @yue.Store[Array[String]] = @yue.Store::new(["深圳"])
  let wifi_on : @yue.Store[Bool] = @yue.Store::new(true)
  let locked : @yue.Store[Bool] = @yue.Store::new(false)
  let table_rows : @yue.Store[Array[@yue.TableRow]] = @yue.Store::new([
    @yue.TableRow::make(["MoonBit", "2023", "多范式,云 + 端"]),
    @yue.TableRow::make(["Rust", "2015", "系统编程"]),
    @yue.TableRow::make(["Go", "2012", "云原生后端"]),
    @yue.TableRow::make(["TypeScript", "2012", "前端大规模工程"]),
  ])
  let table_picked : @yue.Store[String] = @yue.Store::new("未选中")
  let table_sel : @yue.Store[Array[Int]] = @yue.Store::new([])
  let slider_val : @yue.Store[Double] = @yue.Store::new(30.0)
  let rate_val : @yue.Store[Int] = @yue.Store::new(3)
  let picked_color : @yue.Store[String] = @yue.Store::new("#2D68C4")
  let dp_val : @yue.Store[@yue.DateYMD?] = @yue.Store::new(None)
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
  sync.subscribe(fn(_v) { ignore(sync) })
  notify.subscribe(fn(_v) { ignore(notify) })
  counter.subscribe(fn(n) {
    let r = 0.25 + n.to_double() * 0.1
    ratio.set(if r > 1.0 { 1.0 } else { r })
  })

  let sc_handle : Ref[@yue.Scroll?] = Ref(None)
  let tall : Array[@yue.Node] = []
  for i in 0..<20 {
    tall.push(
      @yue.label_t(
        "\{i + 1}. 向下滚动的内容行,点右下角 ↑ 回顶部",
        role=@yue.Body,
      ),
    )
  }

  // ---------- 基础组件(EP Basic) ----------
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
      "主题色文字,悬停显示下划线,点击回调。",
      [
        @yue.hbox([
          @yue.link("打开文档", fn() { picked_lang.set("docs") }),
          @yue.label("   "),
          @yue.link("帮助中心", fn() { picked_lang.set("help") }),
          @yue.label("   最近点击:"),
          @yue.bind_label(picked_lang, fn(s) { s }),
        ]),
      ],
    ),
    section(
      "Divider 分隔线",
      "水平(默认)/竖直 1px 主题边框色,spacing 控制两侧留白。",
      [
        @yue.label("上方内容"),
        @yue.divider(spacing=6.0),
        @yue.label("下方内容"),
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
  // ---------- 表单组件(EP Form) ----------
  let p_form = scroll_page([
    section(
      "Input 输入框",
      "现代化主题唯一输入框:外层自绘 1px 边框(聚焦变主题蓝)+ 白底,内部 Entry 去原生边框与内阴影;margin 控制外边距,直角。",
      [
        @yue.vbox([
          @yue.input_t(text="输入点什么…", margin=10.0),
          @yue.input_t(text="密码框", password=true),
        ]),
      ],
    ),
    section(
      "Textarea 多行输入",
      "外层自绘边框(聚焦变主题色)+ 8px 内边距,内容超出按平台滚动。",
      [
        @yue.textarea_t(
          text="多行文本输入演示。\n第二行内容。",
          height=90.0,
          width=300.0,
        ),
      ],
    ),
    section(
      "InputNumber 数字输入器",
      "-/+ 按钮步进(步长 1),范围 0..10 钳制,数值响应式。",
      [
        @yue.input_number(qty, min=0.0, max=10.0, step=1.0),
        @yue.bind_label(qty, fn(v) { "当前数量:\{v.round()}" }, style=[
          ("marginTop", 6.0),
        ]),
      ],
    ),
    section(
      "Select 下拉选择",
      "可过滤下拉(EP 样式):点字段弹候选,输入实时筛选,↑↓ 高亮、回车选中,Esc 收起;当前选中 ✓ 标记。",
      [
        @yue.select_t(
          ["杭州", "北京", "上海", "深圳", "广州"],
          picked_lang,
          width=170.0,
        ),
      ],
    ),
    section(
      "DatePicker 日期选择",
      "全自绘日历(EP 样式):点字段弹月历,‹/› 切月,点选回填;下方为内联 calendar_t 面板。",
      [
        @yue.hbox(
          [
            @yue.date_picker_t(value=dp_val, width=170.0),
            @yue.label("   选中:"),
            @yue.bind_label(dp_val, fn(d) {
              match d {
                Some(v) => v.format()
                None => "未选"
              }
            }),
          ],
          style_str=[("alignItems", "center")],
        ),
        @yue.calendar_t(),
      ],
    ),
    section(
      "Slider 滑杆",
      "自绘轨道 + thumb,点击/拖拽调值(step 5 量化),值响应式。",
      [
        @yue.slider_t(slider_val, min=0.0, max=100.0, step=5.0),
        @yue.bind_label(slider_val, fn(v) { "当前值:\{v.round()}" }),
      ],
    ),
    section(
      "Rate 评分",
      "五角星:选中实心主题色、未选中描边灰,hover 预亮,点击评分。",
      [
        @yue.rate_t(rate_val, on_change=fn(v) { ignore(v) }),
        @yue.bind_label(rate_val, fn(v) { "评分:\{v} 星" }),
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
      "ColorPicker 取色器",
      "预设色板:点击选色,选中主题色描边 + 白勾;hex 值响应式。",
      [@yue.color_picker_t(picked_color)],
    ),
    section(
      "Form 表单",
      "form_item 行布局(标签右对齐 + 控件区)+ form 分组标题。",
      [
        @yue.form("用户设置", [
          @yue.form_item("用户名", @yue.input_t(text="moonbit", width=200.0)),
          @yue.form_item("城市", @yue.input_t(text="杭州", width=200.0)),
          @yue.form_item("数量", @yue.input_number(qty2, min=1.0, max=9.0)),
        ]),
      ],
    ),
  ])
  // ---------- 导航组件(EP Navigation) ----------
  let p_nav = scroll_page([
    section(
      "Side Menu 侧边导航",
      "窗口左侧即本组件(分组形态 side_menu_sections):组标题不可点,菜单项悬停灰底、选中浅蓝底 + 主题色文字 + 左侧强调条,点击切换页面。",
      [
        @yue.descriptions([
          ("悬停态", "浅灰底"),
          ("选中态", "主题浅蓝底 + 主题色文字 + 3px 强调条"),
          ("联动", "与分段控制器、面包屑共享同一 Store"),
        ]),
      ],
    ),
    section(
      "Segmented 分段控制器",
      "顶栏导航:选中白底 + 主题色文字,悬停灰底过渡;与左侧菜单共享状态。",
      [
        @yue.segmented(
          ["基础组件", "表单组件", "导航组件", "数据展示", "反馈组件"],
          selected,
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
      [@yue.breadcrumb(["MoonShell", "控制台", "基础组件"], selected)],
    ),
    section(
      "Pagination 分页",
      "当前页主题色实底白字,悬停浅蓝;点击页码切换。",
      [@yue.pagination(page_no, 5)],
    ),
    section(
      "Steps 步骤条",
      "完成/当前/待办三态:浅蓝、实底白字、灰;点按钮推进或回退。",
      [
        @yue.steps(["填写", "确认", "完成"], step),
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
          ],
          style=[("marginTop", 8.0)],
        ),
      ],
    ),
    section(
      "PageHeader 页头",
      "‹ 返回(悬停变主题色)+ 标题 + 右侧操作区;点返回回到基础组件页。",
      [
        @yue.page_header(
          "进阶组件",
          fn() { selected.set("基础组件") },
          actions=[@yue.button_t("页面操作", variant=@yue.Soft)],
        ),
      ],
    ),
    section(
      "Backtop 返回顶部",
      "滚动下方区域,点右下角 ↑ 按钮回顶部(scroll 句柄 + 定位 API)。",
      [
        @yue.vbox(
          [
            @yue.scroll(
              @yue.vbox(tall, style=[("padding", 8.0)]),
              style=[("flex", 1.0)],
              handle=fn(s) { sc_handle.val = Some(s) },
            ),
            @yue.hbox(
              [
                @yue.label("        "),
                @yue.backtop_t(fn() {
                  match sc_handle.val {
                    Some(s) => s.set_scroll_position(0.0, 0.0)
                    None => ()
                  }
                }),
              ],
              style=[("padding", 4.0)],
              style_str=[("alignItems", "center")],
            ),
          ],
          style=[("height", 150.0)],
          style_str=[("position", "relative"), ("flexDirection", "column")],
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
              fn(i) { picked_lang.set("菜单项 \{i}") },
          width=140.0,
        ),
        @yue.bind_label(picked_lang, fn(s) { "最近操作:\{s}" }),
      ],
    ),
  ])
  // ---------- 数据展示(EP Data Display) ----------
  let p_data = scroll_page([
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
    section(
      "Card 卡片",
      "标题栏 + 底部分隔线 + 边框,内容区自动留出标题高度。",
      [
        @yue.card(
          "卡片标题",
          [
            @yue.label(
              "卡片内容:组件库全部用 theme_* 主题色着色。",
            ),
          ],
          height=110.0,
        ),
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
    section(
      "Table 表格",
      "表头 + 斑马纹 + 悬停底色,点击行单选;「添加一行」经 Store 驱动整表重建。",
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
            @yue.bind_label(table_picked, fn(s) { s }),
          ],
          style=[("marginTop", 8.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "Table 表格(多选 + 富单元格)",
      "复选框列:行点击勾选,表头全选/清空(部分选中画横条);单元格支持 tag/颜色块/多行文本(行自动撑高)。",
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
        @yue.bind_label(table_sel, fn(s) { "已选 \{s.length()} 行" }),
      ],
    ),
    section(
      "Table 虚拟滚动表格",
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
      "Transfer 穿梭框",
      "点击行选中(方块标记),中间 ›/‹ 把选中项移到对侧。",
      [@yue.transfer(transfer_left, transfer_right)],
    ),
    section(
      "Carousel 轮播",
      "面板序列 + 左右箭头 + 底部指示点,3 秒自动切换(悬停暂停)。",
      [
        @yue.carousel_t(
          [
            @yue.label_t("第一屏:轮播内容可为任意 Node。", role=@yue.Body),
            @yue.label_t("第二屏:自动轮播 3s 一切。", role=@yue.Body),
            @yue.label_t("第三屏:悬停暂停,箭头/圆点手动切。", role=@yue.Body),
          ],
          width=320.0,
          height=80.0,
        ),
      ],
    ),
    section("Empty 空状态", "占位图 + 说明文字。", [
      @yue.empty("这里还没有内容"),
    ]),
  ])
  // ---------- 反馈组件(EP Feedback) ----------
  let p_feedback = scroll_page([
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
      "Result 结果页",
      "大色块符号 + 标题 + 描述 + 操作区;四种语义类型。",
      [
        @yue.result(
          @yue.Success,
          "操作成功",
          "配置已写入并生效。",
          [@yue.button_t("返回首页")],
        ),
        @yue.result(
          @yue.Danger,
          "操作失败",
          "网络异常,请稍后重试。",
          [@yue.button_t("重新加载", variant=@yue.Soft)],
        ),
      ],
    ),
    section(
      "Popover 气泡弹层",
      "popover_t 给任意节点包点击弹层:内容为任意 Node,再次点击收起。",
      [
        @yue.popover_t(
          @yue.button_t("打开气泡"),
          @yue.label_t("气泡内容:任意 Node。", role=@yue.Body),
          180.0,
          60.0,
        ),
      ],
    ),
  ])
  let window = @yue.mount_window(
    [
      @yue.hbox(style=[("flex", 1.0)], style_str=[("alignItems", "stretch")], [
        @yue.side_menu_sections(
          [
            ("基础", ["基础组件", "表单组件"]),
            ("进阶", ["导航组件", "数据展示", "反馈组件"]),
          ],
          selected,
        ),
        @yue.vbox(
          [
            @yue.hbox(
              [
                @yue.segmented(
                  ["基础组件", "表单组件", "导航组件", "数据展示", "反馈组件"],
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
            page("表单组件", selected, p_form),
            page("导航组件", selected, p_nav),
            page("数据展示", selected, p_data),
            page("反馈组件", selected, p_feedback),
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
