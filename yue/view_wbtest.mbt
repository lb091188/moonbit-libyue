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

