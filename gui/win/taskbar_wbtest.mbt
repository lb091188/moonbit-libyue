// 任务栏进度纯函数单测（§6.3）：状态编号往返 + 未知编号归 NoProgress。
// 运行时入口（真 COM + 真窗口）由纯 C 探针 experiment/taskbar_probe 回证。

///|
test "taskbar: 状态编号与 C 侧 TBPF_* 对齐" {
  inspect(taskbar_state_id(NoProgress), content="0")
  inspect(taskbar_state_id(Normal), content="1")
  inspect(taskbar_state_id(Error), content="2")
  inspect(taskbar_state_id(Paused), content="3")
  inspect(taskbar_state_id(Indeterminate), content="4")
}

///|
test "taskbar: 编号往返（id → 枚举 → id 不变）" {
  inspect(taskbar_state_id(taskbar_state_of(0)), content="0")
  inspect(taskbar_state_id(taskbar_state_of(1)), content="1")
  inspect(taskbar_state_id(taskbar_state_of(2)), content="2")
  inspect(taskbar_state_id(taskbar_state_of(3)), content="3")
  inspect(taskbar_state_id(taskbar_state_of(4)), content="4")
}

///|
test "taskbar: 未知编号归 NoProgress（与 C 侧 default 分支一致）" {
  inspect(taskbar_state_id(taskbar_state_of(-1)), content="0")
  inspect(taskbar_state_id(taskbar_state_of(5)), content="0")
  inspect(taskbar_state_id(taskbar_state_of(99)), content="0")
}

///|
test "taskbar: 后端探测可用（Windows 恒真，其余平台打印跳过）" {
  if taskbar_supported() {
    // 连上了才硬断言：不存在的窗口句柄必须给 false，而不是静默成功
    let fake : Window = { id: 999999, width: 0, height: 0 }
    inspect(fake.set_taskbar_state(Normal), content="false")
    inspect(fake.set_taskbar_progress(1, 2), content="false")
  } else {
    println("taskbar: skip (本平台无任务栏进度后端)")
  }
}
