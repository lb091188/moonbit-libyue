///|
/// 音量钳制纯函数（NaN / 越界）。
test "audio_clamp_volume：钳制 [0,1]" {
  inspect(audio_clamp_volume(0.0), content="0")
  inspect(audio_clamp_volume(1.0), content="1")
  inspect(audio_clamp_volume(0.37), content="0.37")
  inspect(audio_clamp_volume(-1.0), content="0")
  inspect(audio_clamp_volume(2.0), content="1")
  inspect(audio_clamp_volume(0.0 / 0.0), content="0")
}

///|
/// 真机冒烟：引擎创建 + 加载系统 wav + 音量读写（无输出设备的服务
/// 容器环境合法跳过后半段；播放/停止属设置类，不在测试中执行）。
test "audio 真机冒烟：引擎/加载/音量（无设备跳过）" {
  match AudioEngine::new() {
    Err(e) => println("audio: 引擎不可用，跳过（\{e}）")
    Ok(engine) => {
      match engine.load("/usr/share/sounds/alsa/Front_Center.wav") {
        Err(e) => println("audio: 加载失败（\{e}）")
        Ok(clip) => {
          println("audio: 加载成功，volume=\{clip.get_volume()}")
          clip.set_volume(0.5)
          inspect(clip.get_volume() > 0.49 && clip.get_volume() < 0.51, content="true")
          clip.free()
        }
      }
      engine.free()
    }
  }
}

///|
/// 错误路径：加载不存在的文件给 LoadFailed 而非崩溃。
test "audio 错误路径：不存在文件 LoadFailed" {
  match AudioEngine::new() {
    Err(e) => println("audio: 引擎不可用，跳过（\{e}）")
    Ok(engine) => {
      match engine.load("/nonexistent/definitely_not_here.wav") {
        Ok(_) => fail("不存在的文件不应加载成功")
        Err(e) => println("audio: 预期错误 \{e}")
      }
      engine.free()
    }
  }
}
