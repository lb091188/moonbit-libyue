// 主题组件库版 hello：theme_apply 生效后全部用主题化组件(button_t/label_t
// /input_t)搭建,不碰任何原生控件外观;窗口底色与文字色随主题走。
// 与 examples/hello 对照:那边是 libyue 原生控件裸用,系统默认外观。

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  // 启动跟随系统深浅,可换 default_theme() 固定浅色
  @yue.theme_apply(
    if @yue.system_prefers_dark() {
      @yue.dark_theme()
    } else {
      @yue.default_theme()
    },
  )
  let name : @yue.Store[String] = @yue.Store::new("MoonBit")
  let greet : @yue.Store[String] = @yue.Store::new("(点「问候」)")
  ignore(
    @yue.mount_window(
    [
      @yue.vbox(
        [
          @yue.label_t("Hello, 主题组件库!", role=@yue.Title),
          @yue.label_t("输入名字点问候,按钮/输入框/文字全是主题化形态。", role=@yue.Secondary),
          @yue.input_t(
            text=name.get(),
            width=240.0,
            on_input=fn(t) { name.set(t) },
          ),
          @yue.button_t(
            "问候",
            variant=@yue.Solid,
            on_click=fn() { greet.set("你好,\{name.get()}!") },
          ),
          @yue.bind_label(greet, fn(s) { s }),
        ],
        style=[("padding", 24.0), ("gap", 12.0)],
      ),
    ],
    title="hello-themed",
    size=Some((360.0, 260.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
    ),
  )
  @yue.run()
}
