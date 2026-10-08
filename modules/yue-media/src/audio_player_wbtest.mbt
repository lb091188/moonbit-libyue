///|
/// 真实节奏等待（busy 等待单调时钟）：真设备分支按设备实际消费推进，
/// 连打 pump 设备来不及吃队列，须按拍留出真实时间。
fn ap_wait_ms(ms : Int) -> Unit {
  let t0 = mbt_now_ms()
  while mbt_now_ms() - t0 < ms.to_int64() {
    ()
  }
}

///|
/// AudioPlayer 冒烟：内置 1 秒正弦 mp3 打开 → 播放 → pump 推进 →
/// seek → 暂停/停止 → 循环重播 → 释放。无输出设备环境（CI）自动走
/// 静音降级分支，状态机照常验证；真设备分支按 25ms/拍真实节奏推进
/// （设备实际消费 PCM），并断言播放中队列有 PCM 在途（「只有拖动
/// 时才有一下声音」的回归断言）。
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
    ap_wait_ms(25)
    p.pump()
    ticks = ticks + 1
    if ticks == 1 {
      // 真设备播放中：首拍 pump 后队列应有 PCM 在途（start 后不再被
      // 误判哑设备——「只有拖动时才有一下声音」的回归断言）
      if !p.is_muted() {
        match p.dev.val {
          Some(d) =>
            if mbt_adev_queued_bytes(d) <= 0L {
              fail("真设备播放中队列应有 PCM 在途")
            }
          None => fail("应持有设备句柄")
        }
      }
    }
    if ticks == 5 {
      // 中途 seek：清队列重定位后仍能继续；位置必须落在 seek 点——
      // 修复前 current 自 0 重新累计，进度条被拉回开头（「拖不动」根因）
      p.seek(0.3)
      inspect(p.is_playing(), content="true")
      if p.current() < 0.29 {
        fail("seek(0.3) 后位置应 ≥0.29，实为 \{p.current()}")
      }
    }
    if ticks == 6 {
      // pump 一拍后位置仍从 seek 点推进（真设备=0.3+消费，哑设备=0.3+0.025）
      if p.current() < 0.29 {
        fail("seek 后 pump 位置不应回落，实为 \{p.current()}")
      }
    }
    if ticks == 10 {
      p.pause()
      inspect(p.is_playing(), content="false")
      p.play()
    }
  }
  // 1 秒素材 + seek，200 拍内应自然播完（真设备/哑设备均 ≈40+ 拍）
  inspect(p.is_playing(), content="false")
  // 循环模式：播放 → EOF 后 pump 应自动回到播放态
  p.set_looping(true)
  p.play()
  let mut nxt = 0
  while p.is_playing() && nxt < 400 {
    ap_wait_ms(25)
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
  println("AudioPlayer 冒烟完成（pump \{ticks} 拍播完 1 秒素材，循环重播验证 OK）")
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
