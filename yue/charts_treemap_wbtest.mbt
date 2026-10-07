// 矩形树图白盒测试：纯函数（节点计值 / 行最差宽高比 / squarified 行划分 /
// 矩形序列 / 层级布局 / 标签排布 / 兄弟取色）语义——重点把 squarified 的
// 行划分与几何按「已知答案」钉住（面积占比、宽高比、行内并排方向），
// 外加两级嵌套（子项落在父矩形内、父先子后）与标签省略；绘制函数保证
// 可编译（真实绘制走 on_draw，由用户真机验证）。
//
// 约定（与实现同源，d3/Bruls squarified 规范）：行贴容器短边、厚沿长边；
// 行判定量 tm_row_worst 收像素面积（value × 定标），行内并排沿短边、
// 每项长 = area·side/Σ。

///|
test "TmItem 构造与 tm_value_of：自身值优先/子项合计/全零退化" {
  let leaf = TmItem::make("叶子", value=10.0)
  assert_eq(leaf.name, "叶子")
  assert_true((leaf.value - 10.0).abs() < 1.0e-12)
  assert_eq(leaf.children.length(), 0)
  let parent = TmItem::make("父", children=[
    TmItem::make("a", value=1.0),
    TmItem::make("b", value=2.0),
  ])
  assert_true((parent.value - 0.0).abs() < 1.0e-12)
  assert_true((tm_value_of(parent) - 3.0).abs() < 1.0e-12) // 子项合计
  assert_true((tm_value_of(leaf) - 10.0).abs() < 1.0e-12) // 自身优先
  assert_eq(tm_value_of(TmItem::make("空")), 0.0) // 全零退化
  // 自身值与子项并存：取自身
  assert_true(
    (tm_value_of(
      TmItem::make("x", value=5.0, children=[TmItem::make("y", value=100.0)]),
    ) -
    5.0).abs() <
    1.0e-12,
  )
  // 三层递归合计
  let deep = TmItem::make("deep", children=[
    TmItem::make("m", children=[TmItem::make("n", value=4.0)]),
  ])
  assert_true((tm_value_of(deep) - 4.0).abs() < 1.0e-12)
  // 负值计 0
  assert_eq(tm_value_of(TmItem::make("neg", value=-3.0)), 0.0)
}

///|
test "tm_row_worst：行判定量（像素面积定标 / 改善 / 恶化 / 方正 / 退化）" {
  // 判定量收像素面积：10×10 容器、总 6 → 定标 100/6，单项 1 的面积 = 100/6
  let a1 = 100.0 / 6.0
  // 单行 [1]：最差宽高比 = side²/area = 100/(100/6) = 6
  assert_true((tm_row_worst([a1], 10.0) - 6.0).abs() < 1.0e-12)
  // 等分两项 [1,1]：Σ=100/3，每项比 = area·side²/Σ² = 1.5（改善）
  assert_true((tm_row_worst([a1, a1], 10.0) - 1.5).abs() < 1.0e-12)
  // 三项等分：Σ=50，每项 100/6 → 比 1.5（[1,1,1,3]@10×10 封行于此）
  assert_true((tm_row_worst([a1, a1, a1], 10.0) - 1.5).abs() < 1.0e-12)
  // 并入 3（面积 50）后总额 100：小项比 = (100/6)·100/100² = 1/6 → 倒数
  // 6，大项比 = 50·100/100² = 0.5 → 倒数 2，取大者 6 —— 6 > 1.5，正是
  // 行在此封口的判据
  assert_true((tm_row_worst([a1, a1, a1, 50.0], 10.0) - 6.0).abs() < 1.0e-9)
  // 不等分 75:25（Σ=100）：大项比 75·100/100² = 0.75 → 4/3，小项比
  // 25·100/100² = 0.25 → 4，取大者 4
  assert_true((tm_row_worst([75.0, 25.0], 10.0) - 4.0).abs() < 1.0e-12)
  // 铺满（area == side²）：比 1（方正）
  assert_true((tm_row_worst([100.0], 10.0) - 1.0).abs() < 1.0e-12)
  // 非正值不入合计
  assert_true((tm_row_worst([100.0, -5.0, 0.0], 10.0) - 1.0).abs() < 1.0e-12)
  // 退化
  assert_eq(tm_row_worst([], 10.0), 0.0)
  assert_eq(tm_row_worst([a1], 0.0), 0.0)
  assert_eq(tm_row_worst([0.0, 0.0], 10.0), 0.0)
}

