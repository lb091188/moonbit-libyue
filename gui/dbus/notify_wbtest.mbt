// 桌面通知白盒测试：入参构造（顺序、replaces_id、hint `value` 的钳制与
// 有无形态）用纯函数钉住；能力探测走真总线（无副作用）；发送与关闭会真弹
// 气泡，属设置类，不在测试里执行——由示例/使用者在明确时机触发。

///|
test {
  // 参数顺序：app_name, replaces_id, app_icon, summary, body, actions, hints, timeout
  let args = nf_notify_args("测试应用", "标题", "正文", "dialog-info", 5000, 0, -1)
  assert_eq(args.length(), 8)
  match args[0] {
    GVString(s) => assert_eq(s, "测试应用")
    _ => assert_true(false) // 走到错误分支：GVString(app_name)
  }
  match args[1] {
    GVUInt32(n) => assert_eq(n, 0)
    _ => assert_true(false) // 走到错误分支：GVUInt32(replaces_id)
  }
  match args[2] {
    GVString(s) => assert_eq(s, "dialog-info")
    _ => assert_true(false) // 走到错误分支：GVString(icon)
  }
  match args[7] {
    GVInt32(t) => assert_eq(t, 5000)
    _ => assert_true(false) // 走到错误分支：GVInt32(timeout)
  }
  // 无进度：hints 空
  match args[6] {
    GVDict(m) => assert_eq(m.length(), 0)
    _ => assert_true(false) // 走到错误分支：GVDict
  }
}

///|
test {
  // 带进度：hint `value` 是 INT32，超过 100 钳到 100，负数不出现
  let args = nf_notify_args("app", "s", "b", "", -1, 7, 140)
  match args[1] {
    GVUInt32(n) => assert_eq(n, 7)
    _ => assert_true(false) // 走到错误分支：GVUInt32(replaces_id)
  }
  match args[6] {
    GVDict(m) =>
      match m.get("value") {
        Some(GVInt32(p)) => assert_eq(p, 100)
        _ => assert_true(false) // 走到错误分支：hint value 应为 GVInt32(100)
      }
    _ => assert_true(false) // 走到错误分支：GVDict
  }
  // 0..100 原样
  let args2 = nf_notify_args("app", "s", "b", "", -1, 0, 42)
  match args2[6] {
    GVDict(m) =>
      match m.get("value") {
        Some(GVInt32(p)) => assert_eq(p, 42)
        _ => assert_true(false) // 走到错误分支：hint value 应为 GVInt32(42)
      }
    _ => assert_true(false) // 走到错误分支：GVDict
  }
  // 负进度（-1）视为「不带进度」
  let args3 = nf_notify_args("app", "s", "b", "", -1, 0, -1)
  match args3[6] {
    GVDict(m) => assert_eq(m.length(), 0)
    _ => assert_true(false) // 走到错误分支：GVDict
  }
}

///|
test {
  // 能力探测：真总线只读调用（本机 xfce4-notifyd 在线时应 Ok）
  match notify_caps() {
    Ok(caps) => {
      println("notify caps: \{caps.raw.length()} 条")
      assert_true(caps.raw.length() > 0)
      // 能力名不翻译：body 是规范里的标准项，xfce4-notifyd 会给
      assert_true(caps.body)
      assert_true(notify_supported())
    }
    Err(NfUnsupported) => println("notify: skip（会话总线/通知服务不可用）")
    Err(NfFailed(m)) => {
      // 总线在、通知服务没装（CI runner 与无桌面会话的机器就是这样）：那是环境
      // 缺项，与上一条同一口径——打印跳过，不当成代码失败
      let no_service =
        m.contains("ServiceUnknown") || m.contains(".service files")
      if no_service {
        println("notify: skip（通知服务未安装：\{m}）")
      } else {
        println("notify_caps failed: \{m}")
        assert_true(false)
      }
    }
  }
}

///|
test {
  // 错误归一：D-Bus 错误名进 NfFailed；连不上总线进 NfUnsupported
  assert_eq(
    NotifyError::NfUnsupported.to_string(),
    "NotifyError::NfUnsupported",
  )
  assert_eq(
    NotifyError::NfFailed("org.freedesktop.Notifications.Error").to_string(),
    "NotifyError::NfFailed(org.freedesktop.Notifications.Error)",
  )
  // 对不存在的服务发通知：拿到的应是 NfFailed（服务名查不到），不是崩溃
  match
    gdbus_call_session(
      "org.freedesktop.Notifications",
      "/org/freedesktop/Notifications",
      "org.freedesktop.Notifications",
      "NoSuchMethod",
      [],
    ) {
    Ok(_) => assert_true(false) // 走到错误分支：不存在的方法应报错
    Err(e) => assert_true(e.name.length() > 0)
  }
}
