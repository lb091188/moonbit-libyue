// 事件系统白盒测试：归一化/键名等私有函数（不依赖原生库）。

///|
test "Windows VK 码归一化到统一常量表" {
  // 字母/数字/空格两表恰好相同，透传
  inspect(normalize_win_vk(0x41), content="65")   // VK_A == VKEY_A
  inspect(normalize_win_vk(0x39), content="57")   // VK_9 == VKEY_9
  inspect(normalize_win_vk(0x20), content="32")   // VK_SPACE == VKEY_SPACE
  // 功能/编辑/方向键：VK 码 → 表内 GDK 键值
  inspect(normalize_win_vk(0x1b), content="65307") // VK_ESCAPE → VKEY_ESCAPE
  inspect(normalize_win_vk(0x0d), content="65293") // VK_RETURN → VKEY_RETURN
  inspect(normalize_win_vk(0x25), content="65361") // VK_LEFT → VKEY_LEFT
  inspect(normalize_win_vk(0x21), content="65365") // VK_PRIOR → VKEY_PRIOR
  inspect(normalize_win_vk(0x70), content="65470") // VK_F1 → VKEY_F1
  inspect(normalize_win_vk(0x7b), content="65481") // VK_F12 → VKEY_F12
  inspect(normalize_win_vk(0x11), content="65507") // VK_CONTROL → VKEY_CONTROL
  inspect(normalize_win_vk(0x2e), content="65535") // VK_DELETE → VKEY_DELETE
  inspect(normalize_win_vk(0x60), content="65456") // VK_NUMPAD0 → VKEY_NUMPAD0
  inspect(normalize_win_vk(0xba), content="59")    // VK_OEM_1 → VKEY_OEM_1
  // 表外键码原样透传
  inspect(normalize_win_vk(0xe7), content="231")
}

///|
test "键名与组合键描述（describe）" {
  inspect(key_code_name(VKEY_ESCAPE), content="Esc")
  inspect(key_code_name(VKEY_RETURN), content="Enter")
  inspect(key_code_name(VKEY_A), content="A")
  inspect(key_code_name(VKEY_7), content="7")
  inspect(key_code_name(VKEY_F5), content="F5")
  inspect(key_code_name(VKEY_NUMPAD3), content="Num3")
  inspect(key_code_name(VKEY_OEM_COMMA), content=",")
  // Ctrl+A → "Ctrl+A"
  let ctrl_a : KeyEvent = {
    kind: KeyDown,
    code: VKEY_A,
    modifiers: KEY_MOD_CTRL,
    timestamp: 0,
  }
  inspect(ctrl_a.describe(), content="Ctrl+A")
  // Ctrl+Shift+Esc
  let combo : KeyEvent = {
    kind: KeyDown,
    code: VKEY_ESCAPE,
    modifiers: KEY_MOD_CTRL.lor(KEY_MOD_SHIFT),
    timestamp: 0,
  }
  inspect(combo.describe(), content="Shift+Ctrl+Esc")
  // 修饰键自身按下不重复前缀
  let shift_only : KeyEvent = {
    kind: KeyDown,
    code: VKEY_SHIFT,
    modifiers: KEY_MOD_SHIFT,
    timestamp: 0,
  }
  inspect(shift_only.describe(), content="Shift")
}
