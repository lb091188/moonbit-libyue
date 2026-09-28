// 图标画法探针:大尺寸渲染指定图标,配合截图自看迭代
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_content_size(260.0, 140.0)
  window.set_title("icon-probe")
  window.center()
  let box_ = @yue.Container::new()
  box_.set_style("width", 260.0)
  box_.set_style("height", 140.0)
  box_.on_draw(fn(p) {
    @yue.draw_icon(p, @yue.IconKind::Users, 70.0, 70.0, 48.0, "#333333")
    @yue.draw_icon(p, @yue.IconKind::Users, 180.0, 70.0, 24.0, "#333333")
  })
  window.set_content(box_)
  window.activate()
  println("probe-icon ready")
  @yue.run()
}
