// 布局算法测试：预期值均按 CSS Flexbox 规则手算。

///|
/// 固定内容尺寸的叶子节点。
fn leaf(w : Double, h : Double) -> Node {
  let n = Node::new()
  n.set_measure(fn(_aw, _ah) { (w, h) })
  n
}

///|
test "固定尺寸子项" {
  let root = Node::new()
  root.set_width(fixed(800.0))
  root.set_height(fixed(600.0))
  let c = leaf(300.0, 200.0)
  root.append_child(c)
  calculate_layout(root, Some(800.0), Some(600.0))
  assert_eq(c.layout().left, 0.0)
  assert_eq(c.layout().top, 0.0)
  assert_eq(c.layout().width, 300.0)
  // align-items 默认 stretch + 容器交叉轴确定 → 撑满 600
  assert_eq(c.layout().height, 600.0)
}

///|
test "grow 均分剩余空间 + 交叉轴拉伸" {
  let root = Node::new()
  root.set_width(fixed(500.0))
  root.set_height(fixed(200.0))
  let c1 = leaf(100.0, 50.0)
  c1.set_flex_grow(1.0)
  let c2 = leaf(200.0, 50.0)
  c2.set_flex_grow(1.0)
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(500.0), Some(200.0))
  assert_eq(c1.layout().width, 200.0)
  assert_eq(c2.layout().width, 300.0)
  assert_eq(c2.layout().left, 200.0)
  assert_eq(c1.layout().height, 200.0)
}

///|
test "shrink 按基准加权收缩" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  let c1 = leaf(200.0, 50.0)
  let c2 = leaf(200.0, 50.0)
  // min-width:auto 会以内容尺寸为收缩下限，这里显式放开
  c1.set_min_width(fixed(0.0))
  c2.set_min_width(fixed(0.0))
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c1.layout().width, 150.0)
  assert_eq(c2.layout().width, 150.0)
  assert_eq(c2.layout().left, 150.0)
}

///|
test "justify 与 align 居中" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(200.0))
  root.set_justify_content(Center)
  root.set_align_items(Center)
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(200.0))
  assert_eq(c.layout().left, 150.0)
  assert_eq(c.layout().top, 75.0)
}

///|
test "百分比尺寸" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(200.0))
  let c = leaf(0.0, 0.0)
  c.set_width(percent(50.0))
  c.set_height(percent(25.0))
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(200.0))
  assert_eq(c.layout().width, 200.0)
  assert_eq(c.layout().height, 50.0)
}

///|
test "wrap 换行 + align-content stretch" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  root.set_flex_wrap(Wrap)
  let c1 = leaf(200.0, 50.0)
  let c2 = leaf(200.0, 50.0)
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(c1.layout().top, 0.0)
  assert_eq(c1.layout().height, 100.0)
  assert_eq(c2.layout().top, 100.0)
  assert_eq(c2.layout().height, 100.0)
  assert_eq(c2.layout().left, 0.0)
}

///|
test "margin auto 吸收主轴剩余空间" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(100.0))
  let c = leaf(100.0, 50.0)
  c.set_margin_left(auto())
  c.set_margin_right(auto())
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(100.0))
  assert_eq(c.layout().left, 150.0)
}

///|
test "padding 偏移子项" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_padding_left(fixed(10.0))
  root.set_padding_top(fixed(10.0))
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c.layout().left, 10.0)
  assert_eq(c.layout().top, 10.0)
}

///|
test "主轴 min:auto 内容下限阻止收缩" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(50.0))
  let c = leaf(200.0, 20.0)
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(50.0))
  assert_eq(c.layout().width, 200.0)
  assert_eq(c.layout().height, 50.0)
}

///|
test "显式 min-width 0 允许收缩到内容以下" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(50.0))
  let c = leaf(200.0, 20.0)
  c.set_min_width(fixed(0.0))
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(50.0))
  assert_eq(c.layout().width, 100.0)
}

///|
test "列间距 gap" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(50.0))
  root.set_column_gap(10.0)
  let c1 = leaf(100.0, 20.0)
  let c2 = leaf(100.0, 20.0)
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(400.0), Some(50.0))
  assert_eq(c2.layout().left, 110.0)
}

///|
test "column 方向 + 交叉轴拉伸" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(400.0))
  root.set_flex_direction(Column)
  let c1 = leaf(50.0, 100.0)
  let c2 = leaf(50.0, 100.0)
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(200.0), Some(400.0))
  assert_eq(c1.layout().top, 0.0)
  assert_eq(c2.layout().top, 100.0)
  assert_eq(c1.layout().width, 200.0)
  assert_eq(c1.layout().height, 100.0)
}

///|
test "嵌套容器作为 flex 项（内容推算高度）" {
  let root = Node::new()
  root.set_width(fixed(600.0))
  root.set_height(fixed(200.0))
  let a = leaf(100.0, 100.0)
  let b = Node::new()
  b.set_width(fixed(200.0))
  b.set_flex_direction(Column)
  let b1 = leaf(50.0, 50.0)
  let b2 = leaf(50.0, 50.0)
  b.append_child(b1)
  b.append_child(b2)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(600.0), Some(200.0))
  assert_eq(b.layout().left, 100.0)
  assert_eq(b.layout().width, 200.0)
  // b 高度 auto，随父容器 align-items:stretch 撑满行交叉尺寸 200
  assert_eq(b.layout().height, 200.0)
  assert_eq(b1.layout().top, 0.0)
  assert_eq(b1.layout().width, 200.0)
  assert_eq(b2.layout().top, 50.0)
}

