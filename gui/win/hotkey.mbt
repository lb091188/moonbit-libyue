// 全局快捷键（W20b）：加速键串解析与平台无关的键位模型。
//
// 本文件只放纯函数——字符串解析与「修饰位/键 → 平台码」的语义约定，
// 平台桩只认这些数字（Win32 的 RegisterHotKey 收 (mods, vk) 两个整数，
// GTK/X11 收 (mods, keysym)，macOS 的 Carbon 收 (mods, keycode)）。
// 解析结果里两套码都给：`keysym` 走 X11 口径（与 core/keys.mbt 的
// KS_* 同源），`vk` 走 Win32 虚拟键码；各平台后端按需取。
//
// 加速键串语法沿用旧栈（yue/widgets.mbt 的 register_global_shortcut）：
//   "CmdOrCtrl+Shift+M" / "Ctrl+Alt+Delete" / "F5" / "Ctrl+," 
// 词序不限、大小写不敏感；`CmdOrCtrl` 是「平台主修饰」的别名——Windows
// 映射 Ctrl、macOS 映射 Cmd(⌘)、Linux 映射 Ctrl。修饰词：Ctrl/Control、
// Shift、Alt/Option、Cmd/Command/Super/Win/Meta、CmdOrCtrl。
// 主键部分：字母 A-Z、数字 0-9、F1-F24、方向键/Home/End/PageUp/PageDown/
// Insert/Delete/Backspace/Tab/Enter/Escape/Space/标点（单字符按 Unicode 码点）。

// utf8.encode：把词拆成字节以取单字符键的 ASCII 码点（MoonBit 的 String
// 下标给 UInt16/Char 口径不一，走字节最稳）。

///|
/// 解析结果：修饰位（与 core/keys.mbt 的 MOD_* 同源）、两套键码、
/// 以及归一化后的键名（诊断与提示文本用）。解析失败返回 None。
pub(all) struct Hotkey {
  /// 修饰位：1=shift 2=ctrl 4=alt 8=meta（与 MOD_* 一致）
  mods : Int
  /// X11 keysym 口径（内核 KS_* 同源）
  keysym : Int
  /// Win32 虚拟键码（RegisterHotKey 用；非 Windows 后端忽略）
  vk : Int
  /// 归一化键名（"M" / "F5" / "PageUp"），大小写按表定
  name : String
}

///|
/// 单个修饰词的判定：返回该词贡献的修饰位；不是修饰词给 -1。
/// `is_mac` 决定 `CmdOrCtrl` 映射 Ctrl(2) 还是 Meta(8)。
fn hotkey_modifier_bit(word : String, is_mac : Bool) -> Int {
  match word {
    "ctrl" | "control" => 2
    "shift" => 1
    "alt" | "option" | "opt" => 4
    "cmd" | "command" | "super" | "win" | "meta" => 8
    "cmdorctrl" | "cmdorctl" | "commandorcontrol" =>
      if is_mac { 8 } else { 2 }
    _ => -1
  }
}

///|
/// 主键名 → (keysym, vk, 归一化名)。名字按小写匹配（调用方预先 lower）。
/// 单字符（字母/数字/标点）由调用方走 `hotkey_char_key` 处理。
priv struct KeyCode {
  keysym : Int
  vk : Int
}

