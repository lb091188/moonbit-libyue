// 隐藏驻留（W23）：hide/show 往返的显隐标志与幂等。无显示服务环境跳过；
// 真机（XFCE+X11）跑通即回证 XWithdrawWindow 链路，唤回原位的肉眼确认走人工清单。

///|
test "hide/show：往返切换 is_hidden 跟随，幂等不重做" {
  if !init_backend() {
    println("hide: skip (无显示服务)")
  } else {
    let win = Window::new(240, 160, "wbtest-hide")
    match win {
      None => println("hide: skip (建窗失败)")
      Some(w) => {
        w.show()
        inspect(w.is_hidden(), content="false")
        w.hide()
        inspect(w.is_hidden(), content="true")
        let (ow, oh) = w.size()
        // 幂等：已隐藏再 hide 不重做（尺寸读数不受影响）
        w.hide()
        inspect(w.is_hidden(), content="true")
        let (sw, sh) = w.size()
        inspect(sw == ow && sh == oh, content="true")
        w.show()
        inspect(w.is_hidden(), content="false")
        // hide 后 request_focus 不异常（W23 验收）
        w.hide()
        w.request_focus()
        inspect(w.is_hidden(), content="true")
        w.show()
        w.close()
      }
    }
  }
}
