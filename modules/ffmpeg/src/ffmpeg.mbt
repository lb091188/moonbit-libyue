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
  NoVideoStream
  DecodeFailed(String)
}

///|
pub impl Show for VfError with fn output(self, logger) {
  match self {
    OpenFailed(msg) => {
      logger.write_string("打开失败：")
      logger.write_string(msg)
    }
    NoVideoStream => logger.write_string("未找到视频流")
    DecodeFailed(msg) => {
      logger.write_string("解码失败：")
      logger.write_string(msg)
    }
  }
}

///|
pub extend VfError with Show::{to_string, output}

///|
/// 解码器：容器 + 视频流解码上下文（RGBA 输出）。
pub(all) struct Demuxer {
  fmt : VfFmt
  dec : VfDec
  width : Int
  height : Int
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
/// 打开视频文件（AVI/MP4/MKV/WebM…随 ffmpeg 解码器覆盖）；
/// width/height 为输出帧目标尺寸（0 = 源尺寸）。
pub fn Demuxer::open(
  path : String,
  width? : Int = 0,
  height? : Int = 0,
) -> Result[Demuxer, VfError] {
  // FFI 返回的裸指针不能裸绑定（MoonBit GC 会把裸 extern 值当 GC 对象
  // drop 导致 mi_free 段错误），必须立即装进 struct 字段（extern 类型
  // 字段不归 GC 管理，同 miniaudio 封装的持有模式）
  let fmt : VfFmtBox = { h: vf_open(@utf8.encode(path)) }
  if vf_ok(fmt.h) != 1 {
    vf_close(fmt.h)
    return Err(OpenFailed(path))
  }
  if vf_video_stream(fmt.h) < 0 {
    vf_close(fmt.h)
    return Err(NoVideoStream)
  }
  let dec : VfDecBox = { h: vf_open_video_decoder(fmt.h, width, height) }
  if vf_dec_width(dec.h) <= 0 {
    vf_close_decoder(dec.h)
    vf_close(fmt.h)
    return Err(OpenFailed("解码器初始化失败"))
  }
  Ok({ fmt: fmt.h, dec: dec.h, width: vf_dec_width(dec.h), height: vf_dec_height(dec.h), })
}

///|
/// 视频流原生宽。
pub fn Demuxer::stream_width(self : Demuxer) -> Int {
  vf_stream_width(self.fmt)
}

///|
/// 视频流原生高。
pub fn Demuxer::stream_height(self : Demuxer) -> Int {
  vf_stream_height(self.fmt)
}

///|
/// 时长秒（容器未知时 0）。
pub fn Demuxer::duration_s(self : Demuxer) -> Double {
  vf_duration_s(self.fmt)
}

///|
/// 解码下一帧为 RGBA 字节（恰好 w*h*4 长度；流结束给 None）。
pub fn Demuxer::decode_rgba(self : Demuxer) -> Bytes? {
  let len = self.width * self.height * 4
  let buf = FixedArray::make(len, b'\x00')
  let out = Bytes::from_array(buf)
  match vf_decode_next(self.dec, out, len) {
    1 => Some(out)
    _ => None
  }
}

///|
/// 跳转到指定秒。
pub fn Demuxer::seek(self : Demuxer, t_s : Double) -> Result[Unit, VfError] {
  if vf_seek_s(self.dec, t_s) == 0 {
    Ok(())
  } else {
    Err(DecodeFailed("seek 失败"))
  }
}

///|
/// 关闭解码器与容器（之后不可再用）。
pub fn Demuxer::close(self : Demuxer) -> Unit {
  vf_close_decoder(self.dec)
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
#external
pub type VfFmt

///|
#external
pub type VfDec
