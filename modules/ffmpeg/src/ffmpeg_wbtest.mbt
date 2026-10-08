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
    println("ffmpeg 音频解码冒烟 \{path}：\{chunks} 段共 \{frames} 帧")
  }
}

///|
/// 视频解码冒烟：testdata 内置 1 秒 96x64 lavfi 测试视频（testsrc，
/// 无外部素材依赖），打开 → 显式开视频解码器 → 逐帧 RGBA → seek。
test "ffmpeg FFI 视频解码：RGBA 逐帧 + seek" {
  let d = match Demuxer::open("src/testdata/testsrc_1s.avi") {
    Ok(d) => d
    Err(e) => fail("testsrc_1s.avi 打开失败：\{e}")
  }
  inspect(d.has_video(), content="true")
  match d.open_video_decoder() {
    Ok(_) => ()
    Err(e) => fail("开视频解码器失败：\{e}")
  }
  let w = d.out_width()
  let h = d.out_height()
  inspect(w > 0, content="true")
  inspect(h > 0, content="true")
  let fb = w * h * 4
  let mut frames = 0
  while true {
    match d.decode_rgba() {
      Some(b) => {
        inspect(b.length(), content="\{fb}")
        frames = frames + 1
        if frames > 100 {
          fail("解码未收敛（EOF 未达）")
        }
      }
      None => break
    }
  }
  inspect(frames > 0, content="true")
  match d.seek(0.1) {
    Ok(_) =>
      match d.decode_rgba() {
        Some(_) => ()
        None => fail("seek 后应能解出帧")
      }
    Err(e) => fail("seek 失败：\{e}")
  }
  d.close()
  println("ffmpeg 视频解码冒烟：\{w}x\{h} 共 \{frames} 帧 + seek 验证")
}
