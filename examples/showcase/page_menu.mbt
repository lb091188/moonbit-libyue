// 菜单与快捷键页：菜单栏说明 / 右键弹出菜单 / 菜单遍历 / 全局快捷键。

///|
fn page_menu() -> @yue.Node {
  let popup_area : Ref[@yue.Container?] = Ref(None)
  let shortcut_id : Ref[Int?] = Ref(None)
  let shortcut_desc = if is_linux() {
    "全局快捷键走 X11 XGrabKey：组合键被系统/桌面占用时注册返回 -1；另有「焦点在桌面时不触发」的已知表现。"
  } else if is_windows() {
    "Windows 全局快捷键经 RegisterHotKey，实测正常。"
  } else {
    "全局快捷键随平台 API 实现。"
  }
  scroll_page([
    section("菜单栏", "窗口顶部菜单栏由 mount_window 的 handle 命令式挂载：role 项（编辑菜单）、加速键、分隔线都在 build_menubar；「演示→遍历本菜单结构」的结果显示在下面。", [
      @yue.bind_label(menu_info, fn(s) { s }),
    ]),
    section("右键弹出菜单", "在蓝色区按下鼠标右键（键位号显示在提示行，GTK 惯例右键为 3），Menu::popup_at 在指针位置弹出自建菜单。", [
      @yue.container(
        handle=fn(c) {
          popup_area.val = Some(c)
          c.on_mouse_down(fn(e) {
            if e.button == 3 {
              let menu = @yue.Menu::new()
              let item_a = menu.add_label_item("弹出菜单项甲")
              item_a.on_click(fn() { menu_info.set("弹出菜单：甲被点击") })
              let _ = menu.add_separator()
              let _item_b = menu.add_label_item("弹出菜单项乙")
              menu.popup_at(e.view_x, e.view_y)
            }
            mouse_btn(e.button)
            false
          })
        },
        style=[("height", 72.0), ("marginBottom", 8.0)],
        style_str=[("backgroundcolor", "#3A5F8A")],
      ),
      @yue.bind_label(menu_info, fn(s) { s }, style=[("marginTop", 8.0)]),
    ]),
    section("全局快捷键", shortcut_desc, [
      @yue.hbox(
        [
          @yue.button(
            "注册 Ctrl+Alt+K",
            on_click=fn() {
              if shortcut_id.val is Some(_) {
                shortcut_info.set("已注册过，先反注册")
              } else {
                let id = @yue.register_global_shortcut("Ctrl+Alt+K", fn() {
                  shortcut_info.set("Ctrl+Alt+K 触发！（全局生效，无需聚焦）")
                })
                shortcut_id.val = Some(id)
                if id == -1 {
                  shortcut_id.val = None
                  shortcut_info.set("注册失败：组合键被系统占用")
                } else {
                  shortcut_info.set("已注册 id=\{id}")
                }
              }
            },
          ),
          @yue.button(
            "反注册",
            on_click=fn() {
              match shortcut_id.val {
                Some(id) => {
                  @yue.unregister_global_shortcut(id)
                  shortcut_info.set("已反注册 id=\{id}")
                  shortcut_id.val = None
                }
                None => shortcut_info.set("尚未注册")
              }
            },
          ),
        ],
        style=[("marginBottom", 8.0)],
      ),
      @yue.bind_label(shortcut_info, fn(s) { s }),
    ]),
  ])
}

///|
/// 记录按下键位号（区分左/中/右键，GTK 惯例 1/2/3）。
fn mouse_btn(button : Int) -> Unit {
  if button != 3 {
    menu_info.set("按下键位 \{button}（右键为 3）")
  }
}
