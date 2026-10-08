///|
/// 播放数学纯函数。
test "播放数学：帧索引/钳制/进度/时间文本" {
  inspect(vp_frame_idx(0.0, 12), content="0")
  inspect(vp_frame_idx(0.5, 12), content="6")
  inspect(vp_frame_idx(-1.0, 12), content="0")
  inspect(vp_clamp_t(5.0, 10.0), content="5")
  inspect(vp_clamp_t(-3.0, 10.0), content="0")
  inspect(vp_clamp_t(99.0, 10.0), content="10")
  inspect(vp_pct(5.0, 10.0), content="0.5")
  inspect(vp_pct(99.0, 10.0), content="1")
  inspect(vp_fmt_time(0.0), content="0:00")
  inspect(vp_fmt_time(65.0), content="1:05")
}

///|
/// 真机冒烟（内置 1 秒带音轨 mp4：make 双 Demuxer → 元信息 → 状态机
/// seek/play/tick 推帧/pause/stop/free）。
test "VideoPlayer 真机冒烟：FFI 双路状态机" {
  let path = "../ffmpeg-mbt/src/testdata/av_1s.mp4"
  let player = match VideoPlayer::make(path, fps=12) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  inspect(player.frame_width() > 0, content="true")
  inspect(player.frame_height() > 0, content="true")
  inspect(player.duration() > 0.0, content="true")
  inspect(player.has_audio(), content="true")
  // 初始 idle、无帧
  inspect(player.is_playing(), content="false")
  match player.current_frame() {
    None => ()
    Some(_) => fail("未播不应有帧")
  }
  // play + 手动 tick（组件里由定时器驱动）解出帧；音轨队列同 tick 补
  player.play()
  inspect(player.is_playing(), content="true")
  player.vp_tick()
  match player.current_frame() {
    Some(b) => inspect(b.length(), content="\{player.frame_width() * player.frame_height() * 4}")
    None => fail("tick 后应有帧")
  }
  let t1 = player.current()
  inspect(t1 > 0.0, content="true")
  // seek 到 0.5s：帧清空，下一 tick 重新解出
  player.seek(0.5)
  match player.current_frame() {
    None => ()
    Some(_) => fail("seek 后应清当前帧")
  }
  player.vp_tick()
  match player.current_frame() {
    Some(_) => ()
    None => fail("seek 后 tick 应有帧")
  }
  // pause/stop/free（free 后时钟停摆语义）
  player.pause()
  inspect(player.is_playing(), content="false")
  player.stop()
  inspect(player.current(), content="0")
  player.set_volume(0.5)
  player.set_looping(true)
  player.free()
  inspect(player.is_closed(), content="true")
  println("VideoPlayer FFI 双路冒烟完成（视频帧 + 音轨 PCM 队列）")
}

///|
/// 无音轨视频（内置 testsrc avi）：静音路径（无音频 Demuxer/设备），
/// 纯视频状态机照常。
test "VideoPlayer 无音轨：静音播放路径" {
  let path = "../ffmpeg-mbt/src/testdata/testsrc_1s.avi"
  let player = match VideoPlayer::make(path, fps=12) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  inspect(player.has_audio(), content="false")
  player.play()
  inspect(player.is_playing(), content="true")
  player.vp_tick()
  match player.current_frame() {
    Some(_) => ()
    None => fail("tick 后应有帧")
  }
  player.stop()
  player.free()
}
