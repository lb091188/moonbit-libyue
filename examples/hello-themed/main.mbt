// 主题组件库版 hello：跟随系统深浅/主色之后，界面全部用主题化组件
// （label_t / entry / button_t / bind_label）搭建，不碰任何原生控件外观；
// 窗口底色与文字色随主题走。与 examples/hello 对照：那边只放一行文字。
//
// 跑法：moon run examples/hello-themed（需要显示服务；没有时打印一行提示后退出）

///|
fn main {
  let name : @core.Store[String] = @core.Store::new("MoonBit")
  let greet : @core.Store[String] = @core.Store::new("(点「问候」)")
  let app = match @ui.mount_window(
    [
      @ui.col(
        [
          @ui.text("Hello, 主题组件库!", role=@ui.Title),
          @ui.text(
            "输入名字点问候，按钮/输入框/文字全是主题化形态。",
            role=@ui.Secondary,
          ),
          @ui.entry(name, width=240.0),
          @ui.button_t("问候", variant=@ui.Solid, on_click=fn() {
            greet.set("你好,\{name.get()}!")
          }),
          @ui.bind_label(greet, fn(s : String) -> String { s }),
        ],
        padding=24.0,
        row_gap=12.0,
      ),
    ],
    title="hello-themed",
    width=360,
    height=260,
    handle=fn(a : @core.App) -> Unit {
      // 启动即按系统偏好上色，之后每 2 秒看一次系统有没有切换；
      // 返回的停表函数在本栈里由宿主收尾，不必自己持有
      let _ = a.follow_system_theme(interval_ms=2000)
    },
  ) {
    None => {
      println("HELLO-THEMED-SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(a) => a
  }
  app.run()
}
