// W36 无头播放便捷入口：不创建窗口、不挂组件树，纯代码驱动解码+输出。
//
// 与 audio_player.mbt / video_player.mbt 的 UI 形态**共享引擎**（audio.mbt / video.mbt），
// 分工是：
// - **无头消费者**（脚本批处理、无 UI 服务、后台混音、单元测试）走本文件的
//   `HeadlessAudio::open` / `HeadlessVideo::open`，通过注入的 `schedule` 通道自
//   驱动 pump；
// - **UI 消费者**（组件形态、要挂进 Node 树）继续走 `audio_player_t` /
//   `video_player_t`——那两条走 Store 反应式 + App 时钟 pump，与 widget 树
//   重绘节奏对齐，硬套本文件的 schedule 反而多一层转发。
//
// 两条路径的引擎调用点、错误处理、循环/倍速/音量语义完全一致。

///|
/// 无头音频播放器：建引擎 + 挂定时器自 pump + 播完回调。
pub(all) struct HeadlessAudio {
  player : AudioPlayer
  mut pump_id : Int
  on_complete : () -> Unit
}

///|
/// 打开音频文件并开始 pump。`schedule` 是定时器注入通道
/// （GUI 层给 `fn(ms, f) { @shell.set_timeout(ms, f) }`，纯后台自管轮询）。
pub fn HeadlessAudio::open(
  path : String,
  schedule : (Int, () -> Unit) -> Int,
  on_complete? : () -> Unit = fn() {},
) -> HeadlessAudio? {
  match AudioPlayer::make(path) {
    Ok(p) => {
      let h : HeadlessAudio = { player: p, pump_id: 0, on_complete: on_complete }
      let self_ref = Ref(h)
      let tick = fn() -> Unit {
        let a = self_ref.val
        let was_playing = a.player.is_playing()
        a.player.pump()
        if was_playing && !a.player.is_playing() && !a.player.is_closed() {
          (a.on_complete)()
        }
        self_ref.val = a
      }
      let id = schedule(20, tick)
      Some({ player: p, pump_id: id, on_complete: on_complete, })
    }
    Err(_) => None
  }
}

///|
pub fn HeadlessAudio::play(self : HeadlessAudio) -> Unit { self.player.play() }
pub fn HeadlessAudio::pause(self : HeadlessAudio) -> Unit { self.player.pause() }
pub fn HeadlessAudio::stop(self : HeadlessAudio) -> Unit { self.player.stop() }
pub fn HeadlessAudio::seek(self : HeadlessAudio, t : Double) -> Unit { self.player.seek(t) }
pub fn HeadlessAudio::set_volume(self : HeadlessAudio, v : Double) -> Unit { self.player.set_volume(v) }
pub fn HeadlessAudio::set_speed(self : HeadlessAudio, v : Double) -> Unit { self.player.set_speed(v) }
pub fn HeadlessAudio::set_looping(self : HeadlessAudio, on : Bool) -> Unit { self.player.set_looping(on) }
pub fn HeadlessAudio::current(self : HeadlessAudio) -> Double { self.player.current() }
pub fn HeadlessAudio::duration(self : HeadlessAudio) -> Double { self.player.duration() }
pub fn HeadlessAudio::is_playing(self : HeadlessAudio) -> Bool { self.player.is_playing() }

///|
pub fn HeadlessAudio::close(
  self : HeadlessAudio,
  cancel : (Int) -> Unit,
) -> Unit {
  cancel(self.pump_id)
  self.player.free()
}

///|
/// 无头视频播放器：同上 + current_frame() 取 RGBA 帧。
pub(all) struct HeadlessVideo {
  player : VideoPlayer
  mut pump_id : Int
  on_complete : () -> Unit
}

///|
pub fn HeadlessVideo::open(
  path : String,
  schedule : (Int, () -> Unit) -> Int,
  on_complete? : () -> Unit = fn() {},
) -> HeadlessVideo? {
  match VideoPlayer::make(path) {
    Ok(p) => {
      let v : HeadlessVideo = { player: p, pump_id: 0, on_complete: on_complete }
      let self_ref = Ref(v)
      let tick = fn() -> Unit {
        let h = self_ref.val
        let was_playing = h.player.is_playing()
        h.player.tick()
        if was_playing && !h.player.is_playing() && !h.player.is_closed() {
          (h.on_complete)()
        }
        self_ref.val = h
      }
      let id = schedule(20, tick)
      Some({ player: p, pump_id: id, on_complete: on_complete, })
    }
    Err(_) => None
  }
}

///|
pub fn HeadlessVideo::play(self : HeadlessVideo) -> Unit { self.player.play() }
pub fn HeadlessVideo::pause(self : HeadlessVideo) -> Unit { self.player.pause() }
pub fn HeadlessVideo::stop(self : HeadlessVideo) -> Unit { self.player.stop() }
pub fn HeadlessVideo::seek(self : HeadlessVideo, t : Double) -> Unit { self.player.seek(t) }
pub fn HeadlessVideo::set_volume(self : HeadlessVideo, v : Double) -> Unit { self.player.set_volume(v) }
pub fn HeadlessVideo::current(self : HeadlessVideo) -> Double { self.player.current() }
pub fn HeadlessVideo::duration(self : HeadlessVideo) -> Double { self.player.duration() }
pub fn HeadlessVideo::is_playing(self : HeadlessVideo) -> Bool { self.player.is_playing() }

///|
/// 当前帧 RGBA 像素；None 表示还没有解码完第一帧。
pub fn HeadlessVideo::current_frame(self : HeadlessVideo) -> Bytes? {
  self.player.current_frame()
}

///|
pub fn HeadlessVideo::close(
  self : HeadlessVideo,
  cancel : (Int) -> Unit,
) -> Unit {
  cancel(self.pump_id)
  self.player.free()
}
