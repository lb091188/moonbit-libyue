// 事件与拖拽页：鼠标五事件 / 双击计数 / 鼠标捕获 / 键盘 / 全局鼠标轮询 /
// 拖出与接收。

///|
fn page_events() -> @yue.Node {
  let mouse_info : @yue.Store[String] = @yue.Store::new(
    "（移入蓝色区操作）",
  )
  let dbl_info : @yue.Store[String] = @yue.Store::new("（双击计数）")
  let cap_info : @yue.Store[String] = @yue.Store::new("未捕获")
  let global_mouse : @yue.Store[String] = @yue.Store::new(
    "（全局鼠标位置，200ms 轮询）",
  )
  let area : Ref[@yue.Container?] = Ref(None)
  let drag_src : Ref[@yue.Container?] = Ref(None)
  let tracker = @yue.ClickTracker::new()
  let drag_icon : @yue.Image? = match
    @yue.read_binary_file("examples/drag_source/drag.png") {
    Some(bytes) => {
      let img = @yue.Image::new_from_png(bytes)
      if img.is_empty() {
        None
      } else {
        Some(img)
      }
    }
    None => None
  }
  let _poll = @yue.set_timer(200, fn() {
    let (mx, my) = @yue.mouse_location()
    let mut mods = ""
    if @yue.shift_pressed() {
      mods = mods + "Shift "
    }
    if @yue.control_pressed() {
      mods = mods + "Ctrl "
    }
    if @yue.alt_pressed() {
      mods = mods + "Alt "
    }
    global_mouse.set(
      "全局鼠标 (\{mx.round()}, \{my.round()}) 修饰键 \{mods}",
    )
    true
  })
  scroll_page([
    section(
      "鼠标事件",
      "五个鼠标事件 + 连击计数（ClickTracker，400ms/5px GTK 惯例）。",
      [
        @yue.container(
          handle=fn(c) {
            area.val = Some(c)
            c.on_mouse_enter(fn(e) {
              mouse_info.set("enter @(\{e.view_x}, \{e.view_y})")
            })
            c.on_mouse_leave(fn(_e) { mouse_info.set("leave") })
            c.on_mouse_move(fn(e) {
              mouse_info.set("move @(\{e.view_x}, \{e.view_y}) btn=\{e.button}")
            })
            c.on_mouse_down(fn(e) {
              let clicks = tracker.feed(e)
              mouse_info.set("down btn=\{e.button} mods=\{e.modifiers}")
              if clicks >= 2 {
                dbl_info.set("双击！连击 \{clicks} 次 btn=\{e.button}")
              }
              false
            })
            c.on_mouse_up(fn(e) {
              mouse_info.set("up btn=\{e.button}")
              false
            })
          },
          style=[("height", 88.0), ("marginBottom", 8.0)],
          style_str=[("backgroundcolor", "#4A90D9")],
        ),
        @yue.bind_label(mouse_info, fn(s) { s }),
        @yue.bind_label(dbl_info, fn(s) { s }),
      ],
    ),
    section(
      "鼠标捕获",
      "set_capture 后移动/抬升都送给该控件；捕获可被其他控件夺走（on_capture_lost）。",
      [
        @yue.button("切换捕获", on_click=fn() {
          when_some(area, fn(c) {
            if c.has_capture() {
              c.release_capture()
            } else {
              c.set_capture()
            }
            cap_info.set(
              if c.has_capture() {
                "已捕获"
              } else {
                "未捕获"
              },
            )
          })
        }),
        @yue.bind_label(cap_info, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "键盘（窗口级）",
      "on_key_down 挂在主窗口；键码统一为跨平台常量表（Windows VK 码自动换算），describe() 输出如 Ctrl+A。",
      [@yue.bind_label(key_info, fn(s) { s })],
    ),
    section(
      "全局鼠标轮询",
      "mouse_location + 修饰键静态查询，200ms 定时器轮询（无需事件回调）。",
      [@yue.bind_label(global_mouse, fn(s) { s })],
    ),
    section(
      "拖拽：拖出与接收",
      "左图按住即 do_drag_file_paths 发起系统拖拽（文件路径 + 图片两种数据）；右侧色块接收文件/文本（register_dragged_types + handle_drop），拖入内容显示在下方。",
      [
        @yue.hbox(
          [
            @yue.container(
              on_draw=fn(painter) {
                match (drag_src.val, drag_icon) {
                  (Some(c), Some(img)) => {
                    let b = c.get_bounds()
                    painter.draw_image(img, 0.0, 0.0, b.width, b.height)
                  }
                  (_, _) => ()
                }
              },
              handle=fn(c) {
                drag_src.val = Some(c)
                c.on_mouse_down(fn(_e) {
                  let _ = c.do_drag_file_paths(
                    ["examples/drag_source/drag.png"],
                    drag_icon,
                  )
                  true
                })
              },
              style=[("width", 96.0), ("height", 96.0)],
            ),
            @yue.container(
              handle=fn(c) {
                c.register_dragged_types([@yue.FilePaths, @yue.Text])
                c.handle_drag_enter(fn(_info, _x, _y) {
                  drag_info.set("拖入中…")
                  @yue.DRAG_OPERATION_COPY
                })
                c.handle_drop(fn(info, _x, _y) {
                  match info.get_data(@yue.FilePaths) {
                    Some(@yue.Paths(paths)) => {
                      let sb = StringBuilder()
                      for i, p in paths {
                        if i > 0 {
                          sb.write_char('\n')
                        }
                        sb.write_string(p)
                      }
                      drag_info.set("拖入文件：\{sb.to_string()}")
                    }
                    _ =>
                      match info.get_data(@yue.Text) {
                        Some(@yue.Text(t)) =>
                          drag_info.set("拖入文本：\{t}")
                        _ => drag_info.set("拖入内容无法识别")
                      }
                  }
                  true
                })
                c.on_drag_leave(fn() { drag_info.set("拖离接收区") })
              },
              style=[("flex", 1.0), ("height", 96.0), ("marginLeft", 12.0)],
              style_str=[("backgroundcolor", "#F4F4F0")],
            ),
          ],
          style=[("marginBottom", 8.0)],
        ),
        @yue.bind_label(drag_info, fn(s) { s }),
      ],
    ),
  ])
}
