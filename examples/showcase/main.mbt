// 全功能 Showcase：一窗展示 moonbit-libyue 的全部已封装能力。
// 消费方视角：只有 MoonBit 类型与回调，看不到任何平台差异。

///|
/// 全局状态：跨页签共享的可变演示数据。
struct State {
  mut click_count : Int
  mut canvas_hue : Int
  mut tray_clicks : Int
  log_lines : Array[String]
  log_labels : Array[@yue.Label]
  veto_close : Ref[Bool]
}

///|
fn State::log(self : State, line : String) -> Unit {
  println("LOG \{line}")
  self.log_lines.push(line)
  // 只保留最近 6 条
  if self.log_lines.length() > 6 {
    let _ = self.log_lines.remove(0)
  }
  let mut text = ""
  for l in self.log_lines {
    text = text + l + "\n"
  }
  for l in self.log_labels {
    l.set_text(text)
  }
}

///|
/// 在当前页创建一个绑定事件日志的标签（同一控件不能挂两个父容器）。
fn State::new_log_label(self : State) -> @yue.Label {
  let label = @yue.Label::new("（事件日志）")
  self.log_labels.push(label)
  label
}

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let state = State::init()
  let win = @yue.Window::new()
  win.set_title("moonbit-libyue 全功能 Showcase")
  win.set_content_size(960.0, 640.0)
  win.on_close(fn(_w) { @yue.quit() })
  win.set_should_close(fn() {
    if state.veto_close.val {
      state.log("窗口关闭被 should_close 拦截(系统页可解除)")
      return false
    }
    true
  })

  win.set_content(build_tabs(win, state))
  win.set_menubar(build_menubar(win, state))
  setup_tray(state, win)

  win.center()
  win.activate()
  @yue.run()
}

///|
fn State::init() -> State {
  {
    click_count: 0,
    canvas_hue: 0,
    tray_clicks: 0,
    log_lines: [],
    log_labels: [],
    veto_close: Ref(false),
  }
}

///|
/// 菜单条：文件 / 帮助，含角色项与快捷键。
fn build_menubar(win : @yue.Window, state : State) -> @yue.MenuBar {
  let bar = @yue.MenuBar::new()

  let file = bar.add_menu("文件")
  let about = file.add_label_item("关于本演示")
  about.set_accelerator("CmdOrCtrl+I")
  about.on_click(fn() { show_about(win) })
  let _ = file.add_separator()
  let quit = file.add_label_item("退出")
  quit.set_accelerator("CmdOrCtrl+Q")
  quit.on_click(fn() { @yue.quit() })

  let edit = bar.add_menu("编辑")
  let _copy = edit.add_role_item(@yue.Copy)
  let _cut = edit.add_role_item(@yue.Cut)
  let _paste = edit.add_role_item(@yue.Paste)
  let _select_all = edit.add_role_item(@yue.SelectAll)

  let demos = bar.add_menu("演示")
  let table_item = demos.add_label_item("表格（独立窗口）")
  table_item.on_click(fn() { open_table_window(state) })
  let check_item = demos.add_check_item("显示详细日志")
  check_item.set_checked(true)
  check_item.on_click(fn() { state.log("菜单勾选 =\{check_item.is_checked()}") })
  let _r1 = demos.add_radio_item("模式一")
  let r2 = demos.add_radio_item("模式二")
  r2.set_checked(true)
  r2.on_click(fn() { state.log("菜单单选 模式二") })
  let traverse = demos.add_label_item("打印演示菜单结构")
  traverse.on_click(fn() {
    state.log("菜单共 \{demos.item_count()} 项:")
    for i in 0..<demos.item_count() {
      let it = demos.item_at(i)
      state.log("  [\{i}] \{it.get_label()}")
    }
  })

  let help = bar.add_menu("帮助")
  let env_item = help.add_label_item("桌面环境信息")
  env_item.on_click(fn() { show_about(win) })
  let shortcut = help.add_label_item("注册全局快捷键 Ctrl+Alt+S")
  shortcut.on_click(fn() {
    let id = @yue.register_global_shortcut("Ctrl+Alt+S", fn() {
      show_about(win)
    })
    state.log("全局快捷键已注册 id=\{id}")
    ignore(id)
  })
  bar
}

