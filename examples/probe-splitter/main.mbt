// splitter 拖宽失效机制探针(第 4 版):样式改写路径已定性失效
// (第 2/3 版:width/flexbasis 运行期改写 GTK 全不落地),本版验证
// set_bounds 直写三件几何(首栏/把手/次栏)是否生效,A=直挂窗口、
// B=scroll 内各测两档。

fn dump(tag : String, pane_a : @yue.Container, outer : @yue.Container) -> Unit {
  let pa = pane_a.get_bounds()
  let o = outer.get_bounds()
  println("[\{tag}] pane_a=\{pa.width} outer=\{o.width}")
}

/// 按首栏宽 x 直写三件几何(相对 outer,像素)
fn apply_bounds(
    outer : @yue.Container,
    pane_a : @yue.Container,
    handle : @yue.Container,
    pane_b : @yue.Container,
    x : Double) -> Unit {
  let b = outer.get_bounds()
  @yue.set_view_bounds(pane_a, 0.0, 0.0, x, b.height)
  @yue.set_view_bounds(handle, x, 0.0, 8.0, b.height)
  @yue.set_view_bounds(pane_b, x + 8.0, 0.0, b.width - x - 8.0, b.height)
}

/// 造一组 splitter 结构,返回 (根容器, 首栏, 把手, 次栏)
fn mk_split() -> (@yue.Container, @yue.Container, @yue.Container, @yue.Container) {
  let outer = @yue.Container::new()
  outer.set_style("flex", 1.0)
  outer.set_style("height", 110.0)
  outer.set_style_str("flexDirection", "row")
  let pane_a = @yue.Container::new()
  pane_a.set_style("width", 150.0)
  pane_a.set_style_str("flexDirection", "column")
  pane_a.add_child(@yue.Label::new("首栏 A"))
  outer.add_child(pane_a)
  let handle = @yue.Container::new()
  handle.set_style("width", 8.0)
  outer.add_child(handle)
  let pane_b = @yue.Container::new()
  pane_b.set_style("flex", 1.0)
  pane_b.set_style_str("flexDirection", "column")
  pane_b.add_child(@yue.Label::new("次栏 B"))
  outer.add_child(pane_b)
  (outer, pane_a, handle, pane_b)
}

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_content_size(560.0, 460.0)
  let root = @yue.Container::new()
  root.set_style_str("flexDirection", "column")
  root.add_child(@yue.Label::new("A=直挂窗口  B=scroll 内(set_bounds 直写)"))
  let (outer_a, pane_a, handle_a, pane_b2) = mk_split()
  root.add_child(outer_a)
  root.add_child(@yue.Label::new("以下 B 在 scroll 内"))
  let scroll = @yue.Scroll::new()
  scroll.set_style("flex", 1.0)
  let holder = @yue.Container::new()
  holder.set_style_str("flexDirection", "column")
  let (outer_b, pane_ba, handle_b, pane_bb) = mk_split()
  holder.add_child(outer_b)
  scroll.set_content(holder)
  root.add_child(scroll)
  window.set_content(root)
  window.center()
  window.on_close(fn(_w) { @yue.quit() })
  window.activate()
  let step : Ref[Int] = Ref(0)
  @yue.set_timer(600, fn() {
    let s = step.val
    step.val = s + 1
    match s {
      0 => dump("01 A 初始", pane_a, outer_a)
      1 => dump("02 B(scroll) 初始", pane_ba, outer_b)
      2 => apply_bounds(outer_a, pane_a, handle_a, pane_b2, 260.0)
      3 => dump("03 A set_bounds 260", pane_a, outer_a)
      4 => apply_bounds(outer_a, pane_a, handle_a, pane_b2, 320.0)
      5 => dump("04 A set_bounds 320", pane_a, outer_a)
      6 => apply_bounds(outer_b, pane_ba, handle_b, pane_bb, 260.0)
      7 => dump("05 B(scroll) set_bounds 260", pane_ba, outer_b)
      8 => apply_bounds(outer_b, pane_ba, handle_b, pane_bb, 320.0)
      9 => dump("06 B(scroll) set_bounds 320", pane_ba, outer_b)
      _ => {
        println("探针结束")
        @yue.quit()
      }
    }
    s < 10
  })
  @yue.run()
}
