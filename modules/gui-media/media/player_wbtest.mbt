// 播放器组件的无头回归：帧字节转换（R/B 交换 + alpha 置不透明 + 短包不越界）
// 与控制条命中分区（播放键区 / 进度轨 / 时间文字区）。真播放由 modules/gui-examples/native-web 回证。

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
test "控制条分区：播放 / 两个逐帧键 / 倍速 / 进度轨 / 音量条 / 时间文字" {
  // w=600 时：pause<34、step_back 34..70、step_fwd 70..106、speed 106..146、
  // 轨道 154..354（宽 200）、音量 362..450（宽 80）、时间文字 >450
  assert_eq(player_bar_hit(10.0, 17.0, 600.0, 34.0).0, "pause")
  assert_eq(player_bar_hit(560.0, 17.0, 600.0, 34.0).0, "")
  // 负坐标落在播放键区（指针事件本来不会为负，这里钉的是「先分区再算比例」的顺序）
  assert_eq(player_bar_hit(-5.0, 17.0, 600.0, 34.0).0, "pause")
  assert_eq(player_bar_hit(50.0, 17.0, 600.0, 34.0).0, "step_back")
  assert_eq(player_bar_hit(90.0, 17.0, 600.0, 34.0).0, "step_fwd")
  assert_eq(player_bar_hit(120.0, 17.0, 600.0, 34.0).0, "speed")
  let mid = player_bar_hit(254.0, 17.0, 600.0, 34.0)
  assert_eq(mid.0, "seek")
  assert_true(mid.1 > 0.45 && mid.1 < 0.55)
  // 轨道两端钳到 0/1（起算 154px、宽 200px），不是越界
  assert_eq(player_bar_hit(154.0, 17.0, 600.0, 34.0).1, 0.0)
  assert_true(player_bar_hit(354.0, 17.0, 600.0, 34.0).1 > 0.99)
  // 音量条同一条判据：起 362px、宽 80px
  assert_eq(player_bar_hit(362.0, 17.0, 600.0, 34.0).0, "volume")
  assert_eq(player_bar_hit(362.0, 17.0, 600.0, 34.0).1, 0.0)
  assert_true(player_bar_hit(400.0, 17.0, 600.0, 34.0).1 > 0.45)
  assert_true(player_bar_hit(442.0, 17.0, 600.0, 34.0).1 > 0.99)
  // 窄到放不下三件时音量条整个让位（绘制与命中同判据）：w=420 时中排只剩轨道
  assert_eq(player_bar_hit(200.0, 17.0, 420.0, 34.0).0, "seek")
  assert_eq(player_bar_hit(300.0, 17.0, 420.0, 34.0).0, "")
  assert_eq(player_bar_hit(100.0, 17.0, 0.0, 34.0).0, "")
  assert_eq(player_bar_hit(100.0, 17.0, 600.0, 0.0).0, "")
}

///|
/// 倍速档位表：点一次走一档、循环回来、负下标也循环；标签短写法。
/// 档位取自表而不是就地 `+= 0.25`，所以不存在浮点漂档的问题。
test "倍速档位与标签" {
  assert_eq(player_speed_at(0), 1.0)
  assert_eq(player_speed_at(1), 1.25)
  assert_eq(player_speed_at(4), 0.75)
  assert_eq(player_speed_at(5), 1.0) // 回到起点
  assert_eq(player_speed_at(-1), 0.75) // 负下标从尾部循环
  assert_eq(vp_fmt_speed(1.0), "1x")
  assert_eq(vp_fmt_speed(2.0), "2x")
  assert_eq(vp_fmt_speed(0.75), "0.75x")
  assert_eq(vp_fmt_speed(1.75), "1.75x") // 表外的值走通用写法
}

///|
/// 倍速钳制与时钟公式：钳到 [0.25,4.0]、NaN 回 1.0；目标时刻=基准+流逝×倍速。
test "倍速钳制与目标时刻" {
  assert_eq(media_clamp_speed(1.5), 1.5)
  assert_eq(media_clamp_speed(0.1), 0.25)
  assert_eq(media_clamp_speed(9.0), 4.0)
  assert_eq(media_clamp_speed(0.0 / 0.0), 1.0)
  assert_eq(vp_target_pts(0.0, 1000L, 2.0), 2.0)
  assert_eq(vp_target_pts(1.5, 500L, 1.0), 2.0)
  assert_eq(vp_target_pts(1.0, 1000L, 0.5), 1.5)
}

///|
/// s16 重采样：2 倍速给一半样本、0.5 倍速给两倍并线性插值；
/// speed==1 / 声道非法 / 太短一律原样返回（不制造新对象）。
test "s16 重采样：样本数按 1/speed 缩、插值取中间值" {
  // 单声道 4 个样本：0, 100, 200, 300（小端 s16）
  let src = bytes_of([
      b'\x00',
      b'\x00',
      b'\x64',
      b'\x00',
      b'\xc8',
      b'\x00',
      b'\x2c',
      b'\x01',
    ])
  let fast = media_resample_s16(src, 1, 2.0)
  assert_eq(fast.length(), 4) // 2 帧
  assert_eq(media_s16_at(fast, 0), 0)
  assert_eq(media_s16_at(fast, 1), 200)
  let slow = media_resample_s16(src, 1, 0.5)
  assert_eq(slow.length(), 16) // 8 帧
  assert_eq(media_s16_at(slow, 1), 50) // 0 与 100 的中点
  assert_eq(media_s16_at(slow, 7), 300) // 末尾钳在最后一个样本
  // 原样返回的三种情形
  assert_eq(media_resample_s16(src, 1, 1.0).length(), 8)
  assert_eq(media_resample_s16(src, 0, 2.0).length(), 8)
  assert_eq(media_resample_s16(bytes_of([b'\x01']), 1, 2.0).length(), 1)
  // 双声道按帧插值，声道不串位：帧 0 = (10, 20)，帧 1 = (30, 40)
  let st = bytes_of([
      b'\x0a',
      b'\x00',
      b'\x14',
      b'\x00',
      b'\x1e',
      b'\x00',
      b'\x28',
      b'\x00',
    ])
  let half = media_resample_s16(st, 2, 2.0)
  assert_eq(half.length(), 4) // 一帧两声道
  assert_eq(media_s16_at(half, 0), 10)
  assert_eq(media_s16_at(half, 1), 20)
}