///|
/// Browser 页的无 state 日志(写入 stdout)。
fn state_log_helper(line : String) -> Unit {
  println("showcase: \{line}")
}

///|
fn show_about(win : @yue.Window) -> Unit {
  let box = @yue.MessageBox::new(@yue.Information)
  box.set_title("关于")
  box.set_text("moonbit-libyue Showcase")
  box.set_informative_text(
    "平台: \{@yue.platform()}\n桌面: \{@yue.desktop_environment()}\n区域: \{@yue.locale()}",
  )
  box.show_for_window(win)
}

///|
/// 系统托盘：自实现 SNI 后端（Linux）/ 原生托盘（其他平台）。
fn setup_tray(state : State, main_win : @yue.Window) -> Unit {
  if !@yue.Tray::is_supported() {
    state.log("托盘：当前环境不可用")
    return
  }
  match @yue.Tray::new("examples/showcase/icon.png") {
    Ok(tray) => {
      tray.set_title("showcase")
      tray.set_tooltip("moonbit-libyue", "右键打开菜单")
      // 托盘菜单：显示主窗口 / 退出（Linux 走 DBusMenu，其他平台原生菜单）
      let menu = @yue.Menu::new()
      let show_item = menu.add_label_item("显示主窗口")
      show_item.on_click(fn() {
        state.log("托盘菜单：显示主窗口")
        main_win.activate()
      })
      let _ = menu.add_separator()
      let quit_item = menu.add_label_item("退出")
      quit_item.on_click(fn() { @yue.quit() })
      tray.set_menu(menu)
      tray.on_click(fn() {
        state.tray_clicks += 1
        state.log("托盘点击 第\{state.tray_clicks} 次")
        let n = @yue.Notification::new()
        n.set_title("托盘被点击")
        n.set_body("第 \{state.tray_clicks} 次点击了托盘图标")
        @yue.NotificationCenter::add(n)
        n.show()
      })
      state.log("托盘：已创建（\{@yue.desktop_environment()}）")
    }
    Err(e) => state.log("托盘创建失败：\{e}")
  }
}

///|
/// 主页签：七页覆盖全部功能面。
fn build_tabs(win : @yue.Window, state : State) -> @yue.Tab {
  let tabs = @yue.Tab::new()
  tabs.set_style("padding", 8.0)
  tabs.add_page("基础控件", build_basics(state))
  tabs.add_page("输入与选择", build_inputs(win, state))
  tabs.add_page("画布", build_canvas(state))
  tabs.add_page("网页", build_browser(win))
  tabs.add_page("对话框", build_dialogs(win, state))
  tabs.add_page("系统集成", fn() { build_system(win, state) }())
  tabs.add_page("事件", fn() { build_events(win, state) }())
  tabs.add_page("富文本", build_richtext(state))
  tabs
}

