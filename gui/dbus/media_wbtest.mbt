// 媒体控制模块白盒测试：总线名过滤（ListNames 应答样例）、PlaybackStatus
// 文本映射、Metadata 的 xesam 字段提取（artist 的 as 数组与单字符串双
// 形态）、playerctl 参数构造与 --format 输出解析、真机只读冒烟
// （media_players / media_status，无会话总线或无播放器时跳过）。
// 播放控制属设置类操作，本文件不真实执行任何播放命令。

///|
/// 构造 ListNames 应答形态（as，混入总线自身名/非播放器代理名）。
fn media_test_names() -> GDBusValue {
  GVArray("s", [
    GVString("org.freedesktop.DBus"),
    GVString(":1.42"),
    GVString("ca.desrt.confuse"),
    GVString("org.mpris.MediaPlayer2.vlc"),
    GVString("org.mpris.MediaPlayer2.playerctld"),
    GVString("org.mpris.MediaPlayer2."),
  ])
}

///|
test "media_is_mpris_name：前缀过滤与空后缀拒绝" {
  assert_true(media_is_mpris_name("org.mpris.MediaPlayer2.vlc"))
  assert_true(media_is_mpris_name("org.mpris.MediaPlayer2.playerctld"))
  assert_true(
    media_is_mpris_name("org.mpris.MediaPlayer2.chromium.instance123"),
  )
  // 非 MPRIS 名字一律不收
  assert_true(!media_is_mpris_name("org.freedesktop.DBus"))
  assert_true(!media_is_mpris_name(":1.42"))
  assert_true(!media_is_mpris_name("org.mpris.MediaPlayer2")) // 缺尾点
  assert_true(!media_is_mpris_name("org.mpris.MediaPlayer2.")) // 空后缀
  assert_true(!media_is_mpris_name("org.mpris.MediaPlayer2X"))
  assert_true(!media_is_mpris_name(""))
}

///|
test "media_mpris_names：ListNames 应答过滤" {
  let names = media_mpris_names(media_test_names())
  assert_eq(names.length(), 2)
  assert_eq(names[0], "org.mpris.MediaPlayer2.vlc")
  assert_eq(names[1], "org.mpris.MediaPlayer2.playerctld")
  // 非数组应答 → 空表（应答形态不符不当作"有播放器"）
  assert_eq(media_mpris_names(GVNone).length(), 0)
  assert_eq(media_mpris_names(GVString("org.mpris.MediaPlayer2.vlc")).length(), 0)
}

///|
test "media_playback_of：PlaybackStatus 文本映射" {
  assert_true(media_playback_of("Playing") is MediaPlaying)
  assert_true(media_playback_of("Paused") is MediaPaused)
  assert_true(media_playback_of("Stopped") is MediaStopped)
  // 容忍首尾空白（应答带换行）
  assert_true(media_playback_of(" Playing\n") is MediaPlaying)
  // 自定义/未知状态原样保留（trim 后）
  assert_true(media_playback_of("TrackChanged") is MediaUnknown("TrackChanged"))
  assert_true(media_playback_of("") is MediaUnknown(""))
  assert_true(media_playback_of("  playing  ") is MediaUnknown("playing"))
}

