// 命令与状态页:设置类(可执行)操作以 label + tag 展示命令文本与
// 性质,不真实执行;只读状态按数据形态选控件并真实读取当前值——
// 布尔用 checkbox、枚举用 radio、文本用 label,均只读展示。关机 /
// 重启 / 注销等危险操作不提供任何入口。
// 文案约定:命令表按平台分流(Linux 侧 CLI / Windows 侧命令),只写通用
// 概念;后端 API 名与探测降级差异见 docs/zh/adaptation.md。
// 电源计划展示名 pp_display 与「系统能力」页同源(见 sysinfo.mbt)。

///|
pub fn page_cmdpreview(_app : @ui.ProbeApp) -> @yue.Node {
  // 可执行组:命令文本 + 性质 tag(按平台分流,均为真实存在的命令形态)
  let exec_items : Array[(String, @components.SemanticType, String)] =
    if @yue.platform() == "windows" {
      [
        (
          "powercfg /setactive <方案 GUID>", @components.Warning,
          "有副作用 · 需管理员",
        ),
        (
          "tzutil /s \"<时区键名>\"", @components.Warning,
          "有副作用 · 需管理员",
        ),
        (
          "print /D:<打印机> <文件路径>", @components.Danger,
          "有副作用 · 真实出纸",
        ),
      ]
    } else {
      [
        (
          "powerprofilesctl set balanced", @components.Warning, "有副作用 · 需认证",
        ),
        (
          "timedatectl set-timezone Asia/Tokyo", @components.Info,
          "等价:写系统时区属性",
        ),
        (
          "bluetoothctl power off", @components.Info, "等价:开关适配器电源",
        ),
        (
          "bluetoothctl scan on", @components.Info, "等价:开始扫描",
        ),
        (
          "playerctl -p <实例名> play-pause", @components.Info,
          "等价:播放/暂停",
        ),
        (
          "udisksctl mount -b /dev/sdX1", @components.Warning, "有副作用 · 真实挂载",
        ),
        (
          "udisksctl unmount -b /dev/sdX1", @components.Warning, "有副作用 · 真实卸载",
        ),
        (
          "lp -d <打印机> -n <份数> <文件路径>", @components.Danger, "有副作用 · 真实出纸",
        ),
      ]
    }
  // 只读组:挂载时真实读取一次当前值
  let pp_node : @yue.Node = match @system.pp_current() {
    Ok(p) =>
      @components.radio_group(
        ["性能", "均衡", "省电"],
        @yue.Store::new(pp_display(p)),
        disabled=true,
      )
    Err(_) =>
      @components.label_t("电源计划: 当前环境不可用", role=@components.Secondary)
  }
  let bt_nodes : Array[@yue.Node] = match @system.bt_adapter_info() {
    Ok(a) =>
      [
        @components.checkbox_t("蓝牙适配器电源", checked=a.powered, disabled=true),
        @components.checkbox_t("正在扫描", checked=a.discovering, disabled=true),
      ]
    Err(_) =>
      [
        @components.label_t(
          "蓝牙适配器: 当前环境不可用",
          role=@components.Secondary,
        ),
      ]
  }
  let ntp_node : @yue.Node = match @system.lc_ntp() {
    Ok(b) => @components.checkbox_t("NTP 时间同步", checked=b, disabled=true)
    Err(_) =>
      @components.label_t("NTP 时间同步: 当前环境不可用", role=@components.Secondary)
  }
  let tz_node : @yue.Node = match @system.lc_timezone() {
    Ok(tz) => @components.label_t("当前时区:\{tz}")
    Err(_) =>
      @components.label_t("当前时区: 当前环境不可用", role=@components.Secondary)
  }
  @ui.page_shell(
    "命令与状态",
    "可执行(设置类)操作以 label + tag 展示命令文本与性质,点击不执行;只读状态按数据形态选控件并真实读取当前值:布尔 → checkbox、枚举 → radio、文本 → label(均只读)。关机 / 重启 / 注销等危险操作不提供任何入口;只读查询全量见「系统能力」页。",
    fn(_refresh) {
      let body : Array[@yue.Node] = []
      body.push(
        @components.label_t("可执行 · 仅展示命令文本", role=@components.Section),
      )
      for it in exec_items {
        body.push(
          @declarative.hbox(
            style=[("alignItems", "center"), ("marginBottom", 6.0)],
            [
              @components.label_t(it.0, style=[("flex", 1.0)]),
              @components.tag_of_type(it.2, it.1),
            ],
          ),
        )
      }
      body.push(
        @components.label_t("只读状态 · 真实读取当前值", role=@components.Section, style=[("marginTop", 16.0)]),
      )
      body.push(pp_node)
      for n in bt_nodes {
        body.push(n)
      }
      body.push(ntp_node)
      body.push(tz_node)
      body
    },
  )
}
