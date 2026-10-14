// showcase 量级的帧成本判据（无头，不弹窗）：同一棵大树跑两种文本形态——
//   warm：全页复用少量字符串（文本布局缓存全命中）
//   cold：每段文字都不同（字符串数量超过缓存上限，逐帧冷建）
// 再分别量「挂载+布局」与「整页重绘一帧」，用来在两个变量之间做对照：
//   ① 样式槽每帧读取（P2-e）② 文本布局缓存（323b537）。
// 跑法：moon run experiment/showcase_cost_bench

const PAGES = 14
const TEXTS_PER_PAGE = 120
const W = 1400
const H = 900

///|
/// 递归数「每帧真的会被画的控件」（有 on_draw 的），顺带数总控件数
fn count_widgets(w : @core.Widget) -> (Int, Int) {
  let mut total = 1
  let mut drawn = if w.on_draw is Some(_) { 1 } else { 0 }
  let kids = w.children()
  for i = 0; i < kids.length(); i = i + 1 {
    let (t, d) = count_widgets(kids[i])
    total += t
    drawn += d
  }
  (total, drawn)
}

///|
/// 一段典型内容：标题 + 一行控件 + 一叠文本行 + 统计块 + 提示条
fn page_of(idx : Int, label : (Int) -> String) -> @core.Node {
  let parts : Array[@core.Node] = [
    @ui.text("第 " + idx.to_string() + " 页", role=@ui.Title),
    @ui.row(
      [
        @ui.button("保存", variant=@ui.Solid),
        @ui.button("取消", variant=@ui.Border),
        @ui.input(@core.Store::new("输入框内容")),
        @ui.tag("标签", "#337ecc"),
        @ui.badge_count(idx),
      ],
      column_gap=8.0,
    ),
    @ui.divider(),
  ]
  for i = 0; i < TEXTS_PER_PAGE; i = i + 1 {
    let _ = parts.push(@ui.text(label(i), font_size=13.0, role=@ui.Secondary))
  }
  let _ = parts.push(@ui.statistic("访问量", "1,234"))
  let _ = parts.push(@ui.alert("提示", description="这一段描述用来带出提示条的画法", t=@ui.Info))
  @ui.col(parts, row_gap=4.0, padding=10.0, width=1360.0, background_color="bg_panel")
}

fn build_page(cold~ : Bool) -> @core.Node {
  // warm：12 条字符串轮转；cold：每条都带唯一编号（数量远超缓存上限）
  let label : (Int) -> String = if cold {
    fn(i : Int) -> String { "唯一文本 " + i.to_string() + "-" + (i * 7919).to_string() }
  } else {
    fn(i : Int) -> String { "复用文本 " + (i % 12).to_string() }
  }
  let pages : Array[@core.Node] = []
  for p = 0; p < PAGES; p = p + 1 {
    let _ = pages.push(page_of(p, label))
  }
  @ui.col(pages, row_gap=8.0, width=W.to_double(), height=H.to_double())
}

fn mount_and_layout(node : @core.Node) -> (@core.Widget, Int, Int, Int64) {
  let root = @core.Widget::new()
  root.set_size(W.to_double(), H.to_double())
  root.set_column()
  let t0 = @win.now_ms()
  let page = (node.mount)(root)
  root.relayout(W.to_double(), H.to_double())
  let t1 = @win.now_ms()
  let (total, drawn) = count_widgets(page)
  (page, total, drawn, t1 - t0)
}

fn paint_frames(page : @core.Widget, n : Int) -> Int64 {
  let bm = @render.Bitmap::new(W, H)
  let p = @render.Painter::new(bm)
  let t0 = @win.now_ms()
  let mut it = 0
  while it < n {
    page.paint(p)
    it += 1
  }
  let t1 = @win.now_ms()
  p.end()
  t1 - t0
}

fn main {
  let (warm_page, widgets, drawn, warm_mount) = mount_and_layout(build_page(cold=false))
  let (cold_page, _, _, cold_mount) = mount_and_layout(build_page(cold=true))
  let n = 20
  let warm_ms = paint_frames(warm_page, n)
  let cold_ms = paint_frames(cold_page, n)
  let warm_per = warm_ms.to_double() / n.to_double()
  let cold_per = cold_ms.to_double() / n.to_double()
  println(
    "SCB widgets=" + widgets.to_string() + " drawn=" + drawn.to_string() +
      " pages=" + PAGES.to_string() + " texts/page=" + TEXTS_PER_PAGE.to_string(),
  )
  println(
    "SCB-COST mount=" + warm_mount.to_string() + "/" + cold_mount.to_string() + "ms" +
      " warm=" + warm_ms.to_string() + "ms cold=" + cold_ms.to_string() + "ms /" +
      n.to_string() + "帧 ⇒ " + warm_per.to_string() + " vs " + cold_per.to_string() + " ms/帧",
  )
}
