// 旭日图白盒测试：纯函数（值聚合 / 树深 / 环形分段布局 / 留缝几何 /
// 文本估算 / 标签适配 / 色深渐变 / 反色文字）语义，构造器与 Store
// 驱动语义；绘制函数保证可编译（真实绘制走 on_draw，由用户真机验证）。

///|
test "sun_total：显式值优先 / 缺省取子项和 / 递归聚合 / 负值口径" {
  // 叶子：显式值即聚合值
  let leaf_a = SunItem::make("a", value=Some(30.0))
  let leaf_b = SunItem::make("b", value=Some(70.0))
  assert_true((sun_total(leaf_a) - 30.0).abs() < 1.0e-12)
  assert_true((sun_total(leaf_b) - 70.0).abs() < 1.0e-12)
  // 缺省 value：make 填子项和，聚合同值
  let parent = SunItem::make("根", children=[leaf_a, leaf_b])
  assert_true((parent.value - 100.0).abs() < 1.0e-12)
  assert_true((sun_total(parent) - 100.0).abs() < 1.0e-12)
  // 显式值 > 子项和：显式优先（残差归父段自身）
  let fixed = SunItem::make("根", value=Some(500.0), children=[leaf_a, leaf_b])
  assert_true((sun_total(fixed) - 500.0).abs() < 1.0e-12)
  // 递归：孙层仍计入
  let mid = SunItem::make("中", children=[
    SunItem::make("c", value=Some(10.0)),
    SunItem::make("d", value=Some(5.0)),
  ])
  let deep = SunItem::make("根", children=[
    SunItem::make("e", value=Some(20.0)),
    mid,
  ])
  assert_true((sun_total(deep) - 35.0).abs() < 1.0e-12)
  assert_true((sun_total(mid) - 15.0).abs() < 1.0e-12)
  // 显式 0 / 负值按缺省处理：回落到子项和；无子项为 0
  let zero = SunItem::make("根", value=Some(0.0), children=[leaf_a, leaf_b])
  assert_true((sun_total(zero) - 100.0).abs() < 1.0e-12)
  assert_eq(sun_total(SunItem::make("空")), 0.0)
  assert_eq(sun_total(SunItem::make("负", value=Some(-3.0))), 0.0)
  // 负值子项不计入（聚合恒 >= 0）
  let neg = SunItem::make("根", children=[SunItem::make("x", value=Some(-5.0))])
  assert_eq(sun_total(neg), 0.0)
}

///|
test "SunItem::make：缺省值填子项和 / 显式值原样 / 子项缺省空表" {
  let leaf = SunItem::make("叶子", value=Some(8.0))
  assert_eq(leaf.name, "叶子")
  assert_true((leaf.value - 8.0).abs() < 1.0e-12)
  assert_eq(leaf.children.length(), 0)
  let sum = SunItem::make("和", children=[
    leaf,
    SunItem::make("b", value=Some(2.0)),
  ])
  assert_true((sum.value - 10.0).abs() < 1.0e-12)
  assert_eq(sum.children.length(), 2)
  let fixed = SunItem::make("显式", value=Some(42.0), children=[leaf])
  assert_true((fixed.value - 42.0).abs() < 1.0e-12)
}

///|
test "sun_layout：三级树逐级同心环 + 每级闭合" {
  // 环数 3：第 1 级 [0,20]、第 2 级 [20,40]、第 3 级 [40,60]
  let root = SunItem::make("根", children=[
    SunItem::make("组", value=Some(10.0), children=[
      SunItem::make("细", value=Some(4.0), children=[
        SunItem::make("叶", value=Some(1.0)),
      ]),
    ]),
    SunItem::make("其余", value=Some(90.0)),
  ])
  let segs = sun_layout(root, (7.0, 8.0), 0.0, 60.0)
  assert_eq(segs.length(), 4)
  assert_eq(segs[0].depth, 1)
  assert_eq(segs[1].depth, 2)
  assert_eq(segs[2].depth, 3)
  assert_eq(segs[3].depth, 1)
  assert_true((segs[0].r_in - 0.0).abs() < 1.0e-9)
  assert_true((segs[0].r_out - 20.0).abs() < 1.0e-9)
  assert_true((segs[1].r_in - 20.0).abs() < 1.0e-9)
  assert_true((segs[1].r_out - 40.0).abs() < 1.0e-9)
  assert_true((segs[2].r_in - 40.0).abs() < 1.0e-9)
  assert_true((segs[2].r_out - 60.0).abs() < 1.0e-9)
  assert_eq(segs[0].cx, 7.0)
  assert_eq(segs[0].cy, 8.0)
  // 第 1 级两段和 = 整圈；第 2 级「细」起始角对齐「组」
  let top = segs[0].a1 - segs[0].a0 + (segs[3].a1 - segs[3].a0)
  assert_true((top - tau).abs() < 1.0e-9)
  assert_eq(segs[1].a0, segs[0].a0)
  assert_eq(segs[2].a0, segs[1].a0)
  assert_eq(segs[2].a1, segs[1].a1)
  assert_eq(segs[1].top, 0)
  assert_eq(segs[2].top, 0)
  assert_eq(segs[3].top, 3)
}

