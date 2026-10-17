// 音频播放示例：gui-media 的 audio 音频组件（ffmpeg 解码 + miniaudio
// 设备直出），控制条（播放/进度/音量/倍速/-5s·+5s 跳转）由组件自带。
// 布局：左侧播放列表（当前曲目高亮、点击换曲），右侧播放器与状态区；
// 载入路径三条——默认资产（modules/gui-examples/assets/1.mp3，路径对 cwd
// 稳健解析）、文件对话框选音频、目录对话框选文件夹后扫描成播放列表。
// 换曲走 holder clear_children + 重挂 audio；打开失败经 on_error 落
// 错误横幅，解码引擎不在位时组件画说明板（探测 + 降级，不静默）。
// 带视频轨的文件走 video，见同模块的 video 示例。
// 歌词：按音频文件同名 .lrc 自动配对（示例侧读文本，组件不碰磁盘），
// 当前行由组件舞台区画在底部，行数经 on_lyric 落状态行。

///|
/// 音频扩展名（目录扫描与文件对话框过滤共用）。
let audio_exts : Array[String] = [
  "wav", "mp3", "ogg", "m4a", "flac", "aac", "opus", "wma",
]

///|
/// 大写 ASCII → 小写（扩展名比较用；非 ASCII 原样保留）。
fn lower_ascii(s : String) -> String {
  let buf = StringBuilder()
  for ch in s {
    buf.write_char(
      if ch >= 'A' && ch <= 'Z' { (ch.to_int() + 32).unsafe_to_char() } else { ch },
    )
  }
  buf.to_string()
}

///|
/// 文件名是否以指定扩展名结尾（大小写不敏感）。
fn has_ext(name : String, ext : String) -> Bool {
  let n = lower_ascii(name)
  let dot = "." + ext
  n.length() >= dot.length() && n[n.length() - dot.length():] == dot
}

///|
fn is_audio(name : String) -> Bool {
  for e in audio_exts {
    if has_ext(name, e) {
      return true
    }
  }
  false
}

///|
/// 路径的末段文件名（跨过最后一个分隔符；没有分隔符就原样返回）。
fn base_name(p : String) -> String {
  let mut cut = -1
  for i = 0; i < p.length(); i = i + 1 {
    if p[i] == '/' {
      cut = i
    }
  }
  if cut < 0 {
    p
  } else {
    p[cut + 1:].to_owned()
  }
}

///|
/// 字符串表里是否已有该值。
fn arr_str_has(a : Array[String], x : String) -> Bool {
  for n in a {
    if n == x {
      return true
    }
  }
  false
}

///|
/// 字符串表里该值的下标（没有则 -1）。
fn arr_str_idx(a : Array[String], x : String) -> Int {
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] == x {
      return i
    }
  }
  -1
}

///|
/// 默认资产的候选路径（moon run 可能从仓库根或模块目录起跑，逐个探测）。
fn asset_candidates(name : String) -> Array[String] {
  ["modules/gui-examples/assets/" + name, "assets/" + name, name]
}

///|
/// 解析默认资产：返回第一个存在的候选路径，都不在则 None。
fn resolve_asset(name : String) -> String? {
  for c in asset_candidates(name) {
    if @sys.sys_path_exists(c) {
      return Some(c)
    }
  }
  None
}

