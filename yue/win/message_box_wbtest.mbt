// W20d 纯函数回归：uType 位组合与返回值归一。位值与 <windows.h> 的 MB_* 宏
// 对齐（0x10 ICONERROR / 0x20 ICONQUESTION / 0x30 ICONWARNING / 0x40
// ICONINFORMATION；按钮 0x0 OK / 0x1 OKCANCEL / 0x2 ABORTRETRYIGNORE /
// 0x3 YESNOCANCEL / 0x4 YESNO / 0x5 RETRYCANCEL；默认钮 0x100/0x200/0x300；
// 0x10000 SETFOREGROUND / 0x40000 TOPMOST / 0x100000 RTLREADING）。
//
// 断言里的 `content=` 是 Int 的十进制渲染（inspect 不做十六进制格式化），故
// 期望值写成「十进制」并在注释里标注对应的十六进制位，便于与 MB_* 宏对照。
// 无载荷枚举在本工具链不派生 Show/Eq（见 app_wbtest.mbt 的口径），结果枚举用
// match 归一成编号再比。

///|
fn mbresult_code(r : MessageBoxResult) -> Int {
  match r {
    Ok => 1
    Cancel => 2
    Abort => 3
    Retry => 4
    Ignore => 5
    Yes => 6
    No => 7
    Failed => 0
  }
}

///|
test "message_box_utype/图标位与按钮位叠加" {
  // 信息 + 确定：ICONINFORMATION(0x40=64) + TOPMOST(0x40000) + SETFOREGROUND(0x10000)
  let t = message_box_utype(Information, Ok)
  inspect(t & 0xF0, content="64") // 0x40
  inspect(t & 0xF, content="0")
  inspect(t & 0x40000, content="262144") // 0x40000
  inspect(t & 0x10000, content="65536") // 0x10000
}

///|
test "message_box_utype/警示与错误图标位" {
  inspect(message_box_utype(Warning, Ok) & 0xF0, content="48") // 0x30
  inspect(message_box_utype(Error, Ok) & 0xF0, content="16") // 0x10
  inspect(message_box_utype(Question, Ok) & 0xF0, content="32") // 0x20
  inspect(message_box_utype(None, Ok) & 0xF0, content="0")
}

///|
test "message_box_utype/按钮组合位" {
  inspect(message_box_utype(None, Ok) & 0xF, content="0")
  inspect(message_box_utype(None, OkCancel) & 0xF, content="1")
  inspect(message_box_utype(None, AbortRetryIgnore) & 0xF, content="2")
  inspect(message_box_utype(None, YesNoCancel) & 0xF, content="3")
  inspect(message_box_utype(None, YesNo) & 0xF, content="4")
  inspect(message_box_utype(None, RetryCancel) & 0xF, content="5")
}

///|
test "message_box_utype/默认钮位" {
  inspect(message_box_utype(None, Ok, default_index=0) & 0xF00, content="0")
  inspect(message_box_utype(None, Ok, default_index=1) & 0xF00, content="256") // 0x100
  inspect(message_box_utype(None, Ok, default_index=2) & 0xF00, content="512") // 0x200
  inspect(message_box_utype(None, Ok, default_index=3) & 0xF00, content="768") // 0x300
  // 越界归零（不崩、不误置位）
  inspect(message_box_utype(None, Ok, default_index=9) & 0xF00, content="0")
}

///|
test "message_box_utype/RTL 位可选" {
  inspect(message_box_utype(None, Ok, is_rtl=false) & 0x100000, content="0")
  inspect(
    message_box_utype(None, Ok, is_rtl=true) & 0x100000,
    content="1048576", // 0x100000
  )
}

///|
test "message_box_utype/四段并用不互相踩" {
  // 错误 + 是/否/取消 + 默认第 2 钮 + RTL：四段各就各位
  let t = message_box_utype(Error, YesNoCancel, default_index=1, is_rtl=true)
  inspect(t & 0xF0, content="16") // 0x10 ICONERROR
  inspect(t & 0xF, content="3") // 0x3 YESNOCANCEL
  inspect(t & 0xF00, content="256") // 0x100 DEFBUTTON2
  inspect(t & 0x100000, content="1048576") // 0x100000 RTL
}

///|
test "message_box_result_of/七个返回值归一" {
  inspect(mbresult_code(message_box_result_of(1)), content="1")
  inspect(mbresult_code(message_box_result_of(2)), content="2")
  inspect(mbresult_code(message_box_result_of(3)), content="3")
  inspect(mbresult_code(message_box_result_of(4)), content="4")
  inspect(mbresult_code(message_box_result_of(5)), content="5")
  inspect(mbresult_code(message_box_result_of(6)), content="6")
  inspect(mbresult_code(message_box_result_of(7)), content="7")
  inspect(mbresult_code(message_box_result_of(0)), content="0")
  inspect(mbresult_code(message_box_result_of(99)), content="0")
}

///|
test "message_box_result_is_affirmative/肯定动作判定" {
  inspect(message_box_result_is_affirmative(Ok), content="true")
  inspect(message_box_result_is_affirmative(Yes), content="true")
  inspect(message_box_result_is_affirmative(Retry), content="true")
  inspect(message_box_result_is_affirmative(Ignore), content="true")
  inspect(message_box_result_is_affirmative(Cancel), content="false")
  inspect(message_box_result_is_affirmative(No), content="false")
  inspect(message_box_result_is_affirmative(Abort), content="false")
  inspect(message_box_result_is_affirmative(Failed), content="false")
}
