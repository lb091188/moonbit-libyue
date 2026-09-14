// 剪贴板与系统页：剪贴板 / 主选区(仅 Linux) / 定时器 / 窗口操作 /
// 无边框透明子窗口 / 关闭拦截。

///|
fn page_system() -> @yue.Node {
  let clip_out : @yue.Store[String] = @yue.Store::new("（剪贴板内容）")
  let clip_in : Ref[@yue.Entry?] = Ref(None)
  let timer_info : @yue.Store[String] = @yue.Store::new("（定时器事件）")
  let win_info : @yue.Store[String] = @yue.Store::new("（窗口操作结果）")
  let on_top = Ref(false)
  let secs : Array[@yue.Node] = [
    section("剪贴板", "Clipboard::get() 为公共同步剪贴板；set_data 写富文本（Html）；get_text 读回。", [
      @yue.entry(text="复制我到剪贴板", handle=fn(e) { clip_in.val = Some(e) }),
      @yue.hbox(
        [
          @yue.button("写入", on_click=fn() { when_some(clip_in, fn(e) { @yue.Clipboard::get().set_text(e.get_text()) }) }),
          @yue.button("读取", on_click=fn() { clip_out.set("剪贴板：\{@yue.Clipboard::get().get_text()}") }),
          @yue.button("写 HTML", on_click=fn() { @yue.Clipboard::get().set_data(@yue.Html, "<b>showcase 富文本剪贴板</b>") }),
        ],
        style=[("marginTop", 8.0), ("marginBottom", 8.0)],
      ),
      @yue.bind_label(clip_out, fn(s) { s }),
    ]),
    section("定时器", "set_timer 周期回调（返回 false 自动停）；set_timeout 单次延时；clear_timeout 可取消。", [
      @yue.button(
        "周期 500ms × 3 + 单次 1700ms",
        on_click=fn() {
          let ticks = Ref(0)
          let _ = @yue.set_timer(500, fn() {
            ticks.val += 1
            timer_info.set("周期 tick \{ticks.val}")
            if ticks.val >= 3 {
              timer_info.set("周期定时器已自动停止")
              return false
            }
            true
          })
          let _ = @yue.set_timeout(1700, fn() { timer_info.set("单次延时 1700ms 触发") })
        },
      ),
      @yue.bind_label(timer_info, fn(s) { s }, style=[("marginTop", 8.0)]),
    ]),
    section("窗口操作", "对主窗口调 maximize / fullscreen / always_on_top / resizable 等窗口 API。", [
      @yue.hbox(
        [
          @yue.button(
            "最大化/还原",
            on_click=fn() {
              when_some(main_win, fn(w) {
                if w.is_maximized() {
                  w.unmaximize()
                  win_info.set("已还原")
                } else {
                  w.maximize()
                  win_info.set("已最大化")
                }
              })
            },
          ),
          @yue.button(
            "全屏切换",
            on_click=fn() {
              when_some(main_win, fn(w) {
                w.set_fullscreen(!w.is_fullscreen())
                win_info.set("全屏=\{!w.is_fullscreen()}")
              })
            },
          ),
          @yue.button(
            "置顶切换",
            on_click=fn() {
              on_top.val = !on_top.val
              when_some(main_win, fn(w) { w.set_always_on_top(on_top.val) })
              win_info.set("置顶=\{on_top.val}")
            },
          ),
          @yue.button(
            "还原尺寸",
            on_click=fn() {
              when_some(main_win, fn(w) {
                w.set_content_size(960.0, 640.0)
                win_info.set("已还原 960×640")
              })
            },
          ),
        ],
        style=[("marginBottom", 8.0)],
      ),
      @yue.bind_label(win_info, fn(s) { s }),
    ]),
    section("无边框透明窗口", "Window::new_with_options(frame=false, transparent=true) + always_on_top；整窗 set_mouse_down_can_move_window 可拖动。窗口无编程关闭 API（上游未暴露），随应用退出。", [
      @yue.button("打开悬浮心形窗口", on_click=fn() { open_floating_heart() }),
    ]),
    section("关闭拦截", "勾选后点窗口关闭被 set_should_close 拦下（演示期间请从菜单「文件→退出」或解除勾选退出）。", [
      @yue.checkbox(
        "开启关闭拦截",
        on_change=fn(v) {
          close_veto.val = v
          if !v {
            veto_info.set("（未开启拦截）")
          }
        },
      ),
      @yue.bind_label(veto_info, fn(s) { s }, style=[("marginTop", 8.0)]),
    ]),
  ]
  // 主选区是 X11 概念：Windows/macOS 上 from_type(Selection) 降级为公共
  // 剪贴板，整段只在 Linux 创建。
  if is_linux() {
    let sel_out : @yue.Store[String] = @yue.Store::new("（主选区读回）")
    secs.push(
      section("主选区 Selection（仅 Linux）", "X11 主选区：选中即写入、中键粘贴的那份；其他平台 from_type(Selection) 降级为公共剪贴板，故整段只在 Linux 出现。", [
        @yue.hbox(
          [
            @yue.button(
              "写入主选区",
              on_click=fn() { @yue.Clipboard::from_type(@yue.Selection).set_data(@yue.Text, "主选区内容") },
            ),
            @yue.button(
              "读回主选区",
              on_click=fn() {
                match @yue.Clipboard::from_type(@yue.Selection).get_data(@yue.Text) {
                  Some(@yue.Text(t)) => sel_out.set("主选区读回：\{t}")
                  _ => sel_out.set("主选区读回失败")
                }
              },
            ),
          ],
          style=[("marginBottom", 8.0)],
        ),
        @yue.bind_label(sel_out, fn(s) { s }),
      ]),
    )
  }
  scroll_page(secs)
}

///|
fn draw_heart(painter : @yue.Painter) -> Unit {
  painter.begin_path()
  painter.move_to(75.0, 40.0)
  painter.bezier_curve_to(75.0, 37.0, 70.0, 25.0, 50.0, 25.0)
  painter.bezier_curve_to(20.0, 25.0, 20.0, 62.5, 20.0, 62.5)
  painter.bezier_curve_to(20.0, 80.0, 40.0, 102.0, 75.0, 120.0)
  painter.bezier_curve_to(110.0, 102.0, 130.0, 80.0, 130.0, 62.5)
  painter.bezier_curve_to(130.0, 62.5, 130.0, 25.0, 100.0, 25.0)
  painter.bezier_curve_to(85.0, 25.0, 75.0, 37.0, 75.0, 40.0)
  painter.fill()
}

///|
/// 无边框透明置顶的心形小窗，整窗可拖动（floating_heart 特性并入 showcase）。
fn open_floating_heart() -> Unit {
  let win = @yue.Window::new_with_options(frame=false, transparent=true)
  win.set_always_on_top(true)
  win.set_content_size(150.0, 130.0)
  let content = @yue.Container::new()
  content.set_mouse_down_can_move_window(true)
  win.set_content(content)
  content.on_draw(fn(painter) {
    painter.set_fill_color("#3000")
    draw_heart(painter)
    painter.translate(-5.0, -5.0)
    painter.set_fill_color("#D46A6A")
    draw_heart(painter)
  })
  win.center()
  win.activate()
}