///|
test "justify-content: space-between" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(100.0))
  root.set_justify_content(SpaceBetween)
  let c1 = leaf(100.0, 50.0)
  let c2 = leaf(100.0, 50.0)
  let c3 = leaf(100.0, 50.0)
  root.append_child(c1)
  root.append_child(c2)
  root.append_child(c3)
  calculate_layout(root, Some(400.0), Some(100.0))
  assert_eq(c1.layout().left, 0.0)
  assert_eq(c2.layout().left, 150.0)
  assert_eq(c3.layout().left, 300.0)
}

///|
test "row-reverse 主轴起端在右" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(100.0))
  root.set_flex_direction(RowReverse)
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(100.0))
  assert_eq(c.layout().left, 300.0)
}

///|
test "根节点按内容取尺寸" {
  let root = Node::new()
  let c = leaf(120.0, 80.0)
  root.append_child(c)
  calculate_layout(root, None, None)
  assert_eq(root.layout().width, 120.0)
  assert_eq(root.layout().height, 80.0)
}

///|
test "max-width 收顶" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(100.0))
  let c = leaf(100.0, 50.0)
  c.set_flex_grow(1.0)
  c.set_max_width(fixed(250.0))
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(100.0))
  assert_eq(c.layout().width, 250.0)
}

///|
test "shrink 不低于 min-width 且负溢出" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(50.0))
  let c1 = leaf(150.0, 30.0)
  c1.set_min_width(fixed(120.0))
  let c2 = leaf(150.0, 30.0)
  c2.set_min_width(fixed(0.0))
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(200.0), Some(50.0))
  // 溢出 100：scaled = 150 + 150 = 300，c2 分摊 100*150/300 = 50 → 100
  // c1 同样分到 100 → 50 < min 120 → 冻结 120，重算：c2 再收缩 20 → 80
  assert_eq(c1.layout().width, 120.0)
  assert_eq(c2.layout().width, 80.0)
}

///|
test "align-self 覆盖 align-items" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(200.0))
  root.set_align_items(FlexEnd)
  let c = leaf(100.0, 50.0)
  c.set_align_self(Some(Center))
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(200.0))
  assert_eq(c.layout().top, 75.0)
}

// ---- 绝对定位（YG2a）----

///|
test "absolute 脱离文档流且按 left/top 定位" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  let a = leaf(100.0, 50.0)
  let b = leaf(40.0, 40.0)
  b.set_position(Absolute)
  b.set_left(fixed(20.0))
  b.set_top(fixed(30.0))
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  // 流内项不受同层绝对定位项影响
  assert_eq(a.layout().left, 0.0)
  assert_eq(a.layout().width, 100.0)
  assert_eq(b.layout().left, 20.0)
  assert_eq(b.layout().top, 30.0)
  assert_eq(b.layout().width, 40.0)
  assert_eq(b.layout().height, 40.0)
}

///|
test "absolute 同轴两侧 inset 撑出尺寸" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_left(fixed(10.0))
  b.set_right(fixed(10.0))
  b.set_height(fixed(20.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(b.layout().width, 280.0)
  assert_eq(b.layout().left, 10.0)
  // top/bottom 全 auto → 静态位置（align-items 默认 stretch → 偏移 0）
  assert_eq(b.layout().top, 0.0)
}

///|
test "absolute 四向全 auto 落静态位置（居中）" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  root.set_justify_content(Center)
  root.set_align_items(Center)
  let b = leaf(40.0, 40.0)
  b.set_position(Absolute)
  b.set_width(fixed(40.0))
  b.set_height(fixed(40.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(b.layout().left, 130.0)
  assert_eq(b.layout().top, 80.0)
}

///|
test "absolute right/bottom 定位" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_width(fixed(40.0))
  b.set_height(fixed(40.0))
  b.set_right(fixed(10.0))
  b.set_bottom(fixed(20.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(b.layout().left, 250.0)
  assert_eq(b.layout().top, 140.0)
}

///|
test "absolute 不撑开容器内容尺寸" {
  let root = Node::new()
  let b = leaf(100.0, 100.0)
  b.set_position(Absolute)
  b.set_left(fixed(5.0))
  b.set_top(fixed(5.0))
  root.append_child(b)
  calculate_layout(root, None, None)
  assert_eq(root.layout().width, 0.0)
  assert_eq(root.layout().height, 0.0)
  assert_eq(b.layout().left, 5.0)
  assert_eq(b.layout().top, 5.0)
  assert_eq(b.layout().width, 100.0)
}

///|
test "absolute 子项内部继续递归布局" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(300.0))
  let b = Node::new()
  b.set_position(Absolute)
  b.set_left(fixed(20.0))
  b.set_top(fixed(10.0))
  b.set_width(fixed(200.0))
  b.set_height(fixed(100.0))
  b.set_flex_direction(Column)
  let b1 = leaf(50.0, 40.0)
  let b2 = leaf(50.0, 40.0)
  b.append_child(b1)
  b.append_child(b2)
  root.append_child(b)
  calculate_layout(root, Some(400.0), Some(300.0))
  assert_eq(b.layout().left, 20.0)
  assert_eq(b.layout().top, 10.0)
  assert_eq(b1.layout().top, 0.0)
  assert_eq(b1.layout().width, 200.0)
  assert_eq(b2.layout().top, 40.0)
}

///|
test "absolute 百分比 inset 相对 padding box" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(200.0))
  root.set_padding_left(fixed(50.0))
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_width(fixed(20.0))
  b.set_height(fixed(20.0))
  b.set_left(percent(50.0))
  root.append_child(b)
  calculate_layout(root, Some(400.0), Some(200.0))
  // padding box 宽 = 400（无 border，padding 含在 padding box 内）
  assert_eq(b.layout().left, 200.0)
}

