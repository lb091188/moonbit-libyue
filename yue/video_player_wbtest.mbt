///|
/// 播放数学纯函数（帧索引/位置钳制/进度/时间文本）。
test "播放数学：帧索引/钳制/进度/时间文本" {
  inspect(vp_frame_idx(0.0, 12), content="0")
  inspect(vp_frame_idx(0.5, 12), content="6")
  inspect(vp_frame_idx(-1.0, 12), content="0")
  inspect(vp_frame_idx(1.0, 0), content="1")
  // 钳制
  inspect(vp_clamp_t(5.0, 10.0), content="5")
  inspect(vp_clamp_t(-3.0, 10.0), content="0")
  inspect(vp_clamp_t(99.0, 10.0), content="10")
  inspect(vp_clamp_t(3.0, 0.0), content="0")
  // 进度
  inspect(vp_pct(5.0, 10.0), content="0.5")
  inspect(vp_pct(0.0, 10.0), content="0")
  inspect(vp_pct(99.0, 10.0), content="1")
  inspect(vp_pct(3.0, 0.0), content="0")
  // 时间文本
  inspect(vp_fmt_time(0.0), content="0:00")
  inspect(vp_fmt_time(9.4), content="0:09")
  inspect(vp_fmt_time(65.0), content="1:05")
  inspect(vp_fmt_time(-5.0), content="0:00")
}

///|
/// 真机全链路冒烟（ffmpeg 缺失跳过）：lavfi 生成带音轨 AVI（2 秒）→
/// VideoPlayer::make → 初始状态 → seek/play/pause/stop → free。
test "VideoPlayer 真机冒烟：make/状态机/seek/free" {
  if !vidf_supported() {
    println("VideoPlayer: ffmpeg 不可用，跳过")
    return
  }
  let avi = "/tmp/yue-vp-test-\{@subproc.get_pid()}.avi"
  // testsrc 视频 + sine 音频合成带音轨 AVI
  match pr_run(
    "ffmpeg",
    [
      "-v", "error", "-y",
      "-f", "lavfi", "-i", "testsrc=duration=2:size=160x120:rate=5",
      "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
      "-pix_fmt", "yuv420p",
      avi,
    ],
    timeout_ms=30000,
  ) {
    Ok(o) =>
      if o.exit_code != 0 {
        println("VideoPlayer: 测试视频生成失败，跳过")
        return
      }
    Err(e) => {
      println("VideoPlayer: spawn 失败（\{e}），跳过")
      return
    }
  }
  let player = match VideoPlayer::make(avi, fps=8, width=160, height=120) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  // 元信息：时长约 2 秒、帧集非空、初始 idle
  // AVI 容器 format duration 含容器 padding(2.0s 源 → 实测 2.2s)；
  // 无 format duration 的容器走帧集兜底(帧数/帧率)。两者都在 2s 量级。
  inspect(player.duration() > 1.9 && player.duration() < 2.5, content="true")
  inspect(player.is_playing(), content="false")
  inspect(player.current(), content="0")
  match player.current_frame() {
    Some(_) => ()
    None => fail("首帧应存在")
  }
  // 状态机：seek → play → pause → play → stop
  player.seek(0.5)
  inspect(player.current(), content="0.5")
  player.play()
  inspect(player.is_playing(), content="true")
  player.pause()
  inspect(player.is_playing(), content="false")
  player.play()
  inspect(player.is_playing(), content="true")
  player.stop()
  inspect(player.is_playing(), content="false")
  inspect(player.current(), content="0")
  // 音量与循环
  player.set_volume(0.5)
  player.set_looping(true)
  player.free()
  println("VideoPlayer 冒烟完成")
}
