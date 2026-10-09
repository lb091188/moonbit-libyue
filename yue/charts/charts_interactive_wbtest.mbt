// 图表交互层白盒测试:DataZoom 窗口数学(归一/缩放锚点/平移边界/可见
// 区间)、VisualMap 色带、图例命中、显隐位与切片工具、导出格式校验。
// 纯函数,无 GUI 依赖;mark 绘制辅助与 ci_legend/ci_tooltip 组件层需
// 真机验证,不在此列(导出写盘仅 Windows 可用,不执行)。

///|
test "ci_zoom_normalize:互换/越界/零跨度撑开" {
  assert_eq(ci_zoom_normalize(100.0, 0.0), (0.0, 100.0))
  assert_eq(ci_zoom_normalize(30.0, 20.0), (20.0, 30.0))
  assert_eq(ci_zoom_normalize(-10.0, 50.0), (0.0, 50.0))
  assert_eq(ci_zoom_normalize(60.0, 500.0), (60.0, 100.0))
  // 零/窄跨度:以中点为心撑到 1%
  assert_eq(ci_zoom_normalize(50.0, 50.0), (49.5, 50.5))
  assert_eq(ci_zoom_normalize(0.0, 0.5), (0.0, 1.0))
  // 贴右上角:撑开后回贴 100
  assert_eq(ci_zoom_normalize(99.9, 99.95), (99.0, 100.0))
}

///|
test "ci_zoom_make/set/reset:构造/设窗/最小跨度/复位" {
  let z = ci_zoom_make()
  assert_eq((z.start, z.end), (0.0, 100.0))
  ci_zoom_set(z, 30.0, 70.0)
  assert_eq((z.start, z.end), (30.0, 70.0))
  assert_eq(ci_zoom_span(z), 40.0)
  // 窄于 min_span:以中点为心撑到 5
  ci_zoom_set(z, 50.0, 50.0)
  assert_eq((z.start, z.end), (47.5, 52.5))
  // 贴边撑开:左缘
  ci_zoom_set(z, 0.0, 3.0, min_span=5.0)
  assert_eq((z.start, z.end), (0.0, 5.0))
  // 越界输入:归一后贴右边
  ci_zoom_set(z, 200.0, 300.0)
  assert_eq((z.start, z.end), (95.0, 100.0))
  ci_zoom_reset(z)
  assert_eq((z.start, z.end), (0.0, 100.0))
}

///|
test "ci_zoom_wheel:以鼠标为锚点缩放(锚点不变式)" {
  // 全窗中心锚点上滚放大(step 0.2):跨度 80,锚点留在窗中点
  let z = ci_zoom_make()
  ci_zoom_wheel(z, 50.0, -1.0)
  assert_eq((z.start, z.end), (10.0, 90.0))
  // 锚点 25%:放大后锚点仍在窗内 25% 处
  let z2 = ci_zoom_make()
  ci_zoom_wheel(z2, 25.0, -1.0)
  assert_eq((z2.start, z2.end), (5.0, 85.0))
  let t = (25.0 - z2.start) / ci_zoom_span(z2)
  assert_true((t - 0.25).abs() < 1.0e-9)
  // 下滚缩小:跨度 96,仍以锚点为中心
  ci_zoom_wheel(z, 50.0, 1.0)
  assert_eq((z.start, z.end), (2.0, 98.0))
  // 锚点贴右缘:连续放大钉在 100 边界(锚点滑动到贴边)
  let zr = ci_zoom_make(end=50.0)
  ci_zoom_wheel(zr, 50.0, -1.0)
  assert_eq((zr.start, zr.end), (10.0, 50.0))
  ci_zoom_wheel(zr, 50.0, -1.0)
  assert_eq((zr.start, zr.end), (18.0, 50.0))
  // 锚点贴左缘:钉在 0 边界
  let zl = ci_zoom_make(start=50.0)
  ci_zoom_wheel(zl, 50.0, -1.0)
  assert_eq((zl.start, zl.end), (50.0, 90.0))
  // 最小跨度兜底:放大不超过 min_span
  let zm = ci_zoom_make()
  ci_zoom_wheel(zm, 50.0, -1.0, min_span=90.0)
  assert_eq((zm.start, zm.end), (5.0, 95.0))
  // 锚点钳到窗外(0..100):t=10 → 起点 100-10*8=20
  let zo = ci_zoom_make(end=10.0)
  ci_zoom_wheel(zo, 300.0, -1.0)
  assert_eq((zo.start, zo.end), (20.0, 28.0))
  // 零跨度退化:不动
  let zd : CiZoom = { start: 50.0, end: 50.0, }
  ci_zoom_wheel(zd, 50.0, -1.0)
  assert_eq((zd.start, zd.end), (50.0, 50.0))
}

