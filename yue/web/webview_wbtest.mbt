// yue/web 的无头回归：探测与构造的一致性、矩形同步的取整与去重规则。
// 真页面渲染与两种摆法由 examples/native-web 冒烟 + 使用者目视负责（AGENTS 规则 6）。

///|
/// 假宿主：窗口句柄取 900 这类越界值，桩里所有 wm_*/wb_* 对越界句柄早退，
/// 于是「构造 + 未挂载状态」可以完全不碰平台。
fn fake_app() -> @core.App {
  let w : @win.Window = { id: 900L, width: 10, height: 10 }
  let root = @core.Widget::new()
  {
    window: w,
    sched: @core.Loop::new(),
    root,
    focus: @core.FocusStack::new(),
    host: @core.make_overlay_host(root),
    wid: 1,
    primary: true,
    closed: false,
    dirty: false,
    running: true,
    last_preedit: ("", 0),
    ime_focus: 0,
    hover_id: -1,
    capture: -1,
    cursor_kind: 0,
  }
}

///|
test "矩形键取整：四舍五入而非截断，负坐标同口径" {
  assert_eq(webview_rect_key((10.4, 20.6, 300.5, 200.2)), (10, 21, 301, 200))
  assert_eq(webview_rect_key((-1.6, -0.4, 100.0, 50.0)), (-2, 0, 100, 50))
  // 亚像素漂移不该被当成「矩形变了」——否则每帧多走一遍 FFI 与一次原生重排
  assert_eq(
    webview_rect_key((0.0, 0.0, 800.0, 600.0)),
    webview_rect_key((0.4, 0.4, 800.4, 600.4)),
  )
}

///|
test "探测与构造一致：supported 决定 webview_new 给不给对象" {
  let app = fake_app()
  match webview_new(app, "about:blank") {
    None => assert_eq(webview_supported(), false)
    Some(v) => {
      assert_eq(webview_supported(), true)
      // 还没拿到真实矩形 = 还没挂载：不该有任何页面态
      assert_eq(v.is_loading(), false)
      assert_eq(v.current_url(), "")
      assert_eq(v.get_title(), "")
      // 没挂过就 close 必须安全（幂等），且状态仍是「没挂过」
      v.close()
      assert_eq(v.is_loading(), false)
    }
  }
}
