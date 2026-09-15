// 环境信息页：全平台环境查询 + 桌面环境(仅 Linux) / 平台说明(按平台) +
// 平台差异速览。

///|
fn page_env() -> @yue.Node {
  let secs : Array[@yue.Node] = [
    section(
      "运行环境",
      "全部平台可用的环境查询 API（值为本次启动的快照）。",
      [
        @yue.label("platform = \{@yue.platform()}"),
        @yue.label("locale = \{@yue.locale()}"),
        @yue.label("深色模式 is_dark = \{@yue.Appearance::is_dark()}"),
        @yue.label("屏幕缩放 scale_factor = \{@yue.Screen::scale_factor()}"),
        @yue.label(
          "主屏尺寸 = \{@yue.Screen::primary_size().0} × \{@yue.Screen::primary_size().1}",
        ),
        @yue.label("应用名 = \{@yue.App::get_name()}"),
      ],
    ),
  ]
  // 桌面环境是 Linux 专属概念（XDG_CURRENT_DESKTOP）：
  // 非 Linux 平台整段不创建
  if is_linux() {
    secs.push(
      section(
        "桌面环境（仅 Linux）",
        "XDG_CURRENT_DESKTOP 识别 + 托盘后端可用性；Windows/macOS 没有桌面环境差异，本段不存在。",
        [
          @yue.label("desktop_environment = \{@yue.desktop_environment()}"),
          @yue.label("托盘可用 is_supported = \{@yue.Tray::is_supported()}"),
          @yue.label(
            "方案文档：docs/tray.md（SNI 直连面板，后端优先级与调试方法）",
          ),
        ],
      ),
    )
  }
  if is_windows() {
    secs.push(
      section(
        "Windows 平台说明（仅 Windows）",
        "本段只在 Windows 下创建。",
        [
          @yue.label("浏览器：优先 WebView2，缺运行时回退 IE"),
          @yue.label(
            "通知：首次发送自动注册 AUMID（写注册表）",
          ),
          @yue.label("Popover：无边框窗口实现，8 秒自动关闭"),
          @yue.label("Group/Scroll：不按内容自增长，需显式高度"),
        ],
      ),
    )
  }
  if is_macos() {
    secs.push(
      section(
        "macOS 平台说明（仅 macOS）",
        "本段只在 macOS 下创建。",
        [
          @yue.label(
            "窗口级菜单栏不可用（菜单挂 App 级，set_menubar 被忽略）",
          ),
          @yue.label("MessageBox.set_title 无效；show 为模态"),
          @yue.label("Window::new_with_options 的 no_activate 被忽略"),
        ],
      ),
    )
  }
  secs.push(
    section(
      "平台差异速览",
      "本仓已文档化的主要平台差异；完整清单与实测记录见 docs/adaptation.md。",
      [
        @yue.label(
          "· 托盘：Linux SNI 直连 / Windows Shell_NotifyIconW / macOS 原生",
        ),
        @yue.label(
          "· 通知：Linux 必须走 Show()（DBus Notify）/ Windows WinRT toast",
        ),
        @yue.label("· 剪贴板主选区 Selection：仅 X11 存在"),
        @yue.label(
          "· 浏览器自定义协议：Linux 可用，Windows WebView2 静默无效",
        ),
        @yue.label("· 富文本范围属性：Windows 降级为全文应用"),
        @yue.label(
          "· VKEY 常量取 GTK 键值表，跨平台对齐在各平台目标里做",
        ),
      ],
    ),
  )
  scroll_page(secs)
}
