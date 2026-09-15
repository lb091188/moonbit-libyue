// 布局演示 + 实测断言：对照 layout_system 指南，把 flex/gap/百分比/对齐/
// 绝对定位/min-width 的 yoga 计算结果与预期几何逐一核对。
// 点「校验布局」按钮打印 CHECK 报告（±1px 容差），Esc 退出。

///|
let failures : Ref[Int] = Ref(0)

///|
fn check(name : String, got : Double, want : Double) -> Unit {
  let ok = (got - want).abs() <= 1.0
  if !ok {
    failures.val += 1
  }
  println("CHECK \{name} want=\{want} got=\{got} ok=\{ok}")
}

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_title("Layout 演示")
  window.set_content_size(600.0, 400.0)
  window.center()
  window.on_close(fn(_window) { @yue.quit() })

  let root = @yue.Container::new()
  root.set_style_str("flexDirection", "column")
  window.set_content(root)

  // 区 1：row + padding + gap + flex + 百分比宽
  let sec1 = @yue.Container::new()
  sec1.set_style("height", 100.0)
  sec1.set_style_str("flexDirection", "row")
  sec1.set_style("padding", 10.0)
  sec1.set_style("gap", 10.0)
  root.add_child(sec1)
  let a = @yue.Container::new()
  a.set_style("flex", 1.0)
  a.set_background_color("#E5534B")
  sec1.add_child(a)
  let b = @yue.Container::new()
  b.set_style_str("width", "50%")
  b.set_background_color("#57AB5A")
  sec1.add_child(b)

  // 区 2：column + justify 居中 + align 居中
  let sec2 = @yue.Container::new()
  sec2.set_style("height", 100.0)
  sec2.set_style_str("flexDirection", "column")
  sec2.set_style_str("justifycontent", "center")
  sec2.set_style_str("alignitems", "center")
  root.add_child(sec2)
  let c = @yue.Container::new()
  c.set_style("width", 100.0)
  c.set_style("height", 40.0)
  c.set_background_color("#D4A72C")
  sec2.add_child(c)

  // 区 3：row + flex 与 min-width 竞争 + 绝对定位
  let sec3 = @yue.Container::new()
  sec3.set_style("height", 100.0)
  sec3.set_style_str("flexDirection", "row")
  root.add_child(sec3)
  let e = @yue.Container::new()
  e.set_style("flex", 1.0)
  e.set_style("minwidth", 150.0)
  e.set_background_color("#6183BB")
  sec3.add_child(e)
  let f = @yue.Container::new()
  f.set_style("width", 500.0)
  f.set_background_color("#8250DF")
  sec3.add_child(f)
  let d = @yue.Container::new()
  d.set_style_str("position", "absolute")
  d.set_style("left", 20.0)
  d.set_style("top", 10.0)
  d.set_style("width", 50.0)
  d.set_style("height", 30.0)
  d.set_background_color("#1A1A1A")
  sec3.add_child(d)

  // 底部：校验按钮
  let footer = @yue.Container::new()
  footer.set_style("flex", 1.0)
  footer.set_style_str("alignitems", "center")
  footer.set_style_str("justifycontent", "center")
  root.add_child(footer)
  let run_btn = @yue.Button::new("校验布局（打印 CHECK 报告）")
  footer.add_child(run_btn)
  run_btn.on_click(fn() {
    let ra = a.get_bounds()
    let rb = b.get_bounds()
    let rc = c.get_bounds()
    let re = e.get_bounds()
    let rf = f.get_bounds()
    let rd = d.get_bounds()
    // 区 1：内容区 580 宽，B=50%=290，gap 10 → A=280；交叉轴 stretch → 高 80
    check("A.x", ra.x, 10.0)
    check("A.w", ra.width, 280.0)
    check("A.h", ra.height, 80.0)
    check("B.x", rb.x, 300.0)
    check("B.w", rb.width, 290.0)
    // 区 2：C 在 600x100 中水平垂直居中（相对 sec2）
    check("C.x", rc.x, 250.0)
    check("C.y", rc.y, 30.0)
    check("C.w", rc.width, 100.0)
    check("C.h", rc.height, 40.0)
    // 区 3：E flex=1 得 100 但 minwidth=150 托底；F 顺移溢出；D 绝对定位
    check("E.x", re.x, 0.0)
    check("E.w", re.width, 150.0)
    check("F.x", rf.x, 150.0)
    check("D.x", rd.x, 20.0)
    check("D.y", rd.y, 10.0)
    check("D.w", rd.width, 50.0)
    check("D.h", rd.height, 30.0)
    // 文本族：TextFormat/TextAttributes/文本往返/系统语义色
    let at = @yue.AttributedText::new_with(
      "hello 文本",
      @yue.TextAttributes::new(),
    )
    at.set_text("文本 A~Z 往返")
    let rt_ok = at.get_text() == "文本 A~Z 往返"
    if !rt_ok {
      failures.val += 1
    }
    println("CHECK text_roundtrip got=\"\{at.get_text()}\" ok=\{rt_ok}")
    let tb = at.get_bounds_for(200.0, 50.0)
    check("text.bounds_w>0", if tb.width > 0.0 { 1.0 } else { 0.0 }, 1.0)
    let sys = @yue.system_color(@yue.Text)
    let sys_ok = sys.length() == 9
    if !sys_ok {
      failures.val += 1
    }
    println("CHECK system_color text=\{sys} ok=\{sys_ok}")
    // 范围属性（视觉：前 2 字符红色加粗），API 调用即验证 ABI 通畅
    at.set_font_for(@yue.Font::new("Sans", 20.0, weight=@yue.Bold), 0, 2)
    at.set_color_for("#E5534B", 0, 2)
    println("CHECK text_range_attrs applied")
    println("LAYOUT_SUMMARY failures=\{failures.val}")
  })

  window.on_key_down(fn(event) {
    if event.code == @yue.VKEY_ESCAPE {
      println("EVENT quit")
      @yue.quit()
      true
    } else {
      false
    }
  })

  // 首次布局完成后转储一次根节点计算布局（调试参考）
  window.on_size_changed(fn() { println("LAYOUT_DUMP size_changed") })

  window.activate()
  @yue.run()
}
