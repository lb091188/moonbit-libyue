// moonbit-libyue 全功能 Showcase：全部页面用声明式 API（Node/mount/Store）实现。
// 结构：Tab 页签 × 小程序式分段（标题 + 说明 + 可玩演示），见 section.mbt；
// 平台差异内容按 platform() 运行时条件组装（桌面环境、托盘后端、剪贴板
// 主选区、自定义协议等只在对应平台出现）。

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let _ = @yue.mount_window(
    // Tab 无 measure 函数,yoga 叶子尺寸在构造时固化(当时 0 页,min 高≈页头),
    // 且 add_page 不刷新;挂在容器里必须给显式外框,flex 1 让页签区撑满窗口。
    // 页内布局不经过 Tab 的 yoga 树:add_page 只挂 GTK 页,每页容器各自是
    // 独立 yoga 子树的根。
    [@yue.tab(build_tabs(), style=[("padding", 8.0), ("flex", 1.0)])],
    title="moonbit-libyue 全功能 Showcase",
    size=Some((960.0, 640.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
    handle=fn(win) {
      main_win.val = Some(win)
      win.set_menubar(build_menubar(win))
      setup_tray(win)
      setup_close_guard(win)
      setup_key_hook(win)
      setup_custom_protocol()
      win.activate()
    },
  )
  @yue.run()
}

///|
/// 十二个页签：名称 + 声明式页面节点。
fn build_tabs() -> Array[(String, @yue.Node)] {
  [
    ("基础控件", page_basics()),
    ("输入与选择", page_inputs()),
    ("布局与容器", page_layout()),
    ("画布与绘制", page_canvas()),
    ("网页", page_browser()),
    ("表格", page_table()),
    ("对话框与消息", page_dialogs()),
    ("菜单与快捷键", page_menu()),
    ("托盘与通知", page_tray()),
    ("剪贴板与系统", page_system()),
    ("环境信息", page_env()),
    ("事件与拖拽", page_events()),
  ]
}

///|
/// 菜单栏：文件 / 编辑 / 演示 / 帮助。Menu 不是视图，经 mount_window 的
/// handle 以命令式补挂（声明树与命令式资产共存的示范）。
fn build_menubar(win : @yue.Window) -> @yue.MenuBar {
  let bar = @yue.MenuBar::new()
  let file = bar.add_menu("文件")
  let about = file.add_label_item("关于本演示")
  about.set_accelerator("CmdOrCtrl+I")
  about.on_click(fn() { show_about(win) })
  let _ = file.add_separator()
  let quit = file.add_label_item("退出")
  quit.set_accelerator("CmdOrCtrl+Q")
  quit.on_click(fn() { @yue.quit() })
  let edit = bar.add_menu("编辑")
  let _c = edit.add_role_item(@yue.Copy)
  let _x = edit.add_role_item(@yue.Cut)
  let _p = edit.add_role_item(@yue.Paste)
  let _s = edit.add_role_item(@yue.SelectAll)
  let demo = bar.add_menu("演示")
  let table_item = demo.add_label_item("表格（独立窗口）")
  table_item.on_click(fn() { open_table_window() })
  let traverse = demo.add_label_item("遍历本菜单结构")
  traverse.on_click(fn() {
    let mut text = "「演示」菜单共 \{demo.item_count()} 项："
    for i in 0..<demo.item_count() {
      text = text + " [\{i}]\{demo.item_at(i).get_label()}"
    }
    menu_info.set(text)
  })
  let help = bar.add_menu("帮助")
  let env_item = help.add_label_item("桌面环境信息")
  env_item.on_click(fn() { show_about(win) })
  bar
}

///|
/// 关闭拦截：系统页勾选后，点窗口关闭被 set_should_close 拦下。
fn setup_close_guard(win : @yue.Window) -> Unit {
  win.set_should_close(fn() {
    if close_veto.val {
      veto_info.set("关闭请求被 set_should_close 拦截（回「剪贴板与系统」页解除）")
      return false
    }
    true
  })
}

///|
/// 键盘钩子：窗口级 on_key_down 更新事件页显示。
fn setup_key_hook(win : @yue.Window) -> Unit {
  win.on_key_down(fn(e) {
    key_info.set("按键 \{e.describe()}（键码 \{e.code}，Esc=\{@yue.VKEY_ESCAPE} A=\{@yue.VKEY_A}）")
    false
  })
}

///|
/// 自定义协议 demo://：注册一次供网页页使用（Windows WebView2 下静默无效）。
fn setup_custom_protocol() -> Unit {
  @yue.Browser::register_protocol("demo", fn(_url) {
    Some((
      "text/html",
      "<html><body style='font-family:sans-serif;background:#20242C;color:#eee'><h2>demo:// 自定义协议 ✓</h2><p>由 register_protocol 注册，ProtocolStringJob 应答。</p></body></html>",
    ))
  })
}

///|
fn show_about(win : @yue.Window) -> Unit {
  let box = @yue.MessageBox::new(@yue.Information)
  box.set_title("关于")
  box.set_text("moonbit-libyue Showcase")
  box.set_informative_text(
    "平台 \{@yue.platform()} ｜ 桌面 \{@yue.desktop_environment()} ｜ 区域 \{@yue.locale()}",
  )
  box.show_for_window(win)
}

///|
/// 系统托盘：Linux 走纯 MoonBit SNI 后端，其他平台原生后端；
/// 状态与点击计数联动「托盘与通知」页显示。
fn setup_tray(win : @yue.Window) -> Unit {
  if !@yue.Tray::is_supported() {
    tray_info.set("当前环境托盘不可用（is_supported = false）")
    return
  }
  match @yue.Tray::new("examples/showcase/icon.png") {
    Ok(tray) => {
      tray_ref.val = Some(tray)
      tray.set_title("showcase")
      tray.set_tooltip("moonbit-libyue", "左键计数，右键菜单")
      let menu = @yue.Menu::new()
      let show_item = menu.add_label_item("显示主窗口")
      show_item.on_click(fn() { win.activate() })
      let _ = menu.add_separator()
      let quit_item = menu.add_label_item("退出")
      quit_item.on_click(fn() { @yue.quit() })
      tray.set_menu(menu)
      tray.on_click(fn() {
        tray_clicks.update(fn(n) { n + 1 })
        let n = @yue.Notification::new()
        n.set_title("托盘被点击")
        n.set_body("第 \{tray_clicks.get()} 次点击托盘图标")
        n.show()
      })
      tray_info.set("托盘已创建（桌面 \{@yue.desktop_environment()}）")
    }
    Err(e) => tray_info.set("托盘创建失败：\{e}")
  }
}
