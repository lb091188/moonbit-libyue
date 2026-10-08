// ---------------------------------------------------------------------------
// 视频播放器组件：画面（黑底 letterbox）+ 悬浮控制条（悬停显隐）+ 全屏
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
/// 视频播放器组件（对标浏览器 <video> 的控件级体验）：画面黑底、帧按
/// 宽高比 letterbox 居中绘制；控制条悬浮于画面底部（position absolute
/// 半透明黑），指针进入画面显示、播放中移开 800ms 后自动隐藏（暂停/
/// 未播常显）。全屏为独立全屏窗口承载画面容器（re-parent，播放器 FFI
/// 与时钟不动）：双击画面或控制条按钮进入，Esc / 按钮 / 窗口关闭退出。
/// 50ms 时钟驱动帧推进 + schedule_paint + 控制条刷新。
pub fn video_player_t(
  player : VideoPlayer,
  style? : Array[(String, &@yue.StyVal)] = [],
  on_event? : (String) -> Unit = fn(_s) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let pos_store : @yue.Store[Double] = @yue.Store::new(0.0)
      let vol_store : @yue.Store[Double] = @yue.Store::new(
        player.volume.val * 100.0,
      )
      let time_label : Ref[@yue.Label?] = Ref(None)
      let play_btn : Ref[@yue.Button?] = Ref(None)
      let seek_defer : Ref[Int] = Ref(-1)
      // 程序刷新抑制:slider 的 on_change 对 Store.set(程序性刷新)同样
      // 触发——不抑制则播放中每 tick 都排一个冗余 seek 防抖,且换载
      // free 后残留定时器会 seek 已释放的 demuxer(悬垂崩溃根因)
      let syncing : Ref[Bool] = Ref(false)
      // 用户拖动/防抖期间锁住进度条,refresh 不得覆盖用户拖到的位置
      let user_seeking : Ref[Bool] = Ref(false)
      // 悬停显隐:指针在画面/控制条内保持显示;移开延时隐藏(拖动中不藏)
      let pointer_in : Ref[Bool] = Ref(false)
      let hide_timer : Ref[Int] = Ref(-1)
      // 全屏状态:画面容器 re-parent 进独立全屏窗口,退出时归还组件
      let fs_active : Ref[Bool] = Ref(false)
      let fs_win : Ref[@yue.Window?] = Ref(None)
      let fs_root : Ref[@yue.Container?] = Ref(None)
      // ---- 画面容器（黑底 letterbox）----
      let view_style : Array[(String, &@yue.StyVal)] = [
        ("width", 480.0),
        ("height", 300.0),
      ]
      for kv in style {
        view_style.push(kv)
      }
      let cv = @yue.themed_container(style=view_style)
      cv.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(cv)
        p.set_fill_color("#000000")
        p.fill_rect(0.0, 0.0, b.width, b.height)
        match player.current_frame() {
          Some(rgba) => {
            let vw = player.frame_width().to_double()
            let vh = player.frame_height().to_double()
            if vw > 0.0 && vh > 0.0 && b.width > 0.0 && b.height > 0.0 {
              match
                vpc_frame_image(
                  rgba,
                  player.frame_width(),
                  player.frame_height(),
                ) {
                Some(img) => {
                  // letterbox:等比缩放居中,四周留黑
                  let s = if b.width / vw < b.height / vh {
                    b.width / vw
                  } else {
                    b.height / vh
                  }
                  let dw = vw * s
                  let dh = vh * s
                  p.draw_image(
                    img,
                    (b.width - dw) / 2.0,
                    (b.height - dh) / 2.0,
                    dw,
                    dh,
                  )
                }
                None => ()
              }
            }
          }
          None => ()
        }
      })
      // ---- 控制条（悬浮画面底部,半透明黑）----
      let ctrl_bar = @yue.themed_container(style=[
        ("position", "absolute"),
        ("bottom", "0"),
        ("left", "0"),
        ("right", "0"),
        ("flexDirection", "row"),
        ("alignItems", "center"),
        ("gap", 8.0),
        ("padding", 6.0),
        ("paddingRight", 2.0),
      ])
      ctrl_bar.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(ctrl_bar)
        p.set_fill_color("#00000080")
        p.fill_rect(0.0, 0.0, b.width, b.height)
      })
      // 悬浮控制条显隐(画面与控制条共用:指针移到控制条时 GTK 会先给
      // 画面发 leave,控制条自身 enter/move 兜底):进入或移动即显示并排
      // 静止计时;静止 1s 或移出(250ms 短延时,防滑经控制条时闪烁)后,
      // 播放中隐藏;拖动进度期间顺延;暂停/未播由 refresh 常显
      fn ctrl_schedule_hide(ms : Int) -> Unit {
        if hide_timer.val >= 0 {
          @yue.clear_timeout(hide_timer.val)
        }
        hide_timer.val = @yue.set_timeout(ms, fn() {
          hide_timer.val = -1
          if player.is_closed() {
            return
          }
          if player.is_playing() {
            if user_seeking.val {
              ctrl_schedule_hide(1000)
            } else {
              @yue.ViewLike::set_visible(ctrl_bar, false)
            }
          }
        })
      }
      fn ctrl_wake() -> Unit {
        pointer_in.val = true
        @yue.ViewLike::set_visible(ctrl_bar, true)
        ctrl_schedule_hide(1000)
      }
      fn ctrl_leave() -> Unit {
        pointer_in.val = false
        ctrl_schedule_hide(250)
      }
      // ---- 控制条控件 ----
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
        color="#ffffffe6",
        handle=fn(l) { time_label.val = Some(l) },
      )
      let progress = @yue.slider_t(
        pos_store,
        min=0.0,
        max=100.0,
        step=0.5,
        bar_color="#ffffff",
        track_color="#ffffff3d",
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
      let vol = @yue.slider_t(
        vol_store,
        min=0.0,
        max=100.0,
        step=1.0,
        bar_color="#ffffff",
        track_color="#ffffff3d",
        on_change=fn(v) { player.set_volume(v / 100.0) },
      )
      let loop_cb = @yue.checkbox_t("循环", color="#ffffffe6", on_change=fn(
        on,
      ) {
        player.set_looping(on)
      })
      // 全屏按钮（自绘:随全屏态切 Fullscreen/FullscreenExit 图标）
      let fs_hover : Ref[Bool] = Ref(false)
      let fs_btn = @yue.themed_container(style=[
        ("width", 28.0),
        ("height", 28.0),
        ("marginLeft", 4.0),
      ])
      fs_btn.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(fs_btn)
        if fs_hover.val {
          p.set_fill_color("#ffffff26")
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        let kind : @yue.IconKind = if fs_active.val {
          @yue.IconKind::FullscreenExit
        } else {
          @yue.IconKind::Fullscreen
        }
        @yue.draw_icon(
          p,
          kind,
          b.width / 2.0,
          b.height / 2.0,
          15.0,
          "#ffffffd9",
        )
      })
      @yue.ViewLike::on_mouse_enter(fs_btn, fn(_e) {
        fs_hover.val = true
        @yue.ViewLike::schedule_paint(fs_btn)
      })
      @yue.ViewLike::on_mouse_leave(fs_btn, fn(_e) {
        fs_hover.val = false
        @yue.ViewLike::schedule_paint(fs_btn)
      })
      // ---- 组件根（box 只装画面;控制条悬浮在画面内）----
      let box = @yue.themed_container(style=[("flexDirection", "column")])
      box.add_child(cv)
      // ---- 全屏（画面容器 re-parent 进/出独立全屏窗口）----
      // 归还画面并收窗口（fs_active 防重入;不触碰播放器 FFI）
      fn fs_exit_quiet() -> Unit {
        if !fs_active.val {
          return
        }
        fs_active.val = false
        match (fs_win.val, fs_root.val) {
          (Some(w), Some(root)) => {
            fs_win.val = None
            fs_root.val = None
            let _ = @yue.Container::remove_child_view(
              root,
              @yue.ViewLike::view(cv),
            )
            box.add_child(cv)
            w.close()
            @yue.ViewLike::schedule_paint(cv)
          }
          _ => ()
        }
      }
      fn fs_exit() -> Unit {
        if fs_active.val {
          fs_exit_quiet()
          on_event("fullscreen-exit")
        }
      }
      fn fs_enter() -> Unit {
        if fs_active.val || player.is_closed() {
          return
        }
        fs_active.val = true
        // 根容器纯黑底承载画面（无 flex 约束,画面几何由 set_view_bounds
        // 直写——GTK 运行期改布局样式不落地,几何直写是 splitter 定案）
        let root = @yue.themed_container(style=[("flex", 1.0)])
        root.on_draw(fn(p) {
          let b = @yue.ViewLike::get_bounds(root)
          p.set_fill_color("#000000")
          p.fill_rect(0.0, 0.0, b.width, b.height)
        })
        // WM 关闭(Alt+F4 等)兜底:归还画面再收窗口
        let win = @yue.Window::make(on_close=fn(_w) { fs_exit_quiet() })
        win.set_fullscreen(true)
        fs_win.val = Some(win)
        fs_root.val = Some(root)
        let _ = @yue.Container::remove_child_view(box, @yue.ViewLike::view(cv))
        root.add_child(cv)
        win.set_content(root)
        win.activate()
        ctrl_wake()
        // 全屏切换是异步窗口状态请求,延后一拍取屏幕尺寸直写画面几何;
        // 退出后回 box 由原 width/height 样式重排恢复
        let _ = @yue.set_timeout(150, fn() {
          if fs_active.val {
            match fs_win.val {
              Some(w) => {
                let sz = w.get_content_size()
                @yue.set_view_bounds(cv, 0.0, 0.0, sz.width, sz.height)
                @yue.ViewLike::schedule_paint(cv)
              }
              None => ()
            }
          }
        })
        on_event("fullscreen")
      }
      fn fs_toggle() -> Unit {
        if fs_active.val {
          fs_exit()
        } else {
          fs_enter()
        }
      }
      let _ = @yue.ViewLike::on_mouse_down(fs_btn, fn(e) {
        if e.button == 1 {
          fs_toggle()
          true
        } else {
          false
        }
      })
      // 控制条装配(mount 内部 attach 到 ctrl_bar)
      ignore((play_btn_node.mount)(@yue.ViewLike::view(ctrl_bar)))
      ignore((progress.mount)(@yue.ViewLike::view(ctrl_bar)))
      ignore((time_lbl.mount)(@yue.ViewLike::view(ctrl_bar)))
      ignore((vol.mount)(@yue.ViewLike::view(ctrl_bar)))
      ignore((loop_cb.mount)(@yue.ViewLike::view(ctrl_bar)))
      ctrl_bar.add_child(fs_btn)
      cv.add_child(ctrl_bar)
      // ---- 画面事件:Esc 退出 / 双击切换 / 悬停显隐 ----
      @yue.ViewLike::set_focusable(cv, true)
      @yue.ViewLike::on_key_down(cv, fn(e) {
        if fs_active.val && e.code == @yue.VKEY_ESCAPE {
          fs_exit()
          true
        } else {
          false
        }
      })
      let dbl = @yue.ClickTracker::new()
      @yue.ViewLike::on_mouse_down(cv, fn(e) {
        if e.button == 1 && dbl.feed(e) >= 2 {
          fs_toggle()
          true
        } else {
          false
        }
      })
      @yue.ViewLike::on_mouse_enter(cv, fn(_e) { ctrl_wake() })
      @yue.ViewLike::on_mouse_move(cv, fn(_e) { ctrl_wake() })
      @yue.ViewLike::on_mouse_leave(cv, fn(_e) { ctrl_leave() })
      @yue.ViewLike::on_mouse_enter(ctrl_bar, fn(_e) { ctrl_wake() })
      @yue.ViewLike::on_mouse_move(ctrl_bar, fn(_e) { ctrl_wake() })
      @yue.ViewLike::on_mouse_leave(ctrl_bar, fn(_e) { ctrl_leave() })
      // ---- 刷新（时间/按钮文本/进度/暂停常显控制条）----
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
        // 暂停/未播常显;播放中且指针在外则维持隐藏态
        if !player.is_playing() && !pointer_in.val {
          @yue.ViewLike::set_visible(ctrl_bar, true)
        }
      }
      // ---- 50ms 时钟：帧推进 + 重绘 + 状态刷新（「只有第一帧」的修复
      // 核心：每 tick vp_tick 解下一帧后必须 schedule_paint 画面容器） ----
      let _ = @yue.set_timer(50, fn() {
        if player.is_closed() {
          // 全屏中换载/释放:收掉全屏窗口归还画面(不触碰已释放的 FFI)
          fs_exit_quiet()
          return false
        }
        if player.is_playing() {
          player.vp_tick()
          @yue.ViewLike::schedule_paint(cv)
        }
        refresh()
        true
      })
      @yue.attach(parent, @yue.ViewLike::view(box))
      @yue.ViewLike::view(box)
    },
  }
}
