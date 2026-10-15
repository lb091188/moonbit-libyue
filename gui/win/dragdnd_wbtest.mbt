// W23 拖放后端的环境读数：有显示服务时挂接/幂等/计数/效果写回真读数，无头
// 环境打印跳过（与 taskbar/notify 的环境分支同款口径）。跨进程真拖（Windows
// OLE、Linux XDND）归真机清单 S26/S27——协议互操作单测自洽不算数（规则 5）；
// Windows 侧另有 experiment/drag_probe 的纯 C 探针，Linux 侧 XDND 的 motion 由
// 指针驱动、合成不了跨进程拖拽，API 用法正确性靠这里与冒烟/真机覆盖。

///|
test "拖放后端：挂接幂等与计数（有显示环境）" {
  if dragdnd_supported() {
    assert_true(wm_init() != 0)
    let id = wm_window_new(120, 80, @utf8.encode("dnd-test"))
    assert_true(id > 0)
    assert_eq(dragdnd_count(), 0)
    assert_true(dragdnd_enable(id))
    assert_true(dragdnd_enable(id)) // 幂等：重复挂仍给 true
    assert_eq(dragdnd_count(), 1)
    assert_eq(dragdnd_effect(id), 0) // 挂上未有会话读 0（承诺 COPY 随 ENTER 置，Windows/GTK 同口径）
    dragdnd_set_effect(id, 1)
    assert_eq(dragdnd_effect(id), 1) // MoonBit 写回读得回
    dragdnd_disable(id)
    assert_eq(dragdnd_count(), 0)
    assert_eq(dragdnd_effect(id), -1) // 撤销后读回 -1
    // 再挂再撤一轮：槽位复用不受上一轮影响
    assert_true(dragdnd_enable(id))
    assert_eq(dragdnd_count(), 1)
    dragdnd_disable(id)
    wm_close(id)
  } else {
    println("dragdnd: skip（本机无显示服务）")
  }
}