// ---- 交叉轴 margin 定位 ----

///|
test "交叉轴 margin 参与定位与拉伸" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  let c = leaf(100.0, 20.0)
  c.set_margin_top(fixed(30.0))
  c.set_margin_bottom(fixed(10.0))
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  // margin box 起端贴行首 → 边框盒下移 30；stretch 高度 = 100 - 30 - 10
  assert_eq(c.layout().top, 30.0)
  assert_eq(c.layout().height, 60.0)
}

///|
test "交叉轴 margin 与 flex-end 对齐" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  root.set_align_items(FlexEnd)
  let c = leaf(100.0, 50.0)
  c.set_margin_top(fixed(20.0))
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(200.0))
  // 外沿尺寸 70 → 剩余 130 给 flex-end → margin box 起端 130，边框盒再 +20
  assert_eq(c.layout().top, 150.0)
  assert_eq(c.layout().height, 50.0)
}

// ---- 基线对齐（YG2b）----

///|
/// 固定内容尺寸 + 基线的叶子（基线到内容盒顶部）。
fn text(w : Double, h : Double, b : Double) -> Node {
  let n = Node::new()
  n.set_measure(fn(_aw, _ah) { (w, h) })
  n.set_baseline(fn(_aw, _ah) { Some(b) })
  n
}

///|
test "两项按基线对齐" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(Baseline)
  let a = text(100.0, 20.0, 10.0)
  let b = text(100.0, 40.0, 30.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(100.0))
  // 升距最大者（b=30）贴行交叉起端，a 下移到同一基线：30 - 10
  assert_eq(b.layout().top, 0.0)
  assert_eq(a.layout().top, 20.0)
  assert_eq(a.layout().height, 20.0)
  assert_eq(b.layout().height, 40.0)
  assert_eq(root.layout().height, 100.0)
}

///|
test "基线决定行交叉尺寸（容器交叉轴不定）" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_align_items(Baseline)
  let a = text(60.0, 30.0, 5.0)
  let b = text(60.0, 30.0, 25.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), None)
  // maxAscent 25 + maxDescent 25 = 50 > 单项最大外沿 30
  assert_eq(root.layout().height, 50.0)
  assert_eq(a.layout().top, 20.0)
  assert_eq(b.layout().top, 0.0)
}

///|
test "stretch 项不参与基线分组" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(Baseline)
  let a = text(100.0, 30.0, 10.0)
  let c = text(100.0, 30.0, 30.0)
  c.set_align_self(Some(Stretch))
  root.append_child(a)
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  // 分组只收 align-self: baseline 的项 → 共同基线仍为 a 的 10
  assert_eq(a.layout().top, 0.0)
  assert_eq(a.layout().height, 30.0)
  assert_eq(c.layout().top, 0.0)
  assert_eq(c.layout().height, 100.0)
}

///|
test "无基线项按 flex-start 摆放" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(Baseline)
  let a = text(100.0, 30.0, 30.0)
  let c = leaf(100.0, 40.0)
  root.append_child(a)
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  // c 无基线 → 不计入升距/降距，自身按交叉轴起端摆放
  assert_eq(a.layout().top, 0.0)
  assert_eq(c.layout().top, 0.0)
  assert_eq(c.layout().height, 40.0)
}

///|
test "margin-top 计入基线升距" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(Baseline)
  let a = text(100.0, 20.0, 10.0)
  a.set_margin_top(fixed(30.0))
  let b = text(100.0, 20.0, 5.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(100.0))
  // 升距按外沿（含 margin）算：a=40 最大 → 基线在 40，b 下移到 35
  assert_eq(a.layout().top, 30.0)
  assert_eq(b.layout().top, 35.0)
}

///|
test "多行时基线只在行内生效" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  root.set_flex_wrap(Wrap)
  root.set_align_items(Baseline)
  let a = text(120.0, 20.0, 10.0)
  let b = text(120.0, 20.0, 15.0)
  let c = text(120.0, 20.0, 5.0)
  root.append_child(a)
  root.append_child(b)
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(200.0))
  // 第一行基线尺寸 15+10=25，第二行 20；align-content: stretch 各补 77.5
  assert_eq(a.layout().top, 5.0)
  assert_eq(b.layout().top, 0.0)
  assert_eq(c.layout().top, 102.5)
  assert_eq(root.layout().height, 200.0)
}

