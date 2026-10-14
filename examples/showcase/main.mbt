// 组件库演示板：侧边导航切换分页。目录结构：
//   shared/ 共享层（App 跨页状态、page/section 段装配、复制回显钩子）
//   pages/  各页内容（每页一个文件）
//   assets/ 图片资源
//
// 响应式分层演示：主题五页（基础/表单/导航/数据/反馈）与各组件页用
// Store/Signal 直连，展示端不写手动 subscribe。
//
// G7 示例迁移（本批 = 骨架 + 第一页）：
//   - 旧链路的 `@yue.initialize()` + `@yue.run()` 换成 `@ui.mount_window` +
//     `App::run`；窗口居中交给 WM（本栈不提供 `center`，与 master 的一条差）。
//   - 主题跟随不再走 `@yue.on_system_theme_change`（旧链路的平台事件通道），
//     改为「跟随开关 + 每 2 秒读一次系统偏好」：手动选色/切深浅先把开关关掉，
//     否则下一拍就被盖回去。系统偏好读数用 `@win.sys_color_scheme/sys_accent`
//     （与 `App::follow_system_theme` 内部同一来源，示例要能手动覆盖故自己开表）。
//   - 菜单栏 / 单实例已接线（2026-10-13 第十五批）：菜单栏是 W20a 的模型
//     翻译（`MenuBar::apply_to` → 原生菜单栏，点击经 `dispatch_menu_command`
//     派发到模型回调，100ms 轮询表挂在宿主）；单实例是 dbus 层的
//     `claim_name` + Wake（无会话总线的环境降级为不做，只打印说明）；
//     D-Bus 的排期通道与 200ms 泵都由宿主给。托盘菜单在系统集成页托盘段。
//   - 待迁页：全部迁完（见 TODO.md；表单组件页 2026-10-12 已迁，事件与布局/
//     窗口/系统集成/图标库/画布与富文本/浏览器六页 2026-10-13 已迁）。

///|
/// 窗口标题
const SHOWCASE_TITLE : String = "组件库演示板"

///|
/// 侧栏底部的版本号。旧链路读 `@yue.VERSION`（主包常量，`scripts/prebuild.py`
/// 在构建期校验它与 `moon.mod` 一致）；新栈示例不再 import 主包，故本地留一份
/// ——它只用于显示，权威值仍是 `moon.mod` 与 `yue/version.mbt`。
const SHOWCASE_VERSION : String = "0.1.0"

///|
/// 主题应用：主色空串用内置基准盘，非空按 HSL 公式派生；深浅随 `dark`。
fn apply_theme(app : @shared.App) -> Unit {
  let dark = app.dark_mode.get()
  let accent = app.accent.get()
  if accent.length() == 0 {
    @theme.theme_apply(if dark {
      @theme.dark_theme()
    } else {
      @theme.default_theme()
    })
  } else {
    @theme.theme_apply(@theme.theme_from_accent(accent, dark=dark))
  }
}

///|
/// 侧栏里的深/浅切换按钮：手动改即视为「不跟随系统」。
fn theme_toggle_button(app : @shared.App) -> @core.Node {
  @ui.icon_button(
    @icons.Moon,
    on_click=fn() {
      app.follow.set(false)
      app.dark_mode.update(fn(v) { !v })
    },
  )
}

///|
/// 菜单栏模型（第十五批接线）：动作全部真实有效——「导航」切页、「主题」
/// 拨深浅与跟随开关、「帮助」关于冒提示 / 退出角色项走 `App::quit`。
/// 项点击经原生菜单派发链（`dispatch_menu_command`）回到这些回调。
fn build_menu_bar(app : @shared.App) -> @core.MenuBar {
  let bar = @core.MenuBar::new()
  let nav = bar.add_menu("导航")
  for name in ["基础组件", "表单组件", "数据展示", "系统集成", "浏览器"] {
    let page = name
    let _ = nav.add_item(page).set_on_click(fn() { app.selected.set(page) })
  }
  let theme = bar.add_menu("主题")
  let _ = theme.add_check_item("跟随系统").set_on_click(fn() {
    app.follow.update(fn(v) { !v })
  })
  let _ = theme.add_item("浅色").set_on_click(fn() {
    app.follow.set(false)
    app.dark_mode.set(false)
  })
  let _ = theme.add_item("深色").set_on_click(fn() {
    app.follow.set(false)
    app.dark_mode.set(true)
  })
  let help = bar.add_menu("帮助")
  let _ = help.add_item("关于").set_on_click(fn() {
    app.toast_push("libyue 组件库演示板 V" + SHOWCASE_VERSION, @ui.Info)
  })
  let _ = help.add_separator()
  let _ = help.add_role_item(@core.MenuRole::Quit).set_on_click(fn() {
    match app.host.val {
      Some(a) => a.quit()
      None => ()
    }
  })
  bar
}

