// 窗口与网页页:窗口 API/快捷键/拖放/原生菜单/Browser。Browser 句柄
// 与导航状态都是页内私有,协议注册在页构建时执行一次。

///|
fn page_window(_app : App) -> @yue.Node {
  let win = _app
  let ontop = Ref(false)
  let web_ref : Ref[@yue.Browser?] = Ref(None)
  let nav_state : @yue.Store[String] = @yue.Store::new("(导航状态)")
  let nav_events : @yue.Store[String] = @yue.Store::new("(导航回调)")
  let bind_state : @yue.Store[String] = @yue.Store::new("(raw binding)")
  // 自定义协议(Browser 段 demo:// 链接用;Windows 静默无效)
  @yue.Browser::register_protocol("demo", fn(_url) {
    Some(
      (
        "text/html",
        "<html><body style='font-family:sans-serif;background:#fff;color:#222'><h2>demo:// 自定义协议 ✓</h2><p>由 register_protocol 注册,ProtocolStringJob 应答。</p></body></html>",
      ),
    )
  })
  scroll_page([
    section(
      "窗口 API",
      "运行期操作窗口:改标题 / 最大化 / 全屏 / 置顶 / 还原尺寸。",
      [
        @yue.hbox([
          @yue.button_t("改标题", on_click=fn() {
            match win.win_ref.val {
              Some(w) => {
                w.set_title("components · 标题已改")
                win.toast_push("窗口标题已更新", @yue.Success)
              }
              None => ()
            }
          }),
          @yue.button_t("最大化/还原", on_click=fn() {
            match win.win_ref.val {
              Some(w) => {
                if w.is_maximized() {
                  w.unmaximize()
                  win.toast_push("已还原", @yue.Info)
                } else {
                  w.maximize()
                  win.toast_push("已最大化", @yue.Info)
                }
              }
              None => ()
            }
          }),
          @yue.button_t("全屏切换", on_click=fn() {
            match win.win_ref.val {
              Some(w) => {
                w.set_fullscreen(!w.is_fullscreen())
                win.toast_push("全屏状态已切换", @yue.Info)
              }
              None => ()
            }
          }),
          @yue.button_t("置顶切换", variant=@yue.Solid, on_click=fn() {
            match win.win_ref.val {
              Some(w) => {
                ontop.val = !ontop.val
                w.set_always_on_top(ontop.val)
                win.toast_push(
                  if ontop.val { "已置顶" } else { "已取消置顶" },
                  @yue.Info,
                )
              }
              None => ()
            }
          }),
          @yue.button_t("还原尺寸", on_click=fn() {
            match win.win_ref.val {
              Some(w) => {
                w.set_content_size(880.0, 720.0)
                win.toast_push("已还原 880×720", @yue.Info)
              }
              None => ()
            }
          }),
        ]),
      ],
    ),
    section(
      "全局快捷键",
      "register_global_shortcut 注册应用外生效的系统快捷键(Ctrl+Alt+C),触发弹 toast;unregister_all_global_shortcuts 注销全部。",
      [
        @yue.hbox([
          @yue.button_t("注册 Ctrl+Alt+C", on_click=fn() {
            ignore(
              @yue.register_global_shortcut("Ctrl+Alt+C", fn() {
                win.toast_push("全局快捷键触发!", @yue.Success)
              }),
            )
            win.toast_push("已注册,切到别的窗口按 Ctrl+Alt+C 试试", @yue.Info)
          }),
          @yue.button_t("注销全部", on_click=fn() {
            @yue.unregister_all_global_shortcuts()
            win.toast_push("全局快捷键已清空", @yue.Warning)
          }),
        ]),
      ],
    ),
    section(
      "拖放接收",
      "register_dragged_types 注册接收文件/文本,从文件管理器拖入下方色块。",
      [
        @yue.vbox(
          [
            @yue.label_t("把文件拖进来", role=@yue.Body, handle=fn(_l) {  }),
          ],
          style=[("height", 70.0), ("width", 420.0), ("padding", 10.0)],
          handle=fn(c) {
            @yue.theme_bind_bg(c, fn() { @yue.theme_current().primary_light })
            c.register_dragged_types([@yue.FilePaths, @yue.Text, @yue.Image])
            c.handle_drag_enter(fn(_info, _x, _y) { @yue.DRAG_OPERATION_COPY })
            // drag-motion 每次移动都按 update 返回值决定接收与否,
            // 不注册则一律拒绝(光标禁止,drop 永不发生)
            c.handle_drag_update(fn(_info, _x, _y) { @yue.DRAG_OPERATION_COPY })
            c.handle_drop(fn(info, _x, _y) {
              match info.get_data(@yue.Image) {
                Some(@yue.Img(_)) => win.toast_push("拖入图片", @yue.Success)
                _ =>
                  match info.get_data(@yue.FilePaths) {
                    Some(@yue.Paths(paths)) => {
                      let sb = StringBuilder()
                      for i, p in paths {
                        if i > 0 {
                          sb.write_string("、")
                        }
                        sb.write_string(p)
                      }
                      win.toast_push("拖入 \{paths.length()} 个文件", @yue.Success)
                    }
                    _ => win.toast_push("拖入文本", @yue.Info)
                  }
              }
              true
            })
          },
        ),
      ],
    ),
    section(
      "原生右键菜单",
      "Menu::new + popup_at 原生菜单(区别于基础页主题化的 context_menu_for)。",
      [
        @yue.context_menu_for(
          @yue.tag("右键我(原生菜单)", "#2D68C4"),
          [
            ("原生菜单项 A", fn() { win.toast_push("原生菜单 A", @yue.Info) }),
            ("-", fn() {  }),
            ("原生菜单项 B", fn() { win.toast_push("原生菜单 B", @yue.Info) }),
          ],
        ),
      ],
    ),
    section(
      "拖出发起",
      "do_drag_file_paths 发起系统拖拽:按住下方色块拖到文件管理器即拖出 icon.png。",
      [
        @yue.vbox(
          [@yue.label_t("按住我拖出去", role=@yue.Body)],
          style=[("height", 60.0), ("width", 200.0), ("padding", 10.0)],
          handle=fn(c) {
            @yue.theme_bind_bg(c, fn() { @yue.theme_current().primary_light })
            let img : @yue.Image? = match @yue.read_binary_file("examples/showcase/icon.png") {
              Some(bytes) => {
                let i = @yue.Image::new_from_png(bytes)
                if i.is_empty() { None } else { Some(i) }
              }
              None => None
            }
            c.on_mouse_down(fn(_e) {
              ignore(c.do_drag_file_paths(["examples/showcase/icon.png"], img))
              true
            })
          },
        ),
      ],
    ),
    section(
      "内嵌网页",
      "Browser(WebView):load_html 本地页 / load_url 加载站点 / demo:// 自定义协议(Windows 静默无效)/ 执行 JS 异步取回结果 / 导航与加载回调 / JS↔原生 raw binding。",
      [
        @yue.hbox([
          @yue.button_t("加载 demo:// 协议", on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.load_url("demo://hello")
                nav_state.set("加载 demo://hello")
              }
              None => ()
            }
          }),
          @yue.button_t("加载本地 HTML", on_click=fn() {
            match web_ref.val {
              Some(b) => {
                b.load_html(
                  "<html><body style='font-family:sans-serif'><h3>load_html 本地片段</h3><button onclick=\"demoBinding('来自网页的调用')\">JS 调原生绑定</button><p id=r></p><script>function demoBinding(s){document.getElementById('r').textContent='已调用: '+s}</script></body></html>",
                )
                nav_state.set("load_html 完成")
              }
              None => ()
            }
          }),
          @yue.button_t("JS 取结果", variant=@yue.Solid, on_click=fn() {
            match web_ref.val {
              Some(b) =>
                b.execute_javascript_with_result(
                  "1 + 41",
                  fn(ok, json) {
                    nav_state.set(
                      if ok { "JS 结果:\{json}(get_title=\{b.get_title()})" } else { "JS 执行失败" },
                    )
                  },
                )
              None => ()
            }
          }),
        ]),
        @yue.hbox(
          [
            @yue.button_t("← 后退", on_click=fn() {
              match web_ref.val {
                Some(b) => b.go_back()
                None => ()
              }
            }),
            @yue.button_t("前进 →", on_click=fn() {
              match web_ref.val {
                Some(b) => b.go_forward()
                None => ()
              }
            }),
            @yue.button_t("刷新", on_click=fn() {
              match web_ref.val {
                Some(b) => b.reload()
                None => ()
              }
            }),
            @yue.button_t("停止", on_click=fn() {
              match web_ref.val {
                Some(b) => b.stop()
                None => ()
              }
            }),
            @yue.button_t(
              "导航能力",
              variant=@yue.Soft,
              on_click=fn() {
                match web_ref.val {
                  Some(b) =>
                    nav_state.set(
                      "可后退=\{b.can_go_back()} 可前进=\{b.can_go_forward()} 加载中=\{b.is_loading()} url=\{b.get_url()}",
                    )
                  None => ()
                }
              },
            ),
          ],
          style=[("marginTop", 8.0)],
        ),
        @yue.browser(handle=fn(x) {
          web_ref.val = Some(x)
          x.load_html(
            "<html><body style='font-family:sans-serif;background:#fff;color:#222;display:flex;align-items:center;justify-content:center;height:100%'><h3>WebView 内嵌页 ✓</h3></body></html>",
          )
          // 导航/加载四回调:提交导航、完成导航、加载态、命令可用性
          x.on_commit_navigation(fn(url) {
            nav_events.set("on_commit_navigation:\{url}")
          })
          x.on_finish_navigation(fn(_url) { nav_events.set("on_finish_navigation(导航完成)") })
          x.on_change_loading(fn() { nav_events.set("on_change_loading(加载态变化)") })
          x.on_update_command(fn() { nav_events.set("on_update_command(导航命令刷新)") })
          // raw binding:网页 JS 调 demoBinding(...) 时原生侧收到 JSON 参数
          x.add_raw_binding("demoBinding", fn(json) {
            bind_state.set("收到网页调用:\{json}")
          })
        }, style=[("width", 480.0), ("height", 150.0), ("marginTop", 8.0)]),
        @yue.hbox(
          [
            @yue.button_t("移除绑定", variant=@yue.Danger, on_click=fn() {
              match web_ref.val {
                Some(b) => {
                  b.remove_binding("demoBinding")
                  bind_state.set(
                    if b.has_bindings() { "仍有其他绑定" } else { "绑定已全部移除" },
                  )
                }
                None => ()
              }
            }),
            @yue.bind_label(bind_state, fn(s) { s }, style=[("marginLeft", 10.0)]),
          ],
          style=[("marginTop", 8.0)],
        ),
        @yue.bind_label(nav_state, fn(s) { s }, style=[("marginTop", 8.0)]),
        @yue.bind_label(nav_events, fn(s) { s }),
      ],
    ),
  ])
}