///|
test "media_status_of：Metadata 的 xesam 字段提取" {
  // 规范形态：xesam:artist 是 as 数组（取首个），其余为字符串
  let meta : Map[String, GDBusValue] = Map([])
  meta.set("mpris:trackid", GVPath("/org/mpris/MediaPlayer2/track/0"))
  meta.set("mpris:length", GVInt64(269000000L))
  meta.set("xesam:title", GVString("晴天"))
  meta.set(
    "xesam:artist",
    GVArray("s", [
      GVString("周杰伦"),
      GVString("费玉清"),
    ]),
  )
  meta.set("xesam:album", GVString("叶惠美"))
  let st = media_status_of("org.mpris.MediaPlayer2.vlc", MediaPlaying, meta)
  assert_eq(st.player, "org.mpris.MediaPlayer2.vlc")
  assert_true(st.playback is MediaPlaying)
  assert_eq(st.title, "晴天")
  assert_eq(st.artist, "周杰伦")
  assert_eq(st.album, "叶惠美")
  // artist 单字符串形态（个别播放器）也收
  let meta2 : Map[String, GDBusValue] = Map([])
  meta2.set("xesam:artist", GVString("陈奕迅"))
  let st2 = media_status_of("p2", MediaPaused, meta2)
  assert_eq(st2.artist, "陈奕迅")
  // 字段缺失/类型不符 → 空串；空 artist 数组 → 空串
  let meta3 : Map[String, GDBusValue] = Map([])
  meta3.set("xesam:artist", GVArray("s", []))
  meta3.set("xesam:title", GVInt32(0)) // 类型不符按缺失
  let st3 = media_status_of("p3", MediaStopped, meta3)
  assert_eq(st3.title, "")
  assert_eq(st3.artist, "")
  assert_eq(st3.album, "")
}

///|
test "media_playerctl_sel / media_playerctl_parse_meta：命令回退纯逻辑" {
  // -p 选择参数：剥 MPRIS 前缀取实例名；非 MPRIS 形态原样
  assert_eq(media_playerctl_sel("org.mpris.MediaPlayer2.vlc"), "vlc")
  assert_eq(media_playerctl_sel("org.mpris.MediaPlayer2.chromium.instance1"), "chromium.instance1")
  assert_eq(media_playerctl_sel("vlc"), "vlc")
  // --format 输出按 US 字符切三段
  let (t1, a1, b1) = media_playerctl_parse_meta(
    "晴天\u{1f}周杰伦\u{1f}叶惠美\n",
  )
  assert_eq(t1, "晴天")
  assert_eq(a1, "周杰伦")
  assert_eq(b1, "叶惠美")
  // 缺段补空串（不支持模板的播放器）
  let (t2, a2, b2) = media_playerctl_parse_meta("只有标题")
  assert_eq((t2, a2, b2), ("只有标题", "", ""))
  let (t3, a3, b3) = media_playerctl_parse_meta("")
  assert_eq((t3, a3, b3), ("", "", ""))
  // 空段保留（标题缺失但分隔符在）
  let (t4, a4, b4) = media_playerctl_parse_meta("\u{1f}歌手\u{1f}专辑")
  assert_eq((t4, a4, b4), ("", "歌手", "专辑"))
}

///|
test "media_playerctl_meta_args：参数表构造" {
  let args = media_playerctl_meta_args("vlc")
  assert_eq(args.length(), 5)
  assert_eq(args[0], "-p")
  assert_eq(args[1], "vlc")
  assert_eq(args[2], "metadata")
  assert_eq(args[3], "--format")
  // 模板含三个 {{字段}} 占位与三个 US 分隔符 → 4 段
  let fmt = args[4]
  assert_true(fmt.contains("{{title}}"))
  assert_true(fmt.contains("{{artist}}"))
  assert_true(fmt.contains("{{album}}"))
  assert_eq(media_split_us(fmt).length(), 4)
}

///|
test "media_mpris_method / media_playerctl_subcmd：命令名映射" {
  assert_eq(media_mpris_method(MediaCmdPlay), "Play")
  assert_eq(media_mpris_method(MediaCmdPause), "Pause")
  assert_eq(media_mpris_method(MediaCmdPlayPause), "PlayPause")
  assert_eq(media_mpris_method(MediaCmdNext), "Next")
  assert_eq(media_mpris_method(MediaCmdPrevious), "Previous")
  assert_eq(media_mpris_method(MediaCmdStop), "Stop")
  assert_eq(media_playerctl_subcmd(MediaCmdPlay), "play")
  assert_eq(media_playerctl_subcmd(MediaCmdPause), "pause")
  assert_eq(media_playerctl_subcmd(MediaCmdPlayPause), "play-pause")
  assert_eq(media_playerctl_subcmd(MediaCmdNext), "next")
  assert_eq(media_playerctl_subcmd(MediaCmdPrevious), "previous")
  assert_eq(media_playerctl_subcmd(MediaCmdStop), "stop")
}

