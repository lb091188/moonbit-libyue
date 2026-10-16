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
/// 组件层的 tick 周期（毫秒）：`audio` 按它排 `pump`，静音降级模式
/// 的位置近似也按它算——两处必须是同一个数，否则无设备环境的进度会漂。
let ap_tick_ms : Int = 33

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
/// 倍速钳制：有效区间 [0.25, 4.0]；NaN 退回 1.0（「没设倍速」而不是最快/最慢档）。
fn media_clamp_speed(v : Double) -> Double {
  let x = if v != v {
    1.0
  } else if v < 0.25 {
    0.25
  } else if v > 4.0 {
    4.0
  } else {
    v
  }
  x
}

///|
/// 读第 i 个 s16 样本（小端、交错按帧内声道偏移算好）。
fn media_s16_at(src : Bytes, i : Int) -> Int {
  let lo = src[i * 2].to_int()
  let hi = src[i * 2 + 1].to_int()
  let v = (hi << 8) | lo
  if v >= 0x8000 { v - 0x10000 } else { v }
}

///|
/// s16 交错 PCM 按倍速重采样（线性插值）：`speed=2` 给一半样本数，设备照常
/// 按原采样率消费，于是媒体时间轴走得快一倍、**音高随动**——本栈不做时间
/// 拉伸（那要相位声码器），代价写在 adaptation 文档里。
/// 声道数非法 / `speed==1` / 太短都原样返回（不制造新对象）。
fn media_resample_s16(
  src : Bytes,
  channels : Int,
  speed : Double,
) -> Bytes {
  if channels <= 0 || speed == 1.0 || src.length() < channels * 4 {
    src
  } else {
    let frames = (src.length() / 2) / channels
    let n = (frames.to_double() / speed).floor().to_int()
    if n <= 0 {
      src
    } else if n == frames {
      src
    } else {
      let buf = FixedArray::make(n * channels * 2, b'\x00')
      let mut j = 0
      while j < n {
        let pos = j.to_double() * speed
        let i0 = pos.floor().to_int()
        let frac = pos - i0.to_double()
        let i1 = if i0 + 1 < frames { i0 + 1 } else { i0 }
        let mut c = 0
        while c < channels {
          let s0 = media_s16_at(src, i0 * channels + c)
          let s1 = media_s16_at(src, i1 * channels + c)
          let mut v = (
            s0.to_double() + (s1 - s0).to_double() * frac
          ).round().to_int()
          if v > 32767 {
            v = 32767
          } else if v < -32768 {
            v = -32768
          }
          let u = if v < 0 { v + 0x10000 } else { v }
          let k = (j * channels + c) * 2
          buf[k] = (u & 0xff).to_byte()
          buf[k + 1] = ((u >> 8) & 0xff).to_byte()
          c = c + 1
        }
        j = j + 1
      }
      Bytes::from_array(buf)
    }
  }
}

///|
/// FFI 句柄的 GC 隔离包装（防裸值被 drop）。
pub(all) struct AdevBox {
  h : MbtAdev
}

