// 环境与平台页:运行环境快照。键盘钩子写在窗口 handle(main),状态
// key_info 经 App 共享到这里显示。

///|
fn page_env(app : App) -> @yue.Node {
  scroll_page([
    section(
      "运行环境",
      "环境查询 API(本次启动快照);键盘钩子显示窗口级 on_key_down(按任意键试试)。",
      [
        @yue.label_t("platform = \{@yue.platform()}", role=@yue.Body),
        @yue.label_t("locale = \{@yue.locale()}", role=@yue.Body),
        @yue.label_t("深色模式 is_dark = \{@yue.Appearance::is_dark()}", role=@yue.Body),
        @yue.label_t("屏幕缩放 scale_factor = \{@yue.Screen::scale_factor()}", role=@yue.Body),
        @yue.label_t(
          "主屏尺寸 = \{@yue.Screen::primary_size().0} × \{@yue.Screen::primary_size().1}",
          role=@yue.Body,
        ),
        @yue.label_t("应用名 = \{@yue.App::get_name()}", role=@yue.Body),
        @yue.label_t("托盘可用 = \{@yue.Tray::is_supported()}", role=@yue.Body),
        @yue.bind_label(app.key_info, fn(s) { "最后按键:\{s}" }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "平台差异速览",
      "本仓已文档化的主要平台差异;完整清单与实测记录见 docs/zh/adaptation.md。",
      [
        @yue.label_t("· 托盘:Linux SNI 直连 / Windows Shell_NotifyIconW / macOS 原生", role=@yue.Secondary),
        @yue.label_t("· 通知:Linux 必须走 Show()(DBus Notify)/ Windows WinRT toast", role=@yue.Secondary),
        @yue.label_t("· 剪贴板主选区 Selection:仅 X11 存在", role=@yue.Secondary),
        @yue.label_t("· 浏览器自定义协议:Linux 可用,Windows WebView2 静默无效", role=@yue.Secondary),
        @yue.label_t("· 富文本范围属性:Windows 降级为全文应用", role=@yue.Secondary),
      ],
    ),
  ])
}
