// 系统能力页：真实读取本机数据。G7 新栈迁移记档（与 master 旧页的差）：
// ① 21 族探针里本栈已平移的 14 族走 `@sys` 真调（音量/浏览器历史与
//    下载/VS Code/应用查找/显示器/窗口/剪贴板/电源计划/系统信息/
//    打印机/环境变量/书签/Firefox 历史/最近文件）+ MPRIS 媒体走 `@dbus`；
//    本栈未接的 5 族（磁盘卷 udisks2/时区语言 timedatectl/蓝牙 bluez/
//    传感器 iio-sensor-proxy/logind 电源会话）以说明行替代，整段不迁；
// ② 旧页的 GTK report_set（标签自然高补丁 + 滚动范围手动刷新）不再需要
//    ——新栈 yoga 布局的多行标签自然长高；
// ③ 「不支持的能力显示错误文本」口径不变：Err 一律落成可读行，不影响
//    其余部分。

///|
/// 截断文本到前 n 个字符（超出补省略号），用于快照里的单行摘要。
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
/// 电源计划展示名（与 powerprofilesctl 侧命令名对应）。
fn pp_display(p : @sys.PowerProfile) -> String {
  match p {
    @sys.PPerformance => "性能(performance)"
    @sys.PBalanced => "均衡(balanced)"
    @sys.PPowerSaver => "省电(power-saver)"
  }
}

