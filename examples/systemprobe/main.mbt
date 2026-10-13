// examples/systemprobe —— 系统能力（`sys`）的**累积**验证示例：每落地一族
// 就把读数接进本页，同族不另开示例（GUI 侧的累计页是 `examples/native-app`）。
//
// 跑法：`moon run examples/systemprobe`（需显示服务），12 秒后自动退出并打印
// 状态行。屏上每行一个**只读**探测；「重新探测」按钮也是只读（注入回证用它），
// 「打开链接」「打开目录」是设置类——点了才交给系统，观感由使用者复验。

///|
priv struct Counts {
  mut os_id : String
  mut desktop : String
  mut monitors : Int
  mut wallpaper : String
  mut volume : Int
  mut profile : String
  mut mime : String
  mut default_app : String
  mut apps : Int
  mut recent : Int
  mut hist : Int
  mut downloads : Int
  mut bookmarks : Int
  mut firefox : Int
  mut vscode : Int
  mut windows : Int
  mut clipboard : Int
}

///|
fn empty_counts() -> Counts {
  {
    os_id: "-",
    desktop: "-",
    monitors: 0,
    wallpaper: "-",
    volume: -1,
    profile: "-",
    mime: "-",
    default_app: "-",
    apps: 0,
    recent: 0,
    hist: 0,
    downloads: 0,
    bookmarks: 0,
    firefox: 0,
    vscode: 0,
    windows: 0,
    clipboard: -1,
  }
}

///|
/// 用分隔符拼接字符串表（不依赖 core/string 的包别名）。
fn join_with(items : Array[String], sep : String) -> String {
  let buf = StringBuilder()
  let mut first = true
  for x in items {
    if !first {
      buf.write_string(sep)
    }
    buf.write_string(x)
    first = false
  }
  buf.to_string()
}

///|
/// 首行 + 按码点截断（读数可能多行、含非 ASCII，直接切片会踩码点边界）。
fn one_line(s : String, max : Int) -> String {
  let buf = StringBuilder()
  let mut n = 0
  for ch in s {
    if ch == '\n' || n >= max {
      break
    }
    buf.write_char(ch)
    n = n + 1
  }
  buf.to_string()
}

