// yoga-mbt 性能基线：千节点树反复布局的耗时测量。
//
// 树规模：根 + 20 组 ×（1 组头 + 10 行）× 每行 5 节点 = 1121 节点，
// 行用 align-items: baseline（基线分组进热路径），列组用 row-gap，
// 叶子带 measure 函数、文本带 baseline 回调。
//
// 用法（在模块目录内）：
//   ~/.moon/bin/moon run bench            # debug
//   ~/.moon/bin/moon run --release bench  # release
// 耗时由 shell 侧 `time` 采集；把 rounds 改成 0 跑一次即得「进程 +建树」
// 基线，两次差值除以轮数就是每次布局的成本。

fn leaf(w : Double, h : Double) -> @src.Node {
  let n = @src.Node::new()
  n.set_measure(fn(_a, _b) { (w, h) })
  n
}

fn text(w : Double, h : Double, b : Double) -> @src.Node {
  let n = @src.Node::new()
  n.set_measure(fn(_a, _b) { (w, h) })
  n.set_baseline(fn(_a, _b) { Some(b) })
  n
}

///|
/// 一行：图标 + 名称（可增长）+ 数值 + 徽标。
fn build_row() -> @src.Node {
  let n = @src.Node::new()
  n.set_height(@src.fixed(32.0))
  n.set_padding_left(@src.fixed(8.0))
  n.set_padding_right(@src.fixed(8.0))
  n.set_column_gap(6.0)
  n.set_align_items(@src.AlignItems::Baseline)
  n.append_child(leaf(20.0, 20.0))
  let t = text(120.0, 20.0, 15.0)
  t.set_flex_grow(1.0)
  t.set_min_width(@src.fixed(0.0))
  n.append_child(t)
  n.append_child(text(60.0, 20.0, 15.0))
  n.append_child(leaf(40.0, 18.0))
  n
}

///|
/// 建树：返回根节点与最后一行（作为读取布局结果的探针）。
fn build_tree(groups : Int, rows : Int) -> (@src.Node, @src.Node) {
  let root = @src.Node::new()
  root.set_width(@src.fixed(1280.0))
  root.set_height(@src.fixed(800.0))
  root.set_flex_direction(@src.FlexDirection::Column)
  root.set_row_gap(4.0)
  let mut probe = root
  for _gi in 0..<groups {
    let g = @src.Node::new()
    g.set_flex_direction(@src.FlexDirection::Column)
    g.set_row_gap(2.0)
    g.append_child(build_row())
    for _r in 0..<rows {
      let row = build_row()
      g.append_child(row)
      probe = row
    }
    root.append_child(g)
  }
  (root, probe)
}

fn run_layouts(root : @src.Node, probe : @src.Node, rounds : Int) -> Double {
  let mut acc = 0.0
  for _i in 0..<rounds {
    @src.calculate_layout(root, Some(1280.0), Some(800.0))
    let l = probe.layout()
    acc = acc + l.width + l.height + l.left + l.top
  }
  acc
}

fn main {
  let rounds = 500
  let (root, probe) = build_tree(20, 10)
  let acc = run_layouts(root, probe, rounds)
  println("yoga-mbt bench 完成：1121 节点 × \{rounds} 轮布局")
  if acc < 0.0 {
    println("unreachable")
  }
}
