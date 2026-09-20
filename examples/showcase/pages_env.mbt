// 环境与平台页:运行环境快照。键盘钩子写在窗口 handle(main),状态
// key_info 经 App 共享到这里显示。

///|
fn page_env(app : App) -> @yue.Node {
  scroll_page([
    section(
      "平台与屏幕",
      "运行环境查询 API(本次启动快照);主屏尺寸 / 缩放因子影响布局与自绘尺寸。",
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
      ],
    ),
    section(
      "外观与能力",
      "主题切换深浅由系统偏好驱动;各子系统能力差异由 libyue 按平台自动降级。",
      [
        @yue.descriptions([
          ("深浅主题", "启动跟随系统,切换即时生效(自绘组件重绘 + 原生 CSS 重建)"),
          ("拖拽", "Linux 源端信号修复 + X11 press timestamp 抓取,Thunar/桌面落文件成功"),
          ("滚动条", "GTK overlay 悬浮式:空闲隐形、悬停/拖拽浮现,不占内容宽度"),
          ("原生控件", "Linux 输入框 / 多行 / 滚动条 / 窗口底色由主题 CSS 接管"),
        ]),
      ],
    ),
    section(
      "键盘钩子与平台差异",
      "窗口级 on_key_down 全局生效(按任意键试试);差异清单完整记录见 docs/zh/adaptation.md。",
      [
        @yue.bind_label(app.key_info, fn(s) { "最后按键:\{s}" }, style=[("marginBottom", 8.0)]),
        @yue.label_t("· 托盘:Linux SNI 直连 / Windows Shell_NotifyIconW / macOS 原生", role=@yue.Secondary),
        @yue.label_t("· 通知:Linux 必须走 Show()(DBus Notify)/ Windows WinRT toast", role=@yue.Secondary),
        @yue.label_t("· 剪贴板主选区 Selection:仅 X11 存在", role=@yue.Secondary),
        @yue.label_t("· 浏览器自定义协议:Linux 可用,Windows WebView2 静默无效", role=@yue.Secondary),
        @yue.label_t("· 富文本范围属性:Windows 降级为全文应用", role=@yue.Secondary),
      ],
    ),
  ])
}