///|
/// 秒 → 人读时长（天/小时/分）。
fn fmt_uptime(secs : Double) -> String {
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
/// kB → GB（一位小数）。
fn fmt_gb(kb : Int) -> String {
  let gb = kb.to_double() / 1024.0 / 1024.0
  gb.round().to_int().to_string() + " GB"
}

///|
/// 空闲秒数 → 人类可读（不足 60 秒给「N.N 秒」，超过给「M 分 K 秒」）。
fn fmt_idle(secs : Double) -> String {
  if secs < 60.0 {
    ((secs * 10.0).round() / 10.0).to_string() + " 秒"
  } else {
    let total = secs.to_int()
    (total / 60).to_string() + " 分 " + (total % 60).to_string() + " 秒"
  }
}

// ---------------------------------------------------------------------------
// 各段只读探测（返回键值行，同时回填计数供退出状态行使用）
// ---------------------------------------------------------------------------

///|
fn probe_system(counts : Ref[Counts]) -> Array[(String, String)] {
  let rows : Array[(String, String)] = []
  match @sys.si_os() {
    Ok(os) => {
      counts.val.os_id = os.id
      rows.push(("发行版", os.pretty_name))
      rows.push(("id / 版本", os.id + " / " + os.version_id))
    }
    Err(e) => rows.push(("发行版", "读不到：" + e.to_string()))
  }
  match @sys.si_machine() {
    Ok(m) =>
      rows.push((
        "机器",
        one_line(m.vendor + " / " + m.product + " / " + m.serial, 60),
      ))
    Err(e) =>
      // 序列号在多数发行版上仅 root 可读，读不到就报状态而不是糊成空串
      rows.push(("机器", "读不到：" + e.to_string()))
  }
  match @sys.si_memory() {
    Ok(mem) =>
      rows.push((
        "内存",
        "总 " +
          fmt_gb(mem.total_kb) + " / 可用 " + fmt_gb(mem.available_kb),
      ))
    Err(e) => rows.push(("内存", "读不到：" + e.to_string()))
  }
  match @sys.si_uptime() {
    Ok(secs) => rows.push(("开机时长", fmt_uptime(secs)))
    Err(e) => rows.push(("开机时长", "读不到：" + e.to_string()))
  }
  counts.val.desktop = @sys.desktop_name()
  rows.push(("桌面环境", @sys.desktop_name() + "（" + @sys.sys_platform() + "）"))
  rows.push(("常用环境变量", "\{@sys.envx_common().length()} 项"))
  rows
}

///|
fn probe_desktop(counts : Ref[Counts]) -> Array[(String, String)] {
  let rows : Array[(String, String)] = []
  match @sys.mon_list() {
    Ok(list) => {
      counts.val.monitors = list.length()
      let names : Array[String] = []
      for m in list {
        if m.connected {
          names.push(m.name + (if m.primary { "*" } else { "" }))
        }
      }
      rows.push(("显示器", "\{list.length()} 个，已连接：" + join_with(names, ",")))
    }
    Err(e) => rows.push(("显示器", "读不到：" + e.to_string()))
  }
  match @sys.wp_get() {
    Ok(path) => {
      counts.val.wallpaper = "ok"
      rows.push(("壁纸", one_line(path, 60)))
    }
    Err(e) => {
      counts.val.wallpaper = "err"
      rows.push(("壁纸", e.to_string()))
    }
  }
  match @sys.vol_get() {
    Ok(v) => {
      counts.val.volume = v.volume
      rows.push((
        "音量",
        "\{v.volume}%（\{v.sink}\{if v.muted { " 静音" } else { "" }}）",
      ))
    }
    Err(e) => rows.push(("音量", e.to_string()))
  }
  match @sys.pp_current() {
    Ok(p) => {
      counts.val.profile = p.to_string()
      rows.push(("电源计划", p.to_string()))
    }
    Err(e) => rows.push(("电源计划", e.to_string()))
  }
  rows.push(
    (
      "亮度",
      if @sys.brightness_supported() {
        match @sys.brightness_devices() {
          Ok(list) => "设备 " + (list.length()).to_string() + " 个"
          Err(e) => e.to_string()
        }
      } else {
        "无 backlight 设备"
      },
    ),
  )
  rows.push(("夜灯", if @sys.nl_supported() { "可用（redshift/gamma 在）" } else { "不可用" }))
  rows.push(
    (
      "打印机",
      match @sys.prt_default() {
        Ok(name) => "默认：" + name
        Err(_) =>
          if @sys.prt_supported() { "有 CUPS，无默认机" } else { "无 lp 命令" }
      },
    ),
  )
  rows
}

///|
fn probe_apps(counts : Ref[Counts]) -> Array[(String, String)] {
  let rows : Array[(String, String)] = []
  match @sys.appfind_installed() {
    Ok(list) => {
      counts.val.apps = list.length()
      let first : Array[String] = []
      for i in 0..<list.length() {
        if i >= 3 {
          break
        }
        first.push(list[i].name)
      }
      rows.push(
        ("已装应用", "\{list.length()} 个，例如：" + join_with(first, "、")),
      )
    }
    Err(e) => rows.push(("已装应用", e.to_string()))
  }
  if @sys.da_supported() {
    match @sys.da_file_type("/etc/hostname") {
      Ok(mime) => {
        counts.val.mime = mime
        rows.push(
          ("文件类型（/etc/hostname）", mime),
        )
      }
      Err(e) => rows.push(("文件类型（/etc/hostname）", e.to_string()))
    }
    match @sys.da_default_for("text/plain") {
      Ok(name) => {
        counts.val.default_app = name
        rows.push(("text/plain 默认应用", name))
      }
      Err(e) => rows.push(("text/plain 默认应用", e.to_string()))
    }
  } else {
    rows.push(("xdg-mime", "不在 PATH"))
  }
  rows
}

///|
fn probe_history(counts : Ref[Counts]) -> Array[(String, String)] {
  let rows : Array[(String, String)] = []
  match @sys.rf_recent(limit=0) {
    Ok(items) => {
      counts.val.recent = items.length()
      let first = if items.length() > 0 {
        one_line(items[0].path, 48)
      } else {
        "-"
      }
      rows.push(("最近文件", "\{items.length()} 条，首条：" + first))
    }
    Err(e) => rows.push(("最近文件", e.to_string()))
  }
  match @sys.bh_browsers() {
    Ok(profiles) => {
      rows.push(("浏览器 profile", "\{profiles.length()} 个有 History 库"))
      match @sys.bh_history(limit=5) {
        Ok(items) => {
          counts.val.hist = items.length()
          let first = if items.length() > 0 {
            one_line(items[0].url, 48)
          } else {
            "-"
          }
          rows.push(("浏览历史样本", "\{items.length()} 条，最新：" + first))
        }
        Err(e) => rows.push(("浏览历史样本", e.to_string()))
      }
      match @sys.bh_downloads(limit=5) {
        Ok(list) => {
          counts.val.downloads = list.length()
          rows.push(("下载样本", "\{list.length()} 条"))
        }
        Err(e) => rows.push(("下载样本", e.to_string()))
      }
    }
    Err(e) => rows.push(("浏览器历史", e.to_string()))
  }
  match @sys.bm_browsers() {
    Ok(list) =>
      if list.length() > 0 {
        let p = list[0]
        match @sys.bm_bookmarks(p.browser) {
          Ok(root) => {
            let n = @sys.bm_flatten(root).length()
            counts.val.bookmarks = n
            rows.push(("书签", "\{p.browser}/\{p.profile}：\{n} 条"))
          }
          Err(e) => rows.push(("书签", e.to_string()))
        }
      }
    Err(e) => rows.push(("书签", e.to_string()))
  }
  if @sys.ffx_supported() {
    match @sys.ffx_profiles() {
      Ok(list) => {
        counts.val.firefox = list.length()
        rows.push(("Firefox profile", "\{list.length()} 个"))
      }
      Err(e) => rows.push(("Firefox profile", e.to_string()))
    }
  } else {
    rows.push(("Firefox", "本机无 profiles.ini / places.sqlite"))
  }
  if @sys.vsc_supported() {
    match @sys.vsc_recent() {
      Ok(list) => {
        counts.val.vscode = list.length()
        rows.push(("VS Code 最近", "\{list.length()} 项"))
      }
      Err(e) => rows.push(("VS Code 最近", e.to_string()))
    }
  } else {
    rows.push(("VS Code", "本机无用户数据目录"))
  }
  rows
}

///|
fn probe_windows(counts : Ref[Counts]) -> Array[(String, String)] {
  let rows : Array[(String, String)] = []
  match @sys.win_list() {
    Ok(list) => {
      counts.val.windows = list.length()
      let first = if list.length() > 0 {
        one_line(list[0].title, 44)
      } else {
        "-"
      }
      rows.push(("窗口（wmctrl）", "\{list.length()} 个，首个：" + first))
    }
    Err(e) => rows.push(("窗口（wmctrl）", e.to_string()))
  }
  match @sys.cbw_get_text() {
    Ok(t) => {
      counts.val.clipboard = t.length()
      rows.push(("剪贴板", "\{t.length()} 字符：" + one_line(t, 44)))
    }
    Err(e) => rows.push(("剪贴板", e.to_string()))
  }
  // D-Bus：会话唯一名（真连一次）、通知能力条数、系统总线在线与否
  match @dbus.dbus_ensure_session() {
    Ok(_) => rows.push(("会话总线", @dbus.dbus_unique_name()))
    Err(e) => rows.push(("会话总线", e))
  }
  match @dbus.notify_caps() {
    Ok(caps) => rows.push(("通知能力", "\{caps.raw.length()} 条"))
    Err(e) => rows.push(("通知能力", e.to_string()))
  }
  rows.push(
    (
      "系统总线",
      if @dbus.dbus_system_alive() {
        "已连接"
      } else {
        "未连接（首次调用时按需连接）"
      },
    ),
  )
  rows
}

///|
/// 一列面板：标题 + 多行读数（整块一个标签，换行由文本自身带）。
fn panel(
  title : String,
  lines : @core.Signal[String],
  width : Double,
) -> @core.Node {
  @ui.view(
    [
      @ui.text(title, size=13.0, weight=@text.SemiBold),
      @ui.text_dyn(lines, size=12.0, wrap=true, max_width=width - 20.0),
    ],
    width=width,
    row_gap=4.0,
    padding=8.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_panel(),
    border=@theme.theme_border(),
  )
}

///|
fn join_lines(rows : Array[(String, String)]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for r in rows {
    if !first {
      buf.write_char('\n')
    }
    buf.write_string(r.0)
    buf.write_string("：")
    buf.write_string(r.1)
    first = false
  }
  buf.to_string()
}

///|
fn rect_str(r : @core.Rect) -> String {
  r.x.round().to_int().to_string() +
    "," +
    r.y.round().to_int().to_string() +
    "," +
    r.w.round().to_int().to_string() +
    "x" +
    r.h.round().to_int().to_string()
}

///|
fn main {
  // 单实例：先声称总线名字；已有实例就唤起它并退出（无总线时降级为不做）
  let app_id = "com.example.moonbitsys"
  match @dbus.claim_name(app_id) {
    Ok(PrimaryOwner) | Ok(AlreadyOwner) =>
      @dbus.on_wake(fn(_args : Array[String]) -> Unit {
        println("SYSPROBE-INST: 收到第二实例的唤起")
      })
    Ok(AlreadyExists) | Ok(InQueue) => {
      match @dbus.wake_existing(app_id, []) {
        Ok(_) => println("SYSPROBE-INST: 已有实例，已唤起并退出")
        Err(e) => println("SYSPROBE-INST: 唤起失败(\{e})，退出")
      }
      return
    }
    Err(e) => println("SYSPROBE-INST: 单实例降级（\{e}）")
  }
  let app = match @core.App::new(1200, 1180, "MoonBit 系统能力 (systemprobe)") {
    Some(a) => a
    None => {
      println("SYSPROBE-SKIP: 本平台无窗口后端或没有显示服务")
      return
    }
  }
  // 把 logind 的亮度写能力装进 sys 的注入槽（sys 不引 D-Bus）
  @dbus.install_logind_brightness()
  let counts : Ref[Counts] = Ref(empty_counts())
  let probes = @core.Store::new(0)
  let opens = @core.Store::new(0)
  let reveals = @core.Store::new(0)
  let clip_changes = @core.Store::new(0)
  let clip_view = @core.Store::new("剪贴板监听：启动时以当前内容作基线，变化才派发")
  let btn_probe : Ref[@core.Widget?] = Ref(None)
  let btn_open : Ref[@core.Widget?] = Ref(None)
  let btn_reveal : Ref[@core.Widget?] = Ref(None)
  let btn_notify : Ref[@core.Widget?] = Ref(None)
  let btn_tray : Ref[@core.Widget?] = Ref(None)
  let btn_auto_on : Ref[@core.Widget?] = Ref(None)
  let btn_auto_off : Ref[@core.Widget?] = Ref(None)
  let notify_hits = @core.Store::new(0)
  let tray_item : Ref[@dbus.Item?] = Ref(None)
  let tray_clicks = @core.Store::new(0)
  let tray_state = @core.Store::new("托盘：未注册")
  let notify_state = @core.Store::new("通知：未发送")
  let sys_store = @core.Store::new(join_lines(probe_system(counts)))
  let desk_store = @core.Store::new(join_lines(probe_desktop(counts)))
  let apps_store = @core.Store::new(join_lines(probe_apps(counts)))
  let hist_store = @core.Store::new(join_lines(probe_history(counts)))
  let wins_store = @core.Store::new(join_lines(probe_windows(counts)))
  // W21d 开机自启：设置类（写盘 / 写注册表），只给按钮；初值只做只读定位
  let auto_id = "com.moonbit.libyue.systemprobe"
  let auto_on_hits = @core.Store::new(0)
  let auto_state = @core.Store::new(
    match @sys.autostart_path(auto_id) {
      Ok(p) => "自启动：未启用（落点 " + p + "）"
      Err(e) => "自启动：不可用（" + e.to_string() + "）"
    },
  )
  // W21e 空闲检测：只读读数（自最后一次输入起的秒数），阈值判定交给调用方
  let btn_idle : Ref[@core.Widget?] = Ref(None)
  let idle_hits = @core.Store::new(0)
  let idle_state = @core.Store::new(
    if @sys.idle_supported() {
      "空闲：支持（点一下读当前秒数）"
    } else {
      "空闲：本平台 / 本会话不支持（macOS 或 Wayland 无 X 服务端）"
    },
  )

  fn reprobe() -> Unit {
    sys_store.set(join_lines(probe_system(counts)))
    desk_store.set(join_lines(probe_desktop(counts)))
    apps_store.set(join_lines(probe_apps(counts)))
    hist_store.set(join_lines(probe_history(counts)))
    wins_store.set(join_lines(probe_windows(counts)))
    probes.update(fn(n : Int) -> Int { n + 1 })
    app.schedule_paint()
  }

  // D-Bus 接线：排期通道与周期泵都由宿主给（dbus 不引 GUI 核心层）
  @dbus.dbus_set_post_delayed(fn(ms : Int, f : () -> Unit) -> Unit {
    let _ = app.timer(ms, f)
  })
  fn pump_loop() -> Unit {
    @dbus.dbus_pump()
    let _ = app.timer(200, pump_loop)
  }
  let _ = app.timer(200, pump_loop)
  // 剪贴板监听：排期通道由宿主注入（sys 不引 GUI 核心层）
  let watcher = @sys.cbw_start_watch(
    fn(ms : Int, f : () -> Unit) -> Unit {
      let _ = app.timer(ms, f)
    },
    fn(text : String) -> Unit {
      clip_changes.update(fn(n : Int) -> Int { n + 1 })
      clip_view.set("剪贴板变化 " + (clip_changes.get()).to_string() + " 次：" + one_line(text, 40))
      app.schedule_paint()
    },
    interval_ms=1000,
  )

  let root = app.root
  root.set_column()
  app.mount([
    @ui.view(
      [
        @ui.text(
          "系统能力（sys）：只读探测在一屏，设置类只给按钮",
          size=15.0,
          weight=@text.SemiBold,
        ),
        @ui.text(
          "「重新探测」也是只读；「打开链接 / 打开目录 / 发通知」会把动作交给系统，点了才有反应",
          size=12.0,
          color=@theme.theme_text_secondary(),
        ),
      ],
      row_gap=2.0,
      padding=8.0,
      align_items=@yoga.AlignItems::FlexStart,
    ),
    @ui.view(
      [
        panel("系统与机器", sys_store.signal(), 580.0),
        panel("桌面与硬件", desk_store.signal(), 580.0),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      row_gap=0.0,
      align_items=@yoga.AlignItems::FlexStart,
    ),
    @ui.view(
      [
        panel("应用与文件类型", apps_store.signal(), 380.0),
        panel("窗口 / 剪贴板 / D-Bus", wins_store.signal(), 380.0),
        panel("最近与历史", hist_store.signal(), 380.0),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      align_items=@yoga.AlignItems::FlexStart,
    ),
    @ui.view(
      [
        @ui.button(
          "重新探测",
          on_click=reprobe,
          min_width=110.0,
          handle=fn(w : @core.Widget) -> Unit { btn_probe.val = Some(w) },
        ),
        @ui.button(
          "打开链接",
          on_click=fn() -> Unit {
            let _ = @sys.open_url("https://libyue.com")
            opens.update(fn(n : Int) -> Int { n + 1 })
            app.schedule_paint()
          },
          kind=@ui.Border,
          min_width=110.0,
          handle=fn(w : @core.Widget) -> Unit { btn_open.val = Some(w) },
        ),
        @ui.button(
          "打开目录",
          on_click=fn() -> Unit {
            let _ = @sys.reveal_in_file_manager("/tmp")
            reveals.update(fn(n : Int) -> Int { n + 1 })
            app.schedule_paint()
          },
          kind=@ui.Border,
          min_width=110.0,
          handle=fn(w : @core.Widget) -> Unit { btn_reveal.val = Some(w) },
        ),
        @ui.text_dyn(
          probes.signal().map(
            fn(n : Int) -> String {
              "重新探测 " + n.to_string() + " 次 / 打开链接 " +
                (opens.get()).to_string() +
                " 次 / 打开目录 " +
                (reveals.get()).to_string() + " 次"
            },
          ),
          size=12.0,
        ),
        @ui.button(
          "发通知(带进度)",
          on_click=fn() -> Unit {
            let n = notify_hits.get()
            let pct = if n >= 3 { 90 } else { 30 * (n + 1) }
            match
              @dbus.notify_send(
                "MoonBit systemprobe",
                "系统能力验证页",
                "第 " + (n + 1).to_string() + " 击，进度 " + pct.to_string() + "%",
                progress=pct,
              ) {
              Ok(id) => {
                notify_state.set(
                  "通知 id=" + id.to_string() + " 进度 " + pct.to_string() + "%",
                )
                notify_hits.update(fn(k : Int) -> Int { k + 1 })
              }
              Err(e) => notify_state.set("发送失败：" + e.to_string())
            }
            app.schedule_paint()
          },
          kind=@ui.Border,
          min_width=130.0,
          handle=fn(w : @core.Widget) -> Unit { btn_notify.val = Some(w) },
        ),
        @ui.button(
          "托盘图标",
          on_click=fn() -> Unit {
            match tray_item.val {
              Some(it) => {
                it.unregister()
                tray_item.val = None
                tray_state.set("托盘：已移除")
              }
              None => {
                match @dbus.Item::create("systemprobe", "") {
                  Ok(it) => {
                    it.set_title("MoonBit 系统能力页")
                    it.set_tooltip("MoonBit", "点一下计数（窗口里看）")
                    it.add_menu_entry("刷新探测", true, fn() -> Unit { reprobe() })
                    it.add_menu_entry("退出", true, fn() -> Unit { app.quit() })
                    it.set_click_handler(fn() -> Unit {
                      tray_clicks.update(fn(k : Int) -> Int { k + 1 })
                      app.schedule_paint()
                    })
                    tray_item.val = Some(it)
                    tray_state.set("托盘：已注册（面板里应出现图标）")
                  }
                  Err(e) => tray_state.set("托盘注册失败：" + e)
                }
              }
            }
            app.schedule_paint()
          },
          kind=@ui.Border,
          min_width=110.0,
          handle=fn(w : @core.Widget) -> Unit { btn_tray.val = Some(w) },
        ),
        @ui.text_dyn(tray_state.signal(), size=12.0),
        @ui.button(
          "启用自启",
          on_click=fn() -> Unit {
            match @sys.autostart_enable(auto_id) {
              Ok(_) => {
                auto_on_hits.update(fn(n : Int) -> Int { n + 1 })
                let loc = match @sys.autostart_path(auto_id) {
                  Ok(p) => p
                  Err(_) => "-"
                }
                auto_state.set(
                  "自启动：已启用（重新登录 / 重启后拉起；落点 " + loc + "）",
                )
              }
              Err(e) => auto_state.set("启用自启失败：" + e.to_string())
            }
            app.schedule_paint()
          },
          kind=@ui.Border,
          min_width=110.0,
          handle=fn(w : @core.Widget) -> Unit { btn_auto_on.val = Some(w) },
        ),
        @ui.button(
          "取消自启",
          on_click=fn() -> Unit {
            match @sys.autostart_disable(auto_id) {
              Ok(_) => auto_state.set("自启动：已取消（幂等，本就不在也算成功）")
              Err(e) => auto_state.set("取消自启失败：" + e.to_string())
            }
            app.schedule_paint()
          },
          kind=@ui.Border,
          min_width=110.0,
          handle=fn(w : @core.Widget) -> Unit { btn_auto_off.val = Some(w) },
        ),
        @ui.text_dyn(auto_state.signal(), size=12.0),
        @ui.button(
          "读空闲",
          on_click=fn() -> Unit {
            match @sys.idle_seconds() {
              Ok(sec) => {
                idle_hits.update(fn(n : Int) -> Int { n + 1 })
                idle_state.set(
                  "空闲：" + fmt_idle(sec) + "（自最后一次输入起）",
                )
              }
              Err(e) => idle_state.set("读空闲失败：" + e.to_string())
            }
            app.schedule_paint()
          },
          kind=@ui.Border,
          min_width=110.0,
          handle=fn(w : @core.Widget) -> Unit { btn_idle.val = Some(w) },
        ),
        @ui.text_dyn(idle_state.signal(), size=12.0),
        @ui.text_dyn(
          tray_clicks.signal().map(fn(k : Int) -> String {
            "托盘点击 " + k.to_string() + " 次"
          }),
          size=12.0,
        ),
        @ui.text_dyn(notify_state.signal(), size=12.0),
        @ui.text_dyn(clip_view.signal(), size=12.0),
      ],
      direction=@yoga.Row,
      column_gap=8.0,
      row_gap=4.0,
      padding=8.0,
      align_items=@yoga.AlignItems::FlexStart,
    ),
  ])
  let _ = app.timer(12000, fn() -> Unit { app.quit() })
  app.run()
  @sys.cbw_stop(watcher)
  match tray_item.val {
    Some(it) => it.unregister()
    None => ()
  }
  let mut geo = "SYSPROBE-GEO"
  for kv in [
    ("probe", btn_probe),
    ("open", btn_open),
    ("reveal", btn_reveal),
    ("notify", btn_notify),
    ("tray", btn_tray),
    ("auto_on", btn_auto_on),
    ("auto_off", btn_auto_off),
    ("idle", btn_idle),
  ] {
    match kv.1.val {
      Some(w) => geo = geo + " " + kv.0 + "=" + rect_str(w.rect)
      None => geo = geo + " " + kv.0 + "=-"
    }
  }
  println(geo)
  let c = counts.val
  println(
    "SYSPROBE-STAT os=\{c.os_id} de=\{c.desktop} mon=\{c.monitors} " +
      "wp=\{c.wallpaper} vol=\{c.volume} prof=\{c.profile} mime=\{c.mime} " +
      "def=\{c.default_app} apps=\{c.apps} recent=\{c.recent} " +
      "hist=\{c.hist} dl=\{c.downloads} bm=\{c.bookmarks} ffx=\{c.firefox} " +
      "vsc=\{c.vscode} wins=\{c.windows} clip=\{c.clipboard} " +
      "probes=\{probes.get()} opens=\{opens.get()} reveals=\{reveals.get()} " +
      "changes=\{clip_changes.get()} ntf=\{notify_hits.get()} " +
      "tray=\{tray_clicks.get()} " +
      "pool=\{@dbus.dbus_unique_name()}",
  )
  // W21d 自启动回证：支持性 / 当前启用态 / 当前 exe / 落点 / 按钮命中数。
  // is_enabled 是即时读盘 / 读注册表，关窗后照读（与窗口读数不同）。
  println(
    "SYSPROBE-AUTOSTART supported=" +
    (if @sys.autostart_supported() { "1" } else { "0" }) +
    " enabled=" +
    (match @sys.autostart_is_enabled(auto_id) {
      Ok(true) => "1"
      Ok(false) => "0"
      Err(_) => "-"
    }) +
    " id=" +
    auto_id +
    " exe=" +
    (match @sys.autostart_exe_path() {
      Some(p) => p
      None => "-"
    }) +
    " on_hits=" +
    auto_on_hits.get().to_string() +
    " note=" +
    auto_state.get(),
  )
  // W21e 空闲回证：支持性 / 当次读数（关窗后照读）/ 按钮命中数 / 状态行。
  println(
    "SYSPROBE-IDLE supported=" +
    (if @sys.idle_supported() { "1" } else { "0" }) +
    " seconds=" +
    (match @sys.idle_seconds() {
      Ok(sec) => sec.to_string()
      Err(e) => e.to_string()
    }) +
    " hits=" +
    idle_hits.get().to_string() +
    " note=" +
    idle_state.get(),
  )
  app.shutdown()
}
