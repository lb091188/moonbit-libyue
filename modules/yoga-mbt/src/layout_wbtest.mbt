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
  assert_eq(t.layout().top, 5.0)
  assert_eq(t.layout().width, 100.0)
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
