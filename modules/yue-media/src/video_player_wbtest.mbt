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
  // play + 手动 tick（组件里由定时器驱动）解出帧；音轨队列同 tick 补。
  // tick 前回拨墙钟 100ms：play 与 tick 同毫秒时目标时刻为 0、位置停
  // 在起点属正常语义，回拨让位置断言确定为 ≈0.1（同下方时钟同轴测）
  player.play()
  inspect(player.is_playing(), content="true")
  player.wall0.val = player.wall0.val - 100L
  player.vp_tick()
  match player.current_frame() {
    Some(b) =>
      inspect(
        b.length(),
        content="\{player.frame_width() * player.frame_height() * 4}",
      )
    None => fail("tick 后应有帧")
  }
  let t1 = player.current()
  if t1 < 0.09 || t1 > 0.15 {
    fail("首 tick 位置应 ≈0.1s：\{t1}")
  }
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
  println(
    "VideoPlayer FFI 双路冒烟完成（视频帧 + 音轨 PCM 队列）",
  )
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

///|
/// 时钟同轴回归：素材实为 12fps，故意传错回退 fps=5——播放位置仍须
/// 按帧时间戳推进（与 duration 同轴），且 EOF 后位置钉在时长（进度
/// 满格）。白盒回拨墙钟基准模拟时间流逝。
test "VideoPlayer 时钟同轴：回退 fps 不影响时间轴" {
  let path = "../ffmpeg-mbt/src/testdata/av_1s.mp4"
  let player = match VideoPlayer::make(path, fps=5) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  let dur = player.duration()
  if dur < 0.9 || dur > 1.1 {
    fail("时长异常：\{dur}（期望 ≈1）")
  }
  player.play()
  player.vp_tick()
  // 回拨 500ms → 目标 0.5s：帧解到 pts>=0.5，位置=0.5
  player.wall0.val = player.wall0.val - 500L
  player.vp_tick()
  let mid = player.current()
  if mid < 0.45 || mid > 0.55 {
    fail("半程位置异常：\{mid}（期望 0.5）")
  }
  // 回拨 2s → 目标超时长：解完全部帧 EOF，位置钉在时长、转停
  player.wall0.val = player.wall0.val - 2000L
  player.vp_tick()
  if player.current() != dur {
    fail("EOF 位置应钉在时长：\{player.current()} != \{dur}")
  }
  inspect(player.is_playing(), content="false")
  player.free()
}

///|
/// 白盒推进到 EOF：每拍把墙钟基准回拨 2s（目标时刻远超时长），解码器
/// 被推到底——追帧上限 8 帧/拍，1 秒素材两三条内 EOF；非循环转 ended
/// 停播（is_playing 翻 false 即收），循环则每拍 vp_restart 回起点、
/// is_playing 保持 true，靠拍数上限收尾。
fn vp_force_eof(player : VideoPlayer) -> Unit {
  let mut rounds = 0
  while player.is_playing() && rounds < 10 {
    player.wall0.val = player.wall0.val - 2000L
    player.vp_tick()
    rounds = rounds + 1
  }
}

///|
/// 循环播放：EOF 时双 demuxer 回起点自动续播（vp_restart）——状态保持
/// 播放、位置归零、视频/音频都能从头再解（AudioPlayer 循环测试的对称
/// 缺口，此前视频侧无循环回归）。
test "VideoPlayer 循环：EOF 自动回起点重播" {
  let path = "../ffmpeg-mbt/src/testdata/av_1s.mp4"
  let player = match VideoPlayer::make(path, fps=12, looping=true) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  player.play()
  vp_force_eof(player)
  // 循环开着：EOF 不转停，回起点继续播
  inspect(player.is_playing(), content="true")
  inspect(player.current(), content="0")
  // 视频 demuxer 已 seek(0)：下一 tick 从头解出首帧
  player.vp_tick()
  match player.current_frame() {
    Some(_) => ()
    None => fail("循环重播应解出帧")
  }
  // 音频 demuxer 已 seek(0)：队列补上 PCM（有声）
  match player.dev.val {
    Some(d) =>
      if mbt_adev_queued_bytes(d) <= 0L {
        fail("循环重播后音频队列应有 PCM 在途")
      }
    None => fail("应有设备句柄")
  }
  player.set_looping(false)
  player.free()
  println("VideoPlayer 循环重播验证 OK")
}

