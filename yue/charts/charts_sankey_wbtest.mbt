// 桑基图白盒测试：纯函数（列分配 / 节点流量 / 分层布局的节点高度与
// 链路端缘）语义，绘制函数保证可编译（真实绘制走 on_draw，由用户真机
// 验证）。

///|
/// 按节点下标取布局矩形（未命中给全 -1/0 的哨兵，断言侧再校验）。
fn sankey_box_of(lay : SankeyLayout, node : Int) -> SankeyNodeBox {
  for b in lay.boxes {
    if b.node == node {
      return b
    }
  }
  { node: -1, col: -1, x: 0.0, y: 0.0, w: 0.0, h: 0.0, }
}

///|
/// 按链路下标取布局色带端缘。
fn sankey_band_of(lay : SankeyLayout, link : Int) -> SankeyLinkBand? {
  for b in lay.bands {
    if b.link == link {
      return Some(b)
    }
  }
  None
}

///|
test "sankey_columns：无入边进第 0 列、沿拓扑右移" {
  // 线性链 0→1→2：层级 0,1,2
  debug_inspect(
    sankey_columns(3, [
      SankeyLink::make(0, 1, 10.0),
      SankeyLink::make(1, 2, 6.0),
    ]),
    content="[0, 1, 2]",
  )
  // 菱形 0→{1,2}→3：1/2 同列，3 收齐后进列 2
  debug_inspect(
    sankey_columns(4, [
      SankeyLink::make(0, 1, 6.0),
      SankeyLink::make(0, 2, 4.0),
      SankeyLink::make(1, 3, 5.0),
      SankeyLink::make(2, 3, 1.0),
    ]),
    content="[0, 1, 1, 2]",
  )
  // 跨级链 0→2 与经停链并存：列号取入边源列最大值 +1（0→1→2 已把 2
  // 推到列 2，0→2 只要求列 1 不生效）
  debug_inspect(
    sankey_columns(3, [
      SankeyLink::make(0, 1, 1.0),
      SankeyLink::make(1, 2, 1.0),
      SankeyLink::make(0, 2, 1.0),
    ]),
    content="[0, 1, 2]",
  )
  // 无链路 / 孤立节点：全在第 0 列
  debug_inspect(sankey_columns(3, []), content="[0, 0, 0]")
  // 越界下标与自环不参与
  debug_inspect(
    sankey_columns(2, [
      SankeyLink::make(0, 5, 1.0),
      SankeyLink::make(5, 1, 1.0),
      SankeyLink::make(-1, 1, 1.0),
      SankeyLink::make(0, 0, 1.0),
    ]),
    content="[0, 0]",
  )
  assert_eq(sankey_columns(0, []).length(), 0)
  // 含环输入：迭代上限截断，结果有限非负（不崩、不停摆）
  let cyc = sankey_columns(2, [
    SankeyLink::make(0, 1, 1.0),
    SankeyLink::make(1, 0, 1.0),
  ])
  assert_eq(cyc.length(), 2)
  assert_true(cyc[0] >= 0)
  assert_true(cyc[1] >= 0)
}

///|
test "sankey_node_flow：max(入, 出) / 非正值不计 / 越界忽略" {
  // 线性链：1 号入 10 出 6 → 10
  debug_inspect(
    sankey_node_flow(3, [
      SankeyLink::make(0, 1, 10.0),
      SankeyLink::make(1, 2, 6.0),
    ]),
    content="[10, 10, 6]",
  )
  // 菱形：0 出 10、3 入 6、1/6 与 2/4 各取入边侧
  debug_inspect(
    sankey_node_flow(4, [
      SankeyLink::make(0, 1, 6.0),
      SankeyLink::make(0, 2, 4.0),
      SankeyLink::make(1, 3, 5.0),
      SankeyLink::make(2, 3, 1.0),
    ]),
    content="[10, 6, 4, 6]",
  )
  // 非正值链路不计入
  debug_inspect(
    sankey_node_flow(3, [
      SankeyLink::make(0, 1, -5.0),
      SankeyLink::make(1, 2, 0.0),
    ]),
    content="[0, 0, 0]",
  )
  // 越界下标忽略
  debug_inspect(
    sankey_node_flow(2, [
      SankeyLink::make(0, 5, 3.0),
      SankeyLink::make(5, 1, 7.0),
    ]),
    content="[0, 0]",
  )
  assert_eq(sankey_node_flow(0, []).length(), 0)
}

