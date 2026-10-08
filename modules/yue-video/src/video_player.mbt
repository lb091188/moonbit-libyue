// 视频播放器（FFI 流式后端）：NoahLiu/ffmpeg 进程内
// 解码——Demuxer 顺序逐帧取 RGBA，播放时钟按 fps 定时推进（每 tick 解
// 一帧并重绘画面容器），seek 为时间戳级（avformat_seek_file）。音轨
// 提取仍走一条 ffmpeg CLI 命令（FFI 音频解码绑定留后续）；音画从
// seek/play 点各自起播，误差数十毫秒级。

///|
/// 播放状态。
pub(all) enum VpState {
  VpIdle
  VpPlaying
  VpPaused
}

///|
/// 播放位置（秒）→ 帧索引（钳非负）。
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
/// 播放位置钳制（负值归 0；超过时长给时长；时长<=0 归 0）。
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
/// 视频播放器：make 打开 FFI Demuxer 并提取音轨 WAV（同步耗时，宜放
/// set_timeout）。无音轨（提取失败/无 ffmpeg CLI）时静音播放；FFI 库
/// 不可用时 make 直接 Err。
pub(all) struct VideoPlayer {
  demuxer : @ffmpeg.Demuxer
  fps : Int
  duration_s : Double
  width : Int
  height : Int
  volume : Ref[Double]
  looping : Ref[Bool]
  state : Ref[VpState]
  pos : Ref[Double]
  frame : Ref[Bytes?]
  frame_no : Ref[Int]
  engine : Ref[@yue.AudioEngine?]
  clip : Ref[@yue.AudioClip?]
  audio_src : String
  audio_seg : String
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
/// 总时长（秒；容器头无时长元数据时 0，进度条按已知部分走）。
pub fn VideoPlayer::duration(self : VideoPlayer) -> Double {
  self.demuxer.duration_s()
}

///|
/// 输出画面宽。
pub fn VideoPlayer::frame_width(self : VideoPlayer) -> Int {
  self.width
}

///|
/// 输出画面高。
pub fn VideoPlayer::frame_height(self : VideoPlayer) -> Int {
  self.height
}

///|
/// 当前已解码帧（RGBA 字节；未开始时 None）。
pub fn VideoPlayer::current_frame(self : VideoPlayer) -> Bytes? {
  self.frame.val
}

///|
/// 设置音量（0..1；钳制）。
pub fn VideoPlayer::set_volume(self : VideoPlayer, v : Double) -> Unit {
  let vol = @yue.audio_clamp_volume(v)
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
/// 开始播放（idle/paused 从当前位置续播；首个 tick 解出首帧）。
pub fn VideoPlayer::play(self : VideoPlayer) -> Unit {
  if self.state.val is VpPlaying {
    return
  }
  self.state.val = VpPlaying
  self.vp_seg_audio()
}

///|
/// 暂停（停音频；帧时钟停；位置保留）。
pub fn VideoPlayer::pause(self : VideoPlayer) -> Unit {
  if self.state.val is VpPlaying {
    self.state.val = VpPaused
    self.vp_audio_stop()
  }
}

///|
/// 停止（停音频、seek 回 0、清当前帧、状态回 idle）。
pub fn VideoPlayer::stop(self : VideoPlayer) -> Unit {
  self.state.val = VpIdle
  self.pos.val = 0.0
  self.frame.val = None
  self.frame_no.val = 0
  self.vp_audio_stop()
  let _ = self.demuxer.seek(0.0)
}

///|
/// 跳转（秒；FFI 时间戳级；播放中从新位置续播，首帧由下一 tick 解出）。
pub fn VideoPlayer::seek(self : VideoPlayer, t : Double) -> Unit {
  let target = vp_clamp_t(t, self.duration_s)
  self.pos.val = target
  self.frame.val = None
  self.frame_no.val = vp_frame_idx(target, self.fps)
  ignore(self.demuxer.seek(target))
  if self.state.val is VpPlaying {
    self.vp_seg_audio()
  }
}

///|
/// 释放（停音频、释放引擎与剪辑、关闭 Demuxer；之后不可再用）。
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
  self.demuxer.close()
}

// ---------------------------------------------------------------------------
// 内部：帧时钟与音频切段
// ---------------------------------------------------------------------------

///|
/// 推进一步播放（组件定时器每 tick 调用；播放中解下一帧并推进位置，
/// 流结束时循环或停）。返回是否仍应继续调度。
fn VideoPlayer::vp_tick(self : VideoPlayer) -> Unit {
  if !(self.state.val is VpPlaying) {
    return
  }
  match self.demuxer.decode_rgba() {
    Some(rgba) => {
      self.frame.val = Some(rgba)
      self.frame_no.val = self.frame_no.val + 1
      self.pos.val = self.frame_no.val.to_double() / self.fps.to_double()
      if self.duration_s <= 0.0 {
        // 容器无时长元数据：按已解帧数外推，进度条可用
        ignore(self)
      }
    }
    None => {
      if self.looping.val {
        let _ = self.demuxer.seek(0.0)
        self.frame_no.val = 0
        self.pos.val = 0.0
        self.vp_seg_audio()
      } else {
        self.state.val = VpIdle
        self.vp_audio_stop()
      }
    }
  }
}

///|
/// 从当前位置切一段音频播放（play/seek/循环 的公共路径）；无音轨或
/// 切段失败时静默（纯视频播放）。
fn VideoPlayer::vp_seg_audio(self : VideoPlayer) -> Unit {
  match self.engine.val {
    None => ()
    Some(engine) =>
      match self.audio_src {
        "" => ()
        src => {
          self.vp_audio_stop()
          let seek = self.pos.val
          let args = if seek <= 0.05 {
            ["-v", "error", "-y", "-i", src, "-c", "copy", self.audio_seg]
          } else {
            [
              "-v", "error", "-y", "-ss", @yue.fmt_axis(seek), "-i", src, "-c",
              "copy", self.audio_seg,
            ]
          }
          let seg_ok = match @yue.pr_run("ffmpeg", args, timeout_ms=30000) {
            Ok(o) => o.exit_code == 0
            Err(_) => false
          }
          if seg_ok {
            match engine.load(self.audio_seg, looping=self.looping.val) {
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
/// 打开视频文件为播放器（FFI Demuxer + 音轨 WAV 提取，同步耗时；调用
/// 方宜放 set_timeout）。fps 为播放帧率（默认 12，控制帧时钟步进）；
/// width/height 为输出画面尺寸（0 = 源尺寸）。
pub fn VideoPlayer::make(
  path : String,
  fps? : Int = 12,
  width? : Int = 0,
  height? : Int = 0,
  volume? : Double = 0.8,
  looping? : Bool = false,
) -> Result[VideoPlayer, String] {
  let demuxer = match @ffmpeg.Demuxer::open(path, width~, height~) {
    Ok(d) => d
    Err(e) => return Err("FFI 打开失败：\{e}")
  }
  let duration = demuxer.duration_s()
  let w = demuxer.width
  let h = demuxer.height
  if w <= 0 || h <= 0 {
    demuxer.close()
    return Err("无效画面尺寸 \{w}x\{h}")
  }
  // 音轨：提取失败（无音轨/无 ffmpeg CLI）时静音播放
  let audio_src = "/tmp/yue-vp.wav"
  let audio_seg = "/tmp/yue-vp-seg.wav"
  let audio_ok = match audiof_extract_wav(path, audio_src) {
    Ok(_) => true
    Err(_) => false
  }
  let engine = if audio_ok {
    match @yue.AudioEngine::new() {
      Ok(e) => Some(e)
      Err(_) => None
    }
  } else {
    None
  }
  Ok({
    demuxer,
    fps,
    duration_s: duration,
    width: w,
    height: h,
    volume: Ref(@yue.audio_clamp_volume(volume)),
    looping: Ref(looping),
    state: Ref(VpIdle),
    pos: Ref(0.0),
    frame: Ref(None),
    frame_no: Ref(0),
    engine: Ref(engine),
    clip: Ref(None),
    audio_src: if audio_ok { audio_src } else { "" },
    audio_seg,
  })
}
