// 文本层的口径回归：不断言具体像素宽（随字体配置变），只断言单调性与约束。

fn painted_count(bm : @render.Bitmap, w : Int, h : Int) -> Int {
  let mut n = 0
  for y = 0; y < h; y = y + 1 {
    for x = 0; x < w; x = x + 1 {
      if bm.pixel(x, y).a > 0 {
        n = n + 1
      }
    }
  }
  n
}

test "测量单调：文本更长更宽、字号更大更高" {
  let a = measure("Hello", 14.0)
  let b = measure("Hello World", 14.0)
  let big = measure("Hello", 28.0)
  match (a, b, big) {
    (Some(a), Some(b), Some(big)) => {
      assert_eq(b.width > a.width, true)
      assert_eq(big.width > a.width, true)
      assert_eq(big.height > a.height, true)
      assert_eq(a.baseline > 0 && a.baseline < a.height, true)
    }
    _ => assert_eq(false, true)
  }
}

test "行高随字号增长且非零" {
  let h14 = line_height(14.0)
  let h28 = line_height(28.0)
  assert_eq(h14 > 0, true)
  assert_eq(h28 > h14, true)
}

test "max_width 约束换行：宽度受钳、高度增长" {
  let one = measure("the quick brown fox jumps over the lazy dog", 14.0)
  let wrapped = measure(
    "the quick brown fox jumps over the lazy dog",
    14.0,
    max_width=80,
    wrap=true,
  )
  match (one, wrapped) {
    (Some(one), Some(wrapped)) => {
      assert_eq(one.width > 80, true)
      assert_eq(wrapped.width <= 80, true)
      assert_eq(wrapped.height > one.height, true)
    }
    _ => assert_eq(false, true)
  }
}

test "ellipsize 尾端省略不超约束" {
  match measure("the quick brown fox jumps over the lazy dog", 14.0,
    max_width=60,
    ellipsize=true,
  ) {
    Some(m) => {
      assert_eq(m.width <= 60, true)
      assert_eq(m.height > 0, true)
    }
    None => assert_eq(false, true)
  }
}

test "绘制真的往自有缓冲落像素" {
  let bm = @render.Bitmap::new(120, 30)
  let ok = draw_to(bm, 2.0, 2.0, "MoonBit", 16.0, "#ffffff")
  assert_eq(ok, true)
  assert_eq(painted_count(bm, 120, 30) > 20, true)
}

test "中文可测可画" {
  match measure("中文测试", 14.0) {
    Some(m) => assert_eq(m.width > 0 && m.height > 0, true)
    None => assert_eq(false, true)
  }
  let bm = @render.Bitmap::new(80, 24)
  assert_eq(draw_to(bm, 1.0, 1.0, "中文", 14.0, "#ff0000"), true)
  assert_eq(painted_count(bm, 80, 24) > 10, true)
}

test "空文本与空缓冲的安全边界" {
  let bm = @render.Bitmap::new(10, 10)
  assert_eq(draw_to(bm, 0.0, 0.0, "", 14.0, "#00ff00"), true)
  let empty = @render.Bitmap::new(0, 0)
  assert_eq(draw_to(empty, 0.0, 0.0, "x", 14.0, "#00ff00"), false)
  // 非法 hex 按黑色兜底，不应崩也不应空画
  let bm2 = @render.Bitmap::new(60, 20)
  assert_eq(draw_to(bm2, 1.0, 1.0, "abc", 14.0, "oops"), true)
}
