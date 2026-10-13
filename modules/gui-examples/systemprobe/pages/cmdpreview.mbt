// 命令与状态页（G7 新栈版）。与 master 旧页的差：
// ① 设置类（可执行）操作依旧只展示命令文本 + 性质 tag，点击不执行；
//    关机/重启/注销等危险操作不提供任何入口——口径不变。
// ② 只读组：本栈已平移的只有电源计划（@sys.pp_current）；蓝牙适配器、
//    NTP/时区三族未平移，以说明行替代（随各自能力批补齐）。
// ③ tag 走 @ui.tag_of_type，radio_group 的状态从文本 Store 换 Int 索引。

///|
/// 命令与状态页。
pub fn page_cmdpreview(_app : @shared.ProbeApp) -> @core.Node {
  // 可执行组：命令文本 + 性质 tag
  let exec_items : Array[(String, @ui.SemanticType, String)] = [
    (
      "powerprofilesctl set balanced", @ui.Warning, "有副作用 · 需认证",
    ),
    (
      "timedatectl set-timezone Asia/Tokyo", @ui.Info,
      "等价:写 timedate1.Timezone 属性",
    ),
    (
      "bluetoothctl power off", @ui.Info, "等价:写 Adapter1.Powered 属性",
    ),
    (
      "bluetoothctl scan on", @ui.Info, "等价:Adapter1.StartDiscovery 方法",
    ),
    (
      "playerctl -p <实例名> play-pause", @ui.Info,
      "等价:MPRIS Player.PlayPause",
    ),
    (
      "udisksctl mount -b /dev/sdX1", @ui.Warning, "有副作用 · 真实挂载",
    ),
    (
      "udisksctl unmount -b /dev/sdX1", @ui.Warning, "有副作用 · 真实卸载",
    ),
    (
      "lp -d <打印机> -n <份数> <文件路径>", @ui.Danger, "有副作用 · 真实出纸",
    ),
  ]
  // 只读组：挂载时真实读取一次当前值（电源计划 → radio 索引）
  let pp_idx : @core.Store[Int] = @core.Store::new(-1)
  let pp_note : @core.Store[String] = @core.Store::new("（挂载时读取）")
  fn read_pp() -> Unit {
    match @sys.pp_current() {
      Ok(p) => {
        let i = match p {
          @sys.PPerformance => 0
          @sys.PBalanced => 1
          @sys.PPowerSaver => 2
        }
        pp_idx.set(i)
        pp_note.set("当前计划已读取（只读展示）")
      }
      Err(e) => {
        pp_idx.set(-1)
        pp_note.set("电源计划读取失败: \{e}")
      }
    }
  }
  let body : Array[@core.Node] = []
  body.push(@ui.label_t("可执行 · 仅展示命令文本", role=@ui.Section))
  for it in exec_items {
    body.push(
      @ui.row(
        [
          @ui.label_t(it.0, handle=fn(w) { w.node.set_flex_grow(1.0) }),
          @ui.tag_of_type(it.2, it.1),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
    )
  }
  body.push(@ui.label_t("只读状态 · 真实读取当前值", role=@ui.Section))
  body.push(
    @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
      read_pp()
      w
    }),
  )
  body.push(
    @ui.bind_label(pp_note, fn(s) {
      if pp_idx.get() >= 0 {
        let names = [
          "性能(performance)", "均衡(balanced)", "省电(power-saver)",
        ]
        "\{s}：\{names[pp_idx.get()]}"
      } else {
        s
      }
    }),
  )
  body.push(
    @ui.label_t(
      "蓝牙适配器 / NTP 时间同步 / 当前时区：本栈尚未平移这三族只读探针（旧链 Linux 专属），以说明替代。",
      role=@ui.Secondary,
    ),
  )
  @shared.page([
    @shared.section(
      "命令与状态",
      "命令与状态",
      "可执行（设置类）操作以 label + tag 展示命令文本与性质，点击不执行；只读状态按数据形态真实读取当前值。关机 / 重启 / 注销等危险操作不提供任何入口；只读查询全量见「系统能力」页。",
      body,
      code=[
        "// 可执行组：label + tag，点击不执行",
        "@ui.row([@ui.label_t(cmd), @ui.tag_of_type(note, @ui.Warning)])",
        "// 只读组：挂载时真调一次",
        "match @sys.pp_current() {",
        "  Ok(p) => pp_idx.set(match p { @sys.PBalanced => 1 ... })",
        "  Err(e) => pp_note.set(\"读取失败: \\{e}\")",
        "}",
      ],
    ),
  ])
}