///|
test "tm_squarified_rows：已知行划分 + 面积占比 + 宽高比" {
  // [1,1,1,3] @10×10：三个 1 成一行（并 3 最差比转差），3 单独一行
  let rows = tm_squarified_rows([1.0, 1.0, 1.0, 3.0], 10.0, 10.0)
  assert_eq(rows.length(), 2)
  debug_inspect(rows[0], content="[0, 1, 2]")
  debug_inspect(rows[1], content="[3]")
  // 对应矩形：首行贴短边 y（容器 10×10 近方，首行走 y 列）、
  // 厚沿 x = 5，行内三项各 5×10/3 沿 y 并排；[3] 落余下 5×10
  let sq : RectF = { x: 0.0, y: 0.0, width: 10.0, height: 10.0, }
  let cells = tm_squarified_rects([1.0, 1.0, 1.0, 3.0], sq)
  assert_eq(cells.length(), 4)
  // 总面积守恒（= 容器面积）
  let mut acc = 0.0
  for c in cells {
    acc = acc + c.width * c.height
  }
  assert_true((acc - 100.0).abs() < 1.0e-6)
  // 面积占比：1/6、1/6、1/6、1/2
  assert_true((cells[0].width * cells[0].height - 100.0 / 6.0).abs() < 1.0e-6)
  assert_true((cells[1].width * cells[1].height - 100.0 / 6.0).abs() < 1.0e-6)
  assert_true((cells[2].width * cells[2].height - 100.0 / 6.0).abs() < 1.0e-6)
  assert_true((cells[3].width * cells[3].height - 50.0).abs() < 1.0e-6)
  // 首行三格同宽（=5）沿 y 并排、紧贴 x=0，第三格让位给 [3] 前的 y 边界
  assert_true(cells[0].x.abs() < 1.0e-9)
  assert_true(cells[0].y.abs() < 1.0e-9)
  assert_true((cells[0].width - 5.0).abs() < 1.0e-9)
  assert_true((cells[1].y - cells[0].y - cells[0].height).abs() < 1.0e-9)
  assert_true((cells[2].y - cells[1].y - cells[1].height).abs() < 1.0e-9)
  assert_true((cells[2].height - 10.0 / 3.0).abs() < 1.0e-9)
  // 末格铺满剩余 5×10（x=5, y=0）
  assert_true((cells[3].x - 5.0).abs() < 1.0e-9)
  assert_true(cells[3].y.abs() < 1.0e-9)
  assert_true((cells[3].width - 5.0).abs() < 1.0e-9)
  assert_true((cells[3].height - 10.0).abs() < 1.0e-9)
  // 每格宽高比（长/短）<= 4（squarified 优化：本样例最差 1.5 与 2）
  for c in cells {
    let r = (c.width / c.height).max(c.height / c.width)
    assert_true(r <= 4.0)
  }
  // 等分四项：三行（2 + 1 + 1），四格均 5×5（宽高比 1，最优解）——
  // 首行并到第三项时最差比转差（见 tm_row_worst 样例），故封两格，
  // 余下 5×10 瘦矩形内 1、1 各行一格
  let rows2 = tm_squarified_rows([1.0, 1.0, 1.0, 1.0], 10.0, 10.0)
  assert_eq(rows2.length(), 3)
  debug_inspect(rows2[0], content="[0, 1]")
  debug_inspect(rows2[1], content="[2]")
  debug_inspect(rows2[2], content="[3]")
  for c in tm_squarified_rects([1.0, 1.0, 1.0, 1.0], sq) {
    assert_true((c.width - 5.0).abs() < 1.0e-9)
    assert_true((c.height - 5.0).abs() < 1.0e-9)
    assert_true((c.width * c.height - 25.0).abs() < 1.0e-6)
  }
  // 两项 [1,1]：一行，两格各 10×5（面积各半）
  let two = tm_squarified_rects([1.0, 1.0], sq)
  assert_true((two[0].width - 10.0).abs() < 1.0e-9)
  assert_true((two[0].height - 5.0).abs() < 1.0e-9)
  assert_true((two[1].y - 5.0).abs() < 1.0e-9)
  // [3,1]：两行（3 自封一行、1 自封一行——并 1 最差比 4 > 1.33 转差），
  // 格 7.5×10 / 2.5×10
  let skew = tm_squarified_rects([3.0, 1.0], sq)
  assert_eq(tm_squarified_rows([3.0, 1.0], 10.0, 10.0).length(), 2)
  assert_true((skew[0].width - 7.5).abs() < 1.0e-9)
  assert_true((skew[0].height - 10.0).abs() < 1.0e-9)
  assert_true((skew[1].x - 7.5).abs() < 1.0e-9)
  assert_true((skew[1].height - 10.0).abs() < 1.0e-9)
  // 横向容器（200×20）：行贴短边 y，厚 = 全宽
  let lay = tm_squarified_rects([3.0, 1.0, 1.0], {
    x: 0.0,
    y: 0.0,
    width: 200.0,
    height: 20.0,
  })
  assert_true((lay[0].width - 120.0).abs() < 1.0e-9)
  assert_true((lay[1].width - 40.0).abs() < 1.0e-9)
  assert_true((lay[2].width - 40.0).abs() < 1.0e-9)
  for c in lay {
    assert_true((c.height - 20.0).abs() < 1.0e-9)
  }
  // 纵向容器（20×200）：行贴短边 x，厚 = 全宽，行内沿 y 并排
  let tall = tm_squarified_rects([3.0, 1.0, 1.0], {
    x: 0.0,
    y: 0.0,
    width: 20.0,
    height: 200.0,
  })
  assert_true((tall[0].width - 20.0).abs() < 1.0e-9)
  assert_true((tall[0].height - 120.0).abs() < 1.0e-9)
  assert_true((tall[1].y - 120.0).abs() < 1.0e-9)
  assert_true((tall[2].height - 40.0).abs() < 1.0e-9)
  // 非正值 / 空表 / 退化容器
  assert_eq(tm_squarified_rows([0.0, -1.0], 10.0, 10.0).length(), 0)
  assert_eq(tm_squarified_rows([], 10.0, 10.0).length(), 0)
  assert_eq(tm_squarified_rows([1.0], 0.0, 10.0).length(), 0)
  let zero = tm_squarified_rects([1.0, 2.0], {
    x: 3.0,
    y: 4.0,
    width: 0.0,
    height: 10.0,
  })
  for c in zero {
    assert_true(c.width.abs() < 1.0e-12 && c.height.abs() < 1.0e-12)
  }
  assert_true((zero[0].x - 3.0).abs() < 1.0e-12) // 零面积矩形锚在原容器原点
  // 非正值项占位同序、不占面积
  let mixed = tm_squarified_rects([0.0, 2.0], sq)
  assert_true(mixed[0].width.abs() < 1.0e-12 && mixed[0].height.abs() < 1.0e-12)
  assert_true((mixed[1].width - 10.0).abs() < 1.0e-9)
  assert_true((mixed[1].height - 10.0).abs() < 1.0e-9)
}

