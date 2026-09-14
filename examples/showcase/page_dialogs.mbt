// 对话框与消息页：文件打开 / 保存 + 文件读写 + 消息框。

///|
fn page_dialogs() -> @yue.Node {
  let open_result : @yue.Store[String] = @yue.Store::new("（结果）")
  let msg_desc = if is_windows() {
    "Windows 上 MessageBox 是 TaskDialog（依赖的 comctl v6 清单已由库内嵌）；按钮响应回传 id。"
  } else if is_macos() {
    "macOS 上 set_title 无效、show 为模态（阻塞至关闭，回调照常）；按钮响应回传 id。"
  } else {
    "GTK 消息框：支持标题 / 正文 / 附加信息与多按钮 on_response。"
  }
  scroll_page([
    section("打开文件", "FileDialog 过滤器 + 多选；run_for_window 模态至选择；read_text_file 直读内容。", [
      @yue.button(
        "打开文件…",
        on_click=fn() {
          when_some(main_win, fn(w) {
            let dlg = @yue.FileDialog::new_open()
            dlg.set_filters("文本文件:txt,md|所有文件:*")
            dlg.set_options(@yue.FILE_OPTION_MULTI_SELECT)
            if dlg.run_for_window(w) {
              let path = dlg.get_result()
              let desc = match @yue.read_text_file(path) {
                Some(c) => "\{c.length()} 字符"
                None => "读取失败"
              }
              open_result.set("已选 \{path}（\{desc}）")
            } else {
              open_result.set("已取消")
            }
          })
        },
      ),
      @yue.bind_label(open_result, fn(s) { s }, style=[("marginTop", 8.0)]),
    ]),
    section("保存文件", "new_save + set_filename；write_text_file 直写内容，返回是否成功。", [
      @yue.button(
        "保存文件…",
        on_click=fn() {
          when_some(main_win, fn(w) {
            let dlg = @yue.FileDialog::new_save()
            dlg.set_filename("showcase.txt")
            if dlg.run_for_window(w) {
              let ok = @yue.write_text_file(dlg.get_result(), "由 showcase 写入\n")
              open_result.set("保存 \{dlg.get_result()}：ok=\{ok}")
            } else {
              open_result.set("已取消")
            }
          })
        },
      ),
    ]),
    section("消息框", msg_desc, [
      @yue.button(
        "弹出消息框（两个按钮）",
        on_click=fn() {
          when_some(main_win, fn(w) {
            let box = @yue.MessageBox::new(@yue.Information)
            box.set_title("消息框")
            box.set_text("这是一个 MessageBox")
            box.set_informative_text("点哪个按钮，响应 id 就显示在下方。")
            box.add_button("好的", 1)
            box.add_button("取消", 2)
            box.on_response(fn(code) { open_result.set("消息框响应 id=\{code}") })
            box.show_for_window(w)
          })
        },
      ),
    ]),
  ])
}
