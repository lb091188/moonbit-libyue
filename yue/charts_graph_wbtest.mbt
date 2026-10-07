// 关系力图白盒测试：纯函数（边有效性 / 静止长度 / 力步进 / 收敛性 /
// 画布适配 / 节点半径 / 边带宽度 / 标签防重叠）语义与确定性。
// 绘制函数（gph_draw_chart / gph_chart_t）走 GUI 挂载路径，保证可编译
// 即可，视觉验证按仓库惯例由真机示例承担。

///|
/// 两点距离（断言语义：两节点弹簧把边拉近/推远）。
fn gph_dist(pts : Array[(Double, Double)], i : Int, j : Int) -> Double {
  let dx = pts[j].0 - pts[i].0
  let dy = pts[j].1 - pts[i].1
  (dx * dx + dy * dy).sqrt()
}

///|
test "GraphNode / GraphEdge / GraphData 构造与边有效性口径" {
  let n0 = GraphNode::make("甲")
  assert_eq(n0.name, "甲")
  assert_eq(n0.value, 1.0) // 默认 value 1
  let n1 = GraphNode::make("乙", value=6.0)
  assert_eq(n1.value, 6.0)
  let e = GraphEdge::make(0, 1)
  assert_eq(e.source, 0)
  assert_eq(e.target, 1)
  assert_eq(e.weight, 1.0) // 默认 weight 1
  let ew = GraphEdge::make(1, 2, weight=4.0)
  assert_eq(ew.weight, 4.0)
  let d = GraphData::make([n0, n1], [e])
  assert_eq(d.nodes.length(), 2)
  assert_eq(d.edges.length(), 1)
  // 边有效性：合法 / 自环 / 越界 / 零负权重
  assert_true(gph_edge_valid(GraphEdge::make(0, 1, weight=1.0), 2))
  assert_false(gph_edge_valid(GraphEdge::make(0, 0, weight=1.0), 2)) // 自环
  assert_false(gph_edge_valid(GraphEdge::make(0, 2, weight=1.0), 2)) // 越上界
  assert_false(gph_edge_valid(GraphEdge::make(-1, 1, weight=1.0), 2)) // 负下标
  assert_false(gph_edge_valid(GraphEdge::make(0, 1, weight=0.0), 2)) // 零权重
  assert_false(gph_edge_valid(GraphEdge::make(0, 1, weight=-2.0), 2)) // 负权重
  assert_true(gph_edge_valid(GraphEdge::make(0, 1, weight=0.5), 2))
}

///|
test "gph_rest_len：短边比例 / 画布退化兜底" {
  // 300×200 → 短边 200 × 0.22 = 44
  assert_eq(gph_rest_len(300.0, 200.0), 44.0)
  // 横竖同尺度无关：200×300 同值
  assert_eq(gph_rest_len(200.0, 300.0), 44.0)
  // 非正边退化为 1：0.22
  assert_eq(gph_rest_len(0.0, 0.0), 0.22)
  assert_eq(gph_rest_len(-5.0, 100.0), 0.22)
  assert_eq(gph_rest_len(100.0, -5.0), 0.22)
}

///|
test "GraphSim::make：圆周均匀布点（确定性起步）/ 空表" {
  let s = GraphSim::make(4, 300.0, 300.0)
  assert_eq(s.pos.length(), 4)
  assert_eq(s.vel.length(), 4)
  // 圆心 (150,150)，半径 0.38×300=114；四点角度 0/90/180/270
  assert_true((s.pos[0].0 - 264.0).abs() < 1.0e-9) // cos0=1
  assert_true((s.pos[0].1 - 150.0).abs() < 1.0e-9)
  assert_true((s.pos[1].0 - 150.0).abs() < 1.0e-9) // cos90=0
  assert_true((s.pos[1].1 - 264.0).abs() < 1.0e-9)
  assert_true((s.pos[2].0 - 36.0).abs() < 1.0e-9) // cos180=-1
  assert_true((s.pos[3].1 - 36.0).abs() < 1.0e-9)
  // 速度归零
  for v in s.vel {
    assert_eq(v, (0.0, 0.0))
  }
  // 空表 / 非正 n
  assert_eq(GraphSim::make(0, 300.0, 300.0).pos.length(), 0)
  assert_eq(GraphSim::make(-3, 300.0, 300.0).vel.length(), 0)
}

