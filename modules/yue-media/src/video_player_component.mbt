// ---------------------------------------------------------------------------
// 视频播放器组件：画面（黑底 + 等比/原始两模式）+ 悬浮控制条（移动
// 唤醒显隐）+ 全屏（独立窗口自绘画面）。控制条为响应式形态：播放态 /
// 显示模式 / 全屏态各由一个 Store 经 swap_node 双预建显隐，时间文本走
// bind_label，无命令式句柄回写。
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
///
/// 控制条控件全部走主题组件 + Store 驱动:播放/暂停、显示模式、全屏三组
/// 双态按钮由 swap_node 按 Store 信号双预建显隐(文字/图标即状态,无
/// set_title 回写);时间文本 bind_label 订阅;进度/音量滑杆、循环复选
/// 与既有语义一致(含程序刷新抑制与拖动锁)。
pub fn video_player_t(
  player : VideoPlayer,
  style? : Array[(String, &@yue.StyVal)] = [],
  on_event? : (String) -> Unit = fn(_s) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      // ---- 状态(Store 驱动控件,refresh 只写 Store) ----
      let pos_store : @yue.Store[Double] = @yue.Store::new(0.0)
      let vol_store : @yue.Store[Double] = @yue.Store::new(
        player.volume.val * 100.0,
      )
      let time_store : @yue.Store[String] = @yue.Store::new("0:00 / 0:00")
      let playing : @yue.Store[Bool] = @yue.Store::new(player.is_playing())
      let fit_contain : @yue.Store[Bool] = @yue.Store::new(true)
      let fs_on : @yue.Store[Bool] = @yue.Store::new(false)
      // 进度拖动:程序刷新抑制 + 用户拖动锁 + 防抖(语义同旧实现)
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
      let hide_timer : Ref[Int] = Ref(-1)
      // 显示模式与全屏状态(Ref 供绘制/窗口逻辑读,控件显隐由 Store)
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
        @yue.ViewLike::set_visible(ctrl_bar, true)
        ctrl_schedule_hide(1000)
      }
      fn ctrl_leave() -> Unit {
        ctrl_schedule_hide(250)
      }
      // ---- 画面宿主事件(Esc/双击/悬停显隐;画面容器与全屏根容器
      // 各挂一份,处理函数共用;ClickTracker 共享,鼠标只落一处)。
      // 退出/进入全屏动作由参数注入,避免局部函数前向引用 ----
      fn vpc_wire_host(
        host : @yue.Container,
        on_esc : () -> Unit,
        on_dbl : () -> Unit,
      ) -> Unit {
        let dbl = @yue.ClickTracker::new()
        @yue.ViewLike::on_key_down(host, fn(e) {
          if fs_active.val && e.code == @yue.VKEY_ESCAPE {
            on_esc()
            true
          } else {
            false
          }
        })
        @yue.ViewLike::on_mouse_down(host, fn(e) {
          if e.button == 1 && dbl.feed(e) >= 2 {
            on_dbl()
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
      // 双击动作经 Ref 间接绑定(全屏进入函数先于 fs_toggle 定义,局部
      // 函数无前向引用)
      let fs_do_toggle : Ref[() -> Unit] = Ref(fn() { () })
      // 控制条归还画面容器并收窗口(fs_active 防重入;不触碰播放器 FFI)
      fn fs_exit_quiet() -> Unit {
        if !fs_active.val {
          return
        }
        fs_active.val = false
        fs_on.set(false)
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
        fs_on.set(true)
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
        vpc_wire_host(root, fn() { fs_exit() }, fn() { (fs_do_toggle.val)() })
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
      fs_do_toggle.val = fn() { fs_toggle() }
      // ---- 控制条控件(声明式 + Store 驱动) ----
      // 播放/暂停:playing 信号双预建显隐(文字即状态)
      let play_pair = @yue.swap_node(
        playing.signal(),
        @components.button_t(
          "暂停",
          variant=@components.Text,
          color="#e6ffffff",
          on_click=fn() {
            player.pause()
            playing.set(false)
            on_event("pause")
          },
          style=[("height", 28.0)],
        ),
        @components.button_t(
          "播放",
          variant=@components.Text,
          color="#e6ffffff",
          on_click=fn() {
            player.play()
            playing.set(true)
            on_event("play")
          },
          style=[("height", 28.0)],
        ),
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
      let time_lbl = @declarative.bind_label(
        time_store,
        fn(s) { s },
        style=[("marginBottom", 0.0)],
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
      // 显示模式切换:fit_contain 信号双预建(按钮文字=当前模式)
      fn fit_apply() -> Unit {
        vpc_repaint()
        on_event(if fit_contain.get() { "fit-contain" } else { "fit-original" })
      }
      let fit_pair = @yue.swap_node(
        fit_contain.signal(),
        @components.button_t(
          "等比",
          variant=@components.Text,
          color="#e6ffffff",
          on_click=fn() {
            fit_contain.set(false)
            fit_mode.val = VpFitOriginal
            fit_apply()
          },
          style=[("height", 28.0)],
        ),
        @components.button_t(
          "原始",
          variant=@components.Text,
          color="#e6ffffff",
          on_click=fn() {
            fit_contain.set(true)
            fit_mode.val = VpFitContain
            fit_apply()
          },
          style=[("height", 28.0)],
        ),
      )
      // 全屏:fs_on 信号双预建(图标即状态)
      let fs_pair = @yue.swap_node(
        fs_on.signal(),
        @icons.icon_button_t(@icons.IconKind::FullscreenExit, on_click=fn() {
          fs_exit()
        }),
        @icons.icon_button_t(@icons.IconKind::Fullscreen, on_click=fn() {
          fs_toggle()
        }),
      )
      // ---- 组件根(box 只装画面;控制条悬浮在画面内) ----
      let box = @yue.themed_container(style=[("flexDirection", "column")])
      box.add_child(cv)
      // 控制条装配(mount 内部 attach 到 ctrl_bar)
      let bar_children : Array[@yue.Node] = [
        play_pair, progress, time_lbl, vol, loop_cb, fit_pair, fs_pair,
      ]
      for ch in bar_children {
        ignore((ch.mount)(@yue.ViewLike::view(ctrl_bar)))
      }
      cv.add_child(ctrl_bar)
      vpc_wire_host(cv, fn() { fs_exit() }, fn() { fs_toggle() })
      @yue.ViewLike::on_mouse_enter(ctrl_bar, fn(_e) { ctrl_wake() })
      @yue.ViewLike::on_mouse_move(ctrl_bar, fn(_e) { ctrl_wake() })
      @yue.ViewLike::on_mouse_leave(ctrl_bar, fn(_e) { ctrl_leave() })
      // ---- 刷新(只写 Store:进度/时间/播放态) ----
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
        time_store.set(
          "\{vp_fmt_time(player.current())} / \{vp_fmt_time(player.duration())}",
        )
        playing.set(player.is_playing())
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
