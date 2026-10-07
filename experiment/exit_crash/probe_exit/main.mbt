// 退出段错误定向复现探针:窗口内放多个 button_t(自绘 Container,
// set_focusable(true) + on_focus_out→repaint 链),启动 700ms 后程序内
// focus() 到其中一个,再由外部 wmctrl -ic 发关闭请求,复刻
// 「焦点在 button_t 上时窗口关闭」的时序,观察进程退出码。
///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  @yue.theme_apply(@yue.theme_from_system())
  let target : Ref[@yue.Container] = Ref(@yue.Container::new())
  let btns : Array[@yue.Node] = []
  for i in 0..<8 {
    let idx = i
    btns.push(
      @yue.button_t("按钮\{idx}", handle=fn(c) {
        if idx == 3 {
          target.val = c
        }
      }),
    )
  }
  ignore(
    @yue.mount_window(
      [@yue.vbox([..btns], style=[("padding", 24.0), ("gap", 6.0)])],
      title="exit-crash-probe",
      size=Some((260.0, 420.0)),
      center=true,
      on_close=fn(_w) { @yue.quit() },
    ),
  )
  // 700ms 后把 GTK 焦点交给 3 号 button_t(自绘可聚焦容器)
  @yue.post_delayed_task(700, fn() {
    target.val.focus()
    println("focused")
  })
  // 1500ms 后程序主动 quit(不经 delete-event,窗口未销毁、焦点仍在
  // button 上)——复刻「菜单退出/回调内 quit」路径:窗口销毁被推迟到
  // exit 静态析构期,届时 gtk_widget_destroy 才同步发 focus-out。
  @yue.post_delayed_task(1500, fn() {
    println("quitting")
    @yue.quit()
  })
  @yue.run()
}
