///|
/// AudioPlayer 冒烟：内置 1 秒正弦 mp3 打开 → 播放 → pump 推进 →
/// seek → 暂停/停止 → 循环重播 → 释放。无输出设备环境（CI）自动走
/// 静音降级分支，状态机照常验证。
test "AudioPlayer 冒烟：播放/pump/seek/循环" {
  let p = match AudioPlayer::make("../ffmpeg-mbt/src/testdata/sine_1s.mp3") {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  inspect(p.channel_count(), content="1")
  inspect(p.sample_rate(), content="44100")
  inspect(p.duration() > 0.9 && p.duration() < 1.1, content="true")
  inspect(p.is_playing(), content="false")
  // 播放 + 推进（真设备吃队列、哑设备按 tick 近似，两分支都应推进）
  p.play()
  inspect(p.is_playing(), content="true")
  let mut ticks = 0
  while p.is_playing() && ticks < 200 {
    p.pump()
    ticks = ticks + 1
    if ticks == 5 {
      // 中途 seek：清队列重定位后仍能继续
      p.seek(0.3)
      inspect(p.is_playing(), content="true")
    }
    if ticks == 10 {
      p.pause()
      inspect(p.is_playing(), content="false")
      p.play()
    }
  }
  // 1 秒素材 + seek，200 tick 内应自然播完（真设备 ≈20+ tick，哑设备 ≈40+ tick）
  inspect(p.is_playing(), content="false")
  // 循环模式：播放 → EOF 后 pump 应自动回到播放态
  p.set_looping(true)
  p.play()
  let mut nxt = 0
  while p.is_playing() && nxt < 400 {
    p.pump()
    nxt = nxt + 1
  }
  // 循环开着时应一直在播（nxt 跑满都还在播）
  inspect(p.is_playing(), content="true")
  p.set_looping(false)
  p.stop()
  inspect(p.is_playing(), content="false")
  inspect(p.current() < 0.05, content="true")
  p.free()
  println("AudioPlayer 冒烟完成（pump \{ticks} tick 播完 1 秒素材，循环重播验证 OK）")
}

///|
/// AudioPlayer 错误路径：不存在的文件 / 无音频流的视频文件。
test "AudioPlayer 错误路径" {
  match AudioPlayer::make("/nonexistent/a.mp3") {
    Err(_) => ()
    Ok(p) => {
      p.free()
      fail("不应打开成功")
    }
  }
  // testsrc_1s.avi 只有视频流：开音频解码器应失败
  match AudioPlayer::make("../ffmpeg-mbt/src/testdata/testsrc_1s.avi") {
    Err(_) => ()
    Ok(p) => {
      p.free()
      fail("纯视频文件不应建成音频播放器")
    }
  }
}
