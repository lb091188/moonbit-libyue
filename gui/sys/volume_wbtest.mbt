
///|
test "vol Windows 读数环：读快照 + 设回当前音量 + 静音态读回一致" {
  if sys_platform() != "windows" {
    println("vol: skip (windows-only 读数环)")
    return
  }
  assert_true(vol_supported())
  match vol_get() {
    Ok(cur) => {
      assert_true(cur.volume >= 0 && cur.volume <= 100)
      match vol_set(cur.volume) {
        Ok(_) => println("vol: set round-trip ok")
        Err(e) => {
          println("vol_set failed: \{e}")
          assert_true(false)
        }
      }
      match vol_get() {
        Ok(after) => assert_true(after.volume == cur.volume && after.muted == cur.muted)
        Err(e) => {
          println("vol_get failed: \{e}")
          assert_true(false)
        }
      }
    }
    Err(e) => {
      println("vol_get failed: \{e}")
      assert_true(false)
    }
  }
}
