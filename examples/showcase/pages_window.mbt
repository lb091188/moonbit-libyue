// 窗口与网页页:窗口 API/快捷键/拖放/原生菜单/Browser。Browser 句柄
// 与导航状态都是页内私有,协议注册在页构建时执行一次。

///|
fn page_window(_app : App) -> @yue.Node {
  let win = _app
  let ontop = Ref(false)
  // WebView 全能力演示迁至独立「浏览器」页(见 pages_browser.mbt)
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
  ])
}
