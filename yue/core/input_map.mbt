// 平台输入映射层（另线 #19 首批）：把各平台的按键码、修饰位与指针按钮号映射到
// 本栈的统一口径（X11 keysym + `MOD_*` + 按钮号 1/2/3），并给出「这颗键先交给谁」
// 的判定表。全部是纯函数——后端桩只负责取原始值并调这里的表，Windows/macOS 落地
// 时不必再各自决定一次语义，也不会决定成三个版本。
//
// 口径三条：
// ① **keysym 用 X11 值**（Linux 后端本来就是 GDK keyval，另两平台向它对齐），
//    可打印 ASCII 就是其字符码；
// ② 字母与数字给**未加 shift 的基码**，shift/caps 由 `win_apply_shift` 折算——
//    X11 的 keyval 已经带 shift 语义，Windows 的虚拟键码没有，不补这一步
//    「Shift+A」会被当成 'a'；
// ③ 符号键（OEM 那些）不在表里：Windows 侧走 `WM_CHAR`/Unicode 通道拿字符，
//    macOS 走 `charactersIgnoringModifiers`，硬编一张键盘布局表既错得多也维护不起。
//
// 用在哪：Linux 后端的修饰位折算目前在 `yue/win/stub.c` 的 `wm_mods`（与本文件的
// `gtk_mods_to_mods` 逐位一致，改一处必须改另一处），按键路由由 GTK 的
// `gtk_im_context_filter_keypress` 现场决定（消费了就只走 commit/preedit 通道）；
// 本文件是**三平台共用的口径与判定表**，Windows/macOS 后端在 MoonBit 侧直接调它。

///|
/// 键该先交给谁。`ToIme` = 先给系统输入法过一遍（未被消费才继续）；
/// `ToHost` = 宿主自己吃（焦点环绕、快捷键、功能键）；
/// `ToKernel` = 直接进编辑内核（光标与选区类）。
pub(all) enum ImeRoute {
  ToIme
  ToHost
  ToKernel
}

///|
/// 本栈的修饰位（与 `keys.mbt` 一致）：1=shift 2=ctrl 4=alt 8=meta。
const WIN_MK_SHIFT : Int = 0x0004
const WIN_MK_CONTROL : Int = 0x0008
const WIN_ALT_DOWN : Int = 0x0020
const WIN_META_DOWN : Int = 0x0040
const MAC_CAPS_LOCK : Int = 0x10000
const MAC_SHIFT : Int = 0x20000
const MAC_CONTROL : Int = 0x40000
const MAC_OPTION : Int = 0x80000
const MAC_COMMAND : Int = 0x100000

///|
/// GDK modifier state → 本栈修饰位。GTK 自己的位是 1=shift 2=lock 4=ctrl
/// 8=alt 16=meta，必须显式重映射；`yue/win` 的 C 桩里那份 `wm_mods` 与此逐位对齐。
pub fn gtk_mods_to_mods(state : Int) -> Int {
  let mut m = 0
  if (state & 1) != 0 {
    m = m | MOD_SHIFT
  }
  if (state & 4) != 0 {
    m = m | MOD_CTRL
  }
  if (state & 8) != 0 {
    m = m | MOD_ALT
  }
  if (state & 16) != 0 {
    m = m | MOD_META
  }
  m
}

///|
/// Win32 按键/指针状态 → 本栈修饰位。`MK_*` 是消息里的位（shift=0x4、
/// control=0x8），alt 取低层钩子的 `LLKHF_ALTDOWN`（0x20），meta 由调用方用
/// `GetKeyState(VK_LWIN)` 补成自定义位 0x40——Windows 没有一个统一的修饰位字。
pub fn win_mods_to_mods(flags : Int) -> Int {
  let mut m = 0
  if (flags & WIN_MK_SHIFT) != 0 {
    m = m | MOD_SHIFT
  }
  if (flags & WIN_MK_CONTROL) != 0 {
    m = m | MOD_CTRL
  }
  if (flags & WIN_ALT_DOWN) != 0 {
    m = m | MOD_ALT
  }
  if (flags & WIN_META_DOWN) != 0 {
    m = m | MOD_META
  }
  m
}

///|
/// macOS `NSEvent.modifierFlags` → 本栈修饰位（Command 记成 meta，
/// Option 记成 alt——与用户看到的键名一致，也与 X11 的 Alt/Meta 语义对齐）。
pub fn mac_mods_to_mods(flags : Int) -> Int {
  let mut m = 0
  if (flags & MAC_SHIFT) != 0 {
    m = m | MOD_SHIFT
  }
  if (flags & MAC_CONTROL) != 0 {
    m = m | MOD_CTRL
  }
  if (flags & MAC_OPTION) != 0 {
    m = m | MOD_ALT
  }
  if (flags & MAC_COMMAND) != 0 {
    m = m | MOD_META
  }
  m
}

