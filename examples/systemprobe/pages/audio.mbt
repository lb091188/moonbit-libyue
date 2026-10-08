// 音频播放页(ffmpeg 解码 + miniaudio 设备直出,全格式 MP3/OGG/M4A/AAC/
// FLAC/WAV…)。两条载入路径:① 演示音频:lavfi 生成 3 秒 440Hz 正弦 MP3;
// ② 本地文件:FileDialog 选盘上音频。控制条用 audio_player_t 组件
// (自带 50ms pump 时钟:补 PCM 队列/播完转态/进度时间刷新);状态标签
// 200ms 轮询 is_playing(自然播完自动回落「已停止」)。

///|
/// 状态标签轮询:直接查播放器 is_playing(自然播完/手动停止都自动
/// 回落),未载入时显示等待文案;仅在文本变化时 set_text。
fn aud_poll_status(
  app : @ui.ProbeApp,
  status : Ref[@yue.Label?],
  refresh : () -> Unit,
) -> Unit {
  let last : Ref[String] = Ref("")
  let _ = @yue.set_timer(200, fn() {
    let text = match app.aud_ap.val {
      Some(p) =>
        if p.is_playing() {
          "▶ 播放中"
        } else if p.is_muted() {
          "■ 已停止(无输出设备,静音降级)"
        } else {
          "■ 已停止(自然播完或手动停止)"
        }
      None => "(等待载入)"
    }
    if text != last.val {
      last.val = text
      match status.val {
        Some(l) => l.set_text(text)
        None => ()
      }
      refresh()
    }
    true
  })
}

///|
/// 载入音频文件:换载先释放旧播放器并移除旧控制条;成功后立即播放并
/// 更新路径标签。解码格式随 ffmpeg(浏览器能播的常见格式均可)。
fn aud_load(
  app : @ui.ProbeApp,
  holder : Ref[@yue.Container?],
  ctrl_view : Ref[@yue.View?],
  path : String,
  path_lbl : Ref[@yue.Label?],
  status : Ref[@yue.Label?],
  refresh : () -> Unit,
) -> Unit {
  match app.aud_ap.val {
    Some(old) => {
      old.stop()
      old.free()
      app.aud_ap.val = None
    }
    None => ()
  }
  match @yuemedia.AudioPlayer::make(path) {
    Ok(p) => {
      app.aud_ap.val = Some(p)
      p.play()
      match path_lbl.val {
        Some(l) => l.set_text("已载入:\{path}")
        None => ()
      }
      // 控制条组件挂进 holder(旧视图先移除;旧组件时钟凭 is_closed 停摆)
      let node = @yuemedia.audio_player_t(p)
      match holder.val {
        Some(c) => {
          match ctrl_view.val {
            Some(v) => {
              let _ = c.remove_child_view(v)
              ()
            }
            None => ()
          }
          let view = (node.mount)(@yue.ViewLike::view(c))
          ctrl_view.val = Some(view)
        }
        None => ()
      }
    }
    Err(e) =>
      match status.val {
        Some(l) => l.set_text("音频加载失败: \{e}")
        None => ()
      }
  }
  refresh()
}

///|
/// 音频播放页:演示音频 / 本地文件两条载入路径 + audio_player_t 控制条。
pub fn page_audio(app : @ui.ProbeApp) -> @yue.Node {
  let path_lbl : Ref[@yue.Label?] = Ref(None)
  let status : Ref[@yue.Label?] = Ref(None)
  let holder : Ref[@yue.Container?] = Ref(None)
  let ctrl_view : Ref[@yue.View?] = Ref(None)
  @ui.page_shell(
    "音频播放",
    "ffmpeg 解码 + miniaudio 设备直出:可解码 MP3/OGG/M4A/AAC/FLAC/WAV 等浏览器常见格式;AudioPlayer 打开文件后由组件 50ms 时钟 pump 推进(补 PCM 队列、播完转态),控制条含播放/暂停、拖进度(松手防抖)、时间、音量、循环;无输出设备环境自动静音降级。",
    fn(refresh) {
      [
        @yue.hbox(
          [
            @yue.button_t(
              "载入演示音频",
              variant=@yue.Solid,
              on_click=fn() {
                let mp3 = "/tmp/yue-probe-demo.mp3"
                match @yue.pr_run(
                  "ffmpeg",
                  [
                    "-v", "error", "-y",
                    "-f", "lavfi", "-i", "sine=frequency=440:duration=3",
                    "-ar", "44100", "-c:a", "libmp3lame",
                    mp3,
                  ],
                  timeout_ms=30000,
                ) {
                  Ok(o) =>
                    if o.exit_code != 0 {
                      match status.val {
                        Some(l) => l.set_text("测试音频生成失败(退出码 \{o.exit_code})")
                        None => ()
                      }
                      refresh()
                      return
                    }
                  Err(e) => {
                    match status.val {
                      Some(l) => l.set_text("ffmpeg 启动失败: \{e}")
                      None => ()
                    }
                    refresh()
                    return
                  }
                }
                aud_load(app, holder, ctrl_view, mp3, path_lbl, status, refresh)
              },
            ),
            @yue.button_t(
              "选择本地音频…",
              on_click=fn() {
                match app.win_ref.val {
                  Some(w) => {
                    let dlg = @yue.FileDialog::new_open()
                    dlg.set_title("选择音频文件")
                    dlg.set_filters("音频文件:wav,mp3,ogg,m4a,flac,aac|所有文件:*")
                    if dlg.run_for_window(w) {
                      let path = dlg.get_result()
                      app.toast_push("已选 \{path}", @yue.Success)
                      aud_load(app, holder, ctrl_view, path, path_lbl, status, refresh)
                    }
                  }
                  None => ()
                }
              },
            ),
          ],
          style=[("gap", 8.0), ("alignItems", "center")],
        ),
        @yue.label_t("(未载入)", role=@yue.Body, handle=fn(l) {
          path_lbl.val = Some(l)
        }),
        // 控制条宿主:载入后由 aud_load 挂 audio_player_t(换载重挂)
        @yue.container(handle=fn(c) { holder.val = Some(c) }),
        @yue.label_t("(等待载入)", role=@yue.Body, handle=fn(l) {
          status.val = Some(l)
          // 状态标签就位后启动轮询(页面惰性挂载,首次进页才计时)
          aud_poll_status(app, status, refresh)
        }),
      ]
    },
  )
}
