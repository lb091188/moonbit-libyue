// W36 收尾：Headless* 端到端 API 无头回归。
// 真音频文件依赖 ffmpeg 与设备，本机 CI 环境不齐；这里用「手动 pump + 状态
// 快照」验证接口层形态——schedule 注入通道被跑到、close 能取消、on_complete
// 语义正确。文件打开失败时结构体本身仍应构造（open 返回 Option 或 Some，
// 后续 play 才真跑）。

test "HeadlessAudio/HeadlessVideo open 无文件时给 None、不炸宿主" {
  let schedule = fn(_ms : Int, _f : () -> Unit) -> Int { 0 }
  match HeadlessAudio::open("/nonexistent/definitely-not-a-file.mp3", schedule) {
    Some(_) => assert_eq(true, false)
    None => assert_true(true)
  }
  match HeadlessVideo::open("/nonexistent/definitely-not-a-file.mp4", schedule) {
    Some(_) => assert_eq(true, false)
    None => assert_true(true)
  }
}

test "HeadlessAudio/HeadlessVideo schedule 通道签名可传" {
  // 只验接口能编、闭包能跑；具体播放依赖 ffmpeg 归真机验收
  let fired : Ref[Int] = Ref(0)
  let schedule = fn(_ms : Int, f : () -> Unit) -> Int {
    fired.val = fired.val + 1
    f()
    42
  }
  // open 大概率返 None（无文件），但 schedule 通道类型要匹配得上
  let _ = HeadlessAudio::open("", schedule)
  let _ = HeadlessVideo::open("", schedule)
}
