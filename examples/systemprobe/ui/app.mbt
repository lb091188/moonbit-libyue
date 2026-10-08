// 共享层:跨页状态 ProbeApp。各页函数以 app 单参取用;
// 页内私有状态留在各页函数体内,不进 ProbeApp。

///|
/// 跨页共享状态:导航选中页、窗口句柄(文件对话框按窗口弹出)、
/// toast 回显、特效散点动画句柄(关窗停止)、视频播放器与音频引擎/
/// 剪辑句柄(关窗统一释放)。
pub(all) struct ProbeApp {
  selected : @yue.Store[String]
  win_ref : Ref[@yue.Window?]
  toast : (String, @yue.SemanticType) -> Unit
  eff_anim : @yue.EffAnim
  vid_player : Ref[@yue.VideoPlayer?]
  aud_engine : Ref[@yue.AudioEngine?]
  aud_clip : Ref[@yue.AudioClip?]
}

///|
/// 推送一条轻提示(转发 toast 函数字段;函数值字段不能直接点调用)。
pub fn ProbeApp::toast_push(
  self : ProbeApp,
  text : String,
  t : @yue.SemanticType,
) -> Unit {
  (self.toast)(text, t)
}
