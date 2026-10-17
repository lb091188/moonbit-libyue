// W32 双击/多击检测：通用 ClickTracker 供 Widget 或宿主消费。
// 从 entry.mbt / textarea.mbt 内联逻辑抽出的可复用形态。
// 400ms 窗口 + 4px 距离阈值（与既有两处口径一致）。

///|
/// 双击判定器：记录上次按下时刻与坐标，按 Down 事件推 click_count。
pub(all) struct ClickTracker {
  mut last_time : Int64
  mut last_x : Double
  mut last_y : Double
  mut click_count : Int
}

///|
pub fn ClickTracker::new() -> ClickTracker {
  { last_time: 0L, last_x: 0.0, last_y: 0.0, click_count: 0, }
}

///|
/// 收到 Down 事件时调：命中双击阈值返回 2（双击），否则重置为 1（单击）。
/// 第三次快速连点返回 3（三击），依次类推。
pub fn ClickTracker::feed_down(self : ClickTracker, x : Double, y : Double) -> Int {
  let now = @shell.now_ms()
  let dt = now - self.last_time
  let dx = x - self.last_x
  let dy = y - self.last_y
  let in_radius = (if dx < 0.0 { 0.0 - dx } else { dx }) < 4.0 &&
    (if dy < 0.0 { 0.0 - dy } else { dy }) < 4.0
  if dt > 0L && dt < 400L && in_radius {
    self.click_count = self.click_count + 1
  } else {
    self.click_count = 1
  }
  self.last_time = now
  self.last_x = x
  self.last_y = y
  self.click_count
}

///|
/// 是否构成双击（click_count == 2 的瞬间返回 true，第三次返回 false 避重复触发）。
pub fn ClickTracker::is_double(self : ClickTracker) -> Bool {
  self.click_count == 2
}

///|
/// 是否构成三击。
pub fn ClickTracker::is_triple(self : ClickTracker) -> Bool {
  self.click_count == 3
}
