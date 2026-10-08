// 命令预览页:设置类操作的命令预览按钮组,点击只把将执行的命令文本
// 写进报告标签,不真实执行;关机/重启/注销等危险操作不提供按钮。

///|
pub fn page_cmdpreview(_app : @ui.ProbeApp) -> @yue.Node {
  let cmd_report : Ref[@yue.Label?] = Ref(None)
  let items : Array[(String, String)] = [
    (
      "预览:切换电源计划(均衡)",
      "powerprofilesctl set balanced   # 有副作用(需认证),此处仅展示命令文本",
    ),
    (
      "预览:设置系统时区(Asia/Tokyo)",
      "timedatectl set-timezone Asia/Tokyo   # 等价于写 timedate1.Timezone 属性",
    ),
    (
      "预览:关闭蓝牙适配器电源",
      "bluetoothctl power off   # 等价于写 org.bluez.Adapter1.Powered=false",
    ),
    (
      "预览:开始蓝牙扫描",
      "bluetoothctl scan on   # 等价于调用 org.bluez.Adapter1.StartDiscovery",
    ),
    (
      "预览:媒体播放/暂停(首个播放器)",
      "playerctl -p <播放器实例名> play-pause   # 等价于 MPRIS Player.PlayPause",
    ),
    (
      "预览:挂载 U 盘",
      "udisksctl mount -b /dev/sdX1   # 等价于 udisks2 Filesystem.Mount",
    ),
    (
      "预览:卸载 U 盘",
      "udisksctl unmount -b /dev/sdX1   # 等价于 udisks2 Filesystem.Unmount",
    ),
    (
      "预览:提交打印任务",
      "lp -d <打印机名> -n <份数> <文件路径>   # 有副作用(真实排队打印),此处仅展示命令文本",
    ),
  ]
  @ui.page_shell(
    "设置类命令预览",
    "只展示将执行的命令文本,不真实执行。关机/重启/注销等危险操作不提供任何入口;其只读查询(会话列表、允许关机/重启)见「系统能力」页快照。",
    fn(refresh) {
      let body : Array[@yue.Node] = []
      for it in items {
        let text = it.0
        let cmd = it.1
        body.push(
          @yue.button_t(
            text,
            variant=@yue.Solid,
            on_click=fn() {
              match cmd_report.val {
                Some(l) => {
                  l.set_text(cmd)
                  // 命令文本写入后刷新滚动范围(挂载后才长高的内容)
                  refresh()
                }
                None => ()
              }
            },
            style=[("alignSelf", "flex-start")],
          ),
        )
      }
      body.push(
        @yue.label_t(
          "(点击预览按钮后此处显示命令文本)",
          role=@yue.Body,
          handle=fn(l) { cmd_report.val = Some(l) },
        ),
      )
      body
    },
  )
}
