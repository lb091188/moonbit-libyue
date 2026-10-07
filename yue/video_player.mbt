// 视频播放器（对标浏览器 <video> 的组件级体验）：给定文件路径，内部
// 完成 ffprobe 元信息、ffmpeg 视频帧集提取与音轨 WAV 提取，播放状态
// 机 + wall-clock 无关的定时器时钟驱动帧推进与音频同源推进；seek 用
// ffmpeg 切段播放（拖进度条防抖 180ms 后执行）。音画同步口径：音频
// 与帧定时器同为 play 起点、50ms 步进，误差在数十毫秒级（精确同步
// 需音频光标回读，见 adaptation.md 记档）。

///|
/// 播放状态。
pub(all) enum VpState {
  VpIdle
  VpPlaying
  VpPaused
}

///|
/// 播放位置（秒）→ 帧索引（钳到合法范围）。
pub fn vp_frame_idx(t_s : Double, fps : Int) -> Int {
  let f = if fps < 1 {
    1.0
  } else {
    fps.to_double()
  }
  let idx = (t_s * f).to_int()
  if idx < 0 {
    0
  } else {
    idx
  }
}

///|
/// 播放位置钳制（负值归 0；超过时长给时长-1 帧内末位；时长<=0 归 0）。
pub fn vp_clamp_t(t : Double, duration_s : Double) -> Double {
  if duration_s <= 0.0 {
    0.0
  } else if t < 0.0 {
    0.0
  } else if t > duration_s {
    duration_s
  } else {
    t
  }
}

///|
/// 进度百分比（0..1；时长<=0 给 0）。
pub fn vp_pct(t : Double, duration_s : Double) -> Double {
  if duration_s <= 0.0 {
    0.0
  } else if t <= 0.0 {
    0.0
  } else if t >= duration_s {
    1.0
  } else {
    t / duration_s
  }
}

///|
/// 时间文本（m:ss；负值按 0）。
pub fn vp_fmt_time(t : Double) -> String {
  let total = if t <= 0.0 {
    0.0
  } else {
    t
  }
  let m = (total / 60.0).to_int()
  let s = (total - m.to_double() * 60.0).to_int()
  "\{m}:\{if s < 10 { "0" } else { "" }}\{s}"
}

///|
/// 视频播放器：make 完成元信息读取、视频帧集与音轨 WAV 提取（均为
/// 同步耗时操作，调用方宜放在 set_timeout 里做或接受界面短暂卡顿）。
/// 无音轨的文件 audio 为 None（静音播放）；音轨存在时音量/静音经
/// AudioEngine 控制。
pub(all) struct VideoPlayer {
  path : String
  frames : VideoFrames
  fps : Int
  duration_s : Double
  volume : Ref[Double]
  looping : Ref[Bool]
  state : Ref[VpState]
  pos : Ref[Double]
  engine : Ref[AudioEngine?]
  clip : Ref[AudioClip?]
  audio_src : String
  audio_seg : String
  seek_defer : Ref[Int]
  timer_started : Ref[Bool]
}

///|
/// 播放中状态查询。
pub fn VideoPlayer::is_playing(self : VideoPlayer) -> Bool {
  self.state.val is VpPlaying
}

///|
/// 播放位置（秒）。
pub fn VideoPlayer::current(self : VideoPlayer) -> Double {
  self.pos.val
}

///|
/// 总时长（秒；ffprobe 拿不到时 0）。
pub fn VideoPlayer::duration(self : VideoPlayer) -> Double {
  self.duration_s
}

///|
/// 设置音量（0..1；钳制）。
pub fn VideoPlayer::set_volume(self : VideoPlayer, v : Double) -> Unit {
  let vol = audio_clamp_volume(v)
  self.volume.val = vol
  match self.clip.val {
    Some(c) => c.set_volume(vol)
    None => ()
  }
}

