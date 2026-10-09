// 象形柱图白盒测试：纯函数（重复计数/平铺坐标/符号边长/stretch 缩放/
// 横竖原点映射/标签偏移/stretch 半幅）语义 + 与 bar_chart_t 的坐标语义
// 对齐（0 基线、正负方向、行内标注位）。绘制函数（pb_draw/pb_chart_t）
// 走 GUI 挂载路径，保证可编译即可，视觉验证按仓库惯例由真机示例承担。

///|
test "pb_repeat_count：ceil 值/单位/零值/负值/退化单位" {
  // 整除：整好 3 个
  assert_eq(pb_repeat_count(30.0, 10.0), 3)
  // 向上取整：25/10 → 3（余量也画满一个）
  assert_eq(pb_repeat_count(25.0, 10.0), 3)
  assert_eq(pb_repeat_count(35.0, 10.0), 4)
  // 不足一个单位：1 个
  assert_eq(pb_repeat_count(4.0, 10.0), 1)
  assert_eq(pb_repeat_count(0.4, 10.0), 1)
  // 零值：0 个（不画）
  assert_eq(pb_repeat_count(0.0, 10.0), 0)
  // 负值按绝对值取整（负方向同样平铺）
  assert_eq(pb_repeat_count(-25.0, 10.0), 3)
  assert_eq(pb_repeat_count(-30.0, 10.0), 3)
  // 单位退化：兜底 1 个（除零/无限平铺防护）
  assert_eq(pb_repeat_count(25.0, 0.0), 1)
  assert_eq(pb_repeat_count(25.0, -5.0), 1)
  assert_eq(pb_repeat_count(0.0, 0.0), 0)
  // 小数单位
  assert_eq(pb_repeat_count(1.0, 0.25), 4)
  assert_eq(pb_repeat_count(1.0, 0.3), 4)
  // 病态小 unit：个数封顶 pb_tile_max，不打爆单帧绘制量
  assert_eq(pb_repeat_count(1000.0, 0.01), 64)
}

///|
test "pb_tile_centers：均分槽中心/边界/退化/覆盖不变量" {
  debug_inspect(pb_tile_centers(100.0, 4), content="[12.5, 37.5, 62.5, 87.5]")
  // 单个：取杆中点
  debug_inspect(pb_tile_centers(60.0, 1), content="[30]")
  // 退化：空
  assert_eq(pb_tile_centers(100.0, 0).length(), 0)
  assert_eq(pb_tile_centers(0.0, 4).length(), 0)
  assert_eq(pb_tile_centers(-10.0, 4).length(), 0)
  // 覆盖不变量：首尾符号（含边长）不越杆轴两端，间距恒为符号间距
  let len = 200.0
  for count in [1, 2, 3, 7, 16] {
    let centers = pb_tile_centers(len, count)
    assert_eq(centers.length(), count)
    let side = pb_symbol_side(len / count.to_double())
    assert_true(centers[0] - side / 2.0 >= -1.0e-9)
    assert_true(centers[count - 1] + side / 2.0 <= len + 1.0e-9)
    // 相邻中心距恒为槽长（均匀平铺）
    if count > 1 {
      assert_true(
        (centers[1] - centers[0] - len / count.to_double()).abs() < 1.0e-9,
      )
    }
  }
}

///|
test "pb_symbol_side：槽长扣距/窄槽钳制/默认间距" {
  // 默认 gap=1.5
  assert_eq(pb_symbol_side(16.0), 14.5)
  // 自定义间距
  assert_eq(pb_symbol_side(16.0, gap=2.0), 14.0)
  assert_eq(pb_symbol_side(16.0, gap=0.0), 16.0)
  // 槽长不足：钳到 1px（符号仍可见）
  assert_eq(pb_symbol_side(1.0), 1.0)
  assert_eq(pb_symbol_side(0.2), 1.0)
  assert_eq(pb_symbol_side(0.0), 1.0)
  assert_eq(pb_symbol_side(-5.0), 1.0)
}

///|
test "pb_stretch_scale：比例/不足一单位/退化单位/零长" {
  // 整倍拉伸
  assert_eq(pb_stretch_scale(120.0, 40.0), 3.0)
  assert_eq(pb_stretch_scale(60.0, 30.0), 2.0)
  // 不足一单位：缩放 < 1（半个单位）
  assert_eq(pb_stretch_scale(20.0, 40.0), 0.5)
  // 单位退化：兜底 1.0（画一个单位尺寸符号）
  assert_eq(pb_stretch_scale(120.0, 0.0), 1.0)
  assert_eq(pb_stretch_scale(120.0, -1.0), 1.0)
  // 零长/负长：0（不画）
  assert_eq(pb_stretch_scale(0.0, 40.0), 0.0)
  assert_eq(pb_stretch_scale(-5.0, 40.0), 0.0)
}

