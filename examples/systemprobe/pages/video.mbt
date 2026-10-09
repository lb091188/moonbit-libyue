// 视频播放页(ffmpeg 解码路线,浏览器级播放器)。两条载入路径:
// ① 演示视频:lavfi 生成 2 秒测试视频;② 本地文件:FileDialog 选盘上
// 视频真解码。换源时释放旧播放器并移除其视图;播放器挂载/报错文本
// 更新后刷新滚动范围。

///|
/// 把构建好的播放器挂进 holder:释放旧播放器、移除旧视图、挂载新
/// 控件,随后刷新滚动范围(挂载后动态长高的内容 GTK 不会自动跟上)。
fn vid_mount_player(
  app : @ui.ProbeApp,
  holder : Ref[@yue.Container?],
  status : Ref[@yue.Label?],
  vid_view : Ref[@yue.View?],
  refresh : () -> Unit,
  path : String,
  fps : Int,
  width : Int,
  height : Int,
) -> Unit {
  match @yuemedia.VideoPlayer::make(path, fps~, width~, height~) {
    Ok(player) => {
      // 换源:旧播放器先停再释放,其视图从 holder 移除
      match app.vid_player.val {
        Some(old) => {
          old.stop()
          old.free()
        }
        None => ()
      }
      app.vid_player.val = Some(player)
      // 载入即自动播放(浏览器 autoplay 同款语义;控制条仍可暂停)
      player.play()
      let node = @yuemedia.video_player_t(player)
      match holder.val {
        Some(c) => {
          match vid_view.val {
            Some(v) => {
              let _ = c.remove_child_view(v)
              ()
            }
            None => ()
          }
          let view = (node.mount)(@yue.ViewLike::view(c))
          vid_view.val = Some(view)
          match status.val {
            Some(l) =>
              l.set_text(
                "已载入 \{path}\n\{player.frame_width()}x\{player.frame_height()} · 时长 \{player.duration()}s(FFI 流式解码,播放/暂停/进度/音量/循环均可交互)",
              )
            None => ()
          }
        }
        None => ()
      }
    }
    Err(e) =>
      match status.val {
        Some(l) => l.set_text("播放器构建失败: \{e}")
        None => ()
      }
  }
  refresh()
}

///|
/// 载入演示视频:lavfi 生成 2 秒 160x120@5 测试视频(AVI 容器 + 正弦
/// 音轨)→ VideoPlayer::make(视频/音频双 Demuxer 流式打开,同步耗时)。
fn vid_load_demo(
  app : @ui.ProbeApp,
  holder : Ref[@yue.Container?],
  status : Ref[@yue.Label?],
  vid_view : Ref[@yue.View?],
  refresh : () -> Unit,
) -> Unit {
  let avi = "/tmp/yue-probe-demo.avi"
  match
    @yue.pr_run(
      "ffmpeg",
      [
        "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=duration=2:size=160x120:rate=5",
        "-f", "lavfi", "-i", "sine=frequency=440:duration=2", "-pix_fmt", "yuv420p",
        avi,
      ],
      timeout_ms=30000,
    ) {
    Ok(o) =>
      if o.exit_code != 0 {
        match status.val {
          Some(l) =>
            l.set_text("测试视频生成失败(退出码 \{o.exit_code})")
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
  vid_mount_player(app, holder, status, vid_view, refresh, avi, 5, 160, 120)
}

///|
/// 视频播放页。首次进入自动载入演示视频;「选择本地视频…」弹文件
/// 对话框取盘上文件真解码(FFI 流式逐帧解码,长短视频均完整,无帧数
/// 上限)。
pub fn page_video(app : @ui.ProbeApp) -> @yue.Node {
  let holder : Ref[@yue.Container?] = Ref(None)
  let status : Ref[@yue.Label?] = Ref(None)
  let vid_view : Ref[@yue.View?] = Ref(None)
  // 首次进页(nav_page 惰性挂载触发 holder handle)自动载入演示视频
  let auto_started : Ref[Bool] = Ref(false)
  @ui.page_shell(
    "视频播放",
    "FFI 流式解码的浏览器级播放器:播放时钟为墙钟+帧时间戳(与时长同轴、1 倍速,高帧率视频跳帧追时钟);控制条悬浮于画面底部(移动/进入即显示,静止 1s 或移出 250ms 后隐藏),双击画面或右下按钮进全屏(Esc/按钮退出),画面黑底等比 letterbox;含播放/暂停、拖进度(松手防抖)、时间、音量、循环。本地文件宽 480 按源比例。",
    fn(refresh) {
      [
        @yue.hbox(
          [
            @yue.button_t(
              if @ffmbt.ffmpeg_supported() {
                "载入演示视频"
              } else {
                "ffmpeg 不可用"
              },
              variant=@yue.Solid,
              on_click=fn() {
                match status.val {
                  Some(l) =>
                    l.set_text(
                      "载入中:生成测试视频并解码(约 1-2 秒)…",
                    )
                  None => ()
                }
                // 生成+解码同步耗时,延后一拍让状态文本先渲染
                let _ = @yue.set_timeout(50, fn() {
                  vid_load_demo(app, holder, status, vid_view, refresh)
                })
              },
            ),
            @yue.button_t("选择本地视频…", on_click=fn() {
              match app.win_ref.val {
                Some(w) => {
                  let dlg = @yue.FileDialog::new_open()
                  dlg.set_title("选择视频文件")
                  dlg.set_filters(
                    "视频文件:mp4,mkv,mov,avi,webm,flv,ts,wmv,m4v,mpg,mpeg|所有文件:*",
                  )
                  if dlg.run_for_window(w) {
                    let path = dlg.get_result()
                    app.toast_push("已选 \{path}", @yue.Success)
                    match status.val {
                      Some(l) =>
                        l.set_text(
                          "载入中:\{path}(probe + 解码同步耗时,视文件大小数秒)…",
                        )
                      None => ()
                    }
                    let _ = @yue.set_timeout(50, fn() {
                      vid_mount_player(
                        app, holder, status, vid_view, refresh, path, 12, 480, 0,
                      )
                    })
                  }
                }
                None => ()
              }
            }),
          ],
          style=[("gap", 8.0), ("alignItems", "center")],
        ),
        @yue.label_t("(播放器加载状态显示在此)", role=@yue.Body, handle=fn(
          l,
        ) {
          status.val = Some(l)
        }),
        @yue.container(handle=fn(c) {
          holder.val = Some(c)
          if !auto_started.val {
            auto_started.val = true
            // make 同步耗时 1-2 秒,延后一拍让页面先渲染
            let _ = @yue.set_timeout(300, fn() {
              if @ffmbt.ffmpeg_supported() {
                match status.val {
                  Some(l) =>
                    l.set_text(
                      "载入中:生成测试视频并解码(约 1-2 秒)…",
                    )
                  None => ()
                }
                vid_load_demo(app, holder, status, vid_view, refresh)
              }
            })
          }
        }),
      ]
    },
  )
}
