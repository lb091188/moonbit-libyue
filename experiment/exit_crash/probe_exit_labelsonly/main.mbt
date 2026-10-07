// 对照探针:与 probe_exit_nofocus 唯一差异是子控件全用 label_t
// (GTK Label 不可聚焦,窗口内不存在 can_focus 子控件),主动 quit。
// 若退出段错误依赖「可聚焦子控件持有焦点」,此探针应恒干净退出。
///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  @yue.theme_apply(@yue.theme_from_system())
  let items : Array[@yue.Node] = []
  for i in 0..<8 {
    items.push(@yue.label_t("标签\{i}"))
  }
  ignore(
    @yue.mount_window(
      [@yue.vbox([..items], style=[("padding", 24.0), ("gap", 6.0)])],
      title="exit-crash-labelsonly",
      size=Some((260.0, 420.0)),
      center=true,
      on_close=fn(_w) { @yue.quit() },
    ),
  )
  @yue.post_delayed_task(1500, fn() { @yue.quit() })
  @yue.run()
}