///|
test "GraphSim::advance 单步：两节点弹簧缩短、速度阻尼、边界反射" {
  // 300×300 画布两节点一条弹簧：弦长 228 > 静止长 44，劲度项压过斥力，
  // 单步后边长必须缩短（弹簧拉近）
  let s = GraphSim::make(2, 300.0, 300.0)
  let d0 = gph_dist(s.pos, 0, 1)
  assert_true((d0 - 228.0).abs() < 1.0e-9)
  GraphSim::advance(s, [GraphEdge::make(0, 1, weight=1.0)], 300.0, 300.0)
  let d1 = gph_dist(s.pos, 0, 1)
  assert_true(d1 < d0)
  assert_true(d0 - d1 > 1.0e-3) // 明显缩短，非数值噪声
  // node0（右，x 大）向内位移、node1（左，x 小）向内位移，两点仍分居
  assert_true(s.pos[0].0 > s.pos[1].0)
  assert_true(s.pos[0].0 < 264.0) // node0 自右缘内移
  assert_true(s.pos[1].0 > 36.0) // node1 自左缘内移
  // 阻尼：速度 = 0.72×旧速(0) + 力，故 |vel| ≤ 合力量级，且与位移同号
  assert_true(s.vel[0].0 < 0.0)
  assert_true(s.vel[1].0 > 0.0)
  // 两步继续收敛（不振荡发散）
  GraphSim::advance(s, [GraphEdge::make(0, 1, weight=1.0)], 300.0, 300.0)
  assert_true(gph_dist(s.pos, 0, 1) < d1)
  // 斥力主导侧：无弹簧边时节点被斥力推开（边长增大）
  let s2 = GraphSim::make(2, 300.0, 300.0)
  let e0 = gph_dist(s2.pos, 0, 1)
  GraphSim::advance(s2, [], 300.0, 300.0)
  assert_true(gph_dist(s2.pos, 0, 1) > e0)
  // 边界反射：大画布单节点被向心力贴到质心（自身即质心 → 不动）
  let s3 = GraphSim::make(1, 300.0, 300.0)
  GraphSim::advance(s3, [], 300.0, 300.0)
  assert_eq(s3.pos[0], (264.0, 150.0)) // 向心目标即自身，步进零位移
  // 空模拟：空转不崩
  let s4 = GraphSim::make(0, 300.0, 300.0)
  GraphSim::advance(s4, [GraphEdge::make(0, 1, weight=1.0)], 300.0, 300.0)
  assert_eq(s4.pos.length(), 0)
  // 零权重边不参与弹簧（等价无边，只有斥力）
  let s5 = GraphSim::make(2, 300.0, 300.0)
  let w0 = gph_dist(s5.pos, 0, 1)
  GraphSim::advance(s5, [GraphEdge::make(0, 1, weight=0.0)], 300.0, 300.0)
  assert_true(gph_dist(s5.pos, 0, 1) > w0)
}

