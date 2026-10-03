// 输入链路与 set_selectable 自动诊断:事件计数 + GTK 属性读回。
#borrow(w)
extern "c" fn ffi_gtk_label_get_selectable(w : UInt64) -> Int = "gtk_label_get_selectable"

fn main {
  if !@yue.initialize() {
    println("init 失败")
    return
  }
  let window = @yue.Window::new()
  window.set_title("input-probe")
  let label = @yue.Label::new("selectable 探针")
  ignore(label) // set_selectable 已撤销:NULabel 非 GtkLabel,见 adaptation.md
  let host = @yue.Container::new()
  host.set_background_color("#305050")
  host.add_child(label)
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(400.0, 300.0)
  window.activate()
  // set_selectable 读回(期望 1;类名已查明为 NULabel 自绘控件)
  let h = @yue.native_handle_view(label.view)
  println("selectable_readback=\{ffi_gtk_label_get_selectable(h)}")
  // 事件计数
  let down = Ref(0)
  let mv = Ref(0)
  let up = Ref(0)
  let wheel = Ref(0)
  host.on_mouse_down(fn(_e) {
    down.val = down.val + 1
    println("mouse_down #\{down.val}")
    host.set_capture()
    true
  })
  host.on_mouse_move(fn(e) {
    mv.val = mv.val + 1
    println("mouse_move #\{mv.val} at \{e.view_x},\{e.view_y}")
  })
  host.on_mouse_up(fn(_e) {
    up.val = up.val + 1
    println("mouse_up #\{up.val}")
    true
  })
  host.on_wheel(fn(d) {
    wheel.val = wheel.val + 1
    println("wheel #\{wheel.val} delta=\{d}")
  })
  // 6 秒后自动退出,汇总
  @yue.set_timer(6000, fn() {
    println("SUMMARY down=\{down.val} move=\{mv.val} up=\{up.val} wheel=\{wheel.val}")
    @yue.quit()
    false
  })
  @yue.run()
}
