// 音频播放（miniaudio 后端：可解码 WAV / MP3 / FLAC,即 miniaudio 内置
// 解码器集合;OGG 需外部 stb_vorbis、m4a/aac 等无内置解码,均不支持）。封装层级：引擎 → 剪辑（load → play/pause/stop/volume）→ 释放；
// 失败统一 Result + AudioError，不崩进程。详见 system-capabilities.md。

///|
/// 音量钳制（有效区间 [0,1]；miniaudio 自身允许放大，这里按常见音量
/// 语义钳住，NaN 按 0 处理）。
pub fn audio_clamp_volume(v : Double) -> Double {
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
/// 音频错误：Unsupported=当前平台不可用；DeviceFailed=无输出设备或
/// 设备初始化失败；LoadFailed=文件解码/加载失败。
pub(all) enum AudioError {
  Unsupported
  DeviceFailed(String)
  LoadFailed(String)
}

///|
pub impl Show for AudioError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("本平台不支持")
    DeviceFailed(msg) => {
      logger.write_string("音频设备不可用：")
      logger.write_string(msg)
    }
    LoadFailed(msg) => {
      logger.write_string("音频加载失败：")
      logger.write_string(msg)
    }
  }
}

///|
pub extend AudioError with Show::{to_string, output}

///|
/// 音频引擎（miniaudio 引擎包装）：进程内可多个，各自持设备上下文；
/// 释放前应释放其加载的剪辑。引擎句柄可 move，语义上对应底层设备的
/// 一个会话；本机无输出设备（服务容器 / 纯 SSH 环境）时 DeviceFailed。
pub(all) struct AudioEngine {
  engine : @miniaudio.MaEngine
}

///|
/// 创建音频引擎（无输出设备或初始化失败 → Err(DeviceFailed)）。
pub fn AudioEngine::new() -> Result[AudioEngine, AudioError] {
  match @miniaudio.MaEngine::new() {
    Ok(e) => Ok({ engine: e, })
    Err(msg) => Err(DeviceFailed(msg))
  }
}

///|
/// 从文件加载音频剪辑。decoded 默认 false（流式加载，适合音乐/长
/// 音频）；true 时全解码进内存（短音效低延迟）。loop 控制循环播放。
pub fn AudioEngine::load(
  self : AudioEngine,
  path : String,
  looping? : Bool = false,
  decoded? : Bool = false,
) -> Result[AudioClip, AudioError] {
  let mut flags = if decoded {
    @miniaudio.MA_SOUND_FLAG_DECODE | @miniaudio.MA_SOUND_FLAG_STREAM
  } else {
    @miniaudio.MA_SOUND_FLAG_STREAM
  }
  if looping {
    flags = flags | @miniaudio.MA_SOUND_FLAG_LOOPING
  }
  match self.engine.load_sound(path, flags) {
    Ok(s) => Ok({ sound: s, })
    Err(msg) => Err(LoadFailed(msg))
  }
}

///|
/// 释放引擎（释放后其剪辑句柄不再可用）。
pub fn AudioEngine::free(self : AudioEngine) -> Unit {
  self.engine.free()
}

///|
/// 音频剪辑：一次 load 对应一个可播放实例；播放 / 停止互斥，重复
/// play 单调（播放中再 play 无副作用），停止后可再 play。
pub(all) struct AudioClip {
  sound : @miniaudio.MaSound
}

///|
/// 开始播放（剪辑 load 后未播放状态）。
pub fn AudioClip::play(self : AudioClip) -> Unit {
  self.sound.play()
}

///|
/// 停止播放（回到起点，可再次 play）。
pub fn AudioClip::stop(self : AudioClip) -> Unit {
  self.sound.stop()
}

///|
/// 是否在播放中。
pub fn AudioClip::is_playing(self : AudioClip) -> Bool {
  self.sound.playing()
}

///|
/// 设置音量（钳制到 [0,1]）。
pub fn AudioClip::set_volume(self : AudioClip, v : Double) -> Unit {
  self.sound.set_volume(Float::from_double(audio_clamp_volume(v)))
}

///|
/// 读取当前音量。
pub fn AudioClip::get_volume(self : AudioClip) -> Double {
  self.sound.get_volume().to_double()
}

///|
/// 释放剪辑。
pub fn AudioClip::free(self : AudioClip) -> Unit {
  self.sound.free()
}