///|
/// 具名键表（小写名 → 码）。返回 None 表示非具名键（可能是单字符）。
fn hotkey_named_key(low : String) -> KeyCode? {
  match low {
    "backspace" => Some({ keysym: 65288, vk: 0x08 })
    "tab" => Some({ keysym: 65289, vk: 0x09 })
    "enter" | "return" => Some({ keysym: 65293, vk: 0x0D })
    "escape" | "esc" => Some({ keysym: 65307, vk: 0x1B })
    "space" => Some({ keysym: 32, vk: 0x20 })
    "left" => Some({ keysym: 65361, vk: 0x25 })
    "up" => Some({ keysym: 65362, vk: 0x26 })
    "right" => Some({ keysym: 65363, vk: 0x27 })
    "down" => Some({ keysym: 65364, vk: 0x28 })
    "home" => Some({ keysym: 65360, vk: 0x24 })
    "end" => Some({ keysym: 65367, vk: 0x23 })
    "pageup" | "pgup" => Some({ keysym: 65365, vk: 0x21 })
    "pagedown" | "pgdn" => Some({ keysym: 65366, vk: 0x22 })
    "insert" | "ins" => Some({ keysym: 65379, vk: 0x2D })
    "delete" | "del" => Some({ keysym: 65535, vk: 0x2E })
    "f1" => Some({ keysym: 65470, vk: 0x70 })
    "f2" => Some({ keysym: 65471, vk: 0x71 })
    "f3" => Some({ keysym: 65472, vk: 0x72 })
    "f4" => Some({ keysym: 65473, vk: 0x73 })
    "f5" => Some({ keysym: 65474, vk: 0x74 })
    "f6" => Some({ keysym: 65475, vk: 0x75 })
    "f7" => Some({ keysym: 65476, vk: 0x76 })
    "f8" => Some({ keysym: 65477, vk: 0x77 })
    "f9" => Some({ keysym: 65478, vk: 0x78 })
    "f10" => Some({ keysym: 65479, vk: 0x79 })
    "f11" => Some({ keysym: 65480, vk: 0x7A })
    "f12" => Some({ keysym: 65481, vk: 0x7B })
    "f13" => Some({ keysym: 65482, vk: 0x7C })
    "f14" => Some({ keysym: 65483, vk: 0x7D })
    "f15" => Some({ keysym: 65484, vk: 0x7E })
    "f16" => Some({ keysym: 65485, vk: 0x7F })
    "f17" => Some({ keysym: 65486, vk: 0x80 })
    "f18" => Some({ keysym: 65487, vk: 0x81 })
    "f19" => Some({ keysym: 65488, vk: 0x82 })
    "f20" => Some({ keysym: 65489, vk: 0x83 })
    "f21" => Some({ keysym: 65490, vk: 0x84 })
    "f22" => Some({ keysym: 65491, vk: 0x85 })
    "f23" => Some({ keysym: 65492, vk: 0x86 })
    "f24" => Some({ keysym: 65493, vk: 0x87 })
    _ => None
  }
}

///|
/// 单字符主键 → 码。ASCII 可显字符：keysym 取该字符（X11 Latin-1 段即码点），
/// vk 取 Win32 的 `VkKeyScan` 口径——字母统一大写 VK、数字/标点取其在 US
/// 布局下的 VK（大写字母 'A'..'Z' 给 0x41+；数字 '0'..'9' 给 0x30+；
/// 标点按 US 布局硬表）。非 ASCII 给 None（全局快捷键必须是 ASCII 键）。
/// `code` 是 ASCII 码点（调用方已从单字符串取到）。
fn hotkey_char_key(code : Int) -> KeyCode? {
  if code >= 97 && code <= 122 {
    // a-z
    Some({ keysym: code, vk: 0x41 + (code - 97) })
  } else if code >= 65 && code <= 90 {
    // A-Z
    Some({ keysym: 97 + (code - 65), vk: code })
  } else if code >= 48 && code <= 57 {
    // 0-9
    Some({ keysym: code, vk: code })
  } else {
    hotkey_punct_key(code)
  }
}

///|
/// US 布局下的标点 VK 表（OEM 键的 VK 是固定值，与布局相关但这是 Win32
/// RegisterHotKey 的既有语义）。keysym 一律取该字符本身（X11 口径）。
fn hotkey_punct_key(code : Int) -> KeyCode? {
  let vk = match code {
    44 => 0xBC // ,
    46 => 0xBE // .
    47 => 0xBF // /
    59 => 0xBA // ;
    39 => 0xDE // '
    91 => 0xDB // [
    93 => 0xDD // ]
    92 => 0xDC // \
    45 => 0xBD // -
    61 => 0xBB // =
    96 => 0xC0 // `
    _ => 0
  }
  if vk == 0 {
    None
  } else {
    Some({ keysym: code, vk })
  }
}

