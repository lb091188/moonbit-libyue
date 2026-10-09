// ---------------------------------------------------------------------------
// 视频播放器组件：画面（黑底 + 等比/原始两模式）+ 悬浮控制条（移动
// 唤醒显隐）+ 全屏（独立窗口自绘画面）
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
/// 显示模式:等比缩放(letterbox 适配容器)/ 原始尺寸(1:1 像素居中,
/// 超出容器裁剪)。
pub(all) enum VpFitMode {
  VpFitContain
  VpFitOriginal
}

///|
/// 在 (b_w × b_h) 区域按显示模式画视频帧(等比:缩放至完整可见居中;
/// 原始:源像素尺寸居中)。
fn vpc_draw_video(
  p : @yue.Painter,
  b_w : Double,
  b_h : Double,
  img : @yue.Image,
  vw : Double,
  vh : Double,
  fit : VpFitMode,
) -> Unit {
  if vw <= 0.0 || vh <= 0.0 || b_w <= 0.0 || b_h <= 0.0 {
    return
  }
  let (dw, dh) = match fit {
    VpFitContain => {
      let s = if b_w / vw < b_h / vh { b_w / vw } else { b_h / vh }
      (vw * s, vh * s)
    }
    VpFitOriginal => (vw, vh)
  }
  p.draw_image(img, (b_w - dw) / 2.0, (b_h - dh) / 2.0, dw, dh)
}

