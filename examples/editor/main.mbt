// 复刻自 yue-sample-apps/editor：菜单栏 + 侧栏按钮 + 文件打开/保存 + TextEdit。
// 偏离：图片按钮改为文字按钮（不引入图片资源依赖）；Vibrant 跳过（macOS 专属）。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  // 菜单：File/Quit(Ctrl+Q) + Edit 角色项
  let menubar = @yue.MenuBar::new()
  let file_menu = menubar.add_menu("File")
  let quit = file_menu.add_label_item("Quit")
  quit.set_accelerator("CmdOrCtrl+Q")
  quit.on_click(fn() { @yue.quit() })
  let edit_menu = menubar.add_menu("Edit")
  let _ = edit_menu.add_role_item(@yue.Copy)
  let _ = edit_menu.add_role_item(@yue.Cut)
  let _ = edit_menu.add_role_item(@yue.Paste)
  let _ = edit_menu.add_role_item(@yue.SelectAll)
  let _ = edit_menu.add_separator()
  let _ = edit_menu.add_role_item(@yue.Undo)
  let _ = edit_menu.add_role_item(@yue.Redo)

  let win = @yue.Window::new()
  win.set_content_size(400.0, 400.0)
  win.on_close(fn(_window) { @yue.quit() })

  let content = @yue.Container::new()
  content.set_style_str("flexDirection", "row")
  win.set_content(content)

  let sidebar = @yue.Container::new()
  sidebar.set_style("padding", 5.0)
  content.add_child(sidebar)

  let edit = @yue.TextEdit::new()
  content.set_background_color("#F00")
  edit.set_style("flex", 1.0)
  content.add_child(edit)

  // 文件状态
  let folder = Ref("")
  let filename = Ref("")

  let open = @yue.Button::new("打开")
  open.set_style("marginBottom", 5.0)
  open.on_click(fn() {
    let dialog = @yue.FileDialog::new_open()
    dialog.set_filters("All Files:*|JavaScript Files:js")
    if dialog.run_for_window(win) {
      let path = dialog.get_result()
      match @yue.read_text_file(path) {
        Some(text) => {
          edit.set_text(text)
          edit.focus()
          let parts = path.split("/").collect()
          win.set_title(parts[parts.length() - 1].to_owned())
        }
        None => println("读取失败：\{path}")
      }
    }
  })
  sidebar.add_child(open)

  let save = @yue.Button::new("保存")
  save.on_click(fn() {
    if folder.val != "" {
      let dialog = @yue.FileDialog::new_save()
      dialog.set_folder(folder.val)
      dialog.set_filename(filename.val)
      if dialog.run_for_window(win) {
        let ok = @yue.write_text_file(dialog.get_result(), edit.get_text())
        if !ok {
          println("保存失败")
        }
      }
    }
  })
  sidebar.add_child(save)

  win.set_menubar(menubar)
  win.center()
  win.activate()
  @yue.run()
}
