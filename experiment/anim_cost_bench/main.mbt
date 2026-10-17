// 动画前置判据探针（CPU 光栅栈下 transition 值不值得做）：
// 量三件事——① 全窗重绘一帧多少钱；② 只有小面积变化时多少钱（有没有
// 「脏矩形」这类的天然便宜可占）；③ 小面积变化单独算多少钱。
// 跑法：moon run experiment/anim_cost_bench

fn ink(bm : @render.Bitmap) -> Int {
  let mut n = 0
  let mut y = 0
  while y < bm.height {
    let mut x = 0
    while x < bm.width {
      if bm.pixel(x, y).a > 0 {
        n += 1
      }
      x += 4
    }
    y += 4
  }
  n
}

// 一屏典型内容：30 行「按钮 + 输入框 + 文本」（native-app/showcase 的密度量级）
fn build_page() -> @widget.Node {
  let rows : Array[@widget.Node] = []
  for _ in 0..<30 {
    let _ = rows.push(@ui.row(
      [
        @ui.button("保存", variant=@ui.Solid),
        @ui.input(@base.Store::new("输入框内容")),
        @ui.text("一行说明文字，用来占住交叉轴", role=@ui.Secondary),
      ],
      column_gap=8.0,
    ))
  }
  @ui.col(rows, row_gap=6.0, padding=12.0, width=1400.0, height=900.0)
}

fn main {
  let w = 1400
  let h = 900
  let bm = @render.Bitmap::new(w, h)
  let root = @widget.Widget::new()
  root.set_size(w.to_double(), h.to_double())
  root.set_column()
  let _ = (build_page().mount)(root)
  root.relayout(w.to_double(), h.to_double())
  let r0 = root.children()[0].rect
  let page = root.children()[0]
  let r1 = page.children()[0].rect
  println("DIAG rows=" + page.children().length().to_string())
  println(
    "DIAG r0w=" + r0.w.to_string() + " r0h=" + r0.h.to_string() + " r1w=" + r1.w.to_string() + " r1h=" + r1.h.to_string(),
  )
  let p = @render.Painter::new(bm)
  // ① 全窗重绘
  let t0 = @win.now_ms()
  let n = 20
  let mut it = 0
  while it < n {
    page.paint(p)
    it += 1
  }
  let full = @win.now_ms() - t0
  // ② 小面积变化：只画一颗按钮大小的圆角矩形（悬停/按压一类的局部变化下限）
  let t1 = @win.now_ms()
  it = 0
  while it < n {
    p.set_fill_color("#2D68C4")
    p.fill_round_rect(20.0, 20.0, 90.0, 32.0, 4.0)
    it += 1
  }
  let part = @win.now_ms() - t1
  // ③ 全树文本布局测量一次要多少钱（relayout 成本：动画每帧不变的话可摊掉）
  let t2 = @win.now_ms()
  it = 0
  while it < n {
    root.relayout(w.to_double(), h.to_double())
    it += 1
  }
  let layout = @win.now_ms() - t2
  println(
    "ANIM-COST \{w}x\{h} frames=\{n} full=\{full}ms(\{full / n.to_int64()}ms/帧) part_90x32=\{part}ms(\{part / n.to_int64()}ms/帧) relayout=\{layout}ms(\{layout / n.to_int64()}ms/帧) ink=\{ink(bm)}",
  )
  p.end()
}
