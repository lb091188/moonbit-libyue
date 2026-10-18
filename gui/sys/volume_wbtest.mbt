
///|
test "vol Windows 读数环：读快照 + 设回当前音量 + 静音态读回一致" {
  if sys_platform() != "windows" {
    println("vol: skip (windows-only 读数环)")
    return
  }
  // 探针即分支：CI 的 runner 没有音频端点（vol_supported 只看 COM 可起，
  // 默认端点要到 vol_get 才暴露缺失），无设备环境的正常形态是跳过而不是判红。
  let cur = match vol_get() {
    Ok(c) => c
    Err(e) => {
      println("vol: skip (本环境无可读音频端点：\{e})")
      return
    }
  }
  assert_true(vol_supported())
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
