// 树图白盒测试：纯函数（子树深度 / 叶子数 / 峰值 / 叶槽位均分 / 圆点
// 半径 / 分层布局几何 / 形态开关）语义，绘制函数保证可编译（真实绘制
// 走 on_draw，由用户真机验证）。

///|
/// 测试样本树（DFS 后序展开为 a1,a2,a,b1,b2,b,root；值：a=4,b=8，
/// 叶与根无值→等大最小圆点）。
fn tree_sample() -> TreeItem {
  let root = TreeItem::make("root")
  let a = TreeItem::make("a", value=Some(4.0))
  root.children.push(a)
  let b = TreeItem::make("b", value=Some(8.0))
  root.children.push(b)
  a.children.push(TreeItem::make("a1"))
  a.children.push(TreeItem::make("a2"))
  b.children.push(TreeItem::make("b1"))
  b.children.push(TreeItem::make("b2"))
  root
}

///|
test "TreeItem 构造 / 子列表可变 / Store 驱动" {
  let solo = TreeItem::make("单点")
  assert_eq(solo.name, "单点")
  assert_eq(solo.value, None)
  assert_eq(solo.children.length(), 0)
  let with_val = TreeItem::make("带值", value=Some(6.0))
  assert_eq(with_val.value, Some(6.0))
  // children 可变：直接 push 增子树
  let a = TreeItem::make("a")
  let b = TreeItem::make("b")
  a.children.push(TreeItem::make("a1"))
  a.children.push(b)
  assert_eq(a.children.length(), 2)
  assert_eq(a.children[1].name, "b")
  // Store 驱动：set 换整表（子树已在引用内改好），订阅收到通知
  let st : @yue.Store[TreeItem] = @yue.Store::new(solo)
  let hits = Ref(0)
  st.subscribe(fn(_r) { hits.val = hits.val + 1 })
  st.set(with_val)
  st.set(tree_sample())
  assert_eq(hits.val, 2)
  assert_eq(st.get().name, "root")
  assert_eq(st.get().children.length(), 2)
}

///|
test "tree_depth / tree_leaf_count / tree_max_value：高度 / 叶子数 / 峰值" {
  let root = tree_sample()
  assert_eq(tree_depth(root), 2) // root→a→a1 两层边
  assert_eq(tree_leaf_count(root), 4)
  assert_true((tree_max_value(root) - 8.0).abs() < 1.0e-12)
  // 单点树：高度 0、叶子 1
  let solo = TreeItem::make("solo")
  assert_eq(tree_depth(solo), 0)
  assert_eq(tree_leaf_count(solo), 1)
  // 全无正值（None / 负值）→ 峰值 0（退化为等大圆点）
  let no_val = TreeItem::make("x", value=Some(-3.0))
  no_val.children.push(TreeItem::make("y"))
  assert_eq(tree_max_value(no_val), 0.0)
  // 不等高子树取最大高度
  let top = TreeItem::make("top")
  top.children.push(TreeItem::make("shallow"))
  let deep = TreeItem::make("deep")
  deep.children.push(TreeItem::make("d1"))
  deep.children[0].children.push(TreeItem::make("d2"))
  top.children.push(deep)
  assert_eq(tree_depth(top), 3)
  assert_eq(tree_leaf_count(top), 2) // 叶子仅 shallow、d2（d1 非叶）
}

///|
test "tree_leaf_slot：叶节点区间均分 / 单点居中 / 退化" {
  // 4 叶均分 [0,200]：槽位中心 25/75/125/175
  assert_true((tree_leaf_slot(0, 4, 0.0, 200.0) - 25.0).abs() < 1.0e-9)
  assert_true((tree_leaf_slot(1, 4, 0.0, 200.0) - 75.0).abs() < 1.0e-9)
  assert_true((tree_leaf_slot(2, 4, 0.0, 200.0) - 125.0).abs() < 1.0e-9)
  assert_true((tree_leaf_slot(3, 4, 0.0, 200.0) - 175.0).abs() < 1.0e-9)
  // 单叶：区间中心
  assert_true((tree_leaf_slot(0, 1, 10.0, 100.0) - 60.0).abs() < 1.0e-9)
  // 非零起点：[100,300] 两叶 → 150/250
  assert_true((tree_leaf_slot(0, 2, 100.0, 200.0) - 150.0).abs() < 1.0e-9)
  assert_true((tree_leaf_slot(1, 2, 100.0, 200.0) - 250.0).abs() < 1.0e-9)
  // 退化：n<=0 或越界 → 区间中点
  assert_true((tree_leaf_slot(0, 0, 0.0, 200.0) - 100.0).abs() < 1.0e-9)
  assert_true((tree_leaf_slot(9, 4, 0.0, 200.0) - 100.0).abs() < 1.0e-9)
  assert_true((tree_leaf_slot(-1, 4, 0.0, 200.0) - 100.0).abs() < 1.0e-9)
}