///|
/// 循环播放开关。
pub fn VideoPlayer::set_looping(self : VideoPlayer, on : Bool) -> Unit {
  self.looping.val = on
}

///|
/// 开始播放（idle 从当前位置起；paused 从暂停位置续播）。
pub fn VideoPlayer::play(self : VideoPlayer) -> Unit {
  if self.state.val is VpPlaying {
    return
  }
  self.state.val = VpPlaying
  self.vp_seg_audio()
  self.vp_ensure_timer()
}

///|
/// 暂停（记录位置，停音频；定时器保持但不推进）。
pub fn VideoPlayer::pause(self : VideoPlayer) -> Unit {
  if self.state.val is VpPlaying {
    self.state.val = VpPaused
    self.vp_audio_stop()
  }
}

///|
/// 停止（停音频、位置归零、状态回 idle）。
pub fn VideoPlayer::stop(self : VideoPlayer) -> Unit {
  self.state.val = VpIdle
  self.pos.val = 0.0
  self.vp_audio_stop()
}

///|
/// 跳转（秒；钳制合法范围；播放中则从新位置续播）。
pub fn VideoPlayer::seek(self : VideoPlayer, t : Double) -> Unit {
  let target = vp_clamp_t(t, self.duration_s)
  self.pos.val = target
  if self.state.val is VpPlaying {
    self.vp_seg_audio()
  }
}

///|
/// 当前帧（RGBA 字节；越界 None）——video_view_t 的帧源。
pub fn VideoPlayer::frame(self : VideoPlayer, idx : Int) -> Bytes? {
  self.frames.frame(idx)
}

///|
/// 按当前播放位置取帧。
pub fn VideoPlayer::current_frame(self : VideoPlayer) -> Bytes? {
  self.frame(vp_frame_idx(self.pos.val, self.fps))
}

///|
/// 释放（停定时器、停音频、释放引擎与剪辑；之后不可再用）。
pub fn VideoPlayer::free(self : VideoPlayer) -> Unit {
  self.vp_audio_stop()
  match self.clip.val {
    Some(c) => c.free()
    None => ()
  }
  match self.engine.val {
    Some(e) => e.free()
    None => ()
  }
}

// ---------------------------------------------------------------------------
// 内部：音频切段与帧时钟
// ---------------------------------------------------------------------------

///|
/// 从当前位置切一段音频播放（seek/play/resume 的公共路径）；无音轨
/// 或切段失败时静默（纯视频播放）。
fn VideoPlayer::vp_seg_audio(self : VideoPlayer) -> Unit {
    match self.engine.val {
      None => ()
      Some(engine) =>
        match self.audio_src {
          "" => ()
          src => {
            // 上一段先停
            self.vp_audio_stop()
            let out = self.vp_seg_path()
            let seek = self.pos.val
            let args = if seek <= 0.05 {
              ["-v", "error", "-y", "-i", src, "-c", "copy", out]
            } else {
              ["-v", "error", "-y", "-ss", fmt_axis(seek), "-i", src, "-c", "copy", out]
            }
            let seg_ok = match pr_run("ffmpeg", args, timeout_ms=30000) {
              Ok(o) => o.exit_code == 0
              Err(_) => false
            }
            if seg_ok {
              match engine.load(out, looping=self.looping.val) {
                Ok(clip) => {
                  self.clip.val = Some(clip)
                  clip.set_volume(self.volume.val)
                  clip.play()
                }
                Err(_) => ()
              }
            }
          }
        }
    }
  }

///|
/// 停当前音频段。
fn VideoPlayer::vp_audio_stop(self : VideoPlayer) -> Unit {
    match self.clip.val {
      Some(c) => {
        c.stop()
        c.free()
        self.clip.val = None
      }
      None => ()
    }
  }

///|
/// 切段输出路径（复用固定名，避免临时文件堆积）。
fn VideoPlayer::vp_seg_path(self : VideoPlayer) -> String {
    self.audio_seg
  }

