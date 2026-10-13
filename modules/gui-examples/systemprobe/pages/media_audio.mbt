// 音频播放页（G7 新栈版）。与 master 旧页的差：
// ① 旧页是 `AudioPlayer::make` + `audio_player_t` 控制条 + 页内 200ms
//    is_playing 轮询三件套；新栈 gui-media 的 `player_t` 音视频一体，
//    纯音频文件同样走它（引擎自动识别无视频轨），pump 时钟并入组件——
//    三件套全部消失，页面只剩「选路径 → 挂组件」。
// ② 两条载入路径保留：演示音频（ffmpeg lavfi 生成 3 秒 440Hz 正弦 MP3）、
//    本地文件（文件对话框选盘上音频）。
// ③ 解码格式随 ffmpeg：MP3/OGG/M4A/AAC/FLAC/WAV 等常见格式均可；无输出
//    设备的降级在组件内部处理（on_error 口径上报）。

///|
/// 音频播放页。
pub fn page_audio(app : @shared.ProbeApp) -> @core.Node {
  let state : @core.Store[String] = @core.Store::new("(等待载入)")
  let holder : Ref[@core.Widget?] = Ref(None)
  @shared.page([
    @shared.section(
      "音频播放",
      "音频播放",
      "ffmpeg 解码 + 设备直出（gui-media player_t，音视频一体）：可解码 MP3/OGG/M4A/AAC/FLAC/WAV 等常见格式；演示音频由 ffmpeg lavfi 现场生成（3 秒 440Hz 正弦），本地文件走文件对话框。旧页的 AudioPlayer 手动 pump 与状态轮询已并入组件。",
      [
        @ui.row(
          [
            @ui.button("载入演示音频", variant=@ui.Solid, on_click=fn() {
              let mp3 = probe_tmp_dir() + "/yue-probe-demo.mp3"
              match
                @sys.pr_run(
                  "ffmpeg",
                  [
                    "-v", "error", "-y", "-f", "lavfi", "-i",
                    "sine=frequency=440:duration=3", "-ar", "44100", "-c:a",
                    "libmp3lame", mp3,
                  ],
                  timeout_ms=30000,
                ) {
                Ok(o) =>
                  if o.exit_code != 0 {
                    state.set("测试音频生成失败(退出码 \{o.exit_code})")
                    return
                  }
                Err(e) => {
                  state.set("ffmpeg 启动失败: \{e}")
                  return
                }
              }
              match holder.val {
                Some(h) => media_mount_player(h, mp3, 420.0, state)
                None => state.set("页面还没挂载，稍后再试")
              }
            }),
            @ui.button("选择本地音频…", on_click=fn() {
              match app.host.val {
                Some(a) => {
                  let dlg = @sys.FileDialog::new_open()
                  dlg.set_filters(
                    "音频文件:wav,mp3,ogg,m4a,flac,aac|所有文件:*",
                  )
                  if dlg.run_for_window(a.wid().to_int64()) {
                    let path = dlg.get_result()
                    match holder.val {
                      Some(h) => media_mount_player(h, path, 420.0, state)
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
        "// 音视频一体：纯音频文件同样走 player_t（引擎识别无视频轨）",
        "@media.player_t(",
        "  mp3_path,",
        "  width=420.0,",
        "  height=300.0,",
        "  auto_play=true,",
        "  on_error=fn(e) { state.set(e) },",
        ")",
        "// 演示音频由 ffmpeg 现场生成：",
        "@sys.pr_run(\"ffmpeg\", [\"-f\", \"lavfi\", \"-i\", \"sine=...\"], ...)",
      ],
    ),
  ])
}