///|
/// macOS 的 Caps Lock 位（`win_apply_shift` 用它决定字母大小写）。
pub fn mac_caps_lock(flags : Int) -> Bool {
  (flags & MAC_CAPS_LOCK) != 0
}

///|
/// Windows 虚拟键码 → X11 keysym。字母给小写基码（shift 另算），数字给字符本身，
/// 控制/功能/小键盘按 X11 常量表；表里没有的给 0（调用方按「未知键」处理）。
pub fn win_vk_to_keysym(vk : Int) -> Int {
  if vk >= 0x41 && vk <= 0x5A {
    // VK_A..VK_Z 就是 'A'..'Z'，X11 的小写字母是 +32
    vk + 32
  } else if vk >= 0x30 && vk <= 0x39 {
    vk
  } else if vk >= 0x60 && vk <= 0x69 {
    // VK_NUMPAD0..9 → XK_KP_0..9（0xFFB0 起）
    65456 + (vk - 0x60)
  } else if vk >= 0x70 && vk <= 0x7B {
    // VK_F1..F12 → XK_F1..F12（0xFFBE 起）
    65470 + (vk - 0x70)
  } else {
    match vk {
      0x08 => KS_BACKSPACE // VK_BACK
      0x09 => KS_TAB
      0x0D => KS_RETURN
      0x10 => 65505 // VK_SHIFT → XK_Shift_L
      0x11 => 65507 // VK_CONTROL → XK_Control_L
      0x12 => 65513 // VK_MENU(Alt) → XK_Alt_L
      0x13 => 65406 // VK_PAUSE → XK_Pause
      0x14 => 65407 // VK_CAPITAL → XK_Caps_Lock
      0x1B => KS_ESCAPE
      0x20 => 32 // VK_SPACE
      0x21 => 65365 // VK_PRIOR → XK_Page_Up
      0x22 => 65366 // VK_NEXT → XK_Page_Down
      0x23 => KS_END
      0x24 => KS_HOME
      0x25 => KS_LEFT
      0x26 => KS_UP
      0x27 => KS_RIGHT
      0x28 => KS_DOWN
      0x29 => 65377 // VK_SELECT → XK_Select
      0x2D => 65379 // VK_INSERT → XK_Insert
      0x2E => KS_DELETE
      0x5B => 65371 // VK_LWIN → XK_Super_L
      0x5C => 65372 // VK_RWIN → XK_Super_R
      0x6A => 65450 // VK_MULTIPLY → XK_KP_Multiply
      0x6B => 65451 // VK_ADD → XK_KP_Add
      0x6D => 65453 // VK_SUBTRACT → XK_KP_Subtract
      0x6E => 65454 // VK_DECIMAL → XK_KP_Decimal
      0x6F => 65455 // VK_DIVIDE → XK_KP_Divide
      0x90 => 65408 // VK_NUMLOCK → XK_Num_Lock
      0x91 => 65409 // VK_SCROLL → XK_Scroll_Lock
      _ => 0
    }
  }
}

///|
/// X11 的 shift 折算：字母看「shift 异或 caps」，数字与符号查 ASCII 移位表；
/// 表里没有的原样返回（不猜布局）。
pub fn win_apply_shift(ks : Int, shift : Bool, caps : Bool) -> Int {
  if ks >= 97 && ks <= 122 {
    if shift != caps {
      ks - 32
    } else {
      ks
    }
  } else if shift {
    match ks {
      49 => 33 // 1 → !
      50 => 64 // 2 → @
      51 => 35
      52 => 36
      53 => 37
      54 => 94
      55 => 38
      56 => 42
      57 => 40
      48 => 41 // 0 → )
      45 => 95 // - → _
      61 => 43 // = → +
      91 => 123 // [ → {
      93 => 125
      92 => 124
      59 => 58
      39 => 34
      44 => 60
      46 => 62
      47 => 63
      96 => 126
      _ => ks
    }
  } else {
    ks
  }
}