///|
test "tree_dot_radius：无 value 等大 / 圆点∝value / 钳制 / 自定义量程" {
  // 全树无值（max_value<=0）：一律 min_r 等大
  assert_true((tree_dot_radius(None, 0.0) - 4.0).abs() < 1.0e-12)
  assert_true((tree_dot_radius(Some(5.0), 0.0) - 4.0).abs() < 1.0e-12)
  // 有值：∝ value/max_value，在 [4,10] 间线性
  assert_true((tree_dot_radius(Some(4.0), 8.0) - 7.0).abs() < 1.0e-12)
  assert_true((tree_dot_radius(Some(8.0), 8.0) - 10.0).abs() < 1.0e-12)
  assert_true((tree_dot_radius(Some(2.0), 8.0) - 5.5).abs() < 1.0e-12)
  // None 节点在一棵有值树里取最小半径（不与叶混淆）
  assert_true((tree_dot_radius(None, 8.0) - 4.0).abs() < 1.0e-12)
  // 超满 / 负值钳制
  assert_true((tree_dot_radius(Some(99.0), 8.0) - 10.0).abs() < 1.0e-12)
  assert_true((tree_dot_radius(Some(-1.0), 8.0) - 4.0).abs() < 1.0e-12)
  // 自定义量程
  assert_true(
    (tree_dot_radius(Some(5.0), 10.0, min_r=2.0, max_r=8.0) - 5.0).abs() <
    1.0e-12,
  )
  assert_true(
    (tree_dot_radius(Some(10.0), 10.0, min_r=2.0, max_r=8.0) - 8.0).abs() <
    1.0e-12,
  )
  // 量程倒置时自动交换
  assert_true(
    (tree_dot_radius(Some(5.0), 10.0, min_r=8.0, max_r=2.0) - 5.0).abs() <
    1.0e-12,
  )
}

///|
test "tree_vertical：纵向开关" {
  assert_true(tree_vertical("vertical"))
  assert_false(tree_vertical("horizontal"))
  assert_false(tree_vertical("")) // 默认横向
  assert_false(tree_vertical("VERTICAL")) // 大小写敏感
  assert_false(tree_vertical("vertical "))
}

///|
test "tree_layout 横向：叶纵向均分 + 父取子中点 + x 按深度分层" {
  let lay = tree_layout(tree_sample(), 0.0, 0.0, 100.0, 200.0)
  assert_eq(lay.max_depth, 2)
  assert_eq(lay.boxes.length(), 7) // 2 内部 + 4 叶 + 根
  assert_eq(lay.edges.length(), 6) // 树的不变式：边 = 节点 - 1
  // boxes 为 DFS 后序（先子后父）：a1,a2,a,b1,b2,b,root
  let leaf_xs : Array[Double] = []
  for i in 0..<7 {
    leaf_xs.push(if lay.boxes[i].is_leaf { lay.boxes[i].x } else { -1.0 })
  }
  let depths = [2, 2, 1, 2, 2, 1, 0]
  for i in 0..<7 {
    assert_eq(lay.boxes[i].depth, depths[i])
    // 叶节点：x 贴最深层（x1），横铺坐标按槽位均分
    if lay.boxes[i].is_leaf {
      assert_true((lay.boxes[i].x - 100.0).abs() < 1.0e-9)
    }
  }
  assert_true((leaf_xs[0] - 100.0).abs() < 1.0e-9)
  let ys = [25.0, 75.0, 50.0, 125.0, 175.0, 150.0, 100.0]
  for i in 0..<7 {
    assert_true((lay.boxes[i].y - ys[i]).abs() < 1.0e-9)
  }
  // 深度分层：根 x=0、内部层 x0+(x1-x0)*d/max_depth
  assert_true((lay.boxes[6].x - 0.0).abs() < 1.0e-9) // 根
  assert_true((lay.boxes[2].x - 50.0).abs() < 1.0e-9) // a（depth 1）
  assert_true((lay.boxes[5].x - 50.0).abs() < 1.0e-9) // b（depth 1）
  // 圆点 ∝ value：a(4/8)=7、b(8/8)=10、叶与根等大最小 4
  assert_true((lay.boxes[2].r - 7.0).abs() < 1.0e-9)
  assert_true((lay.boxes[5].r - 10.0).abs() < 1.0e-9)
  assert_true((lay.boxes[0].r - 4.0).abs() < 1.0e-9)
  assert_true((lay.boxes[6].r - 4.0).abs() < 1.0e-9)
  // 连线直角肘线：边按「子树边先于父边」排列
  // e0/e1：a(50,50)→a1/a2(100, 25/75)，中点横 75
  let e0 = lay.edges[0].pts
  assert_eq(e0.length(), 4)
  assert_eq(e0[0], (50.0, 50.0))
  assert_eq(e0[1], (75.0, 50.0))
  assert_eq(e0[2], (75.0, 25.0))
  assert_eq(e0[3], (100.0, 25.0))
  let e1 = lay.edges[1].pts
  assert_eq(e1[3], (100.0, 75.0)) // a2
  // e4/e5：root(0,100)→a(50,50) / b(50,150)，中点横 25
  let e4 = lay.edges[4].pts
  assert_eq(e4[0], (0.0, 100.0))
  assert_eq(e4[1], (25.0, 100.0))
  assert_eq(e4[2], (25.0, 50.0))
  assert_eq(e4[3], (50.0, 50.0))
  let e5 = lay.edges[5].pts
  assert_eq(e5[0], (0.0, 100.0))
  assert_eq(e5[2], (25.0, 150.0))
  assert_eq(e5[3], (50.0, 150.0))
}