///|
test "pb_bar_origin：横竖两形态原点映射（纵向 (cross,base)，横向 (base,cross)）" {
  // 纵向杆 along=(0,±1)：x 取槽宽中心标量、y 取基线标量
  assert_eq(pb_bar_origin(120.0, (0.0, -1.0), 200.0), (120.0, 200.0))
  assert_eq(pb_bar_origin(120.0, (0.0, 1.0), 200.0), (120.0, 200.0))
  // 横向杆 along=(±1,0)：x 取基线标量、y 取槽宽中心标量
  assert_eq(pb_bar_origin(52.0, (1.0, 0.0), 96.0), (96.0, 52.0))
  assert_eq(pb_bar_origin(52.0, (-1.0, 0.0), 96.0), (96.0, 52.0))
}

///|
test "pb_label_offset：贴杆端外侧（横竖 × 正负，同柱状图行内标注位）" {
  // 纵向：正值柱顶上方 18px，负值柱底下方 2px（标签高 16，不压杆）
  assert_eq(pb_label_offset(false, true), (0.0, -18.0))
  assert_eq(pb_label_offset(false, false), (0.0, 2.0))
  // 横向：正值条右端 4px，负值条左端 64px（标签宽 60，不压杆）
  assert_eq(pb_label_offset(true, true), (4.0, 0.0))
  assert_eq(pb_label_offset(true, false), (-64.0, 0.0))
}

///|
test "pb_stretch_half：半幅 = 杆长一半/槽宽钳制/单位<=0 兜底铺满" {
  // 正常：沿杆轴半幅恰为杆长一半（scale = 值/单位），横轴钳在槽宽内
  assert_eq(pb_stretch_half(120.0, 40.0, 28.0), (60.0, 14.0))
  assert_eq(pb_stretch_half(120.0, 40.0, 10.0), (60.0, 5.0))
  assert_eq(pb_stretch_half(60.0, 30.0, 28.0), (30.0, 14.0))
  // 单位退化（unit_px<=0，即 unit<=0）：单个符号铺满杆长与槽宽，
  // 不画零尺寸符号
  assert_eq(pb_stretch_half(120.0, 0.0, 28.0), (60.0, 14.0))
  assert_eq(pb_stretch_half(120.0, -5.0, 28.0), (60.0, 14.0))
  // 横轴下限 0.5（槽宽极小仍可见）
  assert_eq(pb_stretch_half(120.0, 0.5, 28.0).1, 0.5)
}

///|
test "PbSymbol/PbMode 枚举与 BarItem 数据复用" {
  // 复用 charts.mbt 的 BarItem 作数据（label + value，可为负）
  let items : Array[BarItem] = [
    BarItem::make("一月", 30.0),
    BarItem::make("二月", 8.0),
    BarItem::make("三月", -25.0),
  ]
  assert_eq(items.length(), 3)
  assert_eq(items[0].label, "一月")
  assert_eq(items[2].value, -25.0)
  // 三种内置符号 + 自定义回调均可构造（默认 Rect/Repeat 在组件入参）
  let custom = PbCustom(fn(_p, _x, _y, _w, _h, _color) {  })
  for sym in [PbRect, PbCircle, PbTriangle, custom] {
    let ok = match sym {
      PbRect => true
      PbCircle => true
      PbTriangle => true
      PbCustom(_) => true
    }
    assert_true(ok)
  }
  assert_eq(pb_repeat_count(items[0].value, 10.0), 3)
  assert_eq(pb_repeat_count(items[1].value, 10.0), 1)
  assert_eq(pb_repeat_count(items[2].value, 10.0), 3)
}

