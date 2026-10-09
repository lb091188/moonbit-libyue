// 命令与状态页:设置类(可执行)操作以 label + tag 展示命令文本与
// 性质,不真实执行;只读状态按数据形态选控件并真实读取当前值——
// 布尔用 checkbox、枚举用 radio、文本用 label,均只读展示。关机 /
// 重启 / 注销等危险操作不提供任何入口。

///|
pub fn page_cmdpreview(_app : @ui.ProbeApp) -> @yue.Node {
  // 可执行组:命令文本 + 性质 tag
  let exec_items : Array[(String, @components.SemanticType, String)] = [
    (
      "powerprofilesctl set balanced", @components.Warning, "有副作用 · 需认证",
    ),
    (
      "timedatectl set-timezone Asia/Tokyo", @components.Info,
      "等价:写 timedate1.Timezone 属性",
    ),
    (
      "bluetoothctl power off", @components.Info, "等价:写 Adapter1.Powered 属性",
    ),
    (
      "bluetoothctl scan on", @components.Info, "等价:Adapter1.StartDiscovery 方法",
    ),
    (
      "playerctl -p <实例名> play-pause", @components.Info,
      "等价:MPRIS Player.PlayPause",
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
  // 只读组:挂载时真实读取一次当前值
  let pp_node : @yue.Node = match @system.pp_current() {
    Ok(p) =>
      @components.radio_group(
        ["性能(performance)", "均衡(balanced)", "省电(power-saver)"],
        @yue.Store::new(pp_display(p)),
        disabled=true,
      )
    Err(e) =>
      @components.label_t("电源计划读取失败: \{e}", role=@components.Secondary)
  }
  let bt_nodes : Array[@yue.Node] = match @system.bt_adapter_info() {
    Ok(a) =>
      [
        @components.checkbox_t("蓝牙适配器电源", checked=a.powered, disabled=true),
        @components.checkbox_t("正在扫描", checked=a.discovering, disabled=true),
      ]
    Err(e) =>
      [
        @components.label_t(
          "蓝牙适配器读取失败: \{e}",
          role=@components.Secondary,
        ),
      ]
  }
  let ntp_node : @yue.Node = match @system.lc_ntp() {
    Ok(b) => @components.checkbox_t("NTP 时间同步", checked=b, disabled=true)
    Err(e) =>
      @components.label_t("NTP 状态读取失败: \{e}", role=@components.Secondary)
  }
  let tz_node : @yue.Node = match @system.lc_timezone() {
    Ok(tz) => @components.label_t("当前时区:\{tz}")
    Err(e) =>
      @components.label_t("时区读取失败: \{e}", role=@components.Secondary)
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
