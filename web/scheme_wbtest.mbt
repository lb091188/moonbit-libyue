// 导航失败解析与本地内容通道的无头回归。真协议回灌由 modules/gui-examples/native-web 回证。

///|
test "导航失败载荷：四段拆结构，message 里带竖线不再切坏" {
  match
    nav_error_parse("https://e.x/a|WebKitNetworkError|-4|Could not connect") {
    None => assert_eq(true, false)
    Some(e) => {
      assert_eq(e.uri, "https://e.x/a")
      assert_eq(e.domain, "WebKitNetworkError")
      assert_eq(e.code, -4)
      assert_eq(e.message, "Could not connect")
    }
  }
  // 第四段之后的竖线全归 message（错误文本里常见 URL 与分隔符）
  match nav_error_parse("u|d|7|a|b|c") {
    None => assert_eq(true, false)
    Some(e) => {
      assert_eq(e.code, 7)
      assert_eq(e.message, "a|b|c")
    }
  }
  // 段数不足 / 空载荷都不猜
  assert_eq(
    match nav_error_parse("u|d|7") {
      None => true
      Some(_) => false
    },
    true,
  )
  assert_eq(
    match nav_error_parse("") {
      None => true
      Some(_) => false
    },
    true,
  )
  // 码不是数字时按 0 处理，其余字段照拆
  match nav_error_parse("u|d|abc|msg") {
    None => assert_eq(true, false)
    Some(e) => assert_eq(e.code, 0)
  }
}

///|
/// 未挂载时的登记：受理（挂载即应用），注销能把待应用的登记撤掉；
/// 都没登记过时注销给 false——「未挂载」不等于「随便成功」。
test "未挂载时注册受理、注销可撤，双重注销 false" {
  let v = match webview_new(fake_app(), "about:blank") {
    None => return
    Some(x) => x
  }
  // 用「app」而不是随手起的名字：建视图那一刻名单已封，没声明过的名字
  // 会被门挡在注册之前（那条另有测试）
  assert_eq(v.register_protocol("app", "/tmp"), true) // 受理，等挂载应用
  assert_eq(v.unregister_protocol("app"), true) // 撤掉待应用的登记
  assert_eq(v.unregister_protocol("app"), false) // 没得撤了
}

///|
/// scheme 名单：建第一扇视图即封版；没声明的名字注册不了。
/// 这条测试不依赖执行顺序——它自己先把封版触发掉。
test "scheme 名单预声明：封版后不再接受新名字，未声明的注册被挡" {
  let v = match webview_new(fake_app(), "about:blank") {
    None => return
    Some(x) => x
  }
  // 名单为空时封版补一个缺省名，零配置也能用这条通道
  assert_true(webview_scheme_declared("app"))
  assert_true(webview_declared_schemes().length() >= 1)
  assert_false(webview_scheme_declared("nope-zz"))
  // 已封版：再声明返回 false，且名单不变
  let before = webview_declared_schemes().length()
  assert_false(webview_predeclare_schemes(["late-zz"]))
  assert_eq(webview_declared_schemes().length(), before)
  // 未声明的名字即使句柄有效也进不去（这里句柄为 0，门在 FFI 之前）
  assert_false(v.register_protocol("nope-zz", "/tmp"))
}

///|
test "重定向是一条独立事件，不与导航开始/完成混在一起" {
  let v = match webview_new(fake_app(), "about:blank") {
    None => return
    Some(x) => x
  }
  let log : Array[String] = []
  v.on_event = Some(fn(e : WebEvent) -> Unit {
    match e {
      NavRedirected(u) => log.push("redirect:" + u)
      NavStarted(u) => log.push("start:" + u)
      NavFinished(u) => log.push("finish:" + u)
      _ => ()
    }
  })
  v.dispatch(3, 0L, "https://a/")
  v.dispatch(15, 0L, "https://b/")
  v.dispatch(5, 0L, "https://b/")
  assert_eq(log, [
    "start:https://a/", "redirect:https://b/", "finish:https://b/",
  ])
}

///|
test "失败事件到结构：kind 14 落成 LoadFailed 且载荷当场可拆" {
  // 这两半各自有测试过，中间那道接缝（kind→变体）漏了一次：枚举里有
  // LoadFailed，映射表里没写 14，于是它永远走 Unknown，调用方拿不到原因。
  let v = match webview_new(fake_app(), "about:blank") {
    None => return
    Some(x) => x
  }
  let seen : Ref[NavError?] = Ref(None)
  let raw_len = Ref(0)
  v.on_event = Some(fn(e : WebEvent) -> Unit {
    match e {
      LoadFailed(raw) => {
        raw_len.val = raw.length()
        seen.val = nav_error_parse(raw)
      }
      _ => ()
    }
  })
  v.dispatch(
    14, 0L, "yuedemo://local/index.html|WebKitNetworkError|-1|scheme unregistered",
  )
  assert_true(raw_len.val > 0)
  match seen.val {
    None => assert_eq(true, false)
    Some(ne) => {
      assert_eq(ne.uri, "yuedemo://local/index.html")
      assert_eq(ne.domain, "WebKitNetworkError")
      assert_eq(ne.code, -1)
      assert_eq(ne.message, "scheme unregistered")
    }
  }
}