///|
test "gph_energy：空输入 / 无效边 / 收敛性（迭代后下降）" {
  // 空节点表：0
  assert_eq(gph_energy([], [], 300.0, 300.0), 0.0)
  // 越界/自环/零权重边不计边势：与「无边」输入同能（只剩向心势）
  let pts = [(10.0, 10.0), (50.0, 10.0), (90.0, 10.0)]
  let e_inv = gph_energy(
    pts,
    [GraphEdge::make(0, 9, weight=1.0), GraphEdge::make(1, 1, weight=1.0)],
    300.0,
    300.0,
  )
  let e_none = gph_energy(pts, [], 300.0, 300.0)
  assert_eq(e_inv, e_none)
  // 同 pts 挂一条有效边：边势计入，能量高于无边
  let e_ok = gph_energy(pts, [GraphEdge::make(0, 2, weight=1.0)], 300.0, 300.0)
  assert_true(e_ok > e_none)
  // 斥力势单调性：同边权重下两点越近总势越高（弹簧项同，斥力项 1/d 升）
  let near = gph_energy(
    [(0.0, 0.0), (5.0, 0.0)],
    [GraphEdge::make(0, 1, weight=1.0)],
    300.0,
    300.0,
  )
  let far = gph_energy(
    [(0.0, 0.0), (100.0, 0.0)],
    [GraphEdge::make(0, 1, weight=1.0)],
    300.0,
    300.0,
  )
  assert_true(near > far)
  // 收敛性：两节点 300 步迭代后能量低于起步（单步即降，后续持平）
  let s = GraphSim::make(2, 300.0, 300.0)
  let edges = [GraphEdge::make(0, 1, weight=1.0)]
  let e0 = gph_energy(s.pos, edges, 300.0, 300.0)
  GraphSim::advance(s, edges, 300.0, 300.0)
  let e1 = gph_energy(s.pos, edges, 300.0, 300.0)
  assert_true(e1 < e0)
  for _ in 0..<299 {
    GraphSim::advance(s, edges, 300.0, 300.0)
  }
  let e300 = gph_energy(s.pos, edges, 300.0, 300.0)
  assert_true(e300 < e0)
  // 再 300 步持平（不反弹：收敛点附近 Lyapunov 稳定）
  for _ in 0..<300 {
    GraphSim::advance(s, edges, 300.0, 300.0)
  }
  let e600 = gph_energy(s.pos, edges, 300.0, 300.0)
  assert_true(e600 <= e300 + 1.0)
  // 链 5 节点：300 步后能量低于起步
  let s5 = GraphSim::make(5, 300.0, 300.0)
  let chain = [
    GraphEdge::make(0, 1, weight=1.0),
    GraphEdge::make(1, 2, weight=1.0),
    GraphEdge::make(2, 3, weight=1.0),
    GraphEdge::make(3, 4, weight=1.0),
  ]
  let c0 = gph_energy(s5.pos, chain, 300.0, 300.0)
  for _ in 0..<300 {
    GraphSim::advance(s5, chain, 300.0, 300.0)
  }
  assert_true(gph_energy(s5.pos, chain, 300.0, 300.0) < c0)
  // 星 6 节点：同上
  let s6 = GraphSim::make(6, 300.0, 300.0)
  let star = Array::make(5, GraphEdge::make(0, 1, weight=1.0))
  for i in 1..<6 {
    star[i - 1] = GraphEdge::make(0, i, weight=1.0)
  }
  let st0 = gph_energy(s6.pos, star, 300.0, 300.0)
  for _ in 0..<300 {
    GraphSim::advance(s6, star, 300.0, 300.0)
  }
  assert_true(gph_energy(s6.pos, star, 300.0, 300.0) < st0)
}

///|
test "gph_layout：确定性（同输入同输出）/ 收敛坐标入画布 / 空输入" {
  let nodes = [
    GraphNode::make("a", value=3.0),
    GraphNode::make("b", value=1.0),
    GraphNode::make("c", value=2.0),
    GraphNode::make("d", value=5.0),
  ]
  let edges = [
    GraphEdge::make(0, 1, weight=1.0),
    GraphEdge::make(1, 2, weight=2.0),
    GraphEdge::make(2, 3, weight=0.5),
    GraphEdge::make(3, 0, weight=1.0),
  ]
  let l1 = gph_layout(nodes, edges, 300.0, 200.0)
  let l2 = gph_layout(nodes, edges, 300.0, 200.0)
  assert_eq(l1.points.length(), 4)
  assert_eq(l2.points.length(), 4)
  // 逐点逐轴逐位相等（纯函数，无随机源）
  for i in 0..<4 {
    assert_eq(l1.points[i].0, l2.points[i].0)
    assert_eq(l1.points[i].1, l2.points[i].1)
  }
  // 迭代参数同尺度确定性（默认 300 与显式 300 一致）
  let l3 = gph_layout(nodes, edges, 300.0, 200.0, iterations=300)
  assert_eq(l3.points[0], l1.points[0])
  assert_eq(l3.points[3], l1.points[3])
  // 收敛后坐标落在 [gph_pad, w-gph_pad] × [gph_pad, h-gph_pad] 内
  for (x, y) in l1.points {
    assert_true(x >= 12.0 - 1.0e-9 && x <= 288.0 + 1.0e-9)
    assert_true(y >= 12.0 - 1.0e-9 && y <= 188.0 + 1.0e-9)
  }
  // 空节点表 → 空坐标表
  assert_eq(gph_layout([], [], 300.0, 200.0).points.length(), 0)
  // 负迭代按 0 步：仅画布适配，仍给同长度表
  let z = gph_layout(nodes, edges, 300.0, 200.0, iterations=-5)
  assert_eq(z.points.length(), 4)
  // 单节点图：layout 给 1 点，推进不崩
  let solo = gph_layout([GraphNode::make("only")], [], 300.0, 200.0)
  assert_eq(solo.points.length(), 1)
  assert_true((solo.points[0].0 - 150.0).abs() < 1.0e-9)
  assert_true((solo.points[0].1 - 100.0).abs() < 1.0e-9)
}