///|
test "ci_zoom_pan:平移保跨度 + 边界停住" {
  let z = ci_zoom_make(end=50.0)
  ci_zoom_pan(z, 10.0)
  assert_eq((z.start, z.end), (10.0, 60.0))
  // 右边界:贴 100 停住
  ci_zoom_pan(z, 100.0)
  assert_eq((z.start, z.end), (50.0, 100.0))
  // 左边界:贴 0 停住
  ci_zoom_pan(z, -100.0)
  assert_eq((z.start, z.end), (0.0, 50.0))
  // 全窗平移无位移
  let zf = ci_zoom_make()
  ci_zoom_pan(zf, 10.0)
  assert_eq((zf.start, zf.end), (0.0, 100.0))
}

///|
test "ci_zoom_visible:窗 → 可见序号闭区间" {
  let z = ci_zoom_make()
  assert_eq(ci_zoom_visible(z, 10), (0, 9))
  assert_eq(ci_zoom_visible(z, 1), (0, 0))
  assert_eq(ci_zoom_visible(z, 0), (0, -1))
  let z2 = ci_zoom_make(start=25.0, end=75.0)
  assert_eq(ci_zoom_visible(z2, 10), (2, 7))
  // 极窄窗也至少含一点
  let z3 = ci_zoom_make(start=50.0, end=51.0)
  assert_eq(ci_zoom_visible(z3, 10), (5, 5))
  assert_eq(ci_zoom_visible(z3, 3), (1, 1))
}

///|
test "ci_visual_map:两色带/三色带/量程归一" {
  // 归一分数
  assert_eq(ci_visual_map_frac(5.0, 0.0, 10.0), 0.5)
  assert_eq(ci_visual_map_frac(-5.0, 0.0, 10.0), 0.0)
  assert_eq(ci_visual_map_frac(15.0, 0.0, 10.0), 1.0)
  assert_eq(ci_visual_map_frac(5.0, 5.0, 5.0), 0.0)
  // 两色带:端点与中点(mix_hex 线性,小写 hex)
  let vm = ci_visual_map_make(0.0, 10.0, "#000000", "#ffffff")
  assert_eq(vm.color(0.0), "#000000")
  assert_eq(vm.color(10.0), "#ffffff")
  assert_eq(vm.color(5.0), "#808080")
  assert_eq(vm.color(-3.0), "#000000")
  assert_eq(vm.color(99.0), "#ffffff")
  // 量程无序自动互换
  let vm2 = ci_visual_map_make(10.0, 0.0, "#000000", "#ffffff")
  assert_eq(vm2.color(0.0), "#000000")
  assert_eq(vm2.color(10.0), "#ffffff")
  // 三色带:三段各自线性,中点为 midc
  let vm3 = ci_visual_map3_make(0.0, 5.0, 10.0, "#000000", "#ff0000", "#ffffff")
  assert_eq(vm3.color(0.0), "#000000")
  assert_eq(vm3.color(5.0), "#ff0000")
  assert_eq(vm3.color(10.0), "#ffffff")
  assert_eq(vm3.color(2.5), "#800000")
  // 三色带 mid 与端点重合(0,0,10):mid 不落区间内部,取 min/max 中点 5
  let vm4 = ci_visual_map3_make(0.0, 0.0, 10.0, "#000000", "#ff0000", "#ffffff")
  assert_eq(vm4.color(0.0), "#000000")
  assert_eq(vm4.color(10.0), "#ffffff")
  assert_eq(vm4.color(2.5), "#800000")
  // 非法色串:沿用 mix_hex 回退(原样返回高端色)
  let bad = ci_visual_map_make(0.0, 10.0, "nope", "#ffffff")
  assert_eq(bad.color(3.0), "#ffffff")
}