///|
test "sankey_layout：线性链的列 x / 节点高度 / 链路端缘" {
  // 3 节点线性链（10、6），绘制区 (0,0)-(100,100)，node_w=14 / gap=8
  let lay = sankey_layout(
    3,
    [SankeyLink::make(0, 1, 10.0), SankeyLink::make(1, 2, 6.0)],
    0.0,
    100.0,
    0.0,
    100.0,
  )
  assert_eq(lay.boxes.length(), 3)
  assert_eq(lay.bands.length(), 2)
  debug_inspect(lay.cols, content="[0, 1, 2]")
  // 列 x 均分（span=86 → 0/43/86），单节点列纵向居中
  let b0 = sankey_box_of(lay, 0)
  let b1 = sankey_box_of(lay, 1)
  let b2 = sankey_box_of(lay, 2)
  assert_true((b0.x - 0.0).abs() < 1.0e-9)
  assert_true((b1.x - 43.0).abs() < 1.0e-9)
  assert_true((b2.x - 86.0).abs() < 1.0e-9)
  // 节点高度 ∝ 流量：scale = 100 / max(列流量 10) = 10
  assert_true((b0.h - 100.0).abs() < 1.0e-9)
  assert_true((b1.h - 100.0).abs() < 1.0e-9)
  assert_true((b2.h - 60.0).abs() < 1.0e-9)
  assert_true((b0.y - 0.0).abs() < 1.0e-9)
  assert_true((b2.y - 20.0).abs() < 1.0e-9) // (100-60)/2 居中
  // 链路 0：源右缘 14 → 目标左缘 43，两端都占满节点高
  let a0 = match sankey_band_of(lay, 0) {
    Some(b) => b
    None =>
      { link: -1, x0: 0.0, x1: 0.0, sy0: 0.0, sy1: 0.0, ty0: 0.0, ty1: 0.0, }
  }
  assert_true((a0.x0 - 14.0).abs() < 1.0e-9)
  assert_true((a0.x1 - 43.0).abs() < 1.0e-9)
  assert_true((a0.sy0 - 0.0).abs() < 1.0e-9)
  assert_true((a0.sy1 - 100.0).abs() < 1.0e-9)
  assert_true((a0.ty0 - 0.0).abs() < 1.0e-9)
  assert_true((a0.ty1 - 100.0).abs() < 1.0e-9)
  // 链路 1：高 6×10=60，源端自 b1 顶起，目标端自 b2 顶（20）起
  let a1 = match sankey_band_of(lay, 1) {
    Some(b) => b
    None =>
      { link: -1, x0: 0.0, x1: 0.0, sy0: 0.0, sy1: 0.0, ty0: 0.0, ty1: 0.0, }
  }
  assert_true((a1.x0 - 57.0).abs() < 1.0e-9)
  assert_true((a1.x1 - 86.0).abs() < 1.0e-9)
  assert_true((a1.sy0 - 0.0).abs() < 1.0e-9)
  assert_true((a1.sy1 - 60.0).abs() < 1.0e-9)
  assert_true((a1.ty0 - 20.0).abs() < 1.0e-9)
  assert_true((a1.ty1 - 80.0).abs() < 1.0e-9)
}