///|
/// 帧推进定时器（50ms 步进；播放中推进位置、越界循环或停止）。
fn VideoPlayer::vp_ensure_timer(self : VideoPlayer) -> Unit {
    if self.timer_started.val {
      return
    }
    self.timer_started.val = true
    let mut last : Int = -1
    let _ = set_timer(50, fn() {
      if !(self.state.val is VpPlaying) {
        true
      } else {
        let idx = vp_frame_idx(self.pos.val, self.fps)
        if idx != last {
          last = idx
          self.pos.val = self.pos.val + 50.0 / 1000.0
          if self.pos.val >= self.duration_s && self.duration_s > 0.0 {
            if self.looping.val {
              self.pos.val = 0.0
              self.vp_seg_audio()
            } else {
              self.state.val = VpIdle
              self.pos.val = self.duration_s
              self.vp_audio_stop()
            }
          }
        }
        true
      }
    })
}

///|
/// 打开视频文件为播放器（同步执行：probe + 帧集提取 + 音轨提取，
/// 数秒级耗时；调用方宜放 set_timeout 或后台线程上下文）。
/// fps 为帧集抽取帧率（默认 12；源帧率更高时降采样省内存）；
/// width/height 为帧目标尺寸（0 = 源尺寸）。
pub fn VideoPlayer::make(
  path : String,
  fps? : Int = 12,
  width? : Int = 320,
  height? : Int = 0,
  volume? : Double = 0.8,
  looping? : Bool = false,
) -> Result[VideoPlayer, String] {
  let meta = match vidf_probe(path) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let frames = match vidf_extract(path, fps=fps.to_double(), width=width, height=height, max_frames=1200) {
    Ok(f) => f
    Err(e) => return Err("视频帧提取失败：\{e}")
  }
  // 音轨：提取失败（无音轨/编码不支持）时静音播放
  let audio_src = "/tmp/yue-vp-\{@subproc.get_pid()}.wav"
  let audio_seg = "/tmp/yue-vp-seg-\{@subproc.get_pid()}.wav"
  let audio_ok = match vidf_extract_audio(path, audio_src) {
    Ok(_) => true
    Err(_) => false
  }
  let engine = if audio_ok {
    match AudioEngine::new() {
      Ok(e) => Some(e)
      Err(_) => None
    }
  } else {
    None
  }
  // 时长兜底：部分容器（如 lavfi 写的 AVI）无 format duration（ffprobe
  // 输出 N/A），用帧集时长 = 帧数 / 抽取帧率
  let duration_s = if meta.duration_s > 0.0 {
    meta.duration_s
  } else {
    frames.frame_count.to_double() / fps.to_double()
  }
  Ok({
    path,
    frames,
    fps,
    duration_s,
    volume: Ref(audio_clamp_volume(volume)),
    looping: Ref(looping),
    state: Ref(VpIdle),
    pos: Ref(0.0),
    engine: Ref(engine),
    clip: Ref(None),
    audio_src: if audio_ok { audio_src } else { "" },
    audio_seg,
    seek_defer: Ref(-1),
    timer_started: Ref(false),
  })
}

// ---------------------------------------------------------------------------
// 播放器组件：画面 + 控制条（播放/暂停、进度拖拽、时间、音量、循环）
// ---------------------------------------------------------------------------