///|
test "tm_layout：两级嵌套（子项落父矩形内）+ 间隙留白 + 层数开关" {
  let items = [
    TmItem::make("A", value=1.0, children=[
      TmItem::make("a1", value=3.0),
      TmItem::make("a2", value=1.0),
    ]),
    TmItem::make("B", value=1.0),
  ]
  let rect : RectF = { x: 0.0, y: 0.0, width: 200.0, height: 100.0, }
  // 层数 1：只排顶层（2 项，等分定标，行贴短边 y）
  let top = tm_layout(items, rect, depth=1, gap=0.0)
  assert_eq(top.length(), 2)
  assert_true((top[0].1.width - 100.0).abs() < 1.0e-9)
  assert_true((top[0].1.height - 100.0).abs() < 1.0e-9)
  assert_true((top[1].1.x - 100.0).abs() < 1.0e-9)
  // 层数 2：顶层 2 + A 的 2 个子项 = 4 条，父先子后（depth-first 序）
  let nest = tm_layout(items, rect, depth=2, gap=0.0)
  assert_eq(nest.length(), 4)
  assert_eq(nest[0].0.name, "A")
  assert_eq(nest[1].0.name, "a1")
  assert_eq(nest[2].0.name, "a2")
  assert_eq(nest[3].0.name, "B")
  // gap=0 精确几何：A = 100×100（默认 gap=4 时为 96×96，另测），子层顶部
  // 让出 18px 名称带 → 内层 100×82 起于 y=18；[3,1] 行贴短边 y，
  // a1 = 75×82、a2 = 25×82（面积比 = 值比 3:1）
  let pa = nest[0].1
  let a1 = nest[1].1
  let a2 = nest[2].1
  assert_true((pa.x).abs() < 1.0e-9 && (pa.y).abs() < 1.0e-9)
  assert_true((pa.width - 100.0).abs() < 1.0e-9)
  assert_true((pa.height - 100.0).abs() < 1.0e-9)
  assert_true(a1.x >= pa.x - 1.0e-9 && a1.y >= pa.y + 18.0 - 1.0e-9)
  assert_true(a1.x + a1.width <= pa.x + pa.width + 1.0e-9)
  assert_true(a1.y + a1.height <= pa.y + pa.height + 1.0e-9)
  assert_true((a1.x).abs() < 1.0e-9)
  assert_true((a1.y - 18.0).abs() < 1.0e-9)
  assert_true((a1.width - 75.0).abs() < 1.0e-9)
  assert_true((a1.height - 82.0).abs() < 1.0e-9)
  assert_true((a2.x - 75.0).abs() < 1.0e-9)
  assert_true((a2.y - 18.0).abs() < 1.0e-9)
  assert_true((a2.width - 25.0).abs() < 1.0e-9)
  assert_true((a2.height - 82.0).abs() < 1.0e-9)
  // 子项面积比 = 值比 3:1（gap=0 下精确守恒）
  let r1 = a1.width * a1.height
  let r2 = a2.width * a2.height
  assert_true((r1 / r2 - 3.0).abs() < 1.0e-6)
  // 孙层空：depth=3 同 depth=2
  assert_eq(tm_layout(items, rect, depth=3, gap=0.0).length(), 4)
  // 间隙留白：gap=4 每格四边内缩 2，相邻格间留 4
  let g = tm_layout(items, rect, depth=1, gap=4.0)
  assert_true((g[0].1.x - 2.0).abs() < 1.0e-9)
  assert_true((g[0].1.y - 2.0).abs() < 1.0e-9)
  assert_true((g[0].1.width - 96.0).abs() < 1.0e-9)
  assert_true((g[0].1.height - 96.0).abs() < 1.0e-9)
  assert_true((g[1].1.x - 102.0).abs() < 1.0e-9)
  // 子层嵌套时间隙叠加：内层再内缩 2（a1 落在 (6, 24)）
  let gn = tm_layout(items, rect)
  assert_true((gn[1].1.x - 6.0).abs() < 1.0e-9)
  assert_true((gn[1].1.y - 24.0).abs() < 1.0e-9)
  // 非正值项不产出
  let z = [TmItem::make("z"), TmItem::make("y", value=-1.0)]
  assert_eq(tm_layout(z, rect).length(), 0)
  // 退化矩形容器 → 空
  assert_eq(
    tm_layout(items, { x: 0.0, y: 0.0, width: 0.0, height: 10.0, }).length(),
    0,
  )
  // 父格高度不足名称带：header 归零，子层几何仍产出（不产出生僻矩形）
  let squished = tm_layout(
    [
      TmItem::make("A", children=[
        TmItem::make("a1", value=1.0),
        TmItem::make("a2", value=1.0),
      ]),
    ],
    { x: 0.0, y: 0.0, width: 40.0, height: 12.0, },
  )
  assert_eq(squished.length(), 3) // 父 + 2 子（h=12 < 18，无名称带）
  for e in squished {
    assert_true(e.1.width >= 0.0 && e.1.height >= 0.0)
  }
}

