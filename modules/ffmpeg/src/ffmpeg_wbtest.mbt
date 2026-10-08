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
/// 真机冒烟：系统视频文件打开 → 元信息 → 逐帧解码 → seek。
/// 素材取本机固定的 mp4（无则跳过；不依赖 ffmpeg CLI）。
test "ffmpeg FFI 真机冒烟：打开/逐帧/seek" {
  let path = "/usr/share/trae/resources/app/node_modules/@byted-icube/desktop-modules/dist/media/cue.mp4"
  let d = match Demuxer::open(path) {
    Ok(d) => d
    Err(e) => {
      println("ffmpeg FFI: 素材不可用（\{e}），跳过")
      return
    }
  }
  inspect(d.stream_width() > 0, content="true")
  inspect(d.stream_height() > 0, content="true")
  inspect(d.duration_s() > 0.0, content="true")
  // 逐帧解码（最多 30 帧），帧尺寸 = w*h*4
  let fb = d.width * d.height * 4
  let mut frames = 0
  while frames < 30 {
    match d.decode_rgba() {
      Some(b) => {
        if frames == 0 {
          inspect(b.length(), content="\{fb}")
        }
        frames = frames + 1
      }
      None => break
    }
  }
  inspect(frames > 0, content="true")
  // seek 到 0.1s 再解一帧
  match d.seek(0.1) {
    Ok(_) => match d.decode_rgba() {
      Some(_) => ()
      None => fail("seek 后应能解出帧")
    }
    Err(e) => fail("seek 失败：\{e}")
  }
  d.close()
  println("ffmpeg FFI 冒烟完成（前 30 帧解码 + seek 验证，实际共 \{frames} 帧解出）")
}
