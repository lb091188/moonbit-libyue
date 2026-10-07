///|
/// 帧间隔与下一帧推进纯函数。
test "vid_frame_delay / vid_next_frame：帧步进逻辑" {
  inspect(vid_frame_delay(30), content="34")
  inspect(vid_frame_delay(1), content="1000")
  inspect(vid_frame_delay(0), content="1000")
  inspect(vid_frame_delay(-5), content="1000")
  inspect(vid_frame_delay(1000), content="1")
  inspect(vid_frame_delay(2000), content="1")
  inspect(vid_rgba_len(2, 3), content="24")
  // 非循环中段 → Some(idx+1)
  match vid_next_frame(0, 3, false) {
    Some(n) => inspect(n, content="1")
    None => fail("非循环中段不应结束")
  }
  // 非循环末帧 / 单帧 / 零帧 → None
  match vid_next_frame(2, 3, false) {
    None => ()
    Some(_) => fail("非循环末帧应结束")
  }
  match vid_next_frame(0, 1, true) {
    None => ()
    Some(_) => fail("单帧不应推进")
  }
  match vid_next_frame(0, 0, true) {
    None => ()
    Some(_) => fail("零帧不应推进")
  }
  // 循环末帧 → 回卷 0
  match vid_next_frame(2, 3, true) {
    Some(n) => inspect(n, content="0")
    None => fail("循环末帧应回卷")
  }
}

///|
/// 帧源注入：合法帧 → Some(Image)；None / 长度不符 → None。
test "vid_frame_image：帧源注入与校验" {
  let good = FixedArray::make(vid_rgba_len(2, 2), b'\x40')
  let src_ok : VideoFrameSource = fn(_i) { Some(Bytes::from_array(good)) }
  match vid_frame_image(src_ok, 0, 2, 2) {
    Some(_) => ()
    None => fail("合法帧应得 Some")
  }
  // 长度不符 → None
  let bad = FixedArray::make(5, b'\x00')
  let src_len : VideoFrameSource = fn(_i) { Some(Bytes::from_array(bad)) }
  match vid_frame_image(src_len, 0, 2, 2) {
    None => ()
    Some(_) => fail("长度不符应 None")
  }
  // 源给 None → None
  let src_none : VideoFrameSource = fn(_i) { None }
  match vid_frame_image(src_none, 0, 2, 2) {
    None => ()
    Some(_) => fail("源 None 应 None")
  }
  // 帧号透传：source 看到的 idx 与请求一致
  let seen = Ref(-1)
  let src_idx : VideoFrameSource = fn(i) {
    seen.val = i
    None
  }
  let _ = vid_frame_image(src_idx, 7, 2, 2)
  inspect(seen.val, content="7")
}

///|
/// 播放句柄：建/暂停/停止语义。
test "VidHandle：建/暂停/停止" {
  let h = VidHandle::make()
  inspect(h.is_running(), content="true")
  inspect(h.is_paused(), content="false")
  vid_pause(h)
  inspect(h.is_paused(), content="true")
  vid_resume(h)
  inspect(h.is_paused(), content="false")
  vid_stop(h)
  inspect(h.is_running(), content="false")
}