///|
test "tm_label_lines：双行/单行/截断/退化（复用 truncate 手法）" {
  // 宽高足够：名称 + 数值
  let both = tm_label_lines("容器A", 1234.5, 120.0, 40.0)
  assert_eq(both.0, "容器A")
  assert_eq(both.1, "1234.5")
  // 高度 16..30：只给名称
  let one = tm_label_lines("容器A", 1234.5, 120.0, 24.0)
  assert_eq(one.0, "容器A")
  assert_eq(one.1, "")
  // 高度不足 16：整行不显示
  let none = tm_label_lines("容器A", 1.0, 120.0, 15.9)
  assert_eq(none.0, "")
  assert_eq(none.1, "")
  // 名称放不下（可用宽 13 ≤ truncate 阈值 8+5）：连带数值行也不显示
  let tight = tm_label_lines("abcdefghij", 1.0, 21.0, 40.0)
  assert_eq(tight.0, "")
  assert_eq(tight.1, "")
  // 名称被截断加省略号（等宽估算 7px/字符，同 charts truncate_to）
  let cut = tm_label_lines("abcdefghij", 1.0, 64.0, 40.0)
  assert_eq(cut.0, "abcdefg…")
  assert_eq(cut.1, "1")
  // 数值走 fmt_axis 多级单位缩写
  let big = tm_label_lines("n", 2.5e6, 120.0, 40.0)
  assert_eq(big.0, "n")
  assert_eq(big.1, "2.5M")
  // 名称空串：整行不显示（即便空间够）
  assert_eq(tm_label_lines("", 1.0, 120.0, 40.0).0, "")
  // 起截长度边界：可用宽 40 → max_chars = 5，7 字符应截成 "abcd…"
  let edge = tm_label_lines("abcdefg", 1.0, 48.0, 40.0)
  assert_eq(edge.0, "abcd…")
}