///|
test "象形柱几何组合：计数→平铺→符号尺寸（含单位像素换算）" {
  // 与 pb_draw 纵向分支同源的画布常量
  let x0 = 46.0
  let x1 = 548.0
  let y0 = 14.0
  let y1 = 256.0
  let items : Array[BarItem] = [
    BarItem::make("a", 30.0),
    BarItem::make("b", 8.0),
    BarItem::make("c", -25.0),
  ]
  let n = items.length()
  let values : Array[Double] = []
  for it in items {
    values.push(it.value)
  }
  let (lo, hi) = bar_range(values)
  let ticks = nice_ticks(lo, hi, count=4)
  // 刻度不变量：非空、严格递增、全落在值域内，且 0 基线在刻度中
  // （bar_range 含 0，nice_ticks 按整齐步长扫过值域必经 0）
  assert_true(ticks.length() >= 2)
  for k in 0..<ticks.length() {
    assert_true(ticks[k] >= lo - 1.0e-9 && ticks[k] <= hi + 1.0e-9)
    if k > 0 {
      assert_true(ticks[k] > ticks[k - 1])
    }
  }
  let mut has_zero = false
  for t in ticks {
    if t == 0.0 {
      has_zero = true
    }
  }
  assert_true(has_zero)
  let yb = map_y(0.0, lo, hi, y0, y1)
  for i in 0..<items.length() {
    let v = items[i].value
    let vy = map_y(v, lo, hi, y0, y1)
    let len = (vy - yb).abs()
    let positive = v >= 0.0
    let unit = 10.0
    let a = if v < 0.0 { -v } else { v }
    let unit_px = unit * (len / a)
    // PbRepeat：count 个符号均分杆长，边长与槽中心自洽
    let count = pb_repeat_count(v, unit)
    let side = pb_symbol_side(len / count.to_double())
    let centers = pb_tile_centers(len, count)
    assert_eq(centers.length(), count)
    assert_true(side >= 1.0)
    assert_true(side <= len / count.to_double() + 1.0e-9)
    // 符号横轴半幅钳制在柱槽宽内（不越槽，同 pb_draw_bar 口径）
    let slot_bar = (x1 - x0) / n.to_double()
    let (bx, bw) = bar_slot(i, n, x0, x1, gap=slot_bar * 0.25)
    assert_true(bx >= x0)
    assert_true(bx + bw <= x1 + 1.0e-9)
    let half_cross = (side.min(bw) / 2.0).max(0.5)
    assert_true(half_cross <= bw / 2.0 + 1.0e-9)
    // PbStretch：单符号沿杆轴拉伸 scale = 值/单位，半幅恰为杆长一半
    let (half_along, half_cross) = pb_stretch_half(len, unit_px, bw)
    assert_true((half_along - len / 2.0).abs() < 1.0e-9)
    assert_true((half_cross - (unit_px.min(bw) / 2.0).max(0.5)).abs() < 1.0e-9)
    // 纵向数值标签：贴杆端外侧（正值 vy-18 在柱顶上方，负值 vy+2 在柱底下方）
    let (_, ldy) = pb_label_offset(false, positive)
    let ly = vy + ldy
    if positive {
      assert_true(vy < yb)
      assert_true(ly < vy)
    } else {
      assert_true(vy > yb)
      assert_true(ly > vy)
    }
  }
  // ---- 横向条分支（对齐 draw_bar_chart 横向常量）----
  let hx0 = 84.0
  let hx1 = 540.0
  let hy0 = 12.0
  let hy1 = 252.0
  let xb = map_xv(0.0, lo, hi, hx0, hx1)
  let hslot = (hy1 - hy0) / n.to_double()
  for i in 0..<n {
    let v = items[i].value
    let positive = v >= 0.0
    let by = hy0 +
      hslot * i.to_double() +
      (hslot - (hslot - 4.0).max(1.0)) / 2.0
    let bh = (hslot - 4.0).max(1.0)
    let vx = map_xv(v, lo, hi, hx0, hx1)
    let len = (vx - xb).abs()
    // 符号中心链（pb_draw_bar 同源）：原点 pb_bar_origin(cross=by+bh/2,
    // along=(±1,0), base=xb) → (x,y)=(xb+off, by+bh/2)，横向杆 x 取
    // 基线标量（不是槽宽中心标量），否则整根条画飞
    let (ox, oy) = pb_bar_origin(
      by + bh / 2.0,
      (if positive { 1.0 } else { -1.0 }, 0.0),
      xb,
    )
    assert_eq(ox, xb)
    assert_eq(oy, by + bh / 2.0)
    let a = if v < 0.0 { -v } else { v }
    let unit_px = 10.0 * (len / a)
    for off in pb_tile_centers(len, pb_repeat_count(v, 10.0)) {
      let cx = ox + (if positive { 1.0 } else { -1.0 }) * off
      let cy = oy
      // 横轴恒在行带内（不越槽）
      assert_true(cy >= hy0 - 1.0e-9 && cy <= hy1 + 1.0e-9)
      // 沿杆轴落在基线与值端之间（含两端）
      assert_true(cx >= xb.min(vx) - 1.0e-9 && cx <= xb.max(vx) + 1.0e-9)
    }
    // stretch 单符号中心 = 杆中点，半幅铺满杆长
    let (ha, hc) = pb_stretch_half(len, unit_px, bh)
    let midx = ox + (if positive { 1.0 } else { -1.0 }) * (len / 2.0)
    assert_true((midx - (xb + vx) / 2.0).abs() < 1.0e-9)
    assert_true((ha - len / 2.0).abs() < 1.0e-9)
    assert_true(hc <= bh / 2.0 + 1.0e-9)
    // 横向数值标签：贴杆端外侧（正值 vx+4，负值 vx-64，宽 60 不压杆）
    let (ldx, _) = pb_label_offset(true, positive)
    let lx = vx + ldx
    if positive {
      assert_true(vx > xb)
      assert_true(lx > vx)
    } else {
      assert_true(vx < xb)
      assert_true(lx + 60.0 <= vx + 1.0e-9)
    }
  }
}
