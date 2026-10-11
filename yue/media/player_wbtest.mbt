// 播放器组件的无头回归：帧字节转换（R/B 交换 + alpha 置不透明 + 短包不越界）
// 与控制条命中分区（播放键区 / 进度轨 / 时间文字区）。真播放由 examples/native-web 回证。

///|
/// 本工具链的 Bytes 构造：FixedArray::make + 按下标写（没有 of_list/freeze）。
fn bytes_of(items : Array[Byte]) -> Bytes {
  let raw = FixedArray::make(items.length(), b'\x00')
  for i = 0; i < items.length(); i = i + 1 {
    raw[i] = items[i]
  }
  Bytes::from_array(raw)
}

///|
test "帧回灌：RGBA 进、BGRA 出、alpha 恒不透明" {
  let src = bytes_of([
    b'\x10',
    b'\x20',
    b'\x30',
    b'\x00',
    b'\xaa',
    b'\xbb',
    b'\xcc',
    b'\x80',
  ])
  let bm = rgba_to_bitmap(src, 2, 1)
  assert_eq(bm.width, 2)
  assert_eq(bm.height, 1)
  // 像素 0：源 R=0x10 G=0x20 B=0x30 → 缓冲里是 B,G,R,A
  assert_eq(bm.data[0], b'\x30')
  assert_eq(bm.data[1], b'\x20')
  assert_eq(bm.data[2], b'\x10')
  assert_eq(bm.data[3], b'\xff')
  assert_eq(bm.data[4], b'\xcc')
  assert_eq(bm.data[7], b'\xff')
}

///|
test "帧回灌：短包只填能填的、尺寸非正给空位图" {
  let short_ = bytes_of([b'\x01', b'\x02', b'\x03'])
  let bm = rgba_to_bitmap(short_, 2, 1)
  // 不足一个像素的字节不写第三像素，第一像素也没被写坏（R/B 交换后仍是 3,2,1,ff）
  assert_eq(bm.data[0], b'\x03')
  assert_eq(bm.data[1], b'\x02')
  assert_eq(bm.data[2], b'\x01')
  assert_eq(bm.data[3], b'\xff')
  let empty = rgba_to_bitmap(Bytes::new(0), 0, 0)
  assert_eq(empty.data.length(), 0)
}

///|
test "控制条分区：最左 34px 是播放键，右侧 150px 是时间文字，中间是进度轨" {
  assert_eq(player_bar_hit(10.0, 17.0, 600.0, 34.0).0, "pause")
  assert_eq(player_bar_hit(560.0, 17.0, 600.0, 34.0).0, "")
  // 负坐标落在播放键区（指针事件本来不会为负，这里钉的是「先分区再算比例」的顺序）
  assert_eq(player_bar_hit(-5.0, 17.0, 600.0, 34.0).0, "pause")
  assert_eq(player_bar_hit(42.0, 17.0, 600.0, 34.0).0, "seek")
  // 轨道起算 42px、宽 600-190=410：中点约 (42+205)
  let mid = player_bar_hit(247.0, 17.0, 600.0, 34.0)
  assert_eq(mid.0, "seek")
  assert_true(mid.1 > 0.45 && mid.1 < 0.55)
  // 轨道两端钳到 0/1（轨道起 42px、宽 410px）；右侧时间文字区不算 seek
  assert_eq(player_bar_hit(42.0, 17.0, 600.0, 34.0).1, 0.0)
  assert_true(player_bar_hit(449.0, 17.0, 600.0, 34.0).1 > 0.99)
  assert_eq(player_bar_hit(100.0, 17.0, 0.0, 34.0).0, "")
  assert_eq(player_bar_hit(100.0, 17.0, 600.0, 0.0).0, "")
}
