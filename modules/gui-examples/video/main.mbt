// 视频播放示例：gui-media 的 video 全包组件（引擎/控制条/字幕叠加），
// 视频区为主、右侧栏是播放列表与信息。载入路径三条——默认资产
// （modules/gui-examples/assets/1.mp4，路径对 cwd 稳健解析）、文件对话框
// 选视频、目录对话框选文件夹后扫描成播放列表。字幕双来源：不给外挂文本时
// 组件自动读**容器内嵌轨**；「选外挂 .srt」读文本后经 subtitle 参数传入
// （外部文件读取归调用方）。换曲走 holder clear_children + 重挂 video；
// 打开失败经 on_error 落错误横幅，引擎不在位时组件画说明板（不静默）。

///|
/// 视频扩展名（目录扫描与文件对话框过滤共用）。
let video_exts : Array[String] = [
  "mp4", "mkv", "mov", "avi", "webm", "flv", "ts", "wmv", "m4v", "mpg", "mpeg",
]

///|
/// 大写 ASCII → 小写（扩展名比较用；非 ASCII 原样保留）。
fn lower_ascii(s : String) -> String {
  let buf = StringBuilder()
  for ch in s {
    buf.write_char(
      if ch >= 'A' && ch <= 'Z' {
        (ch.to_int() + 32).unsafe_to_char()
      } else {
        ch
      },
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
fn is_video(name : String) -> Bool {
  for e in video_exts {
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
  let selected : @core.Store[String] = @core.Store::new("")
  let track_line : @core.Store[String] = @core.Store::new("（还没载入视频）")
  let tick_line : @core.Store[String] = @core.Store::new("")
  let sub_line : @core.Store[String] = @core.Store::new("字幕：未打开（打开时回报来源与条数）")
  let err_line : @core.Store[String] = @core.Store::new("")
  // 外挂字幕文本（空串 = 用容器内嵌轨；读取归本示例，组件只收文本）
  let sub_text : Ref[String] = Ref("")
  let list_holder : Ref[@core.Widget?] = Ref(None)
  let player_holder : Ref[@core.Widget?] = Ref(None)
  let host : Ref[@core.App?] = Ref(None)
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
  /// 把播放器挂进视频区（换载语义：清掉旧的再挂新的）。
  fn mount_player(path : String, display : String) -> Unit {
    err_line.set("")
    track_line.set("正在播放：\{display}")
    match player_holder.val {
      Some(h) => {
        h.clear_children()
        let node = @media.video(
          path,
          subtitle=sub_text.val,
          width=760.0,
          height=420.0,
          auto_play=true,
          on_tick=fn(t : Double, frames : Int, playing : Bool) -> Unit {
            if frames % 8 == 0 {
              tick_line.set(
                (if playing { "▶ " } else { "❚❚ " }) +
                  t.to_string() + "s · " + frames.to_string() + " 帧",
              )
            }
          },
          on_subtitle=fn(n : Int, embedded : Bool) -> Unit {
            if n == 0 {
              sub_line.set(
                if embedded {
                  "字幕：内嵌轨打开但 0 条（这条片没有字幕）"
                } else {
                  "字幕：外挂文本解析出 0 条（检查 .srt 时间轴格式）"
                },
              )
            } else {
              sub_line.set(
                "字幕：\{n} 条（" +
                  (if embedded { "容器内嵌轨，自动读取" } else { "外挂 SRT 文本" }) +
                  "）",
              )
            }
          },
          on_error=fn(e : String) -> Unit { fail(e) },
          handle=fn(w) {
            w.node.set_width(@yoga.percent(100.0))
            w.node.set_flex_grow(1.0)
          },
        )
        let _ = node.mount_into(h)
      }
      None => fail("视频区还没挂载，稍后再试")
    }
  }
  /// 空播放列表时给视频区一个明确的引导空态。
  fn mount_empty_player(note : String) -> Unit {
    match player_holder.val {
      Some(h) => {
        h.clear_children()
        let _ = @ui
          .view(
            [
              @ui.empty(description=note),
              @ui.text("用右侧「选择文件…」或「选择目录…」载入视频", role=@ui.Secondary),
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
  /// 按当前 tracks 重建侧栏列表；列表变化后自动跳到第一部。
  fn rebuild_list(pick_first : Bool) -> Unit {
    match list_holder.val {
      Some(h) => {
        h.clear_children()
        if tracks.val.is_empty() {
          let _ = @ui.empty(description="播放列表为空").mount_into(h)
          mount_empty_player("没有可播放的视频")
          return
        }
        let names = display_names()
        if pick_first || !arr_str_has(names, selected.get()) {
          selected.set(names[0])
        } else {
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
  // 选中名变化 → 换片（点列表项、列表重建跳首部都走这条）
  selected.subscribe(fn(name : String) {
    let names = display_names()
    let idx = arr_str_idx(names, name)
    if idx >= 0 && idx < tracks.val.length() {
      mount_player(tracks.val[idx], name)
    }
  })
  fn pick_video_file() -> Unit {
    match host.val {
      Some(a) => {
        let dlg = @sys.FileDialog::new_open()
        dlg.set_filters("视频文件:mp4,mkv,mov,avi,webm,flv,ts,wmv,m4v,mpg,mpeg|所有文件:*")
        if dlg.run_for_window(a.wid().to_int64()) {
          let p = dlg.get_result()
          tracks.val.push(p)
          toast("已加入播放列表：\{base_name(p)}", @ui.Success)
          rebuild_list(false)
          let names = display_names()
          selected.set(names[names.length() - 1])
        }
        dlg.destroy()
      }
      None => fail("宿主未就绪，打不开文件对话框")
    }
  }
  fn pick_video_dir() -> Unit {
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
                if is_video(n) {
                  found.push(dir + "/" + n)
                }
              }
              if found.is_empty() {
                tracks.val = []
                fail("目录里没有视频文件：\{dir}")
              } else {
                tracks.val = found
                toast("扫描到 \{found.length()} 个视频文件", @ui.Success)
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
  // 外挂 .srt：读文本存住，重挂当前片（subtitle 参数生效）；清除则回到内嵌轨
  fn pick_subtitle() -> Unit {
    match host.val {
      Some(a) => {
        let dlg = @sys.FileDialog::new_open()
        dlg.set_filters("字幕文件:srt,vtt|所有文件:*")
        if dlg.run_for_window(a.wid().to_int64()) {
          let p = dlg.get_result()
          match @sys.sys_read_text_file(p) {
            Some(t) => {
              sub_text.val = t
              toast("已读外挂字幕：\{base_name(p)}（换曲也沿用）", @ui.Success)
              // 重挂当前片让 subtitle 参数立即生效
              let names = display_names()
              let idx = arr_str_idx(names, selected.get())
              if idx >= 0 && idx < tracks.val.length() {
                mount_player(tracks.val[idx], selected.get())
              }
            }
            None => fail("字幕读不出（不是文本或不可读）：\{p}")
          }
        }
        dlg.destroy()
      }
      None => fail("宿主未就绪，打不开文件对话框")
    }
  }
  fn clear_subtitle() -> Unit {
    sub_text.val = ""
    sub_line.set("字幕：回到容器内嵌轨（外挂文本已清除）")
    let names = display_names()
    let idx = arr_str_idx(names, selected.get())
    if idx >= 0 && idx < tracks.val.length() {
      mount_player(tracks.val[idx], selected.get())
    }
  }
  let body = @ui.col(
    [
      @ui.col(
        [
          @ui.text("视频播放", role=@ui.Section),
          @ui.text(
            "视频区为主，侧栏是播放列表与信息；字幕双来源——容器内嵌轨自动读取，或选外挂 .srt 文本传入。控制条是图标按钮 + 进度/音量条，另有缩放三档（适配/铺满/1:1）与全屏；快捷键 空格播放/暂停、回车全屏、←/→ 逐帧、↑/↓ 音量、Esc 退全屏。",
            role=@ui.Secondary,
            max_width=960.0,
          ),
        ],
        padding=12.0,
        row_gap=4.0,
      ),
      @ui.row(
        [
          // 视频区（主）
          @ui.col(
            [@ui.col([], grow=1.0, handle=fn(c) { player_holder.val = Some(c) })],
            grow=1.0,
            padding=10.0,
            background_color="bg_panel",
            border_color="border",
          ),
          // 侧栏：播放列表 + 载入入口 + 字幕 + 状态
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
                  @ui.button("选择文件…", variant=@ui.Solid, on_click=pick_video_file),
                  @ui.button("选择目录…", variant=@ui.Soft, on_click=pick_video_dir),
                ],
                row_gap=6.0,
              ),
              @ui.divider(text="字幕"),
              @ui.col(
                [
                  @ui.button("选外挂 .srt…", on_click=pick_subtitle),
                  @ui.button("用内嵌轨", variant=@ui.Text, on_click=clear_subtitle),
                ],
                row_gap=6.0,
              ),
              @ui.divider(),
              @ui.col(
                [
                  @ui.bind_label(track_line, fn(s) { s }),
                  @ui.bind_label(tick_line, fn(s) { s }, font_size=12.0, color="text_secondary"),
                  @ui.bind_label(sub_line, fn(s) { s }, font_size=12.0, color="text_secondary"),
                  @core.bind_node(err_line.signal(), fn(e : String) -> @core.Node {
                    if e.length() == 0 {
                      @ui.view([])
                    } else {
                      @ui.alert(e, t=@ui.Danger)
                    }
                  }),
                ],
                row_gap=4.0,
              ),
            ],
            width=280.0,
            padding=10.0,
            row_gap=8.0,
            background_color="bg_panel",
            border_color="border",
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
    title="视频播放示例",
    width=1180,
    height=720,
    handle=fn(a : @core.App) {
      host.val = Some(a)
      // 首帧后载入默认资产（此时挂载已完成，播放器能直接挂进视频区）
      let _ = a.timer(0, fn() -> Unit {
        if loaded.val {
          return
        }
        loaded.val = true
        match resolve_asset("1.mp4") {
          Some(p) => {
            tracks.val = [p]
            rebuild_list(true)
          }
          None => {
            tracks.val = []
            rebuild_list(true)
            err_line.set("默认资产 1.mp4 没找到（候选：modules/gui-examples/assets/）；用「选择文件…」载入本地视频")
          }
        }
      })
    },
  )
  match mounted {
    None => {
      println("VIDEO-SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(h) => {
      println("VIDEO-READY")
      h.run()
    }
  }
}
