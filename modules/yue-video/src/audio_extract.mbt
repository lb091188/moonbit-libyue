// 音轨提取（ffmpeg CLI 单命令；视频解码走本包 FFI，音频 PCM 直出绑定
// 留后续）。产物 WAV 交 AudioEngine 播放。

///|
/// ffmpeg CLI 是否可用（进程内缓存，首次真探 `ffmpeg -version`）。
pub fn audiof_supported() -> Bool {
  let cached = audiof_cache.val
  if cached >= 0 {
    return cached == 1
  }
  let ok = match @yue.pr_run("ffmpeg", ["-version"]) {
    Ok(out) => out.exit_code == 0 && out.stdout.contains("ffmpeg version")
    Err(_) => false
  }
  audiof_cache.val = if ok { 1 } else { 0 }
  ok
}

let audiof_cache : Ref[Int] = Ref(-1)

///|
/// 提取视频文件的音轨为 WAV（16bit 44.1kHz 立体声重采样）。无音轨 /
/// 编码不支持 / CLI 不可用时 Err。
pub fn audiof_extract_wav(path : String, out_wav : String) -> Result[Unit, String] {
  let out = match @yue.pr_run(
    "ffmpeg",
    [
      "-v", "error", "-y", "-i", path, "-vn", "-acodec", "pcm_s16le", "-ar",
      "44100", "-ac", "2", out_wav,
    ],
    timeout_ms=120000,
  ) {
    Ok(o) => o
    Err(e) => return Err("ffmpeg 执行失败：\{e}")
  }
  if out.exit_code != 0 {
    return Err("ffmpeg 退出码 \{out.exit_code}（详见输出）")
  }
  Ok(())
}