///|
test "tree_layout 纵向：叶横向均分 + 父取子中点 + y 按深度分层" {
  let lay = tree_layout(tree_sample(), 0.0, 0.0, 200.0, 100.0, vertical=true)
  assert_eq(lay.max_depth, 2)
  assert_eq(lay.boxes.length(), 7)
  assert_eq(lay.edges.length(), 6)
  // DFS 后序同横向；横铺轴换到 x：叶均分 25/75/125/175，y 贴最深层 100
  let xs = [25.0, 75.0, 50.0, 125.0, 175.0, 150.0, 100.0]
  let ys = [100.0, 100.0, 50.0, 100.0, 100.0, 50.0, 0.0]
  for i in 0..<7 {
    assert_true((lay.boxes[i].x - xs[i]).abs() < 1.0e-9)
    assert_true((lay.boxes[i].y - ys[i]).abs() < 1.0e-9)
  }
  // 肘线换成纵向拐点：root(100,0)→a(50,50)，中点纵 25
  let e4 = lay.edges[4].pts
  assert_eq(e4[0], (100.0, 0.0))
  assert_eq(e4[1], (100.0, 25.0))
  assert_eq(e4[2], (50.0, 25.0))
  assert_eq(e4[3], (50.0, 50.0))
  // 半径口径与横向一致
  assert_true((lay.boxes[2].r - 7.0).abs() < 1.0e-9)
  assert_true((lay.boxes[5].r - 10.0).abs() < 1.0e-9)
}

///|
test "tree_layout 退化：单点树 / 空名空子空树 / 区间反向 / 无值等大" {
  // 单点树：无连线，节点落在分层起点 + 横铺中点
  let solo = tree_layout(TreeItem::make("solo"), 10.0, 20.0, 110.0, 120.0)
  assert_eq(solo.max_depth, 0)
  assert_eq(solo.boxes.length(), 1)
  assert_eq(solo.edges.length(), 0)
  assert_true((solo.boxes[0].x - 10.0).abs() < 1.0e-9)
  assert_true((solo.boxes[0].y - 70.0).abs() < 1.0e-9)
  assert_true((solo.boxes[0].r - 4.0).abs() < 1.0e-9) // 无值等大
  // 非零起点非零 span 的单点树：横铺中点 = start + span/2
  let solo2 = tree_layout(TreeItem::make("solo"), 100.0, 0.0, 300.0, 200.0)
  assert_true((solo2.boxes[0].y - 100.0).abs() < 1.0e-9)
  // 区间反向（x1<x0）：坐标单调可推、不崩
  let rev = tree_layout(tree_sample(), 100.0, 0.0, 0.0, 200.0)
  assert_eq(rev.boxes.length(), 7)
  assert_true((rev.boxes[6].x - 100.0).abs() < 1.0e-9) // 根贴 x0
  assert_true((rev.boxes[0].x - 0.0).abs() < 1.0e-9) // 叶贴 x1
  // 全树无值：所有圆点等大（最小半径）
  let noval = TreeItem::make("r")
  noval.children.push(TreeItem::make("c1"))
  noval.children.push(TreeItem::make("c2"))
  let l2 = tree_layout(noval, 0.0, 0.0, 100.0, 100.0)
  for b in l2.boxes {
    assert_true((b.r - 4.0).abs() < 1.0e-9)
  }
}

///|
test "tree_names：DFS 后序展开与 boxes 同序" {
  let root = tree_sample()
  let lay = tree_layout(root, 0.0, 0.0, 100.0, 200.0)
  let names = tree_names(root)
  assert_eq(names.length(), lay.boxes.length())
  let want = ["a1", "a2", "a", "b1", "b2", "b", "root"]
  for i in 0..<7 {
    assert_eq(names[i], want[i])
    // 同名 box 的 is_leaf 与展开语义一致：内部节点 a/b/root 非叶
    if want[i] == "a" || want[i] == "b" || want[i] == "root" {
      assert_false(lay.boxes[i].is_leaf)
    } else {
      assert_true(lay.boxes[i].is_leaf)
    }
  }
}
