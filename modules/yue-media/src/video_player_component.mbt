// ---------------------------------------------------------------------------
// 播放器组件：画面 + 控制条（播放/暂停、进度拖拽、时间、音量、循环）
// ---------------------------------------------------------------------------

///|
/// 帧字节 → Image（RGBA → PNG 内存编码 → 解码；失败 None）。
fn vpc_frame_image(bytes : Bytes, width : Int, height : Int) -> @yue.Image? {
  if bytes.length() != @yue.vid_rgba_len(width, height) {
    return None
  }
  match @yue.pngr_encode_rgba(bytes, width, height) {
    Ok(png) => {
      let img = @yue.Image::new_from_png(png)
      if img.is_empty() {
        None
      } else {
        Some(img)
      }
    }
    Err(_) => None
  }
}

///|
/// 视频播放器组件（对标浏览器 <video> 的控件级体验）：50ms 时钟驱动
/// ——播放中每 tick 调 player 的帧推进（FFI 逐帧解码）并 schedule_paint
/// 重绘画面容器（位置推进不触发重绘是上一版「只有第一帧」的根因），
/// 同时刷新进度/时间/按钮文本。控制条：播放/暂停按钮、可拖进度条
/// （松手防抖 180ms 后 seek）、时间文本、音量滑条、循环开关。
pub fn video_player_t(
  player : VideoPlayer,
  style? : Array[(String, &@yue.StyVal)] = [],
  on_event? : (String) -> Unit = fn(_s) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let pos_store : @yue.Store[Double] = @yue.Store::new(0.0)
      let vol_store : @yue.Store[Double] = @yue.Store::new(player.volume.val * 100.0)
      let time_label : Ref[@yue.Label?] = Ref(None)
      let play_btn : Ref[@yue.Button?] = Ref(None)
      let seek_defer : Ref[Int] = Ref(-1)
      // ---- 画面容器 ----
      let view_style : Array[(String, &@yue.StyVal)] = [
        ("width", 480.0),
        ("height", 300.0),
      ]
      for kv in style {
        view_style.push(kv)
      }
      let cv = @yue.themed_container(style=view_style)
      @yue.set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(cv)
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        match player.current_frame() {
          Some(rgba) =>
            match vpc_frame_image(rgba, player.frame_width(), player.frame_height()) {
              Some(img) => p.draw_image(img, 0.0, 0.0, b.width, b.height)
              None => {
                p.set_fill_color(@yue.theme_bg_panel())
                p.fill_rect(0.0, 0.0, b.width, b.height)
              }
            }
          None => {
            p.set_fill_color(@yue.theme_bg_panel())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
        }
      })
      // ---- 控制条 ----
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
      // ---- 50ms 时钟：帧推进 + 重绘 + 状态刷新（「只有第一帧」的修复
      // 核心：每 tick vp_tick 解下一帧后必须 schedule_paint 画面容器） ----
      let _ = @yue.set_timer(50, fn() {
        if player.is_closed() {
          return false
        }
        if player.is_playing() {
          player.vp_tick()
          @yue.ViewLike::schedule_paint(cv)
        }
        refresh()
        true
      })
      let row = @yue.hbox(
        style=[("gap", 8.0), ("alignItems", "center"), ("padding", 6.0)],
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
      fn vpc_as_node(c : @yue.Container) -> @yue.Node {
        {
          mount: fn(parent) {
            @yue.attach(parent, @yue.ViewLike::view(c))
            @yue.ViewLike::view(c)
          },
        }
      }
      let box = @yue.vbox(style=[("gap", 6.0)], [vpc_as_node(cv), row])
      let _view = (box.mount)(parent)
      _view
    },
  }
}
