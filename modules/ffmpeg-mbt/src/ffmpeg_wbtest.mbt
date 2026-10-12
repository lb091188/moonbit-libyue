///|
/// 不存在的文件给 OpenFailed（自包含，无外部依赖）。
test "ffmpeg FFI 错误路径" {
  match Demuxer::open("/nonexistent/no.avi") {
    Err(OpenFailed(_)) => ()
    Err(_) => fail("应是 OpenFailed")
    Ok(d) => {
      d.close()
      fail("不应打开成功")
    }
  }
}

///|
/// 版本探测（动态链在加载期已保证库可达，此为防御性断言）。
test "ffmpeg FFI version" {
  inspect(ffmpeg_version() > 0, content="true")
  inspect(ffmpeg_supported(), content="true")
}

///|
/// 音频解码冒烟：testdata 内置 1 秒正弦（mp3/ogg/m4a/wav 四种容器
/// 与编码组合），打开 → 显式开音频解码器 → 累计 PCM 帧数 ≈ 1 秒 →
/// seek 后可继续解码。纯音频文件不再因无视频流被拒。
test "ffmpeg FFI 音频解码：四格式 PCM 直出" {
  let cases = [
    ("src/testdata/sine_1s.mp3", 44100),
    ("src/testdata/sine_1s.ogg", 44100),
    ("src/testdata/sine_1s.m4a", 44100),
    ("src/testdata/sine_1s.wav", 44100),
  ]
  for case in cases {
    let (path, rate) = case
    let d = match Demuxer::open(path) {
      Ok(d) => d
      Err(e) => fail("\{path} 打开失败：\{e}")
    }
    inspect(d.has_audio(), content="true")
    match d.open_audio_decoder() {
      Ok(_) => ()
      Err(e) => fail("\{path} 开音频解码器失败：\{e}")
    }
    inspect(d.audio_channels() >= 1, content="true")
    inspect(d.audio_rate(), content="\{rate}")
    // 累计解码到流结束；1 秒正弦应有 ≈ rate 帧（±0.1s 容差）
    let mut frames = 0
    let mut chunks = 0
    while true {
      match d.decode_pcm() {
        Some(pcm) => {
          frames = frames + pcm.length() / (d.audio_channels() * 2)
          chunks = chunks + 1
          if chunks > 4096 {
            fail("\{path} 解码未收敛（EOF 未达）")
          }
        }
        None => break
      }
    }
    if frames < rate * 9 / 10 || frames > rate * 11 / 10 {
      fail("\{path} 解码帧数异常：\{frames}（期望 ≈\{rate}）")
    }
    // seek 后应能继续解出 PCM
    match d.seek(0.0) {
      Ok(_) =>
        match d.decode_pcm() {
          Some(_) => ()
          None => fail("\{path} seek 后应能解出 PCM")
        }
      Err(e) => fail("\{path} seek 失败：\{e}")
    }
    d.close()
    println(
      "ffmpeg 音频解码冒烟 \{path}：\{chunks} 段共 \{frames} 帧",
    )
  }
}

///|
/// 视频解码冒烟：testdata 内置 1 秒 96x64 lavfi 测试视频（testsrc，
/// 无外部素材依赖），打开 → 显式开视频解码器 → 逐帧 RGBA → seek。
/// 帧时间戳（pts）与流帧率随帧校验：pts 非负单调、末帧贴近容器
/// 时长（与 duration 同轴的证据）、seek 后重置。
test "ffmpeg FFI 视频解码：RGBA 逐帧 + pts/帧率 + seek" {
  let d = match Demuxer::open("src/testdata/testsrc_1s.avi") {
    Ok(d) => d
    Err(e) => fail("testsrc_1s.avi 打开失败：\{e}")
  }
  inspect(d.has_video(), content="true")
  match d.open_video_decoder() {
    Ok(_) => ()
    Err(e) => fail("开视频解码器失败：\{e}")
  }
  // 流帧率：素材为 12fps
  let fps = d.video_fps()
  if fps < 11.0 || fps > 13.0 {
    fail("流帧率异常：\{fps}（期望 ≈12）")
  }
  let w = d.out_width()
  let h = d.out_height()
  inspect(w > 0, content="true")
  inspect(h > 0, content="true")
  let fb = w * h * 4
  let mut frames = 0
  let mut last_pts = -1.0
  let mut pts_monotonic = true
  while true {
    match d.decode_rgba() {
      Some(b) => {
        inspect(b.length(), content="\{fb}")
        frames = frames + 1
        let pts = d.last_frame_pts()
        if pts < 0.0 || (last_pts >= 0.0 && pts <= last_pts) {
          pts_monotonic = false
        }
        last_pts = pts
        if frames > 100 {
          fail("解码未收敛（EOF 未达）")
        }
      }
      None => break
    }
  }
  inspect(frames > 0, content="true")
  inspect(pts_monotonic, content="true")
  // 末帧 pts 贴近容器时长（1 秒素材末帧 11/12 ≈ 0.917）
  if last_pts < 0.8 || last_pts > 1.0 {
    fail("末帧 pts 异常：\{last_pts}（期望 ≈0.92）")
  }
  match d.seek(0.1) {
    Ok(_) => {
      // seek 后旧 pts 重置，不再指向 seek 前位置
      if d.last_frame_pts() != -1.0 {
        fail("seek 后 last_frame_pts 应重置为 -1")
      }
      match d.decode_rgba() {
        Some(_) => ()
        None => fail("seek 后应能解出帧")
      }
    }
    Err(e) => fail("seek 失败：\{e}")
  }
  d.close()
  println(
    "ffmpeg 视频解码冒烟 \{w}x\{h} 共 \{frames} 帧（fps=\{fps}，末帧 pts=\{last_pts}）",
  )
}

