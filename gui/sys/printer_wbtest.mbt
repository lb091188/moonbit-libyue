
///|
test "prt Windows 读数环：winspool 枚举 + 默认打印机语义" {
  if sys_platform() != "windows" {
    println("prt: skip (windows-only 读数环)")
    return
  }
  match prt_list() {
    Ok(printers) =>
      for p in printers {
        assert_true(p.name != "")
      }
    Err(e) => {
      println("prt_list failed: \{e}")
      assert_true(false)
    }
  }
  // 未装打印机的机器 prt_list 合法为空；默认打印机缺省是 ParseFailed 语义
  match prt_default() {
    Ok(_) => println("prt: default ok")
    Err(PrtParseFailed(_)) => println("prt: no default (合法)")
    Err(e) => {
      println("prt_default failed: \{e}")
      assert_true(false)
    }
  }
}