///|
/// 页 1：标签 / 按钮 / 输入回显 / 滑块联动进度条。
fn build_basics(state : State) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)

  let head = @yue.Label::new("基础控件 —— 标签 / 按钮 / 输入框 / 滑块 / 进度条")
  head.set_style_str("color", "#356AA0")
  head.set_style("marginBottom", 10.0)
  page.add_child(head)

  // 按钮：点击计数
  let btn = @yue.Button::new("点我 (0)")
  btn.set_style("marginBottom", 8.0)
  page.add_child(btn)

  // 输入框：回显
  let entry = @yue.Entry::new()
  entry.set_text("在这里输入…")
  entry.set_style("marginBottom", 8.0)
  page.add_child(entry)

  let echo = @yue.Label::new("回显：")
  echo.set_style("marginBottom", 8.0)
  page.add_child(echo)

  // 滑块联动进度条
  let slider = @yue.Slider::new()
  slider.set_range(0.0, 100.0)
  slider.set_step(1.0)
  slider.set_style("marginBottom", 8.0)
  page.add_child(slider)

  let progress = @yue.ProgressBar::new()
  progress.set_style("marginBottom", 8.0)
  page.add_child(progress)

  let slider_label = @yue.Label::new("滑块值：0")
  slider_label.set_style("marginBottom", 8.0)
  page.add_child(slider_label)

  let pulse = @yue.Button::new("切换进度条滚动模式")
  page.add_child(pulse)

  // 复选 / 单选按钮(Button::Type)
  let check = @yue.Button::new_of(@yue.Checkbox, "启用扩展")
  check.set_style("marginBottom", 8.0)
  page.add_child(check)
  let radio_row = @yue.Container::new()
  radio_row.set_style_str("flexDirection", "row")
  radio_row.set_style("marginBottom", 8.0)
  page.add_child(radio_row)
  let radio_a = @yue.Button::new_of(@yue.Radio, "主题甲")
  let radio_b = @yue.Button::new_of(@yue.Radio, "主题乙")
  radio_b.set_checked(true)
  radio_a.set_style("marginRight", 12.0)
  radio_row.add_child(radio_a)
  radio_row.add_child(radio_b)

  // 密码输入框(Entry::Type)
  let password = @yue.Entry::new_of(@yue.Password)
  password.set_text("口令")
  password.set_style("marginBottom", 8.0)
  page.add_child(password)

  let mut indeterminate = false
  btn.on_click(fn() {
    state.click_count += 1
    btn.set_title("点我 (\{state.click_count})")
    state.log("按钮点击 \{state.click_count}")
  })
  entry.on_text_change(fn() { echo.set_text("回显：\{entry.get_text()}") })
  entry.on_activate(fn() { state.log("输入框回车：\{entry.get_text()}") })
  slider.on_value_change(fn() {
    let v = slider.get_value().round()
    progress.set_value(v / 100.0)
    slider_label.set_text("滑块值：\{v}")
  })
  pulse.on_click(fn() {
    indeterminate = !indeterminate
    progress.set_indeterminate(indeterminate)
    state.log("进度条滚动模式：\{indeterminate}")
  })
  check.on_click(fn() { state.log("复选 =\{check.is_checked()}") })
  radio_a.on_click(fn() { state.log("单选 甲") })
  radio_b.on_click(fn() { state.log("单选 乙") })
  password.on_activate(fn() { state.log("密码长度 \{password.get_text().length()}") })
  page
}