///|
test "tm_sibling_color：兄弟同色系不同明度（主题主色现取）" {
  let base = theme_primary()
  // n <= 1：直接主色（无兄弟可比）
  assert_eq(tm_sibling_color(0, 1), base)
  assert_eq(tm_sibling_color(3, 0), base)
  // n = 2：一亮一暗、同色相
  let c0 = tm_sibling_color(0, 2)
  let c1 = tm_sibling_color(1, 2)
  assert_true(c0 != c1)
  let hl = fn(hex : String) -> (Double, Double, Double) {
    match parse_hex(hex) {
      Some((r, g, b)) => rgb_to_hsl(r, g, b)
      None => (0.0, 0.0, 0.0)
    }
  }
  let (h0, _s0, l0) = hl(c0)
  let (h1, _s1, l1) = hl(c1)
  // 同色相：明度极值两端经 8bit 量化后 h 回读有 ~0.2° 漂移，故与基色
  // 同色系的判据用 1° 容差（远小于 HSL 60° 分档，且远大于量化噪声）
  match parse_hex(base) {
    Some((r, g, b)) => {
      let (hb, _sb, _lb) = rgb_to_hsl(r, g, b)
      assert_true((h0 - hb).abs() < 1.0 && (h1 - hb).abs() < 1.0)
    }
    None => assert_true(false)
  }
  assert_true(l0 > l1) // i 小更亮
  // n = 8：明度随 i 不增（HSL 的 L 单调不增，钳端可平台）
  let mut prev = 1.0
  for i in 0..<8 {
    let (_h, _s, l) = hl(tm_sibling_color(i, 8))
    assert_true(l <= prev)
    prev = l
  }
  assert_true(prev < l0) // 末端比首端暗
  // 下标越界钳到两端
  assert_eq(tm_sibling_color(-5, 4), tm_sibling_color(0, 4))
  assert_eq(tm_sibling_color(9, 4), tm_sibling_color(3, 4))
  // 产出形如 "#RRGGBB"（6 位）
  assert_eq(tm_sibling_color(0, 3).length(), 7)
}

///|
test "TmItem 数据经 Store 驱动：set 换表 + 订阅通知" {
  let st : Store[Array[TmItem]] = Store::new([
    TmItem::make("A", value=1.0),
    TmItem::make("B", value=2.0),
  ])
  let hits = Ref(0)
  st.subscribe(fn(_v) { hits.val = hits.val + 1 })
  st.set([TmItem::make("C", value=5.0)])
  assert_eq(hits.val, 1)
  assert_eq(st.get().length(), 1)
  assert_eq(st.get()[0].name, "C")
  assert_true((tm_value_of(st.get()[0]) - 5.0).abs() < 1.0e-12)
}

///|
test "tm_layout：大表（300 叶）面积守恒 / 不出界 / 宽高比有界" {
  let items : Array[TmItem] = []
  for i in 0..<300 {
    items.push(TmItem::make("n\{i}", value=(i % 17 + 1).to_double()))
  }
  let rect : RectF = { x: 8.0, y: 6.0, width: 560.0, height: 340.0, }
  let out = tm_layout(items, rect, depth=1, gap=0.0)
  assert_eq(out.length(), 300)
  let mut acc = 0.0
  let mut worst = 0.0
  for e in out {
    let c = e.1
    // 不出界
    assert_true(c.x >= rect.x - 1.0e-9 && c.y >= rect.y - 1.0e-9)
    assert_true(c.x + c.width <= rect.x + rect.width + 1.0e-6)
    assert_true(c.y + c.height <= rect.y + rect.height + 1.0e-6)
    acc = acc + c.width * c.height
    let r = (c.width / c.height).max(c.height / c.width)
    if r > worst {
      worst = r
    }
  }
  // 总面积守恒（定标误差在浮点噪声内）
  assert_true((acc - rect.width * rect.height).abs() < 1.0e-4)
  // squarified 优化：最差宽高比远低于朴素等分切条（≈17 档值 × 340 高）
  assert_true(worst < 60.0)
}
