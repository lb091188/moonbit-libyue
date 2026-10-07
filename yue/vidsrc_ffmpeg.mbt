// ffmpeg CLI 视频源：ffprobe 解析元信息（CSV 输出），ffmpeg 解码为
// 单个 raw RGBA 文件（rawvideo muxer 顺序写帧），帧源按帧号偏移切片
// 喂 video_view_t。AVI/MP4/MKV/WebM 等容器随 ffmpeg 解码器覆盖；音轨
// 另路提取 WAV 交 AudioEngine 播放（音画各自从 0 起播的近似同步）。
// 帧数据整读进内存，分辨率/帧数/时长经参数钳制，详见
// system-capabilities.md「视频播放（ffmpeg 路线）」。

///|
/// ffmpeg/ffprobe 是否可用（进程内缓存，首次真实探测 `ffmpeg -version`）。
pub fn vidf_supported() -> Bool {
  let cached = vidf_supported_cache.val
  if cached >= 0 {
    return cached == 1
  }
  let ok = match pr_run("ffmpeg", ["-version"]) {
    Ok(out) => out.exit_code == 0 && out.stdout.contains("ffmpeg version")
    Err(_) => false
  }
  vidf_supported_cache.val = if ok { 1 } else { 0 }
  ok
}

let vidf_supported_cache : Ref[Int] = Ref(-1)

///|
/// 视频元信息：帧尺寸、帧率（fps）、时长秒（ffprobe 拿不到时 0）。
pub(all) struct VideoMeta {
  width : Int
  height : Int
  fps : Double
  duration_s : Double
  has_audio : Bool
}

///|
/// 去行首尾空白（空格/\r）。
fn vidf_trim(s : StringView) -> StringView {
  let mut a = 0
  let mut b = s.length()
  while a < b && (s[a] == 32 || s[a] == 13) {
    a = a + 1
  }
  while b > a && (s[b - 1] == 32 || s[b - 1] == 13) {
    b = b - 1
  }
  s[a:b]
}

///|
/// 按逗号切分（ffprobe CSV 单行；不处理引号转义——探测输出字段无逗号）。
fn vidf_split_commas(line : StringView) -> Array[StringView] {
  let out : Array[StringView] = []
  let v = line[0:]
  let mut start = 0
  let mut i = 0
  for ch in v {
    if ch == ',' {
      out.push(v[start:i])
      start = i + 1
    }
    i = i + 1
  }
  out.push(v[start:])
  out
}

///|
/// 十进制无符号解析（ASCII 数字串；空/含非数字给 None）。
fn vidf_parse_u64(s : StringView) -> UInt64? {
  if s == "" {
    return None
  }
  let mut v : UInt64 = 0UL
  for ch in s {
    let d = ch.to_int() - 48
    if d < 0 || d > 9 {
      return None
    }
    v = v * 10UL + d.to_uint64()
  }
  Some(v)
}

///|
/// 解析 r_frame_rate 分数（"5/1"、"30000/1001"；分母 0/空给 0）。
fn vidf_parse_rate(s : StringView) -> Double {
  match s.split("/").to_array() {
    [num, den] =>
      match (vidf_parse_u64(num), vidf_parse_u64(den)) {
        (Some(n), Some(d)) => if d == 0 {
          0.0
        } else {
          n.to_double() / d.to_double()
        }
        _ => 0.0
      }
    [num] =>
      match vidf_parse_u64(num) {
        Some(n) => n.to_double()
        None => 0.0
      }
    _ => 0.0
  }
}

///|
/// ffprobe CSV 行解析（每流一行 `video,宽,高,率/分母`；format 行纯
/// 数字=时长秒；`audio,` 前缀=音频流存在）。
fn vidf_parse_probe(output : String) -> VideoMeta {
  let mut width = 0
  let mut height = 0
  let mut fps = 0.0
  let mut duration = 0.0
  let mut has_audio = false
  for line in output.split("\n") {
    let line = vidf_trim(line)
    if line == "" {
      continue
    }
    if line.has_prefix("video,") {
      let f = vidf_split_commas(line)
      if f.length() >= 3 {
        width = match vidf_parse_u64(f[1]) {
          Some(n) => n.to_int()
          None => 0
        }
        height = match vidf_parse_u64(f[2]) {
          Some(n) => n.to_int()
          None => 0
        }
        if f.length() >= 4 {
          fps = vidf_parse_rate(f[3])
        }
      }
    } else if line.has_prefix("audio,") {
      has_audio = true
    } else {
      // format duration 行：纯数字与小数点组成
      let mut numeric = line != ""
      for ch in line {
        let d = ch.to_int() - 48
        if d != 0 && (d < 0 || d > 9) && ch != '.' {
          numeric = false
        }
      }
      if numeric {
        duration = parse_duration(line)
      }
    }
  }
  { width, height, fps, duration_s: duration, has_audio, }
}

///|
/// 解析小数十进制（"2.000000"→2.0；非法给 0）。整数部分 + 小数部分。
fn parse_duration(s : StringView) -> Double {
  let parts = s.split(".").to_array()
  let int_part = match parts[0] {
    "" => 0.0
    txt =>
      match vidf_parse_u64(txt) {
        Some(n) => n.to_double()
        None => return 0.0
      }
  }
  if parts.length() == 1 {
    return int_part
  }
  let frac = parts[1]
  let mut frac_val = 0.0
  let mut scale = 0.1
  for i, ch in frac.iter2() {
    let _ = i
    let d = ch.to_int() - 48
    if d < 0 || d > 9 {
      return int_part
    }
    frac_val = frac_val + d.to_double() * scale
    scale = scale * 0.1
  }
  int_part + frac_val
}