///|
test "sun_max_depth：树最大深度 = 环数" {
  assert_eq(sun_max_depth(SunItem::make("叶子", value=Some(1.0))), 0)
  let l1 = SunItem::make("根", children=[
    SunItem::make("a", value=Some(1.0)),
    SunItem::make("b", value=Some(1.0)),
  ])
  assert_eq(sun_max_depth(l1), 1)
  let l2 = SunItem::make("根", children=[
    SunItem::make("a", value=Some(1.0)),
    SunItem::make("组", children=[SunItem::make("x", value=Some(1.0))]),
  ])
  assert_eq(sun_max_depth(l2), 2)
  let l3 = SunItem::make("根", children=[
    SunItem::make("组", children=[
      SunItem::make("细", children=[SunItem::make("叶", value=Some(1.0))]),
    ]),
  ])
  assert_eq(sun_max_depth(l3), 3)
  // 空节点不计深度（无子项）
  assert_eq(sun_max_depth(SunItem::make("空", children=[])), 0)
}

///|
test "sun_layout：顶层角度分配和 = 360 度闭合 / 12 点方向起始" {
  let root = SunItem::make("根", children=[
    SunItem::make("华东", value=Some(30.0), children=[
      SunItem::make("上海", value=Some(20.0)),
      SunItem::make("江苏", value=Some(10.0)),
    ]),
    SunItem::make("华南", value=Some(70.0)),
  ])
  let segs = sun_layout(root, (100.0, 100.0), 20.0, 100.0)
  // 深度优先序：父段下标恒小于子段
  assert_eq(segs.length(), 4)
  for i, seg in segs {
    if seg.parent >= 0 {
      assert_true(seg.parent < i)
    }
  }
  // 圆心与层级/值量纲
  assert_eq(segs[0].cx, 100.0)
  assert_eq(segs[0].cy, 100.0)
  assert_eq(segs[0].depth, 1)
  assert_true((segs[0].value - 30.0).abs() < 1.0e-12)
  assert_eq(segs[3].depth, 1)
  assert_true((segs[3].value - 70.0).abs() < 1.0e-12)
  assert_eq(segs[1].depth, 2)
  assert_true((segs[1].value - 20.0).abs() < 1.0e-12)
  assert_true((segs[2].value - 10.0).abs() < 1.0e-12)
  // 起始角：根段自 12 点方向（-π/2）起
  assert_true((segs[0].a0 - -pi / 2.0).abs() < 1.0e-12)
  // 顶层两段：30% / 70%
  assert_true((segs[0].a1 - segs[0].a0 - tau * 0.3).abs() < 1.0e-12)
  assert_true((segs[3].a1 - segs[3].a0 - tau * 0.7).abs() < 1.0e-12)
  // 闭合：顶层扫角和 = 整圈（末段终止角精确收到根段末端）
  let top_sum = segs[0].a1 - segs[0].a0 + (segs[3].a1 - segs[3].a0)
  assert_true((top_sum - tau).abs() < 1.0e-9)
  assert_true((segs[3].a1 - (-pi / 2.0 + tau)).abs() < 1.0e-12)
  // 环半径：环数 = 树深 2，[r0, r1] 均分两级
  assert_true((segs[0].r_in - 20.0).abs() < 1.0e-9)
  assert_true((segs[0].r_out - 60.0).abs() < 1.0e-9)
  assert_true((segs[1].r_in - 60.0).abs() < 1.0e-9)
  assert_true((segs[1].r_out - 100.0).abs() < 1.0e-9)
  assert_true(segs[1].r_out > segs[1].r_in)
}