///|
test "嵌套容器基线上抛给父容器" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(Baseline)
  let a = text(100.0, 20.0, 10.0)
  let b = Node::new()
  b.set_width(fixed(100.0))
  b.set_padding_top(fixed(5.0))
  b.set_flex_direction(Column)
  let t = text(80.0, 30.0, 20.0)
  b.append_child(t)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(100.0))
  // b 的基线 = padding-top 5 + 首项基线 20 = 25，比 a 的 10 大 → 共同基线 25
  assert_eq(b.layout().top, 0.0)
  assert_eq(a.layout().top, 15.0)
  assert_eq(b.layout().height, 35.0)
  assert_eq(t.layout().top, 5.0)
  assert_eq(t.layout().width, 100.0)
}

// ---- 容器 auto 尺寸与自身 padding/border（YG2b′）----

///|
test "行容器 auto 尺寸含自身 padding" {
  let root = Node::new()
  root.set_padding_left(fixed(10.0))
  root.set_padding_top(fixed(10.0))
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, None, None)
  assert_eq(root.layout().width, 110.0)
  assert_eq(root.layout().height, 60.0)
  assert_eq(c.layout().left, 10.0)
  assert_eq(c.layout().top, 10.0)
  assert_eq(c.layout().width, 100.0)
  assert_eq(c.layout().height, 50.0)
}

///|
test "列容器 auto 尺寸含自身 padding" {
  let root = Node::new()
  root.set_padding_left(fixed(10.0))
  root.set_padding_top(fixed(10.0))
  root.set_flex_direction(Column)
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, None, None)
  assert_eq(root.layout().width, 110.0)
  assert_eq(root.layout().height, 60.0)
  assert_eq(c.layout().left, 10.0)
  assert_eq(c.layout().top, 10.0)
  assert_eq(c.layout().width, 100.0)
}

///|
test "容器 auto 尺寸含自身 border" {
  let root = Node::new()
  root.set_border_left(fixed(7.0))
  root.set_border_top(fixed(3.0))
  let c = leaf(40.0, 20.0)
  root.append_child(c)
  calculate_layout(root, None, None)
  assert_eq(root.layout().width, 47.0)
  assert_eq(root.layout().height, 23.0)
  assert_eq(c.layout().left, 7.0)
  assert_eq(c.layout().top, 3.0)
}

///|
test "折行容器 auto 尺寸:主轴取最宽行、交叉轴累加行高" {
  let root = Node::new()
  root.set_padding_left(fixed(10.0))
  root.set_padding_top(fixed(10.0))
  root.set_flex_wrap(Wrap)
  let x = leaf(80.0, 20.0)
  let y = leaf(80.0, 20.0)
  root.append_child(x)
  root.append_child(y)
  // 可用宽 100 − padding-left 10 = 90，两项各 80 → 只能一行一项
  calculate_layout(root, Some(100.0), None)
  assert_eq(root.layout().width, 90.0)
  assert_eq(root.layout().height, 50.0)
  assert_eq(x.layout().top, 10.0)
  assert_eq(y.layout().top, 30.0)
}

// ---- aspect-ratio（YG2c，比例语义为 border-box）----

///|
test "宽确定时按比例推高" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(FlexStart)
  let c = Node::new()
  c.set_measure(fn(_aw, _ah) { (0.0, 0.0) })
  c.set_width(fixed(100.0))
  c.set_aspect_ratio(Some(2.0))
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c.layout().width, 100.0)
  assert_eq(c.layout().height, 50.0)
}

///|
test "高确定时按比例推宽" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(FlexStart)
  let c = Node::new()
  c.set_measure(fn(_aw, _ah) { (200.0, 20.0) })
  c.set_height(fixed(40.0))
  c.set_aspect_ratio(Some(2.0))
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c.layout().width, 80.0)
  assert_eq(c.layout().height, 40.0)
}

///|
test "列容器按主轴高度推交叉轴宽度" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(300.0))
  root.set_flex_direction(Column)
  root.set_align_items(FlexStart)
  let c = Node::new()
  c.set_measure(fn(_aw, _ah) { (10.0, 10.0) })
  c.set_height(fixed(60.0))
  c.set_aspect_ratio(Some(2.0))
  root.append_child(c)
  calculate_layout(root, Some(200.0), Some(300.0))
  assert_eq(c.layout().height, 60.0)
  assert_eq(c.layout().width, 120.0)
}

///|
test "容器自身按比例定尺寸" {
  let root = Node::new()
  root.set_width(fixed(320.0))
  root.set_aspect_ratio(Some(2.0))
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, Some(320.0), None)
  // 高 = 320 / 2，压过内容推算的 50
  assert_eq(root.layout().width, 320.0)
  assert_eq(root.layout().height, 160.0)
  // 子项无比例，交叉轴仍按默认 stretch 撑满
  assert_eq(c.layout().height, 160.0)
}

///|
test "stretch 优先于比例换算的交叉尺寸" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  let c = Node::new()
  c.set_measure(fn(_aw, _ah) { (0.0, 0.0) })
  c.set_width(fixed(100.0))
  c.set_aspect_ratio(Some(2.0))
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  // 规范 §9.4 尾注：stretch 决定 used 交叉尺寸且不回灌主轴;
  // 要保持比例需给 align-items / align-self 非 stretch 值
  assert_eq(c.layout().height, 100.0)
  c.set_align_self(Some(FlexStart))
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c.layout().height, 50.0)
}

