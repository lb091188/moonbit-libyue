// 宽度自定义验证(临时):五组件统一 width=300,截图像素测量实际宽度。

///|
///|
fn main {
  if !@yue.initialize() {
    return
  }
  let picked : @yue.Store[String] = @yue.Store::new("")
  let dv : @yue.Store[@yue.DateYMD?] = @yue.Store::new(None)
  let sv : @yue.Store[Double] = @yue.Store::new(0.5)
  let rows : Array[@yue.Node] = [
    @yue.label_t("select_t 300"),
    @yue.select_t(["杭州", "北京", "上海", "深圳", "广州"], picked, width=300.0),
    @yue.label_t("input_t 300"),
    @yue.input_t(width=300.0),
    @yue.label_t("input_t 300 + 超长文本(验证溢出指示已隐)"),
    @yue.input_t(
      width=300.0,
      text="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    ),
    @yue.label_t("textarea_t 300"),
    @yue.textarea_t(width=300.0, height=70.0),
    @yue.label_t("date_picker_t 300"),
    @yue.date_picker_t(value=dv, width=300.0),
    @yue.label_t("slider_t 300"),
    @yue.slider_t(sv, width=300.0),
  ]
  let window = @yue.mount_window(
    [@yue.vbox(rows, style=[("padding", 16.0)])],
    title="width=300 验证",
    size=Some((380.0, 640.0)),
  )
  window.activate()
  @yue.run()
}
