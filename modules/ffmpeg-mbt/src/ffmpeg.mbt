///|
/// ffmpeg 动态链是否可用（进程内缓存，首次探测版本导出）。
pub fn ffmpeg_supported() -> Bool {
  let cached = supported_cache.val
  if cached >= 0 {
    return cached == 1
  }
  let ok = vf_version() > 0
  supported_cache.val = if ok { 1 } else { 0 }
  ok
}

let supported_cache : Ref[Int] = Ref(-1)

///|
/// ffmpeg 库版本（avformat_version，如 60161637 对应 6.1）。
pub fn ffmpeg_version() -> Int {
  vf_version()
}

///|
/// 打开失败/解码错误。
pub(all) enum VfError {
  OpenFailed(String)
  NoMediaStream
  DecodeFailed(String)
}

///|
pub impl Show for VfError with fn output(self, logger) {
  match self {
    OpenFailed(msg) => {
      logger.write_string("打开失败：")
      logger.write_string(msg)
    }
    NoMediaStream => logger.write_string("未找到可解的媒体流")
    DecodeFailed(msg) => {
      logger.write_string("解码失败：")
      logger.write_string(msg)
    }
  }
}

///|
pub extend VfError with Show::{to_string, output}

///|
/// 容器 + 视频流/音频流解码上下文。open 只开容器探测流；视频/音频
/// 解码器按需显式打开（纯音频文件不开视频、反之亦然）。视频解码器
/// 输出 RGBA（sws），音频解码器输出 s16 交错 PCM（swr）。
pub(all) struct Demuxer {
  fmt : VfFmt
  mut dec : VfDec
  mut adec : VfADec
}

///|
/// FFI 句柄的 GC 隔离包装（防裸值被 drop）。
pub(all) struct VfFmtBox {
  h : VfFmt
}

///|
/// FFI 句柄的 GC 隔离包装（防裸值被 drop）。
pub(all) struct VfDecBox {
  h : VfDec
}

///|
/// FFI 句柄的 GC 隔离包装（防裸值被 drop）。
pub(all) struct VfADecBox {
  h : VfADec
}

///|
/// 打开媒体文件（视频 AVI/MP4/MKV/WebM、音频 MP3/OGG/FLAC/M4A…
/// 随 ffmpeg 解码器覆盖）。容器无任何可解媒体流时 Err。视频/音频
/// 解码器随后按需 open_video_decoder / open_audio_decoder。
pub fn Demuxer::open(path : String) -> Result[Demuxer, VfError] {
  // FFI 返回的裸指针不能裸绑定（MoonBit GC 会把裸 extern 值当 GC 对象
  // drop 导致 mi_free 段错误），必须立即装进 struct 字段（extern 类型
  // 字段不归 GC 管理）
  let fmt : VfFmtBox = { h: vf_open(@utf8.encode(path)) }
  if vf_ok(fmt.h) != 1 {
    vf_close(fmt.h)
    return Err(OpenFailed(path))
  }
  if vf_video_stream(fmt.h) < 0 && vf_audio_stream(fmt.h) < 0 {
    vf_close(fmt.h)
    return Err(NoMediaStream)
  }
  Ok({ fmt: fmt.h, dec: vf_no_decoder(), adec: vf_no_audio_decoder() })
}

///|
/// 是否含视频流。
pub fn Demuxer::has_video(self : Demuxer) -> Bool {
  vf_video_stream(self.fmt) >= 0
}

///|
/// 是否含音频流。
pub fn Demuxer::has_audio(self : Demuxer) -> Bool {
  vf_audio_stream(self.fmt) >= 0
}

///|
/// 视频流原生宽（无视频流 0）。
pub fn Demuxer::stream_width(self : Demuxer) -> Int {
  vf_stream_width(self.fmt)
}

///|
/// 视频流原生高（无视频流 0）。
pub fn Demuxer::stream_height(self : Demuxer) -> Int {
  vf_stream_height(self.fmt)
}

