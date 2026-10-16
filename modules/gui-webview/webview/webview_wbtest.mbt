// web 的无头回归：探测与构造的一致性、矩形同步的取整与去重规则。
// 真页面渲染与两种摆法由 modules/gui-examples/native-web 冒烟 + 使用者目视负责（AGENTS 规则 6）。

///|
/// 假宿主：窗口句柄取越界值（桩里所有 wm_*/wb_* 对越界句柄早退），
/// 经 `@core.test_app(@core.fake_session(..))` 通道构造（App 字段已不对外）。
fn fake_app() -> @core.App {
  @core.test_app(@core.fake_session(900, 1, true, 10, 10))
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

///|
test "未挂载时所有调用都是安全的空操作" {
  let v = match webview_open(fake_app(), webview_options("https://e.x/")) {
    None => return
    Some(x) => x
  }
  let log : Array[String] = []
  v.on_event = Some(fn(e : WebEvent) -> Unit {
    match e {
      TitleChanged(t) => log.push("title:" + t)
      CloseRequested => log.push("close")
      Unknown(k, _) => log.push("unknown:" + k.to_string())
      _ => log.push("other")
    }
  })
  v.load_url("https://e.x/b")
  v.reload()
  v.stop()
  v.go_back()
  v.go_forward()
  v.set_user_agent("UA/1")
  v.set_new_window_policy(true)
  v.set_permission_mode(true)
  v.set_download_mode(false)
  v.set_visible(false)
  v.get_cookies_for_url("https://e.x/")
  v.execute_javascript("1+1")
  assert_eq(v.can_go_back(), false)
  assert_eq(v.can_go_forward(), false)
  assert_eq(v.is_crashed(), false)
  assert_eq(v.has_bindings(), false)
  // 需要句柄的三条在未挂载时一律给 false / -1，而不是崩
  assert_eq(v.add_user_script("x"), false)
  assert_eq(v.add_raw_binding("native_echo"), false)
  assert_eq(v.capture_dom(PageText, fn(_s : DomSnapshot) -> Unit { () }), false)
  assert_eq(v.execute_javascript_with_result("1", fn(_r : String) -> Unit { () }), -1L)
  // 地址是记下来的（挂载时才交给引擎）
  assert_eq(v.url, "https://e.x/b")
  assert_eq(log.length(), 0)
}

///|
test "事件分派：kind 映射逐条对上，JS 回包按序号配对后出队" {
  let v = match webview_new(fake_app(), "about:blank") {
    None => return
    Some(x) => x
  }
  let log : Array[String] = []
  v.on_event = Some(fn(e : WebEvent) -> Unit {
    match e {
      TitleChanged(t) => log.push("title:" + t)
      NavFinished(t) => log.push("finish:" + t)
      UrlChanged(t) => log.push("url:" + t)
      NavStarted(t) => log.push("start:" + t)
      NavCommitted(t) => log.push("commit:" + t)
      NavRedirected(t) => log.push("redirect:" + t)
      LoadFailed(t) => log.push("fail:" + t)
      Permission(t) => log.push("perm:" + t)
      Download(t) => log.push("dl:" + t)
      NewWindow(t) => log.push("win:" + t)
      Cookies(t) => log.push("cookies:" + t)
      ProcessTerminated(t) => log.push("crash:" + t)
      CloseRequested => log.push("close")
      Unknown(k, t) => log.push("unknown:" + k.to_string() + ":" + t)
      _ => log.push("other")
    }
  })
  v.dispatch(1, 0L, "标题")
  v.dispatch(5, 0L, "https://e.x/")
  v.dispatch(2, 0L, "https://e.x/")
  v.dispatch(3, 0L, "https://e.x/")
  v.dispatch(4, 0L, "https://e.x/")
  v.dispatch(15, 0L, "https://e.x/2")
  v.dispatch(14, 0L, "https://e.x/2|WebKitNetworkError|-1|boom")
  v.dispatch(9, 0L, "GeolocationPermissionRequest")
  v.dispatch(10, 0L, "https://e.x/f.zip")
  v.dispatch(8, 0L, "https://e.x/open")
  v.dispatch(13, 0L, "[]")
  v.dispatch(11, 0L, "reason=1")
  v.dispatch(12, 0L, "")
  v.dispatch(77, 0L, "x")
  assert_eq(
    log,
    [
      "title:标题",
      "finish:https://e.x/",
      "url:https://e.x/",
      "start:https://e.x/",
      "commit:https://e.x/",
      "redirect:https://e.x/2",
      "fail:https://e.x/2|WebKitNetworkError|-1|boom",
      "perm:GeolocationPermissionRequest",
      "dl:https://e.x/f.zip",
      "win:https://e.x/open",
      "cookies:[]",
      "crash:reason=1",
      "close",
      "unknown:77:x",
    ],
  )
  // JS 回包：命中等待者就回调一次并出队，没命中只当事件走旁路
  let got : Array[String] = []
  v.eval_waiters.push((4L, fn(r : String) -> Unit { got.push("4:" + r) }))
  v.dispatch(7, 4L, "hello")
  v.dispatch(7, 4L, "again")
  assert_eq(got, ["4:hello"])
  assert_eq(v.eval_waiters.length(), 0)
}

///|
test "invoke 通道：页面载荷直达 on_invoke，旁路也看得到" {
  let v = match webview_new(fake_app(), "about:blank") {
    None => return
    Some(x) => x
  }
  let hits : Array[String] = []
  let seen : Array[Int] = []
  v.on_invoke = Some(fn(p : String) -> Unit { hits.push(p) })
  v.on_event = Some(fn(_e : WebEvent) -> Unit { seen.push(1) })
  v.dispatch(6, 0L, "{\"msg\":\"hi\"}")
  v.dispatch(6, 0L, "第二段")
  assert_eq(hits, ["{\"msg\":\"hi\"}", "第二段"])
  assert_eq(seen.length(), 2)
}

///|
test "持久化探测与信号掩码：不可用引擎不会谎报可持久" {
  match browser_profile_persistence() {
    Persistent => assert_eq(webview_supported(), true)
    EphemeralOnly => ()
  }
  assert_true(webview_signal_mask() >= 0)
}

///|
/// 窗口被宿主拆掉时没人来调 `close`：泵下一拍必须自己收口（停泵、句柄作废、
/// 丢掉等回包的求值），而不是继续拿这个句柄去查引擎。
test "视图没了就地收口：句柄作废、泵停、待回求值丢掉" {
  let v = match webview_open(fake_app(), webview_options("about:blank")) {
    None => return
    Some(x) => x
  }
  // 摆成「曾经挂上过」：句柄非零、泵在跑、还压着一条等回包的求值。
  // 900 号窗越界，桩里建不出真视图，所以这个句柄对应的视图本来就「不在」
  v.handle = 9L
  v.pumping = true
  v.eval_waiters.push((1L, fn(_r : String) -> Unit { () }))
  assert_eq(v.is_alive(), false)
  assert_eq(v.retire_if_dead(), true)
  assert_eq(v.handle, 0L)
  assert_eq(v.pumping, false)
  assert_eq(v.eval_waiters.length(), 0)
  // 收口之后泵那一拍直接返回，不会再排下一次定时器，也不会去碰引擎
  v.pump()
}
