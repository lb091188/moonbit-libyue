// examples/native-web —— webview 与媒体的**累积**验证示例（批 B 起建，同族不另开页）。
//
// 跑法：`moon run examples/native-web`（需显示服务）。20 秒后自动退出并打印
// `NATIVE-WEB-STAT` / `NATIVE-WEB-GEO` 两行，字段与屏上读数一一对应。
//
// 本批验的是**两种摆法同源**：整页（Tauri-like，单 pane 铺满）与左右分栏（原生
// 工具栏/侧栏 + 页面区）。页面区是窗口层的原生子件，不吃 `clip_rect`、恒覆盖在
// 自绘像素之上；两侧不重叠由布局保证。引擎不在位时（缺 webkit2gtk-4.1 或别的
// 平台）走**探测 + 降级**：画一块自绘面板说清原因，不静默。

///|
fn rect_str(r : @core.Rect) -> String {
  "\{r.x.round().to_int()},\{r.y.round().to_int()},\{r.w.round().to_int()}x\{r.h.round().to_int()}"
}

///|
fn main {
  let app = match @core.App::new(1100, 700, "MoonBit Webview (批 B)") {
    Some(a) => a
    None => {
      println("NATIVE-WEB-SKIP: 本平台无窗口后端或没有显示服务")
      return
    }
  }
  let root = app.root
  root.set_column()
  root.set_padding(12.0, 10.0)
  root.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
    p.set_fill_color(@theme.theme_bg_page())
    p.fill_rect(0.0, 0.0, r.w, r.h)
  })
  let supported = @web.webview_supported()
  let wv = if supported { @web.webview_new(app, "https://example.com/") } else { None }
  let addr = @core.Store::new("https://example.com/")
  let loads = Ref(0)
  let clicks = Ref(0)
  let mode_full = Ref(false)
  let sidebar_w : Ref[@core.Widget?] = Ref(None)
  let pane_w : Ref[@core.Widget?] = Ref(None)
  let _ = app.focus.register(31)

  // 顶部工具条（原生区）：地址 + 载入/重载/停止 + 摆法切换
  app.mount([
    @ui.label("webview pane（批 B）：一窗多区，每区一个 owner", size=15.0),
    @ui.container(
      [
        @ui.entry(addr, placeholder="地址", focus_id=31, width=420.0),
        @ui.button(
          "载入",
          on_click=fn() {
            match wv {
              Some(v) => {
                v.load_url(addr.get())
                loads.val = loads.val + 1
              }
              None => ()
            }
          },
          min_width=76.0,
        ),
        @ui.button(
          "重载",
          on_click=fn() {
            match wv {
              Some(v) => v.reload()
              None => ()
            }
          },
          min_width=76.0,
        ),
        @ui.button(
          "停止",
          on_click=fn() {
            match wv {
              Some(v) => v.stop()
              None => ()
            }
          },
          min_width=76.0,
        ),
        @ui.button(
          "整页 / 分栏",
          on_click=fn() {
            clicks.val = clicks.val + 1
            mode_full.val = !mode_full.val
            match sidebar_w.val {
              Some(w) => w.set_visible(!mode_full.val)
              None => ()
            }
          },
          min_width=120.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=8.0,
      padding=6.0,
      bg=@theme.theme_bg_panel(),
      border=@theme.theme_border(),
      align_items=@yoga.AlignItems::Center,
    ),
  ])

  match wv {
    None => {
      // 探测不到引擎：自绘一块说明板（降级不静默）
      app.mount([
        @ui.container(
          [
            @ui.label("webview 引擎不在位", size=14.0),
            @ui.label(
              "本机缺 webkit2gtk-4.1（或非 Linux 平台）。pane 通道本身可用，" +
                "页面区改画自绘内容；装上引擎后本页自动走 webview 分支。",
              size=12.0,
            ),
          ],
          padding=12.0,
          grow=1.0,
          bg=@theme.theme_bg_panel(),
          border=@theme.theme_border(),
        ),
      ])
    }
    Some(v) => {
      app.mount([
        @ui.container(
          [
            @ui.container(
              [
                @ui.label("原生侧栏", size=13.0),
                @ui.label("owner = 自绘 Painter", size=12.0),
                @ui.label("这一侧的矩形与页面区不重叠", size=12.0),
              ],
              width=240.0,
              padding=10.0,
              row_gap=6.0,
              bg=@theme.theme_bg_page(),
              border=@theme.theme_border(),
              handle=fn(w : @core.Widget) -> Unit { sidebar_w.val = Some(w) },
            ),
            @ui.container(
              [v.node(grow=1.0)],
              grow=1.0,
              padding=0.0,
              bg=@theme.theme_bg_panel(),
              border=@theme.theme_border(),
              handle=fn(w : @core.Widget) -> Unit { pane_w.val = Some(w) },
            ),
          ],
          direction=@yoga.Row,
          column_gap=10.0,
          grow=1.0,
        ),
      ])
    }
  }

  // 状态行：每帧现读（页面标题/地址/是否还在加载 + 两个计数）
  let status = @core.Widget::new()
  status.node.set_height(@yoga.fixed(24.0))
  status.on_draw = Some(fn(
    _w : @core.Widget,
    p : @render.Painter,
    _r : @core.Rect,
  ) -> Unit {
    p.flush()
    let line = match wv {
      None => "supported=0"
      Some(v) =>
        "supported=1 loading=" +
        (if v.is_loading() { "1" } else { "0" }) +
        " title='" +
        v.get_title() +
        "' url='" +
        v.current_url() +
        "'"
    }
    let _ = @text.draw_text_at(
      p,
      0.0,
      0.0,
      line +
        " loads=" +
        loads.val.to_string() +
        " toggles=" +
        clicks.val.to_string() +
        " mode=" +
        (if mode_full.val { "整页" } else { "分栏" }),
      13.0,
      @theme.theme_text_primary(),
    )
  })
  root.append_child(status)

  let ticker : Ref[() -> Unit] = Ref(fn() { () })
  ticker.val = fn() -> Unit {
    if app.is_running() {
      app.schedule_paint()
      let _ = app.timer(120, ticker.val)
    }
  }
  let _ = app.timer(120, ticker.val)
  let _ = app.timer(20000, fn() { app.quit() })
  app.run()

  let pane_rect = match pane_w.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let side_rect = match sidebar_w.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let (loading, title, url) = match wv {
    None => (false, "", "")
    Some(v) => (v.is_loading(), v.get_title(), v.current_url())
  }
  match wv {
    Some(v) => v.close()
    None => ()
  }
  println(
    "NATIVE-WEB-STAT supported=" +
      (if supported { "1" } else { "0" }) +
      " loads=" +
      loads.val.to_string() +
      " toggles=" +
      clicks.val.to_string() +
      " mode=" +
      (if mode_full.val { "full" } else { "split" }) +
      " loading=" +
      (if loading { "1" } else { "0" }) +
      " title='" +
      title +
      "' url='" +
      url +
      "'",
  )
  println("NATIVE-WEB-GEO pane=" + pane_rect + " sidebar=" + side_rect)
  app.shutdown()
}
