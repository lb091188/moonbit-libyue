// 托盘与通知页：后端探测 / 点击联动 / 主题图标(仅 Linux) / 桌面通知。

///|
fn page_tray() -> @yue.Node {
  let tray_desc = if is_linux() {
    "Linux：纯 MoonBit SNI 协议栈直连面板（方案见 docs/tray.md）；watcher 不在线时回退 AppIndicator，两者皆无返回 Err(Unsupported)。"
  } else if is_windows() {
    "Windows：原生 Shell_NotifyIconW 后端；set_title 为空操作（libyue 无对应概念）。"
  } else {
    "macOS：原生托盘后端。"
  }
  let notify_desc = if is_windows() {
    "Windows：WinRT toast，首次发送自动注册 AUMID（写注册表）；横幅可能被专注助手抑制。"
  } else if is_macos() {
    "macOS：经用户通知中心发送。"
  } else {
    "Linux：经 org.freedesktop.Notifications 的 Notify 调用（libyue 的 AddNotification 从不发 DBus，shim 已统一到 Show）；actions 经 libnotify 生效。"
  }
  let secs : Array[@yue.Node] = [
    section("托盘状态", tray_desc, [
      @yue.bind_label(tray_info, fn(s) { s }),
      @yue.bind_label(
        tray_clicks,
        fn(n) {
          "托盘图标已被点击 \{n} 次（左键 Activate / 点击）"
        },
        style=[("marginTop", 8.0)],
      ),
    ]),
    section("桌面通知", notify_desc, [
      @yue.hbox(
        [
          @yue.button("发通知（带按钮）", on_click=fn() {
            let n = @yue.Notification::new()
            n.set_title("来自 Showcase")
            n.set_body("桌面通知正常工作 ✓（带两个按钮）")
            n.set_actions([("查看", "view"), ("忽略", "ignore")])
            n.show()
          }),
          @yue.button("发静默通知", on_click=fn() {
            let n = @yue.Notification::new()
            n.set_title("静默通知")
            n.set_body("set_silent(true)：不发声不打扰")
            n.set_silent(true)
            @yue.NotificationCenter::add(n)
          }),
        ],
        style=[("marginBottom", 8.0)],
      ),
    ]),
  ]
  // 仅 Linux SNI 后端支持主题图标名与悬浮提示；其余平台为空操作，整段不创建
  if is_linux() {
    secs.push(
      section(
        "主题图标与悬浮提示（仅 Linux SNI）",
        "set_icon_name 跟随系统主题（如 utilities-terminal）；set_tooltip 设悬浮提示。其他平台为空操作，故整段只在 Linux 出现。",
        [
          @yue.hbox(
            [
              @yue.button("主题图标 utilities-terminal", on_click=fn() {
                when_some(tray_ref, fn(t) {
                  t.set_icon_name("utilities-terminal")
                })
              }),
              @yue.button("更新悬浮提示", on_click=fn() {
                when_some(tray_ref, fn(t) {
                  t.set_tooltip(
                    "moonbit-libyue", "悬浮提示更新于演示按钮",
                  )
                })
              }),
            ],
            style=[("marginBottom", 8.0)],
          ),
        ],
      ),
    )
  }
  scroll_page(secs)
}
