// 音频播放器（ffmpeg 解码 + miniaudio 设备直出）：Demuxer 解出 s16
// 交错 PCM 推进设备字节队列，pump 由组件定时器驱动（填充 + 播完转态）。
// 解码格式随 ffmpeg（MP3/OGG/M4A/AAC/FLAC/WAV…）。无输出设备环境
// （CI/headless）自动降级静音模式，状态机照常推进。

///|
/// 播放状态。
pub(all) enum ApState {
  ApIdle
  ApPlaying
  ApPaused
  ApEnded
}

///|
/// 填充目标：队列高于此值不再解码（约 0.3 秒的 PCM）。
let ap_high_water : Int = 40000

///|
/// 音量钳制（有效区间 [0,1]；NaN 按 0 处理）。
fn media_clamp_volume(v : Double) -> Double {
  let x = if v != v {
    0.0
  } else if v < 0.0 {
    0.0
  } else if v > 1.0 {
    1.0
  } else {
    v
  }
  x
}

///|
/// FFI 句柄的 GC 隔离包装（防裸值被 drop）。
pub(all) struct AdevBox {
  h : MbtAdev
}

///|
/// 音频播放器：make 打开文件（ffmpeg Demuxer）与输出设备；组件层
/// 以 50ms 定时器调 pump 推进。duration 来自容器头。
pub(all) struct AudioPlayer {
  demuxer : @ffmbt.Demuxer
  dev : Ref[MbtAdev?]
  channels : Int
  rate : Int
  duration_s : Double
  volume : Ref[Double]
  looping : Ref[Bool]
  state : Ref[ApState]
  eof : Ref[Bool]
  closed : Ref[Bool]
  played_base : Ref[Int64]
  muted_ticks : Ref[Int]
}

///|
/// 是否已释放（释放后组件时钟应停摆，不再触碰 FFI 句柄）。
pub fn AudioPlayer::is_closed(self : AudioPlayer) -> Bool {
  self.closed.val
}

///|
/// 播放中状态查询。
pub fn AudioPlayer::is_playing(self : AudioPlayer) -> Bool {
  self.state.val is ApPlaying
}

///|
/// 播放位置（秒；按设备已消费字节换算，静音降级按 tick 近似）。
pub fn AudioPlayer::current(self : AudioPlayer) -> Double {
  match self.dev.val {
    Some(d) =>
      if mbt_adev_has_device(d) == 1 {
        let consumed = mbt_adev_played_bytes(d) - self.played_base.val
        let frames = consumed.to_double() / (self.channels * 2).to_double()
        let t = frames / self.rate.to_double()
        if t < 0.0 {
          0.0
        } else if self.duration_s > 0.0 && t > self.duration_s {
          self.duration_s
        } else {
          t
        }
      } else {
        // 哑设备：每 tick 解一帧（一帧 ≈ 25ms）近似推进
        self.muted_ticks.val.to_double() * 0.025
      }
    None => 0.0
  }
}

///|
/// 总时长（秒；容器头无时长元数据时 0）。
pub fn AudioPlayer::duration(self : AudioPlayer) -> Double {
  self.duration_s
}

///|
/// 声道数。
pub fn AudioPlayer::channel_count(self : AudioPlayer) -> Int {
  self.channels
}

///|
/// 采样率。
pub fn AudioPlayer::sample_rate(self : AudioPlayer) -> Int {
  self.rate
}

///|
/// 是否静音降级模式（无输出设备）。
pub fn AudioPlayer::is_muted(self : AudioPlayer) -> Bool {
  match self.dev.val {
    Some(d) => mbt_adev_has_device(d) != 1
    None => true
  }
}

///|
/// 设置音量（0..1；钳制）。
pub fn AudioPlayer::set_volume(self : AudioPlayer, v : Double) -> Unit {
  let vol = media_clamp_volume(v)
  self.volume.val = vol
  match self.dev.val {
    Some(d) => mbt_adev_set_volume(d, Float::from_double(vol))
    None => ()
  }
}

