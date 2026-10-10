// yoga-mbt 性能基线：千节点树反复布局的耗时测量。
//
// 树规模：根 + 20 组 ×（1 组头 + 10 行）× 每行 5 节点 = 1121 节点，
// 行用 align-items: baseline（基线分组进热路径），列组用 row-gap，
// 叶子带 measure 函数、文本带 baseline 回调。
//
// 三个场景对应 GUI 里真实会遇到的三种重排（口径见 adaptation「脏区增量重排」条）：
//   steady   —— 同参数重复布局（每帧 relayout，界面内容没变）
//   one_leaf —— 每轮改一个叶子的内容高（一行文本变长，只有那一条链受影响）
//   resize   —— 每轮换一个可用宽（拖窗口，全树都要重排）
//
// 用法（在模块目录内）：
//   moon run bench            # debug
//   moon run --release bench  # release
// 计时用 `moonbitlang/core/env` 的毫秒时钟（bench 是外部包，引擎本体保持零依赖）。

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
/// 建树：返回根节点与探针（第一个文字叶子、最后一行，用于读取结果防优化掉）。
fn build_tree(groups : Int, rows : Int) -> (@src.Node, @src.Node, @src.Node) {
  let root = @src.Node::new()
  root.set_width(@src.fixed(1280.0))
  root.set_height(@src.fixed(800.0))
  root.set_flex_direction(@src.FlexDirection::Column)
  root.set_row_gap(4.0)
  let mut probe = root
  let mut probe_text = root
  let mut first = true
  for _gi in 0..<groups {
    let g = @src.Node::new()
    g.set_flex_direction(@src.FlexDirection::Column)
    g.set_row_gap(2.0)
    g.append_child(build_row())
    for _r in 0..<rows {
      let row = build_row()
      g.append_child(row)
      probe = row
      if first {
        // 第一行的第二个子项（可增长的文字叶子）
        probe_text = row.children()[1]
        first = false
      }
    }
    root.append_child(g)
  }
  (root, probe, probe_text)
}

///|
/// 读一遍探针的布局结果，累成校验值（防止整轮布局被当成死代码）。
fn probe_sum(probe : @src.Node, probe_text : @src.Node) -> Double {
  let a = probe.layout()
  let b = probe_text.layout()
  a.width + a.height + a.left + a.top + b.width + b.height
}

fn report(name : String, rounds : Int, ms : UInt64, sum : Double) -> Unit {
  let per_round_us = (
    ms.to_double() * 1000.0 / (if rounds > 0 { rounds.to_double() } else { 1.0 })
  ).round().to_int()
  println(
    "\{name}：\{rounds} 轮 合计 \{ms.to_int()}ms，每轮 \{per_round_us}µs（校验值 \{sum.round().to_int()}）",
  )
}

fn main {
  let rounds = 500
  let (root, probe, probe_text) = build_tree(20, 10)

  // 建树 + 首轮全量布局（一次性成本）
  let t0 = @env.now()
  @src.calculate_layout(root, Some(1280.0), Some(800.0))
  let sum0 = probe_sum(probe, probe_text)
  let t_first = @env.now() - t0
  println("首轮全量：\{t_first.to_int()}ms（校验值 \{sum0.round().to_int()}）")

  // 场景 1：同参数重复布局
  let mut acc = 0.0
  let t1 = @env.now()
  for _i in 0..<rounds {
    @src.calculate_layout(root, Some(1280.0), Some(800.0))
    acc = acc + probe_sum(probe, probe_text)
  }
  report("steady  同参数重复", rounds, @env.now() - t1, acc)

  // 场景 2：每轮改一个叶子的内容高（18↔20 交替）
  let mut acc2 = 0.0
  let t2 = @env.now()
  for i in 0..<rounds {
    let h = if i % 2 == 0 { 20.0 } else { 22.0 }
    probe_text.set_measure(fn(_a, _b) { (120.0, h) })
    @src.calculate_layout(root, Some(1280.0), Some(800.0))
    acc2 = acc2 + probe_sum(probe, probe_text)
  }
  report("one_leaf 单点变更", rounds, @env.now() - t2, acc2)

  // 场景 3：每轮换根的显式宽（800..1399），整棵树都要重排——
  // 这就是「与今天等价」的那一档，用来量增量重排没有把全量路径拖慢
  let mut acc3 = 0.0
  let t3 = @env.now()
  for i in 0..<rounds {
    let w = (800 + (i % 600)).to_double()
    root.set_width(@src.fixed(w))
    @src.calculate_layout(root, Some(1280.0), Some(800.0))
    acc3 = acc3 + probe_sum(probe, probe_text)
  }
  report("resize  换可用宽", rounds, @env.now() - t3, acc3)
}