///|
test "比例换算值给自动最小尺寸封顶" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(100.0))
  root.set_align_items(FlexStart)
  let c = Node::new()
  c.set_measure(fn(_aw, _ah) { (200.0, 20.0) })
  c.set_height(fixed(10.0))
  c.set_aspect_ratio(Some(2.0))
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(100.0))
  // 基准 = 10 × 2 = 20；min:auto 取内容(200)与换算值(20)的较小者
  assert_eq(c.layout().width, 20.0)
  assert_eq(c.layout().height, 10.0)
}

///|
test "非正比例视同未设置" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(FlexStart)
  let c = leaf(50.0, 30.0)
  c.set_aspect_ratio(Some(0.0))
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c.layout().width, 50.0)
  assert_eq(c.layout().height, 30.0)
}

///|
test "column 容器不做基线对齐" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(300.0))
  root.set_flex_direction(Column)
  root.set_align_items(Baseline)
  let a = text(100.0, 30.0, 10.0)
  let b = text(100.0, 30.0, 20.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(200.0), Some(300.0))
  // 主轴为列时项的 inline 轴不平行于主轴 → 按起端顺序排列，交叉轴不拉伸
  assert_eq(a.layout().top, 0.0)
  assert_eq(b.layout().top, 30.0)
  assert_eq(a.layout().width, 100.0)
  assert_eq(a.layout().height, 30.0)
}

// ---- 翻转定位参照（LTR 快照，YG2d 顺带修的既有缺陷）----

///|
test "row-reverse 容器 auto 主轴尺寸时子项无负偏移" {
  let root = Node::new()
  root.set_flex_direction(RowReverse)
  let a = leaf(100.0, 50.0)
  let b = leaf(100.0, 50.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, None, None)
  // 参照取内容推算的行主轴尺寸 200（此前当成 0 → 子项偏移 -100 / -200）
  assert_eq(a.layout().left, 100.0)
  assert_eq(b.layout().left, 0.0)
  assert_eq(root.layout().width, 200.0)
}

///|
test "列容器交叉轴 margin 左参与定位" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(300.0))
  root.set_flex_direction(Column)
  root.set_align_items(FlexStart)
  let c = leaf(100.0, 50.0)
  c.set_margin_left(fixed(20.0))
  root.append_child(c)
  calculate_layout(root, Some(200.0), Some(300.0))
  assert_eq(c.layout().left, 20.0)
  assert_eq(c.layout().top, 0.0)
}

///|
test "column-reverse 的绝对定位静态位置落主轴末端" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  root.set_flex_direction(ColumnReverse)
  root.set_align_items(FlexStart)
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_width(fixed(40.0))
  b.set_height(fixed(40.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  // 主轴起端在下方 → 双 auto 的静态位置贴底
  assert_eq(b.layout().top, 160.0)
  assert_eq(b.layout().left, 0.0)
}

// ---- RTL（YG2d）----

///|
test "rtl 行容器项从右向左排" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_direction(Rtl)
  root.set_align_items(FlexStart)
  let a = leaf(100.0, 50.0)
  let b = leaf(100.0, 50.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(a.layout().left, 200.0)
  assert_eq(b.layout().left, 100.0)
}

///|
test "rtl 与 row-reverse 叠加回到左起端" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_flex_direction(RowReverse)
  root.set_direction(Rtl)
  root.set_align_items(FlexStart)
  let a = leaf(100.0, 50.0)
  let b = leaf(100.0, 50.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(a.layout().left, 0.0)
  assert_eq(b.layout().left, 100.0)
}

///|
test "rtl 列容器交叉轴起端在右" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(300.0))
  root.set_flex_direction(Column)
  root.set_direction(Rtl)
  root.set_align_items(FlexStart)
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, Some(200.0), Some(300.0))
  assert_eq(c.layout().left, 100.0)
  assert_eq(c.layout().top, 0.0)
}

///|
test "rtl 列容器交叉轴起端取右边距" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(300.0))
  root.set_flex_direction(Column)
  root.set_direction(Rtl)
  root.set_align_items(FlexStart)
  let c = leaf(100.0, 50.0)
  c.set_margin_right(fixed(20.0))
  root.append_child(c)
  calculate_layout(root, Some(200.0), Some(300.0))
  // 交叉轴起端在右,margin-right 是起端 margin → 项自右边缘内缩 20
  assert_eq(c.layout().left, 80.0)
}

///|
test "rtl 行容器 justify flex-end 落到物理左端" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_direction(Rtl)
  root.set_justify_content(FlexEnd)
  root.set_align_items(FlexStart)
  let a = leaf(100.0, 50.0)
  root.append_child(a)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(a.layout().left, 0.0)
}

///|
test "rtl 下 margin 左右仍按物理边参与主轴" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_direction(Rtl)
  root.set_align_items(FlexStart)
  let a = leaf(100.0, 50.0)
  a.set_margin_left(fixed(20.0))
  let b = leaf(100.0, 50.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(100.0))
  // rtl 主轴起端在右:a 贴右边缘,margin-left 是主轴末端 → 落在 a 左侧
  assert_eq(a.layout().left, 200.0)
  assert_eq(b.layout().left, 80.0)
}

///|
test "rtl 行容器 margin auto 吸收剩余空间" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_direction(Rtl)
  root.set_align_items(FlexStart)
  let a = leaf(100.0, 50.0)
  a.set_margin_left(auto())
  root.append_child(a)
  calculate_layout(root, Some(300.0), Some(100.0))
  // margin-left 在 rtl 行容器里是主轴末端 margin → 剩余空间给左侧,项贴右端
  assert_eq(a.layout().left, 200.0)
}

