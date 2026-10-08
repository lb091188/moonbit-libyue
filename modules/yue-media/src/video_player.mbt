// 视频播放器（FFI 流式后端）：NoahLiu/ffmpeg-mbt 进程内
// 解码——视频 Demuxer 顺序逐帧取 RGBA，播放时钟按 fps 定时推进（每
// tick 解一帧并重绘画面容器），seek 为时间戳级（avformat_seek_file）。
// 音轨为第二个独立 Demuxer（同文件各开一个容器上下文，读游标互不
// 干扰），解出 s16 PCM 直推输出设备队列——音画从 play/seek 点各自
// 起播，误差数十毫秒级。

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
/// 视频播放器：make 打开视频 Demuxer；含音轨时另开音频 Demuxer 与
/// 输出设备（FFI 全链路，无 CLI）。无音轨时静音播放；FFI 库不可用
/// 时 make 直接 Err。
pub(all) struct VideoPlayer {
  demuxer : @ffmbt.Demuxer
  audio : Ref[@ffmbt.Demuxer?]
  dev : Ref[MbtAdev?]
  fps : Int
  duration_s : Double
  width : Int
  height : Int
  volume : Ref[Double]
  looping : Ref[Bool]
  state : Ref[VpState]
  closed : Ref[Bool]
  pos : Ref[Double]
  frame : Ref[Bytes?]
  frame_no : Ref[Int]
}