///|
/// 读取当前音量。
pub fn AudioPlayer::get_volume(self : AudioPlayer) -> Double {
  self.volume.val
}

///|
/// 循环播放开关。
pub fn AudioPlayer::set_looping(self : AudioPlayer, on : Bool) -> Unit {
  self.looping.val = on
}

///|
/// 开始播放（idle/paused/ended 从当前位置续播；ended 重头）。
pub fn AudioPlayer::play(self : AudioPlayer) -> Unit {
  if self.state.val is ApPlaying {
    return
  }
  if self.state.val is ApEnded {
    self.ap_restart()
  }
  self.state.val = ApPlaying
  match self.dev.val {
    Some(d) => {
      let _ = mbt_adev_start(d)
      ()
    }
    None => ()
  }
}

///|
/// 暂停（设备停取，位置保留）。
pub fn AudioPlayer::pause(self : AudioPlayer) -> Unit {
  if self.state.val is ApPlaying {
    self.state.val = ApPaused
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
/// 停止（回起点；下次 play 从头播）。
pub fn AudioPlayer::stop(self : AudioPlayer) -> Unit {
  self.state.val = ApIdle
  self.ap_reset_pos()
}

///|
/// 跳转（秒；清队列重定位，播放中从新位置续播）。
pub fn AudioPlayer::seek(self : AudioPlayer, t : Double) -> Unit {
  let target = vp_clamp_t(t, self.duration_s)
  match self.dev.val {
    Some(d) => {
      mbt_adev_clear(d)
      self.played_base.val = mbt_adev_played_bytes(d)
    }
    None => ()
  }
  ignore(self.demuxer.seek(target))
  self.eof.val = false
  self.muted_ticks.val = 0
  if self.state.val is ApPlaying {
    self.ap_fill()
  }
}

///|
/// 释放（停设备、关 Demuxer；之后不可再用，组件时钟凭 is_closed
/// 停摆）。
pub fn AudioPlayer::free(self : AudioPlayer) -> Unit {
  if self.closed.val {
    return
  }
  self.closed.val = true
  self.state.val = ApIdle
  match self.dev.val {
    Some(d) => mbt_adev_close(d)
    None => ()
  }
  self.demuxer.close()
}

// ---------------------------------------------------------------------------
// 内部：填充与状态推进
// ---------------------------------------------------------------------------

///|
/// 推进一步（组件定时器每 tick 调用）：播放中补队列、EOF 后队列放空
/// 转态（循环则回到起点）。静音降级模式下按 tick 近似推进位置。
pub fn AudioPlayer::pump(self : AudioPlayer) -> Unit {
  if self.closed.val || !(self.state.val is ApPlaying) {
    return
  }
  match self.dev.val {
    Some(d) =>
      if mbt_adev_has_device(d) == 1 {
        self.ap_fill()
        if self.eof.val && mbt_adev_queued_bytes(d) == 0L {
          if self.looping.val {
            self.ap_restart()
          } else {
            self.state.val = ApEnded
          }
        }
      } else {
        // 哑设备：解一段丢一段，按 tick×25ms 近似推进，到时长转态
        match self.demuxer.decode_pcm() {
          Some(_) => ()
          None => self.eof.val = true
        }
        self.muted_ticks.val = self.muted_ticks.val + 1
        let played = self.muted_ticks.val.to_double() * 0.025
        if self.eof.val || played >= self.duration_s {
          if self.looping.val {
            self.ap_restart()
          } else {
            self.state.val = ApEnded
          }
        }
      }
    None => ()
  }
}

///|
/// 补队列到高水位。
fn AudioPlayer::ap_fill(self : AudioPlayer) -> Unit {
  match self.dev.val {
    Some(d) =>
      while mbt_adev_queued_bytes(d) < ap_high_water.to_int64() {
        match self.demuxer.decode_pcm() {
          Some(pcm) => {
            let _ = mbt_adev_push(d, pcm, pcm.length())
            ()
          }
          None => {
            self.eof.val = true
            break
          }
        }
      }
    None => ()
  }
}

///|
/// 回到起点（清队列 + seek 0 + 重填）。
fn AudioPlayer::ap_restart(self : AudioPlayer) -> Unit {
  match self.dev.val {
    Some(d) => {
      mbt_adev_clear(d)
      self.played_base.val = mbt_adev_played_bytes(d)
    }
    None => ()
  }
  ignore(self.demuxer.seek(0.0))
  self.eof.val = false
  self.muted_ticks.val = 0
  self.state.val = ApPlaying
  self.ap_fill()
}

///|
/// 停止态归零。
fn AudioPlayer::ap_reset_pos(self : AudioPlayer) -> Unit {
  match self.dev.val {
    Some(d) => {
      mbt_adev_clear(d)
      self.played_base.val = mbt_adev_played_bytes(d)
    }
    None => ()
  }
  ignore(self.demuxer.seek(0.0))
  self.eof.val = false
  self.muted_ticks.val = 0
}

///|
/// 打开音频文件为播放器（ffmpeg 全格式：MP3/OGG/M4A/AAC/FLAC/WAV…）。
pub fn AudioPlayer::make(
  path : String,
  volume? : Double = 0.8,
  looping? : Bool = false,
) -> Result[AudioPlayer, String] {
  let demuxer = match @ffmbt.Demuxer::open(path) {
    Ok(d) => d
    Err(e) => return Err("FFI 打开失败：\{e}")
  }
  match demuxer.open_audio_decoder() {
    Ok(_) => ()
    Err(e) => {
      demuxer.close()
      return Err("音频解码器打开失败：\{e}")
    }
  }
  let ch = demuxer.audio_channels()
  let rate = demuxer.audio_rate()
  if ch <= 0 || rate <= 0 {
    demuxer.close()
    return Err("无效音频参数 ch=\{ch} rate=\{rate}")
  }
  let dev : AdevBox = { h: mbt_adev_open(ch, rate) }
  Ok({
    demuxer,
    dev: Ref(Some(dev.h)),
    channels: ch,
    rate,
    duration_s: demuxer.duration_s(),
    volume: Ref(media_clamp_volume(volume)),
    looping: Ref(looping),
    state: Ref(ApIdle),
    eof: Ref(false),
    closed: Ref(false),
    played_base: Ref(0L),
    muted_ticks: Ref(0),
  })
}

///|
#external
pub type MbtAdev

///|
extern "c" fn mbt_adev_open(ch : Int, rate : Int) -> MbtAdev = "mbt_adev_open"

///|
#borrow(p)
extern "c" fn mbt_adev_close(p : MbtAdev) -> Unit = "mbt_adev_close"

///|
#borrow(p)
extern "c" fn mbt_adev_has_device(p : MbtAdev) -> Int = "mbt_adev_has_device"

///|
#borrow(p)
extern "c" fn mbt_adev_start(p : MbtAdev) -> Int = "mbt_adev_start"

///|
#borrow(p)
extern "c" fn mbt_adev_pause(p : MbtAdev) -> Int = "mbt_adev_pause"

///|
#borrow(p, data)
extern "c" fn mbt_adev_push(
  p : MbtAdev,
  data : Bytes,
  len : Int,
) -> Int = "mbt_adev_push"

///|
#borrow(p)
extern "c" fn mbt_adev_queued_bytes(p : MbtAdev) -> Int64 = "mbt_adev_queued_bytes"

///|
#borrow(p)
extern "c" fn mbt_adev_played_bytes(p : MbtAdev) -> Int64 = "mbt_adev_played_bytes"

///|
#borrow(p)
extern "c" fn mbt_adev_clear(p : MbtAdev) -> Unit = "mbt_adev_clear"

///|
#borrow(p)
extern "c" fn mbt_adev_set_volume(p : MbtAdev, v : Float) -> Unit = "mbt_adev_set_volume"