///|
test "rtl 绝对定位四向全 auto 静态位置靠右" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  root.set_direction(Rtl)
  root.set_align_items(FlexStart)
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_width(fixed(40.0))
  b.set_height(fixed(40.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(b.layout().left, 260.0)
  assert_eq(b.layout().top, 0.0)
}

///|
test "rtl 列容器绝对定位静态交叉位置在右" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  root.set_flex_direction(Column)
  root.set_direction(Rtl)
  root.set_align_items(FlexStart)
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_width(fixed(40.0))
  b.set_height(fixed(40.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(b.layout().left, 260.0)
  assert_eq(b.layout().top, 0.0)
}

///|
test "rtl 列容器折行:首行靠右、次行在其左" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(300.0))
  root.set_flex_direction(Column)
  root.set_flex_wrap(Wrap)
  root.set_direction(Rtl)
  let a = leaf(100.0, 80.0)
  let b = leaf(100.0, 80.0)
  let c = leaf(100.0, 80.0)
  let d = leaf(100.0, 80.0)
  root.append_child(a)
  root.append_child(b)
  root.append_child(c)
  root.append_child(d)
  calculate_layout(root, Some(200.0), Some(300.0))
  // 高 300 装三行(3×80=240,第四个折到第二列);主轴不受 direction 影响,
  // 交叉轴起端在右 → 第一列 left=100,第二列 left=0
  assert_eq(a.layout().left, 100.0)
  assert_eq(a.layout().top, 0.0)
  assert_eq(c.layout().left, 100.0)
  assert_eq(c.layout().top, 160.0)
  assert_eq(d.layout().left, 0.0)
  assert_eq(d.layout().top, 0.0)
}

// ---- 绝对定位子项的 aspect-ratio（YG2e）----

///|
test "绝对定位项由宽按比例推高" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_left(fixed(20.0))
  b.set_top(fixed(10.0))
  b.set_width(fixed(100.0))
  b.set_aspect_ratio(Some(2.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(b.layout().width, 100.0)
  assert_eq(b.layout().height, 50.0)
  assert_eq(b.layout().left, 20.0)
  assert_eq(b.layout().top, 10.0)
}

///|
test "绝对定位项由高按比例推宽" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_top(fixed(30.0))
  b.set_height(fixed(40.0))
  b.set_aspect_ratio(Some(2.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  // 左右 inset 全 auto → 横向落静态位置
  assert_eq(b.layout().width, 80.0)
  assert_eq(b.layout().height, 40.0)
  assert_eq(b.layout().left, 0.0)
  assert_eq(b.layout().top, 30.0)
}

///|
test "绝对定位项两侧 inset 撑出宽后按比例推高" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  let b = leaf(0.0, 0.0)
  b.set_position(Absolute)
  b.set_left(fixed(10.0))
  b.set_right(fixed(10.0))
  b.set_top(fixed(20.0))
  b.set_aspect_ratio(Some(4.0))
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(b.layout().width, 280.0)
  assert_eq(b.layout().height, 70.0)
  assert_eq(b.layout().left, 10.0)
}

// ---- 测量缓存失效（YG3b）----

///|
test "改样式后重新布局不使用旧测量缓存" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(FlexStart)
  let c = leaf(100.0, 50.0)
  c.set_padding_left(fixed(10.0))
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c.layout().width, 110.0)
  // 同键 (可用宽, 可用高) 下样式变了 → 入口清缓存后必须重新测量
  c.set_padding_left(fixed(50.0))
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c.layout().width, 150.0)
  assert_eq(c.layout().left, 0.0)
}

///|
test "改基线后重新布局不使用旧缓存" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_align_items(Baseline)
  let a = text(100.0, 20.0, 5.0)
  let b = text(100.0, 20.0, 10.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(100.0))
  // 共同基线 = max(5, 10) = 10 → a 下移 5
  assert_eq(a.layout().top, 5.0)
  assert_eq(b.layout().top, 0.0)
  b.set_baseline(fn(_aw, _ah) { Some(18.0) })
  calculate_layout(root, Some(300.0), Some(100.0))
  // 基线改到 18 → 共同基线 18,a 下移 13
  assert_eq(a.layout().top, 13.0)
  assert_eq(b.layout().top, 0.0)
}

// ---- 像素网格取整（YG3c）----

///|
/// 三个等分主轴的容器（每份 100/3，天生带小数），根宽 100。
fn three_grow() -> (Node, Node, Node, Node) {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(50.0))
  let a = leaf(0.0, 0.0)
  let b = leaf(0.0, 0.0)
  let c = leaf(0.0, 0.0)
  a.set_flex(1.0, 1.0, fixed(0.0))
  b.set_flex(1.0, 1.0, fixed(0.0))
  c.set_flex(1.0, 1.0, fixed(0.0))
  root.append_child(a)
  root.append_child(b)
  root.append_child(c)
  (root, a, b, c)
}

