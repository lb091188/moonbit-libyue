// View 级接口白盒测试:需要真实控件的路径仅在 DISPLAY 存在时执行
// (与 charts_wbtest 的两级模式一致,CI 无显示环境保持绿)。

///|
test "native_handle_view:有显示环境时返回非 0 原生句柄" {
  let display = @env.get_env_var("DISPLAY")
  if display.unwrap_or("") == "" {
    println("native_handle: skip (no DISPLAY)")
    return
  }
  if !initialize() {
    println("native_handle: skip (init failed)")
    return
  }
  let label = Label::new("handle probe")
  let h = native_handle_view(label.view)
  inspect(h > 0, content="true")
}

///|
test "set_selectable:有显示环境时开关不崩(功能视觉验证归真机清单)" {
  let display = @env.get_env_var("DISPLAY")
  if display.unwrap_or("") == "" {
    println("set_selectable: skip (no DISPLAY)")
    return
  }
  if !initialize() {
    println("set_selectable: skip (init failed)")
    return
  }
  let label = Label::new("可选择文本")
  label.set_selectable(true)
  label.set_selectable(false)
  inspect(label.get_text(), content="可选择文本")
}