///|
/// 播完后再点播放：双 demuxer 回起点从头重播（修复前停在 EOF——位置
/// 钉时长、画面钉末帧、音频队列全空，再点播放毫无变化）。
test "VideoPlayer 播完后再 play：回起点重播" {
  let path = "../ffmpeg-mbt/src/testdata/av_1s.mp4"
  let player = match VideoPlayer::make(path, fps=12) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  player.play()
  vp_force_eof(player)
  // 播完（非循环）：位置钉时长、离开播放态
  inspect(player.is_playing(), content="false")
  if player.current() != player.duration() {
    fail(
      "EOF 位置应钉在时长：\{player.current()} != \{player.duration()}",
    )
  }
  // 再 play：回起点重播
  player.play()
  inspect(player.is_playing(), content="true")
  inspect(player.current(), content="0")
  // 视频侧从头解帧
  player.vp_tick()
  match player.current_frame() {
    Some(_) => ()
    None => fail("重播首 tick 应解出帧")
  }
  // 音频侧有声：队列有 PCM 在途、音轨 demuxer 可继续解
  match player.dev.val {
    Some(d) =>
      if mbt_adev_queued_bytes(d) <= 0L {
        fail("播完重播后音频队列应有 PCM 在途")
      }
    None => fail("应有设备句柄")
  }
  match player.audio.val {
    Some(a) =>
      match a.decode_pcm() {
        Some(_) => ()
        None => fail("重播后音轨 demuxer 应能解出 PCM")
      }
    None => fail("应有音轨 demuxer")
  }
  player.free()
}

///|
/// 播完态拖进度：seek 离开 ended 态，再 play 从落点续播而非回起点
/// （重播语义只属于「停在末尾直接再 play」）。
test "VideoPlayer 播完态 seek 后再 play：从落点续播" {
  let path = "../ffmpeg-mbt/src/testdata/av_1s.mp4"
  let player = match VideoPlayer::make(path, fps=12) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  player.play()
  vp_force_eof(player)
  inspect(player.is_playing(), content="false")
  // 拖到 0.5s：离开 ended，再 play 从 0.5 续播（位置不归零）
  player.seek(0.5)
  player.play()
  inspect(player.is_playing(), content="true")
  let t = player.current()
  if t < 0.45 || t > 0.6 {
    fail("播完态 seek(0.5) 后再 play 应从落点续播：\{t}")
  }
  player.vp_tick()
  match player.current_frame() {
    Some(_) => ()
    None => fail("seek 后续播应解出帧")
  }
  player.free()
}

///|
/// stop 后再 play：音频 demuxer 同步回起点，重播有声（修复前 stop 只
/// seek 视频 demuxer，音轨停在 EOF——vp_fill_audio 全程解不出 PCM，
/// 有声画面全程静音）。
test "VideoPlayer stop 后再 play：重播有声" {
  let path = "../ffmpeg-mbt/src/testdata/av_1s.mp4"
  let player = match VideoPlayer::make(path, fps=12) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  player.play()
  vp_force_eof(player)
  inspect(player.is_playing(), content="false")
  // stop：双 demuxer 都回起点、状态回 idle
  player.stop()
  inspect(player.is_playing(), content="false")
  inspect(player.current(), content="0")
  // 再 play：音频队列补上 PCM（修复前音轨 EOF、队列全空、全程无声）
  player.play()
  inspect(player.is_playing(), content="true")
  match player.dev.val {
    Some(d) =>
      if mbt_adev_queued_bytes(d) <= 0L {
        fail("stop 后再 play 音频队列应有 PCM 在途")
      }
    None => fail("应有设备句柄")
  }
  match player.audio.val {
    Some(a) =>
      match a.decode_pcm() {
        Some(_) => ()
        None => fail("stop 后音轨 demuxer 应能解出 PCM")
      }
    None => fail("应有音轨 demuxer")
  }
  // 视频侧同样从头解帧
  player.vp_tick()
  match player.current_frame() {
    Some(_) => ()
    None => fail("stop 重播首 tick 应解出帧")
  }
  player.free()
}

///|
/// 音量钳制：media_clamp_volume（音频/视频播放器共用）与 VideoPlayer::
/// set_volume 同规则——负值归 0、超 1 归 1、NaN 归 0（AudioPlayer 侧
/// 循环测试之外的对称缺口）。
test "音量钳制：media_clamp_volume 与 set_volume" {
  inspect(media_clamp_volume(-0.5), content="0")
  inspect(media_clamp_volume(0.0), content="0")
  inspect(media_clamp_volume(0.25), content="0.25")
  inspect(media_clamp_volume(1.0), content="1")
  inspect(media_clamp_volume(2.0), content="1")
  inspect(media_clamp_volume(0.0 / 0.0), content="0")
  // VideoPlayer::set_volume 钳制后落 volume 字段（并透传设备）
  let path = "../ffmpeg-mbt/src/testdata/av_1s.mp4"
  let player = match VideoPlayer::make(path, fps=12) {
    Ok(p) => p
    Err(e) => fail("make 失败：\{e}")
  }
  player.set_volume(5.0)
  inspect(player.volume.val, content="1")
  player.set_volume(-1.0)
  inspect(player.volume.val, content="0")
  player.set_volume(0.5)
  inspect(player.volume.val, content="0.5")
  player.free()
}