///|
test "整像素网格:等分边取整后无 1px 缝" {
  let (root, a, b, c) = three_grow()
  root.set_pixel_grid(1.0)
  calculate_layout(root, Some(100.0), Some(50.0))
  // 原始边 0 / 33.33 / 66.67 / 100 → 取整 0 / 33 / 67 / 100
  assert_eq(a.layout().left, 0.0)
  assert_eq(a.layout().width, 33.0)
  assert_eq(b.layout().left, 33.0)
  assert_eq(b.layout().width, 34.0)
  assert_eq(c.layout().left, 67.0)
  assert_eq(c.layout().width, 33.0)
  assert_eq(root.layout().width, 100.0)
}

///|
test "半像素网格取整" {
  let (root, a, b, c) = three_grow()
  root.set_pixel_grid(0.5)
  calculate_layout(root, Some(100.0), Some(50.0))
  assert_eq(a.layout().width, 33.5)
  assert_eq(b.layout().left, 33.5)
  assert_eq(b.layout().width, 33.0)
  assert_eq(c.layout().left, 66.5)
  assert_eq(c.layout().width, 33.5)
}

///|
test "不设网格时保留小数值" {
  let (root, _a, b, _c) = three_grow()
  calculate_layout(root, Some(100.0), Some(50.0))
  assert_eq(b.layout().left, 100.0 / 3.0)
  assert_eq(b.layout().width, 100.0 / 3.0)
}

///|
test "嵌套项取整按绝对坐标补偿" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(50.0))
  root.set_pixel_grid(1.0)
  let mut mid : Node = Node::new()
  let mut inner : Array[Node] = []
  for i in 0..<3 {
    let g = Node::new()
    g.set_flex(1.0, 1.0, fixed(0.0))
    let x = leaf(0.0, 0.0)
    let y = leaf(0.0, 0.0)
    x.set_flex(1.0, 1.0, fixed(0.0))
    y.set_flex(1.0, 1.0, fixed(0.0))
    g.append_child(x)
    g.append_child(y)
    if i == 1 {
      mid = g
      inner = [x, y]
    }
    root.append_child(g)
  }
  calculate_layout(root, Some(100.0), Some(50.0))
  // 中间容器绝对边 33.33 / 66.67 → 取整 33 / 67(宽 34)
  assert_eq(mid.layout().left, 33.0)
  assert_eq(mid.layout().width, 34.0)
  // 内部两项绝对边 33.33 / 50 / 66.67 → 取整 33 / 50 / 67,相对父项 0 / 17
  assert_eq(inner[0].layout().left, 0.0)
  assert_eq(inner[0].layout().width, 17.0)
  assert_eq(inner[1].layout().left, 17.0)
  assert_eq(inner[1].layout().width, 17.0)
}

///|
/// 文本叶子（按词折行模拟）：`words` 为各词宽，行高 `line_h`。
/// 可用宽 `None` → 不折行（max-content 探询）；`Some(w)` → 按词依次装行，
/// 宽取最宽一行（词不拆分，故 `Some(0.0)` 即最长词宽 = min-content 探询），
/// 高为行数 × 行高。
fn text_wrap(words : Array[Double], line_h : Double) -> Node {
  let n = Node::new()
  n.set_measure(fn(avail_w, _avail_h) {
    match avail_w {
      None => (
        words.iter().fold(init=0.0, fn(a, v) { a + v }),
        line_h,
      )
      Some(av) => {
        let mut line_w = 0.0
        let mut max_w = 0.0
        let mut lines = 1
        for w0 in words {
          if line_w > 0.0 && line_w + w0 > av {
            lines = lines + 1
            line_w = w0
          } else {
            line_w = line_w + w0
          }
          if line_w > max_w {
            max_w = line_w
          }
        }
        (max_w, lines.to_double() * line_h)
      }
    }
  })
  n
}

///|
test "内在尺寸:width: max-content 不被可用空间压窄" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(200.0))
  root.set_align_items(FlexStart)
  let c = text_wrap([70.0, 60.0, 30.0], 20.0)
  c.set_width(max_content())
  // 参与收缩的话基准会被 §9.7 压回可用空间，这里只验尺寸解析
  c.set_flex_shrink(0.0)
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(200.0))
  // 词宽合计 160（不折行），超出可用 100 也不压窄
  assert_eq(c.layout().width, 160.0)
  assert_eq(c.layout().height, 20.0)
}

///|
test "内在尺寸:width: min-content 等于最长词宽" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(200.0))
  root.set_align_items(FlexStart)
  let c = text_wrap([70.0, 60.0, 30.0], 20.0)
  c.set_width(min_content())
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(200.0))
  assert_eq(c.layout().width, 70.0)
  // 70 宽下装行：70 / 60+30=90>70 → 三行
  assert_eq(c.layout().height, 60.0)
}

///|
test "内在尺寸:fit-content 夹在 min 与 max 之间" {
  let mk = fn(box : Double) -> Node {
    let root = Node::new()
    root.set_width(fixed(box))
    root.set_height(fixed(200.0))
    root.set_align_items(FlexStart)
    let c = text_wrap([70.0, 60.0, 30.0], 20.0)
    c.set_width(fit_content())
    root.append_child(c)
    calculate_layout(root, Some(box), Some(200.0))
    c
  }
  // clamp(70, 40, 160) = 70
  assert_eq(mk(40.0).layout().width, 70.0)
  // clamp(70, 100, 160) = 100
  assert_eq(mk(100.0).layout().width, 100.0)
  // clamp(70, 200, 160) = 160
  assert_eq(mk(200.0).layout().width, 160.0)
}

