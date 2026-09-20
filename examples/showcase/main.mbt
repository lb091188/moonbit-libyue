// 组件库演示板(showcase 风格):侧边导航切换分页,每页内多个
// 「标题 + 描述 + 全状态演示」分段。覆盖组件:
//   tag/tag_of_type · avatar · badge · statistic · alert(四类型/可关闭)
//   side_menu · segmented · breadcrumb · pagination · steps
//   descriptions · timeline · collapse · card · code_view
//   result · empty
// 配色为深色高级变体主题(theme_* 常量)。

///|
/// 一段演示:标题 + 一句说明 + 演示区 + 分隔留白。
/// 标题/说明走 label_t 文字角色(Section / Secondary)。
fn is_linux() -> Bool {
  @yue.platform() == "linux"
}

///|
fn section(
  title : String,
  desc : String,
  content : Array[@yue.Node],
) -> @yue.Node {
  let t = @yue.label_t(title, role=@yue.Section, style=[
    ("marginBottom", 4.0),
  ])
  let d = @yue.label_t(desc, role=@yue.Secondary, style=[
    ("marginBottom", 10.0),
  ])
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
  let (toast_node, toast_push) = @yue.toast_layer()
  let win_ref : Ref[@yue.Window?] = Ref(None)
  let tray_ref : Ref[@yue.Tray?] = Ref(None)
  let ontop : Ref[Bool] = Ref(false)
  // 原生控件页状态
  let nat_clicks : @yue.Store[Int] = @yue.Store::new(0)
  let nat_echo : @yue.Store[String] = @yue.Store::new("")
  let nat_slider : @yue.Store[Double] = @yue.Store::new(0.0)
  let nat_pick : @yue.Store[String] = @yue.Store::new("乙")
  let nat_combo : @yue.Store[String] = @yue.Store::new("MoonBit")
  let nat_picker : @yue.Store[String] = @yue.Store::new("(未选择)")
  let nat_bar : Ref[@yue.ProgressBar?] = Ref(None)
  let nat_indet : Ref[Bool] = Ref(false)
  let nat_cb : Ref[@yue.ComboBox?] = Ref(None)
  let nat_pk : Ref[@yue.Picker?] = Ref(None)
  let nat_edit : Ref[@yue.TextEdit?] = Ref(None)
  let nat_pop : Ref[@yue.Button?] = Ref(None)
  let nat_date_val : @yue.Store[Int64] = @yue.Store::new(946684800L)
  let nat_date = @yue.DatePicker::new_with({
    elements: @yue.HourMinute,
    has_stepper: true,
  })
  nat_date.set_date(946684800L)
  nat_date.on_date_change(fn() { nat_date_val.set(nat_date.get_date()) })
  // 画布页状态与资产
  let canvas_hue = Ref(0)
  let canvas_blend = Ref(0)
  let canvas_blends = [
    @yue.BlendMode::Normal,
    @yue.Multiply,
    @yue.Screen,
    @yue.Difference,
    @yue.Xor,
  ]
  let canvas_blend_names = ["Normal", "Multiply", "Screen", "Difference", "Xor"]
  let canvas_info : @yue.Store[String] = @yue.Store::new("Normal")
  let canvas_ref : Ref[@yue.Container?] = Ref(None)
  let canvas_rt : Ref[@yue.Container?] = Ref(None)
  let canvas_img : Ref[@yue.Image?] = Ref(
    match @yue.read_binary_file("examples/showcase/icon.png") {
      Some(bytes) => {
        let img = @yue.Image::new_from_png(bytes)
        if img.is_empty() {
          None
        } else {
          Some(img)
        }
      }
      None => None
    },
  )
  let canvas_repaint = fn() -> Unit {
    match canvas_ref.val {
      Some(c) => c.schedule_paint()
      None => ()
    }
  }
  let draw_canvas_scene = fn(painter : @yue.Painter) -> Unit {
    painter.set_fill_color("#20242C")
    painter.fill_rect(0.0, 0.0, 640.0, 300.0)
    let colors = ["#E8B34B", "#4B8BE8", "#4BE888"]
    for i in 0..<3 {
      painter.set_fill_color(colors[(i + canvas_hue.val) % 3])
      painter.arc(160.0 + i.to_double() * 160.0, 130.0, 60.0, 0.0, 6.28318)
      painter.fill()
    }
    painter.set_stroke_color("#4A5060")
    for k in 0..<9 {
      painter.stroke_rect(24.0, 205.0 + k.to_double() * 10.0, 592.0, 1.0)
    }
    painter.draw_text(
      "MoonBit × libyue 自绘文本",
      24.0,
      262.0,
      592.0,
      30.0,
      align=@yue.TextAlign::Center,
      color="#F0F0F0",
    )
    match (canvas_ref.val, canvas_img.val) {
      (Some(c), Some(img)) => {
        painter.set_blend_mode(canvas_blends[canvas_blend.val])
        let b = c.get_bounds()
        painter.draw_image(img, b.width - 90.0, 10.0, 80.0, 80.0)
        painter.set_blend_mode(@yue.Normal)
      }
      (_, _) => ()
    }
  }
  // 富文本对象
  let rt = @yue.AttributedText::new_with(
    "MoonBit 富文本:这段文字有范围着色与粗体。",
    @yue.TextAttributes::new(),
  )
  rt.set_font(@yue.Font::new("Sans", 20.0, weight=@yue.Bold))
  rt.set_font_for(@yue.Font::new("Sans", 24.0, weight=@yue.Black), 0, 6)
  rt.set_color("#356AA0")
  rt.set_color_for("#E5534B", 8, 11)
  let rt_wrap = Ref(true)
  let rt_ellipsis = Ref(false)
  // 环境页状态
  let key_info : @yue.Store[String] = @yue.Store::new("(无)")
  let web_ref : Ref[@yue.Browser?] = Ref(None)
  // 事件与布局页状态
  let evt_mouse : @yue.Store[String] = @yue.Store::new("(移入色块区操作)")
  let evt_dbl : @yue.Store[String] = @yue.Store::new("(双击计数)")
  let evt_cap : @yue.Store[String] = @yue.Store::new("未捕获")
  let evt_area : Ref[@yue.Container?] = Ref(None)
  let evt_clicks = @yue.ClickTracker::new()
  let evt_gmouse : @yue.Store[String] = @yue.Store::new("(全局鼠标,200ms 轮询)")
  ignore(
    @yue.set_timer(200, fn() {
      let (mx, my) = @yue.mouse_location()
      let mut mods = ""
      if @yue.shift_pressed() {
        mods = mods + "Shift "
      }
      if @yue.control_pressed() {
        mods = mods + "Ctrl "
      }
      if @yue.alt_pressed() {
        mods = mods + "Alt "
      }
      evt_gmouse.set("全局鼠标 (\{mx.round()}, \{my.round()}) 修饰键 \{mods}")
      true
    }),
  )
  let cursor_area : Ref[@yue.Container?] = Ref(None)
  let cursor_now : @yue.Store[String] = @yue.Store::new("Default")
  let apply_cursor = fn(t : @yue.CursorType, name : String) -> Unit {
    match cursor_area.val {
      Some(c) => {
        @yue.View::set_cursor(c, @yue.Cursor::new(t))
        cursor_now.set(name)
      }
      None => ()
    }
  }
  // 系统集成页补充状态
  let close_veto : Ref[Bool] = Ref(false)
  let veto_info : @yue.Store[String] = @yue.Store::new("(未开启拦截)")
  let tray_clicks : @yue.Store[Int] = @yue.Store::new(0)
  let sel_out : @yue.Store[String] = @yue.Store::new("(主选区读回)")
  // 原生控件页补充状态
  let nat_tab_sw : @yue.Store[Int] = @yue.Store::new(0)
  let nat_scroll : Ref[@yue.Scroll?] = Ref(None)
  let nat_policy : Ref[Bool] = Ref(false)
  // Browser 导航与 binding 状态
  let nav_state : @yue.Store[String] = @yue.Store::new("(导航状态)")
  let nav_events : @yue.Store[String] = @yue.Store::new("(导航回调)")
  let bind_state : @yue.Store[String] = @yue.Store::new("(raw binding)")
  // 自定义协议(Browser 段 demo:// 链接用;Windows 静默无效)
  @yue.Browser::register_protocol("demo", fn(_url) {
    Some(
      (
        "text/html",
        "<html><body style='font-family:sans-serif;background:#fff;color:#222'><h2>demo:// 自定义协议 ✓</h2><p>由 register_protocol 注册,ProtocolStringJob 应答。</p></body></html>",
      ),
    )
  })
  let dlg_basic : @yue.Store[Bool] = @yue.Store::new(false)
  let dlg_form : @yue.Store[Bool] = @yue.Store::new(false)
  let dlg_name : @yue.Store[String] = @yue.Store::new("")
  // 深浅主题:启动跟随系统,系统切换时实时联动;「切换深浅」按钮手动覆盖
  let dark_mode : @yue.Store[Bool] = @yue.Store::new(@yue.system_prefers_dark())
  dark_mode.subscribe(fn(v) {
    if v {
      @yue.theme_apply(@yue.dark_theme())
    } else {
      @yue.theme_apply(@yue.default_theme())
    }
  })
  @yue.on_system_theme_change(fn() { dark_mode.set(@yue.system_prefers_dark()) })
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

  // ---------- 基础组件(EP Basic) ----------
  let p_basic = scroll_page([
    section(
      "Icon 图标系统 / IconButton 图标按钮",
      "37 个内置矢量图标(draw_icon 统一入口,悬停看名称);icon_button_t 方形 hover 收敛按钮,工具栏排列右侧统一 6px 间距。",
      [
        @yue.hbox(
          (
            {
              let cells : Array[@yue.Node] = []
              let icons = @yue.all_icons()
              for row in 0..<4 {
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
          @yue.label_t("最近点击:", role=@yue.Body),
          @yue.bind_label(picked_lang, fn(s) { s }),
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
            ("复制", fn() { picked_lang.set("已复制") }),
            ("重命名", fn() { picked_lang.set("重命名") }),
            ("-", fn() {  }),
            ("删除", fn() { picked_lang.set("已删除") }),
          ],
        ),
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
      "现代化主题唯一输入框:外层自绘 1px 边框(聚焦变主题蓝)+ 白底,内部 Entry 去原生边框与内阴影;margin 控制外边距,直角。clearable=true:悬停且非空时右侧出现 ✕,点击清空。",
      [
        @yue.vbox([
          @yue.input_t(text="输入点什么…", margin=10.0),
          @yue.input_t(text="密码框", password=true),
          @yue.input_t(text="悬停出现 ✕,点击清空", clearable=true),
        ]),
      ],
    ),
    section(
      "Textarea 多行输入",
      "外层自绘边框(聚焦变主题色)+ 8px 内边距,内容超出按平台滚动;clearable=true 悬停非空时 ✕ 清空。",
      [
        @yue.textarea_t(
          text="多行文本输入演示。\n第二行内容。",
          height=90.0,
          width=300.0,
          clearable=true,
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
      "点击字段弹候选列表(EP 样式):悬停高亮、当前选中 ✓ 标记,点选回填并收起;clearable=true 悬停有值时箭头旁 ✕ 清空选择;三平台同形态。",
      [
        @yue.select_t(
          ["杭州", "北京", "上海", "深圳", "广州"],
          picked_lang,
          width=170.0,
          clearable=true,
        ),
      ],
    ),
    section(
      "DatePicker 日期选择",
      "全自绘日历(EP 样式):点字段弹月历,‹/› 切月,点选回填;下方为内联 calendar_t 面板;clearable=true 悬停有值时 ✕ 清空。",
      [
        @yue.hbox(
          [
            @yue.date_picker_t(value=dp_val, width=170.0, clearable=true),
            @yue.label_t("选中:", role=@yue.Body),
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
            @yue.label_t("禁用", role=@yue.Body),
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
            @yue.label_t("消息", role=@yue.Body),
            @yue.label("      "),
            @yue.badge_dot(),
            @yue.label_t("在线", role=@yue.Body),
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
            @yue.label_t("卡片内容:组件库全部用 theme_* 主题色着色。"),
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
              @yue.label_t(
                "moon add NoahLiu/moonbit-libyue 后即可用 @yue.* 访问。",
              ),
            ],
          ),
          (
            "支持哪些平台?",
            [@yue.label_t("Linux(X11)/ Windows;macOS 进行中。")],
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
    section(
      "Toast 轻提示",
      "操作反馈瞬态提示:推送后顶部居中出现,2.6 秒自动消失,多条堆叠;层挂在窗口根(absolute 顶部,不占布局)。",
      [
        @yue.hbox([
          @yue.button_t("成功", on_click=fn() { toast_push("保存成功", @yue.Success) }),
          @yue.button_t("警告", on_click=fn() { toast_push("连接超时,已重试", @yue.Warning) }),
          @yue.button_t("错误", on_click=fn() { toast_push("提交失败:网络不可达", @yue.Danger) }),
          @yue.button_t("普通", variant=@yue.Solid, on_click=fn() { toast_push("已加入下载队列", @yue.Info) }),
        ]),
      ],
    ),
    section(
      "Dialog 对话框",
      "同窗遮罩 + 居中面板(absolute 相对挂载容器,本演示挂在窗口根,遮罩盖全窗);✕/取消/确定触发回调后自动收起,visible 由 Store 驱动。",
      [
        @yue.hbox([
          @yue.button_t("基础对话框", on_click=fn() { dlg_basic.set(true) }),
          @yue.button_t("表单对话框", variant=@yue.Solid, on_click=fn() { dlg_form.set(true) }),
          @yue.bind_label(dlg_name, fn(n) { if n == "" { "尚未提交" } else { "提交了:\\{n}" } }),
        ]),
      ],
    ),
  ])
  // ---------- 系统能力(现代主题包装的 libyue 系统件) ----------
  let p_sys_secs : Array[@yue.Node] = [
    section(
      "文件对话框",
      "FileDialog 模态打开/保存,回显所选路径;配套 read/write_text_file 直读直写。",
      [
        @yue.hbox([
          @yue.button_t("打开文件…", on_click=fn() {
            match win_ref.val {
              Some(w) => {
                let dlg = @yue.FileDialog::new_open()
                dlg.set_filters("文本文件:txt,md|所有文件:*")
                if dlg.run_for_window(w) {
                  toast_push("已选 \{dlg.get_result()}", @yue.Success)
                } else {
                  toast_push("已取消", @yue.Info)
                }
              }
              None => ()
            }
          }),
          @yue.button_t("保存文件…", on_click=fn() {
            match win_ref.val {
              Some(w) => {
                let dlg = @yue.FileDialog::new_save()
                dlg.set_filename("components.txt")
                if dlg.run_for_window(w) {
                  let ok = @yue.write_text_file(dlg.get_result(), "由 components 写入\n")
                  toast_push(
                    if ok { "已保存 \{dlg.get_result()}" } else { "保存失败" },
                    if ok { @yue.Success } else { @yue.Danger },
                  )
                } else {
                  toast_push("已取消", @yue.Info)
                }
              }
              None => ()
            }
          }),
        ]),
      ],
    ),
    section(
      "消息框",
      "原生 MessageBox(模态对话):标题/正文/按钮,响应 id 回传。",
      [
        @yue.hbox([
          @yue.button_t("询问框", on_click=fn() {
            match win_ref.val {
              Some(w) => {
                let box = @yue.MessageBox::new(@yue.Information)
                box.set_title("确认操作")
                box.set_text("要执行该操作吗?")
                box.add_button("确定", 1)
                box.add_button("取消", 2)
                box.on_response(fn(code) {
                  toast_push("消息框响应 id=\{code}", @yue.Info)
                })
                box.show_for_window(w)
              }
              None => ()
            }
          }),
          @yue.button_t("警告框", on_click=fn() {
            match win_ref.val {
              Some(w) => {
                let box = @yue.MessageBox::new(@yue.Warning)
                box.set_title("警告")
                box.set_text("此操作不可撤销!")
                box.show_for_window(w)
              }
              None => ()
            }
          }),
        ]),
      ],
    ),
    section(
      "系统通知",
      "Notification 提交系统通知中心(桌面端右上角弹出,应用外可见);set_actions 带操作按钮,set_silent 静默发送。",
      [
        @yue.hbox([
          @yue.button_t("普通通知", on_click=fn() {
            let n = @yue.Notification::new()
            n.set_title("components 演示")
            n.set_body("这是一条系统通知,点击后已提交通知中心。")
            n.show()
            toast_push("通知已提交", @yue.Success)
          }),
          @yue.button_t("带按钮", on_click=fn() {
            let n = @yue.Notification::new()
            n.set_title("带操作按钮的通知")
            n.set_body("点通知上的按钮试试(查看 / 忽略)")
            n.set_actions([("查看", "view"), ("忽略", "ignore")])
            n.show()
          }),
          @yue.button_t("静默通知", variant=@yue.Soft, on_click=fn() {
            let n = @yue.Notification::new()
            n.set_title("静默通知")
            n.set_body("set_silent(true):不发声不打扰")
            n.set_silent(true)
            @yue.NotificationCenter::add(n)
          }),
        ]),
      ],
    ),
    section(
      "剪贴板",
      "Clipboard 读写系统剪贴板文本;set_data 写富文本(Html);X11 下另有主选区(见下方)。",
      [
        @yue.hbox([
          @yue.button_t("写入文本", on_click=fn() {
            @yue.Clipboard::get().set_text("来自 components 的剪贴板内容")
            toast_push("已写入剪贴板", @yue.Success)
          }),
          @yue.button_t("读回显示", variant=@yue.Solid, on_click=fn() {
            let t = @yue.Clipboard::get().get_text()
            toast_push(
              if t == "" { "剪贴板为空" } else { "读到: \{t}" },
              if t == "" { @yue.Warning } else { @yue.Info },
            )
          }),
          @yue.button_t("写 HTML 富文本", on_click=fn() {
            @yue.Clipboard::get().set_data(
              @yue.Html,
              "<b>components 富文本剪贴板</b>",
            )
            toast_push("已写入 Html 富文本", @yue.Success)
          }),
        ]),
      ],
    ),
    section(
      "定时器与延迟任务",
      "set_timeout 单次延时 / set_timer 周期回调(返回 false 自动停)/ post_delayed_task 主线程任务。",
      [
        @yue.hbox([
          @yue.button_t("1.5 秒后提示", on_click=fn() {
            ignore(@yue.set_timeout(1500, fn() { toast_push("延时任务触发", @yue.Success) }))
          }),
          @yue.button_t("周期计数到 3", variant=@yue.Solid, on_click=fn() {
            let n = Ref(0)
            @yue.set_timer(700, fn() {
              n.val = n.val + 1
              toast_push("第 \{n.val} 次周期回调", @yue.Info)
              n.val < 3
            })
          }),
        ]),
      ],
    ),
    section(
      "托盘状态",
      "左下角托盘图标:左键点击计数联动(见顶栏通知);Linux SNI 后端支持主题图标名(set_icon_name 跟随系统主题),其他平台为空操作。",
      [
        @yue.bind_label(tray_clicks, fn(n) { "托盘图标已被点击 \{n} 次" }),
        @yue.hbox(
          [
            @yue.button_t("切主题图标(Linux)", on_click=fn() {
              match tray_ref.val {
                Some(t) => {
                  t.set_icon_name("utilities-terminal")
                  toast_push("托盘图标已切为系统主题图标", @yue.Success)
                }
                None => toast_push("托盘不可用", @yue.Warning)
              }
            }),
            @yue.button_t("切回图片图标", on_click=fn() {
              match tray_ref.val {
                Some(t) => {
                  t.set_icon("examples/showcase/icon.png")
                  toast_push("已切回图片图标", @yue.Info)
                }
                None => ()
              }
            }),
          ],
          style=[("marginTop", 8.0)],
        ),
      ],
    ),
    section(
      "无边框透明窗口",
      "Window::new_with_options(frame=false, transparent=true) + always_on_top;整窗 set_mouse_down_can_move_window 可拖动(桌面宠物/悬浮件的形态基础)。窗口无编程关闭 API(上游未暴露),随应用退出。",
      [
        @yue.button_t("打开悬浮心形窗口", variant=@yue.Solid, on_click=fn() {
          open_floating_heart()
        }),
      ],
    ),
    section(
      "关闭拦截",
      "勾选后点窗口关闭被 set_should_close 拦下(演示期间请从菜单「文件→退出」或解除勾选退出)。",
      [
        @yue.checkbox_t("开启关闭拦截", checked=false, on_change=fn(v) {
          close_veto.val = v
          if !v {
            veto_info.set("(未开启拦截)")
          }
        }),
        @yue.bind_label(veto_info, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
    ),
  ]
  // 主选区是 X11 概念:Windows/macOS 上 from_type(Selection) 降级为公共
  // 剪贴板,整段只在 Linux 创建
  if is_linux() {
    p_sys_secs.push(
      section(
        "主选区 Selection(仅 Linux)",
        "X11 主选区:选中即写入、中键粘贴的那份;其他平台 from_type(Selection) 降级为公共剪贴板,故整段只在 Linux 出现。",
        [
          @yue.hbox([
            @yue.button_t("写入主选区", on_click=fn() {
              @yue.Clipboard::from_type(@yue.Selection).set_data(
                @yue.Text,
                "主选区内容",
              )
            }),
            @yue.button_t("读回主选区", on_click=fn() {
              match
                @yue.Clipboard::from_type(@yue.Selection).get_data(@yue.Text) {
                Some(@yue.Text(t)) => sel_out.set("主选区读回:\{t}")
                _ => sel_out.set("主选区读回失败")
              }
            }),
          ]),
          @yue.bind_label(sel_out, fn(s) { s }, style=[("marginTop", 8.0)]),
        ],
      ),
    )
  }
  let p_sys = scroll_page(p_sys_secs)

  // ---------- 事件与布局(事件信号 × yoga 布局模型) ----------
  let p_event = scroll_page([
    section(
      "鼠标事件",
      "五个鼠标事件 + 连击计数(ClickTracker,400ms/5px GTK 惯例);事件对象带视图坐标/屏幕坐标/按键/修饰键。",
      [
        @yue.vbox(
          [@yue.label_t("鼠标操作区", role=@yue.Body)],
          style=[("height", 88.0), ("marginBottom", 8.0)],
          handle=fn(c) {
            evt_area.val = Some(c)
            c.on_mouse_enter(fn(e) { evt_mouse.set("enter (\{e.view_x}, \{e.view_y})") })
            c.on_mouse_leave(fn(_e) { evt_mouse.set("leave") })
            c.on_mouse_move(fn(e) {
              evt_mouse.set("move (\{e.view_x}, \{e.view_y}) btn=\{e.button}")
            })
            c.on_mouse_down(fn(e) {
              let clicks = evt_clicks.feed(e)
              evt_mouse.set("down btn=\{e.button} mods=\{e.modifiers}")
              if clicks >= 2 {
                evt_dbl.set("双击!连击 \{clicks} 次 btn=\{e.button}")
              }
              false
            })
            c.on_mouse_up(fn(e) {
              evt_mouse.set("up btn=\{e.button}")
              false
            })
          },
        ),
        @yue.bind_label(evt_mouse, fn(s) { s }),
        @yue.bind_label(evt_dbl, fn(s) { s }),
      ],
    ),
    section(
      "鼠标捕获",
      "set_capture 后移动/抬升都送给该控件;捕获可被其他控件夺走(on_capture_lost)。",
      [
        @yue.hbox([
          @yue.button_t("切换捕获", on_click=fn() {
            match evt_area.val {
              Some(c) => {
                if c.has_capture() {
                  c.release_capture()
                } else {
                  c.set_capture()
                }
                evt_cap.set(if c.has_capture() { "已捕获" } else { "未捕获" })
              }
              None => ()
            }
          }),
          @yue.bind_label(evt_cap, fn(s) { s }, style=[("marginLeft", 10.0)]),
        ]),
      ],
    ),
    section(
      "全局鼠标轮询",
      "mouse_location + 修饰键静态查询(shift/control/alt_pressed),200ms 定时器轮询,无需事件回调。",
      [@yue.bind_label(evt_gmouse, fn(s) { s })],
    ),
    section(
      "光标 Cursor",
      "View::set_cursor 切换悬停光标——把鼠标移到下方色块上再点按钮。",
      [
        @yue.vbox(
          [@yue.label_t("光标预览区", role=@yue.Body)],
          style=[("height", 48.0), ("marginBottom", 8.0)],
          handle=fn(c) {
            cursor_area.val = Some(c)
            @yue.theme_bind_bg(c, fn() { @yue.theme_current().primary })
          },
        ),
        @yue.hbox([
          @yue.button_t("手型", on_click=fn() { apply_cursor(@yue.Hand, "Hand") }),
          @yue.button_t("文本", on_click=fn() { apply_cursor(@yue.Text, "Text") }),
          @yue.button_t("十字", on_click=fn() { apply_cursor(@yue.Crosshair, "Crosshair") }),
          @yue.button_t("禁止", on_click=fn() { apply_cursor(@yue.NotAllowed, "NotAllowed") }),
          @yue.button_t("默认", on_click=fn() { apply_cursor(@yue.Default, "Default") }),
        ]),
        @yue.bind_label(cursor_now, fn(s) { "当前光标:\{s}" }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "嵌套布局",
      "hbox/vbox 嵌套、固定宽 / 百分比 / flex 权重三种宽度模型(yoga 样式,全集见 docs/zh/layout.md)。",
      [
        @yue.hbox(
          [
            @yue.label_t(
              "固定 80",
              role=@yue.Body,
              style=[("width", 80.0), ("height", 40.0), ("marginRight", 8.0)],
              style_str=[("backgroundcolor", "#3A5F8A")],
            ),
            @yue.label_t(
              "50%",
              role=@yue.Body,
              style=[("height", 40.0), ("marginRight", 8.0)],
              style_str=[("width", "50%"), ("backgroundcolor", "#8A3A5F")],
            ),
            @yue.label_t(
              "flex 1",
              role=@yue.Body,
              style=[("height", 40.0)],
              style_str=[("backgroundcolor", "#5F8A3A")],
            ),
          ],
          style=[("marginBottom", 8.0)],
        ),
      ],
    ),
  ])
  let p_win = scroll_page([
    section(
      "窗口 API",
      "运行期操作窗口:改标题 / 最大化 / 全屏 / 置顶 / 还原尺寸。",
      [
        @yue.hbox([
          @yue.button_t("改标题", on_click=fn() {
            match win_ref.val {
              Some(w) => {
                w.set_title("components · 标题已改")
                toast_push("窗口标题已更新", @yue.Success)
              }
              None => ()
            }
          }),
          @yue.button_t("最大化/还原", on_click=fn() {
            match win_ref.val {
              Some(w) => {
                if w.is_maximized() {
                  w.unmaximize()
                  toast_push("已还原", @yue.Info)
                } else {
                  w.maximize()
                  toast_push("已最大化", @yue.Info)
                }
              }
              None => ()
            }
          }),
          @yue.button_t("全屏切换", on_click=fn() {
            match win_ref.val {
              Some(w) => {
                w.set_fullscreen(!w.is_fullscreen())
                toast_push("全屏状态已切换", @yue.Info)
              }
              None => ()
            }
          }),
          @yue.button_t("置顶切换", variant=@yue.Solid, on_click=fn() {
            match win_ref.val {
              Some(w) => {
                ontop.val = !ontop.val
                w.set_always_on_top(ontop.val)
                toast_push(
                  if ontop.val { "已置顶" } else { "已取消置顶" },
                  @yue.Info,
                )
              }
              None => ()
            }
          }),
          @yue.button_t("还原尺寸", on_click=fn() {
            match win_ref.val {
              Some(w) => {
                w.set_content_size(880.0, 720.0)
                toast_push("已还原 880×720", @yue.Info)
              }
              None => ()
            }
          }),
        ]),
      ],
    ),
    section(
      "全局快捷键",
      "register_global_shortcut 注册应用外生效的系统快捷键(Ctrl+Alt+C),触发弹 toast;unregister_all_global_shortcuts 注销全部。",
      [
        @yue.hbox([
          @yue.button_t("注册 Ctrl+Alt+C", on_click=fn() {
            ignore(
              @yue.register_global_shortcut("Ctrl+Alt+C", fn() {
                toast_push("全局快捷键触发!", @yue.Success)
              }),
            )
            toast_push("已注册,切到别的窗口按 Ctrl+Alt+C 试试", @yue.Info)
          }),
          @yue.button_t("注销全部", on_click=fn() {
            @yue.unregister_all_global_shortcuts()
            toast_push("全局快捷键已清空", @yue.Warning)
          }),
        ]),
      ],
    ),
    section(
      "拖放接收",
      "register_dragged_types 注册接收文件/文本,从文件管理器拖入下方色块。",
      [
        @yue.vbox(
          [
            @yue.label_t("把文件拖进来", role=@yue.Body, handle=fn(_l) {  }),
          ],
          style=[("height", 70.0), ("width", 420.0), ("padding", 10.0)],
          handle=fn(c) {
            @yue.theme_bind_bg(c, fn() { @yue.theme_current().primary_light })
            c.register_dragged_types([@yue.FilePaths, @yue.Text, @yue.Image])
            c.handle_drag_enter(fn(_info, _x, _y) { @yue.DRAG_OPERATION_COPY })
            // drag-motion 每次移动都按 update 返回值决定接收与否,
            // 不注册则一律拒绝(光标禁止,drop 永不发生)
            c.handle_drag_update(fn(_info, _x, _y) { @yue.DRAG_OPERATION_COPY })
            c.handle_drop(fn(info, _x, _y) {
              match info.get_data(@yue.Image) {
                Some(@yue.Img(_)) => toast_push("拖入图片", @yue.Success)
                _ =>
                  match info.get_data(@yue.FilePaths) {
                    Some(@yue.Paths(paths)) => {
                      let sb = StringBuilder()
                      for i, p in paths {
                        if i > 0 {
                          sb.write_string("、")
                        }
                        sb.write_string(p)
                      }
                      toast_push("拖入 \{paths.length()} 个文件", @yue.Success)
                    }
                    _ => toast_push("拖入文本", @yue.Info)
                  }
              }
              true
            })
          },
        ),
      ],
    ),
    section(
      "原生右键菜单",
      "Menu::new + popup_at 原生菜单(区别于基础页主题化的 context_menu_for)。",
      [
        @yue.context_menu_for(
          @yue.tag("右键我(原生菜单)", "#2D68C4"),
          [
            ("原生菜单项 A", fn() { toast_push("原生菜单 A", @yue.Info) }),
            ("-", fn() {  }),
            ("原生菜单项 B", fn() { toast_push("原生菜单 B", @yue.Info) }),
          ],
        ),
      ],
    ),
    section(
      "拖出发起",
      "do_drag_file_paths 发起系统拖拽:按住下方色块拖到文件管理器即拖出 icon.png。",
      [
        @yue.vbox(
          [@yue.label_t("按住我拖出去", role=@yue.Body)],
          style=[("height", 60.0), ("width", 200.0), ("padding", 10.0)],
          handle=fn(c) {
            @yue.theme_bind_bg(c, fn() { @yue.theme_current().primary_light })
            let img : @yue.Image? = match @yue.read_binary_file("examples/showcase/icon.png") {
              Some(bytes) => {
                let i = @yue.Image::new_from_png(bytes)
                if i.is_empty() { None } else { Some(i) }
              }
              None => None
            }
            c.on_mouse_down(fn(_e) {
              ignore(c.do_drag_file_paths(["examples/showcase/icon.png"], img))
              true
            })
          },
        ),
      ],
    ),
    section(
      "内嵌网页",
      "Browser(WebView):load_html 本地页 / load_url 加载站点 / demo:// 自定义协议(Windows 静默无效)/ 执行 JS 异步取回结果 / 导航与加载回调 / JS↔原生 raw binding。",
      [
        @yue.hbox([
          @yue.button_t("加载 demo:// 协议", on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.load_url("demo://hello")
                nav_state.set("加载 demo://hello")
              }
              None => ()
            }
          }),
          @yue.button_t("加载本地 HTML", on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.load_html(
                  "<html><body style='font-family:sans-serif'><h3>load_html 本地片段</h3><button onclick=\"demoBinding('来自网页的调用')\">JS 调原生绑定</button><p id=r></p><script>function demoBinding(s){document.getElementById('r').textContent='已调用: '+s}</script></body></html>",
                )
                nav_state.set("load_html 完成")
              }
              None => ()
            }
          }),
          @yue.button_t("JS 取结果", variant=@yue.Solid, on_click=fn() {
            match web_ref.val {
              Some(b) =>
                b.execute_javascript_with_result(
                  "1 + 41",
                  fn(ok, json) {
                    nav_state.set(
                      if ok { "JS 结果:\{json}(get_title=\{b.get_title()})" } else { "JS 执行失败" },
                    )
                  },
                )
              None => ()
            }
          }),
        ]),
        @yue.hbox(
          [
            @yue.button_t("← 后退", on_click=fn() {
              match web_ref.val {
                Some(b) => b.go_back()
                None => ()
              }
            }),
            @yue.button_t("前进 →", on_click=fn() {
              match web_ref.val {
                Some(b) => b.go_forward()
                None => ()
              }
            }),
            @yue.button_t("刷新", on_click=fn() {
              match web_ref.val {
                Some(b) => b.reload()
                None => ()
              }
            }),
            @yue.button_t("停止", on_click=fn() {
              match web_ref.val {
                Some(b) => b.stop()
                None => ()
              }
            }),
            @yue.button_t(
              "导航能力",
              variant=@yue.Soft,
              on_click=fn() {
                match web_ref.val {
                  Some(b) =>
                    nav_state.set(
                      "可后退=\{b.can_go_back()} 可前进=\{b.can_go_forward()} 加载中=\{b.is_loading()} url=\{b.get_url()}",
                    )
                  None => ()
                }
              },
            ),
          ],
          style=[("marginTop", 8.0)],
        ),
        @yue.browser(handle=fn(x) {
          web_ref.val = Some(x)
          x.load_html(
            "<html><body style='font-family:sans-serif;background:#fff;color:#222;display:flex;align-items:center;justify-content:center;height:100%'><h3>WebView 内嵌页 ✓</h3></body></html>",
          )
          // 导航/加载四回调:提交导航、完成导航、加载态、命令可用性
          x.on_commit_navigation(fn(url) {
            nav_events.set("on_commit_navigation:\{url}")
          })
          x.on_finish_navigation(fn(_url) { nav_events.set("on_finish_navigation(导航完成)") })
          x.on_change_loading(fn() { nav_events.set("on_change_loading(加载态变化)") })
          x.on_update_command(fn() { nav_events.set("on_update_command(导航命令刷新)") })
          // raw binding:网页 JS 调 demoBinding(...) 时原生侧收到 JSON 参数
          x.add_raw_binding("demoBinding", fn(json) {
            bind_state.set("收到网页调用:\{json}")
          })
        }, style=[("width", 480.0), ("height", 150.0), ("marginTop", 8.0)]),
        @yue.hbox(
          [
            @yue.button_t("移除绑定", variant=@yue.Danger, on_click=fn() {
              match web_ref.val {
                Some(b) => {
                  b.remove_binding("demoBinding")
                  bind_state.set(
                    if b.has_bindings() { "仍有其他绑定" } else { "绑定已全部移除" },
                  )
                }
                None => ()
              }
            }),
            @yue.bind_label(bind_state, fn(s) { s }, style=[("marginLeft", 10.0)]),
          ],
          style=[("marginTop", 8.0)],
        ),
        @yue.bind_label(nav_state, fn(s) { s }, style=[("marginTop", 8.0)]),
        @yue.bind_label(nav_events, fn(s) { s }),
      ],
    ),
  ])

  // ---------- 原生控件(libyue 原生件 × 主题包装) ----------
  let p_native = scroll_page([
    section(
      "原生标签 / 按钮",
      "libyue 原生 Button/Label(系统主题外观),点击计数由 Store 驱动回显。",
      [
        @yue.hbox([
          @yue.button("原生按钮", on_click=fn() { nat_clicks.update(fn(n) { n + 1 }) }),
          @yue.bind_label(nat_clicks, fn(n) { "已点 \{n} 次" }, style=[("marginLeft", 10.0)]),
        ]),
      ],
    ),
    section(
      "单行输入 Entry",
      "原生输入框:on_input 实时回显、on_enter 回车、password 密码框。",
      [
        @yue.entry(text="在这里输入…", on_input=fn(t) { nat_echo.set(t) }, on_enter=fn(t) {
          nat_echo.set("\{t}(回车)")
        }),
        @yue.bind_label(nat_echo, fn(s) { "回显:\{s}" }, style=[("marginTop", 8.0)]),
        @yue.entry(text="口令", password=true, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "滑块联动进度条",
      "原生 Slider + ProgressBar(handle 命令式 set_value);按钮切换不确定态。",
      [
        @yue.slider(range=Some((0.0, 100.0)), step=Some(1.0), on_change=fn(v) {
          nat_slider.set(v)
          match nat_bar.val {
            Some(p) => p.set_value(v / 100.0)
            None => ()
          }
        }),
        @yue.progress(handle=fn(p) { nat_bar.val = Some(p) }, style=[("marginTop", 8.0)]),
        @yue.bind_label(nat_slider, fn(v) { "滑块值:\{v.round()}" }, style=[("marginTop", 8.0)]),
        @yue.button_t("切换不确定态", on_click=fn() {
          nat_indet.val = !nat_indet.val
          match nat_bar.val {
            Some(p) => p.set_indeterminate(nat_indet.val)
            None => ()
          }
        }),
      ],
    ),
    section(
      "复选框 / 单选组",
      "原生 checkbox 独立勾选;同组 radio 自动互斥。",
      [
        @yue.checkbox("启用扩展", on_change=fn(v) { if v { nat_pick.set("扩展已启用") } }),
        @yue.hbox(
          [
            @yue.radio("甲", on_change=fn(v) { if v { nat_pick.set("甲") } }),
            @yue.radio("乙", checked=true, on_change=fn(v) { if v { nat_pick.set("乙") } }),
            @yue.radio("丙", on_change=fn(v) { if v { nat_pick.set("丙") } }),
          ],
          style=[("marginTop", 8.0)],
        ),
        @yue.bind_label(nat_pick, fn(s) { "当前:\{s}" }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "下拉组合框 / 只读选择器",
      "ComboBox 可编辑(on_select/on_input);Picker 只读列表选择。",
      [
        @yue.combo(
          items=["MoonBit", "libyue", "GTK"],
          selected=0,
          on_select=fn() {
            match nat_cb.val {
              Some(c) => nat_combo.set(c.get_selected_item())
              None => ()
            }
          },
          handle=fn(c) { nat_cb.val = Some(c) },
        ),
        @yue.picker(
          items=["红", "绿", "蓝"],
          on_change=fn() {
            match nat_pk.val {
              Some(p) => nat_picker.set(p.get_selected_item())
              None => ()
            }
          },
          handle=fn(p) { nat_pk.val = Some(p) },
          style=[("marginTop", 8.0)],
        ),
        @yue.bind_label(nat_combo, fn(s) { "组合框:\{s}" }, style=[("marginTop", 8.0)]),
        @yue.bind_label(nat_picker, fn(s) { "选择器:\{s}" }),
      ],
    ),
    section(
      "日期时间选择",
      "原生 DatePicker(HourMinute 元素 + 步进器),epoch 秒读写。",
      [
        @yue.node_of(nat_date, style=[("marginBottom", 8.0)]),
        @yue.bind_label(nat_date_val, fn(t) { "当前 epoch 秒:\{t}" }),
      ],
    ),
    section(
      "GIF 播放",
      "GifPlayer 无解码器依赖播放 GIF(dot.gif);yoga 叶子需显式宽高。",
      [
        @yue.gif(
          image=Some(@yue.Image::new_from_file("examples/showcase/dot.gif")),
          style=[("width", 120.0), ("height", 120.0)],
        ),
      ],
    ),
    section(
      "多行文本编辑",
      "TextEdit 编辑 API:撤销重做/剪切复制粘贴/选区与插入。",
      [
        @yue.text_edit(
          text="多行文本…\n试试撤销 / 重做 / 全选 / 插入。",
          handle=fn(t) { nat_edit.val = Some(t) },
          style=[("height", 96.0)],
        ),
        @yue.hbox(
          [
            @yue.button_t("撤销", on_click=fn() { match nat_edit.val { Some(t) => t.undo() 
 None => () } }),
            @yue.button_t("重做", on_click=fn() { match nat_edit.val { Some(t) => t.redo() 
 None => () } }),
            @yue.button_t("全选", on_click=fn() { match nat_edit.val { Some(t) => t.select_all() 
 None => () } }),
            @yue.button_t("粘贴", on_click=fn() { match nat_edit.val { Some(t) => t.paste() 
 None => () } }),
            @yue.button_t("插入一行", on_click=fn() { match nat_edit.val { Some(t) => t.insert_text("\n(插入)") 
 None => () } }),
          ],
          style=[("marginTop", 8.0)],
        ),
      ],
    ),
    section(
      "气泡 Popover",
      "原生 Popover 气泡(Linux 原生气泡;Windows 右下 8 秒自动关)。",
      [
        @yue.button("弹出气泡", handle=fn(b) { nat_pop.val = Some(b) }, on_click=fn() {
          match nat_pop.val {
            Some(b) => {
              let pop = @yue.Popover::new()
              let tip = @yue.Label::new("这是一个 Popover 气泡")
              tip.set_style("padding", 10.0)
              pop.set_content(tip)
              pop.set_content_size(180.0, 44.0)
              pop.show_relative_to(b)
            }
            None => ()
          }
        }),
      ],
    ),
    section(
      "分组 Group",
      "原生 Group:标题 + 内容;Windows 的 Group 不按内容自增长(GTK 按自然尺寸撑开),跨平台一致需显式高度。",
      [
        @yue.group(
          "分组:内嵌标签",
          @yue.label("分组里的内容", style=[("padding", 8.0)]),
          style=[("height", 96.0)],
        ),
      ],
    ),
    section(
      "原生页签 Tab",
      "原版 Tab 控件:声明式 tab 节点逐个加页,切换时 on_change 回调计数(主题化页签见「导航组件」页 Tabs)。",
      [
        @yue.tab(
          [
            ("文本", @yue.label("第一个页签的内容", style=[("padding", 8.0)])),
            ("输入", @yue.entry(text="页签里的输入框", style=[("padding", 8.0)])),
            (
              "按钮",
              @yue.hbox([@yue.button("页签内按钮")], style=[("padding", 8.0)]),
            ),
          ],
          on_change=fn() { nat_tab_sw.update(fn(n) { n + 1 }) },
          style=[("height", 120.0), ("marginBottom", 8.0)],
        ),
        @yue.bind_label(nat_tab_sw, fn(n) { "切换次数:\{n}" }),
      ],
    ),
    section(
      "滚动区 Scroll",
      "内容尺寸 + 滚动条策略(Automatic/Always/Never)切换;overlay 滚动条仅 GTK 生效,Windows 无此概念。",
      [
        @yue.scroll(
          @yue.vbox([
            @yue.label_t("滚动区第一行", role=@yue.Body, style=[("padding", 8.0)]),
            @yue.label_t("滚动区第二行", role=@yue.Body, style=[("padding", 8.0)]),
            @yue.label_t("滚动区第三行", role=@yue.Body, style=[("padding", 8.0)]),
            @yue.label_t("滚动区第四行", role=@yue.Body, style=[("padding", 8.0)]),
          ]),
          handle=fn(s) { nat_scroll.val = Some(s) },
          style=[("height", 90.0), ("marginBottom", 8.0)],
        ),
        @yue.button("切换滚动条策略", on_click=fn() {
          nat_policy.val = !nat_policy.val
          match nat_scroll.val {
            Some(s) =>
              if nat_policy.val {
                s.set_scrollbar_policy(@yue.Always, @yue.Always)
              } else {
                s.set_scrollbar_policy(@yue.Automatic, @yue.Automatic)
              }
            None => ()
          }
        }),
      ],
    ),
    section(
      "原生表格 Table",
      "TableModel 是 trait,数据与视图分离;列类型 Text/Checkbox/Edit(勾选与编辑经 set_value 回写),行激活/选择变化有回调。Linux(GTK) 下 Table 放进 Notebook 页签测量尺寸会触发崩溃,演示放独立子窗口。",
      [
        @yue.button_t("打开表格演示窗口", variant=@yue.Solid, on_click=fn() {
          open_table_window()
        }),
      ],
    ),
  ])

  // ---------- 画布与富文本(Painter / Image / AttributedText) ----------
  let p_canvas = scroll_page([
    section(
      "自绘画布",
      "container on_draw 自绘:圆环 / 网格 / 文本 / PNG 图片叠加(混合模式);schedule_paint 触发重绘。",
      [
        @yue.container(
          on_draw=fn(p) { draw_canvas_scene(p) },
          handle=fn(c) {
            canvas_ref.val = Some(c)
            c.on_size_changed(fn() { c.schedule_paint() })
          },
          style=[("height", 300.0), ("marginBottom", 8.0), ("width", 640.0)],
        ),
        @yue.hbox([
          @yue.button_t("旋转色相", on_click=fn() {
            canvas_hue.val = (canvas_hue.val + 1) % 3
            canvas_repaint()
          }),
          @yue.button_t("切换混合模式", on_click=fn() {
            canvas_blend.val = (canvas_blend.val + 1) % canvas_blends.length()
            canvas_info.set(canvas_blend_names[canvas_blend.val])
            canvas_repaint()
          }),
          @yue.button_t("导出缩放图", variant=@yue.Solid, on_click=fn() {
            match canvas_img.val {
              Some(img) => {
                let half = img.resize(img.get_width() / 2.0, img.get_height() / 2.0)
                let ok = half.write_to_file("png", "/tmp/components_half.png")
                canvas_info.set(
                  if ok { "已导出 /tmp/components_half.png" } else { "导出失败" },
                )
              }
              None => canvas_info.set("无图片可导出")
            }
          }),
        ]),
        @yue.bind_label(canvas_info, fn(s) { "混合模式:\{s}" }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "富文本 AttributedText",
      "范围属性:0-6 号字符 Black 24 号字,8-11 号字符红色(set_font_for/set_color_for);换行/省略号/改写。",
      [
        @yue.container(
          on_draw=fn(painter) {
            match canvas_rt.val {
              Some(c) => {
                let size = c.get_bounds()
                painter.fill_rect(0.0, 0.0, size.width, size.height)
                painter.draw_attributed_text(rt, 10.0, 20.0, size.width - 20.0, 100.0)
              }
              None => ()
            }
          },
          handle=fn(c) {
            canvas_rt.val = Some(c)
            c.on_size_changed(fn() { c.schedule_paint() })
          },
          style=[("height", 120.0), ("marginBottom", 8.0), ("width", 640.0)],
          style_str=[("backgroundcolor", "#F4F4F0")],
        ),
        @yue.hbox([
          @yue.button_t("换行开关", on_click=fn() {
            rt_wrap.val = !rt_wrap.val
            rt.set_format({
              align: @yue.Start,
              valign: @yue.Start,
              wrap: rt_wrap.val,
              ellipsis: rt_ellipsis.val,
            })
            match canvas_rt.val {
              Some(c) => c.schedule_paint()
              None => ()
            }
          }),
          @yue.button_t("省略号开关", on_click=fn() {
            rt_ellipsis.val = !rt_ellipsis.val
            rt.set_format({
              align: @yue.Start,
              valign: @yue.Start,
              wrap: true,
              ellipsis: rt_ellipsis.val,
            })
            match canvas_rt.val {
              Some(c) => c.schedule_paint()
              None => ()
            }
          }),
          @yue.button_t("改写文本", variant=@yue.Solid, on_click=fn() {
            rt.set_text("文本已替换 ✓(属性保留)")
            match canvas_rt.val {
              Some(c) => c.schedule_paint()
              None => ()
            }
          }),
        ]),
        @yue.label_t(
          "系统语义色 Text=\{@yue.system_color(@yue.Text)} WindowBackground=\{@yue.system_color(@yue.WindowBackground)} Border=\{@yue.system_color(@yue.Border)}",
          role=@yue.Secondary,
          style=[("marginTop", 8.0)],
        ),
      ],
    ),
  ])

  // ---------- 环境与平台(运行环境快照) ----------
  let p_env = scroll_page([
    section(
      "运行环境",
      "环境查询 API(本次启动快照);键盘钩子显示窗口级 on_key_down。",
      [
        @yue.label_t("platform = \{@yue.platform()}", role=@yue.Body),
        @yue.label_t("locale = \{@yue.locale()}", role=@yue.Body),
        @yue.label_t("深色模式 is_dark = \{@yue.Appearance::is_dark()}", role=@yue.Body),
        @yue.label_t("屏幕缩放 scale_factor = \{@yue.Screen::scale_factor()}", role=@yue.Body),
        @yue.label_t(
          "主屏尺寸 = \{@yue.Screen::primary_size().0} × \{@yue.Screen::primary_size().1}",
          role=@yue.Body,
        ),
        @yue.label_t("应用名 = \{@yue.App::get_name()}", role=@yue.Body),
        @yue.label_t("托盘可用 = \{@yue.Tray::is_supported()}", role=@yue.Body),
        @yue.bind_label(key_info, fn(s) { "最后按键:\{s}" }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "平台差异速览",
      "本仓已文档化的主要平台差异;完整清单与实测记录见 docs/zh/adaptation.md。",
      [
        @yue.label_t("· 托盘:Linux SNI 直连 / Windows Shell_NotifyIconW / macOS 原生", role=@yue.Secondary),
        @yue.label_t("· 通知:Linux 必须走 Show()(DBus Notify)/ Windows WinRT toast", role=@yue.Secondary),
        @yue.label_t("· 剪贴板主选区 Selection:仅 X11 存在", role=@yue.Secondary),
        @yue.label_t("· 浏览器自定义协议:Linux 可用,Windows WebView2 静默无效", role=@yue.Secondary),
        @yue.label_t("· 富文本范围属性:Windows 降级为全文应用", role=@yue.Secondary),
      ],
    ),
  ])

  let window = @yue.mount_window(
    [
      @yue.hbox(style=[("flex", 1.0)], style_str=[("alignItems", "stretch")], [
        @yue.side_menu_sections(
          [
            ("基础", ["基础组件", "表单组件", "事件与布局"]),
            ("进阶", ["导航组件", "数据展示", "反馈组件"]),
            ("原生", ["原生控件", "画布与富文本"]),
            ("系统", ["系统集成", "窗口与网页", "环境与平台"]),
          ],
          selected,
        ),
        @yue.vbox(
          [
            @yue.hbox(
              [
                @yue.segmented(
                  [
                    "基础组件",
                    "表单组件",
                    "事件与布局",
                    "导航组件",
                    "数据展示",
                    "反馈组件",
                    "原生控件",
                    "画布与富文本",
                    "系统集成",
                    "窗口与网页",
                    "环境与平台",
                  ],
                  selected,
                ),
                @yue.button_t(
                  "切换深浅",
                  variant=@yue.Soft,
                  on_click=fn() { dark_mode.update(fn(v) { !v }) },
                ),
                @yue.label("      "),
                @yue.tag("MoonShell", "#2D68C4"),
                @yue.tag("v0.2", "#2E9E5B"),
              ],
              style=[("padding", 10.0)],
              style_str=[("alignItems", "center")],
              handle=fn(c) {
                fn apply() -> Unit {
                  c.set_background_color(@yue.theme_current().bg_panel)
                }

                apply()
                @yue.on_theme_change(apply)
              },
            ),
            page("基础组件", selected, p_basic),
            page("表单组件", selected, p_form),
            page("事件与布局", selected, p_event),
            page("导航组件", selected, p_nav),
            page("数据展示", selected, p_data),
            page("反馈组件", selected, p_feedback),
            page("系统集成", selected, p_sys),
            page("窗口与网页", selected, p_win),
            page("原生控件", selected, p_native),
            page("画布与富文本", selected, p_canvas),
            page("环境与平台", selected, p_env),
          ],
          style=[("flex", 1.0)],
          handle=fn(c) {
            fn apply() -> Unit {
              c.set_background_color(@yue.theme_current().bg_page)
            }

            apply()
            @yue.on_theme_change(apply)
          },
        ),
        // 轻提示层挂窗口根:absolute 顶部横条,不占布局
        toast_node,
        // 对话框挂窗口根:absolute 遮罩相对挂载容器,盖全窗
        @yue.dialog_t(
          dlg_basic,
          "删除确认",
          [
            @yue.alert_closeable("此操作不可撤销,请确认。", @yue.Warning),
            @yue.label_t("确定要删除「示例项目」吗?", role=@yue.Body),
          ],
          confirm_text="删除",
          cancel_text="取消",
          on_confirm=fn() { dlg_name.set("(确认删除)") },
          close_on_mask=true,
        ),
        @yue.dialog_t(
          dlg_form,
          "新建连接",
          [
            @yue.label_t("名称", role=@yue.Body),
            @yue.input_t(text="例如:开发库", width=320.0, on_input=fn(t) { dlg_name.set(t) }),
            @yue.label_t("地址", role=@yue.Body),
            @yue.input_t(text="host:port", width=320.0),
          ],
          width=380.0,
        ),
      ]),
    ],
    title="组件库演示板",
    size=Some((880.0, 720.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
    handle=fn(w) {
      win_ref.val = Some(w)
      // 菜单栏(原生 MenuBar):关于 + 退出 + 编辑角色项
      let bar = @yue.MenuBar::new()
      let file = bar.add_menu("文件")
      let about = file.add_label_item("关于本演示")
      about.set_accelerator("CmdOrCtrl+I")
      about.on_click(fn() {
        match win_ref.val {
          Some(w) => {
            let box = @yue.MessageBox::new(@yue.Information)
            box.set_title("关于")
            box.set_text("moonbit-libyue 组件库演示板")
            box.set_informative_text(
              "平台 \{@yue.platform()} ｜ 桌面 \{@yue.desktop_environment()} ｜ 区域 \{@yue.locale()}",
            )
            box.show_for_window(w)
          }
          None => ()
        }
      })
      let _ = file.add_separator()
      let quit = file.add_label_item("退出")
      quit.set_accelerator("CmdOrCtrl+Q")
      quit.on_click(fn() { @yue.quit() })
      let edit = bar.add_menu("编辑")
      let _c = edit.add_role_item(@yue.Copy)
      let _x = edit.add_role_item(@yue.Cut)
      let _p = edit.add_role_item(@yue.Paste)
      let _s = edit.add_role_item(@yue.SelectAll)
      let demo = bar.add_menu("演示")
      let table_item = demo.add_label_item("表格(独立窗口)")
      table_item.on_click(fn() { open_table_window() })
      let traverse = demo.add_label_item("遍历本菜单结构")
      traverse.on_click(fn() {
        let mut text = "「演示」菜单共 \{demo.item_count()} 项:"
        for i in 0..<demo.item_count() {
          text = text + " [\{i}]\{demo.item_at(i).get_label()}"
        }
        toast_push(text, @yue.Info)
      })
      w.set_menubar(bar)
      // 关闭拦截:系统集成页勾选后,点窗口关闭被 set_should_close 拦下
      w.set_should_close(fn() {
        if close_veto.val {
          veto_info.set("关闭请求被 set_should_close 拦截(回「系统集成」页解除)")
          return false
        }
        true
      })
      // 系统托盘:Linux SNI / 其他平台原生;点击计数联动系统集成页
      if @yue.Tray::is_supported() {
        match @yue.Tray::new("examples/showcase/icon.png") {
          Ok(tray) => {
            tray_ref.val = Some(tray)
            tray.set_title("components")
            tray.set_tooltip("moonbit-libyue 组件库演示板", "左键计数,右键菜单")
            let menu = @yue.Menu::new()
            let show_item = menu.add_label_item("显示主窗口")
            show_item.on_click(fn() { w.activate() })
            let _ = menu.add_separator()
            let quit_item = menu.add_label_item("退出")
            quit_item.on_click(fn() { @yue.quit() })
            tray.set_menu(menu)
            tray.on_click(fn() {
              tray_clicks.update(fn(n) { n + 1 })
              let n = @yue.Notification::new()
              n.set_title("components")
              n.set_body("第 \{tray_clicks.get()} 次点击托盘图标")
              n.show()
            })
          }
          Err(_e) => ()
        }
      }
      // 窗口级键盘钩子(环境页显示;describe 输出如 Ctrl+A)
      w.on_key_down(fn(e) {
        key_info.set(
          "\{e.describe()}(键码 \{e.code},Esc=\{@yue.VKEY_ESCAPE} A=\{@yue.VKEY_A})",
        )
        false
      })
    },
  )
  window.activate()
  @yue.run()
}

///|
fn draw_heart(painter : @yue.Painter) -> Unit {
  painter.begin_path()
  painter.move_to(75.0, 40.0)
  painter.bezier_curve_to(75.0, 37.0, 70.0, 25.0, 50.0, 25.0)
  painter.bezier_curve_to(20.0, 25.0, 20.0, 62.5, 20.0, 62.5)
  painter.bezier_curve_to(20.0, 80.0, 40.0, 102.0, 75.0, 120.0)
  painter.bezier_curve_to(110.0, 102.0, 130.0, 80.0, 130.0, 62.5)
  painter.bezier_curve_to(130.0, 62.5, 130.0, 25.0, 100.0, 25.0)
  painter.bezier_curve_to(85.0, 25.0, 75.0, 37.0, 75.0, 40.0)
  painter.fill()
}

///|
/// 无边框透明置顶的心形小窗,整窗可拖动(悬浮件/桌面宠物的形态基础)。
fn open_floating_heart() -> Unit {
  let win = @yue.Window::new_with_options(frame=false, transparent=true)
  win.set_always_on_top(true)
  win.set_content_size(150.0, 130.0)
  let content = @yue.Container::new()
  content.set_mouse_down_can_move_window(true)
  win.set_content(content)
  content.on_draw(fn(painter) {
    painter.set_fill_color("#3000")
    draw_heart(painter)
    painter.translate(-5.0, -5.0)
    painter.set_fill_color("#D46A6A")
    draw_heart(painter)
  })
  win.center()
  win.activate()
}