///|
/// 单个「非修饰词」词的解析：(码, 规范显示名)。具名键优先、否则单 ASCII
/// 字符；都不匹配给 None。
fn hotkey_main_key(word : String, low : String) -> (KeyCode, String)? {
  match hotkey_named_key(low) {
    Some(k) => Some((k, hotkey_canonical_name(low)))
    None => {
      // 单字符键：取该词的 ASCII 码点（"M" / "," / "5"）；多字节（非
      // ASCII）不给全局快捷键
      let bs = @utf8.encode(word)
      if bs.length() != 1 {
        None
      } else {
        match hotkey_char_key(bs[0].to_int()) {
          Some(k) => Some((k, hotkey_char_name(bs[0].to_int())))
          None => None
        }
      }
    }
  }
}

///|
/// 解析加速键串。`is_mac` 决定 `CmdOrCtrl` 的落点（Windows/Linux 传 false）。
/// 成功给 Some(Hotkey)；词表为空、含未知词、或没有主键时给 None。
pub fn parse_accelerator(spec : String, is_mac : Bool) -> Hotkey? {
  let parts = spec.split("+")
  let cleaned : Array[String] = []
  for p in parts {
    let s = p.trim()
    if s != "" {
      cleaned.push(s.to_owned())
    }
  }
  if cleaned.length() == 0 {
    return None
  }
  let mut mods = 0
  let mut key : KeyCode? = None
  let mut key_name = ""
  for p in cleaned {
    let low = p.to_lower()
    let bit = hotkey_modifier_bit(low, is_mac)
    if bit >= 0 {
      mods = mods | bit
      continue
    }
    if key is Some(_) {
      // 出现第二个主键：非法
      return None
    }
    match hotkey_main_key(p, low) {
      None => return None
      Some(pair) => {
        key = Some(pair.0)
        key_name = pair.1
      }
    }
  }
  match key {
    None => None
    Some(k) => Some({ mods, keysym: k.keysym, vk: k.vk, name: key_name })
  }
}

///|
/// 具名键的规范显示名（提示文本用）。
fn hotkey_canonical_name(low : String) -> String {
  match low {
    "enter" | "return" => "Enter"
    "escape" | "esc" => "Esc"
    "space" => "Space"
    "left" => "Left"
    "up" => "Up"
    "right" => "Right"
    "down" => "Down"
    "home" => "Home"
    "end" => "End"
    "pageup" | "pgup" => "PageUp"
    "pagedown" | "pgdn" => "PageDown"
    "insert" | "ins" => "Insert"
    "delete" | "del" => "Delete"
    "backspace" => "Backspace"
    "tab" => "Tab"
    _ =>
      // F1..F24 等：首字母大写（"f5" → "F5"）
      if low.length() >= 2 {
        hotkey_char_name(low[0].to_int()) + low[1:].to_owned()
      } else {
        low
      }
  }
}

///|
/// 单字符键的规范显示名：字母/数字大写，标点原样。`code` 是 ASCII 码点。
fn hotkey_char_name(code : Int) -> String {
  if code >= 97 && code <= 122 {
    ((code - 32).to_char().unwrap_or('?')).to_string()
  } else {
    code.to_char().unwrap_or('?').to_string()
  }
}

///|
/// 修饰位的规范显示名（提示文本用）。顺序按平台惯例：mac 是
/// Cmd/Shift/Alt/Ctrl，其余是 Ctrl/Shift/Alt/Win——主修饰在最前。
pub fn hotkey_mods_label(mods : Int, is_mac : Bool) -> String {
  let mut s = ""
  if is_mac {
    if (mods & 8) != 0 {
      s = s + "Cmd+"
    }
    if (mods & 1) != 0 {
      s = s + "Shift+"
    }
    if (mods & 4) != 0 {
      s = s + "Alt+"
    }
    if (mods & 2) != 0 {
      s = s + "Ctrl+"
    }
  } else {
    if (mods & 2) != 0 {
      s = s + "Ctrl+"
    }
    if (mods & 1) != 0 {
      s = s + "Shift+"
    }
    if (mods & 4) != 0 {
      s = s + "Alt+"
    }
    if (mods & 8) != 0 {
      s = s + "Win+"
    }
  }
  s
}

///|
/// 完整的加速键提示文本（"Ctrl+Shift+M"），菜单项右侧显示用。
pub fn hotkey_label(hk : Hotkey, is_mac : Bool) -> String {
  hotkey_mods_label(hk.mods, is_mac) + hk.name
}
