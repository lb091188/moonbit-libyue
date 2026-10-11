// 接线层与单实例的白盒测试：logind 亮度注入后 `yue/sys` 的门与探针一致；
// 单实例名字声称走真总线（本进程内两次声称 → 首个 PrimaryOwner、再来
// AlreadyOwner——幂等语义）。

///|
test {
  // 注入前 sys 的亮度门是「未接入」的假；注入后等于 logind 在线与否
  let logind = logind_available()
  install_logind_brightness()
  assert_eq(@sys.brightness_supported(), logind)
  println("bridge: logind_available=\{logind}")
  // 设备枚举只读 sysfs，与 logind 无关，注入不改它
  match @sys.brightness_devices() {
    Ok(list) => println("bridge: backlight devices=\{list.length()}")
    Err(e) => println("bridge: devices err \{e}")
  }
}

///|
test {
  // 单实例真总线：同一进程同一连接声称两次，第二次是 AlreadyOwner（幂等）
  let app_id = "com.example.moonbitsys.bridgetest"
  match claim_name(app_id) {
    Ok(PrimaryOwner) =>
      match claim_name(app_id) {
        Ok(AlreadyOwner) => ()
        Ok(_) => {
          println("bridge: 第二次声称不是 AlreadyOwner")
          assert_true(false)
        }
        Err(e) => {
          println("bridge: 第二次声称失败 \{e}")
          assert_true(false)
        }
      }
    Ok(AlreadyOwner) => println("bridge: 名字已被本进程持有（重复跑）")
    Ok(_) => println("bridge: 首次声称不是 PrimaryOwner（被别的进程占着？）")
    Err(e) => {
      println("bridge: skip（会话总线不可用：\{e}）")
    }
  }
}