///|
/// 时长秒（容器未知时 0）。
pub fn Demuxer::duration_s(self : Demuxer) -> Double {
  vf_duration_s(self.fmt)
}

///|
/// 打开视频解码器（RGBA 输出）。width/height 为输出帧目标尺寸
/// （0 = 源尺寸）。已开时幂等。
pub fn Demuxer::open_video_decoder(
  self : Demuxer,
  width? : Int = 0,
  height? : Int = 0,
) -> Result[Unit, VfError] {
  if vf_dec_width(self.dec) > 0 {
    return Ok(())
  }
  if !self.has_video() {
    return Err(DecodeFailed("无视频流"))
  }
  // FFI 裸指针立即装 struct 字段（同 open 的 GC 隔离约定）
  let dec : VfDecBox = { h: vf_open_video_decoder(self.fmt, width, height) }
  if vf_dec_width(dec.h) <= 0 {
    vf_close_decoder(dec.h)
    return Err(DecodeFailed("视频解码器初始化失败"))
  }
  self.dec = dec.h
  Ok(())
}

///|
/// 打开音频解码器（s16 交错 PCM 输出）。已开时幂等。
pub fn Demuxer::open_audio_decoder(self : Demuxer) -> Result[Unit, VfError] {
  if vf_adec_channels(self.adec) > 0 {
    return Ok(())
  }
  if !self.has_audio() {
    return Err(DecodeFailed("无音频流"))
  }
  let adec : VfADecBox = { h: vf_open_audio_decoder(self.fmt) }
  if vf_adec_channels(adec.h) <= 0 {
    vf_close_audio_decoder(adec.h)
    return Err(DecodeFailed("音频解码器初始化失败"))
  }
  self.adec = adec.h
  Ok(())
}

///|
/// 音频解码输出声道数（未开音频解码器 0）。
pub fn Demuxer::audio_channels(self : Demuxer) -> Int {
  vf_adec_channels(self.adec)
}

///|
/// 音频解码输出采样率（未开音频解码器 0）。
pub fn Demuxer::audio_rate(self : Demuxer) -> Int {
  vf_adec_rate(self.adec)
}

///|
/// 视频解码输出宽（未开视频解码器 0）。
pub fn Demuxer::out_width(self : Demuxer) -> Int {
  vf_dec_width(self.dec)
}

///|
/// 视频解码输出高（未开视频解码器 0）。
pub fn Demuxer::out_height(self : Demuxer) -> Int {
  vf_dec_height(self.dec)
}

///|
/// 解码下一帧为 RGBA 字节（恰好 out_w*out_h*4 长度；流结束/未开
/// 视频解码器给 None）。
pub fn Demuxer::decode_rgba(self : Demuxer) -> Bytes? {
  let w = vf_dec_width(self.dec)
  let h = vf_dec_height(self.dec)
  if w <= 0 || h <= 0 {
    return None
  }
  let len = w * h * 4
  let buf = FixedArray::make(len, b'\x00')
  let out = Bytes::from_array(buf)
  match vf_decode_next(self.dec, out, len) {
    1 => Some(out)
    _ => None
  }
}

///|
/// 解码下一段音频为 s16 交错 PCM（单帧音频 ~1024-1536 样本；流结束/
/// 未开音频解码器给 None）。每次内部分配精确长度字节。
pub fn Demuxer::decode_pcm(self : Demuxer) -> Bytes? {
  let ch = vf_adec_channels(self.adec)
  if ch <= 0 {
    return None
  }
  let cap = 65536
  let raw = FixedArray::make(cap, b'\x00')
  let out = Bytes::from_array(raw)
  let frames = vf_decode_pcm(self.adec, out, cap)
  if frames <= 0 {
    return None
  }
  let len = frames * ch * 2
  if len == cap {
    return Some(out)
  }
  let exact = FixedArray::make(len, b'\x00')
  exact.blit_from_bytes(0, out, 0, len)
  Some(Bytes::from_array(exact))
}

