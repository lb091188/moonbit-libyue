// 外部事件循环三接口白盒冒烟:不建控件、不跑 run(),验证单步迭代/跨线程唤醒/
// 退出清理的 C ABI 链路在三平台均正常返回。唤醒→提前返回的时序语义由机制
// 实验覆盖(experiment/async_coexist 的 glib_step 与 async 外部循环实验),
// 此处只保证不崩、不挂、返回值合法。

///|
test "loop poll/wakeup/terminate 冒烟:正常返回不阻塞" {
  // 0=不等待:应立即返回,不阻塞测试
  let r1 = loop_poll(0)
  inspect(r1 >= 0, content="true")
  // 唤醒后再非阻塞迭代一轮:唤醒消息应在本轮被取走;断言只保返回合法
  loop_wakeup()
  let r2 = loop_poll(0)
  inspect(r2 >= 0, content="true")
  loop_terminate()
}
