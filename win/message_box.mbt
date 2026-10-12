// 原生消息框（W20d）的纯函数层：语义参数 → Win32 `MessageBoxW` 的 `uType`
// 位组合。位值与 `<windows.h>` 的 MB_* 宏逐位对齐（见
// docs/zh/adaptation.md），这里不 include 头文件也要在无平台时可用——探针与
// 单测跑的是同一份映射，桩层只是把结果原样递给 MessageBoxW。
//
// 为什么位组合也算「纯函数」值得单列：`MessageBoxW` 的 uType 是**图标位 ∪
// 按钮位 ∪ 默认钮位 ∪ 模态位**四段并用一个 DWORD 传的，映射错了表现为
// 「图标在但按钮不对」或「返回值编号对不上」，而这类错误编译期全绿、真机才发现
// （与 W6 IME、W16 剪贴板同性质）。把映射抽出来做 wbtest，「Win32 位口径」就有了
// 可回归的单一真源。

///|
/// 消息框语义类型（对应 `MB_ICON*` 图标段）。
pub(all) enum MessageBoxKind {
  None
  Information
  Warning
  Error
  Question
}

///|
/// 按钮集合（对应 `MB_*` 按钮段，决定 `wm_message_box` 的返回编号语义）。
pub(all) enum MessageBoxButtons {
  Ok
  OkCancel
  YesNo
  YesNoCancel
  RetryCancel
  AbortRetryIgnore
}

///|
/// 图标位：`MB_ICON*`。None → 0（系统给默认）。
fn message_box_icon_bits(kind : MessageBoxKind) -> Int {
  match kind {
    None => 0
    Information => 0x00000040
    Warning => 0x00000030
    Error => 0x00000010
    Question => 0x00000020
  }
}

///|
/// 按钮位：`MB_*` 按钮组合。
fn message_box_button_bits(buttons : MessageBoxButtons) -> Int {
  match buttons {
    Ok => 0x00000000
    OkCancel => 0x00000001
    YesNoCancel => 0x00000003
    YesNo => 0x00000004
    RetryCancel => 0x00000005
    AbortRetryIgnore => 0x00000002
  }
}

///|
/// 默认钮位：`MB_DEFBUTTON2/3/4`。0 表示默认第一个钮（`MB_DEFBUTTON1` 即 0）。
fn message_box_default_bits(default_index : Int) -> Int {
  match default_index {
    1 => 0x00000100
    2 => 0x00000200
    3 => 0x00000300
    _ => 0
  }
}

///|
/// 组装 `MessageBoxW` 的 `uType`：图标 ∪ 按钮 ∪ 默认钮，并置顶置位
/// `MB_TOPMOST`（消息框挂在本进程窗口之上，避免被别的窗口盖住）与
/// `MB_SETFOREGROUND`（拿到前台焦点，用户一眼看见）。
/// `is_rtl` 为 true 时补 `MB_RTLREADING`（从右到左阅读顺序）。
pub fn message_box_utype(
  kind : MessageBoxKind,
  buttons : MessageBoxButtons,
  default_index? : Int = 0,
  is_rtl? : Bool = false,
) -> Int {
  let mut bits = message_box_icon_bits(kind)
  bits = bits | message_box_button_bits(buttons)
  bits = bits | message_box_default_bits(default_index)
  bits = bits | 0x00040000 // MB_TOPMOST
  bits = bits | 0x00010000 // MB_SETFOREGROUND
  if is_rtl {
    bits = bits | 0x00100000 // MB_RTLREADING
  }
  bits
}

///|
/// 返回值编号 → 语义结果。`MessageBoxW` 返回值口径：1 OK / 2 CANCEL /
/// 3 ABORT / 4 RETRY / 5 IGNORE / 6 YES / 7 NO；0 = 失败或内存不足。
/// 归一到 `MessageBoxResult`，调用方不再记数字。
pub(all) enum MessageBoxResult {
  Ok
  Cancel
  Abort
  Retry
  Ignore
  Yes
  No
  Failed
}

///|
pub fn message_box_result_of(code : Int) -> MessageBoxResult {
  match code {
    1 => Ok
    2 => Cancel
    3 => Abort
    4 => Retry
    5 => Ignore
    6 => Yes
    7 => No
    _ => Failed
  }
}

///|
/// 该结果是否为「肯定」动作（Yes/Ok/Retry/Ignore 之外——语义上「继续」的
/// 那种）。调用方常只需一个布尔，这里给统一判定，免得每种按钮组合各写一遍。
pub fn message_box_result_is_affirmative(r : MessageBoxResult) -> Bool {
  match r {
    Ok | Yes | Retry | Ignore => true
    _ => false
  }
}