///|
/// 页 2：文本编辑 / 选择器 / 日期 / 分组 / 滚动 / 气泡。
fn build_inputs(win : @yue.Window, state : State) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)

  let head = @yue.Label::new("输入与选择 —— 文本编辑 / 下拉 / 日期 / 分组 / 滚动")
  head.set_style_str("color", "#356AA0")
  head.set_style("marginBottom", 10.0)
  page.add_child(head)

  // 可编辑下拉
  let combo = @yue.ComboBox::new()
  combo.add_item("MoonBit")
  combo.add_item("libyue")
  combo.add_item("GTK")
  combo.select_item_at(0)
  combo.set_style("marginBottom", 8.0)
  page.add_child(combo)

  let combo_label = @yue.Label::new("下拉选择：MoonBit")
  combo_label.set_style("marginBottom", 8.0)
  page.add_child(combo_label)

  // 只读选择器
  let picker = @yue.Picker::new()
  picker.add_item("红")
  picker.add_item("绿")
  picker.add_item("蓝")
  picker.set_style("marginBottom", 8.0)
  page.add_child(picker)

  // 日期选择(带选项:仅时分 + 步进器)
  let date = @yue.DatePicker::new_with({
    elements: @yue.HourMinute,
    has_stepper: true,
  })
  date.set_style("marginBottom", 8.0)
  page.add_child(date)

  let date_label = @yue.Label::new("日期变更会记录到事件日志")
  date_label.set_style("marginBottom", 8.0)
  page.add_child(date_label)

  // 分组内嵌滚动文本编辑
  let group = @yue.Group::new("分组：滚动区里的文本编辑")
  group.set_style("marginBottom", 8.0)
  let scroll = @yue.Scroll::new()
  scroll.set_content_size(640.0, 96.0)
  let edit = @yue.TextEdit::new()
  edit.set_text("在此滚动/编辑多行文本…\nTextEdit 支持撤销重做选区粘贴。\n第二行\n第三行\n第四行")
  scroll.set_content(edit)
  group.set_content(scroll)
  page.add_child(group)

  // 滚动条策略切换(Scroll::Policy)
  let policy_btn = @yue.Button::new("滚动条策略: 自动 → 常显")
  policy_btn.set_style("marginBottom", 8.0)
  page.add_child(policy_btn)
  let mut policy_on = false

  // 气泡
  let pop_btn = @yue.Button::new("在按钮旁弹出气泡")
  page.add_child(pop_btn)

  combo.on_selection_change(fn() {
    combo_label.set_text("下拉选择：\{combo.get_selected_item()}")
    state.log("下拉选择 \{combo.get_selected_item()}")
  })
  picker.on_selection_change(fn() {
    state.log("选择器 → \{picker.get_selected_item()}")
  })
  date.on_date_change(fn() { state.log("时间变更为 \{date.get_date()}") })
  policy_btn.on_click(fn() {
    policy_on = !policy_on
    if policy_on {
      scroll.set_scrollbar_policy(@yue.Always, @yue.Always)
    } else {
      scroll.set_scrollbar_policy(@yue.Automatic, @yue.Automatic)
    }
    let p = scroll.get_scrollbar_policy()
    let name = fn(v : @yue.ScrollPolicy) -> String {
      if v is @yue.Always {
        "常显"
      } else if v is @yue.Never {
        "隐藏"
      } else {
        "自动"
      }
    }
    policy_btn.set_title("滚动条策略: \{name(p.0)}/\{name(p.1)}")
    state.log("滚动条策略 =\{name(p.0)}/\{name(p.1)}")
  })
  edit.on_text_change(fn() { state.log("文本编辑变化") })
  pop_btn.on_click(fn() {
    let pop = @yue.Popover::new()
    let tip = @yue.Label::new("这是一个 Popover 气泡")
    tip.set_style("padding", 10.0)
    pop.set_content(tip)
    pop.set_content_size(180.0, 44.0)
    pop.on_close(fn() { state.log("气泡关闭") })
    pop.show_relative_to(pop_btn)
    let _ = win
  })
  page
}

///|
/// 表格模型：语言清单 + 可编辑星数 + 勾选。
struct LangModel {
  names : Array[String]
  stars : Array[Int]
  likes : Array[Bool]
}

///|
impl @yue.TableModel for LangModel with row_count(self) {
  self.names.length()
}

///|
impl @yue.TableModel for LangModel with get_value(self, column, row) {
  match column {
    0 => @yue.Str(self.names[row])
    1 => @yue.Flag(self.likes[row])
    2 => @yue.Str("\{self.stars[row]} ★")
    _ => @yue.Str("?")
  }
}

///|
impl @yue.TableModel for LangModel with set_value(self, column, row, value) {
  match (column, value) {
    (1, @yue.Flag(b)) => self.likes[row] = b
    (2, @yue.Str(s)) => {
      // 取前导数字（用户编辑星数列后回写）
      let mut n = 0
      let mut seen = false
      for i in 0..<s.length() {
        let c = s.unsafe_get(i).to_int()
        if c >= 48 && c <= 57 {
          n = n * 10 + (c - 48)
          seen = true
        } else if seen {
          break
        }
      }
      self.stars[row] = if seen { n } else { self.stars[row] }
    }
    (_, _) => ()
  }
}