///|
test "sun_layout：父子角度对齐（首子段对齐父段起、末子段对齐父段止）" {
  let root = SunItem::make("根", children=[
    SunItem::make("组", value=Some(40.0), children=[
      SunItem::make("x", value=Some(25.0)),
      SunItem::make("y", value=Some(75.0)),
    ]),
    SunItem::make("其余", value=Some(60.0)),
  ])
  let segs = sun_layout(root, (0.0, 0.0), 10.0, 90.0)
  // 序：[组(0), x(1), y(2), 其余(3)]
  assert_eq(segs.length(), 4)
  // 父子对齐：x 的起 = 组的起；y 的止 = 组的止（位级一致）
  assert_eq(segs[1].a0, segs[0].a0)
  assert_eq(segs[2].a1, segs[0].a1)
  // x/y 沿父段顺序排布、互不相交（x 的止 = y 的起）
  assert_true((segs[1].a1 - segs[2].a0).abs() < 1.0e-9)
  assert_true(segs[1].a0 < segs[1].a1 && segs[1].a1 <= segs[2].a1)
  // 组内占比 25:75（份额按组内聚合值）
  let ps = segs[0].a1 - segs[0].a0
  assert_true((segs[1].a1 - segs[1].a0 - ps * 0.25).abs() < 1.0e-12)
  assert_true((segs[2].a1 - segs[2].a0 - ps * 0.75).abs() < 1.0e-12)
  // 父段索引与顶层归属
  assert_eq(segs[0].parent, -1)
  assert_eq(segs[1].parent, 0)
  assert_eq(segs[2].parent, 0)
  assert_eq(segs[3].parent, -1)
  assert_eq(segs[0].top, 0)
  assert_eq(segs[3].top, 3)
  assert_eq(segs[1].top, 0)
  assert_eq(segs[2].top, 0)
}

///|
test "sun_layout：显式父值与子项和不一致时残差归父段（子段仍闭合整圈）" {
  // 根显式 999，子项 25/75：子项按份额瓜分整圈，不摊薄
  let root = SunItem::make("根", value=Some(999.0), children=[
    SunItem::make("a", value=Some(25.0)),
    SunItem::make("b", value=Some(75.0)),
  ])
  let segs = sun_layout(root, (50.0, 50.0), 0.0, 100.0)
  assert_eq(segs.length(), 2)
  assert_true((segs[0].a1 - segs[0].a0 - tau * 0.25).abs() < 1.0e-12)
  assert_true((segs[1].a1 - segs[1].a0 - tau * 0.75).abs() < 1.0e-12)
  assert_true((segs[1].a1 - (-pi / 2.0 + tau)).abs() < 1.0e-12)
  // 唯一子项独占整圈
  let one = SunItem::make("根", children=[
    SunItem::make("唯", value=Some(7.0)),
  ])
  let solo = sun_layout(one, (0.0, 0.0), 10.0, 50.0)
  assert_eq(solo.length(), 1)
  assert_true((solo[0].a0 - -pi / 2.0).abs() < 1.0e-12)
  assert_true((solo[0].a1 - (-pi / 2.0 + tau)).abs() < 1.0e-9)
}

///|
test "sun_layout：零值子项不占角度 / 零值父回落子项和 / 空表退化" {
  // b 无值无子项（聚合 0）：不产出分段也不占角度
  let root = SunItem::make("根", children=[
    SunItem::make("a", value=Some(10.0)),
    SunItem::make("b"),
    SunItem::make("c", value=Some(30.0)),
  ])
  let segs = sun_layout(root, (0.0, 0.0), 5.0, 55.0)
  assert_eq(segs.length(), 2)
  assert_eq(segs[0].name, "a")
  assert_eq(segs[1].name, "c")
  assert_true((segs[0].a1 - segs[0].a0 - tau * 0.25).abs() < 1.0e-12)
  assert_true((segs[1].a1 - segs[1].a0 - tau * 0.75).abs() < 1.0e-12)
  // 组显式 0、子项 4/6：聚合回落子项和 10，段照常产出
  let grp = SunItem::make("组", value=Some(0.0), children=[
    SunItem::make("x", value=Some(4.0)),
    SunItem::make("y", value=Some(6.0)),
  ])
  let root2 = SunItem::make("根", children=[
    SunItem::make("a", value=Some(90.0)),
    grp,
  ])
  let segs2 = sun_layout(root2, (0.0, 0.0), 5.0, 55.0)
  assert_eq(segs2.length(), 4)
  assert_true((segs2[1].value - 10.0).abs() < 1.0e-12)
  let gs = segs2[1].a1 - segs2[1].a0
  assert_true((segs2[2].a1 - segs2[2].a0 - gs * 0.4).abs() < 1.0e-12)
  assert_true((segs2[3].a1 - segs2[3].a0 - gs * 0.6).abs() < 1.0e-12)
  // 空表退化：无子项 / 总值 <= 0 / 负值
  assert_eq(
    sun_layout(SunItem::make("单点", value=Some(5.0)), (0.0, 0.0), 5.0, 55.0).length(),
    0,
  )
  assert_eq(sun_layout(SunItem::make("空"), (0.0, 0.0), 5.0, 55.0).length(), 0)
  assert_eq(
    sun_layout(
      SunItem::make("根", children=[SunItem::make("x", value=Some(-1.0))]),
      (0.0, 0.0),
      5.0,
      55.0,
    ).length(),
    0,
  )
}

