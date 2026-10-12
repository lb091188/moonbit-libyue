// W22 热键门面单测：回查表语义（纯逻辑，不碰真注册）。
// 真注册/轮询由 W20b 的 win 侧测试与探针回证；本文件只验门面自己的表。

///|
test "hotkey: 未注册 id 的回查给空串（不崩）" {
  inspect(hotkey_spec_of(999999), content="")
  inspect(hotkey_registered_count(), content="0")
}

///|
test "hotkey: 后端探测（Windows 恒真，其余平台打印跳过）" {
  if hotkey_supported() {
    // 连上了才硬断言：空加速串必须走 Err(Failed) 而不是崩或静默成功
    // （解析不过就进不了注册，无系统副作用）
    match hotkey_register("") {
      Err(_) => inspect(1, content="1")
      Ok(_) => inspect(0, content="1")
    }
  } else {
    println("hotkey: skip (本平台无全局热键后端，W22 门面给 Unsupported)")
  }
}
