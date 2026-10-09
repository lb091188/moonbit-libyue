// 对照探针:与 probe_exit 唯一差异是不调 focus()(焦点不在任何
// button_t 上),其余一致(主动 quit)。若退出段错误的必要条件是
// 「焦点在可聚焦控件上」,此探针应恒干净退出。
///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  @yue.theme_apply(@yue.theme_from_system())
  let btns : Array[@yue.Node] = []
  for i in 0..<8 {
    btns.push(@components.button_t("按钮\{i}"))
  }
  ignore(
    @declarative.mount_window(
      [@declarative.vbox([..btns], style=[("padding", 24.0), ("gap", 6.0)])],
      title="exit-crash-nofocus",
      size=Some((260.0, 420.0)),
      center=true,
      on_close=fn(_w) { @yue.quit() },
    ),
  )
  @yue.post_delayed_task(1500, fn() { @yue.quit() })
  @yue.run()
}