///|
test "sun_layout：半径钳制（r0 负值归 0 / r1 < r0 环厚为 0）" {
  let root = SunItem::make("根", children=[
    SunItem::make("a", value=Some(1.0)),
    SunItem::make("b", value=Some(1.0)),
  ])
  // r0 负：内半径钳 0，单级树环数 1，环铺满 [0, r1]
  let neg = sun_layout(root, (1.0, 2.0), -5.0, 50.0)
  assert_true((neg[0].r_in - 0.0).abs() < 1.0e-9)
  assert_true((neg[0].r_out - 50.0).abs() < 1.0e-9)
  assert_eq(neg[0].cx, 1.0)
  assert_eq(neg[0].cy, 2.0)
  // r1 < r0：环厚 0，角度分配照常闭合
  let inv = sun_layout(root, (0.0, 0.0), 50.0, 10.0)
  assert_eq(inv.length(), 2)
  assert_true((inv[0].r_in - 50.0).abs() < 1.0e-9)
  assert_eq(inv[0].r_in, inv[0].r_out)
  assert_true((inv[1].a1 - (-pi / 2.0 + tau)).abs() < 1.0e-12)
}

///|
test "sun_seam：角度留缝（两端各半缝 / 无剩余 None / 半径钳制）" {
  // gap=1.6、rm=100：半缝角 0.008，两端各让
  match sun_seam(0.0, 1.0, 100.0) {
    None => fail("应留缝后仍可画")
    Some((a0, a1)) => {
      assert_true((a0 - 0.008).abs() < 1.0e-12)
      assert_true((a1 - 0.992).abs() < 1.0e-12)
      // 缝宽合计 = gap / rm
      assert_true((a1 - a0 - (1.0 - 1.6 / 100.0)).abs() < 1.0e-12)
    }
  }
  // sweep 已不足两个半缝：无剩余，None（该段不画）
  assert_true(sun_seam(0.0, 0.015, 100.0) == None)
  assert_true(sun_seam(0.0, 0.02, 100.0) != None)
  // rm <= 1 钳到 1：半缝角 = gap/2（不按 rm 放大）
  match sun_seam(0.0, 3.0, 0.5) {
    None => fail("钳制后应仍可画")
    Some((a0, a1)) => {
      assert_true((a0 - 0.8).abs() < 1.0e-12)
      assert_true((a1 - 2.2).abs() < 1.0e-12)
    }
  }
  // gap=0：原样透传；sweep=0：None
  match sun_seam(0.25, 0.75, 30.0, gap=0.0) {
    None => fail("gap=0 应透传")
    Some((a0, a1)) => {
      assert_eq(a0, 0.25)
      assert_eq(a1, 0.75)
    }
  }
  assert_true(sun_seam(1.0, 1.0, 30.0) == None)
}

///|
test "sun_radial_gap：环间留缝（半径对称内缩 / 环厚不足 None）" {
  match sun_radial_gap(10.0, 30.0) {
    None => fail("环厚足够应可画")
    Some((ri, ro)) => {
      assert_true((ri - 10.4).abs() < 1.0e-9)
      assert_true((ro - 29.6).abs() < 1.0e-9)
    }
  }
  // 环厚恰好 = gap：无剩余（0.8 加 1e-9 容差，浮点边界不翻车）
  assert_true(sun_radial_gap(10.0, 10.8) == None)
  // 略大于 gap：内缩后仍为正宽度
  match sun_radial_gap(10.0, 10.9) {
    None => fail("环厚略大于缝宽应可画")
    Some((ri, ro)) => assert_true(ri > 10.0 && ro < 10.9 && ro > ri)
  }
  // 退化：零厚 / 负厚
  assert_true(sun_radial_gap(10.0, 10.0) == None)
  assert_true(sun_radial_gap(30.0, 10.0) == None)
  // gap=0：原样透传
  match sun_radial_gap(10.0, 30.0, gap=0.0) {
    None => fail("gap=0 应透传")
    Some((ri, ro)) => {
      assert_eq(ri, 10.0)
      assert_eq(ro, 30.0)
    }
  }
}

