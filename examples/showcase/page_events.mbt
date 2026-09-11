// 事件页与富文本页：对照 events_and_delegates 指南与文本族的完整演示。

///|
/// 页：事件 —— 鼠标五事件 / 双击计数 / 鼠标捕获 / 键盘 / 定时器轮询全局鼠标。
fn build_events(win : @yue.Window, state : State) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)
  let head = @yue.Label::new("事件 —— 移入蓝色区域 / 点击 / 双击 / 按住捕获 / 按键（配合下方日志）")
  head.set_style_str("color", "#356AA0")
  head.set_style("marginBottom", 10.0)
  page.add_child(head)
  let status = @yue.Label::new("（事件状态）")
  status.set_style("marginBottom", 8.0)
  page.add_child(status)
  // 键盘事件状态（window.on_key_down 更新）
  let key_status = @yue.Label::new("（在此窗口按键，Esc 修饰键提示）")
  key_status.set_style("marginBottom", 8.0)
  page.add_child(key_status)

  // 事件接收区
  let area = @yue.Container::new()
  area.set_style("flex", 1.0)
  area.set_background_color("#4A90D9")
  page.add_child(area)
  let tracker = @yue.ClickTracker::new()
  area.on_mouse_enter(fn(e) {
    status.set_text("enter @(\{e.view_x}, \{e.view_y})")
    state.log("鼠标进入")
  })
  area.on_mouse_leave(fn(_e) {
    status.set_text("leave")
    state.log("鼠标离开")
  })
  area.on_mouse_move(fn(e) {
    status.set_text("move @(\{e.view_x}, \{e.view_y}) btn=\{e.button}")
  })
  area.on_mouse_down(fn(e) {
    let clicks = tracker.feed(e)
    status.set_text(
      "down btn=\{e.button} 第\{clicks}次点击 mods=\{e.modifiers} ts=\{e.timestamp}",
    )
    if clicks >= 2 {
      state.log("双击！btn=\{e.button} 连击 \{clicks} 次")
    }
    false
  })
  area.on_mouse_up(fn(e) {
    status.set_text("up btn=\{e.button}")
    false
  })

  // 鼠标捕获
  let cap_row = @yue.Container::new()
  cap_row.set_style_str("flexDirection", "row")
  cap_row.set_style("marginTop", 8.0)
  page.add_child(cap_row)
  let cap_btn = @yue.Button::new("切换鼠标捕获")
  cap_btn.set_style("marginRight", 10.0)
  cap_row.add_child(cap_btn)
  let cap_state = @yue.Label::new("未捕获")
  cap_row.add_child(cap_state)
  cap_btn.on_click(fn() {
    if area.has_capture() {
      area.release_capture()
    } else {
      area.set_capture()
    }
    cap_state.set_text(if area.has_capture() { "已捕获" } else { "未捕获" })
    state.log("鼠标捕获 =\{area.has_capture()}")
  })
  area.on_capture_lost(fn() {
    cap_state.set_text("捕获被夺走")
    state.log("捕获丢失")
  })

  // 键盘：挂在主窗口（Signal 支持多槽）
  win.on_key_down(fn(e) {
    let mods = if e.has_mod(@yue.KEY_MOD_SHIFT) {
      "Shift+"
    } else if e.has_mod(@yue.KEY_MOD_CTRL) {
      "Ctrl+"
    } else {
      ""
    }
    key_status.set_text("key \{mods}code=\{e.code}（Esc=\{@yue.VKEY_ESCAPE}, A=\{@yue.VKEY_A}）")
    if e.code == @yue.VKEY_A {
      state.log("按键 A \{mods}")
    } else if e.code == @yue.VKEY_ESCAPE {
      state.log("按键 Esc")
    }
    false
  })

  // 定时器轮询全局鼠标位置与修饰键（MessageLoop + Event 静态查询）
  let global_label = @yue.Label::new("（全局鼠标位置，200ms 轮询）")
  global_label.set_style("marginTop", 8.0)
  page.add_child(global_label)
  let _timer = @yue.set_timer(200, fn() {
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
    global_label.set_text("全局鼠标 (\{mx.round()}, \{my.round()}) 修饰键: \{mods}")
    true
  })
  page.add_child(state.new_log_label())
  page
}

