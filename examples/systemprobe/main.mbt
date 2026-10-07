// 系统能力与扩展图表演示板。
// 系统能力真实读取本机数据(音量/屏幕亮度/浏览器历史与下载记录/VS Code
// 最近工作区/应用二进制查找/媒体播放状态/显示器/窗口列表/剪贴板文本/
// 磁盘卷/电源与会话/电源计划/系统信息/时区与语言/蓝牙/传感器/打印机/
// 环境变量/浏览器书签/Firefox 历史/GTK 最近文件),点「读取系统能力」后
// 逐段呈现,结果因机而异;设置类操作只提供命令预览(只展示将执行的命令
// 文本,不真实执行),关机/重启/注销等危险操作不提供任何入口。
// 图表为内置演示数据:第一批六种扩展图表(雷达/热力/K 线/漏斗/箱线/
// 桑基)+ 第二批九种新图表(地图/关系图/平行坐标/象形柱/旭日/主题河流/
// 树图/矩形树图/特效散点)+ line/bar/donut 交互版(hover 浮层 / 图例
// 点击显隐 / 滚轮缩放与拖拽平移)。
// 不支持的能力显示对应错误文本,不影响其余部分。

///|
/// 截断文本到前 n 个字符(超出补省略号),用于快照里的单行摘要。
fn trunc_str(s : String, n : Int) -> String {
  if s.length() <= n {
    return s
  }
  let buf = StringBuilder()
  let mut i = 0
  for ch in s {
    if i >= n {
      break
    }
    buf.write_char(ch)
    i = i + 1
  }
  buf.write_string("…")
  buf.to_string()
}

///|
/// 电源计划展示名(与 powerprofilesctl 侧命令名对应)。
fn pp_display(p : @yue.PowerProfile) -> String {
  match p {
    @yue.PPerformance => "性能(performance)"
    @yue.PBalanced => "均衡(balanced)"
    @yue.PPowerSaver => "省电(power-saver)"
  }
}

