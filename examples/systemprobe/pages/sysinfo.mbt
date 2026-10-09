// 系统能力页:真实读取本机数据(音量/亮度/浏览器历史与下载/VS Code
// 最近工作区/应用查找/媒体播放/显示器/窗口/剪贴板/磁盘/电源/电源计划/
// 系统信息/时区/蓝牙/传感器/打印机/环境变量/书签/Firefox/最近文件),
// 点「读取系统能力」后逐段呈现,结果因机而异;不支持的能力显示对应
// 错误文本,不影响其余部分。

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
fn pp_display(p : @system.PowerProfile) -> String {
  match p {
    @system.PPerformance => "性能(performance)"
    @system.PBalanced => "均衡(balanced)"
    @system.PPowerSaver => "省电(power-saver)"
  }
}

///|
/// 收集系统能力各模块的当前快照(多行文本):只读查询真调本机;设置类
/// 命令仅文本预览(见「命令预览」页),危险操作无入口。
fn sysprobe_collect() -> String {
  let buf = StringBuilder()
  buf.write_string("== 音量(默认 sink) ==\n")
  match @system.vol_get() {
    Ok(v) =>
      buf.write_string(
        "sink: \{v.sink}\n音量: \{v.volume}%  静音: \{if v.muted { "是" } else { "否" }}\n",
      )
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 屏幕亮度 ==\n")
  match @system.brightness_devices() {
    Ok(devs) => {
      if devs.is_empty() {
        buf.write_string("无背光设备\n")
      }
      for d in devs {
        let cur = match @system.brightness_get(d) {
          Ok(p) => "\{p}%"
          Err(e) => "读取失败(\{e})"
        }
        buf.write_string("\{d.name}(量程 \{d.max}): \{cur}\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 浏览器历史(前 6 条) ==\n")
  match @system.bh_history(limit=6) {
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
  match @system.bh_downloads(limit=3) {
    Ok(items) => {
      buf.write_string("\n== 浏览器下载记录(前 3 条) ==\n")
      if items.is_empty() {
        buf.write_string("无记录\n")
      }
      for d in items {
        buf.write_string(
          "\{d.target_path}  \{d.received_bytes}/\{d.total_bytes} 字节  \{@system.bh_download_state_name(d.state)}\n",
        )
      }
    }
    Err(_) => ()
  }
  buf.write_string("\n== VS Code 最近工作区(前 8 条) ==\n")
  match @system.vsc_recent() {
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
    match @system.appfind_executable(name) {
      Ok(p) => buf.write_string("\{name} -> \{p}\n")
      Err(_) => buf.write_string("\{name} -> 未找到\n")
    }
  }
  buf.write_string("\n== 默认应用查询(只读) ==\n")
  if @system.da_supported() {
    match @system.da_file_type("/etc/hostname") {
      Ok(mime) => {
        buf.write_string("/etc/hostname 类型: \{mime}\n")
        match @system.da_default_for(mime) {
          Ok(d) => buf.write_string("默认应用: \{d}\n")
          Err(@system.DefaultAppError::NoDefault(_)) => buf.write_string("默认应用: 未登记\n")
          Err(e) => buf.write_string("默认应用查询失败: \{e}\n")
        }
        let htmls = @system.da_associations_for("text/html")
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
  buf.write_string("\n== 媒体播放(MPRIS,只读) ==\n")
  match @system.media_players() {
    Ok(players) => {
      if players.is_empty() {
        buf.write_string("无播放器实例\n")
      }
      for p in players {
        buf.write_string("\{p.identity}(\{p.name})\n")
        match @system.media_status(p.name) {
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
  match @system.mon_current() {
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
  match @system.mon_list() {
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
  match @system.win_list() {
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
  match @system.cbw_get_text() {
    Ok(t) => buf.write_string("当前文本: \{trunc_str(t, 60)}\n")
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 磁盘卷(udisks2/lsblk,只读) ==\n")
  match @system.dsk_volumes() {
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
  if @system.pwrc_supported() {
    match @system.pwrc_sessions() {
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
    match @system.pwrc_can_power_off() {
      Ok(b) => buf.write_string("允许关机: \{if b { "是" } else { "否" }}\n")
      Err(e) => buf.write_string("关机权限查询失败: \{e}\n")
    }
    match @system.pwrc_can_reboot() {
      Ok(b) => buf.write_string("允许重启: \{if b { "是" } else { "否" }}\n")
      Err(e) => buf.write_string("重启权限查询失败: \{e}\n")
    }
    buf.write_string("关机/重启/注销为危险操作,本演示板不提供执行入口\n")
  } else {
    buf.write_string("不可用: 无 logind 或非 Linux\n")
  }
  buf.write_string("\n== 电源计划(powerprofilesctl,只读) ==\n")
  match @system.pp_profiles() {
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
  match @system.pp_current() {
    Ok(p) => buf.write_string("当前计划: \{pp_display(p)}\n")
    Err(e) => buf.write_string("当前计划读取失败: \{e}\n")
  }
  buf.write_string("\n== 系统信息(只读) ==\n")
  match @system.si_os() {
    Ok(o) =>
      buf.write_string("发行版: \{o.pretty_name}(id \{o.id},版本 \{o.version_id})\n")
    Err(e) => buf.write_string("发行版读取失败: \{e}\n")
  }
  match @system.si_machine() {
    Ok(m) => buf.write_string("机器: \{m.vendor} \{m.product}(序列号 \{m.serial})\n")
    Err(e) => buf.write_string("机器标识读取失败: \{e}\n")
  }
  match @system.si_memory() {
    Ok(mem) =>
      buf.write_string(
        "内存: 共 \{mem.total_kb / 1024} MB,可用 \{mem.available_kb / 1024} MB\n",
      )
    Err(e) => buf.write_string("内存读取失败: \{e}\n")
  }
  match @system.si_uptime() {
    Ok(secs) =>
      buf.write_string(
        "开机时长: \{secs / 3600.0} 小时(约 \{secs / 86400.0} 天)\n",
      )
    Err(e) => buf.write_string("开机时长读取失败: \{e}\n")
  }
  buf.write_string("\n== 时区与语言(只读) ==\n")
  match @system.lc_timezone() {
    Ok(tz) => buf.write_string("时区: \{tz}\n")
    Err(e) => buf.write_string("时区读取失败: \{e}\n")
  }
  match @system.lc_ntp() {
    Ok(b) => buf.write_string("NTP 同步: \{if b { "已开启" } else { "未开启" }}\n")
    Err(e) => buf.write_string("NTP 状态读取失败: \{e}\n")
  }
  match @system.lc_lang() {
    Ok(l) => buf.write_string("语言: \{l}\n")
    Err(e) => buf.write_string("语言读取失败: \{e}\n")
  }
  buf.write_string("\n== 蓝牙(bluez,只读) ==\n")
  if @system.bt_supported() {
    match @system.bt_adapter_info() {
      Ok(a) => {
        let power = if a.powered { "开" } else { "关" }
        let scanning = if a.discovering { "是" } else { "否" }
        buf.write_string("适配器: \{a.name}(\{a.address}) 电源: \{power} 扫描中: \{scanning}\n")
      }
      Err(e) => buf.write_string("适配器读取失败: \{e}\n")
    }
    match @system.bt_devices() {
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
  if @system.sns_supported() {
    if @system.sns_has_ambient_light() {
      match @system.sns_ambient_light() {
        Ok(lux) => buf.write_string("环境光照度: \{lux} lx\n")
        Err(e) => buf.write_string("环境光读取失败: \{e}\n")
      }
    } else {
      buf.write_string("无环境光传感器\n")
    }
    match @system.sns_accelerometer_orientation() {
      Ok(o) => buf.write_string("加速度计方向: \{o}\n")
      Err(e) => buf.write_string("加速度计读取失败: \{e}\n")
    }
  } else {
    buf.write_string("不可用: 无 iio-sensor-proxy 服务或无传感器\n")
  }
  buf.write_string("\n== 打印机(CUPS,只读) ==\n")
  if @system.prt_supported() {
    match @system.prt_list() {
      Ok(ps) => {
        if ps.is_empty() {
          buf.write_string("无打印机\n")
        }
        for p in ps {
          let ok = if @system.prt_status_available(p.status) { "可用" } else { "不可用" }
          buf.write_string("\{p.name}: \{p.status} \{ok}\n")
        }
      }
      Err(e) => buf.write_string("打印机列表读取失败: \{e}\n")
    }
    match @system.prt_default() {
      Ok(d) => {
        buf.write_string("默认打印机: \{d}\n")
        match @system.prt_queue(d) {
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
  match @system.bm_browsers() {
    Ok(profs) => {
      if profs.is_empty() {
        buf.write_string("未发现任何浏览器 profile\n")
      }
      for p in profs {
        buf.write_string("\{p.browser} / \{p.profile}: \{p.bookmarks_path}\n")
      }
      if profs.length() > 0 {
        // 取首个 profile 所属浏览器的书签树,先序扁平化后展示前 6 条 url
        match @system.bm_bookmarks(profs[0].browser) {
          Ok(root) => {
            let flats = @system.bm_flatten(root)
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
  match @system.ffx_history(limit=6) {
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
  match @system.rf_recent(limit=8) {
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
/// 系统能力页:读取按钮把快照写进报告标签,随后刷新滚动范围(报告文本
//  在挂载后才长高,GTK 滚动范围不会自动跟上)。
pub fn page_sysinfo(app : @ui.ProbeApp) -> @yue.Node {
  ignore(app)
  let report : Ref[@yue.Label?] = Ref(None)
  @ui.page_shell(
    "系统能力",
    "系统能力读取本机真实数据,结果因机而异;不支持的能力显示对应错误文本,不影响其余部分。设置类操作见「命令预览」页(只展示命令文本,不真实执行)。",
    fn(refresh) {
      [
        @components.button_t(
          "读取系统能力",
          variant=@components.Solid,
          on_click=fn() {
            match report.val {
              Some(l) => @ui.report_set(l, sysprobe_collect(), refresh)
              None => ()
            }
          },
        ),
        @components.label_t(
          "(点击按钮后此处显示 音量/亮度/浏览器历史/VS Code/应用查找/媒体/显示器/窗口/剪贴板/磁盘/电源/电源计划/系统信息/时区/蓝牙/传感器/打印机/环境变量/书签/Firefox/最近文件 的读取结果)",
          role=@components.Body,
          handle=fn(l) { report.val = Some(l) },
        ),
      ]
    },
  )
}
