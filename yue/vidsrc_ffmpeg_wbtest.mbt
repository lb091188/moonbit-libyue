///|
/// 帧率分数解析（ffmpeg 的 r_frame_rate 形态）。
test "vidf_parse_rate：分数形态" {
  inspect(vidf_parse_rate("5/1"), content="5")
  inspect(vidf_parse_rate("30000/1001"), content="29.97002997002997")
  inspect(vidf_parse_rate("0/0"), content="0")
  inspect(vidf_parse_rate("24"), content="24")
  inspect(vidf_parse_rate("abc"), content="0")
}

///|
/// ffprobe CSV 输出解析（真实输出形态：视频流行 / 时长行 / 音频行）。
test "vidf_parse_probe：CSV 行解析" {
  let m = vidf_parse_probe(
    "video,160,120,5/1\n2.000000\naudio,44100,2\n",
  )
  inspect(m.width, content="160")
  inspect(m.height, content="120")
  inspect(m.fps, content="5")
  inspect(m.duration_s > 1.9 && m.duration_s < 2.1, content="true")
  inspect(m.has_audio, content="true")
  // 无音频无时长的最小输出
  let m2 = vidf_parse_probe("video,1920,1080,30000/1001\n")
  inspect(m2.width, content="1920")
  inspect(m2.has_audio, content="false")
  inspect(m2.duration_s, content="0")
}

///|
/// VideoFrames 帧切片：帧号偏移与越界。
test "VideoFrames：frame 偏移与越界" {
  // 2 帧 × 2x2(RGBA=16 字节) = 32 字节，内容按帧号区分
  let data = FixedArray::make(32, b'\x00')
  for i = 0; i < 16; i = i + 1 {
    data[i] = b'\x11'
  }
  for i = 16; i < 32; i = i + 1 {
    data[i] = b'\x22'
  }
  let frames : VideoFrames = {
    data: Bytes::from_array(data),
    width: 2,
    height: 2,
    frame_count: 2,
  }
  match frames.frame(0) {
    Some(b) => inspect(b[0].to_int() == 0x11 && b.length() == 16, content="true")
    None => fail("帧 0 应存在")
  }
  match frames.frame(1) {
    Some(b) => inspect(b[0].to_int() == 0x22, content="true")
    None => fail("帧 1 应存在")
  }
  match frames.frame(2) {
    None => ()
    Some(_) => fail("越界应 None")
  }
}

///|
/// 真机全链路冒烟（ffmpeg 缺失时跳过）：lavfi 生成测试视频 → probe →
/// 提取帧集 → 帧源切片。
test "vidf 真机冒烟：生成/probe/提取/切片" {
  if !vidf_supported() {
    println("vidf: ffmpeg 不可用，跳过")
    return
  }
  let avi = "/tmp/yue-vidf-test-\{@subproc.get_pid()}.avi"
  match pr_run(
    "ffmpeg",
    ["-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=duration=2:size=160x120:rate=5", "-pix_fmt", "yuv420p", avi],
    timeout_ms=30000,
  ) {
    Ok(o) => if o.exit_code != 0 {
      println("vidf: 测试视频生成失败，跳过")
      return
    }
    Err(e) => {
      println("vidf: spawn 失败（\{e}），跳过")
      return
    }
  }
  // probe：尺寸与帧率
  match vidf_probe(avi) {
    Err(e) => fail("probe 失败：\{e}")
    Ok(m) => {
      inspect(m.width, content="160")
      inspect(m.height, content="120")
      inspect(m.fps > 4.9 && m.fps < 5.1, content="true")
    }
  }
  // 提取：源 2 秒 5fps → 目标 4fps ≈ 8 帧
  match vidf_extract(avi, fps=4.0, width=160, height=120) {
    Err(e) => fail("提取失败：\{e}")
    Ok(frames) => {
      inspect(frames.frame_count >= 7, content="true")
      inspect(frames.frame_bytes(), content="76800")
      // 帧源切片首帧非空
      let src = vidf_source(frames)
      match src(0) {
        Some(b) => inspect(b.length(), content="76800")
        None => fail("帧源 0 应非空")
      }
      match src(frames.frame_count) {
        None => ()
        Some(_) => fail("帧源越界应 None")
      }
    }
  }
}
