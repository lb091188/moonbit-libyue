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
      let vol_store : @yue.Store[Double] = @yue.Store::new(
        player.get_volume() * 100.0,
      )
      let time_label : Ref[@yue.Label?] = Ref(None)
      let play_btn : Ref[@yue.Button?] = Ref(None)
      let seek_defer : Ref[Int] = Ref(-1)
      // 程序刷新抑制(Store.set 也触发 on_change,同视频组件)与用户
      // 拖动锁(拖动中 refresh 不得覆盖进度)
      let syncing : Ref[Bool] = Ref(false)
      let user_seeking : Ref[Bool] = Ref(false)
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
      let time_lbl = @components.label_t("0:00 / 0:00", role=@components.Body, handle=fn(
        l,
      ) {
        time_label.val = Some(l)
      })
      let progress = @components.slider_t(
        pos_store,
        min=0.0,
        max=100.0,
        step=0.5,
        on_change=fn(v) {
          // 程序性刷新(refresh 的 Store.set)不触发 seek
          if syncing.val {
            return
          }
          user_seeking.val = true
          if seek_defer.val >= 0 {
            @yue.clear_timeout(seek_defer.val)
          }
          let dur = player.duration()
          let target = if dur <= 0.0 { 0.0 } else { v / 100.0 * dur }
          seek_defer.val = @yue.set_timeout(180, fn() {
            seek_defer.val = -1
            user_seeking.val = false
            // 换载/释放后的残留定时器:不得触碰已 free 的 FFI 句柄
            if player.is_closed() {
              return
            }
            player.seek(target)
            on_event("seek")
          })
        },
      )
      let vol = @components.slider_t(vol_store, min=0.0, max=100.0, step=1.0, on_change=fn(
        v,
      ) {
        player.set_volume(v / 100.0)
      })
      let loop_cb = @components.checkbox_t("循环", on_change=fn(on) {
        player.set_looping(on)
      })
      // ---- 刷新（时间/按钮文本/进度）----
      let refresh = fn() {
        // 用户拖动中不动进度条(否则拖到一半被弹回播放位置)
        if !user_seeking.val {
          syncing.val = true
          pos_store.set(
            if player.duration() > 0.0 {
              vp_pct(player.current(), player.duration()) * 100.0
            } else {
              0.0
            },
          )
          syncing.val = false
        }
        match play_btn.val {
          Some(b) =>
            b.set_title(if player.is_playing() { "暂停" } else { "播放" })
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
      let row = @declarative.hbox(style=row_style, [
        play_btn_node,
        @components.label_t("进度", role=@components.Secondary),
        progress,
        time_lbl,
        @components.label_t("音量", role=@components.Secondary),
        vol,
        loop_cb,
      ])
      (row.mount)(parent)
    },
  }
}