///|
/// 视频帧集：解码后的连续 RGBA 帧（帧 i 起于 i*帧字节数）。
pub(all) struct VideoFrames {
  data : Bytes
  width : Int
  height : Int
  frame_count : Int
}

///|
/// 帧字节长度。
pub fn VideoFrames::frame_bytes(self : VideoFrames) -> Int {
  vid_rgba_len(self.width, self.height)
}

///|
/// 按帧号取该帧 RGBA 字节（越界给 None）。
pub fn VideoFrames::frame(self : VideoFrames, idx : Int) -> Bytes? {
  let fb = self.frame_bytes()
  if idx < 0 || idx >= self.frame_count {
    return None
  }
  Some(self.data[idx * fb : (idx + 1) * fb].to_fixedarray() |> Bytes::from_array)
}

///|
/// VideoFrames → video_view_t 的帧源。
pub fn vidf_source(frames : VideoFrames) -> VideoFrameSource {
  fn(i) { frames.frame(i) }
}

///|
/// 用 ffprobe 读视频元信息（不存在的文件 / 无视频流给 Err）。
pub fn vidf_probe(path : String) -> Result[VideoMeta, String] {
  let out = match pr_run(
    "ffprobe",
    [
      "-v", "error",
      "-show_entries", "stream=codec_type,width,height,r_frame_rate",
      "-show_entries", "format=duration",
      "-of", "csv=p=0",
      path,
    ],
    timeout_ms=15000,
  ) {
    Ok(o) => o
    Err(e) => return Err("ffprobe 执行失败：\{e}")
  }
  if out.exit_code != 0 {
    return Err("ffprobe 退出码 \{out.exit_code}")
  }
  let meta = vidf_parse_probe(out.stdout)
  if meta.width <= 0 || meta.height <= 0 {
    return Err("未读到视频流")
  }
  Ok(meta)
}

///|
/// 提取帧集：ffprobe 得元信息 → ffmpeg 解码为 raw RGBA 单文件 → 整读
/// 进内存。fps（缺 8）、width/height（缺按源尺寸）、max_frames（缺 240）
/// 钳制内存占用（默认上限约 240 帧 × 帧字节数）。路径含特殊字符时引号
/// 由 ffmpeg 自行解析，不安全输入由调用方把关。
pub fn vidf_extract(
  path : String,
  fps? : Double = 8.0,
  width? : Int = 0,
  height? : Int = 0,
  max_frames? : Int = 240,
) -> Result[VideoFrames, String] {
  let meta = match vidf_probe(path) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let w = if width > 0 {
    width
  } else {
    meta.width
  }
  let h = if height > 0 {
    height
  } else {
    meta.height
  }
  if w <= 0 || h <= 0 {
    return Err("无效的目标分辨率 \{w}x\{h}")
  }
  if fps <= 0.0 {
    return Err("fps 必须为正")
  }
  let out_path = "\{vidf_tmp_dir()}/yue-vidf-\{@subproc.get_pid()}.raw"
  let fps_str = fmt_axis(fps)
  let vf = "fps=\{fps_str},scale=\{w}:\{h}"
  let out = match pr_run(
    "ffmpeg",
    [
      "-v", "error",
      "-y",
      "-i", path,
      "-vf", vf,
      "-pix_fmt", "rgba",
      "-frames:v", max_frames.to_string(),
      "-f", "rawvideo",
      out_path,
    ],
    timeout_ms=120000,
  ) {
    Ok(o) => o
    Err(e) => return Err("ffmpeg 执行失败：\{e}")
  }
  if out.exit_code != 0 {
    return Err("ffmpeg 退出码 \{out.exit_code}（详见 ffmpeg 输出）")
  }
  let data = match read_binary_file(out_path) {
    Some(b) => b
    None => return Err("解码输出读取失败")
  }
  let fb = w * h * 4
  let count = if fb <= 0 {
    0
  } else {
    data.length() / fb
  }
  if count == 0 {
    return Err("解码出 0 帧（文件损坏或编码不支持）")
  }
  Ok({ data, width: w, height: h, frame_count: count, })
}

///|
/// 提取音轨为 WAV（16bit 44.1kHz 立体声重采样；无音轨时 ffmpeg 退出
/// 非零，Err 带输出）。产物交 AudioEngine::load 播放。
pub fn vidf_extract_audio(path : String, out_wav : String) -> Result[Unit, String] {
  let out = match pr_run(
    "ffmpeg",
    ["-v", "error", "-y", "-i", path, "-vn", "-acodec", "pcm_s16le", "-ar", "44100", "-ac", "2", out_wav],
    timeout_ms=120000,
  ) {
    Ok(o) => o
    Err(e) => return Err("ffmpeg 执行失败：\{e}")
  }
  if out.exit_code != 0 {
    return Err("ffmpeg 退出码 \{out.exit_code}（详见 ffmpeg 输出）")
  }
  Ok(())
}

///|
/// 临时目录（与 procrun 同源：TMPDIR → /tmp）。
fn vidf_tmp_dir() -> String {
  match @env.get_env_var("TMPDIR") {
    Some(d) => if d == "" { "/tmp" } else { d }
    None => "/tmp"
  }
}