///|
/// 表格演示（独立子窗口）：文本 / 复选 / 可编辑列 + 行激活事件。
/// 注：Table 在 GTK 的 Notebook 页内测量尺寸会触发崩溃，因此放独立窗口。
fn open_table_window(state : State) -> Unit {
  let win = @yue.Window::new()
  win.set_title("表格演示")
  win.set_content_size(520.0, 380.0)

  let page = @yue.Container::new()
  page.set_style("padding", 12.0)

  let table = @yue.Table::new()
  table.add_column_with_options("语言", { column_type: @yue.Text, column: 0, width: 160 })
  table.add_column_with_options("喜欢", { column_type: @yue.Checkbox, column: -1, width: 80 })
  table.add_column_with_options("星数", { column_type: @yue.Edit, column: -1, width: 120 })
  table.set_has_border(true)
  table.set_style("flex", 1.0)
  table.set_model(
    LangModel::{
      names: ["MoonBit", "Rust", "Zig", "Go"],
      stars: [5, 5, 4, 3],
      likes: [true, true, true, false],
    },
    3,
  )
  table.on_row_activate(fn(row) { state.log("表格行激活：第 \{row} 行") })
  table.on_selection_change(fn() { state.log("表格选择变化") })
  page.add_child(table)

  let log = state.new_log_label()
  log.set_style("marginTop", 8.0)
  page.add_child(log)

  win.set_content(page)
  win.center()
  win.activate()
}

///|
/// 页 4：自绘画布（onDraw + schedulePaint 重绘）+ 富文本。
fn build_canvas(state : State) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)

  let head = @yue.Label::new("画布 —— Canvas 自绘（点击按钮旋转色相）")
  head.set_style_str("color", "#356AA0")
  head.set_style("marginBottom", 10.0)
  page.add_child(head)

  let canvas = @yue.Container::new()
  canvas.set_style("height", 320.0)
  canvas.set_style("marginBottom", 8.0)
  page.add_child(canvas)

  let btn_row = @yue.Container::new()
  btn_row.set_style_str("flexDirection", "row")
  btn_row.set_style("marginBottom", 8.0)
  page.add_child(btn_row)
  let repaint = @yue.Button::new("旋转色相重绘")
  btn_row.add_child(repaint)
  let blend_btn = @yue.Button::new("混合模式: Normal")
  blend_btn.set_style("marginRight", 8.0)
  btn_row.add_child(blend_btn)
  let img_btn = @yue.Button::new("绘制/导出图片")
  btn_row.add_child(img_btn)
  let blends = [@yue.BlendMode::Normal, @yue.Multiply, @yue.Screen, @yue.Difference, @yue.Xor]
  let mut blend_i = 0
  let icon_img : @yue.Image? = match @yue.read_binary_file("examples/drag_source/drag.png") {
    Some(bytes) => {
      let img = @yue.Image::new_from_png(bytes)
      if img.is_empty() {
        state.log("图片解码失败")
        None
      } else {
        state.log("图片解码 \{img.get_width()}×\{img.get_height()} sf=\{img.get_scale_factor()}")
        Some(img)
      }
    }
    None => None
  }

  let draw = fn(painter : @yue.Painter) {
    let hue = state.canvas_hue
    painter.set_fill_color("#20242C")
    painter.fill_rect(0.0, 0.0, 640.0, 320.0)
    // 三色圆环
    let colors = ["#E8B34B", "#4B8BE8", "#4BE888"]
    for i in 0..<3 {
      let c = colors[(i + hue) % 3]
      painter.set_fill_color(c)
      let cx = 160.0 + i.to_double() * 160.0
      painter.arc(cx, 140.0, 60.0, 0.0, 6.28318)
      painter.fill()
    }
    // 网格线
    painter.set_stroke_color("#4A5060")
    for k in 0..<9 {
      painter.stroke_rect(24.0, 220.0 + k.to_double() * 10.0, 592.0, 1.0)
    }
    painter.set_fill_color("#F0F0F0")
    painter.draw_text(
      "MoonBit × libyue 自绘文本",
      24.0,
      280.0,
      592.0,
      30.0,
      align=@yue.TextAlign::Center,
      color="#F0F0F0",
    )
    let _ = hue
  }
  // 图片叠加进绘制管线(混合模式对它生效)
  let draw_with_image = fn(painter : @yue.Painter) {
    draw(painter)
    match icon_img {
      Some(img) => {
        painter.set_blend_mode(blends[blend_i])
        let b = canvas.get_bounds()
        painter.draw_image(img, b.width - 90.0, 10.0, 80.0, 80.0)
        painter.set_blend_mode(@yue.Normal)
      }
      None => ()
    }
  }
  canvas.on_draw(fn(p) { draw_with_image(p) })
  canvas.schedule_paint()
  repaint.on_click(fn() {
    state.canvas_hue = (state.canvas_hue + 1) % 3
    canvas.schedule_paint()
    state.log("画布重绘 hue=\{state.canvas_hue}")
  })
  blend_btn.on_click(fn() {
    blend_i = (blend_i + 1) % blends.length()
    blend_btn.set_title("混合模式: \{blend_i}")
    canvas.schedule_paint()
    state.log("混合模式切换 ->\{blend_i}")
  })
  img_btn.on_click(fn() {
    match icon_img {
      Some(img) => {
        let half = img.resize(img.get_width() / 2.0, img.get_height() / 2.0)
        let ok = half.write_to_file("png", "/tmp/showcase_icon_half.png")
        state.log("图片缩放导出 /tmp/showcase_icon_half.png ok=\{ok}")
        canvas.schedule_paint()
      }
      None => state.log("无图片可导出")
    }
  })
  // 尺寸变化 + 计算布局转储(几何族/布局调试)
  let mut resize_count = 0
  canvas.on_size_changed(fn() {
    resize_count += 1
    if resize_count == 1 {
      let b = canvas.get_bounds()
      state.log("画布首布局 \{b.width}×\{b.height} 窗口偏移 (\{@yue.offset_from_window(canvas).dx}, \{@yue.offset_from_window(canvas).dy})")
    }
  })
  page
}