///|
/// 音频播放器：make 打开文件（ffmpeg Demuxer）与输出设备；组件层
/// 以 `ap_tick_ms` 定时器调 pump 推进。duration 来自容器头。
pub(all) struct AudioPlayer {
  demuxer : @ffmbt.Demuxer
  dev : Ref[MbtAdev?]
  channels : Int
  rate : Int
  duration_s : Double
  volume : Ref[Double]
  speed : Ref[Double]
  looping : Ref[Bool]
  state : Ref[ApState]
  eof : Ref[Bool]
  closed : Ref[Bool]
  played_base : Ref[Int64]
  pos_base : Ref[Double]
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
/// 播放位置（秒，媒体时间轴）：seek 基准位置 + 自基准以来设备已消费
/// 秒数；静音降级按 tick 近似累加。
pub fn AudioPlayer::current(self : AudioPlayer) -> Double {
  match self.dev.val {
    Some(d) =>
      if mbt_adev_has_device(d) == 1 {
        let consumed = mbt_adev_played_bytes(d) - self.played_base.val
        let frames = consumed.to_double() / (self.channels * 2).to_double()
        // 队列里是重采样后的样本：消费 N 个样本 = 走过 N*speed 个源样本
        let t =
          self.pos_base.val + frames * self.speed.val / self.rate.to_double()
        if t < 0.0 {
          0.0
        } else if self.duration_s > 0.0 && t > self.duration_s {
          self.duration_s
        } else {
          t
        }
      } else {
        // 哑设备：每 tick 解一帧（一帧 ≈ 一个 tick）近似推进
        self.pos_base.val + self.muted_ticks.val.to_double() *
          ap_tick_ms.to_double() / 1000.0 * self.speed.val
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
/// 倍速（0.25..4.0；钳制）。音频走 `media_resample_s16` 的线性重采样：
/// 样本数按 1/speed 缩，设备仍按原采样率消费，于是媒体时间轴快一倍、
/// **音高随动**——本栈不做时间拉伸（那要相位声码器），代价写在文档里。
/// 换速时把位置基准重钉一次（`played_base`/`pos_base`），否则时钟会跳一下。
pub fn AudioPlayer::set_speed(self : AudioPlayer, v : Double) -> Unit {
  if self.closed.val {
    return
  }
  let cur = self.current()
  self.speed.val = media_clamp_speed(v)
  match self.dev.val {
    Some(d) => self.played_base.val = mbt_adev_played_bytes(d)
    None => ()
  }
  self.pos_base.val = cur
  self.muted_ticks.val = 0
}

///|
/// 当前倍速。
pub fn AudioPlayer::get_speed(self : AudioPlayer) -> Double {
  self.speed.val
}

///|
/// 设置音量（0..1；钳制）。
pub fn AudioPlayer::set_volume(self : AudioPlayer, v : Double) -> Unit {
  if self.closed.val {
    return
  }
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
  if self.closed.val || self.state.val is ApPlaying {
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
  if self.closed.val {
    return
  }
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
  if self.closed.val {
    return
  }
  self.state.val = ApIdle
  self.ap_reset_pos()
}

///|
/// 跳转（秒；清队列重定位，播放中从新位置续播）。位置基准取 target
/// （消费字节从零重新累计），current() 落在新位置而非从 0 重新涨。
pub fn AudioPlayer::seek(self : AudioPlayer, t : Double) -> Unit {
  if self.closed.val {
    return
  }
  let target = vp_clamp_t(t, self.duration_s)
  match self.dev.val {
    Some(d) => {
      mbt_adev_clear(d)
      self.played_base.val = mbt_adev_played_bytes(d)
    }
    None => ()
  }
  ignore(self.demuxer.seek(target))
  self.pos_base.val = target
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
        // 哑设备：解一段丢一段，按基准位置+tick×ap_tick_ms 近似推进，到时长转态
        match self.demuxer.decode_pcm() {
          Some(_) => ()
          None => self.eof.val = true
        }
        self.muted_ticks.val = self.muted_ticks.val + 1
        let played = self.current()
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
            let out = media_resample_s16(pcm, self.channels, self.speed.val)
            let _ = mbt_adev_push(d, out, out.length())
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
/// 回到起点（清队列 + seek 0 + 重填；位置基准归零）。
fn AudioPlayer::ap_restart(self : AudioPlayer) -> Unit {
  match self.dev.val {
    Some(d) => {
      mbt_adev_clear(d)
      self.played_base.val = mbt_adev_played_bytes(d)
    }
    None => ()
  }
  ignore(self.demuxer.seek(0.0))
  self.pos_base.val = 0.0
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
  self.pos_base.val = 0.0
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
  let dev : AdevBox = { h: mbt_adev_open(ch, rate), }
  Ok({
    demuxer,
    dev: Ref(Some(dev.h)),
    channels: ch,
    rate,
    duration_s: demuxer.duration_s(),
    volume: Ref(media_clamp_volume(volume)),
    speed: Ref(1.0),
    looping: Ref(looping),
    state: Ref(ApIdle),
    eof: Ref(false),
    closed: Ref(false),
    played_base: Ref(0L),
    pos_base: Ref(0.0),
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
extern "c" fn mbt_adev_push(p : MbtAdev, data : Bytes, len : Int) -> Int = "mbt_adev_push"

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
