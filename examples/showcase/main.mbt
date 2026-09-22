// 组件库演示板:侧边导航切换分页,每页内容在独立的 pages_*.mbt。
// 响应式分层演示:
//   主题五页(基础/表单/导航/数据/反馈)用 Signal 自动依赖收集;
//   「Store 对照」页保留 Store 手动接线模式,可与信号页对照;
//   原生控件页纯命令式 set;事件/系统/窗口/画布页维持 Store 手动模式。
// 跨页状态收在 App(导航/窗口/托盘/对话框/主题页共享计数),页内私有
// 状态留在各页函数体内。

///|
fn is_linux() -> Bool {
  @yue.platform() == "linux"
}

///|
/// 一段演示:标题 + 一句说明 + 演示区 + 分隔留白。
/// 标题/说明走 label_t 文字角色(Section / Secondary)。
fn section(
  title : String,
  desc : String,
  content : Array[@yue.Node],
) -> @yue.Node {
  let t = @yue.label_t(title, role=@yue.Section, style=[
    ("marginBottom", 4.0),
  ])
  let d = @yue.label_t(desc, role=@yue.Secondary, style=[
    ("marginBottom", 10.0),
  ])
  let nodes : Array[@yue.Node] = [t, d]
  for c in content {
    nodes.push(c)
  }
  nodes.push(@yue.separator(style=[("marginTop", 4.0), ("marginBottom", 20.0)]))
  @yue.vbox(nodes, style=[("marginBottom", 6.0)])
}

///|
/// 一页 = 整页滚动区包住全部分段。
fn scroll_page(sections : Array[@yue.Node]) -> @yue.Node {
  @yue.scroll(@yue.vbox(sections, style=[("padding", 14.0)]), style=[
    ("flex", 1.0),
  ])
}

///|
/// 主区页面:挂载后订阅导航状态做 set_visible 切换。
fn page(
  name : String,
  selected : @yue.Store[String],
  content : @yue.Node,
) -> @yue.Node {
  @yue.vbox([content], style=[("flex", 1.0)], handle=fn(c) {
    fn apply(s : String) -> Unit {
      c.set_visible(s == name)
    }

    apply(selected.get())
    selected.subscribe(apply)
  })
}

///|
/// 跨页共享状态:导航、窗口/托盘句柄、对话框、主题页共享计数。
/// 各页函数以 app 单参取用;页内私有状态不进 App。
struct App {
  selected : @yue.Store[String]
  toast : (String, @yue.SemanticType) -> Unit
  win_ref : Ref[@yue.Window?]
  tray_ref : Ref[@yue.Tray?]
  close_veto : Ref[Bool]
  veto_info : @yue.Store[String]
  dark_mode : @yue.Store[Bool]
  // 主题主色(hex):空串 = 内置基准盘,否则 theme_from_accent 公式派生
  accent : @yue.Store[String]
  tray_clicks : @yue.Store[Int]
  dlg_basic : @yue.Store[Bool]
  dlg_form : @yue.Store[Bool]
  dlg_name : @yue.Store[String]
  key_info : @yue.Store[String]
  // 主题页共享信号:基础页 Button 触发,数据页 Statistic/Progress 展示,
  // visits/ratio 为 computed 派生(信号版消灭了手动 subscribe 接线)
  counter : @yue.Signal[Int]
  visits : @yue.Signal[String]
  ratio : @yue.Signal[Double]
  picked_lang : @yue.Signal[String]
}

