// 电源计划白盒：纯函数（GUID 对表）+ Windows 直调真读数环。
// pp_set 有系统副作用，只做「写回当前方案」的 round-trip（等效无操作）。

///|
test "pp Windows 直调读数环：profiles 非空 + current 可识别 + set 回当前" {
  if sys_platform() != "windows" {
    println("pp: skip (windows-only 读数环)")
    return
  }
  assert_true(pp_supported())
  match pp_profiles() {
    Ok(profiles) => assert_true(profiles.length() == 3)
    Err(e) => {
      println("pp_profiles failed: \{e}")
      assert_true(false)
    }
  }
  match pp_current() {
    Ok(cur) => {
      // 写回当前方案：系统调用走全链，状态等效无变化
      match pp_set(cur) {
        Ok(_) => println("pp: set round-trip ok (\{cur})")
        Err(e) => {
          println("pp_set failed: \{e}")
          assert_true(false)
        }
      }
    }
    Err(e) => {
      println("pp_current failed: \{e}")
      assert_true(false)
    }
  }
}