///|
/// 页 5：网页视图（WebKit）+ 地址栏 + 导航。
fn build_browser(win : @yue.Window) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)

  let head = @yue.Label::new("网页 —— Browser 内嵌 WebKit 视图")
  head.set_style_str("color", "#356AA0")
  head.set_style("marginBottom", 10.0)
  page.add_child(head)

  let bar = @yue.Container::new()
  bar.set_style_str("flexDirection", "row")
  bar.set_style("marginBottom", 8.0)
  let url = @yue.Entry::new()
  url.set_text("https://www.moonbitlang.com")
  url.set_style("flex", 1.0)
  bar.add_child(url)
  let go = @yue.Button::new("转到")
  bar.add_child(go)
  let back = @yue.Button::new("←")
  bar.add_child(back)
  let fwd = @yue.Button::new("→")
  bar.add_child(fwd)
  page.add_child(bar)

  let browser = @yue.Browser::new()
  browser.set_style("flex", 1.0)
  page.add_child(browser)

  // 自定义协议 demo://hello — 演示注册/渲染/注销
  @yue.Browser::register_protocol("demo", fn(_url) {
    Some((
      "text/html",
      "<html><body style='font-family:sans-serif'><h2>demo:// 自定义协议 ✓</h2><p>由 ProtocolStringJob 提供,通过 register_protocol 注册。</p></body></html>",
    ))
  })

  let js_btn = @yue.Button::new("执行 JS")
  js_btn.set_style("marginRight", 8.0)
  bar.add_child(js_btn)
  let html_btn = @yue.Button::new("本地 HTML")
  html_btn.set_style("marginRight", 8.0)
  bar.add_child(html_btn)
  let demo_btn = @yue.Button::new("demo://")
  bar.add_child(demo_btn)

  go.on_click(fn() { browser.load_url(url.get_text()) })
  url.on_activate(fn() { browser.load_url(url.get_text()) })
  back.on_click(fn() { browser.go_back() })
  fwd.on_click(fn() { browser.go_forward() })
  browser.on_update_title(fn(_url) {
    win.set_title("Showcase — \{browser.get_url()}")
  })
  js_btn.on_click(fn() {
    browser.execute_javascript("document.title = 'JS-OK'")
    state_log_helper("已执行 JS(若生效标题会变为 JS-OK)")
  })
  html_btn.on_click(fn() {
    browser.load_html("<h3>load_html 本地片段</h3><p>不经过网络。</p>")
  })
  demo_btn.on_click(fn() { browser.load_url("demo://hello") })
  browser.load_url(url.get_text())
  page
}

