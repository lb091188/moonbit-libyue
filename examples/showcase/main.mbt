// 组件库演示板:侧边导航切换分页。目录结构:
//   ui/    共享层(App 跨页状态、scroll_page 段装配、复制回显钩子)
//   pages/ 各页内容(每页一个文件)+ 独立表格窗口
//   assets/ 图片资源(icon.png / dot.gif)
// 响应式分层演示:
//   主题五页(基础/表单/导航/数据/反馈)用 Signal 自动依赖收集;
//   「Store 对照」页保留 Store 手动接线模式,可与信号页对照;
//   原生控件页纯命令式 set;事件/系统/窗口/画布页维持 Store 手动模式。

///|
/// 窗口标题:单实例 Windows 兜底路径按标题查找首实例窗口,两个实例须一致
const SHOWCASE_TITLE : String = "组件库演示板"

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let selected : @yue.Store[String] = @yue.Store::new("基础组件")
  let (toast_node, toast_push) = @yue.toast_layer()
  // 章节「复制」按钮的回显走同一 toast 层(见 ui/section.mbt)
  @ui.code_toast.val = Some(toast_push)
  let counter = @yue.Signal::new(0)
  let app : @ui.App = {
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
    si_role: @yue.Store::new("(探测中)"),
    si_wake: @yue.Store::new("(未收到唤起)"),
  }
  // 深浅主题:启动跟随系统,系统切换时实时联动;「切换深浅」按钮手动覆盖。
  // 主色(accent)非空时改走公式派生色板,深浅切换沿用当前主色
  fn apply_theme() -> Unit {
    let dark = app.dark_mode.get()
    let accent = app.accent.get()
    if accent == "" {
      @yue.theme_apply(
        if dark {
          @yue.dark_theme()
        } else {
          @yue.default_theme()
        },
      )
    } else {
      @yue.theme_apply(@yue.theme_from_accent(accent, dark~))
    }
  }

  app.dark_mode.subscribe(fn(_v) { apply_theme() })
  app.accent.subscribe(fn(_a) { apply_theme() })
  @yue.on_system_theme_change(fn() {
    app.dark_mode.set(@yue.system_prefers_dark())
  })
  // 初始应用一次(subscribe 注册不回调):系统深浅 + 系统主色
  apply_theme()

  // 单实例:首实例持有应用专属身份并监听唤起;第二实例唤醒首实例后直接
  // 退出(不建窗口)。Windows 兜底路径按标题查找,故标题固定并登记
  match @yue.SingleInstance::acquire("org.moonbitlibyue.Showcase") {
    Ok(Some(si)) => {
      app.si_role.set("首实例:已持有 org.moonbitlibyue.Showcase")
      @yue.set_instance_window_title(SHOWCASE_TITLE)
      si.on_activate(fn(args) {
        app.si_wake.set(
          "收到唤起:参数 \{args.length()} 个 [\{args.join(" ")}]",
        )
        app.toast_push("第二实例唤起了本窗口", @yue.Info)
        match app.win_ref.val {
          Some(w) => {
            if w.is_minimized() {
              w.restore()
            }
            w.activate()
          }
          None => ()
        }
      })
    }
    Ok(None) => {
      // 已有实例且已向它发唤醒:本实例使命完成,不进消息循环
      app.si_role.set("第二实例:已唤起首实例,本实例退出")
      return
    }
    Err(e) => app.si_role.set("单实例不可用:\{e}(降级继续运行)")
  }

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
                          "基础组件", "图标库", "表单组件", "导航组件",
                          "数据展示", "图表", "反馈组件", "代码与文档",
                          "事件与布局", "Store 对照",
                        ],
                      ),
                      (
                        "原生与自绘",
                        ["原生控件", "画布与富文本"],
                      ),
                      (
                        "系统能力",
                        [
                          "系统集成", "窗口", "浏览器", "环境与平台",
                        ],
                      ),
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
            @yue.hbox(
              [
                @yue.label_t(
                  "V\{@yue.VERSION}",
                  role=@yue.Secondary,
                ),
                // 图标随状态切换:bind_node 订阅 dark_mode 信号,变化时
                // 重挂整棵子树(低频切换的正解;高频场景用 bind 文本
                // 绑定或 handle 命令式改属性)
                @yue.bind_node(app.dark_mode.signal(), fn(dark) {
                  @yue.icon_button_t(
                    if dark { @yue.Sun } else { @yue.Moon },
                    on_click=fn() { app.dark_mode.update(fn(v) { !v }) },
                    tip=if dark { "切换到浅色" } else { "切换到深色" },
                    size=22.0,
                  )
                }),
              ],
                  style=[
                    ("marginLeft",20.0),
                    ("paddingLeft", 20.0),
                    ("paddingTop", 6.0),
                    ("paddingBottom", 10.0),
                  ],

            )
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
                @yue.button_t("切换深浅", variant=@yue.Soft, on_click=fn() {
                  app.dark_mode.update(fn(v) { !v })
                }),
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
            @ui.page("基础组件", selected, @pages.page_basic(app)),
            @ui.page("图标库", selected, @pages.page_icons(app)),
            @ui.page("表单组件", selected, @pages.page_form(app)),
            @ui.page("事件与布局", selected, @pages.page_events(app)),
            @ui.page("导航组件", selected, @pages.page_nav(app)),
            @ui.page("数据展示", selected, @pages.page_data(app)),
            @ui.page("图表", selected, @pages.page_charts(app)),
            @ui.page("代码与文档", selected, @pages.page_code(app)),
            @ui.page("反馈组件", selected, @pages.page_feedback(app)),
            @ui.page("Store 对照", selected, @pages.page_store_demo(app)),
            @ui.page("系统集成", selected, @pages.page_system(app)),
            @ui.page("窗口", selected, @pages.page_window(app)),
            @ui.page("浏览器", selected, @pages.page_browser(app)),
            @ui.page("原生控件", selected, @pages.page_native(app)),
            @ui.page("画布与富文本", selected, @pages.page_canvas(app)),
            @ui.page("环境与平台", selected, @pages.page_env(app)),
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
            @yue.alert_closeable(
              "此操作不可撤销,请确认。",
              @yue.Warning,
            ),
            @yue.label_t(
              "确定要删除「示例项目」吗?",
              role=@yue.Body,
            ),
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
            @yue.input_t(text="例如:开发库", width=320.0, on_input=fn(t) {
              app.dlg_name.set(t)
            }),
            @yue.label_t("地址", role=@yue.Body),
            @yue.input_t(text="host:port", width=320.0),
          ],
          width=380.0,
        ),
      ]),
    ],
    title=SHOWCASE_TITLE,
    size=Some((1280.0, 720.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
    handle=fn(w) {
      app.win_ref.val = Some(w)
      // 演示板固定画布 1280×720,不提供拖角调整
      w.set_resizable(false)
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
      table_item.on_click(fn() { @pages.open_table_window() })
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
          app.veto_info.set(
            "关闭请求被 set_should_close 拦截(回「系统集成」页解除)",
          )
          return false
        }
        true
      })
      // 系统托盘:Linux SNI / 其他平台原生;点击计数联动系统集成页
      if @yue.Tray::is_supported() {
        match @yue.Tray::new("examples/showcase/assets/icon.png") {
          Ok(tray) => {
            app.tray_ref.val = Some(tray)
            tray.set_title("components")
            tray.set_tooltip(
              "moonbit-libyue 组件库演示板", "左键计数,右键菜单",
            )
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