///|
/// macOS 虚拟键码（`kVK_*`，硬件键位）→ X11 keysym。字母/数字**不在这里**：
/// mac 的字符要由事件带的 Unicode 文本给（键盘布局由系统解析），这张表只覆盖
/// 编辑键、导航键、功能键与小键盘；表外给 0。
pub fn mac_vk_to_keysym(code : Int) -> Int {
  match code {
    36 => KS_RETURN // kVK_Return
    48 => KS_TAB // kVK_Tab
    49 => 32 // kVK_Space
    51 => KS_BACKSPACE // kVK_Delete（退格）
    53 => KS_ESCAPE
    76 => 65421 // kVK_ANSI_KeypadEnter → XK_KP_Enter
    75 => 65454 // kVK_ANSI_KeypadDecimal → XK_KP_Decimal
    67 => 65450 // kVK_ANSI_KeypadMultiply
    69 => 65451 // kVK_ANSI_KeypadPlus
    78 => 65453 // kVK_ANSI_KeypadMinus
    71 => 65455 // kVK_ANSI_KeypadDivide
    117 => KS_DELETE // kVK_ForwardDelete → XK_Delete
    115 => KS_HOME
    119 => KS_END
    116 => 65365 // kVK_PageUp
    121 => 65366 // kVK_PageDown
    123 => KS_LEFT
    124 => KS_RIGHT
    125 => KS_DOWN
    126 => KS_UP
    122 => 65470 // kVK_F1
    120 => 65471 // kVK_F2
    99 => 65472 // kVK_F3
    118 => 65473 // kVK_F4
    96 => 65474 // kVK_F5
    97 => 65475 // kVK_F6
    98 => 65476 // kVK_F7
    100 => 65477 // kVK_F8
    101 => 65478 // kVK_F9
    109 => 65479 // kVK_F10
    103 => 65480 // kVK_F11
    111 => 65481 // kVK_F12
    _ => 0
  }
}

///|
/// Win32 指针消息的 `MK_*` 按钮位 → 本栈按钮号（1 左 2 中 3 右，与 X11 同口径）。
pub fn win_button_to_index(mk : Int) -> Int {
  if (mk & 0x0001) != 0 {
    1
  } else if (mk & 0x0002) != 0 {
    3
  } else if (mk & 0x0010) != 0 {
    2
  } else {
    0
  }
}

///|
/// macOS `NSMouseEvent.buttonNumber` → 本栈按钮号（0 左 1 右 2 中）。
pub fn mac_button_to_index(number : Int) -> Int {
  match number {
    0 => 1
    1 => 3
    2 => 2
    _ => 0
  }
}

///|
/// 这颗键先交给谁。规则（Linux 已实测闭环，Win/mac 复用同一张表）：
/// ① **组合中一律先给输入法**——Tab 选候选、退格删组合串、空格上屏，
///    这时宿主吃走就会把输入法的编辑动作打断；
/// ② 光标与选区类键（方向、Home/End、PageUp/Down、退格、删除）直进编辑内核——
///    带 Ctrl 也算（按词跳、到首尾），带 Alt 不算（那是宿主的「后退」）；
/// ③ 未组合时 Tab / Shift+Tab 归宿主（焦点环绕，见 `App::move_focus`）；
/// ④ 带 Ctrl/Meta/Alt 的组合不喂输入法（快捷键语义在宿主侧）；
/// ⑤ 可打印键先给输入法过一遍（未被消费才进内核）——G5a 实测「未被消费键才进
///    内核」就是这一条；
/// ⑥ 其余（功能键、Escape、修饰键自身）归宿主。
pub fn ime_route(keysym : Int, mods : Int, composing : Bool) -> ImeRoute {
  let ctrl_meta = (mods & (MOD_CTRL | MOD_META)) != 0
  let alt_only = (mods & MOD_ALT) != 0
  let tab_key = keysym == KS_TAB || keysym == KS_ISO_LEFT_TAB
  let cursor_key =
    keysym == KS_LEFT || keysym == KS_RIGHT || keysym == KS_UP ||
      keysym == KS_DOWN || keysym == KS_HOME || keysym == KS_END ||
      keysym == 65365 || keysym == 65366 || keysym == KS_BACKSPACE ||
      keysym == KS_DELETE
  if composing {
    ToIme
  } else if cursor_key && !alt_only {
    // 光标与选区类：带 Ctrl 也算（按词跳、到首尾），带 Alt 不算（那是宿主的「后退」）
    ToKernel
  } else if tab_key {
    ToHost
  } else if ctrl_meta || alt_only {
    ToHost
  } else if keysym_is_printable(keysym) {
    ToIme
  } else {
    ToHost
  }
}

///|
/// 焦点换控件时要不要打断输入法（`im_reset` 的触发条件）。规则：**逻辑焦点真的
/// 换了控件**才 reset——每拍都 reset 会一直打断组合（G5a 实测坑），而换焦点时不
/// reset 会把 A 框里排队的拼音 commit 落进 B 框。
pub fn ime_should_reset(prev_focus : Int, next_focus : Int) -> Bool {
  prev_focus != next_focus && (prev_focus != 0 || next_focus != 0)
}

///|
/// 输入法四条件之一：每拍喂给输入法的「已提交文本 + 光标」。给 None 表示这一拍
/// 不喂（焦点控件没有声明 `im_context`，或焦点不在任何控件上）。
pub fn ime_should_feed_surrounding(focus_id : Int) -> Bool {
  focus_id != 0
}