///|
/// 视频播放器组件（对标浏览器 <video> 的控件级体验）：画面黑底,帧按
/// 显示模式绘制(等比 letterbox / 原始 1:1,控制条按钮切换);控制条悬浮
/// 画面底部(半透明黑、白色控件),鼠标进入或移动即显示,静止 1 秒或移出
/// 后隐藏(与播放状态无关;拖动进度期间顺延)。全屏为独立全屏窗口自绘
/// 画面(画面绘制与事件挂到全屏根容器,几何来自窗口布局):双击画面或
/// 按钮进入,Esc / 按钮 / 窗口关闭退出。50ms 时钟驱动帧推进与刷新。
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
      // 悬浮控制条显隐:进入/移动即显示并排静止计时;静止 1s 或移出
      // (250ms 短延时防指针滑经控制条时画面 leave 先到而闪烁)后隐藏,
      // 与播放状态无关;拖动进度期间顺延
      let pointer_in : Ref[Bool] = Ref(false)
      let hide_timer : Ref[Int] = Ref(-1)
      // 显示模式与全屏状态
      let fit_mode : Ref[VpFitMode] = Ref(VpFitContain)
      let fs_active : Ref[Bool] = Ref(false)
      let fs_win : Ref[@yue.Window?] = Ref(None)
      let fs_root : Ref[@yue.Container?] = Ref(None)
      // 画面容器(创建于事件装配前,绘制与事件函数都引用它)
      let view_style : Array[(String, &@yue.StyVal)] = [
        ("width", 480.0),
        ("height", 300.0),
      ]
      for kv in style {
        view_style.push(kv)
      }
      let cv = @yue.themed_container(style=view_style)
      // 画面绘制:黑底 + 帧按显示模式(画面容器与全屏根容器共用)
      fn vpc_paint_frame(host : @yue.Container, p : @yue.Painter) -> Unit {
        let b = @yue.ViewLike::get_bounds(host)
        p.set_fill_color("#000000")
        p.fill_rect(0.0, 0.0, b.width, b.height)
        match player.current_frame() {
          Some(rgba) => {
            let vw = player.frame_width()
            let vh = player.frame_height()
            match vpc_frame_image(rgba, vw, vh) {
              Some(img) =>
                vpc_draw_video(
                  p,
                  b.width,
                  b.height,
                  img,
                  vw.to_double(),
                  vh.to_double(),
                  fit_mode.val,
                )
              None => ()
            }
          }
          None => ()
        }
      }
      // 当前画面宿主重绘(全屏时画面画在全屏根容器上)
      fn vpc_repaint() -> Unit {
        match fs_root.val {
          Some(root) => @yue.ViewLike::schedule_paint(root)
          None => ()
        }
        @yue.ViewLike::schedule_paint(cv)
      }
      cv.on_draw(fn(p) { vpc_paint_frame(cv, p) })
      // ---- 控制条(悬浮画面底部,半透明黑 + 白色控件) ----
      let ctrl_bar = @yue.themed_container(style=[
        ("position", "absolute"),
        ("bottom", "0"),
        ("left", "0"),
        ("right", "0"),
        ("height", 40.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
        ("gap", 8.0),
        ("padding", 6.0),
        ("paddingRight", 2.0),
      ])
      ctrl_bar.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(ctrl_bar)
        p.set_fill_color("#80000000")
        p.fill_rect(0.0, 0.0, b.width, b.height)
      })
      // 显隐调度
      fn ctrl_schedule_hide(ms : Int) -> Unit {
        if hide_timer.val >= 0 {
          @yue.clear_timeout(hide_timer.val)
        }
        hide_timer.val = @yue.set_timeout(ms, fn() {
          hide_timer.val = -1
          if player.is_closed() {
            return
          }
          // 静止超时或移出:隐藏(与播放状态无关);拖动进度期间顺延
          if user_seeking.val {
            ctrl_schedule_hide(1000)
          } else {
            @yue.ViewLike::set_visible(ctrl_bar, false)
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
          // 高 28 与等比/全屏自绘按钮统一(内建高度偏大,行内不齐)
          let b = @yue.Button::make(
            "播放",
            on_click=fn() {
              if player.is_playing() {
                player.pause()
                on_event("pause")
              } else {
                player.play()
                on_event("play")
              }
            },
            style=[("height", 28.0)],
          )
          play_btn.val = Some(b)
          @yue.attach(parent, @yue.ViewLike::view(b))
          @yue.ViewLike::view(b)
        },
      }
      let time_lbl = @components.label_t(
        "0:00 / 0:00",
        role=@components.Body,
        color="#e6ffffff",
        handle=fn(l) { time_label.val = Some(l) },
      )
      let progress = @components.slider_t(
        pos_store,
        min=0.0,
        max=100.0,
        step=0.5,
        bar_color="#ffffff",
        track_color="#3dffffff",
        // 内建 marginBottom 10 会把滑杆顶离行中线,归 0 交给 alignItems 居中
        style=[("marginBottom", 0.0)],
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
      let vol = @components.slider_t(
        vol_store,
        min=0.0,
        max=100.0,
        step=1.0,
        bar_color="#ffffff",
        track_color="#3dffffff",
        style=[("marginBottom", 0.0)],
        on_change=fn(v) { player.set_volume(v / 100.0) },
      )
      let loop_cb = @components.checkbox_t(
        "循环",
        color="#e6ffffff",
        style=[("marginBottom", 0.0)],
        on_change=fn(on) { player.set_looping(on) },
      )
      // 显示模式切换按钮(自绘:当前模式文字,点击等比/原始循环)
      let fit_hover : Ref[Bool] = Ref(false)
      let fit_btn = @yue.themed_container(style=[
        ("width", 44.0),
        ("height", 28.0),
      ])
      fn fit_label() -> String {
        if fit_mode.val is VpFitContain {
          "等比"
        } else {
          "原始"
        }
      }
      fit_btn.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(fit_btn)
        if fit_hover.val {
          p.set_fill_color("#26ffffff")
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        let at = @yue.AttributedText::new(
          fit_label(),
          valign=@yue.Center,
          wrap=false,
        )
        at.set_font(@yue.Font::new("Sans", 12.0))
        at.set_color("#d9ffffff")
        let tw = at.get_bounds_for(10000.0, 100.0).width
        p.draw_attributed_text(at, (b.width - tw) / 2.0, 0.0, b.width, b.height)
      })
      @yue.ViewLike::on_mouse_enter(fit_btn, fn(_e) {
        fit_hover.val = true
        @yue.ViewLike::schedule_paint(fit_btn)
      })
      @yue.ViewLike::on_mouse_leave(fit_btn, fn(_e) {
        fit_hover.val = false
        @yue.ViewLike::schedule_paint(fit_btn)
      })
      // 全屏按钮(自绘:随全屏态切 Fullscreen/FullscreenExit 图标)
      let fs_hover : Ref[Bool] = Ref(false)
      let fs_btn = @yue.themed_container(style=[
        ("width", 28.0),
        ("height", 28.0),
      ])
      fs_btn.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(fs_btn)
        if fs_hover.val {
          p.set_fill_color("#26ffffff")
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        let kind : @icons.IconKind = if fs_active.val {
          @icons.IconKind::FullscreenExit
        } else {
          @icons.IconKind::Fullscreen
        }
        @icons.draw_icon(
          p,
          kind,
          b.width / 2.0,
          b.height / 2.0,
          15.0,
          "#d9ffffff",
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
      // ---- 组件根(box 只装画面;控制条悬浮在画面内) ----
      let box = @yue.themed_container(style=[("flexDirection", "column")])
      box.add_child(cv)
      // ---- 画面宿主事件(Esc/双击/悬停显隐;画面容器与全屏根容器
      // 各挂一份,处理函数共用;ClickTracker 共享,鼠标只落一处) ----
      let dbl = @yue.ClickTracker::new()
      // 全屏动作经 Ref 间接绑定(事件装配先于 fs_exit/fs_toggle 定义,
      // 局部函数无前向引用)
      let fs_do_exit : Ref[() -> Unit] = Ref(fn() { () })
      let fs_do_toggle : Ref[() -> Unit] = Ref(fn() { () })
      fn vpc_wire_host(host : @yue.Container) -> Unit {
        @yue.ViewLike::on_key_down(host, fn(e) {
          if fs_active.val && e.code == @yue.VKEY_ESCAPE {
            (fs_do_exit.val)()
            true
          } else {
            false
          }
        })
        @yue.ViewLike::on_mouse_down(host, fn(e) {
          if e.button == 1 && dbl.feed(e) >= 2 {
            (fs_do_toggle.val)()
            true
          } else {
            false
          }
        })
        @yue.ViewLike::on_mouse_enter(host, fn(_e) { ctrl_wake() })
        @yue.ViewLike::on_mouse_move(host, fn(_e) { ctrl_wake() })
        @yue.ViewLike::on_mouse_leave(host, fn(_e) { ctrl_leave() })
      }
      // ---- 全屏:独立全屏窗口自绘画面 ----
      // 控制条归还画面容器并收窗口(fs_active 防重入;不触碰播放器 FFI)
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
              @yue.ViewLike::view(ctrl_bar),
            )
            cv.add_child(ctrl_bar)
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
        // 全屏根容器:几何来自窗口布局(flex:1 即整屏),画面绘制/事件/
        // 控制条都挂这里——不 re-parent 画面、不直写几何(set_view_bounds
        // 直写会被后续布局事件冲掉,画面停在旧尺寸的根因)
        let root = @yue.themed_container(style=[("flex", 1.0)])
        root.on_draw(fn(p) { vpc_paint_frame(root, p) })
        // WM 关闭(Alt+F4 等)兜底:归还控制条再收窗口
        let win = @yue.Window::make(on_close=fn(_w) { fs_exit_quiet() })
        win.set_fullscreen(true)
        fs_win.val = Some(win)
        fs_root.val = Some(root)
        vpc_wire_host(root)
        let _ = @yue.Container::remove_child_view(
          cv,
          @yue.ViewLike::view(ctrl_bar),
        )
        root.add_child(ctrl_bar)
        win.set_content(root)
        win.activate()
        @yue.ViewLike::set_focusable(root, true)
        @yue.ViewLike::focus(root)
        ctrl_wake()
        on_event("fullscreen")
      }
      fn fs_toggle() -> Unit {
        if fs_active.val {
          fs_exit()
        } else {
          fs_enter()
        }
      }
      fs_do_exit.val = fn() { fs_exit() }
      fs_do_toggle.val = fn() { fs_toggle() }
      let _ = @yue.ViewLike::on_mouse_down(fs_btn, fn(e) {
        if e.button == 1 {
          fs_toggle()
          true
        } else {
          false
        }
      })
      let _ = @yue.ViewLike::on_mouse_down(fit_btn, fn(e) {
        if e.button == 1 {
          fit_mode.val = if fit_mode.val is VpFitContain {
            VpFitOriginal
          } else {
            VpFitContain
          }
          vpc_repaint()
          @yue.ViewLike::schedule_paint(fit_btn)
          on_event(
            if fit_mode.val is VpFitContain {
              "fit-contain"
            } else {
              "fit-original"
            },
          )
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
      ctrl_bar.add_child(fit_btn)
      ctrl_bar.add_child(fs_btn)
      cv.add_child(ctrl_bar)
      vpc_wire_host(cv)
      @yue.ViewLike::on_mouse_enter(ctrl_bar, fn(_e) { ctrl_wake() })
      @yue.ViewLike::on_mouse_move(ctrl_bar, fn(_e) { ctrl_wake() })
      @yue.ViewLike::on_mouse_leave(ctrl_bar, fn(_e) { ctrl_leave() })
      // ---- 刷新(时间/按钮文本/进度) ----
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
      // ---- 50ms 时钟：帧推进 + 重绘 + 状态刷新 ----
      let _ = @yue.set_timer(50, fn() {
        if player.is_closed() {
          // 全屏中换载/释放:收掉全屏窗口归还控制条(不触碰 FFI)
          fs_exit_quiet()
          return false
        }
        if player.is_playing() {
          player.vp_tick()
          match fs_root.val {
            Some(root) => @yue.ViewLike::schedule_paint(root)
            None => ()
          }
          @yue.ViewLike::schedule_paint(cv)
        }
        refresh()
        true
      })
      // 初始:控制条可见,静止 1s 后自动隐藏
      ctrl_schedule_hide(1000)
      @yue.attach(parent, @yue.ViewLike::view(box))
      @yue.ViewLike::view(box)
    },
  }
}