///|
test "ci_legend_hit:累加几何命中/界外" {
  let items = [("a", "#111111"), ("bb", "#222222")]
  // 项宽:10+4+len*7+16 → "a" 37,"bb" 44
  assert_eq(ci_legend_hit(0.0, items), 0)
  assert_eq(ci_legend_hit(36.9, items), 0)
  assert_eq(ci_legend_hit(37.0, items), 1)
  assert_eq(ci_legend_hit(80.9, items), 1)
  assert_eq(ci_legend_hit(81.0, items), -1)
  assert_eq(ci_legend_hit(5.0, []), -1)
  // 可见宽度门槛:第二项起点 37 >= 36 → 该项不绘制也不命中
  assert_eq(ci_legend_hit(38.0, items, width=36.0), -1)
  assert_eq(ci_legend_hit(20.0, items, width=36.0), 0)
}

///|
test "ci_fit_len / ci_toggle_flag:补齐与翻转" {
  debug_inspect(
    ci_fit_len([true, false], 4),
    content="[true, false, true, true]",
  )
  debug_inspect(ci_fit_len([true, false], 1), content="[true]")
  debug_inspect(ci_fit_len([], 0), content="[]")
  debug_inspect(ci_toggle_flag([true, false], 1), content="[true, true]")
  // 越界不动(返回副本)
  let f = [true, false]
  debug_inspect(ci_toggle_flag(f, -1), content="[true, false]")
  debug_inspect(ci_toggle_flag(f, 5), content="[true, false]")
  debug_inspect(f, content="[true, false]") // 入参不被修改
}

///|
test "ci_filter_visible(_at):可见项 + 原序号" {
  let arr = ["a", "b", "c"]
  debug_inspect(
    ci_filter_visible(arr, [true, false, true]),
    content="([\"a\", \"c\"], [0, 2])",
  )
  // 全隐藏
  debug_inspect(
    ci_filter_visible(arr, [false, false, false]),
    content="([], [])",
  )
  // 带偏移:flags 按全量索引寻址(先按窗切片再过滤的场景,flags 为全量长)
  let flags = [true, true, true, false, false, false, false, true]
  debug_inspect(
    ci_filter_visible_at(["x", "y", "z"], flags, 5),
    content="([\"z\"], [7])",
  )
  let on_all = [true, true, true, true, true, true, true, true]
  debug_inspect(
    ci_filter_visible_at(["x", "y"], on_all, 5),
    content="([\"x\", \"y\"], [5, 6])",
  )
}

///|
test "ci_slice_range:闭区间切片/越界收窄/空区间" {
  debug_inspect(ci_slice_range([1, 2, 3, 4, 5], 1, 3), content="[2, 3, 4]")
  debug_inspect(ci_slice_range([1, 2, 3], 0, 99), content="[1, 2, 3]")
  debug_inspect(ci_slice_range([1, 2, 3], 2, 1), content="[]")
  debug_inspect(ci_slice_range([1, 2, 3], -5, 1), content="[1, 2]")
  let empty : Array[Int] = []
  debug_inspect(ci_slice_range(empty, 0, 1), content="[]")
}

///|
test "ci_save_chart:格式/尺寸校验先行(不触盘)" {
  let draw = fn(_p : @yue.Painter, _w : Double, _h : Double) -> Unit { () }
  // 尺寸非法
  let r1 = ci_save_chart(draw, 0.0, 100.0, "/tmp/x.png")
  assert_true(r1 is Err(WriteFailed(_)))
  // 格式不支持
  let r2 = ci_save_chart(draw, 100.0, 100.0, "/tmp/x.bmp", format="bmp")
  assert_true(r2 is Err(UnsupportedFormat("bmp")))
  // 合法形状:Linux 上写盘由 shim 恒失败(位图导出仅 Windows 可用),
  // 错误消息须带格式与路径
  let r3 = ci_save_chart(draw, 100.0, 100.0, "/tmp/x.png", format="jpeg")
  match r3 {
    Err(WriteFailed(m)) =>
      assert_true(m.contains("jpeg") && m.contains("/tmp/x.png"))
    Err(_) => fail("格式合法不应报格式错误")
    Ok(_) => fail("Linux 位图导出应当失败")
  }
}