///|
test "内在尺寸:min-width: max-content 顶住收缩" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(200.0))
  let c = text_wrap([70.0, 60.0, 30.0], 20.0)
  c.set_min_width(max_content())
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(200.0))
  assert_eq(c.layout().width, 160.0)
}

///|
test "内在尺寸:flex-basis: max-content 作为基准参与 grow" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(60.0))
  let a = text_wrap([70.0, 60.0, 30.0], 20.0)
  a.set_flex_basis(max_content())
  a.set_flex_grow(1.0)
  let b = text_wrap([50.0, 40.0], 20.0)
  b.set_flex_basis(max_content())
  b.set_flex_grow(1.0)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(60.0))
  // 基准 160 + 90 = 250，剩余 50 均分
  assert_eq(a.layout().width, 185.0)
  assert_eq(b.layout().width, 115.0)
}

///|
test "内在尺寸:列容器的 min-content 宽取最宽子项" {
  let root = Node::new()
  root.set_width(fixed(1000.0))
  root.set_height(fixed(400.0))
  root.set_align_items(FlexStart)
  let box1 = Node::new()
  box1.set_flex_direction(Column)
  box1.set_padding_left(fixed(10.0))
  box1.set_padding_right(fixed(10.0))
  box1.set_width(min_content())
  let t1 = text_wrap([70.0, 60.0, 30.0], 20.0)
  let t2 = text_wrap([40.0, 30.0], 20.0)
  t2.set_margin_top(fixed(5.0))
  t2.set_margin_bottom(fixed(5.0))
  box1.append_child(t1)
  box1.append_child(t2)
  root.append_child(box1)
  calculate_layout(root, Some(1000.0), Some(400.0))
  // 列容器：交叉轴（宽）取最大子项 min-content = 70，再加两侧 padding 20
  assert_eq(box1.layout().width, 90.0)
  // max-content 宽 = max(160, 70) + 20
  box1.set_width(max_content())
  calculate_layout(root, Some(1000.0), Some(400.0))
  assert_eq(box1.layout().width, 180.0)
}

///|
test "内在尺寸:折行容器的基准为 max-content、下限为最宽单项" {
  let mk = fn(box : Double) -> (Node, Node, Node, Node) {
    let root = Node::new()
    root.set_width(fixed(box))
    root.set_height(fixed(200.0))
    let inner = Node::new()
    inner.set_flex_wrap(Wrap)
    inner.set_align_items(FlexStart)
    // 行盒按内容高紧排，便于直接比对 top（默认 stretch 会把行高摊成容器高）
    inner.set_align_content(FlexStart)
    let a = leaf(60.0, 20.0)
    let b = leaf(50.0, 20.0)
    let c = leaf(40.0, 20.0)
    inner.append_child(a)
    inner.append_child(b)
    inner.append_child(c)
    root.append_child(inner)
    calculate_layout(root, Some(box), Some(200.0))
    (inner, a, b, c)
  }
  // 基准 = max-content（单项不折行）= 150，收缩到可用 100 为止
  let (inner1, _a1, b1, c1) = mk(100.0)
  assert_eq(inner1.layout().width, 100.0)
  assert_eq(b1.layout().top, 20.0)
  assert_eq(c1.layout().top, 20.0)
  // 可用 55 时收缩被 min:auto = min-content（最宽单项 60）顶住，
  // 三项各占一行
  let (inner2, _a2, b2, c2) = mk(55.0)
  assert_eq(inner2.layout().width, 60.0)
  assert_eq(b2.layout().top, 20.0)
  assert_eq(c2.layout().top, 40.0)
}

///|
test "内在尺寸:不换行容器的 min-content 主轴为子项之和" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(200.0))
  let inner = Node::new()
  inner.set_align_items(FlexStart)
  inner.append_child(leaf(60.0, 20.0))
  inner.append_child(leaf(50.0, 20.0))
  root.append_child(inner)
  calculate_layout(root, Some(100.0), Some(200.0))
  // nowrap：min-content 主轴 = 60 + 50 = 110，收缩被下限顶住
  assert_eq(inner.layout().width, 110.0)
}

///|
test "内在尺寸:绝对定位项的 width: max-content" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(200.0))
  let c = text_wrap([70.0, 60.0, 30.0], 20.0)
  c.set_position(Absolute)
  c.set_left(fixed(5.0))
  c.set_top(fixed(5.0))
  c.set_width(max_content())
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(200.0))
  assert_eq(c.layout().width, 160.0)
  assert_eq(c.layout().height, 20.0)
  assert_eq(c.layout().left, 5.0)
}

///|
test "内在尺寸缓存:改子项后重排不用旧内在尺寸" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(200.0))
  let inner = Node::new()
  inner.set_align_items(FlexStart)
  let a = leaf(60.0, 20.0)
  let b = leaf(50.0, 20.0)
  inner.append_child(a)
  inner.append_child(b)
  root.append_child(inner)
  calculate_layout(root, Some(100.0), Some(200.0))
  assert_eq(inner.layout().width, 110.0)
  // 子项改窄后 min-content 下限随之变小（内在缓存在入口被清）
  b.set_width(fixed(20.0))
  calculate_layout(root, Some(100.0), Some(200.0))
  assert_eq(inner.layout().width, 80.0)
}
