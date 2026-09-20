// 事件与布局页:事件信号 × yoga 布局模型。维持 Store 手动模式——
// 事件回显是「事件 → 文本」直写,手动接线即最直白表达。

///|
fn page_events(_app : App) -> @yue.Node {
  let evt_mouse : @yue.Store[String] = @yue.Store::new("(移入色块区操作)")
  let evt_dbl : @yue.Store[String] = @yue.Store::new("(双击计数)")
  let evt_cap : @yue.Store[String] = @yue.Store::new("未捕获")
  let evt_area : Ref[@yue.Container?] = Ref(None)
  let evt_clicks = @yue.ClickTracker::new()
  let evt_gmouse : @yue.Store[String] = @yue.Store::new("(全局鼠标,200ms 轮询)")
  ignore(
    @yue.set_timer(200, fn() {
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
      evt_gmouse.set("全局鼠标 (\{mx.round()}, \{my.round()}) 修饰键 \{mods}")
      true
    }),
  )
  let cursor_area : Ref[@yue.Container?] = Ref(None)
  let cursor_now : @yue.Store[String] = @yue.Store::new("Default")
  let apply_cursor = fn(t : @yue.CursorType, name : String) -> Unit {
    match cursor_area.val {
      Some(c) => {
        @yue.View::set_cursor(c, @yue.Cursor::new(t))
        cursor_now.set(name)
      }
      None => ()
    }
  }
  scroll_page([
    section(
      "鼠标事件",
      "五鼠标事件 + 连击计数;事件带视图/屏幕坐标、按键、修饰键。",
      [
        @yue.vbox(
          [@yue.label_t("鼠标操作区", role=@yue.Body)],
          style=[("height", 88.0), ("marginBottom", 8.0)],
          handle=fn(c) {
            evt_area.val = Some(c)
            c.on_mouse_enter(fn(e) { evt_mouse.set("enter (\{e.view_x}, \{e.view_y})") })
            c.on_mouse_leave(fn(_e) { evt_mouse.set("leave") })
            c.on_mouse_move(fn(e) {
              evt_mouse.set("move (\{e.view_x}, \{e.view_y}) btn=\{e.button}")
            })
            c.on_mouse_down(fn(e) {
              let clicks = evt_clicks.feed(e)
              evt_mouse.set("down btn=\{e.button} mods=\{e.modifiers}")
              if clicks >= 2 {
                evt_dbl.set("双击!连击 \{clicks} 次 btn=\{e.button}")
              }
              false
            })
            c.on_mouse_up(fn(e) {
              evt_mouse.set("up btn=\{e.button}")
              false
            })
          },
        ),
        @yue.bind_label(evt_mouse, fn(s) { s }),
        @yue.bind_label(evt_dbl, fn(s) { s }),
      ],
    ),
    section(
      "鼠标捕获",
      "set_capture 后移动/抬升都送给该控件;捕获可被其他控件夺走(on_capture_lost)。",
      [
        @yue.hbox([
          @yue.button_t("切换捕获", on_click=fn() {
            match evt_area.val {
              Some(c) => {
                if c.has_capture() {
                  c.release_capture()
                } else {
                  c.set_capture()
                }
                evt_cap.set(if c.has_capture() { "已捕获" } else { "未捕获" })
              }
              None => ()
            }
          }),
          @yue.bind_label(evt_cap, fn(s) { s }, style=[("marginLeft", 10.0)]),
        ]),
      ],
    ),
    section(
      "全局鼠标轮询",
      "mouse_location + 修饰键查询,200ms 轮询。",
      [@yue.bind_label(evt_gmouse, fn(s) { s })],
    ),
    section(
      "光标 Cursor",
      "View::set_cursor 切换悬停光标——把鼠标移到下方色块上再点按钮。",
      [
        @yue.vbox(
          [@yue.label_t("光标预览区", role=@yue.Body)],
          style=[("height", 48.0), ("marginBottom", 8.0)],
          handle=fn(c) {
            cursor_area.val = Some(c)
            @yue.theme_bind_bg(c, fn() { @yue.theme_current().primary })
          },
        ),
        @yue.hbox([
          @yue.button_t("手型", on_click=fn() { apply_cursor(@yue.Hand, "Hand") }),
          @yue.button_t("文本", on_click=fn() { apply_cursor(@yue.Text, "Text") }),
          @yue.button_t("十字", on_click=fn() { apply_cursor(@yue.Crosshair, "Crosshair") }),
          @yue.button_t("禁止", on_click=fn() { apply_cursor(@yue.NotAllowed, "NotAllowed") }),
          @yue.button_t("默认", on_click=fn() { apply_cursor(@yue.Default, "Default") }),
        ]),
        @yue.bind_label(cursor_now, fn(s) { "当前光标:\{s}" }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "嵌套布局",
      "固定宽/百分比/flex 三种宽度模型(全集见 docs/zh/layout.md)。",
      [
        @yue.hbox(
          [
            @yue.label_t(
              "固定 80",
              role=@yue.Body,
              style=[("width", 80.0), ("height", 40.0), ("marginRight", 8.0)],
              style_str=[("backgroundcolor", "#3A5F8A")],
            ),
            @yue.label_t(
              "50%",
              role=@yue.Body,
              style=[("height", 40.0), ("marginRight", 8.0)],
              style_str=[("width", "50%"), ("backgroundcolor", "#8A3A5F")],
            ),
            @yue.label_t(
              "flex 1",
              role=@yue.Body,
              style=[("height", 40.0)],
              style_str=[("backgroundcolor", "#5F8A3A")],
            ),
          ],
          style=[("marginBottom", 8.0)],
        ),
      ],
    ),
  ])
}