///|
/// 页：富文本 —— AttributedText 全属性 + 范围着色 + 换行/省略 + 系统语义色。
fn build_richtext(state : State) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("padding", 12.0)
  let head = @yue.Label::new("富文本 —— AttributedText / 范围属性 / 系统语义色")
  head.set_style_str("color", "#356AA0")
  head.set_style("marginBottom", 10.0)
  page.add_child(head)

  // 富文本绘制区
  let canvas = @yue.Container::new()
  canvas.set_style("height", 140.0)
  canvas.set_background_color("#F4F4F0")
  canvas.set_style("marginBottom", 8.0)
  page.add_child(canvas)
  let at = @yue.AttributedText::new_with(
    "MoonBit 富文本：这段文字有范围着色与粗体。",
    @yue.TextAttributes::new(),
  )
  let big = @yue.Font::new("Sans", 20.0, weight=@yue.Bold)
  at.set_font(big)
  at.set_font_for(@yue.Font::new("Sans", 24.0, weight=@yue.Black), 0, 6)
  at.set_color("#356AA0")
  at.set_color_for("#E5534B", 8, 11)
  let mut ellipsis = false
  let mut wrap = true
  canvas.on_draw(fn(painter) {
    let size = canvas.get_bounds()
    painter.fill_rect(0.0, 0.0, size.width, size.height)
    painter.draw_attributed_text(at, 10.0, 20.0, size.width - 20.0, 100.0)
  })
  canvas.schedule_paint()

  let btn_row = @yue.Container::new()
  btn_row.set_style_str("flexDirection", "row")
  btn_row.set_style("marginBottom", 8.0)
  page.add_child(btn_row)
  let wrap_btn = @yue.Button::new("换行: 开")
  wrap_btn.set_style("marginRight", 8.0)
  btn_row.add_child(wrap_btn)
  let ell_btn = @yue.Button::new("省略号: 关")
  btn_row.add_child(ell_btn)
  let info = @yue.Label::new("")
  info.set_style("marginBottom", 8.0)
  page.add_child(info)

  wrap_btn.on_click(fn() {
    wrap = !wrap
    at.set_format({
      align: @yue.Start,
      valign: @yue.Start,
      wrap,
      ellipsis,
    })
    wrap_btn.set_title("换行: \{wrap}")
    canvas.schedule_paint()
    state.log("富文本换行 =\{wrap}")
  })
  ell_btn.on_click(fn() {
    ellipsis = !ellipsis
    at.set_format({
      align: @yue.Start,
      valign: @yue.Start,
      wrap: true,
      ellipsis,
    })
    ell_btn.set_title("省略号: \{ellipsis}")
    canvas.schedule_paint()
    state.log("富文本省略号 =\{ellipsis}")
  })

  // 文本往返
  let rt_btn = @yue.Button::new("改写文本（get/set 往返）")
  rt_btn.set_style("marginBottom", 8.0)
  page.add_child(rt_btn)
  rt_btn.on_click(fn() {
    at.set_text("文本已替换 ✓（属性保留）")
    info.set_text("get_text = \{at.get_text()}")
    let b = at.get_bounds_for(300.0, 80.0)
    state.log(
      "bounds_for(300,80) = \{b.width}×\{b.height}",
    )
    canvas.schedule_paint()
  })

  // 系统语义色
  let sys_label = @yue.Label::new(
    "系统语义色 Text=\{@yue.system_color(@yue.Text)} WindowBackground=\{@yue.system_color(@yue.WindowBackground)} Border=\{@yue.system_color(@yue.Border)}",
  )
  sys_label.set_style("marginTop", 4.0)
  page.add_child(sys_label)
  page
}