///|
/// 跳转到指定秒（已开的视频/音频解码器各自时间戳级 seek 并冲刷）。
pub fn Demuxer::seek(self : Demuxer, t_s : Double) -> Result[Unit, VfError] {
  let mut ok = true
  if vf_dec_width(self.dec) > 0 && vf_seek_s(self.dec, t_s) != 0 {
    ok = false
  }
  if vf_adec_channels(self.adec) > 0 && vf_aseek_s(self.adec, t_s) != 0 {
    ok = false
  }
  if ok {
    Ok(())
  } else {
    Err(DecodeFailed("seek 失败"))
  }
}

///|
/// 关闭解码器与容器（之后不可再用）。
pub fn Demuxer::close(self : Demuxer) -> Unit {
  vf_close_decoder(self.dec)
  vf_close_audio_decoder(self.adec)
  vf_close(self.fmt)
}

///|
extern "c" fn vf_version() -> Int = "vf_version"

///|
#borrow(path)
extern "c" fn vf_open(path : Bytes) -> VfFmt = "vf_open"

///|
#borrow(f)
extern "c" fn vf_ok(f : VfFmt) -> Int = "vf_ok"

///|
#borrow(f)
extern "c" fn vf_close(f : VfFmt) -> Unit = "vf_close"

///|
#borrow(f)
extern "c" fn vf_video_stream(f : VfFmt) -> Int = "vf_video_stream"

///|
#borrow(f)
extern "c" fn vf_audio_stream(f : VfFmt) -> Int = "vf_audio_stream"

///|
extern "c" fn vf_no_decoder() -> VfDec = "vf_no_decoder"

///|
extern "c" fn vf_no_audio_decoder() -> VfADec = "vf_no_audio_decoder"

///|
#borrow(f)
extern "c" fn vf_stream_width(f : VfFmt) -> Int = "vf_stream_width"

///|
#borrow(f)
extern "c" fn vf_stream_height(f : VfFmt) -> Int = "vf_stream_height"

///|
#borrow(f)
extern "c" fn vf_duration_s(f : VfFmt) -> Double = "vf_duration_s"

///|
#borrow(f)
extern "c" fn vf_open_video_decoder(f : VfFmt, out_w : Int, out_h : Int) -> VfDec = "vf_open_video_decoder"

///|
#borrow(d)
extern "c" fn vf_close_decoder(d : VfDec) -> Unit = "vf_close_decoder"

///|
#borrow(d)
extern "c" fn vf_dec_width(d : VfDec) -> Int = "vf_dec_width"

///|
#borrow(d)
extern "c" fn vf_dec_height(d : VfDec) -> Int = "vf_dec_height"

///|
#borrow(d, out)
extern "c" fn vf_decode_next(d : VfDec, out : Bytes, out_len : Int) -> Int = "vf_decode_next"

///|
#borrow(d)
extern "c" fn vf_seek_s(d : VfDec, t_s : Double) -> Int = "vf_seek_s"

///|
#borrow(f)
extern "c" fn vf_open_audio_decoder(f : VfFmt) -> VfADec = "vf_open_audio_decoder"

///|
#borrow(d)
extern "c" fn vf_close_audio_decoder(d : VfADec) -> Unit = "vf_close_audio_decoder"

///|
#borrow(d)
extern "c" fn vf_adec_channels(d : VfADec) -> Int = "vf_adec_channels"

///|
#borrow(d)
extern "c" fn vf_adec_rate(d : VfADec) -> Int = "vf_adec_rate"

///|
#borrow(d, out)
extern "c" fn vf_decode_pcm(d : VfADec, out : Bytes, out_len : Int) -> Int = "vf_decode_pcm"

///|
#borrow(d)
extern "c" fn vf_aseek_s(d : VfADec, t_s : Double) -> Int = "vf_aseek_s"

///|
#external
pub type VfFmt

///|
#external
pub type VfDec

///|
#external
pub type VfADec