///|
/// 页 6：文件对话框 + 消息框。
fn build_dialogs(win : @yue.Window, state : State) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)

  let head = @yue.Label::new("对话框 —— 文件打开 / 保存 / 消息框")
  head.set_style_str("color", "#356AA0")
  head.set_style("marginBottom", 10.0)
  page.add_child(head)

  let result = @yue.Label::new("（结果）")
  result.set_style("marginBottom", 10.0)
  page.add_child(result)

  let open_btn = @yue.Button::new("打开文件…")
  open_btn.set_style("marginBottom", 8.0)
  page.add_child(open_btn)

  let save_btn = @yue.Button::new("保存文件…")
  save_btn.set_style("marginBottom", 8.0)
  page.add_child(save_btn)

  let msg_btn = @yue.Button::new("弹出消息框")
  page.add_child(msg_btn)

  open_btn.on_click(fn() {
    let dlg = @yue.FileDialog::new_open()
    dlg.set_filters("文本文件:txt,md|所有文件:*")
    dlg.set_options(@yue.FILE_OPTION_MULTI_SELECT)
    if dlg.run_for_window(win) {
      let path = dlg.get_result()
      result.set_text("已选：\{path}")
      let content = @yue.read_text_file(path)
      let desc = match content {
        Some(c) => "\{c.length()} 字符"
        None => "失败"
      }
      state.log("读取文件 \{path}（\{desc}）")
    } else {
      state.log("取消了打开")
    }
  })
  save_btn.on_click(fn() {
    let dlg = @yue.FileDialog::new_save()
    dlg.set_filename("showcase.txt")
    if dlg.run_for_window(win) {
      let ok = @yue.write_text_file(dlg.get_result(), "由 showcase 写入\n")
      result.set_text("保存 \{dlg.get_result()}：\{ok}")
      state.log("保存文件 ok=\{ok}")
    } else {
      state.log("取消了保存")
    }
  })
  msg_btn.on_click(fn() {
    let box = @yue.MessageBox::new(@yue.Information)
    box.set_title("消息框")
    box.set_text("这是一个 MessageBox")
    box.set_informative_text("支持标题 / 正文 / 附加信息与按钮响应。")
    box.show_for_window(win)
  })
  page
}

