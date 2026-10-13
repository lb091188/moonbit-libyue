// 视频播放页（G7 新栈版）。与 master 旧页的差：
// ① 播放器从「VideoPlayer::make + video_player_t 手动分离」换成 gui-media
//    的 `player_t` 全包组件——path 直接给，内部自建引擎/控制条/字幕，
//    换载 = holder 清空重挂；观测走 on_tick/on_error。
// ② 两条载入路径保留：演示视频（ffmpeg lavfi 生成测试片，走 @sys.pr_run）、
//    本地文件（文件对话框选盘上视频真解码，parent 传宿主窗口 id）。
// ③ 「不支持 ffmpeg」语义化降级：pr_run 启动失败 / player_t on_error 都落
//    状态行，不静默。

///|
/// 演示媒体文件落点：走系统 TEMP（拿不到回落 /tmp），不往仓库里写。
fn probe_tmp_dir() -> String {
  match @sys.envx_get("TEMP") {
    Some(t) => t
    None => "/tmp"
  }
}

///|
/// 把构建好的播放器挂进 holder：清掉旧内容再挂新的（换载语义）。
fn media_mount_player(
  holder : @core.Widget,
  path : String,
  width : Double,
  state : @core.Store[String],
) -> Unit {
  state.set("载入中:\{path}…")
  holder.clear_children()
  let node = @media.player_t(
    path,
    width=width,
    height=300.0,
    auto_play=true,
    on_tick=fn(t : Double, frames : Int, playing : Bool) -> Unit {
      if playing && frames % 5 == 0 {
        state.set("▶ \{t.to_string()}s · \{frames} 帧")
      }
    },
    on_error=fn(e : String) -> Unit { state.set("播放器错误: \{e}") },
  )
  let _ = node.mount_into(holder)
  state.set("已载入 \{path}")
}

///|
/// 视频播放页。
pub fn page_video(app : @shared.ProbeApp) -> @core.Node {
  let state : @core.Store[String] = @core.Store::new("(播放器加载状态显示在此)")
  // 播放器宿主（node_of_new 挂载时填）：载入后由按钮回调清空重挂
  let holder : Ref[@core.Widget?] = Ref(None)
  @shared.page([
    @shared.section(
      "视频播放",
      "视频播放",
      "ffmpeg 流式解码的播放器组件（gui-media player_t，音视频一体）：播放/暂停、拖进度、时间、音量、倍速、循环、全屏都在控制条里；演示视频由 ffmpeg lavfi 现场生成（2 秒测试片），本地文件走文件对话框真解码。",
      [
        @ui.row(
          [
            @ui.button_t("载入演示视频", variant=@ui.Solid, on_click=fn() {
              let avi = probe_tmp_dir() + "/yue-probe-demo.avi"
              match
                @sys.pr_run(
                  "ffmpeg",
                  [
                    "-v", "error", "-y", "-f", "lavfi", "-i",
                    "testsrc=duration=2:size=160x120:rate=5", "-f", "lavfi",
                    "-i", "sine=frequency=440:duration=2", "-pix_fmt",
                    "yuv420p", avi,
                  ],
                  timeout_ms=30000,
                ) {
                Ok(o) =>
                  if o.exit_code != 0 {
                    state.set("测试视频生成失败(退出码 \{o.exit_code})")
                    return
                  }
                Err(e) => {
                  state.set("ffmpeg 启动失败: \{e}")
                  return
                }
              }
              match holder.val {
                Some(h) => media_mount_player(h, avi, 320.0, state)
                None => state.set("页面还没挂载，稍后再试")
              }
            }),
            @ui.button_t("选择本地视频…", on_click=fn() {
              match app.host.val {
                Some(a) => {
                  let dlg = @sys.FileDialog::new_open()
                  dlg.set_filters(
                    "视频文件:mp4,mkv,mov,avi,webm,flv,ts,wmv,m4v,mpg,mpeg|所有文件:*",
                  )
                  if dlg.run_for_window(a.wid().to_int64()) {
                    let path = dlg.get_result()
                    match holder.val {
                      Some(h) => media_mount_player(h, path, 480.0, state)
                      None => state.set("页面还没挂载，稍后再试")
                    }
                  }
                }
                None => state.set("宿主未就绪，打不开文件对话框")
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(state, fn(s) { s }),
        @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
          holder.val = Some(w)
          w
        }),
      ],
      code=[
        "// 播放器组件全包：path 直接给，换载 = holder 清空重挂",
        "@media.player_t(",
        "  path,",
        "  width=480.0,",
        "  height=300.0,",
        "  auto_play=true,",
        "  on_tick=fn(t, frames, playing) { ... },",
        "  on_error=fn(e) { state.set(e) },",
        ")",
        "// 演示视频由 ffmpeg 现场生成：",
        "@sys.pr_run(\"ffmpeg\", [\"-f\", \"lavfi\", ...], timeout_ms=30000)",
      ],
    ),
  ])
}
