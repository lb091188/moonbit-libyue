// 表格页：说明 + 独立子窗口入口（Linux 下 Table 进 Notebook 会崩溃）。

///|
fn page_table() -> @yue.Node {
  let desc = if is_linux() {
    "Linux(GTK) 下 Table 放进 Notebook 页签测量尺寸会触发崩溃，因此演示放独立子窗口；TableModel 是 trait，数据与视图分离，可编辑列通过 set_value 回写。"
  } else {
    "TableModel 是 trait，数据与视图分离，可编辑列通过 set_value 回写；为跨平台一致，演示放独立子窗口。"
  }
  scroll_page([
    section("表格 Table", desc, [
      @yue.label_t(
        "列类型：Text / Edit（可编辑回写）/ Checkbox（勾选回写）/ Custom（自绘列）；行激活与选择变化有事件回调。",
        role=@yue.Secondary,
        style=[("marginBottom", 8.0)],
      ),
      @yue.button("打开表格演示窗口", on_click=fn() {
        open_table_window()
      }),
    ]),
  ])
}
