// W20b 全局快捷键：加速键串解析的纯函数回归。
// 只钉「字符串 → 修饰位/键码/显示名」这一段，平台桩（RegisterHotKey）
// 的成败由探针与真机验证覆盖（X11 下 XGrabKey 排他、Win32 下组合键被
// 占用即失败，都是运行期事实）。

///|
test "parse: 基本修饰 + 字母键（CmdOrCtrl 在非 mac 落 Ctrl）" {
  match parse_accelerator("CmdOrCtrl+Shift+M", false) {
    None => fail("应解析成功")
    Some(hk) => {
      assert_eq(hk.mods, 2 | 1)
      assert_eq(hk.keysym, 109) // 'm'
      assert_eq(hk.vk, 0x4D)
      assert_eq(hk.name, "M")
    }
  }
}

///|
test "parse: CmdOrCtrl 在 mac 落 Meta(Cmd)" {
  match parse_accelerator("CmdOrCtrl+Shift+M", true) {
    None => fail("应解析成功")
    Some(hk) => assert_eq(hk.mods, 8 | 1)
  }
}

///|
test "parse: 词序不限、大小写不敏感" {
  let a = parse_accelerator("shift+ctrl+m", false)
  let b = parse_accelerator("Ctrl+Shift+M", false)
  match (a, b) {
    (Some(x), Some(y)) => {
      assert_eq(x.mods, y.mods)
      assert_eq(x.keysym, y.keysym)
      assert_eq(x.vk, y.vk)
    }
    _ => fail("两者都应解析成功")
  }
}

///|
test "parse: 具名键（F 系列 / PageUp / Escape 别名）" {
  match parse_accelerator("Ctrl+F5", false) {
    Some(hk) => {
      assert_eq(hk.keysym, 65474)
      assert_eq(hk.vk, 0x74)
      assert_eq(hk.name, "F5")
    }
    None => fail("F5 应解析成功")
  }
  match parse_accelerator("Alt+PgUp", false) {
    Some(hk) => assert_eq(hk.name, "PageUp")
    None => fail("PgUp 应解析成功")
  }
  match parse_accelerator("Esc", false) {
    Some(hk) => {
      assert_eq(hk.keysym, 65307)
      assert_eq(hk.name, "Esc")
    }
    None => fail("Esc 应解析成功")
  }
}

///|
test "parse: 修饰词别名（Control / Option / Super / Win / Meta）" {
  for spec in ["Control+A", "Option+A", "Super+A", "Win+A", "Meta+A"] {
    match parse_accelerator(spec, false) {
      Some(hk) => assert_true(hk.mods != 0)
      None => fail("\{spec} 应解析成功")
    }
  }
  // Option 是 Alt（4）的别名
  match parse_accelerator("Option+A", false) {
    Some(hk) => assert_eq(hk.mods, 4)
    None => fail("Option 应解析成功")
  }
}

///|
test "parse: 数字与标点（含 ',' 单字符键）" {
  match parse_accelerator("Ctrl+5", false) {
    Some(hk) => {
      assert_eq(hk.keysym, 53)
      assert_eq(hk.vk, 0x35)
      assert_eq(hk.name, "5")
    }
    None => fail("Ctrl+5 应解析成功")
  }
  match parse_accelerator("Ctrl+,", false) {
    Some(hk) => {
      assert_eq(hk.keysym, 44)
      assert_eq(hk.vk, 0xBC)
      assert_eq(hk.name, ",")
    }
    None => fail("Ctrl+, 应解析成功")
  }
}

///|
test "parse: 无主键 / 空串 / 未知词 / 两个主键 一律失败" {
  assert_true(parse_accelerator("Ctrl+Shift", false) is None)
  assert_true(parse_accelerator("", false) is None)
  assert_true(parse_accelerator("   ", false) is None)
  assert_true(parse_accelerator("Ctrl+NotAKey", false) is None)
  assert_true(parse_accelerator("Ctrl+A+B", false) is None)
}

///|
test "parse: 非 ASCII 单字符不接受（全局快捷键必须 ASCII）" {
  assert_true(parse_accelerator("Ctrl+中", false) is None)
}

///|
test "label: 修饰位与键名拼出提示文本" {
  // 非 mac：CmdOrCtrl 落 Ctrl(2)，提示文本按位渲染
  match parse_accelerator("CmdOrCtrl+Shift+M", false) {
    Some(hk) => assert_eq(hotkey_label(hk, false), "Ctrl+Shift+M")
    None => fail("应解析成功")
  }
  // mac：CmdOrCtrl 落 Meta(8)，提示用 Cmd 样式
  match parse_accelerator("CmdOrCtrl+Shift+M", true) {
    Some(hk) => assert_eq(hotkey_label(hk, true), "Cmd+Shift+M")
    None => fail("应解析成功")
  }
}

///|
test "label: 修饰位顺序固定 Ctrl/Shift/Alt/Meta" {
  match parse_accelerator("Alt+Shift+Ctrl+F1", false) {
    Some(hk) => assert_eq(hotkey_label(hk, false), "Ctrl+Shift+Alt+F1")
    None => fail("应解析成功")
  }
}