///|
/// 页 7：系统集成 —— 托盘 / 剪贴板 / 通知 / 快捷键 / 环境信息。
fn build_system(win : @yue.Window, state : State) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)

  let head = @yue.Label::new("系统集成 —— 托盘 / 剪贴板 / 通知 / 全局快捷键 / 环境")
  head.set_style_str("color", "#356AA0")
  head.set_style("marginBottom", 10.0)
  page.add_child(head)

  let info = @yue.Label::new(
    "平台 \{@yue.platform()} ｜ 桌面 \{@yue.desktop_environment()} ｜ 区域 \{@yue.locale()} ｜ 深色 \{@yue.Appearance::is_dark()} ｜ 缩放 \{@yue.Screen::scale_factor()} ｜ 主屏 \{@yue.Screen::primary_size().0}×\{@yue.Screen::primary_size().1}",
  )
  info.set_style("marginBottom", 10.0)
  page.add_child(info)

  let clip_in = @yue.Entry::new()
  clip_in.set_text("复制我到剪贴板")
  clip_in.set_style("marginBottom", 8.0)
  page.add_child(clip_in)

  let clip_row = @yue.Container::new()
  clip_row.set_style_str("flexDirection", "row")
  clip_row.set_style("marginBottom", 8.0)
  let set_btn = @yue.Button::new("写入剪贴板")
  let get_btn = @yue.Button::new("读取剪贴板")
  let clip_out = @yue.Label::new("（剪贴板内容）")
  clip_out.set_style("marginLeft", 10.0)
  clip_row.add_child(set_btn)
  clip_row.add_child(get_btn)
  clip_row.add_child(clip_out)
  page.add_child(clip_row)

  let notify_btn = @yue.Button::new("发送桌面通知(带按钮)")
  notify_btn.set_style("marginBottom", 8.0)
  page.add_child(notify_btn)

  let data_row = @yue.Container::new()
  data_row.set_style_str("flexDirection", "row")
  data_row.set_style("marginBottom", 8.0)
  let html_clip_btn = @yue.Button::new("剪贴板写 HTML")
  let sel_clip_btn = @yue.Button::new("主选区读回")
  html_clip_btn.set_style("marginRight", 8.0)
  data_row.add_child(html_clip_btn)
  data_row.add_child(sel_clip_btn)
  page.add_child(data_row)

  let timer_btn = @yue.Button::new("定时器演示(500ms×3)")
  timer_btn.set_style("marginBottom", 8.0)
  page.add_child(timer_btn)

  let winopt_btn = @yue.Button::new("窗口: 切换可调整大小")
  winopt_btn.set_style("marginBottom", 8.0)
  page.add_child(winopt_btn)

  let veto_btn = @yue.Button::new("关闭拦截: 关")
  veto_btn.set_style("marginBottom", 8.0)
  page.add_child(veto_btn)

  let shortcut_btn = @yue.Button::new("注册全局快捷键 Ctrl+Alt+S")
  shortcut_btn.set_style("marginBottom", 8.0)
  page.add_child(shortcut_btn)

  let table_btn = @yue.Button::new("打开表格演示窗口")
  table_btn.set_style("marginBottom", 8.0)
  page.add_child(table_btn)

  page.add_child(state.new_log_label())

  set_btn.on_click(fn() { @yue.Clipboard::get().set_text(clip_in.get_text()) })
  get_btn.on_click(fn() {
    clip_out.set_text("剪贴板：\{@yue.Clipboard::get().get_text()}")
  })
  notify_btn.on_click(fn() {
    let n = @yue.Notification::new()
    n.set_title("来自 Showcase")
    n.set_body("桌面通知正常工作 ✓(带两个按钮)")
    n.set_actions([("查看", "view"), ("忽略", "ignore")])
    @yue.NotificationCenter::add(n)
    n.show()
    state.log("通知(带按钮)已发送")
  })
  html_clip_btn.on_click(fn() {
    @yue.Clipboard::get().set_data(@yue.Html, "<b>showcase 富文本剪贴板</b>")
    state.log("剪贴板写入 HTML 数据")
  })
  sel_clip_btn.on_click(fn() {
    let sel = @yue.Clipboard::from_type(@yue.Selection)
    sel.set_data(@yue.Text, "主选区内容")
    match sel.get_data(@yue.Text) {
      Some(@yue.Text(t)) => state.log("主选区读回: \{t}")
      _ => state.log("主选区读回失败")
    }
  })
  timer_btn.on_click(fn() {
    let ticks = Ref(0)
    let _id = @yue.set_timer(500, fn() {
      ticks.val += 1
      state.log("定时器 tick \{ticks.val}")
      if ticks.val >= 3 {
        state.log("定时器自动停止")
        return false
      }
      true
    })
    ignore(_id)
    let _tid2 = @yue.set_timeout(1700, fn() {
      state.log("单次延时任务触发")
    })
    ignore(_tid2)
  })
  winopt_btn.on_click(fn() {
    let now = win.is_resizable()
    win.set_resizable(!now)
    win.set_has_shadow(now)
    state.log("窗口 resizable=\{!now} shadow=\{now} maximized=\{win.is_maximized()}")
  })
  veto_btn.on_click(fn() {
    state.veto_close.val = !state.veto_close.val
    veto_btn.set_title("关闭拦截: \{state.veto_close.val}")
    state.log("关闭拦截 =\{state.veto_close.val}")
  })
  table_btn.on_click(fn() { open_table_window(state) })
  shortcut_btn.on_click(fn() {
    let id = @yue.register_global_shortcut("Ctrl+Alt+S", fn() {
      state.log("全局快捷键触发！")
      let n = @yue.Notification::new()
      n.set_title("全局快捷键")
      n.set_body("Ctrl+Alt+S 被按下（全局，无需聚焦）")
      @yue.NotificationCenter::add(n)
      n.show()
    })
    state.log("快捷键注册 id=\{id}")
  })
  page
}
