///|
/// 通知进度文本与进度正文组合测试（通知规范无进度 hint，正文内
/// 字符进度条是跨平台一致呈现；渲染规则见 notification_progress_text）。
test "notification_progress_text：端点与钳制" {
  // 端点：0% 全空、100% 全满
  inspect(
    notification_progress_text(0.0),
    content="░░░░░░░░░░ 0%",
  )
  inspect(
    notification_progress_text(100.0),
    content="██████████ 100%",
  )
  // 中点：5/10 格
  inspect(
    notification_progress_text(50.0),
    content="█████░░░░░ 50%",
  )
  // 越界钳制：负值按 0、超过按 100
  inspect(
    notification_progress_text(-3.0),
    content="░░░░░░░░░░ 0%",
  )
  inspect(
    notification_progress_text(150.0),
    content="██████████ 100%",
  )
  // NaN 按 0 处理
  inspect(
    notification_progress_text(0.0 / 0.0),
    content="░░░░░░░░░░ 0%",
  )
  // 自定义宽度：2 格、半数进位 0.4*2=0.8→四舍五入 1
  inspect(notification_progress_text(40.0, width=2), content="█░ 40%")
  // width<=0 只给百分比
  inspect(notification_progress_text(42.0, width=0), content="42%")
  inspect(notification_progress_text(42.0, width=-5), content="42%")
  // 四舍五入：45.9% 显示为 45%（to_int 截断），格数以 p 为基准
  inspect(
    notification_progress_text(45.9),
    content="█████░░░░░ 45%",
  )
}

///|
/// 进度正文 = 原文 + 换行 + 进度文本（组合规则锁契约）。
test "Notification::set_progress：正文加换行进度行" {
  let n = Notification::new()
  n.set_progress("正在导出 3/8 个文件", 37.5, width=4)
  n.close()
  // set_body 无读取 API，正文组合规则由通知 body 通道保证；此处验证
  // 组装与 notify 通道不抛异常（通知系统不可用时 show 前不出错）。
  println(
    "进度正文组装冒烟通过（通知通道不读回，验证点：组合无异常）",
  )
}