///|
fn main {
  let selected : @core.Store[String] = @core.Store::new("基础组件")
  let toast_push = @ui.toast_layer(duration_ms=2600)
  // 代码区「复制」的回显走同一 toast 层
  @shared.code_toast.val = Some(toast_push)
  let counter = @core.Signal::new(0)
  let app : @shared.App = {
    selected,
    toast: toast_push,
    dark_mode: @core.Store::new(@win.sys_color_scheme() == "dark"),
    // 启动即跟随系统主色调（系统无主色概念时回落内置 primary）
    accent: @core.Store::new(@win.sys_accent()),
    follow: @core.Store::new(true),
    counter,
    // visits/ratio 由 counter 派生（computed 自动收集依赖，不写手动接线）
    visits: @core.Signal::computed(fn() {
      (counter.get() * 1601 + 12804).to_string()
    }),
    ratio: @core.Signal::computed(fn() {
      let r = 0.25 + counter.get().to_double() * 0.1
      if r > 1.0 {
        1.0
      } else {
        r
      }
    }),
    picked_lang: @core.Signal::new(""),
    dlg_basic: @core.Store::new(false),
    dlg_form: @core.Store::new(false),
    dlg_name: @core.Store::new(""),
    dlg_result: @core.Store::new(""),
    // 宿主句柄：挂载时由下方 handle 回调填入（窗口页/快捷键页取用）
    host: Ref(None),
  }
  // 深浅/主色任一变化即整体换主题；subscribe 注册不回调，故先应用一次
  app.dark_mode.subscribe(fn(_v) { apply_theme(app) })
  app.accent.subscribe(fn(_a) { apply_theme(app) })
  apply_theme(app)
  // 单实例（dbus 层）：先声称总线名；已有实例就唤起它并退出。
  // 无会话总线的环境（如 Windows 桌面）Err 降级为不做，只打印说明。
  match @dbus.claim_name("com.moonbitlibyue.showcase") {
    Ok(@dbus.PrimaryOwner) | Ok(@dbus.AlreadyOwner) =>
      // 首实例：注册 Wake 回调——切回首页并冒提示
      @dbus.on_wake(fn(_args : Array[String]) -> Unit {
        selected.set("基础组件")
        app.toast_push("已被第二实例唤起", @ui.Info)
      })
    Ok(@dbus.AlreadyExists) | Ok(@dbus.InQueue) => {
      let _ = @dbus.wake_existing("com.moonbitlibyue.showcase", [])
      println("SHOWCASE-INST: 已有实例，已唤起并退出")
      return
    }
    Err(e) => println("SHOWCASE-INST: 单实例降级（\{e}）")
  }
  let slot : Ref[@core.App?] = Ref(None)
  let mounted = @ui.mount_window(
    [
      @ui.row(
        [
          // 侧栏：可滚动的分组菜单（窗口矮时滚到底部项）+ 底部主题切换 + 版本号
          @ui.col(
            [
              @ui.scroll_view(
                [
                  @ui.menu_sections(
                    [("组件", ["基础组件", "表单组件", "导航组件", "数据展示", "图表", "代码文档", "Store", "反馈组件", "事件与布局", "窗口", "系统集成", "图标库", "画布与富文本", "浏览器", "过渡与效果"])],
                    selected,
                    icons=[
                      ("基础组件", @icons.Appstore),
                      ("表单组件", @icons.Edit1),
                      ("导航组件", @icons.Compass),
                      ("数据展示", @icons.Chart),
                      ("图表", @icons.DataLine),
                      ("代码文档", @icons.Document),
                      ("Store", @icons.Database),
                      ("反馈组件", @icons.ChatRound),
                      ("事件与布局", @icons.Mouse),
                      ("窗口", @icons.Windows),
                      ("系统集成", @icons.Cpu),
                      ("图标库", @icons.Layout),
                      ("画布与富文本", @icons.Brush),
                      ("浏览器", @icons.Chrome),
                      ("过渡与效果", @icons.MagicStick),
                    ],
                    width=180.0,
                  ),
                ],
                @ui.ScrollState::new(),
                handle=fn(v) { v.node.set_flex_grow(1.0) },
              ),
              @ui.row(
                [
                  @ui.text("V" + SHOWCASE_VERSION, role=@ui.Secondary),
                  theme_toggle_button(app),
                ],
                padding=10.0,
                column_gap=8.0,
              ),
            ],
            width=180.0,
          ),
          // 主区：按导航状态切换的页（惰性挂载，首次选中才建控件）
          @ui.col(
            [
              @shared.nav_page("基础组件", selected, @pages.page_basic(app)),
              @shared.nav_page("表单组件", selected, @pages.page_form(app)),
              @shared.nav_page("导航组件", selected, @pages.page_nav(app)),
              @shared.nav_page("数据展示", selected, @pages.page_data(app)),
              @shared.nav_page("图表", selected, @pages.page_charts(app)),
              @shared.nav_page("代码文档", selected, @pages.page_code(app)),
              @shared.nav_page("Store", selected, @pages.page_store_demo(app)),
              @shared.nav_page("反馈组件", selected, @pages.page_feedback(app)),
              @shared.nav_page("事件与布局", selected, @pages.page_events(app)),
              @shared.nav_page("窗口", selected, @pages.page_window(app)),
              @shared.nav_page("系统集成", selected, @pages.page_system(app)),
              @shared.nav_page("图标库", selected, @pages.page_icons(app)),
              @shared.nav_page("画布与富文本", selected, @pages.page_canvas(app)),
              @shared.nav_page("浏览器", selected, @pages.page_browser(app)),
              @shared.nav_page("过渡与效果", selected, @pages.page_anim(app)),
              // 对话框挂窗口根：锚点自己是 0 尺寸占位，可见性只由 Store 驱动
              @ui.dialog(
                app.dlg_basic,
                "删除确认",
                [
                  @ui.alert(
                    "此操作不可撤销，请确认。",
                    t=@ui.Warning,
                    closable=true,
                  ),
                  @ui.text("确定要删除「示例项目」吗？", role=@ui.Body),
                ],
                confirm_text="删除",
                cancel_text="取消",
                on_confirm=fn() { app.dlg_result.set("已确认删除") },
                close_on_mask=true,
              ),
              @ui.dialog(
                app.dlg_form,
                "新建连接",
                [
                  @ui.text("名称", role=@ui.Body),
                  @ui.input(app.dlg_name, placeholder="例如：开发库", width=320.0),
                  @ui.text("地址", role=@ui.Body),
                  @ui.input(@core.Store::new(""), placeholder="host:port", width=320.0),
                ],
                on_confirm=fn() { app.dlg_result.set(app.dlg_name.get()) },
                width=380.0,
              ),
            ],
            grow=1.0,
          ),
        ],
        grow=1.0,
        align_items=@yoga.AlignItems::Stretch,
      ),
    ],
    title=SHOWCASE_TITLE,
    width=1280,
    height=720,
    handle=fn(a : @core.App) {
      slot.val = Some(a)
      // 窗口页/快捷键页经 `app.host` 取宿主（页函数体跑完时还没挂载，这里填）
      app.host.val = Some(a)
      // 单实例的 D-Bus 接线：排期通道与 200ms 泵都由宿主给（dbus 不引 GUI
      // 核心层）。无总线时 pump 空转，无副作用。
      @dbus.dbus_set_post_delayed(fn(ms : Int, f : () -> Unit) -> Unit {
        let _ = a.timer(ms, f)
      })
      let pump : Ref[() -> Unit] = Ref(fn() { () })
      pump.val = fn() -> Unit {
        @dbus.dbus_pump()
        let _ = a.timer(200, pump.val)
      }
      (pump.val)()
      // 原生菜单栏：模型翻译成原生菜单挂窗口；项点击经 WM_COMMAND 回收，
      // 100ms 轮询表派发到模型回调（托盘菜单项走同一条派发链）
      let bar = build_menu_bar(app)
      if bar.apply_to(a.window) {
        let menu_tick : Ref[() -> Unit] = Ref(fn() { () })
        menu_tick.val = fn() -> Unit {
          let _ = @core.dispatch_menu_command()
          let _ = a.timer(100, menu_tick.val)
        }
        (menu_tick.val)()
      } else {
        println("SHOWCASE-MENU: 菜单栏挂载失败（后端不支持或建菜单失败）")
      }
      // 「跟随系统」轮询：开关打开时每 2 秒读一次系统深浅与主色，
      // 变了就写进 App（App 的 subscribe 再落成 theme_apply）
      let tick : Ref[() -> Unit] = Ref(fn() { () })
      tick.val = fn() -> Unit {
        if app.follow.get() {
          app.dark_mode.set(@win.sys_color_scheme() == "dark")
          app.accent.set(@win.sys_accent())
        }
        let _ = a.timer(2000, tick.val)
      }
      (tick.val)()
    },
  )
  match mounted {
    None => {
      println("SHOWCASE-SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(host) => {
      println("SHOWCASE-READY title=\{SHOWCASE_TITLE} pages=14 follow=1")
      @core.paint_profile_reset()
      host.run()
    }
  }
  println("SHOWCASE-DONE page=\{selected.get()}")
  // 帧耗时分段账本：切页/渲染卡顿归因用（布局 vs 绘制 vs 上屏，见 gui/core/prof.mbt）。
  // Windows 的 GUI 进程 stdout 到不了 moon run 的捕获，落一份文件兜底（cwd=运行目录）
  let prof = @core.paint_profile_summary()
  println("SHOWCASE-PROF " + prof)
  let body = "SHOWCASE-PROF " + prof + "\n"
  let cwd = @sys.current_dir()
  let _ = if cwd == "" {
    @sys.sys_write_text_file("showcase-prof.txt", body)
  } else {
    @sys.sys_write_text_file(cwd + "/showcase-prof.txt", body)
  }
}
