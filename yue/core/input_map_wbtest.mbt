// 平台输入映射层的无头回归：三平台修饰位、两套键码表、shift 折算、按钮号，
// 以及「这颗键先交给谁」的判定表。后端桩落地时直接复用这些表，不再各自决定语义。

///|
fn route_is_ime(r : ImeRoute) -> Bool {
  match r {
    ToIme => true
    _ => false
  }
}

///|
fn route_is_host(r : ImeRoute) -> Bool {
  match r {
    ToHost => true
    _ => false
  }
}

///|
fn route_is_kernel(r : ImeRoute) -> Bool {
  match r {
    ToKernel => true
    _ => false
  }
}

///|
test "修饰位：GDK / Win32 / macOS 三套位都折到 1=shift 2=ctrl 4=alt 8=meta" {
  assert_eq(gtk_mods_to_mods(1), MOD_SHIFT)
  assert_eq(gtk_mods_to_mods(4), MOD_CTRL)
  assert_eq(gtk_mods_to_mods(8), MOD_ALT)
  assert_eq(gtk_mods_to_mods(16), MOD_META)
  // GDK 的 lock 位（2）不该被当成任何修饰键
  assert_eq(gtk_mods_to_mods(2), 0)
  assert_eq(gtk_mods_to_mods(1 | 4 | 8 | 16 | 2), 15)
  assert_eq(win_mods_to_mods(0x0004), MOD_SHIFT)
  assert_eq(win_mods_to_mods(0x0008), MOD_CTRL)
  assert_eq(win_mods_to_mods(0x0020), MOD_ALT)
  assert_eq(win_mods_to_mods(0x0040), MOD_META)
  assert_eq(win_mods_to_mods(0x0001 | 0x0002), 0) // 按钮位不是修饰键
  assert_eq(mac_mods_to_mods(0x20000), MOD_SHIFT)
  assert_eq(mac_mods_to_mods(0x40000), MOD_CTRL)
  assert_eq(mac_mods_to_mods(0x80000), MOD_ALT) // Option
  assert_eq(mac_mods_to_mods(0x100000), MOD_META) // Command
  assert_eq(mac_mods_to_mods(0x10000), 0) // CapsLock 不算修饰键
  assert_eq(mac_caps_lock(0x10000), true)
  assert_eq(mac_caps_lock(0x20000), false)
}

///|
test "Windows 虚拟键码：字母给小写基码、控制/功能/小键盘按 X11 常量" {
  assert_eq(win_vk_to_keysym(0x41), 97) // VK_A → 'a'
  assert_eq(win_vk_to_keysym(0x5A), 122) // VK_Z → 'z'
  assert_eq(win_vk_to_keysym(0x30), 48) // VK_0 → '0'
  assert_eq(win_vk_to_keysym(0x08), KS_BACKSPACE)
  assert_eq(win_vk_to_keysym(0x09), KS_TAB)
  assert_eq(win_vk_to_keysym(0x0D), KS_RETURN)
  assert_eq(win_vk_to_keysym(0x1B), KS_ESCAPE)
  assert_eq(win_vk_to_keysym(0x20), 32)
  assert_eq(win_vk_to_keysym(0x21), 65365) // PRIOR → Page_Up
  assert_eq(win_vk_to_keysym(0x25), KS_LEFT)
  assert_eq(win_vk_to_keysym(0x2D), 65379) // INSERT
  assert_eq(win_vk_to_keysym(0x2E), KS_DELETE)
  assert_eq(win_vk_to_keysym(0x70), 65470) // F1
  assert_eq(win_vk_to_keysym(0x7B), 65481) // F12
  assert_eq(win_vk_to_keysym(0x60), 65456) // 小键盘 0
  assert_eq(win_vk_to_keysym(0x69), 65465) // 小键盘 9
  assert_eq(win_vk_to_keysym(0x6E), 65454) // DECIMAL
  assert_eq(win_vk_to_keysym(0x5B), 65371) // LWIN → Super_L
  assert_eq(win_vk_to_keysym(0x00), 0) // 未知键给 0，由调用方按未知处理
  assert_eq(win_vk_to_keysym(0xDE), 0)
}

///|
test "shift 折算：字母看 shift 异或 caps，数字与符号查表，表外原样" {
  assert_eq(win_apply_shift(97, true, false), 65) // a + shift → A
  assert_eq(win_apply_shift(97, false, true), 65) // caps 单独按也出大写
  assert_eq(win_apply_shift(97, true, true), 97) // shift + caps 又回小写
  assert_eq(win_apply_shift(49, true, false), 33) // 1 → !
  assert_eq(win_apply_shift(48, true, false), 41) // 0 → )
  assert_eq(win_apply_shift(59, true, false), 58) // ; → :
  assert_eq(win_apply_shift(39, true, false), 34) // ' → "
  assert_eq(win_apply_shift(65288, true, false), KS_BACKSPACE) // 控制键不动
  assert_eq(win_apply_shift(97, false, false), 97)
}