///|
/// 收集系统能力各模块的当前快照(多行文本):只读查询真调本机;设置类
/// 命令仅文本预览(见命令预览按钮),危险操作无入口。
fn sysprobe_collect() -> String {
  let buf = StringBuilder()
  buf.write_string("== 音量(默认 sink) ==\n")
  match @yue.vol_get() {
    Ok(v) =>
      buf.write_string(
        "sink: \{v.sink}\n音量: \{v.volume}%  静音: \{if v.muted { "是" } else { "否" }}\n",
      )
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 屏幕亮度 ==\n")
  match @yue.brightness_devices() {
    Ok(devs) => {
      if devs.is_empty() {
        buf.write_string("无背光设备\n")
      }
      for d in devs {
        let cur = match @yue.brightness_get(d) {
          Ok(p) => "\{p}%"
          Err(e) => "读取失败(\{e})"
        }
        buf.write_string("\{d.name}(量程 \{d.max}): \{cur}\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 浏览器历史(前 6 条) ==\n")
  match @yue.bh_history(limit=6) {
    Ok(items) => {
      if items.is_empty() {
        buf.write_string("无记录\n")
      }
      for it in items {
        let title = if it.title == "" { "(无标题)" } else { it.title }
        buf.write_string("[\{it.visit_count}次] \{title}\n  \{it.url}\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  match @yue.bh_downloads(limit=3) {
    Ok(items) => {
      buf.write_string("\n== 浏览器下载记录(前 3 条) ==\n")
      if items.is_empty() {
        buf.write_string("无记录\n")
      }
      for d in items {
        buf.write_string(
          "\{d.target_path}  \{d.received_bytes}/\{d.total_bytes} 字节  \{@yue.bh_download_state_name(d.state)}\n",
        )
      }
    }
    Err(_) => ()
  }
  buf.write_string("\n== VS Code 最近工作区(前 8 条) ==\n")
  match @yue.vsc_recent() {
    Ok(paths) => {
      if paths.is_empty() {
        buf.write_string("无记录\n")
      }
      let n = if paths.length() > 8 { 8 } else { paths.length() }
      for i = 0; i < n; i = i + 1 {
        buf.write_string("\{paths[i]}\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 应用二进制查找 ==\n")
  for name in ["sh", "firefox", "code", "google-chrome"] {
    match @yue.appfind_executable(name) {
      Ok(p) => buf.write_string("\{name} -> \{p}\n")
      Err(_) => buf.write_string("\{name} -> 未找到\n")
    }
  }
  buf.write_string("\n== 默认应用查询(只读) ==\n")
  if @yue.da_supported() {
    match @yue.da_file_type("/etc/hostname") {
      Ok(mime) => {
        buf.write_string("/etc/hostname 类型: \{mime}\n")
        match @yue.da_default_for(mime) {
          Ok(d) => buf.write_string("默认应用: \{d}\n")
          Err(@yue.DefaultAppError::NoDefault(_)) => buf.write_string("默认应用: 未登记\n")
          Err(e) => buf.write_string("默认应用查询失败: \{e}\n")
        }
        let htmls = @yue.da_associations_for("text/html")
        if htmls.is_empty() {
          buf.write_string("text/html 关联: 无\n")
        } else {
          buf.write_string("text/html 关联: \{htmls.join(", ")}\n")
        }
      }
      Err(e) => buf.write_string("文件类型查询失败: \{e}\n")
    }
  } else {
    buf.write_string("xdg-mime 不可用,跳过\n")
  }
  // ---- 第二批新模块:只读查询真调,失败只映出错误文本 ----
  buf.write_string("\n== 媒体播放(MPRIS,只读) ==\n")
  match @yue.media_players() {
    Ok(players) => {
      if players.is_empty() {
        buf.write_string("无播放器实例\n")
      }
      for p in players {
        buf.write_string("\{p.identity}(\{p.name})\n")
        match @yue.media_status(p.name) {
          Ok(st) =>
            buf.write_string(
              "  状态: \{st.playback}  标题: \{trunc_str(st.title, 40)}  艺术家: \{trunc_str(st.artist, 20)}  专辑: \{trunc_str(st.album, 20)}\n",
            )
          Err(e) => buf.write_string("  状态读取失败: \{e}\n")
        }
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 显示器(xrandr,只读) ==\n")
  match @yue.mon_current() {
    Ok(outs) => {
      if outs.is_empty() {
        buf.write_string("无已连接输出\n")
      }
      for o in outs {
        buf.write_string(
          "\{o.name}: \{o.width}x\{o.height} @ \{o.refresh_centi / 100}.\{o.refresh_centi % 100}Hz  位置 +\{o.pos_x}+\{o.pos_y}\n",
        )
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  match @yue.mon_list() {
    Ok(mons) => {
      for m in mons {
        let conn = if m.connected { "已连接" } else { "未连接" }
        let prim = if m.primary { "主输出" } else { "非主输出" }
        buf.write_string("\{m.name}: \{conn} \{prim} 支持模式 \{m.modes.length()} 种\n")
      }
    }
    Err(e) => buf.write_string("模式列表不可用: \{e}\n")
  }
  buf.write_string("\n== 窗口列表(wmctrl,只读;前 8 个) ==\n")
  match @yue.win_list() {
    Ok(wins) => {
      if wins.is_empty() {
        buf.write_string("无窗口\n")
      }
      let n = if wins.length() > 8 { 8 } else { wins.length() }
      for i = 0; i < n; i = i + 1 {
        buf.write_string(
          "\{wins[i].id} [桌面 \{wins[i].desktop}] \{trunc_str(wins[i].title, 40)}\n",
        )
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 剪贴板文本(xclip,只读) ==\n")
  match @yue.cbw_get_text() {
    Ok(t) => buf.write_string("当前文本: \{trunc_str(t, 60)}\n")
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 磁盘卷(udisks2/lsblk,只读) ==\n")
  match @yue.dsk_volumes() {
    Ok(vols) => {
      if vols.is_empty() {
        buf.write_string("无卷\n")
      }
      for v in vols {
        let label = if v.label == "" { "" } else { " [\{v.label}]" }
        let mount = match v.mountpoint {
          Some(p) => p
          None => "未挂载"
        }
        let removable = if v.removable { "可移动" } else { "内置" }
        buf.write_string(
          "\{v.device}\{label}  \{v.size_bytes / 1024L / 1024L / 1024L} GiB  \{removable}  挂载点: \{mount}\n",
        )
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 电源(logind,只读) ==\n")
  if @yue.pwrc_supported() {
    match @yue.pwrc_sessions() {
      Ok(sessions) => {
        if sessions.is_empty() {
          buf.write_string("无登录会话\n")
        }
        for s in sessions {
          let seat = if s.seat == "" { "远程/无 seat" } else { s.seat }
          buf.write_string("会话 \{s.id}: 用户 \{s.user}(uid \{s.uid}) 座位 \{seat}\n")
        }
      }
      Err(e) => buf.write_string("会话列表不可用: \{e}\n")
    }
    match @yue.pwrc_can_power_off() {
      Ok(b) => buf.write_string("允许关机: \{if b { "是" } else { "否" }}\n")
      Err(e) => buf.write_string("关机权限查询失败: \{e}\n")
    }
    match @yue.pwrc_can_reboot() {
      Ok(b) => buf.write_string("允许重启: \{if b { "是" } else { "否" }}\n")
      Err(e) => buf.write_string("重启权限查询失败: \{e}\n")
    }
    buf.write_string("关机/重启/注销为危险操作,本演示板不提供执行入口\n")
  } else {
    buf.write_string("不可用: 无 logind 或非 Linux\n")
  }
  buf.write_string("\n== 电源计划(powerprofilesctl,只读) ==\n")
  match @yue.pp_profiles() {
    Ok(profs) => {
      if profs.is_empty() {
        buf.write_string("无可用计划\n")
      }
      let names : Array[String] = []
      for p in profs {
        names.push(pp_display(p))
      }
      buf.write_string("可用计划: \{names.join(" / ")}\n")
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  match @yue.pp_current() {
    Ok(p) => buf.write_string("当前计划: \{pp_display(p)}\n")
    Err(e) => buf.write_string("当前计划读取失败: \{e}\n")
  }
  buf.write_string("\n== 系统信息(只读) ==\n")
  match @yue.si_os() {
    Ok(o) =>
      buf.write_string("发行版: \{o.pretty_name}(id \{o.id},版本 \{o.version_id})\n")
    Err(e) => buf.write_string("发行版读取失败: \{e}\n")
  }
  match @yue.si_machine() {
    Ok(m) => buf.write_string("机器: \{m.vendor} \{m.product}(序列号 \{m.serial})\n")
    Err(e) => buf.write_string("机器标识读取失败: \{e}\n")
  }
  match @yue.si_memory() {
    Ok(mem) =>
      buf.write_string(
        "内存: 共 \{mem.total_kb / 1024} MB,可用 \{mem.available_kb / 1024} MB\n",
      )
    Err(e) => buf.write_string("内存读取失败: \{e}\n")
  }
  match @yue.si_uptime() {
    Ok(secs) =>
      buf.write_string(
        "开机时长: \{secs / 3600.0} 小时(约 \{secs / 86400.0} 天)\n",
      )
    Err(e) => buf.write_string("开机时长读取失败: \{e}\n")
  }
  buf.write_string("\n== 时区与语言(只读) ==\n")
  match @yue.lc_timezone() {
    Ok(tz) => buf.write_string("时区: \{tz}\n")
    Err(e) => buf.write_string("时区读取失败: \{e}\n")
  }
  match @yue.lc_ntp() {
    Ok(b) => buf.write_string("NTP 同步: \{if b { "已开启" } else { "未开启" }}\n")
    Err(e) => buf.write_string("NTP 状态读取失败: \{e}\n")
  }
  match @yue.lc_lang() {
    Ok(l) => buf.write_string("语言: \{l}\n")
    Err(e) => buf.write_string("语言读取失败: \{e}\n")
  }
  buf.write_string("\n== 蓝牙(bluez,只读) ==\n")
  if @yue.bt_supported() {
    match @yue.bt_adapter_info() {
      Ok(a) => {
        let power = if a.powered { "开" } else { "关" }
        let scanning = if a.discovering { "是" } else { "否" }
        buf.write_string("适配器: \{a.name}(\{a.address}) 电源: \{power} 扫描中: \{scanning}\n")
      }
      Err(e) => buf.write_string("适配器读取失败: \{e}\n")
    }
    match @yue.bt_devices() {
      Ok(devs) => {
        if devs.is_empty() {
          buf.write_string("无已登记设备\n")
        }
        let n = if devs.length() > 8 { 8 } else { devs.length() }
        for i = 0; i < n; i = i + 1 {
          let d = devs[i]
          let paired = if d.paired { "已配对" } else { "未配对" }
          let connected = if d.connected { "已连接" } else { "未连接" }
          let trusted = if d.trusted { "已信任" } else { "未信任" }
          buf.write_string(
            "\{d.name}(\{d.address}): \{paired} \{connected} \{trusted}\n",
          )
        }
      }
      Err(e) => buf.write_string("设备列表读取失败: \{e}\n")
    }
  } else {
    buf.write_string("不可用: 无蓝牙适配器或 bluez 不在线\n")
  }
  buf.write_string("\n== 传感器(iio-sensor-proxy,只读) ==\n")
  if @yue.sns_supported() {
    if @yue.sns_has_ambient_light() {
      match @yue.sns_ambient_light() {
        Ok(lux) => buf.write_string("环境光照度: \{lux} lx\n")
        Err(e) => buf.write_string("环境光读取失败: \{e}\n")
      }
    } else {
      buf.write_string("无环境光传感器\n")
    }
    match @yue.sns_accelerometer_orientation() {
      Ok(o) => buf.write_string("加速度计方向: \{o}\n")
      Err(e) => buf.write_string("加速度计读取失败: \{e}\n")
    }
  } else {
    buf.write_string("不可用: 无 iio-sensor-proxy 服务或无传感器\n")
  }
  buf.write_string("\n== 打印机(CUPS,只读) ==\n")
  if @yue.prt_supported() {
    match @yue.prt_list() {
      Ok(ps) => {
        if ps.is_empty() {
          buf.write_string("无打印机\n")
        }
        for p in ps {
          let ok = if @yue.prt_status_available(p.status) { "可用" } else { "不可用" }
          buf.write_string("\{p.name}: \{p.status} \{ok}\n")
        }
      }
      Err(e) => buf.write_string("打印机列表读取失败: \{e}\n")
    }
    match @yue.prt_default() {
      Ok(d) => {
        buf.write_string("默认打印机: \{d}\n")
        match @yue.prt_queue(d) {
          Ok(jobs) => {
            if jobs.is_empty() {
              buf.write_string("打印队列为空\n")
            }
            for j in jobs {
              buf.write_string("  任务 \{j.id}: \{j.name}\n")
            }
          }
          Err(e) => buf.write_string("打印队列读取失败: \{e}\n")
        }
      }
      Err(_) => buf.write_string("未设置默认打印机\n")
    }
  } else {
    buf.write_string("不可用: 未装 CUPS(lpstat 缺失)或非 Linux\n")
  }
  buf.write_string("\n== 环境变量(常用 + XDG_*) ==\n")
  let envs = @yue.envx_common()
  if envs.is_empty() {
    buf.write_string("无\n")
  } else {
    for k, v in envs.iter2() {
      buf.write_string("\{k} = \{trunc_str(v, 60)}\n")
    }
  }
  buf.write_string("\n== 浏览器书签(只读) ==\n")
  match @yue.bm_browsers() {
    Ok(profs) => {
      if profs.is_empty() {
        buf.write_string("未发现任何浏览器 profile\n")
      }
      for p in profs {
        buf.write_string("\{p.browser} / \{p.profile}: \{p.bookmarks_path}\n")
      }
      if profs.length() > 0 {
        // 取首个 profile 所属浏览器的书签树,先序扁平化后展示前 6 条 url
        match @yue.bm_bookmarks(profs[0].browser) {
          Ok(root) => {
            let flats = @yue.bm_flatten(root)
            let n = if flats.length() > 6 { 6 } else { flats.length() }
            for i = 0; i < n; i = i + 1 {
              let b = flats[i]
              match b.url {
                Some(u) =>
                  buf.write_string("  \{trunc_str(b.name, 30)}: \{trunc_str(u, 50)}\n")
                None => ()
              }
            }
          }
          Err(e) => buf.write_string("书签树读取失败: \{e}\n")
        }
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== Firefox 历史(只读;前 6 条) ==\n")
  match @yue.ffx_history(limit=6) {
    Ok(items) => {
      if items.is_empty() {
        buf.write_string("无记录\n")
      }
      for it in items {
        let title = if it.title == "" { "(无标题)" } else { it.title }
        buf.write_string("[\{it.visit_count}次] \{trunc_str(title, 40)}\n  \{it.url}\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== GTK 最近文件(recently-used.xbel,只读;前 8 条) ==\n")
  match @yue.rf_recent(limit=8) {
    Ok(items) => {
      if items.is_empty() {
        buf.write_string("无记录\n")
      }
      for it in items {
        let mime = match it.mime {
          Some(m) => m
          None => "未知"
        }
        buf.write_string("\{trunc_str(it.path, 60)} (MIME \{mime}, \{it.app_count} 个应用)\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.to_string()
}

///|
/// 设置类操作的命令预览按钮组:点击只把将执行的命令文本写进报告标签,
/// 不真实执行;关机/重启/注销等危险操作不提供按钮。
fn cmd_preview_buttons(report : Ref[@yue.Label?]) -> Array[@yue.Node] {
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
  let out : Array[@yue.Node] = []
  for it in items {
    let text = it.0
    let cmd = it.1
    out.push(
      @yue.button_t(
        text,
        variant=@yue.Solid,
        on_click=fn() {
          match report.val {
            Some(l) => {
              l.set_text(cmd)
              @yue.ViewLike::update_layout(l)
            }
            None => ()
          }
        },
      ),
    )
  }
  out
}

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  @yue.theme_apply(@yue.theme_from_system())
  // 报告标签:点「读取」后 set_text;变长文本须补 update_layout,否则
  // 宽度停在挂载瞬间被截断
  let report : Ref[@yue.Label?] = Ref(None)
  // 命令预览报告标签:只展示将执行的命令文本,不真实执行
  let cmd_report : Ref[@yue.Label?] = Ref(None)
  // 雷达图:六维对比,双系列
  let radar_ind : @yue.Store[Array[@yue.RadarIndicator]] = @yue.Store::new([
    @yue.RadarIndicator::make("渲染", 100.0),
    @yue.RadarIndicator::make("IO", 100.0),
    @yue.RadarIndicator::make("内存", 100.0),
    @yue.RadarIndicator::make("启动", 100.0),
    @yue.RadarIndicator::make("体积", 100.0),
    @yue.RadarIndicator::make("功耗", 100.0),
  ])
  let radar_ser : @yue.Store[Array[@yue.RadarSeries]] = @yue.Store::new([
    @yue.RadarSeries::make("本方案", [88.0, 72.0, 80.0, 92.0, 85.0, 78.0]),
    @yue.RadarSeries::make("对照", [70.0, 90.0, 65.0, 75.0, 60.0, 82.0]),
  ])
  // 热力图:一周三时段活跃度矩阵
  let heat : @yue.Store[@yue.HeatGrid] = @yue.Store::new(
    @yue.HeatGrid::make(
      ["周一", "周二", "周三", "周四", "周五", "周六", "周日"],
      ["上午", "下午", "晚间"],
      [
        [3.0, 5.0, 7.0, 4.0, 6.0, 9.0, 8.0],
        [6.0, 8.0, 9.0, 7.0, 5.0, 10.0, 9.0],
        [2.0, 3.0, 8.0, 9.0, 7.0, 6.0, 4.0],
      ],
    ),
  )
  // K 线:七根演示蜡烛(含涨跌与影线形态)
  let candles : @yue.Store[Array[@yue.Candle]] = @yue.Store::new([
    @yue.Candle::make(100.0, 108.0, 98.0, 105.0),
    @yue.Candle::make(105.0, 107.0, 99.0, 101.0),
    @yue.Candle::make(101.0, 110.0, 100.0, 108.0),
    @yue.Candle::make(108.0, 112.0, 104.0, 106.0),
    @yue.Candle::make(106.0, 109.0, 101.0, 103.0),
    @yue.Candle::make(103.0, 105.0, 97.0, 99.0),
    @yue.Candle::make(99.0, 104.0, 96.0, 102.0),
  ])
  // 漏斗:转化漏斗五层
  let funnel : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("浏览", 1000.0),
    @yue.BarItem::make("加购", 420.0),
    @yue.BarItem::make("下单", 260.0),
    @yue.BarItem::make("支付", 190.0),
    @yue.BarItem::make("复购", 80.0),
  ])
  // 箱线:三组耗时分布(含离群点)
  let boxp : @yue.Store[Array[(String, Array[Double])]] = @yue.Store::new([
    ("渲染", [12.0, 14.0, 15.0, 16.0, 18.0, 21.0, 25.0, 30.0]),
    ("IO", [5.0, 6.0, 6.5, 7.0, 8.0, 9.0, 12.0]),
    ("启动", [70.0, 75.0, 78.0, 80.0, 82.0, 90.0, 110.0]),
  ])
  // 桑基:浏览 -> 加购/直接下单 -> 支付/流失 的流向
  let sankey : @yue.Store[@yue.SankeyData] = @yue.Store::new(
    @yue.SankeyData::make(
      [
        @yue.SankeyNode::make("浏览"),
        @yue.SankeyNode::make("加购"),
        @yue.SankeyNode::make("直接下单"),
        @yue.SankeyNode::make("支付"),
        @yue.SankeyNode::make("流失"),
      ],
      [
        @yue.SankeyLink::make(0, 1, 420.0),
        @yue.SankeyLink::make(0, 2, 200.0),
        @yue.SankeyLink::make(1, 3, 190.0),
        @yue.SankeyLink::make(2, 3, 160.0),
        @yue.SankeyLink::make(0, 4, 380.0),
        @yue.SankeyLink::make(1, 4, 230.0),
      ],
    ),
  )
  // ---- 第二批九种新图表(内置演示数据) ----
  // 地图:手绘简化多边形示意(非真实疆界,环为 (lon, lat) 闭合点列),
  // 另配三条城市间飞线
  let geo_regions : @yue.Store[Array[@yue.GeoRegion]] = @yue.Store::new([
    @yue.GeoRegion::make(Some("北部"), [
      [(112.0, 41.0), (118.0, 42.0), (120.0, 40.0), (117.0, 38.0), (113.0, 39.0), (112.0, 41.0)],
    ]),
    @yue.GeoRegion::make(Some("东部"), [
      [(118.0, 32.0), (122.0, 31.0), (121.0, 28.0), (119.0, 27.0), (117.0, 30.0), (118.0, 32.0)],
    ]),
    @yue.GeoRegion::make(Some("南部"), [
      [(110.0, 25.0), (114.0, 25.5), (117.0, 24.0), (114.0, 21.5), (109.5, 22.5), (110.0, 25.0)],
    ]),
    @yue.GeoRegion::make(Some("西部"), [
      [(100.0, 33.0), (106.0, 35.0), (108.0, 31.0), (103.0, 28.5), (99.5, 29.5), (100.0, 33.0)],
    ]),
    @yue.GeoRegion::make(Some("岛屿"), [
      [(119.5, 26.5), (120.5, 26.5), (120.5, 25.0), (119.5, 25.0), (119.5, 26.5)],
    ]),
  ])
  let geo_flights : Array[@yue.GeoFlight] = [
    @yue.GeoFlight::make((116.4, 39.9), (121.47, 31.23)),
    @yue.GeoFlight::make((121.47, 31.23), (113.26, 23.13)),
    @yue.GeoFlight::make((113.26, 23.13), (104.07, 30.67)),
  ]
  // 关系图:网关→服务→缓存/数据库 的力导向布局演示
  let graph : @yue.Store[@yue.GraphData] = @yue.Store::new(
    @yue.GraphData::make(
      [
        @yue.GraphNode::make("网关"),
        @yue.GraphNode::make("服务 A"),
        @yue.GraphNode::make("服务 B"),
        @yue.GraphNode::make("服务 C"),
        @yue.GraphNode::make("缓存"),
        @yue.GraphNode::make("数据库", value=2.0),
      ],
      [
        @yue.GraphEdge::make(0, 1),
        @yue.GraphEdge::make(0, 2),
        @yue.GraphEdge::make(1, 3),
        @yue.GraphEdge::make(2, 3, weight=2.0),
        @yue.GraphEdge::make(1, 4),
        @yue.GraphEdge::make(2, 4),
        @yue.GraphEdge::make(4, 5),
        @yue.GraphEdge::make(3, 5, weight=2.0),
      ],
    ),
  )
  // 平行坐标:四轴五行,「饱和度」轴手动给定 0..100 量程
  let par_axes : @yue.Store[Array[@yue.ParAxis]] = @yue.Store::new([
    @yue.ParAxis::make("延迟(ms)"),
    @yue.ParAxis::make("吞吐(MB/s)"),
    @yue.ParAxis::make("错误率(%)"),
    @yue.ParAxis::make("饱和度(%)", min=Some(0.0), max=Some(100.0)),
  ])
  let par_rows : @yue.Store[Array[Array[Double]]] = @yue.Store::new([
    [12.0, 320.0, 0.5, 40.0],
    [18.0, 260.0, 1.2, 55.0],
    [9.0, 410.0, 0.2, 35.0],
    [25.0, 180.0, 2.0, 70.0],
    [15.0, 300.0, 0.8, 48.0],
  ])
  // 象形柱图:圆形符号沿基线重复平铺(单位 12),带数值标签
  let pb_data : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("北京", 92.0),
    @yue.BarItem::make("上海", 78.0),
    @yue.BarItem::make("广州", 64.0),
    @yue.BarItem::make("成都", 45.0),
    @yue.BarItem::make("西安", 36.0),
  ])
  // 旭日图:两级层级,叶子给显式值、父层按子项聚合
  let sun_root : @yue.Store[@yue.SunItem] = @yue.Store::new(
    @yue.SunItem::make(
      "访问来源",
      children=[
        @yue.SunItem::make(
          "搜索",
          children=[
            @yue.SunItem::make("百度", value=Some(42.0)),
            @yue.SunItem::make("必应", value=Some(18.0)),
          ],
        ),
        @yue.SunItem::make("直接访问", value=Some(35.0)),
        @yue.SunItem::make(
          "外链",
          children=[
            @yue.SunItem::make("社区", value=Some(22.0)),
            @yue.SunItem::make("博客", value=Some(12.0)),
          ],
        ),
      ],
    ),
  )
  // 主题河流:三条层七个时间点的堆叠流域
  let trv_names : @yue.Store[Array[String]] = @yue.Store::new(["移动端", "桌面端", "平板"])
  let trv_values : @yue.Store[Array[Array[Double]]] = @yue.Store::new([
    [12.0, 18.0, 25.0, 22.0, 30.0, 28.0, 20.0],
    [30.0, 32.0, 28.0, 35.0, 40.0, 38.0, 33.0],
    [8.0, 9.0, 11.0, 10.0, 14.0, 13.0, 9.0],
  ])
  // 树图:横向布局的层级树(叶子按 value 定圆点大小)
  let tree_root : @yue.Store[@yue.TreeItem] = @yue.Store::new(
    {
      name: "产品线",
      value: None,
      children: [
        {
          name: "移动端",
          value: Some(60.0),
          children: [
            { name: "iOS", value: Some(35.0), children: [] },
            { name: "Android", value: Some(25.0), children: [] },
          ],
        },
        {
          name: "桌面端",
          value: Some(40.0),
          children: [
            { name: "Windows", value: Some(22.0), children: [] },
            { name: "Linux", value: Some(18.0), children: [] },
          ],
        },
      ],
    },
  )
  // 矩形树图:两级分区(父节点按子项合计)
  let tm_items : @yue.Store[Array[@yue.TmItem]] = @yue.Store::new([
    @yue.TmItem::make(
      "研发",
      children=[
        @yue.TmItem::make("前端", value=30.0),
        @yue.TmItem::make("后端", value=45.0),
        @yue.TmItem::make("测试", value=15.0),
      ],
    ),
    @yue.TmItem::make(
      "设计",
      children=[
        @yue.TmItem::make("视觉", value=18.0),
        @yue.TmItem::make("交互", value=12.0),
      ],
    ),
    @yue.TmItem::make("运营", value=25.0),
  ])
  // 特效散点:涟漪动画句柄外置,关窗时停止定时器
  let eff_anim = @yue.EffAnim::make()
  let eff_points : @yue.Store[Array[@yue.EffPoint]] = @yue.Store::new([
    @yue.EffPoint::make(18.0, 72.0, size=20.0),
    @yue.EffPoint::make(32.0, 58.0, size=14.0),
    @yue.EffPoint::make(47.0, 83.0, size=24.0),
    @yue.EffPoint::make(55.0, 40.0, size=12.0),
    @yue.EffPoint::make(66.0, 63.0, size=16.0),
    @yue.EffPoint::make(78.0, 35.0, size=18.0),
    @yue.EffPoint::make(88.0, 70.0, size=13.0),
  ])
  // ---- 交互版图表:line / bar / donut ----
  let it_line : @yue.Store[Array[@yue.LineSeries]] = @yue.Store::new([
    {
      name: "CPU",
      max_points: 16,
      points: [22.0, 28.0, 25.0, 31.0, 36.0, 33.0, 40.0, 38.0, 45.0, 42.0, 50.0, 47.0, 55.0, 60.0, 58.0, 64.0],
    },
    {
      name: "内存",
      max_points: 16,
      points: [40.0, 42.0, 41.0, 44.0, 46.0, 45.0, 48.0, 50.0, 49.0, 52.0, 55.0, 54.0, 57.0, 60.0, 59.0, 62.0],
    },
  ])
  let it_bar : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("一月", 120.0),
    @yue.BarItem::make("二月", 96.0),
    @yue.BarItem::make("三月", 145.0),
    @yue.BarItem::make("四月", -35.0),
    @yue.BarItem::make("五月", 168.0),
    @yue.BarItem::make("六月", 132.0),
  ])
  let it_donut : @yue.Store[Array[@yue.DonutSlice]] = @yue.Store::new([
    @yue.DonutSlice::make("研发", 42.0),
    @yue.DonutSlice::make("市场", 26.0),
    @yue.DonutSlice::make("运营", 18.0),
    @yue.DonutSlice::make("职能", 14.0),
  ])
  let inner : Array[@yue.Node] = [
    @yue.label_t("系统能力 · 扩展图表", role=@yue.Title),
    @yue.label_t(
      "系统能力读取本机真实数据,结果因机而异;图表为内置演示数据。",
      role=@yue.Secondary,
    ),
    @yue.button_t(
      "读取系统能力",
      variant=@yue.Solid,
      style=[("marginTop", 12.0)],
      on_click=fn() {
        match report.val {
          Some(l) => {
            l.set_text(sysprobe_collect())
            @yue.ViewLike::update_layout(l)
          }
          None => ()
        }
      },
    ),
    @yue.label_t(
      "(点击按钮后此处显示 音量/亮度/浏览器历史/VS Code/应用查找/媒体/显示器/窗口/剪贴板/磁盘/电源/电源计划/系统信息/时区/蓝牙/传感器/打印机/环境变量/书签/Firefox/最近文件 的读取结果)",
      role=@yue.Body,
      style=[("marginTop", 10.0)],
      handle=fn(l) { report.val = Some(l) },
    ),
    @yue.label_t("扩展图表(第一批:六种)", role=@yue.Section, style=[("marginTop", 16.0)]),
    @yue.radar_chart_t(radar_ind, radar_ser, fill=true),
    @yue.heatmap_t(heat, fill=true, show_values=true),
    @yue.candlestick_t(candles, fill=true),
    @yue.funnel_t(funnel, fill=true),
    @yue.boxplot_t(boxp, fill=true),
    @yue.sankey_t(sankey, fill=true),
    @yue.label_t("新图表(第二批:九种)", role=@yue.Section, style=[("marginTop", 16.0)]),
    @yue.label_t(
      "地图为手绘简化多边形示意(非真实疆界);全部为内置演示数据。",
      role=@yue.Secondary,
    ),
    @yue.geo_map_t(geo_regions, flights=geo_flights, fill=true),
    @yue.gph_chart_t(graph, fill=true),
    @yue.par_chart_t(par_axes, par_rows, fill=true),
    @yue.pb_chart_t(
      pb_data,
      symbol=@yue.PbCircle,
      mode=@yue.PbRepeat,
      unit=12.0,
      show_values=true,
      fill=true,
    ),
    @yue.sun_chart_t(sun_root, center_text=Some("总计 129"), fill=true),
    @yue.trv_chart_t(trv_names, trv_values, fill=true),
    @yue.tree_chart_t(tree_root, fill=true),
    @yue.tm_chart_t(tm_items, fill=true),
    @yue.eff_chart_t(
      eff_points,
      x_range=Some((0.0, 100.0)),
      y_range=Some((0.0, 100.0)),
      anim=eff_anim,
      fill=true,
    ),
    @yue.label_t(
      "交互图表(hover 浮层 / 图例点击显隐 / 滚轮缩放与拖拽平移)",
      role=@yue.Section,
      style=[("marginTop", 16.0)],
    ),
    @yue.label_t(
      "line / bar 为交互版(默认 zoom=true,滚轮以鼠标为锚点缩放、左键拖拽平移);donut 无 x 轴,不提供 DataZoom;三图均含 tooltip 与可点击图例。",
      role=@yue.Secondary,
    ),
    @yue.line_chart_it(it_line, fill=true),
    @yue.bar_chart_it(it_bar, fill=true),
    @yue.donut_chart_it(it_donut, center="合计 100", fill=true),
    @yue.label_t(
      "设置类命令预览(只展示将执行的命令文本,不真实执行)",
      role=@yue.Section,
      style=[("marginTop", 16.0)],
    ),
    @yue.label_t(
      "关机/重启/注销等危险操作不提供任何入口;其只读查询(会话列表、允许关机/重启)见上方快照。",
      role=@yue.Secondary,
    ),
    @yue.label_t(
      "(点击预览按钮后此处显示命令文本)",
      role=@yue.Body,
      handle=fn(l) { cmd_report.val = Some(l) },
    ),
  ] + cmd_preview_buttons(cmd_report)
  ignore(
    @yue.mount_window(
      [@yue.scroll(@yue.vbox(inner, style=[("padding", 20.0), ("gap", 14.0)]))],
      title="systemprobe",
      size=Some((960.0, 740.0)),
      center=true,
      on_close=fn(_w) {
        @yue.eff_stop(eff_anim)
        @yue.quit()
      },
    ),
  )
  @yue.run()
}