///|
test "sankey_layout：菱形多出/入边的偏移消费与贴合" {
  // 0→{1,2}→3（6、4、5、1），绘制区 (0,0)-(100,92)，node_w=14 / gap=8
  let lay = sankey_layout(
    4,
    [
      SankeyLink::make(0, 1, 6.0),
      SankeyLink::make(0, 2, 4.0),
      SankeyLink::make(1, 3, 5.0),
      SankeyLink::make(2, 3, 1.0),
    ],
    0.0,
    100.0,
    0.0,
    92.0,
  )
  assert_eq(lay.boxes.length(), 4)
  assert_eq(lay.bands.length(), 4)
  let b0 = sankey_box_of(lay, 0)
  let b1 = sankey_box_of(lay, 1)
  let b2 = sankey_box_of(lay, 2)
  let b3 = sankey_box_of(lay, 3)
  // scale = 92 / 10 = 9.2：节点高 92 / 55.2 / 36.8 / 55.2
  assert_true((b0.h - 92.0).abs() < 1.0e-6)
  assert_true((b1.h - 55.2).abs() < 1.0e-6)
  assert_true((b2.h - 36.8).abs() < 1.0e-6)
  assert_true((b3.h - 55.2).abs() < 1.0e-6)
  // 列 1 两节点：下标序纵向排布，总高超出可用高时顶对齐
  assert_true((b1.y - 0.0).abs() < 1.0e-6)
  assert_true((b2.y - 63.2).abs() < 1.0e-6) // 55.2 + gap 8
  // 列 2 单节点居中：(92-55.2)/2 = 18.4
  assert_true((b3.y - 18.4).abs() < 1.0e-6)
  // 同源两带沿节点纵向依序消费（无缝衔接）
  let a0 = match sankey_band_of(lay, 0) {
    Some(b) => b
    None =>
      { link: -1, x0: 0.0, x1: 0.0, sy0: 0.0, sy1: 0.0, ty0: 0.0, ty1: 0.0, }
  }
  let a1 = match sankey_band_of(lay, 1) {
    Some(b) => b
    None =>
      { link: -1, x0: 0.0, x1: 0.0, sy0: 0.0, sy1: 0.0, ty0: 0.0, ty1: 0.0, }
  }
  let a2 = match sankey_band_of(lay, 2) {
    Some(b) => b
    None =>
      { link: -1, x0: 0.0, x1: 0.0, sy0: 0.0, sy1: 0.0, ty0: 0.0, ty1: 0.0, }
  }
  let a3 = match sankey_band_of(lay, 3) {
    Some(b) => b
    None =>
      { link: -1, x0: 0.0, x1: 0.0, sy0: 0.0, sy1: 0.0, ty0: 0.0, ty1: 0.0, }
  }
  assert_true((a1.sy0 - a0.sy1).abs() < 1.0e-6) // 源端偏移衔接在 55.2
  assert_true((a0.sy0 - b0.y).abs() < 1.0e-6) // 自节点顶起
  assert_true((a1.sy1 - (b0.y + b0.h)).abs() < 1.0e-6) // 铺满节点高
  // 同目标两带依序衔接在 46（5×9.2）
  assert_true((a3.ty0 - a2.ty1).abs() < 1.0e-6)
  assert_true((a2.ty0 - b3.y).abs() < 1.0e-6)
  assert_true((a3.ty1 - (b3.y + b3.h)).abs() < 1.0e-6)
  // 带高 ∝ value：5↔1 两带高度比 5
  let h2 = a2.ty1 - a2.ty0
  let h3 = a3.ty1 - a3.ty0
  assert_true((h2 / h3 - 5.0).abs() < 1.0e-6)
  // 带不超出节点矩形（源/目标两侧）
  assert_true(a0.sy0 >= b0.y - 1.0e-6)
  assert_true(a0.sy1 <= b0.y + b0.h + 1.0e-6)
  assert_true(a0.ty0 >= b1.y - 1.0e-6)
  assert_true(a0.ty1 <= b1.y + b1.h + 1.0e-6)
  // 源右缘 / 目标左缘
  assert_true((a2.x0 - 57.0).abs() < 1.0e-6)
  assert_true((a2.x1 - 86.0).abs() < 1.0e-6)
}