///|
fn main {
  let toast = @ui.toast_layer(duration_ms=2200)
  // 播放列表：完整路径表 + 选中名（menu 的 Store 存显示名）
  let tracks : Ref[Array[String]] = Ref([])
  let selected : @base.Store[String] = @base.Store::new("")
  let track_line : @base.Store[String] = @base.Store::new("（还没载入曲目）")
  let tick_line : @base.Store[String] = @base.Store::new("")
  let lyric_line : @base.Store[String] = @base.Store::new("")
  let err_line : @base.Store[String] = @base.Store::new("")
  let list_holder : Ref[@widget.Widget?] = Ref(None)
  let player_holder : Ref[@widget.Widget?] = Ref(None)
  let host : Ref[@widget.App?] = Ref(None)
  let loaded : Ref[Bool] = Ref(false)
  fn fail(msg : String) -> Unit {
    err_line.set(msg)
    toast(msg, @ui.Danger)
  }
  /// 显示名去重：同名文件追加序号，避免 menu 的选中名对不上路径。
  fn display_names() -> Array[String] {
    let names : Array[String] = []
    for p in tracks.val {
      let base = base_name(p)
      let mut disp = base
      let mut j = 2
      while arr_str_has(names, disp) {
        disp = base + " · \{j}"
        j = j + 1
      }
      names.push(disp)
    }
    names
  }
  /// 同名 .lrc 配对：把音频扩展名换成 .lrc，在就读文本传进组件
  /// （外部文件的读取归调用方，组件不碰磁盘路径）。
  fn sidecar_lyric(path : String) -> String {
    let mut dot = -1
    let mut slash = -1
    for i = 0; i < path.length(); i = i + 1 {
      if path[i] == '.' {
        dot = i
      } else if path[i] == '/' {
        slash = i
      }
    }
    let base = if dot > slash { path[0:dot].to_owned() } else { path }
    let cand = base + ".lrc"
    if !@sys.sys_path_exists(cand) {
      return ""
    }
    match @sys.sys_read_text_file(cand) {
      Some(t) => t
      None => ""
    }
  }
  /// 把播放器挂进右侧区域（换载语义：清掉旧的再挂新的）。
  fn mount_player(path : String, display : String) -> Unit {
    err_line.set("")
    track_line.set("正在播放：\{display}")
    match player_holder.val {
      Some(h) => {
        h.clear_children()
        let node = @media.audio(
          path,
          lyric=sidecar_lyric(path),
          width=560.0,
          height=220.0,
          auto_play=true,
          on_tick=fn(t : Double, playing : Bool) -> Unit {
            tick_line.set(
              (if playing { "▶ " } else { "❚❚ " }) + @media.vp_fmt_time(t),
            )
          },
          on_speed=fn(v : Double) -> Unit {
            tick_line.set("倍速 \{v.to_string()}x")
          },
          on_lyric=fn(n : Int) -> Unit {
            lyric_line.set(
              if n > 0 { "歌词 \{n} 行（同名 .lrc）" } else { "没配上同名 .lrc" },
            )
          },
          on_error=fn(e : String) -> Unit { fail(e) },
          handle=fn(w) {
            w.node.set_width(@yoga.percent(100.0))
            w.node.set_flex_grow(1.0)
          },
        )
        let _ = node.mount_into(h)
      }
      None => fail("播放器区域还没挂载，稍后再试")
    }
  }
  /// 空播放列表时给右侧一个明确的引导空态。
  fn mount_empty_player(note : String) -> Unit {
    match player_holder.val {
      Some(h) => {
        h.clear_children()
        let _ = @ui
          .view(
            [
              @ui.empty(description=note),
              @ui.text("用左侧「选择文件…」或「选择目录…」载入音频", role=@ui.Secondary),
            ],
            row_gap=6.0,
            align_items=@yoga.AlignItems::Center,
            justify_content=@yoga.JustifyContent::Center,
            padding=12.0,
            grow=1.0,
          )
          .mount_into(h)
      }
      None => ()
    }
  }
  /// 按当前 tracks 重建左侧列表；列表变化后自动跳到第一首。
  fn rebuild_list(pick_first : Bool) -> Unit {
    match list_holder.val {
      Some(h) => {
        h.clear_children()
        if tracks.val.is_empty() {
          let _ = @ui.empty(description="播放列表为空").mount_into(h)
          mount_empty_player("没有可播放的音频")
          return
        }
        let names = display_names()
        if pick_first || !arr_str_has(names, selected.get()) {
          selected.set(names[0])
        } else {
          // 选中项仍在列表里：手动重挂一次（列表重建不触发 Store）
          for i = 0; i < tracks.val.length(); i = i + 1 {
            if names[i] == selected.get() {
              mount_player(tracks.val[i], names[i])
            }
          }
        }
        let _ = @ui
          .menu(names, selected, width=232.0, handle=fn(w) {
            w.node.set_flex_grow(1.0)
          })
          .mount_into(h)
      }
      None => ()
    }
  }
  // 选中名变化 → 换曲（点列表项、列表重建跳首曲都走这条）
  selected.subscribe(fn(name : String) {
    let names = display_names()
    let idx = arr_str_idx(names, name)
    if idx >= 0 && idx < tracks.val.length() {
      mount_player(tracks.val[idx], name)
    }
  })
  fn pick_audio_file() -> Unit {
    match host.val {
      Some(a) => {
        let dlg = @sys.FileDialog::new_open()
        dlg.set_filters("音频文件:wav,mp3,ogg,m4a,flac,aac,opus,wma|所有文件:*")
        if dlg.run_for_window(a.wid().to_int64()) {
          let p = dlg.get_result()
          tracks.val.push(p)
          toast("已加入播放列表：\{base_name(p)}", @ui.Success)
          rebuild_list(false)
          // 直接切到新加的曲子
          let names = display_names()
          selected.set(names[names.length() - 1])
        }
        dlg.destroy()
      }
      None => fail("宿主未就绪，打不开文件对话框")
    }
  }
  fn pick_audio_dir() -> Unit {
    match host.val {
      Some(a) => {
        let dlg = @sys.FileDialog::new_open()
        dlg.set_options(@sys.FILE_OPTION_PICK_FOLDERS)
        if dlg.run_for_window(a.wid().to_int64()) {
          let dir = dlg.get_result()
          match @sys.fsx_list_dir(dir) {
            Ok(names) => {
              let found : Array[String] = []
              for n in names {
                if is_audio(n) {
                  found.push(dir + "/" + n)
                }
              }
              if found.is_empty() {
                tracks.val = []
                fail("目录里没有音频文件：\{dir}")
              } else {
                tracks.val = found
                toast("扫描到 \{found.length()} 个音频文件", @ui.Success)
              }
              rebuild_list(true)
            }
            Err(e) => fail("目录列举失败：\{dir}（\{e}）")
          }
        }
        dlg.destroy()
      }
      None => fail("宿主未就绪，打不开文件对话框")
    }
  }
  let body = @ui.col(
    [
      @ui.col(
        [
          @ui.text("音频播放", role=@ui.Section),
          @ui.text(
            "gui-media audio（ffmpeg 解码 + 设备直出）：列表点选换曲，控制条是图标按钮 + 进度/音量条，歌词按同名 .lrc 自动配对；快捷键 空格播放/暂停、回车全屏、←/→ ±5 秒、↑/↓ 音量、Esc 退全屏。",
            role=@ui.Secondary,
            max_width=860.0,
          ),
        ],
        padding=12.0,
        row_gap=4.0,
      ),
      @ui.row(
        [
          // 左：播放列表 + 载入入口
          @ui.col(
            [
              @ui.text("播放列表", role=@ui.Secondary),
              @ui.scroll_view(
                [@ui.col([], handle=fn(c) { list_holder.val = Some(c) })],
                @ui.ScrollState::new(),
                handle=fn(v) { v.node.set_flex_grow(1.0) },
              ),
              @ui.divider(),
              @ui.col(
                [
                  @ui.button("选择文件…", variant=@ui.Solid, on_click=pick_audio_file),
                  @ui.button("选择目录…", variant=@ui.Soft, on_click=pick_audio_dir),
                ],
                row_gap=6.0,
              ),
            ],
            width=260.0,
            padding=10.0,
            row_gap=8.0,
            background_color="bg_panel",
            border_color="border",
          ),
          // 右：播放器 + 状态区
          @ui.col(
            [
              @ui.col([], grow=1.0, handle=fn(c) { player_holder.val = Some(c) }),
              @ui.col(
                [
                  @ui.bind_label(track_line, fn(s) { s }),
                  @ui.bind_label(tick_line, fn(s) { s }, font_size=12.0, color="text_secondary"),
                  @ui.bind_label(lyric_line, fn(s) { s }, font_size=12.0, color="text_secondary"),
                  @widget.bind_node(err_line.signal(), fn(e : String) -> @widget.Node {
                    if e.length() == 0 {
                      @ui.view([])
                    } else {
                      @ui.alert(e, t=@ui.Danger)
                    }
                  }),
                ],
                row_gap=6.0,
                padding=8.0,
              ),
            ],
            grow=1.0,
            padding=10.0,
            row_gap=8.0,
          ),
        ],
        grow=1.0,
        align_items=@yoga.AlignItems::Stretch,
      ),
    ],
    grow=1.0,
  )
  let mounted = @ui.mount_window(
    [body],
    title="音频播放示例",
    width=1020,
    height=640,
    handle=fn(a : @widget.App) {
      host.val = Some(a)
      // 首帧后载入默认资产（此时挂载已完成，播放器能直接挂进右侧区域）
      let _ = a.timer(0, fn() -> Unit {
        if loaded.val {
          return
        }
        loaded.val = true
        match resolve_asset("1.mp3") {
          Some(p) => {
            tracks.val = [p]
            rebuild_list(true)
          }
          None => {
            tracks.val = []
            rebuild_list(true)
            err_line.set("默认资产 1.mp3 没找到（候选：modules/gui-examples/assets/）；用「选择文件…」载入本地音频")
          }
        }
      })
    },
  )
  match mounted {
    None => {
      println("AUDIO-SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(h) => {
      println("AUDIO-READY")
      h.run()
    }
  }
}