///|
/// ASS 对话行前缀剥离的判据：只在「前八字段是数字/空」时剥，正文里的逗号不动。
test "字幕文本归一化：剥 ASS 整行前缀，普通逗号不误伤" {
  assert_eq(
    subtitle_ass_text("0,0,Default,,0,0,0,,第一条字幕"),
    "第一条字幕",
  )
  assert_eq(subtitle_ass_text("你好, 世界"), "你好, 世界")
  assert_eq(subtitle_ass_text("正文里,有,很多,逗号,但前缀不是数字"), "正文里,有,很多,逗号,但前缀不是数字")
  assert_eq(subtitle_ass_text(""), "")
  // 字段数不足八段的一律原样（宁可不剥，也不把正文切一半）
  assert_eq(subtitle_ass_text("0,0,Default,,0,0,0,短行"), "0,0,Default,,0,0,0,短行")
}

///|
/// 内嵌字幕轨：`av_1s_subs.mp4` 是 h264 + aac + mov_text 三流，两条字幕分别落在
/// 0.2s 与 0.6s。四条判据：① 容器报有字幕流；② 整条读出的条数/时间戳/中文文本
/// 对得上（mov_text 解码器只给 ASS 整行，前缀必须已被剥掉）；③ 读字幕**不搅动**
/// 同一路径上视频解码器的读位置（另开一份容器这条设计的全部理由）；
/// ④ 「没有这条轨」与「文件打不开」分开报。
test "ffmpeg FFI 内嵌字幕：整条读出、剥前缀、不搅动主时间轴" {
  let path = "src/testdata/av_1s_subs.mp4"
  let dm = match Demuxer::open(path) {
    Ok(d) => d
    Err(e) => fail("打开失败：\{e}")
  }
  assert_eq(dm.has_subtitle(), true)
  assert_eq(dm.open_video_decoder(width=96, height=64) is Ok(_), true)
  let f1 = dm.decode_rgba()
  assert_eq(f1 is Some(_), true)
  let p1 = dm.last_frame_pts()
  dm.close()
  // ④ 先读字幕：另开容器，不该动上面那份的读位置
  let cues = match subtitle_cues(path) {
    Err(e) => fail("字幕读取失败：\{e}")
    Ok(c) => c
  }
  assert_eq(cues.length(), 2)
  assert_true(cues[0].start_s > 0.15 && cues[0].start_s < 0.25)
  assert_eq(cues[0].text, "第一条字幕")
  assert_true(cues[0].end_s > cues[0].start_s)
  assert_true(cues[1].start_s > 0.55 && cues[1].start_s < 0.65)
  assert_eq(cues[1].text, "第二条带标记")
  // ③ 再开一份继续解：第一帧之后仍能解出更晚的帧（读位置没被字幕 drain 掉）
  let dm2 = match Demuxer::open(path) {
    Ok(d) => d
    Err(e) => fail("二次打开失败：\{e}")
  }
  assert_eq(dm2.open_video_decoder(width=96, height=64) is Ok(_), true)
  let mut seen = 0
  let mut last_pts = p1
  while seen < 3 {
    seen = seen + 1
    match dm2.decode_rgba() {
      Some(_) => last_pts = dm2.last_frame_pts()
      None => break
    }
  }
  assert_true(seen >= 2)
  assert_true(last_pts > p1)
  dm2.close()
  // ④ 没有字幕流的文件：Ok([])；打不开的文件：Err(OpenFailed)
  match subtitle_cues("src/testdata/sine_1s.m4a") {
    Ok(c) => assert_eq(c.length(), 0)
    Err(e) => fail("无字幕流应是 Ok([])，实际 \{e}")
  }
  match subtitle_cues("/nonexistent/no.mp4") {
    Err(OpenFailed(_)) => ()
    Err(e) => fail("应是 OpenFailed，实际 \{e}")
    Ok(c) => fail("不存在的文件不该成功，实际 \{c.length()} 条")
  }
}