///|
/// 视频播放器组件（对标浏览器 <video> 的控件级体验）：画面按当前播放
/// 位置逐帧渲染（帧源经 player.current_frame → PNG → Image → draw_image），
/// 控制条含播放/暂停按钮、可拖进度条（松手防抖 180ms 后 seek）、时间
/// 文本、音量滑条、循环开关。player 由调用方 VideoPlayer::make 得到
/// （同步耗时，宜先 set_timeout 里准备好再挂本组件）。
pub fn video_player_t(
  player : VideoPlayer,
  style? : Array[(String, &StyVal)] = [],
  on_event? : (String) -> Unit = fn(_s) {  },
) -> Node {
  {
    mount: fn(parent) {
      // ---- 状态 ----
      let pos_store : Store[Double] = Store::new(0.0)
      let playing_store : Store[Bool] = Store::new(false)
      let vol_store : Store[Double] = Store::new(player.volume.val * 100.0)
      let time_label : Ref[Label?] = Ref(None)
      let seek_defer : Ref[Int] = Ref(-1)
      // ---- 画面 ----
      let view_style : Array[(String, &StyVal)] = [("width", 480.0), ("height", 300.0)]
      for kv in style {
        view_style.push(kv)
      }
      let cv = themed_container(style=view_style)
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        let idx = vp_frame_idx(player.pos.val, player.fps)
        match vid_frame_image(fn(i) { player.frame(i) }, idx, player.frames.width, player.frames.height) {
          Some(img) => p.draw_image(img, 0.0, 0.0, b.width, b.height)
          None => {
            p.set_fill_color(theme_bg_panel())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
        }
      })
      // ---- 控制条 ----
      // 播放/暂停按钮：原生 Button（set_title 动态文本）
      let play_btn : Ref[Button?] = Ref(None)
      let play_btn_node : Node = {
        mount: fn(parent) {
          let b = Button::new("播放")
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
          attach(parent, ViewLike::view(b))
          ViewLike::view(b)
        },
      }
      // 时间文本：label_t 的 handle 收 Label，set_text 刷新
      let time_lbl = label_t("0:00 / 0:00", role=Body, handle=fn(l) { time_label.val = Some(l) })
      let progress = slider_t(
        pos_store,
        min=0.0,
        max=100.0,
        step=0.5,
        on_change=fn(v) {
          // 拖拽：更新显示 + 防抖 seek（180ms 无新事件才真正跳）
          if seek_defer.val >= 0 {
            clear_timeout(seek_defer.val)
          }
          let dur = player.duration()
          let target = if dur <= 0.0 {
            0.0
          } else {
            v / 100.0 * dur
          }
          seek_defer.val = set_timeout(
            180,
            fn() {
              player.seek(target)
              seek_defer.val = -1
              on_event("seek")
            },
          )
        },
      )
      let vol = slider_t(
        vol_store,
        min=0.0,
        max=100.0,
        step=1.0,
        on_change=fn(v) { player.set_volume(v / 100.0) },
      )
      let loop_cb = checkbox_t("循环", on_change=fn(on) { player.set_looping(on) })
      // ---- 刷新：按钮文本/时间文本随播放状态 ----
      let refresh = fn() {
        let playing = player.is_playing()
        playing_store.set(playing)
        pos_store.set(player.pos.val)
        match play_btn.val {
          Some(b) => b.set_title(if playing { "暂停" } else { "播放" })
          None => ()
        }
        match time_label.val {
          Some(l) =>
            l.set_text("\{vp_fmt_time(player.pos.val)} / \{vp_fmt_time(player.duration())}")
          None => ()
        }
      }
      // 50ms 采样驱动进度/时间/按钮文本（播放中刷新；有位置时也刷）
      let _ = set_timer(50, fn() {
        if player.is_playing() || player.pos.val > 0.0 {
          refresh()
        }
        true
      })
      let row = hbox(
        style=[("gap", 8.0), ("alignItems", "center"), ("padding", 6.0)],
        [
          play_btn_node,
          label_t("进度", role=Secondary),
          progress,
          time_lbl,
          label_t("音量", role=Secondary),
          vol,
          loop_cb,
        ],
      )
      // 原生容器包成声明式 Node 后进 vbox
      fn vp_as_node(c : Container) -> Node {
        {
          mount: fn(parent) {
            attach(parent, ViewLike::view(c))
            ViewLike::view(c)
          },
        }
      }
      let box = vbox(style=[("gap", 6.0)], [vp_as_node(cv), row])
      let _view = (box.mount)(parent)
      _view
    },
  }
}