///|
test "gph_fit_canvas：包围盒等比缩放居中 / 退化轴 / 空输入" {
  // 单点：居中（span=0 两轴都不拉伸，仅平移）
  let one = gph_fit_canvas([(50.0, 30.0)], 300.0, 200.0)
  assert_eq(one.points.length(), 1)
  assert_true((one.points[0].0 - 150.0).abs() < 1.0e-9)
  assert_true((one.points[0].1 - 100.0).abs() < 1.0e-9)
  // 水平两跨：span_x=100 → sx=276/100=2.76；span_y=0（退化轴 sy=1）→ 等比
  // s=min=1，x 不平移拉伸只居中：(300-100)/2=100
  let two = gph_fit_canvas([(0.0, 0.0), (100.0, 0.0)], 300.0, 200.0)
  assert_true((two.points[0].0 - 100.0).abs() < 1.0e-9)
  assert_true((two.points[1].0 - 200.0).abs() < 1.0e-9)
  assert_true((two.points[0].1 - 100.0).abs() < 1.0e-9) // y 轴仅居中
  // 等比：方阵 span_x=span_y=100 → 可用 276×176 → s=min(2.76, 1.76)=1.76；
  // 短轴（y）贴满留白带 12→188，长轴（x）居中双侧 (300-176)/2=62
  let sq = gph_fit_canvas([(0.0, 0.0), (100.0, 100.0)], 300.0, 200.0)
  let s_eff = 176.0 / 100.0
  assert_true((sq.points[0].0 - 62.0).abs() < 1.0e-9)
  assert_true((sq.points[1].0 - (62.0 + 100.0 * s_eff)).abs() < 1.0e-9)
  assert_true((sq.points[0].1 - 12.0).abs() < 1.0e-9)
  assert_true((sq.points[1].1 - (12.0 + 100.0 * s_eff)).abs() < 1.0e-9)
  // 长宽不等：span_x=100 → sx=276/100=2.76；span_y=50 → sy=176/50=3.52；
  // 等比取小 s=2.76：x 贴留白带 12→288，y 居中 (200-138)/2=31→169
  let rect = gph_fit_canvas([(0.0, 0.0), (100.0, 50.0)], 300.0, 200.0)
  assert_true((rect.points[0].0 - 12.0).abs() < 1.0e-9)
  assert_true((rect.points[1].0 - 288.0).abs() < 1.0e-9)
  assert_true((rect.points[0].1 - 31.0).abs() < 1.0e-9)
  assert_true((rect.points[1].1 - 169.0).abs() < 1.0e-9)
  // 空输入
  assert_eq(gph_fit_canvas([], 300.0, 200.0).points.length(), 0)
  // 画布退化（≤0）不崩，只按 1px 口径
  let deg = gph_fit_canvas([(0.0, 0.0), (10.0, 10.0)], 0.0, 0.0)
  assert_eq(deg.points.length(), 2)
}

///|
test "gph_node_radius：面积量程钳制 / 退化" {
  // ∝ sqrt(v/vmax)：vmax=9 → v=0 → 6；v=9/4 → 6+0.5×12=12；v=9 → 18
  assert_true((gph_node_radius(0.0, 9.0) - 6.0).abs() < 1.0e-12)
  assert_true((gph_node_radius(2.25, 9.0) - 12.0).abs() < 1.0e-12)
  assert_true((gph_node_radius(9.0, 9.0) - 18.0).abs() < 1.0e-12)
  // 超 vmax 钳上限；负值钳下限
  assert_true((gph_node_radius(99.0, 9.0) - 18.0).abs() < 1.0e-12)
  assert_true((gph_node_radius(-4.0, 9.0) - 6.0).abs() < 1.0e-12)
  // vmax<=0（全零图）：下限
  assert_true((gph_node_radius(3.0, 0.0) - 6.0).abs() < 1.0e-12)
  assert_true((gph_node_radius(3.0, -1.0) - 6.0).abs() < 1.0e-12)
  // 自定义量程
  // 自定义量程：2 + sqrt(5/10)×(20-2) = 14.7279…
  assert_true(
    (gph_node_radius(5.0, 10.0, r_min=2.0, r_max=20.0) - 14.727922061357857).abs() <
    1.0e-12,
  )
}

