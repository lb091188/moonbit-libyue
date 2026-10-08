// ---------------------------------------------------------------------------
// 音频播放器组件：控制条（播放/暂停、进度拖拽、时间、音量、循环）
// ---------------------------------------------------------------------------

///|
/// 音频播放器组件（对标浏览器 <audio> 的控件级体验）：50ms 时钟驱动
/// ——播放中每 tick 调 player.pump()（补 PCM 队列/播完转态）并刷新
/// 进度/时间/按钮文本。控制条：播放/暂停按钮、可拖进度条（松手防抖
/// 180ms 后 seek）、时间文本、音量滑条、循环开关。
pub fn audio_player_t(
  player : AudioPlayer,
  style? : Array[(String, &@yue.StyVal)] = [],
  on_event? : (String) -> Unit = fn(_s) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let pos_store : @yue.Store[Double] = @yue.Store::new(0.0)
      let vol_store : @yue.Store[Double] = @yue.Store::new(player.get_volume() * 100.0)
      let time_label : Ref[@yue.Label?] = Ref(None)
      let play_btn : Ref[@yue.Button?] = Ref(None)
      let seek_defer : Ref[Int] = Ref(-1)
      // ---- 播放/暂停按钮 ----
      let play_btn_node : @yue.Node = {
        mount: fn(parent) {
          let b = @yue.Button::new("播放")
          b.on_click(fn() {
            if player.is_playing() {
              player.pause()
              on_event("pause")
            } else {
              player.play()
              on_event("play")
            }
          })
          play_btn.val = Some(b)
          @yue.attach(parent, @yue.ViewLike::view(b))
          @yue.ViewLike::view(b)
        },
      }
      let time_lbl = @yue.label_t(
        "0:00 / 0:00",
        role=@yue.Body,
        handle=fn(l) { time_label.val = Some(l) },
      )
      let progress = @yue.slider_t(
        pos_store,
        min=0.0,
        max=100.0,
        step=0.5,
        on_change=fn(v) {
          if seek_defer.val >= 0 {
            @yue.clear_timeout(seek_defer.val)
          }
          let dur = player.duration()
          let target = if dur <= 0.0 {
            0.0
          } else {
            v / 100.0 * dur
          }
          seek_defer.val = @yue.set_timeout(
            180,
            fn() {
              player.seek(target)
              seek_defer.val = -1
              on_event("seek")
            },
          )
        },
      )
      let vol = @yue.slider_t(
        vol_store,
        min=0.0,
        max=100.0,
        step=1.0,
        on_change=fn(v) { player.set_volume(v / 100.0) },
      )
      let loop_cb = @yue.checkbox_t(
        "循环",
        on_change=fn(on) { player.set_looping(on) },
      )
      // ---- 刷新（时间/按钮文本/进度）----
      let refresh = fn() {
        pos_store.set(if player.duration() > 0.0 {
          vp_pct(player.current(), player.duration()) * 100.0
        } else {
          0.0
        })
        match play_btn.val {
          Some(b) => b.set_title(if player.is_playing() { "暂停" } else { "播放" })
          None => ()
        }
        match time_label.val {
          Some(l) =>
            l.set_text(
              "\{vp_fmt_time(player.current())} / \{vp_fmt_time(player.duration())}",
            )
          None => ()
        }
      }
      // ---- 50ms 时钟：补队列 + 状态推进 + 控制条刷新（播放器释放后停摆） ----
      let _ = @yue.set_timer(50, fn() {
        if player.is_closed() {
          return false
        }
        player.pump()
        refresh()
        true
      })
      let row_style : Array[(String, &@yue.StyVal)] = [
        ("gap", 8.0),
        ("alignItems", "center"),
        ("padding", 6.0),
      ]
      for kv in style {
        row_style.push(kv)
      }
      let row = @yue.hbox(
        style=row_style,
        [
          play_btn_node,
          @yue.label_t("进度", role=@yue.Secondary),
          progress,
          time_lbl,
          @yue.label_t("音量", role=@yue.Secondary),
          vol,
          loop_cb,
        ],
      )
      (row.mount)(parent)
    },
  }
}
