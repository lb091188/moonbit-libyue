// 单实例接线层的白盒测试：名字声称走真总线（本进程内两次声称 → 首个
// PrimaryOwner、再来 AlreadyOwner——幂等语义）。

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
