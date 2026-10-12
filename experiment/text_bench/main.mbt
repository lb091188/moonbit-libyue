// 文字路径的微基准（真机性能回归用，见 docs/zh/adaptation.md「W17a」条）：
// 建一次大位图，按真实布局形态（带 translate 的会话 + 盒内绘制）重复 200 次，
// 打印总毫秒与落墨数。健康值：本机（Win10 + 雅黑 13px）≈ 70-100ms / 200 次
// （单次约 0.35ms；若回落到 ms 级说明画布缓存/blit 快路径被破坏）。
// 跑法：moon run experiment/text_bench

///|
fn ink(bm : @render.Bitmap) -> Int {
  let mut n = 0
  for y = 0; y < bm.height; y = y + 1 {
    for x = 0; x < bm.width; x = x + 1 {
      if bm.pixel(x, y).a > 0 {
        n = n + 1
      }
    }
  }
  n
}

fn main {
  let bm = @render.Bitmap::new(1400, 320)
  let p = @render.Painter::new(bm)
  let f = @text.Font::new("Microsoft YaHei", 13.0)
  let t0 = @env.now()
  for i = 0; i < 200; i = i + 1 {
    p.save()
    p.translate(0.0, (i % 20).to_double() * 14.0)
    let _ = @text.draw_box_at(
      p, 0.0, 0.0, 400.0, 20.0, "样本文字 sample 123", f, "#000",
    )
    p.restore()
  }
  p.end()
  println("BENCH-200 = \{@env.now() - t0} ms ink=\{ink(bm)}")
}
