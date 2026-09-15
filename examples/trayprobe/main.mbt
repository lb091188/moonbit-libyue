// 托盘适配探针：跨桌面环境实测托盘图标 / 激活 / 右键菜单的最小工具。
// 全部关键事件打 stdout 日志（[probe] 前缀），便于 SSH 自动化里 grep 判定。
// 运行：moon run examples/trayprobe（须在仓库根，图标路径按相对路径解析）。

///|
let last_event : Ref[String] = Ref("（无）")

///|
fn log(msg : String) -> Unit {
  println("[probe] \{msg}")
  last_event.val = msg
}

///|
fn main {
  if !@yue.initialize() {
    println("[probe] GUI 初始化失败")
    return
  }
  log("platform=\{@yue.platform()} desktop=\{@yue.desktop_environment()} tray_supported=\{@yue.Tray::is_supported()}")

  let window = @yue.Window::new()
  window.set_title("trayprobe")
  window.set_content_size(380.0, 160.0)
  let status = @yue.Label::new("托盘探针已启动，看面板角落的月牙图标")
  window.set_content(status)
  window.center()
  window.on_close(fn(_w) { @yue.quit() })

  if !@yue.Tray::is_supported() {
    log("无托盘后端，退出")
    return
  }
  match @yue.Tray::new("examples/trayprobe/icon.png") {
    Ok(tray) => {
      tray.set_title("trayprobe")
      tray.set_tooltip("trayprobe", "托盘适配探针：左键激活，右键菜单")
      let menu = @yue.Menu::new()
      let show_item = menu.add_label_item("显示窗口")
      show_item.on_click(fn() {
        window.activate()
        log("菜单点击：显示窗口")
      })
      let theme_item = menu.add_label_item("换成终端图标(set_icon_name)")
      theme_item.on_click(fn() {
        tray.set_icon_name("utilities-terminal")
        log("菜单点击：set_icon_name(utilities-terminal)")
      })
      let _ = menu.add_separator()
      let quit_item = menu.add_label_item("退出")
      quit_item.on_click(fn() {
        log("菜单点击：退出 → quit()")
        @yue.quit()
      })
      tray.set_menu(menu)
      tray.on_click(fn() { log("托盘激活(Activate/点击)") })
      log("托盘已创建，菜单挂载完毕（3 项 + 分隔线）")
    }
    Err(e) => log("托盘创建失败：\{e}")
  }
  @yue.run()
}
