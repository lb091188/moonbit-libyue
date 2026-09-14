// 输入与选择页：下拉 / 选择器 / 日期 / GIF / 多行文本编辑操作 / 气泡。

///|
fn page_inputs() -> @yue.Node {
  let combo_pick : @yue.Store[String] = @yue.Store::new("MoonBit")
  let picker_pick : @yue.Store[String] = @yue.Store::new("（未选择）")
  let date_val : @yue.Store[Int64] = @yue.Store::new(946684800L)
  let cb : Ref[@yue.ComboBox?] = Ref(None)
  let pk : Ref[@yue.Picker?] = Ref(None)
  let edit : Ref[@yue.TextEdit?] = Ref(None)
  let pop_btn : Ref[@yue.Button?] = Ref(None)
  // 日期选择带选项（仅时分 + 步进器）：DatePicker 的选项参数不在
  // 声明式节点上，用 node_of 从命令式桥进树（两个世界的官方通道）。
  let date = @yue.DatePicker::new_with({ elements: @yue.HourMinute, has_stepper: true })
  date.set_date(946684800L)
  date.on_date_change(fn() { date_val.set(date.get_date()) })
  scroll_page([
    section("下拉组合框", "ComboBox 可编辑：on_select 响应选择、on_input 响应文本变化（取值经 handle）。", [
      @yue.combo(
        items=["MoonBit", "libyue", "GTK"],
        selected=0,
        on_select=fn() { when_some(cb, fn(c) { combo_pick.set(c.get_selected_item()) }) },
        handle=fn(c) { cb.val = Some(c) },
      ),
      @yue.bind_label(combo_pick, fn(s) { "下拉选择：\{s}" }, style=[("marginTop", 8.0)]),
    ]),
    section("只读选择器", "Picker 无输入态，仅从列表选择。", [
      @yue.picker(
        items=["红", "绿", "蓝"],
        on_change=fn() { when_some(pk, fn(p) { picker_pick.set(p.get_selected_item()) }) },
        handle=fn(p) { pk.val = Some(p) },
      ),
      @yue.bind_label(picker_pick, fn(s) { "选择器：\{s}" }, style=[("marginTop", 8.0)]),
    ]),
    section("日期时间选择", "DatePicker 带 HourMinute 元素与步进器；epoch 秒读写（set_date/get_date）。", [
      @yue.node_of(date, style=[("marginBottom", 8.0)]),
      @yue.bind_label(date_val, fn(t) { "当前 epoch 秒：\{t}" }),
    ]),
    section("GIF 播放", "GifPlayer 播放 GIF（示例资产 examples/advanced/dot.gif），无解码器依赖。", [
      @yue.gif(image=Some(@yue.Image::new_from_file("examples/advanced/dot.gif"))),
    ]),
    section("多行文本编辑", "TextEdit 编辑 API：撤销重做 / 剪切复制粘贴 / 选区与插入（按钮经 handle 操作句柄）。", [
      @yue.text_edit(
        text="多行文本…\n试试撤销 / 重做 / 全选 / 插入。",
        handle=fn(t) { edit.val = Some(t) },
        style=[("height", 96.0)],
      ),
      @yue.hbox(
        [
          @yue.button("撤销", on_click=fn() { when_some(edit, fn(t) { t.undo() }) }),
          @yue.button("重做", on_click=fn() { when_some(edit, fn(t) { t.redo() }) }),
          @yue.button("全选", on_click=fn() { when_some(edit, fn(t) { t.select_all() }) }),
          @yue.button("剪切", on_click=fn() { when_some(edit, fn(t) { t.cut() }) }),
          @yue.button("粘贴", on_click=fn() { when_some(edit, fn(t) { t.paste() }) }),
          @yue.button("插入一行", on_click=fn() { when_some(edit, fn(t) { t.insert_text("\n（插入）") }) }),
          @yue.button("清空", on_click=fn() { when_some(edit, fn(t) { t.delete() }) }),
        ],
        style=[("marginTop", 8.0)],
      ),
    ]),
    section("气泡 Popover", "点击按钮在按钮旁弹出。平台实现不同：Linux 原生气泡；Windows 右下弹出 8 秒自动关闭；macOS 不自动关。", [
      @yue.button(
        "弹出气泡",
        handle=fn(b) { pop_btn.val = Some(b) },
        on_click=fn() {
          when_some(pop_btn, fn(b) {
            let pop = @yue.Popover::new()
            let tip = @yue.Label::new("这是一个 Popover 气泡")
            tip.set_style("padding", 10.0)
            pop.set_content(tip)
            pop.set_content_size(180.0, 44.0)
            pop.show_relative_to(b)
          })
        },
      ),
    ]),
  ])
}
