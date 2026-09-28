// 窗口与网页页:窗口 API/快捷键/拖放/Browser。Browser 句柄
// 与导航状态都是页内私有,协议注册在页构建时执行一次。

///|
pub fn page_window(_app : @ui.App) -> @yue.Node {
  let win = _app
  let ontop = Ref(false)
  // WebView 全能力演示迁至独立「浏览器」页(见 pages_browser.mbt)
  @ui.page([
    @ui.section(
      "窗口",
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
              Some(w) =>
                if w.is_maximized() {
                  w.unmaximize()
                  win.toast_push("已还原", @yue.Info)
                } else {
                  w.maximize()
                  win.toast_push("已最大化", @yue.Info)
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
                  if ontop.val {
                    "已置顶"
                  } else {
                    "已取消置顶"
                  },
                  @yue.Info,
                )
              }
              None => ()
            }
          }),
          @yue.button_t("还原尺寸", on_click=fn() {
            match win.win_ref.val {
              Some(w) => {
                w.set_content_size(1280.0, 720.0)
                win.toast_push("已还原 1280×720", @yue.Info)
              }
              None => ()
            }
          }),
        ]),
      ],
      code=[
        "// w : @yue.Window 窗口句柄,来自 mount_window(..., handle=fn(w)) 回调",
        "// set_title(标题):设置窗口标题",
        "w.set_title(\"components · 标题已改\")",
        "// is_maximized():查询当前是否已最大化",
        "if w.is_maximized() {",
        "// unmaximize():取消最大化",
        "  w.unmaximize()",
        "} else {",
        "// maximize():最大化窗口",
        "  w.maximize()",
        "}",
        "// is_fullscreen():查询当前是否全屏,取反即切换",
        "// set_fullscreen(Bool):true 进入 / false 退出全屏",
        "w.set_fullscreen(!w.is_fullscreen())",
        "// set_always_on_top(Bool):true 置顶窗口,false 取消置顶",
        "w.set_always_on_top(true)",
        "// set_content_size(宽, 高):设置内容区尺寸(逻辑像素)",
        "w.set_content_size(1280.0, 720.0)",
        "// activate():激活窗口并获得焦点",
        "w.activate()",
      ],
    ),
    @ui.section(
      "快捷键",
      "全局快捷键",
      "应用外生效的系统快捷键(Ctrl+Alt+C)。",
      [
        @yue.hbox([
          @yue.button_t("注册 Ctrl+Alt+C", on_click=fn() {
            ignore(
              @yue.register_global_shortcut("Ctrl+Alt+C", fn() {
                win.toast_push("全局快捷键触发!", @yue.Success)
              }),
            )
            win.toast_push(
              "已注册,切到别的窗口按 Ctrl+Alt+C 试试",
              @yue.Info,
            )
          }),
          @yue.button_t("注销全部", on_click=fn() {
            @yue.unregister_all_global_shortcuts()
            win.toast_push("全局快捷键已清空", @yue.Warning)
          }),
        ]),
      ],
      code=[
        "// 应用外生效的系统快捷键",
        "// register_global_shortcut(组合键, 回调):注册系统级快捷键,返回注册 id",
        "// 组合键格式如 \"CmdOrCtrl+Shift+M\";返回 -1 表示注册失败",
        "// (X11 下组合键被系统或桌面环境占用即失败,需换键)",
        "ignore(@yue.register_global_shortcut(\"Ctrl+Alt+C\", fn() {",
        "  println(\"触发!\")",
        "}))",
        "// unregister_all_global_shortcuts():注销全部全局快捷键",
        "// (单个注销用 unregister_global_shortcut(id))",
        "@yue.unregister_all_global_shortcuts()",
      ],
    ),
    @ui.section(
      "拖入",
      "拖放接收",
      "register_dragged_types 注册接收文件/文本,从文件管理器拖入下方色块。",
      [
        @yue.vbox(
          [
            @yue.label_t("把文件拖进来", role=@yue.Body, handle=fn(_l) {

            }),
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
                Some(@yue.Img(_)) =>
                  win.toast_push("拖入图片", @yue.Success)
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
                      win.toast_push(
                        "拖入 \{paths.length()} 个文件",
                        @yue.Success,
                      )
                    }
                    _ => win.toast_push("拖入文本", @yue.Info)
                  }
              }
              true
            })
          },
        ),
      ],
      code=[
        "// c 为接收区视图句柄(vbox 的 handle 回调参数);先注册类型,再挂三个处理器",
        "// register_dragged_types(种类数组):声明可接收的拖拽数据种类",
        "// DataKind 共四种:Text / Html / Image / FilePaths",
        "c.register_dragged_types([@yue.FilePaths, @yue.Text, @yue.Image])",
        "// 拖拽进入:回调(拖拽信息, 位置x, 位置y),返回 DRAG_OPERATION_* 操作位",
        "// 声明愿意接受的操作(COPY=复制);是否真接收由下条 drag-update 决定",
        "c.handle_drag_enter(fn(_info, _x, _y) { @yue.DRAG_OPERATION_COPY })",
        "// drag-update 每次移动都按返回值决定接收与否(返回 0 拒绝);",
        "// 不注册则一律拒绝(光标显示禁止,drop 永不发生)",
        "c.handle_drag_update(fn(_info, _x, _y) { @yue.DRAG_OPERATION_COPY })",
        "// 拖放落下:回调(拖拽信息, x, y),返回 true 表示已处理",
        "// (否则平台按默认行为继续冒泡/回滚)",
        "c.handle_drop(fn(info, _x, _y) {",
        "// get_data(种类) 读指定种类数据(仅在拖拽回调内有效),返回 DragData?:",
        "// Text(String) / Paths(路径数组) / Img(Image)",
        "  match info.get_data(@yue.FilePaths) {",
        "    Some(@yue.Paths(paths)) => println(\"拖入 \\{paths.length()} 个文件\")",
        "    _ => ()", "  }", "  true", "})",
      ],
    ),
    @ui.section(
      "拖出",
      "拖出发起",
      "do_drag_file_paths 发起系统拖拽:按住下方色块拖到文件管理器即拖出 icon.png。",
      [
        @yue.vbox(
          [@yue.label_t("按住我拖出去", role=@yue.Body)],
          style=[("height", 60.0), ("width", 200.0), ("padding", 10.0)],
          handle=fn(c) {
            @yue.theme_bind_bg(c, fn() { @yue.theme_current().primary_light })
            let img : @yue.Image? = match
              @yue.read_binary_file("examples/showcase/assets/icon.png") {
              Some(bytes) => {
                let i = @yue.Image::new_from_png(bytes)
                if i.is_empty() {
                  None
                } else {
                  Some(i)
                }
              }
              None => None
            }
            c.on_mouse_down(fn(_e) {
              ignore(c.do_drag_file_paths(["examples/showcase/assets/icon.png"], img))
              true
            })
          },
        ),
      ],
      code=[
        "// do_drag_file_paths(文件路径数组, 跟随图 Image?):发起系统拖拽,拖出文件",
        "// (跟随图传 None 则不带拖动跟随图;返回 Int,演示中 ignore 丢弃)",
        "// read_binary_file(路径):读二进制文件,成功返回字节,失败返回 None",
        "let img : @yue.Image? = match @yue.read_binary_file(\"icon.png\") {",
        "// Image::new_from_png(字节, scale 默认 1.0):从内存解码图片(支持 PNG/JPEG)",
        "  Some(bytes) => Some(@yue.Image::new_from_png(bytes))",
        "  None => None",
        "}",
        "// 鼠标按下时发起拖拽;回调返回 true 表示事件已处理",
        "c.on_mouse_down(fn(_e) {",
        "  ignore(c.do_drag_file_paths([\"icon.png\"], img))",
        "  true",
        "})",
      ],
    ),
  ])
}