///|
test "sankey_layout：无效链路不出带 / 零流量最小高 / 空与单列退化" {
  // 非正值、自环、越界的链路一律不产出 band
  let lay = sankey_layout(
    3,
    [
      SankeyLink::make(0, 1, -5.0),
      SankeyLink::make(0, 2, 0.0),
      SankeyLink::make(0, 0, 7.0),
      SankeyLink::make(0, 9, 3.0),
      SankeyLink::make(-1, 1, 3.0),
    ],
    0.0,
    100.0,
    0.0,
    100.0,
  )
  assert_eq(lay.bands.length(), 0)
  assert_eq(lay.boxes.length(), 3)
  debug_inspect(lay.cols, content="[0, 0, 0]")
  // 全零流量：节点给最小高 3px，单列居中
  let zlay = sankey_layout(
    2,
    [SankeyLink::make(0, 1, 0.0)],
    0.0,
    100.0,
    0.0,
    100.0,
  )
  let z0 = sankey_box_of(zlay, 0)
  assert_true((z0.x - 43.0).abs() < 1.0e-9) // span=86 单列居中
  assert_true((z0.h - 3.0).abs() < 1.0e-9)
  assert_true((z0.y - (100.0 - 14.0) / 2.0).abs() < 1.0e-9) // 两节点 + gap 居中
  // 空图
  let empty = sankey_layout(0, [], 0.0, 100.0, 0.0, 100.0)
  assert_eq(empty.boxes.length(), 0)
  assert_eq(empty.bands.length(), 0)
  assert_eq(empty.cols.length(), 0)
}

///|
test "sankey_layout：自定义 node_w / gap / min_h 生效" {
  let lay = sankey_layout(
    2,
    [SankeyLink::make(0, 1, 4.0)],
    0.0,
    50.0,
    0.0,
    40.0,
    node_w=10.0,
    gap=4.0,
    min_h=6.0,
  )
  let b0 = sankey_box_of(lay, 0)
  let b1 = sankey_box_of(lay, 1)
  assert_true((b0.w - 10.0).abs() < 1.0e-9)
  assert_true((b0.h - 40.0).abs() < 1.0e-9) // 单列单节点占满可用高
  assert_true((b1.h - 40.0).abs() < 1.0e-9)
  assert_true((b1.x - 40.0).abs() < 1.0e-9) // span = 50-10 = 40
  let a0 = match sankey_band_of(lay, 0) {
    Some(b) => b
    None =>
      { link: -1, x0: 0.0, x1: 0.0, sy0: 0.0, sy1: 0.0, ty0: 0.0, ty1: 0.0, }
  }
  assert_true((a0.x0 - 10.0).abs() < 1.0e-9)
  assert_true((a0.x1 - 40.0).abs() < 1.0e-9)
  assert_true((a0.sy1 - 40.0).abs() < 1.0e-9)
}

///|
test "SankeyData 构造与 sankey_t 组件可编译（不 mount，真机验证绘制）" {
  let data = SankeyData::make(
    [
      SankeyNode::make("收入"),
      SankeyNode::make("支出A"),
      SankeyNode::make("支出B"),
    ],
    [SankeyLink::make(0, 1, 7.0), SankeyLink::make(0, 2, 3.0)],
  )
  assert_eq(data.nodes.length(), 3)
  assert_eq(data.nodes[0].name, "收入")
  assert_eq(data.links[1].value, 3.0)
  assert_eq(data.links[1].target, 2)
  // 组件构造只建未挂载片段（无平台副作用）；绘制路径走 on_draw，
  // 由用户真机验证
  let store : @yue.Store[SankeyData] = @yue.Store::new(data)
  let node = sankey_t(store)
  ignore(node.mount)
}
