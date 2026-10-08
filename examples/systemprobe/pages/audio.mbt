// 音频播放页(miniaudio 引擎:WAV/MP3/FLAC/OGG 等)。两条载入路径:
// ① 演示音频:lavfi 生成 3 秒 440Hz 正弦 WAV;② 本地文件:FileDialog
// 选盘上音频。引擎懒创建,换载先释放旧剪辑;状态标签 200ms 轮询
// is_playing(自然播完自动回落「已停止」),文本变化后刷新滚动范围。

///|
/// 状态标签轮询:直接查剪辑 is_playing(自然播完/手动停止都自动回落),
/// 未载入剪辑时显示等待文案;仅在文本变化时 set_text + 刷新滚动范围。
fn aud_poll_status(
  app : @ui.ProbeApp,
  status : Ref[@yue.Label?],
  refresh : () -> Unit,
) -> Unit {
  let last : Ref[String] = Ref("")
  let _ = @yue.set_timer(200, fn() {
    let text = match app.aud_clip.val {
      Some(c) =>
        if c.is_playing() {
          "▶ 播放中"
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
/// 载入音频文件:引擎懒创建(无输出设备时报错文本);换载先释放旧
/// 剪辑;成功后立即播放并更新路径标签。
fn aud_load(
  app : @ui.ProbeApp,
  path : String,
  path_lbl : Ref[@yue.Label?],
  status : Ref[@yue.Label?],
  refresh : () -> Unit,
) -> Unit {
  // 引擎懒创建:首次载入(或上次创建失败)时尝试建引擎
  if app.aud_engine.val is None {
    match @yue.AudioEngine::new() {
      Ok(e) => app.aud_engine.val = Some(e)
      Err(e) => {
        match status.val {
          Some(l) => l.set_text("音频引擎创建失败: \{e}")
          None => ()
        }
        refresh()
        return
      }
    }
  }
  let engine = match app.aud_engine.val {
    Some(e) => e
    None => return
  }
  match app.aud_clip.val {
    Some(old) => {
      old.stop()
      old.free()
      app.aud_clip.val = None
    }
    None => ()
  }
  match engine.load(path) {
    Ok(clip) => {
      app.aud_clip.val = Some(clip)
      clip.play()
      match path_lbl.val {
        Some(l) => l.set_text("已载入:\{path}")
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
/// 音频播放页:演示音频 / 本地文件两条载入路径 + 播放/停止/音量控制。
pub fn page_audio(app : @ui.ProbeApp) -> @yue.Node {
  let path_lbl : Ref[@yue.Label?] = Ref(None)
  let status : Ref[@yue.Label?] = Ref(None)
  let vol : @yue.Store[Double] = @yue.Store::new(80.0)
  @ui.page_shell(
    "音频播放",
    "miniaudio 后端,支持 WAV/MP3/FLAC/OGG 等;引擎懒创建,本机无输出设备时显示错误文本。 AudioClip 一次 load 对应一个可播放实例:播放/停止互斥,停止后可再播放,重复 play 无副作用。",
    fn(refresh) {
      [
        @yue.hbox(
          [
            @yue.button_t(
              "载入演示音频",
              variant=@yue.Solid,
              on_click=fn() {
                let wav = "/tmp/yue-probe-demo.wav"
                match @yue.pr_run(
                  "ffmpeg",
                  [
                    "-v", "error", "-y",
                    "-f", "lavfi", "-i", "sine=frequency=440:duration=3",
                    "-ar", "44100",
                    wav,
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
                aud_load(app, wav, path_lbl, status, refresh)
              },
            ),
            @yue.button_t(
              "选择本地音频…",
              on_click=fn() {
                match app.win_ref.val {
                  Some(w) => {
                    let dlg = @yue.FileDialog::new_open()
                    dlg.set_title("选择音频文件")
                    dlg.set_filters(
                      "音频文件:wav,mp3,flac,ogg,m4a,aac,opus,wma,aiff|所有文件:*",
                    )
                    if dlg.run_for_window(w) {
                      let path = dlg.get_result()
                      app.toast_push("已选 \{path}", @yue.Success)
                      aud_load(app, path, path_lbl, status, refresh)
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
        @yue.hbox(
          [
            @yue.button_t(
              "播放",
              on_click=fn() {
                match app.aud_clip.val {
                  Some(c) => {
                    c.play()
                    c.set_volume(vol.get() / 100.0)
                    if !c.is_playing() {
                      app.toast_push("引擎未就绪或剪辑已释放", @yue.Warning)
                    }
                  }
                  None => app.toast_push("请先载入音频", @yue.Info)
                }
              },
            ),
            @yue.button_t(
              "停止",
              on_click=fn() {
                match app.aud_clip.val {
                  Some(c) => c.stop()
                  None => ()
                }
              },
            ),
            @yue.label_t("音量", role=@yue.Body),
            @yue.slider_t(
              vol,
              min=0.0,
              max=100.0,
              step=1.0,
              on_change=fn(v) {
                match app.aud_clip.val {
                  Some(c) => c.set_volume(v / 100.0)
                  None => ()
                }
              },
              style=[("width", 220.0)],
            ),
          ],
          style=[("gap", 8.0), ("alignItems", "center")],
        ),
        @yue.label_t("(等待载入)", role=@yue.Body, handle=fn(l) {
          status.val = Some(l)
          // 状态标签就位后启动轮询(页面惰性挂载,首次进页才计时)
          aud_poll_status(app, status, refresh)
        }),
      ]
    },
  )
}
