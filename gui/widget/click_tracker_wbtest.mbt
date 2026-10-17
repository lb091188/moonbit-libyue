// W32 ClickTracker 双击判定无头回归。

test "单击：首次 feed_down 返回 1" {
  let t = ClickTracker::new()
  assert_eq(t.feed_down(10.0, 20.0), 1)
  assert_false(t.is_double())
}

test "双击：400ms 内同位再点返回 2" {
  let t = ClickTracker::new()
  t.last_time = @shell.now_ms() - 100L
  t.last_x = 10.0
  t.last_y = 20.0
  t.click_count = 1
  let c = t.feed_down(11.0, 21.0)
  assert_eq(c, 2)
  assert_true(t.is_double())
}

test "超距不触发双击：>4px 偏移回 1" {
  let t = ClickTracker::new()
  t.last_time = @shell.now_ms() - 50L
  t.last_x = 0.0
  t.last_y = 0.0
  t.click_count = 1
  let c = t.feed_down(10.0, 10.0)
  assert_eq(c, 1)
}
