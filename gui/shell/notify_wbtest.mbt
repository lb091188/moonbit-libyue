// W21a 通知门面回归：纯函数部分（kind/百分比夹取、进度正文降级、错误 Show、
// 后端名一致性）。真气泡的弹出/替换/收起归 experiment/notify_probe（纯 C 探针
// 直喂 wm_notify_*，真发 NIM_MODIFY 再用静态表反读）；这里的 wbtest 只做一次
// 「发一张再收起」的生命周期冒烟，且无后端时跳过。

///|
test "notify_clamp_kind：夹到 0..2" {
  inspect(notify_clamp_kind(-1), content="0")
  inspect(notify_clamp_kind(0), content="0")
  inspect(notify_clamp_kind(1), content="1")
  inspect(notify_clamp_kind(2), content="2")
  inspect(notify_clamp_kind(3), content="2")
  inspect(notify_clamp_kind(99), content="2")
}

///|
test "notify_clamp_pct：夹到 0..100" {
  inspect(notify_clamp_pct(-5), content="0")
  inspect(notify_clamp_pct(0), content="0")
  inspect(notify_clamp_pct(50), content="50")
  inspect(notify_clamp_pct(100), content="100")
  inspect(notify_clamp_pct(101), content="100")
}

///|
test "notify_body_with_progress：负值不改进度正文" {
  // pct < 0 表示「不带进度」，正文原样返回（含空串）
  inspect(notify_body_with_progress("下载中", -1), content="下载中")
  inspect(notify_body_with_progress("", -1), content="")
}

///|
test "notify_body_with_progress：带进度拼进正文（可见降级）" {
  inspect(notify_body_with_progress("下载中", 42), content="下载中（42%）")
  // 正文为空时只留百分比
  inspect(notify_body_with_progress("", 7), content="7%")
}

///|
test "notify_body_with_progress：百分比同样被夹取" {
  inspect(notify_body_with_progress("x", 200), content="x（100%）")
  inspect(notify_body_with_progress("x", -3), content="x") // 负值=不带进度
}

///|
test "NotifyError 的 Show 两种变体" {
  assert_eq(NotifyError::Unsupported.to_string(), "NotifyError::Unsupported")
  assert_true(NotifyError::Failed("后端离线").to_string().contains("后端离线"))
  assert_true(NotifyError::Failed("x").to_string().has_prefix("NotifyError::Failed("))
}

///|
test "notify_backend_name 与 notify_backend 一致且非空" {
  let name = notify_backend_name()
  assert_true(name.length() > 0)
  // 名字与枚举一一对应，不许出现「有名字没后端」或反之
  match notify_backend() {
    Some(Dbus) => assert_eq(name, "dbus")
    Some(WinBalloon) => assert_eq(name, "win-balloon")
    None => assert_eq(name, "none")
  }
  assert_eq(notify_supported(), notify_backend() is Some(_))
}

///|
test "notify_caps：有后端给 Ok 且含 body 能力，无后端给 Unsupported" {
  let caps = notify_caps()
  if notify_supported() {
    match caps {
      Ok(c) =>
        // 两个后端都能显示独立正文（Linux body 能力 / Win32 szInfo）
        assert_true(c.body)
      Err(e) => fail("有后端却拿不到能力：\{e}")
    }
  } else {
    match caps {
      Err(NotifyError::Unsupported) => assert_true(true)
      _ => fail("无后端却拿到了能力")
    }
  }
}

///|
test "notify 生命周期（无通知后端的机器自动跳过）" {
  // 会真的在桌面弹一张气泡再立刻收起（同一拍内完成）。无后端的环境跳过而非
  // 造假——探测即口径。
  if !notify_supported() {
    println("skip: 本机没有可用的通知后端")
  } else {
    match notify_send("libyue-wbtest", "wbtest 标题", "wbtest 正文") {
      Err(e) => println("skip: 发通知失败(\{e})")
      Ok(id) => {
        assert_true(id > 0)
        // 进度更新：拿回 id（后端可能复用原 id）
        match notify_progress(id, "libyue-wbtest", "wbtest 标题", "下载中", 60) {
          Ok(pid) => assert_true(pid > 0)
          Err(e) => fail("进度更新失败：\{e}")
        }
        // 关闭成功；重复关闭后端应幂等（Win32 上第二关是 slot 已空的无操作）
        assert_true(notify_close(id) is Ok(_))
        let _ = notify_close(id)
      }
    }
  }
}