///|
/// 是否已释放（释放后组件时钟应停摆，不再触碰 FFI 句柄）。
pub fn VideoPlayer::is_closed(self : VideoPlayer) -> Bool {
  self.closed.val
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
/// 总时长（秒；make 时缓存，容器头无时长元数据时 0，进度条按已知
/// 部分走）。
pub fn VideoPlayer::duration(self : VideoPlayer) -> Double {
  self.duration_s
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
/// 是否含音轨。
pub fn VideoPlayer::has_audio(self : VideoPlayer) -> Bool {
  self.audio.val is Some(_)
}

///|
/// 当前已解码帧（RGBA 字节；未开始时 None）。
pub fn VideoPlayer::current_frame(self : VideoPlayer) -> Bytes? {
  self.frame.val
}

///|
/// 设置音量（0..1；钳制）。
pub fn VideoPlayer::set_volume(self : VideoPlayer, v : Double) -> Unit {
  let vol = media_clamp_volume(v)
  self.volume.val = vol
  match self.dev.val {
    Some(d) => mbt_adev_set_volume(d, Float::from_double(vol))
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
  match self.dev.val {
    Some(d) => {
      let _ = mbt_adev_start(d)
      ()
    }
    None => ()
  }
  self.vp_fill_audio()
}

///|
/// 暂停（停帧时钟与音频设备；位置保留）。
pub fn VideoPlayer::pause(self : VideoPlayer) -> Unit {
  if self.state.val is VpPlaying {
    self.state.val = VpPaused
    match self.dev.val {
      Some(d) => {
        let _ = mbt_adev_pause(d)
        ()
      }
      None => ()
    }
  }
}

///|
/// 停止（停音频、seek 回 0、清当前帧、状态回 idle）。
pub fn VideoPlayer::stop(self : VideoPlayer) -> Unit {
  self.state.val = VpIdle
  self.pos.val = 0.0
  self.frame.val = None
  self.frame_no.val = 0
  self.vp_audio_flush()
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
  self.vp_audio_flush()
  match self.audio.val {
    Some(a) => ignore(a.seek(target))
    None => ()
  }
  if self.state.val is VpPlaying {
    self.vp_fill_audio()
  }
}

///|
/// 释放（停设备、关双 Demuxer；之后不可再用，组件时钟凭 is_closed
/// 停摆）。
pub fn VideoPlayer::free(self : VideoPlayer) -> Unit {
  if self.closed.val {
    return
  }
  self.closed.val = true
  self.state.val = VpIdle
  match self.dev.val {
    Some(d) => mbt_adev_close(d)
    None => ()
  }
  match self.audio.val {
    Some(a) => a.close()
    None => ()
  }
  self.demuxer.close()
}

// ---------------------------------------------------------------------------
// 内部：帧时钟与音频直出
// ---------------------------------------------------------------------------

///|
/// 推进一步播放（组件定时器每 tick 调用；播放中解下一帧并推进位置、
/// 补音频队列，流结束时循环或停）。
fn VideoPlayer::vp_tick(self : VideoPlayer) -> Unit {
  if self.closed.val || !(self.state.val is VpPlaying) {
    return
  }
  match self.demuxer.decode_rgba() {
    Some(rgba) => {
      self.frame.val = Some(rgba)
      self.frame_no.val = self.frame_no.val + 1
      self.pos.val = self.frame_no.val.to_double() / self.fps.to_double()
    }
    None => {
      if self.looping.val {
        let _ = self.demuxer.seek(0.0)
        self.frame_no.val = 0
        self.pos.val = 0.0
        self.vp_audio_flush()
        match self.audio.val {
          Some(a) => {
            ignore(a.seek(0.0))
            self.vp_fill_audio()
          }
          None => ()
        }
      } else {
        self.state.val = VpIdle
        self.vp_audio_flush()
        match self.dev.val {
          Some(d) => {
            let _ = mbt_adev_pause(d)
            ()
          }
          None => ()
        }
      }
    }
  }
  self.vp_fill_audio()
}

///|
/// 补音频队列到高水位（有音轨时）。
fn VideoPlayer::vp_fill_audio(self : VideoPlayer) -> Unit {
  match (self.audio.val, self.dev.val) {
    (Some(a), Some(d)) =>
      while mbt_adev_queued_bytes(d) < ap_high_water.to_int64() {
        match a.decode_pcm() {
          Some(pcm) => {
            let _ = mbt_adev_push(d, pcm, pcm.length())
            ()
          }
          None => break
        }
      }
    (_, _) => ()
  }
}

///|
/// 清音频待播队列（stop/seek 用）。
fn VideoPlayer::vp_audio_flush(self : VideoPlayer) -> Unit {
  match self.dev.val {
    Some(d) => mbt_adev_clear(d)
    None => ()
  }
}

///|
/// 打开视频文件为播放器（FFI 全链路：视频 Demuxer + 音轨独立
/// Demuxer + 输出设备；同步耗时，调用方宜放 set_timeout）。fps 为
/// 播放帧率（默认 12，控制帧时钟步进）；width/height 为输出画面
/// 尺寸（0 = 源尺寸）。
pub fn VideoPlayer::make(
  path : String,
  fps? : Int = 12,
  width? : Int = 0,
  height? : Int = 0,
  volume? : Double = 0.8,
  looping? : Bool = false,
) -> Result[VideoPlayer, String] {
  let demuxer = match @ffmbt.Demuxer::open(path) {
    Ok(d) => d
    Err(e) => return Err("FFI 打开失败：\{e}")
  }
  match demuxer.open_video_decoder(width~, height~) {
    Ok(_) => ()
    Err(e) => {
      demuxer.close()
      return Err("视频解码器打开失败：\{e}")
    }
  }
  let duration = demuxer.duration_s()
  let w = demuxer.out_width()
  let h = demuxer.out_height()
  if w <= 0 || h <= 0 {
    demuxer.close()
    return Err("无效画面尺寸 \{w}x\{h}")
  }
  // 音轨：同文件再开一个独立容器上下文（读游标与视频互不干扰）；
  // 无音轨或解码器不可用时静音播放
  let audio : Ref[@ffmbt.Demuxer?] = Ref(None)
  let dev : Ref[MbtAdev?] = Ref(None)
  if demuxer.has_audio() {
    match @ffmbt.Demuxer::open(path) {
      Ok(ad) =>
        match ad.open_audio_decoder() {
          Ok(_) => {
            let ch = ad.audio_channels()
            let rate = ad.audio_rate()
            if ch > 0 && rate > 0 {
              let boxed : AdevBox = { h: mbt_adev_open(ch, rate) }
              dev.val = Some(boxed.h)
              audio.val = Some(ad)
            } else {
              ad.close()
            }
          }
          Err(_) => ad.close()
      }
      Err(_) => ()
    }
  }
  Ok({
    demuxer,
    audio,
    dev,
    fps,
    duration_s: duration,
    width: w,
    height: h,
    volume: Ref(media_clamp_volume(volume)),
    looping: Ref(looping),
    state: Ref(VpIdle),
    closed: Ref(false),
    pos: Ref(0.0),
    frame: Ref(None),
    frame_no: Ref(0),
  })
}