///|
/// 推送一条轻提示(转发 toast 函数字段;函数值字段不能直接点调用)。
fn App::toast_push(
  self : App,
  text : String,
  t : @yue.SemanticType,
) -> Unit {
  (self.toast)(text, t)
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let selected : @yue.Store[String] = @yue.Store::new("基础组件")
  let (toast_node, toast_push) = @yue.toast_layer()
  let counter = @yue.Signal::new(0)
  let app : App = {
    selected,
    toast: toast_push,
    win_ref: Ref(None),
    tray_ref: Ref(None),
    close_veto: Ref(false),
    veto_info: @yue.Store::new("(未开启拦截)"),
    dark_mode: @yue.Store::new(@yue.system_prefers_dark()),
    // 启动即跟随系统主色调(系统无主色概念时回落内置 primary)
    accent: @yue.Store::new(@yue.system_accent()),
    tray_clicks: @yue.Store::new(0),
    dlg_basic: @yue.Store::new(false),
    dlg_form: @yue.Store::new(false),
    dlg_name: @yue.Store::new(""),
    key_info: @yue.Store::new("(无)"),
    counter,
    visits: counter.map(fn(n) { (n * 1601 + 12804).to_string() }),
    ratio: counter.map(fn(n) {
      let r = 0.25 + n.to_double() * 0.1
      if r > 1.0 {
        1.0
      } else {
        r
      }
    }),
    picked_lang: @yue.Signal::new(""),
  }
  // 深浅主题:启动跟随系统,系统切换时实时联动;「切换深浅」按钮手动覆盖。
  // 主色(accent)非空时改走公式派生色板,深浅切换沿用当前主色
  fn apply_theme() -> Unit {
    let dark = app.dark_mode.get()
    let accent = app.accent.get()
    if accent == "" {
      @yue.theme_apply(if dark { @yue.dark_theme() } else { @yue.default_theme() })
    } else {
      @yue.theme_apply(@yue.theme_from_accent(accent, dark~))
    }
  }

  app.dark_mode.subscribe(fn(_v) { apply_theme() })
  app.accent.subscribe(fn(_a) { apply_theme() })
  @yue.on_system_theme_change(fn() { app.dark_mode.set(@yue.system_prefers_dark()) })
  // 初始应用一次(subscribe 注册不回调):系统深浅 + 系统主色
  apply_theme()

  let window = @yue.mount_window(
    [
      @yue.hbox(style=[("flex", 1.0)], style_str=[("alignItems", "stretch")], [
        // 侧栏:菜单(可滚动,窗口矮时滚到底部项) + 底部钉住包版本号
        // (与 moon.mod 同步,scripts/prebuild.py 构建期校验)
        @yue.vbox(
          [
            @yue.scroll(
              @yue.vbox(
                [
                  @yue.side_menu_sections(
                    [
                      (
                        "组件",
                        [
                          "基础组件", "图标库", "表单组件", "导航组件", "数据展示",
                          "图表", "反馈组件", "代码与文档", "事件与布局", "Store 对照",
                        ],
                      ),
                      ("原生与自绘", ["原生控件", "画布与富文本"]),
                      ("系统能力", ["系统集成", "窗口", "浏览器", "环境与平台"]),
                    ],
                    selected,
                    icons=[
                      ("基础组件", @yue.Grid),
                      ("图标库", @yue.Star),
                      ("表单组件", @yue.Edit),
                      ("导航组件", @yue.Hamburger),
                      ("数据展示", @yue.BarChart),
                      ("图表", @yue.PieChart),
                      ("反馈组件", @yue.MessageCircle),
                      ("代码与文档", @yue.Code),
                      ("事件与布局", @yue.Zap),
                      ("Store 对照", @yue.Refresh),
                      ("原生控件", @yue.Monitor),
                      ("画布与富文本", @yue.Image),
                      ("系统集成", @yue.Gear),
                      ("窗口", @yue.Square),
                      ("浏览器", @yue.Globe),
                      ("环境与平台", @yue.Cpu),
                    ],
                  ),
                ],
                style=[("width", 180.0)],
              ),
              style=[("flex", 1.0), ("width", 180.0)],
            ),
            @yue.label_t(
              "moonbit-libyue \{@yue.VERSION}",
              role=@yue.Secondary,
              style=[("paddingLeft", 20.0), ("paddingTop", 6.0), ("paddingBottom", 10.0)],
            ),
          ],
          style=[("width", 180.0)],
          handle=fn(c) {
            fn apply() -> Unit {
              c.set_background_color(@yue.theme_current().bg_panel)
            }

            apply()
            @yue.on_theme_change(apply)
          },
        ),
        @yue.vbox(
          [
            @yue.hbox(
              [
                @yue.button_t(
                  "切换深浅",
                  variant=@yue.Soft,
                  on_click=fn() { app.dark_mode.update(fn(v) { !v }) },
                ),
                @yue.label("      "),
                @yue.tag("MoonShell", "#2D68C4"),
              ],
              style=[("padding", 10.0)],
              style_str=[("alignItems", "center")],
              handle=fn(c) {
                fn apply() -> Unit {
                  c.set_background_color(@yue.theme_current().bg_panel)
                }

                apply()
                @yue.on_theme_change(apply)
              },
            ),
            page("基础组件", selected, page_basic(app)),
            page("图标库", selected, page_icons(app)),
            page("表单组件", selected, page_form(app)),
            page("事件与布局", selected, page_events(app)),
            page("导航组件", selected, page_nav(app)),
            page("数据展示", selected, page_data(app)),
            page("图表", selected, page_charts(app)),
            page("代码与文档", selected, page_code(app)),
            page("反馈组件", selected, page_feedback(app)),
            page("Store 对照", selected, page_store_demo(app)),
            page("系统集成", selected, page_system(app)),
            page("窗口", selected, page_window(app)),
            page("浏览器", selected, page_browser(app)),
            page("原生控件", selected, page_native(app)),
            page("画布与富文本", selected, page_canvas(app)),
            page("环境与平台", selected, page_env(app)),
          ],
          style=[("flex", 1.0)],
          handle=fn(c) {
            fn apply() -> Unit {
              c.set_background_color(@yue.theme_current().bg_page)
            }

            apply()
            @yue.on_theme_change(apply)
          },
        ),
        // 轻提示层挂窗口根:absolute 顶部横条,不占布局
        toast_node,
        // 对话框挂窗口根:absolute 遮罩相对挂载容器,盖全窗
        @yue.dialog_t(
          app.dlg_basic,
          "删除确认",
          [
            @yue.alert_closeable("此操作不可撤销,请确认。", @yue.Warning),
            @yue.label_t("确定要删除「示例项目」吗?", role=@yue.Body),
          ],
          confirm_text="删除",
          cancel_text="取消",
          on_confirm=fn() { app.dlg_name.set("(确认删除)") },
          close_on_mask=true,
        ),
        @yue.dialog_t(
          app.dlg_form,
          "新建连接",
          [
            @yue.label_t("名称", role=@yue.Body),
            @yue.input_t(text="例如:开发库", width=320.0, on_input=fn(t) { app.dlg_name.set(t) }),
            @yue.label_t("地址", role=@yue.Body),
            @yue.input_t(text="host:port", width=320.0),
          ],
          width=380.0,
        ),
      ]),
    ],
    title="组件库演示板",
    size=Some((880.0, 720.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
    handle=fn(w) {
      app.win_ref.val = Some(w)
      // 菜单栏(原生 MenuBar):关于 + 退出 + 编辑角色项
      let bar = @yue.MenuBar::new()
      let file = bar.add_menu("文件")
      let about = file.add_label_item("关于本演示")
      about.set_accelerator("CmdOrCtrl+I")
      about.on_click(fn() {
        match app.win_ref.val {
          Some(w) => {
            let box = @yue.MessageBox::new(@yue.Information)
            box.set_title("关于")
            box.set_text("moonbit-libyue 组件库演示板")
            box.set_informative_text(
              "平台 \{@yue.platform()} ｜ 桌面 \{@yue.desktop_environment()} ｜ 区域 \{@yue.locale()}",
            )
            box.show_for_window(w)
          }
          None => ()
        }
      })
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
      let table_item = demo.add_label_item("表格(独立窗口)")
      table_item.on_click(fn() { open_table_window() })
      let traverse = demo.add_label_item("遍历本菜单结构")
      traverse.on_click(fn() {
        let mut text = "「演示」菜单共 \{demo.item_count()} 项:"
        for i in 0..<demo.item_count() {
          text = text + " [\{i}]\{demo.item_at(i).get_label()}"
        }
        app.toast_push(text, @yue.Info)
      })
      w.set_menubar(bar)
      // 关闭拦截:系统集成页勾选后,点窗口关闭被 set_should_close 拦下
      w.set_should_close(fn() {
        if app.close_veto.val {
          app.veto_info.set("关闭请求被 set_should_close 拦截(回「系统集成」页解除)")
          return false
        }
        true
      })
      // 系统托盘:Linux SNI / 其他平台原生;点击计数联动系统集成页
      if @yue.Tray::is_supported() {
        match @yue.Tray::new("examples/showcase/icon.png") {
          Ok(tray) => {
            app.tray_ref.val = Some(tray)
            tray.set_title("components")
            tray.set_tooltip("moonbit-libyue 组件库演示板", "左键计数,右键菜单")
            let menu = @yue.Menu::new()
            let show_item = menu.add_label_item("显示主窗口")
            show_item.on_click(fn() { w.activate() })
            let _ = menu.add_separator()
            let quit_item = menu.add_label_item("退出")
            quit_item.on_click(fn() { @yue.quit() })
            tray.set_menu(menu)
            tray.on_click(fn() {
              app.tray_clicks.update(fn(n) { n + 1 })
              let n = @yue.Notification::new()
              n.set_title("components")
              n.set_body("第 \{app.tray_clicks.get()} 次点击托盘图标")
              n.show()
            })
          }
          Err(_e) => ()
        }
      }
      // 窗口级键盘钩子(环境页显示;describe 输出如 Ctrl+A)
      w.on_key_down(fn(e) {
        app.key_info.set(
          "\{e.describe()}(键码 \{e.code},Esc=\{@yue.VKEY_ESCAPE} A=\{@yue.VKEY_A})",
        )
        false
      })
    },
  )
  window.activate()
  @yue.run()
}