///|
test "gph_edge_width：权重线性量程 / 退化" {
  // wmax=8 → w=0 → 1；w=4 → 3；w=8 → 5
  assert_true((gph_edge_width(0.0, 8.0) - 1.0).abs() < 1.0e-12)
  assert_true((gph_edge_width(4.0, 8.0) - 3.0).abs() < 1.0e-12)
  assert_true((gph_edge_width(8.0, 8.0) - 5.0).abs() < 1.0e-12)
  // 超 wmax / 负值钳
  assert_true((gph_edge_width(99.0, 8.0) - 5.0).abs() < 1.0e-12)
  assert_true((gph_edge_width(-2.0, 8.0) - 1.0).abs() < 1.0e-12)
  // wmax<=0（无有效 weight）：下限
  assert_true((gph_edge_width(3.0, 0.0) - 1.0).abs() < 1.0e-12)
  assert_true((gph_edge_width(-1.0, 0.0) - 1.0).abs() < 1.0e-12)
  // 自定义带宽
  assert_true(
    (gph_edge_width(5.0, 10.0, w_min=0.5, w_max=8.0) - 4.25).abs() < 1.0e-12,
  )
}

///|
test "gph_label_slots：防重叠推挤最小间距 / 空输入" {
  // 三个标签锚点挤在一行：升序推挤到 gap 14 之上（稳定取下标序）
  let pts = [(10.0, 100.0), (20.0, 100.0), (30.0, 100.0)]
  let radii = [6.0, 6.0, 6.0]
  let slots = gph_label_slots(pts, radii, gap=14.0)
  assert_eq(slots.length(), 3)
  assert_true((slots[0] - (100.0 + 2.1)).abs() < 1.0e-12) // 首个锚点原样
  assert_true((slots[1] - (slots[0] + 14.0)).abs() < 1.0e-12) // 推挤到间距
  assert_true((slots[2] - (slots[1] + 14.0)).abs() < 1.0e-12)
  // y 乱序也按 y 升序推挤，输出按下标回填
  let pts2 = [(0.0, 300.0), (0.0, 100.0), (0.0, 200.0)]
  let s2 = gph_label_slots(pts2, [1.0, 1.0, 1.0], gap=10.0)
  assert_true((s2[1] - (100.0 + 0.35)).abs() < 1.0e-12) // idx1 最低排首
  assert_true((s2[2] - 200.35).abs() < 1.0e-12) // 高于前一 slot+gap → 不推挤
  assert_true((s2[0] - 300.35).abs() < 1.0e-12) // 最高者原样
  // 空 radii 退化：锚点 = 圆心 y，仍不糊
  let s3 = gph_label_slots([(0.0, 50.0), (0.0, 52.0)], [], gap=14.0)
  assert_true((s3[0] - 50.0).abs() < 1.0e-12)
  assert_true((s3[1] - 64.0).abs() < 1.0e-12)
  // 空输入
  assert_eq(gph_label_slots([], []).length(), 0)
}

///|
test "GraphData 构造与 gph_chart_t 组件可编译（不 mount，真机验证绘制）" {
  let data = GraphData::make(
    [
      GraphNode::make("中心", value=9.0),
      GraphNode::make("分支A", value=3.0),
      GraphNode::make("分支B", value=1.0),
    ],
    [GraphEdge::make(0, 1, weight=6.0), GraphEdge::make(0, 2, weight=2.0)],
  )
  assert_eq(data.nodes.length(), 3)
  assert_eq(data.nodes[0].name, "中心")
  assert_eq(data.nodes[1].value, 3.0)
  assert_eq(data.edges[1].weight, 2.0)
  assert_eq(data.edges[1].target, 2)
  // 布局走默认迭代数，坐标数对齐节点数
  let lay = gph_layout(data.nodes, data.edges, 560.0, 320.0)
  assert_eq(lay.points.length(), 3)
  // 组件构造只建未挂载片段（无平台副作用）；绘制路径走 on_draw，
  // 由用户真机验证
  let store : Store[GraphData] = Store::new(data)
  let node = gph_chart_t(store)
  ignore(node.mount)
}