///|
test "sun_text_units：CJK 全角按 2 字宽 / 半角按 1" {
  assert_eq(sun_text_units(""), 0)
  assert_eq(sun_text_units("abc"), 3)
  assert_eq(sun_text_units("旭日图"), 6)
  assert_eq(sun_text_units("旭a"), 3)
  assert_eq(sun_text_units("A-1"), 3)
  // 全角区界外一位（· 为半角）
  assert_eq(sun_text_units("a·b"), 3)
}

///|
test "sun_label_fits：弧长与环厚双条件 / 半径钳制" {
  // 「上海」4 字宽 → 需 38px；sweep=π/4、rm=60 → 弧长 47px，环厚 30 → 放得下
  assert_true(sun_label_fits("上海", tau / 8.0, 60.0, 30.0))
  // 环厚不足 15px：放不下
  assert_false(sun_label_fits("上海", tau / 8.0, 60.0, 14.0))
  // 弧长不足：放不下
  assert_false(sun_label_fits("上海", 0.05, 60.0, 30.0))
  // rm <= 1 钳到 1（弧长 = sweep）
  assert_true(sun_label_fits("上海", 40.0, 0.5, 16.0))
  assert_false(sun_label_fits("上海", 30.0, 0.5, 16.0))
  // 长名（「旭日图测试」10 字宽需 80px）在宽弧放下、窄弧放不下
  assert_true(sun_label_fits("旭日图测试", tau / 4.0, 60.0, 20.0))
  assert_false(sun_label_fits("旭日图测试", tau / 24.0, 60.0, 20.0))
}

///|
test "sun_shade：第 1 级原色 / 逐层提亮 7% / 上限 35%" {
  assert_eq(sun_shade("#808080", 1), "#808080")
  assert_eq(sun_shade("#808080", 0), "#808080") // depth < 1 按 1
  assert_eq(sun_shade("#808080", -3), "#808080")
  assert_eq(sun_shade("#808080", 2), "#929292") // +0.07 → 146
  assert_eq(sun_shade("#808080", 4), "#b6b6b6") // +0.21 → 182
  assert_eq(sun_shade("#808080", 5), "#c7c7c7") // +0.28 → 199
  assert_eq(sun_shade("#808080", 6), "#d9d9d9") // +0.35 → 217（触顶）
  assert_eq(sun_shade("#808080", 20), "#d9d9d9") // 钳在 0.35
}

///|
test "sun_text_on：按填充亮度挑深字 / 白字 / 解析失败兜底" {
  assert_eq(sun_text_on("#FFFFFF"), "#1D2129") // 亮底深字
  assert_eq(sun_text_on("#FFC800"), "#1D2129")
  assert_eq(sun_text_on("#000000"), "#FFFFFF") // 暗底白字
  assert_eq(sun_text_on("#1E88E5"), "#FFFFFF")
  assert_eq(sun_text_on("#808080"), "#FFFFFF") // 128 < 150
  assert_eq(sun_text_on("oops"), "#FFFFFF") // 非法输入兜底
  assert_eq(sun_text_on("12345"), "#FFFFFF") // 位数不足解析失败
}

///|
test "SunItem Store 驱动：set 换树根 / 订阅通知一次" {
  let s : @yue.Store[SunItem] = @yue.Store::new(SunItem::make("空"))
  assert_eq(s.get().name, "空")
  let hits = Ref(0)
  s.subscribe(fn(_v) { hits.val = hits.val + 1 })
  s.set(
    SunItem::make("根", children=[
      SunItem::make("华东", value=Some(30.0)),
      SunItem::make("华南", value=Some(70.0)),
    ]),
  )
  assert_eq(hits.val, 1)
  assert_eq(s.get().children.length(), 2)
  assert_true((sun_total(s.get()) - 100.0).abs() < 1.0e-12)
  // 换树根后布局跟随（顶层两段各半圈）
  let segs = sun_layout(s.get(), (0.0, 0.0), 10.0, 50.0)
  assert_eq(segs.length(), 2)
  assert_true((segs[0].a1 - segs[0].a0 - tau * 0.3).abs() < 1.0e-12)
}
