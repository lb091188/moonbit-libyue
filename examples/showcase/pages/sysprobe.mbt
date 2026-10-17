// 系统能力探测页（第 15 页）：只读探针分组展示——系统与桌面 / 显示器与窗口 /
// 应用与文件 / 浏览器数据 / 剪贴板与电源与总线。每段带「重新探测」重读本组；
// 能力不在位或读不到的族给「读不到：原因」降级行，不静默吞（探测 + 语义化
// 降级口径）。设置类能力（写自启、改音量等）在「系统集成」页，本页只读。

///|
/// 秒 → 人读时长（天/时/分）。
fn sp_uptime(secs : Double) -> String {
  let total = secs.to_int()
  let d = total / 86400
  let h = (total % 86400) / 3600
  let m = (total % 3600) / 60
  if d > 0 {
    "\{d} 天 \{h} 时 \{m} 分"
  } else if h > 0 {
    "\{h} 时 \{m} 分"
  } else {
    "\{m} 分"
  }
}

///|
/// kB → GB（四舍五入到整数位）。
fn sp_gb(kb : Int) -> String {
  (kb.to_double() / 1024.0 / 1024.0).round().to_int().to_string() + " GB"
}

///|
/// 按码点截断到前 n 个字符（超出补省略号）。
fn sp_clip(s : String, n : Int) -> String {
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
/// 电源计划展示名。
fn sp_pp_name(p : @sys.PowerProfile) -> String {
  match p {
    @sys.PPerformance => "性能(performance)"
    @sys.PBalanced => "均衡(balanced)"
    @sys.PPowerSaver => "省电(power-saver)"
  }
}

///|
/// 探针面板：标题 + 多行读数（Err 一律落成可读行，不影响其余部分）。
fn sp_panel(
  title : String,
  body : @base.Signal[String],
  width : Double,
) -> @widget.Node {
  @ui.view(
    [
      @ui.text(title, font_size=13.0, weight=@text.SemiBold),
      @ui.text_dyn(body, font_size=12.0, wrap=true, max_width=width - 24.0),
    ],
    width=width,
    row_gap=4.0,
    padding=10.0,
    align_items=@yoga.AlignItems::FlexStart,
    background_color="bg_panel",
    border_color="border",
  )
}

///|
/// 一段探测组：段头「重新探测」按钮 + 两个并排面板。
fn sp_group(
  btn_label : String,
  collect_a : () -> String,
  store_a : @base.Store[String],
  title_a : String,
  collect_b : () -> String,
  store_b : @base.Store[String],
  title_b : String,
) -> Array[@widget.Node] {
  let refresh = fn() -> Unit {
    store_a.set(collect_a())
    store_b.set(collect_b())
  }
  refresh()
  [
    @ui.row(
      [
        @ui.button(btn_label, variant=@ui.Solid, on_click=fn() { refresh() }),
        @ui.text("读数因机而异；读不到的族显示原因，不影响其余部分。", role=@ui.Secondary),
      ],
      column_gap=10.0,
      align_items=@yoga.AlignItems::Center,
    ),
    @ui.row(
      [
        sp_panel(title_a, store_a.signal(), 460.0),
        sp_panel(title_b, store_b.signal(), 460.0),
      ],
      column_gap=10.0,
      align_items=@yoga.AlignItems::FlexStart,
    ),
  ]
}

///|
/// 系统与机器：发行版 / 机器 / 内存 / 开机时长 / 桌面环境。
fn sp_sys_machine() -> String {
  let buf = StringBuilder()
  match @sys.si_os() {
    Ok(o) =>
      buf.write_string("发行版: \{o.pretty_name}（id \{o.id}，版本 \{o.version_id}）\n")
    Err(e) => buf.write_string("发行版: 读不到：\{e}\n")
  }
  match @sys.si_machine() {
    Ok(m) =>
      buf.write_string("机器: \{sp_clip(m.vendor + " " + m.product, 50)}（序列号 \{sp_clip(m.serial, 24)}）\n")
    Err(e) => buf.write_string("机器: 读不到：\{e}\n")
  }
  match @sys.si_memory() {
    Ok(mem) =>
      buf.write_string("内存: 共 \{sp_gb(mem.total_kb)}，可用 \{sp_gb(mem.available_kb)}\n")
    Err(e) => buf.write_string("内存: 读不到：\{e}\n")
  }
  match @sys.si_uptime() {
    Ok(secs) => buf.write_string("开机时长: \{sp_uptime(secs)}\n")
    Err(e) => buf.write_string("开机时长: 读不到：\{e}\n")
  }
  buf.write_string("桌面环境: \{@sys.desktop_name()}（\{@sys.sys_platform()}）\n")
  buf.to_string()
}

///|
/// 桌面与外设：环境变量 / 壁纸 / 夜灯 / 打印机。
fn sp_sys_desktop() -> String {
  let buf = StringBuilder()
  let envs = @sys.envx_common()
  buf.write_string("常用环境变量: \{envs.length()} 项\n")
  for k, v in envs.iter2() {
    buf.write_string("  \{k} = \{sp_clip(v, 48)}\n")
  }
  match @sys.wp_get() {
    Ok(path) => buf.write_string("壁纸: \{sp_clip(path, 56)}\n")
    Err(e) => buf.write_string("壁纸: 读不到：\{e}\n")
  }
  buf.write_string(
    "夜灯: \{if @sys.nl_supported() { "可用（redshift/gamma 在）" } else { "本机不可用" }}\n",
  )
  if @sys.prt_supported() {
    match @sys.prt_list() {
      Ok(ps) => {
        buf.write_string("打印机: \{ps.length()} 台\n")
        for p in ps {
          let ok = if @sys.prt_status_available(p.status) { "可用" } else { "不可用" }
          buf.write_string("  \{sp_clip(p.name, 40)} [\{ok}]\n")
        }
      }
      Err(e) => buf.write_string("打印机列表: 读不到：\{e}\n")
    }
    match @sys.prt_default() {
      Ok(d) => buf.write_string("默认打印机: \{sp_clip(d, 40)}\n")
      Err(_) => buf.write_string("默认打印机: 未设置\n")
    }
  } else {
    buf.write_string("打印机: 本机取不到列表（无 CUPS / winspool）\n")
  }
  buf.to_string()
}

///|
/// 显示器：在用模式 + 全部输出与模式数。
fn sp_monitors() -> String {
  let buf = StringBuilder()
  match @sys.mon_current() {
    Ok(outs) => {
      buf.write_string("在用模式: \{outs.length()} 个\n")
      for o in outs {
        buf.write_string(
          "  \{o.name}: \{o.width}x\{o.height} @ \{o.refresh_centi / 100}.\{o.refresh_centi % 100}Hz 位置 +\{o.pos_x}+\{o.pos_y}\n",
        )
      }
    }
    Err(e) => buf.write_string("在用模式: 读不到：\{e}\n")
  }
  buf.write_string("\n")
  match @sys.mon_list() {
    Ok(mons) => {
      buf.write_string("全部输出: \{mons.length()} 个\n")
      for m in mons {
        let conn = if m.connected { "已连接" } else { "未连接" }
        let prim = if m.primary { "主输出" } else { "非主输出" }
        buf.write_string("  \{m.name}: \{conn} \{prim}，支持模式 \{m.modes.length()} 种\n")
      }
    }
    Err(e) => buf.write_string("全部输出: 读不到：\{e}\n")
  }
  buf.to_string()
}

///|
/// 窗口列表（只读，前 10 个）。
fn sp_windows() -> String {
  let buf = StringBuilder()
  match @sys.win_list() {
    Ok(wins) => {
      buf.write_string("窗口: \{wins.length()} 个（列前 10）\n")
      let n = if wins.length() > 10 { 10 } else { wins.length() }
      for i = 0; i < n; i = i + 1 {
        buf.write_string(
          "  \{wins[i].id} [桌面 \{wins[i].desktop}] \{sp_clip(wins[i].title, 40)}\n",
        )
      }
    }
    Err(e) => buf.write_string("窗口: 读不到：\{e}\n")
  }
  buf.to_string()
}

///|
/// 已装应用：桌面项统计 + 常见二进制查找。
fn sp_apps() -> String {
  let buf = StringBuilder()
  match @sys.appfind_installed() {
    Ok(list) => {
      let first : Array[String] = []
      for i = 0; i < list.length(); i = i + 1 {
        if i >= 4 {
          break
        }
        first.push(list[i].name)
      }
      buf.write_string("已装应用: \{list.length()} 个，例如 \{first.join("、")}\n")
    }
    Err(e) => buf.write_string("已装应用: 读不到：\{e}\n")
  }
  buf.write_string("二进制查找:\n")
  for name in ["sh", "firefox", "code", "google-chrome"] {
    match @sys.appfind_executable(name) {
      Ok(p) => buf.write_string("  \{name} → \{sp_clip(p, 52)}\n")
      Err(_) => buf.write_string("  \{name} → 未找到\n")
    }
  }
  buf.to_string()
}

///|
/// 最近文件与 VS Code 工作区。
fn sp_recent() -> String {
  let buf = StringBuilder()
  match @sys.rf_recent(limit=8) {
    Ok(items) => {
      buf.write_string("最近文件: \{items.length()} 条（列前 8）\n")
      for it in items {
        let mime = match it.mime {
          Some(m) => m
          None => "未知"
        }
        buf.write_string("  \{sp_clip(it.path, 52)}（\{mime}）\n")
      }
    }
    Err(e) => buf.write_string("最近文件: 读不到：\{e}\n")
  }
  buf.write_string("\n")
  if @sys.vsc_supported() {
    match @sys.vsc_recent() {
      Ok(paths) => {
        buf.write_string("VS Code 最近工作区: \{paths.length()} 条（列前 6）\n")
        let n = if paths.length() > 6 { 6 } else { paths.length() }
        for i = 0; i < n; i = i + 1 {
          buf.write_string("  \{sp_clip(paths[i], 56)}\n")
        }
      }
      Err(e) => buf.write_string("VS Code 最近工作区: 读不到：\{e}\n")
    }
  } else {
    buf.write_string("VS Code: 本机无用户数据目录\n")
  }
  buf.to_string()
}

///|
/// 浏览器历史与下载（Chromium 系）。
fn sp_browser_hist() -> String {
  let buf = StringBuilder()
  match @sys.bh_browsers() {
    Ok(profiles) => {
      buf.write_string("浏览器 profile: \{profiles.length()} 个有 History 库\n")
      match @sys.bh_history(limit=6) {
        Ok(items) => {
          buf.write_string("历史样本: \{items.length()} 条（列前 6）\n")
          for it in items {
            let title = if it.title == "" { "(无标题)" } else { it.title }
            buf.write_string("  [\{it.visit_count}次] \{sp_clip(title, 34)}\n")
          }
        }
        Err(e) => buf.write_string("历史样本: 读不到：\{e}\n")
      }
      match @sys.bh_downloads(limit=3) {
        Ok(list) => {
          buf.write_string("下载样本: \{list.length()} 条\n")
          for d in list {
            buf.write_string(
              "  \{sp_clip(d.target_path, 44)} \{d.received_bytes}/\{d.total_bytes} 字节 \{@sys.bh_download_state_name(d.state)}\n",
            )
          }
        }
        Err(e) => buf.write_string("下载样本: 读不到：\{e}\n")
      }
    }
    Err(e) => buf.write_string("浏览器历史: 读不到：\{e}\n")
  }
  buf.to_string()
}

///|
/// 书签与 Firefox 历史。
fn sp_bookmarks() -> String {
  let buf = StringBuilder()
  match @sys.bm_browsers() {
    Ok(profs) => {
      if profs.is_empty() {
        buf.write_string("书签: 未发现任何浏览器 profile\n")
      }
      for p in profs {
        buf.write_string("书签源: \{p.browser} / \{p.profile}\n")
      }
      if profs.length() > 0 {
        match @sys.bm_bookmarks(profs[0].browser) {
          Ok(root) => {
            let flats = @sys.bm_flatten(root)
            buf.write_string("书签树: \{flats.length()} 条（列前 6）\n")
            let n = if flats.length() > 6 { 6 } else { flats.length() }
            for i = 0; i < n; i = i + 1 {
              let b = flats[i]
              match b.url {
                Some(u) =>
                  buf.write_string("  \{sp_clip(b.name, 26)}: \{sp_clip(u, 44)}\n")
                None => ()
              }
            }
          }
          Err(e) => buf.write_string("书签树: 读不到：\{e}\n")
        }
      }
    }
    Err(e) => buf.write_string("书签: 读不到：\{e}\n")
  }
  buf.write_string("\n")
  if @sys.ffx_supported() {
    match @sys.ffx_history(limit=6) {
      Ok(items) => {
        buf.write_string("Firefox 历史: \{items.length()} 条（列前 6）\n")
        for it in items {
          let title = if it.title == "" { "(无标题)" } else { it.title }
          buf.write_string("  [\{it.visit_count}次] \{sp_clip(title, 34)}\n")
        }
      }
      Err(e) => buf.write_string("Firefox 历史: 读不到：\{e}\n")
    }
  } else {
    buf.write_string("Firefox: 本机无 profiles.ini / places.sqlite\n")
  }
  buf.to_string()
}

///|
/// 剪贴板与电源（含只读的自启状态与空闲读数）。
fn sp_clip_power() -> String {
  let buf = StringBuilder()
  match @sys.cbw_get_text() {
    Ok(t) => buf.write_string("剪贴板文本: \{sp_clip(t, 56)}\n")
    Err(e) => buf.write_string("剪贴板: 读不到：\{e}\n")
  }
  match @sys.pp_profiles() {
    Ok(profs) => {
      let names : Array[String] = []
      for p in profs {
        names.push(sp_pp_name(p))
      }
      buf.write_string("电源计划: \{names.join(" / ")}\n")
    }
    Err(e) => buf.write_string("电源计划: 读不到：\{e}\n")
  }
  match @sys.pp_current() {
    Ok(p) => buf.write_string("当前计划: \{sp_pp_name(p)}\n")
    Err(e) => buf.write_string("当前计划: 读不到：\{e}\n")
  }
  if @sys.idle_supported() {
    match @sys.idle_seconds() {
      Ok(sec) => buf.write_string("空闲: \{sec.to_int()} 秒（自最后一次输入起）\n")
      Err(e) => buf.write_string("空闲: 读取失败：\{e}\n")
    }
  } else {
    buf.write_string("空闲: 本平台/本会话不支持\n")
  }
  if @sys.autostart_supported() {
    let id = "libyue.showcase"
    match @sys.autostart_is_enabled(id) {
      Ok(v) => buf.write_string("本示例开机自启: \{if v { "已开启" } else { "未开启" }}\n")
      Err(e) => buf.write_string("本示例开机自启: 读不到：\{e}\n")
    }
    match @sys.autostart_path(id) {
      Ok(p) => buf.write_string("自启落点: \{sp_clip(p, 52)}\n")
      Err(e) => buf.write_string("自启落点: 读不到：\{e}\n")
    }
  } else {
    buf.write_string("开机自启: 本平台不支持\n")
  }
  buf.to_string()
}

///|
/// D-Bus 与媒体（会话/系统总线、通知能力、MPRIS 播放器）。
fn sp_dbus_media() -> String {
  let buf = StringBuilder()
  match @dbus.dbus_ensure_session() {
    Ok(_) => buf.write_string("会话总线: 已连接（\{sp_clip(@dbus.dbus_unique_name(), 44)}）\n")
    Err(e) => buf.write_string("会话总线: 不可用：\{e}\n")
  }
  buf.write_string(
    "系统总线: \{if @dbus.dbus_system_alive() { "已连接" } else { "未连接（首次调用时按需连接）" }}\n",
  )
  match @dbus.notify_caps() {
    Ok(caps) => buf.write_string("通知能力: \{caps.raw.length()} 条\n")
    Err(e) => buf.write_string("通知能力: 读不到：\{e}\n")
  }
  buf.write_string("\n")
  match @dbus.media_players() {
    Ok(players) => {
      buf.write_string("MPRIS 媒体播放器: \{players.length()} 个\n")
      for p in players {
        buf.write_string("  \{p.identity}（\{p.name}）\n")
        match @dbus.media_status(p.name) {
          Ok(st) =>
            buf.write_string(
              "    状态 \{st.playback} · \{sp_clip(st.title, 32)} · \{sp_clip(st.artist, 20)}\n",
            )
          Err(e) => buf.write_string("    状态读取失败：\{e}\n")
        }
      }
    }
    Err(e) => buf.write_string("MPRIS 媒体: 读不到：\{e}\n")
  }
  buf.to_string()
}

///|
/// 系统能力探测页。五段各带「重新探测」；每组两块面板并排。
pub fn page_sysprobe(_app : @shared.App) -> @widget.Node {
  let sys_a : @base.Store[String] = @base.Store::new("")
  let sys_b : @base.Store[String] = @base.Store::new("")
  let mon_a : @base.Store[String] = @base.Store::new("")
  let mon_b : @base.Store[String] = @base.Store::new("")
  let app_a : @base.Store[String] = @base.Store::new("")
  let app_b : @base.Store[String] = @base.Store::new("")
  let brw_a : @base.Store[String] = @base.Store::new("")
  let brw_b : @base.Store[String] = @base.Store::new("")
  let ses_a : @base.Store[String] = @base.Store::new("")
  let ses_b : @base.Store[String] = @base.Store::new("")
  @shared.page([
    @shared.section(
      "系统桌面",
      "系统与桌面",
      "发行版 / 机器 / 内存 / 开机时长 / 桌面环境，以及环境变量、壁纸、夜灯、打印机。全部只读。",
      sp_group(
        "重新探测",
        sp_sys_machine,
        sys_a,
        "系统与机器",
        sp_sys_desktop,
        sys_b,
        "桌面与外设",
      ),
    ),
    @shared.section(
      "显示器窗口",
      "显示器与窗口",
      "显示器在用模式与全部输出（xrandr 只读）；窗口列表（wmctrl 只读，列前 10）。",
      sp_group(
        "重新探测",
        sp_monitors,
        mon_a,
        "显示器",
        sp_windows,
        mon_b,
        "窗口列表",
      ),
    ),
    @shared.section(
      "应用文件",
      "应用与文件",
      "已装应用统计与常见二进制查找；最近文件（recently-used.xbel）与 VS Code 最近工作区。",
      sp_group("重新探测", sp_apps, app_a, "已装应用", sp_recent, app_b, "最近与编辑器"),
    ),
    @shared.section(
      "浏览器",
      "浏览器数据",
      "Chromium 系历史与下载、书签树；Firefox 历史。读的是本机浏览器的本地库，不上网。",
      sp_group(
        "重新探测",
        sp_browser_hist,
        brw_a,
        "历史与下载",
        sp_bookmarks,
        brw_b,
        "书签与 Firefox",
      ),
    ),
    @shared.section(
      "剪贴板电源",
      "剪贴板 / 电源 / 总线",
      "剪贴板文本、电源计划、空闲读数、自启状态（只读）；D-Bus 会话/系统总线、通知能力与 MPRIS 媒体。",
      sp_group(
        "重新探测",
        sp_clip_power,
        ses_a,
        "剪贴板与电源",
        sp_dbus_media,
        ses_b,
        "D-Bus 与媒体",
      ),
    ),
  ])
}