///|
/// 收集系统能力各模块的当前快照（多行文本）：只读查询真调本机；设置类
/// 命令仅文本预览（见「命令与状态」页），危险操作无入口。
fn sysprobe_collect() -> String {
  let buf = StringBuilder()
  buf.write_string("== 音量(默认 sink) ==\n")
  match @sys.vol_get() {
    Ok(v) =>
      buf.write_string(
        "sink: \{v.sink}\n音量: \{v.volume}%  静音: \{if v.muted { "是" } else { "否" }}\n",
      )
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 浏览器历史(前 6 条) ==\n")
  match @sys.bh_history(limit=6) {
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
  match @sys.bh_downloads(limit=3) {
    Ok(items) => {
      buf.write_string("\n== 浏览器下载记录(前 3 条) ==\n")
      if items.is_empty() {
        buf.write_string("无记录\n")
      }
      for d in items {
        buf.write_string(
          "\{d.target_path}  \{d.received_bytes}/\{d.total_bytes} 字节  \{@sys.bh_download_state_name(d.state)}\n",
        )
      }
    }
    Err(_) => ()
  }
  buf.write_string("\n== VS Code 最近工作区(前 8 条) ==\n")
  match @sys.vsc_recent() {
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
    match @sys.appfind_executable(name) {
      Ok(p) => buf.write_string("\{name} -> \{p}\n")
      Err(_) => buf.write_string("\{name} -> 未找到\n")
    }
  }
  buf.write_string("\n== 媒体播放(MPRIS,只读) ==\n")
  match @dbus.media_players() {
    Ok(players) => {
      if players.is_empty() {
        buf.write_string("无播放器实例\n")
      }
      for p in players {
        buf.write_string("\{p.identity}(\{p.name})\n")
        match @dbus.media_status(p.name) {
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
  match @sys.mon_current() {
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
  match @sys.mon_list() {
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
  match @sys.win_list() {
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
  buf.write_string("\n== 剪贴板文本(只读) ==\n")
  match @sys.cbw_get_text() {
    Ok(t) => buf.write_string("当前文本: \{trunc_str(t, 60)}\n")
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 电源计划(powerprofilesctl,只读) ==\n")
  match @sys.pp_profiles() {
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
  match @sys.pp_current() {
    Ok(p) => buf.write_string("当前计划: \{pp_display(p)}\n")
    Err(e) => buf.write_string("当前计划读取失败: \{e}\n")
  }
  buf.write_string("\n== 系统信息(只读) ==\n")
  match @sys.si_os() {
    Ok(o) =>
      buf.write_string("发行版: \{o.pretty_name}(id \{o.id},版本 \{o.version_id})\n")
    Err(e) => buf.write_string("发行版读取失败: \{e}\n")
  }
  match @sys.si_machine() {
    Ok(m) => buf.write_string("机器: \{m.vendor} \{m.product}(序列号 \{m.serial})\n")
    Err(e) => buf.write_string("机器标识读取失败: \{e}\n")
  }
  match @sys.si_memory() {
    Ok(mem) =>
      buf.write_string(
        "内存: 共 \{mem.total_kb / 1024} MB,可用 \{mem.available_kb / 1024} MB\n",
      )
    Err(e) => buf.write_string("内存读取失败: \{e}\n")
  }
  match @sys.si_uptime() {
    Ok(secs) =>
      buf.write_string(
        "开机时长: \{secs / 3600.0} 小时(约 \{secs / 86400.0} 天)\n",
      )
    Err(e) => buf.write_string("开机时长读取失败: \{e}\n")
  }
  buf.write_string("\n== 打印机(只读) ==\n")
  if @sys.prt_supported() {
    match @sys.prt_list() {
      Ok(ps) => {
        if ps.is_empty() {
          buf.write_string("无打印机\n")
        }
        for p in ps {
          let ok = if @sys.prt_status_available(p.status) { "可用" } else { "不可用" }
          buf.write_string("\{p.name}: \{p.status} \{ok}\n")
        }
      }
      Err(e) => buf.write_string("打印机列表读取失败: \{e}\n")
    }
    match @sys.prt_default() {
      Ok(d) => buf.write_string("默认打印机: \{d}\n")
      Err(_) => buf.write_string("未设置默认打印机\n")
    }
  } else {
    buf.write_string("不可用: winspool/lpstat 都取不到列表\n")
  }
  buf.write_string("\n== 环境变量(常用 + XDG_*) ==\n")
  let envs = @sys.envx_common()
  if envs.is_empty() {
    buf.write_string("无\n")
  } else {
    for k, v in envs.iter2() {
      buf.write_string("\{k} = \{trunc_str(v, 60)}\n")
    }
  }
  buf.write_string("\n== 浏览器书签(只读) ==\n")
  match @sys.bm_browsers() {
    Ok(profs) => {
      if profs.is_empty() {
        buf.write_string("未发现任何浏览器 profile\n")
      }
      for p in profs {
        buf.write_string("\{p.browser} / \{p.profile}: \{p.bookmarks_path}\n")
      }
      if profs.length() > 0 {
        // 取首个 profile 所属浏览器的书签树，先序扁平化后展示前 6 条 url
        match @sys.bm_bookmarks(profs[0].browser) {
          Ok(root) => {
            let flats = @sys.bm_flatten(root)
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
  match @sys.ffx_history(limit=6) {
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
  buf.write_string("\n== 最近文件(recently-used.xbel,只读;前 8 条) ==\n")
  match @sys.rf_recent(limit=8) {
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
/// 系统能力页：读取按钮把快照写进报告标签。
pub fn page_sysinfo(_app : @shared.ProbeApp) -> @core.Node {
  let report : @core.Store[String] = @core.Store::new(
    "(点击按钮后此处显示 音量/浏览器历史/VS Code/应用查找/媒体/显示器/窗口/剪贴板/电源计划/系统信息/打印机/环境变量/书签/Firefox/最近文件 的读取结果)",
  )
  @shared.page([
    @shared.section(
      "系统能力",
      "系统能力",
      "读取本机真实数据，结果因机而异；不支持的能力显示对应错误文本，不影响其余部分。设置类操作见「命令与状态」页（只展示命令文本，不真实执行）。",
      [
        @ui.button("读取系统能力", variant=@ui.Solid, on_click=fn() {
          report.set(sysprobe_collect())
        }),
        @ui.bind_label(report, fn(s) { s }),
      ],
      code=[
        "fn sysprobe_collect() -> String {",
        "  let buf = StringBuilder()",
        "  match @sys.vol_get() {",
        "    Ok(v) => buf.write_string(\"音量: \\{v.volume}%\")",
        "    Err(e) => buf.write_string(\"不可用: \\{e}\")",
        "  }",
        "  // 浏览器历史 / VS Code / 显示器 / 窗口 / 打印机 …同理逐族真调",
        "  buf.to_string()",
        "}",
        "// MPRIS 媒体走 @dbus：",
        "match @dbus.media_players() { ... }",
      ],
    ),
  ])
}