///|
test "macOS 虚拟键码：只覆盖编辑/导航/功能/小键盘，字母数字走 Unicode 通道" {
  assert_eq(mac_vk_to_keysym(36), KS_RETURN)
  assert_eq(mac_vk_to_keysym(48), KS_TAB)
  assert_eq(mac_vk_to_keysym(49), 32)
  assert_eq(mac_vk_to_keysym(51), KS_BACKSPACE) // kVK_Delete 是退格
  assert_eq(mac_vk_to_keysym(117), KS_DELETE) // ForwardDelete 才是删除
  assert_eq(mac_vk_to_keysym(123), KS_LEFT)
  assert_eq(mac_vk_to_keysym(126), KS_UP)
  assert_eq(mac_vk_to_keysym(115), KS_HOME)
  assert_eq(mac_vk_to_keysym(121), 65366) // PageDown
  assert_eq(mac_vk_to_keysym(122), 65470) // F1
  assert_eq(mac_vk_to_keysym(111), 65481) // F12
  assert_eq(mac_vk_to_keysym(76), 65421) // 小键盘回车
  assert_eq(mac_vk_to_keysym(0), 0) // kVK_ANSI_A 不在表里（字符由事件给）
}

///|
test "按钮号：Win32 的 MK 位与 macOS 的 buttonNumber 都折成 1 左 2 中 3 右" {
  assert_eq(win_button_to_index(0x0001), 1) // MK_LBUTTON
  assert_eq(win_button_to_index(0x0002), 3) // MK_RBUTTON
  assert_eq(win_button_to_index(0x0010), 2) // MK_MBUTTON
  assert_eq(win_button_to_index(0x0020), 0) // 后退键不是三键之一
  assert_eq(win_button_to_index(0), 0)
  assert_eq(mac_button_to_index(0), 1)
  assert_eq(mac_button_to_index(1), 3)
  assert_eq(mac_button_to_index(2), 2)
  assert_eq(mac_button_to_index(3), 0)
}

///|
test "按键路由：组合中一律给输入法，Ctrl/Meta 组合不喂输入法" {
  // ① 组合中：连 Tab / 退格 / 方向都给输入法（选候选、删组合串、移组合光标）
  assert_eq(route_is_ime(ime_route(KS_TAB, 0, true)), true)
  assert_eq(route_is_ime(ime_route(KS_BACKSPACE, 0, true)), true)
  assert_eq(route_is_ime(ime_route(KS_LEFT, 0, true)), true)
  assert_eq(route_is_ime(ime_route(97, MOD_CTRL, true)), true)
  // ② 未组合的快捷键归宿主
  assert_eq(route_is_host(ime_route(99, MOD_CTRL, false)), true) // Ctrl+C
  assert_eq(route_is_host(ime_route(97, MOD_META, false)), true) // Cmd/Win+A
  assert_eq(route_is_host(ime_route(70, MOD_ALT, false)), true) // Alt+F
  // ③ Tab / Shift+Tab 归宿主（焦点环绕）
  assert_eq(route_is_host(ime_route(KS_TAB, 0, false)), true)
  assert_eq(route_is_host(ime_route(KS_ISO_LEFT_TAB, MOD_SHIFT, false)), true)
  // ④ 光标与选区类直进内核
  assert_eq(route_is_kernel(ime_route(KS_LEFT, 0, false)), true)
  assert_eq(route_is_kernel(ime_route(KS_HOME, MOD_CTRL, false)), true)
  assert_eq(route_is_kernel(ime_route(KS_BACKSPACE, 0, false)), true)
  assert_eq(route_is_kernel(ime_route(KS_DELETE, 0, false)), true)
  // ⑤ 可打印键先过输入法
  assert_eq(route_is_ime(ime_route(97, 0, false)), true)
  assert_eq(route_is_ime(ime_route(32, 0, false)), true)
  // ⑥ 其余（功能键、Escape、修饰键自身）归宿主
  assert_eq(route_is_host(ime_route(65470, 0, false)), true) // F1
  assert_eq(route_is_host(ime_route(KS_ESCAPE, 0, false)), true)
  assert_eq(route_is_host(ime_route(65505, 0, false)), true) // Shift_L
  assert_eq(route_is_host(ime_route(0, 0, false)), true) // 未知键
}

///|
test "输入法动作的触发条件：换焦点才 reset，无焦点不喂 surrounding" {
  assert_eq(ime_should_reset(3, 5), true)
  assert_eq(ime_should_reset(5, 5), false) // 每拍都 reset 会一直打断组合
  assert_eq(ime_should_reset(0, 0), false)
  assert_eq(ime_should_reset(0, 5), true) // 从无焦点到有焦点也要清一次上下文
  assert_eq(ime_should_feed_surrounding(5), true)
  assert_eq(ime_should_feed_surrounding(0), false)
}