///|
test "media 真机只读冒烟：players 与 status（无总线或无播放器跳过）" {
  if @sys.sys_platform() != "linux" {
    println("media: skip (非 Linux)")
    return
  }
  println("media_supported: \{media_supported()}")
  match media_players() {
    Ok(players) =>
      for p in players {
        println("media player: \{p.identity} (\{p.name})")
        match media_status(p.name) {
          Ok(s) => println("media status: \{s}")
          Err(e) => println("media_status(\{p.name}) failed: \{e}")
        }
      }
    Err(NoPlayer) =>
      println("media: 无 MPRIS 播放器（等待播放器上线）")
    Err(Unsupported) => println("media: 平台不支持")
    Err(e) => println("media_players failed: \{e}")
  }
}

///|
test "media 错误路径：不存在的播放器给错误而非 Ok" {
  if @sys.sys_platform() != "linux" {
    println("media: skip (非 Linux)")
    return
  }
  // 只读查询：ServiceUnknown（无此服务）与 playerctl 回退失败都应是
  // Err；不存在的实例名不可能读回 Ok
  match media_status("org.mpris.MediaPlayer2.__no_such_player__") {
    Ok(_) => fail("不存在的播放器不应读回 Ok")
    Err(e) => println("media_status(不存在实例) 预期错误: \{e}")
  }
  // media_players 在无播放器时给 NoPlayer，在有播放器时给 Ok，两者
  // 之外都 println 出来（由真机冒烟测试观察）
  match media_players() {
    Ok(ps) => println("players: \{ps.length()} 个")
    Err(e) => println("players err: \{e}")
  }
}

///|
test "media_status_changed：状态快照变化判定" {
  let base = MediaStatus::{
    player: "org.mpris.MediaPlayer2.vlc",
    playback: MediaPlaying,
    title: "A",
    artist: "B",
    album: "C",
  }
  // 完全相同的快照无变化
  assert_false(media_status_changed(base, base))
  // 播放态变化
  assert_true(media_status_changed(
      base,
      MediaStatus::{ ..base, playback: MediaPaused },
    ))
  // 标题变化
  assert_true(media_status_changed(base, MediaStatus::{ ..base, title: "X" }))
  // 艺术家变化
  assert_true(media_status_changed(base, MediaStatus::{ ..base, artist: "Y" }))
  // 专辑变化
  assert_true(media_status_changed(base, MediaStatus::{ ..base, album: "Z" }))
  // player 字段本身不参与变化判定（目标锁定后不会变）
  assert_false(media_status_changed(base, MediaStatus::{ ..base, player: "other" }))
}

///|
test "MediaWatcher：建/运行中/停止 语义" {
  let w = MediaWatcher::make()
  assert_true(w.is_running())
  media_watch_stop(w)
  assert_false(w.is_running())
}

///|
test "media 真机冒烟：监视启动后立停不崩（无播放器环境跳过触发）" {
  if @sys.sys_platform() != "linux" {
    println("media watch: skip (非 Linux)")
    return
  }
  // 无播放器机器上目标解析失败，轮询静默跳过、on_change 不触发；
  // 有播放器机器上首轮建基线也不触发。启动后立即停止验证句柄与
  // 定时器注销路径不抛异常。
  let mut fired = 0
  // 排期通道由调用方注入（GUI 层给 @shell.set_timeout）：这里给假通道，
  // 只验证句柄与停止路径，不真起轮询
  let pending : Array[() -> Unit] = []
  let w = media_watch_status(
    fn(_ms : Int, f : () -> Unit) -> Unit { pending.push(f) },
    fn(_s : MediaStatus) -> Unit { fired = fired + 1 },
    interval_ms=100,
  )
  assert_true(pending.length() == 1)
  media_watch_stop(w)
  assert_false(w.is_running())
  println("media watch 冒烟完成（触发次数 \{fired}）")
}
