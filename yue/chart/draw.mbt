// 图表组件（新栈）：折线/面积、柱状/条形、环形、仪表盘、散点五种通用图。
//
// 渲染模型与 master 一致：单一自绘容器，`on_draw` 里现取主题色（换主题即跟随），
// 数据经 `Store` 驱动，换数据只重绘画布不重建控件树；纯函数几何都在 `algo.mbt`，
// 绘制与命中同源（`bar_hit` 与柱状绘制共用槽宽公式）。
//
// 密集数据的绘制成本与窗口大小脱钩：折线按「像素列」抽稀（每列取极值），
// 面积模式每列填一个到锚线的矩形、折线模式每列画 min..max 竖条——1000 点
// 全段描边在软件光栅化下超验收线（实测数据见 docs/zh/adaptation.md）。

///|
/// 图表系列色（≤4 序列循环）：主题四语义色，深浅主题下自动跟随。
pub fn series_color(i : Int) -> String {
  match i % 4 {
    0 => @theme.theme_primary()
    1 => @theme.theme_success()
    2 => @theme.theme_warning()
    _ => @theme.theme_danger()
  }
}

///|
/// 环形图扇区色（5 色循环，相邻扇区不同色）。
pub fn donut_color(i : Int) -> String {
  match i % 5 {
    0 => @theme.theme_primary()
    1 => @theme.theme_success()
    2 => @theme.theme_warning()
    3 => @theme.theme_danger()
    _ => @theme.theme_info()
  }
}

fn label_font() -> @text.Font {
  @text.Font::new("", 12.0)
}

fn hint_font() -> @text.Font {
  @text.Font::new("", 13.0)
}

///|
/// 横向网格 + 左侧刻度标签（右对齐贴轴）；顺带画底部基线。
pub fn draw_hgrid(
  p : @render.Painter,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  lo : Double,
  hi : Double,
  ticks : Array[Double],
  label_w? : Double = 40.0,
) -> Unit {
  let f = label_font()
  p.set_line_width(1.0)
  for t in ticks {
    let ty = map_y(t, lo, hi, y0, y1)
    if ty < y0 - 0.5 || ty > y1 + 0.5 {
      continue
    }
    p.set_stroke_color(@theme.theme_border())
    p.begin_path()
    p.move_to(x0, ty)
    p.line_to(x1, ty)
    p.stroke()
    let _ = @text.draw_box_at(
      p,
      x0 - label_w - 4.0,
      ty - 8.0,
      label_w,
      16.0,
      fmt_axis(t),
      f,
      @theme.theme_text_secondary(),
      align=@text.End,
      valign=@text.Center,
      wrap=false,
    )
  }
  p.set_stroke_color(@theme.theme_border())
  p.begin_path()
  p.move_to(x0, y1)
  p.line_to(x1, y1)
  p.stroke()
}

///|
/// 竖直网格 + 底部刻度标签（居中对齐贴轴）。
pub fn draw_vgrid(
  p : @render.Painter,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  lo : Double,
  hi : Double,
  ticks : Array[Double],
) -> Unit {
  let f = label_font()
  p.set_line_width(1.0)
  for t in ticks {
    let tx = map_xv(t, lo, hi, x0, x1)
    if tx < x0 - 0.5 || tx > x1 + 0.5 {
      continue
    }
    p.set_stroke_color(@theme.theme_border())
    p.begin_path()
    p.move_to(tx, y0)
    p.line_to(tx, y1)
    p.stroke()
    let _ = @text.draw_box_at(
      p,
      tx - 30.0,
      y1 + 3.0,
      60.0,
      16.0,
      fmt_axis(t),
      f,
      @theme.theme_text_secondary(),
      align=@text.Center,
      valign=@text.Center,
      wrap=false,
    )
  }
}

///|
/// 列抽稀：把 n 个点按绘制区宽度压缩为像素列，每列取 (x, y_min, y_max)
/// （保极值）。点数 <= 列数时逐点输出；密集时每列一个竖段。
pub fn decimate_columns(
  points : Array[Double],
  lo : Double,
  hi : Double,
  x0 : Double,
  x1 : Double,
  y0 : Double,
  y1 : Double,
) -> Array[(Double, Double, Double)] {
  let out : Array[(Double, Double, Double)] = []
  let n = points.length()
  if n <= 0 {
    return out
  }
  let cols = (x1 - x0).round().to_int().max(1)
  if n <= cols {
    for i in 0..<n {
      let y = map_y(points[i], lo, hi, y0, y1)
      out.push((map_idx(i, n, x0, x1), y, y))
    }
    return out
  }
  let span = if cols > 1 { (x1 - x0) / (cols - 1).to_double() } else { 0.0 }
  for c in 0..<cols {
    let i0 = c * n / cols
    let i1 = if c == cols - 1 { n } else { (c + 1) * n / cols }
    if i1 <= i0 {
      continue
    }
    let mut vmin = points[i0]
    let mut vmax = points[i0]
    for i in i0..<i1 {
      let v = points[i]
      if v < vmin {
        vmin = v
      }
      if v > vmax {
        vmax = v
      }
    }
    let x = x0 + c.to_double() * span
    out.push((x, map_y(vmin, lo, hi, y0, y1), map_y(vmax, lo, hi, y0, y1)))
  }
  out
}

///|
/// 面积填充锚点：0 在值域内时取零线，全正值取绘制区底，全负值取绘制区顶。
pub fn area_anchor(lo : Double, hi : Double, y0 : Double, y1 : Double) -> Double {
  if lo <= 0.0 && hi >= 0.0 {
    map_y(0.0, lo, hi, y0, y1)
  } else if lo > 0.0 {
    y1
  } else {
    y0
  }
}

///|
/// 折线/面积图绘制（画布坐标）。
pub fn draw_line_chart(
  p : @render.Painter,
  w : Double,
  h : Double,
  series : Array[LineSeries],
  area : Bool,
  y_range : (Double, Double)?,
  show_last : Bool,
) -> Unit {
  let pad_l = 46.0
  let pad_r = if show_last { 56.0 } else { 12.0 }
  let pad_t = 12.0
  let pad_b = 18.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let (lo, hi) = match y_range {
    Some((a, b)) => if a <= b { (a, b) } else { (b, a) }
    None => auto_y_range(series)
  }
  draw_hgrid(
    p,
    x0,
    y0,
    x1,
    y1,
    lo,
    hi,
    nice_ticks(lo, hi, count=4),
    label_w=pad_l - 12.0,
  )
  let mut any = false
  for s in series {
    if s.points.length() > 0 {
      any = true
    }
  }
  if !any {
    let _ = @text.draw_box_at(
      p,
      x0,
      (y0 + y1) / 2.0 - 10.0,
      x1 - x0,
      20.0,
      "暂无数据",
      hint_font(),
      @theme.theme_text_secondary(),
      align=@text.Center,
      valign=@text.Center,
      wrap=false,
    )
    return
  }
  p.set_line_width(1.0)
  for si, s in series {
    let n = s.points.length()
    if n == 0 {
      continue
    }
    let color = series_color(si)
    let cols = decimate_columns(s.points, lo, hi, x0, x1, y0, y1)
    let colw = if cols.length() > 1 {
      (x1 - x0) / (cols.length() - 1).to_double() + 0.5
    } else {
      x1 - x0 + 0.5
    }
    let dense = n > (x1 - x0).round().to_int().max(1)
    if dense {
      if area {
        let anchor = area_anchor(lo, hi, y0, y1)
        p.set_fill_color(with_alpha(color, "26"))
        for col in cols {
          let (cx, ymin, ymax) = col
          if ymax < anchor - 0.01 {
            p.fill_rect(cx - colw / 2.0, ymax, colw, anchor - ymax)
          }
          if ymin > anchor + 0.01 {
            p.fill_rect(cx - colw / 2.0, anchor, colw, ymin - anchor)
          }
        }
      } else {
        p.set_fill_color(color)
        for col in cols {
          let (cx, ymin, ymax) = col
          p.fill_rect(cx - colw / 2.0, ymin, colw, (ymax - ymin).max(1.0))
        }
      }
    } else {
      let anchor = area_anchor(lo, hi, y0, y1)
      if area {
        p.set_fill_color(with_alpha(color, "26"))
        p.begin_path()
        p.move_to(cols[0].0, anchor)
        for col in cols {
          p.line_to(col.0, col.2)
        }
        p.line_to(cols[cols.length() - 1].0, anchor)
        p.close_path()
        p.fill()
      }
      p.set_stroke_color(color)
      p.begin_path()
      p.move_to(cols[0].0, cols[0].1)
      for col in cols {
        p.line_to(col.0, col.1)
        p.line_to(col.0, col.2)
      }
      p.stroke()
    }
  }
  if show_last {
    // 末端值标签：多序列末端值接近时逐个画会叠压，先按 y 排开、推到最小间距
    // 之外并压回画布内，再统一绘制
    let labels : Array[(Double, String, String)] = []
    for si, s in series {
      let n = s.points.length()
      if n == 0 {
        continue
      }
      let v = s.points[n - 1]
      labels.push((map_y(v, lo, hi, y0, y1), fmt_axis(v), series_color(si)))
    }
    // 按 y 插入排序（序列数 <=4，不必引排序器）
    for i = 1; i < labels.length(); i = i + 1 {
      let mut j = i
      while j > 0 && labels[j].0 < labels[j - 1].0 {
        let tmp = labels[j]
        labels[j] = labels[j - 1]
        labels[j - 1] = tmp
        j = j - 1
      }
    }
    let gap = 14.0
    let top = y0 + 9.0
    let bottom = y1 + 9.0
    for i in 1..<labels.length() {
      if labels[i].0 < labels[i - 1].0 + gap {
        labels[i] = (labels[i - 1].0 + gap, labels[i].1, labels[i].2)
      }
    }
    if labels.length() > 0 {
      let off = (labels[labels.length() - 1].0 - bottom).max(0.0)
      if off > 0.0 {
        for i in 0..<labels.length() {
          labels[i] = ((labels[i].0 - off).max(top), labels[i].1, labels[i].2)
        }
      }
    }
    let f = label_font()
    for label in labels {
      let (ly, txt, color) = label
      let _ = @text.draw_box_at(
        p,
        x1 + 8.0,
        ly - 9.0,
        (pad_r - 12.0).max(12.0),
        18.0,
        txt,
        f,
        color,
        align=@text.Start,
        valign=@text.Center,
        wrap=false,
      )
    }
  }
}

///|
/// 柱状图绘制（`horizontal=true` 横向条，false 纵向柱；`hover` 为高亮类目索引）。
pub fn draw_bar_chart(
  p : @render.Painter,
  w : Double,
  h : Double,
  data : Array[BarItem],
  horizontal : Bool,
  hover : Int,
  y_range? : (Double, Double)? = None,
) -> Unit {
  let n = data.length()
  if n == 0 || w <= 0.0 || h <= 0.0 {
    return
  }
  let values : Array[Double] = []
  for it in data {
    values.push(it.value)
  }
  let (lo, hi) = match y_range {
    Some(r) => r
    None => bar_range(values)
  }
  let ticks = nice_ticks(lo, hi, count=4)
  let f = label_font()
  p.set_line_width(1.0)
  if !horizontal {
    let pad_l = 46.0
    let pad_r = 12.0
    let pad_t = 14.0
    let pad_b = 24.0
    let x0 = pad_l
    let x1 = w - pad_r
    let y0 = pad_t
    let y1 = h - pad_b
    if x1 <= x0 || y1 <= y0 {
      return
    }
    draw_hgrid(p, x0, y0, x1, y1, lo, hi, ticks, label_w=pad_l - 12.0)
    let yb = map_y(0.0, lo, hi, y0, y1)
    let slot = (x1 - x0) / n.to_double()
    // 类目标签抽稀：槽宽不足 26px 时每隔 step 个画一个
    let step =
      if slot >= 26.0 { 1 } else { (26.0 / slot).ceil().to_int().max(1) }
    for i in 0..<n {
      let (bx, bw) = bar_slot(i, n, x0, x1, gap=slot * 0.25)
      let vy = map_y(data[i].value, lo, hi, y0, y1)
      let top = if vy < yb { vy } else { yb }
      let bh = (vy - yb).abs().max(1.0)
      let positive = data[i].value >= 0.0
      let base_color = if positive { @theme.theme_primary() } else { @theme.theme_danger() }
      let light_color =
        if positive { @theme.theme_primary_light() } else { @theme.theme_danger_light() }
      if hover == i {
        p.set_fill_color(light_color)
        p.fill_rect(bx, top, bw, bh)
        p.set_stroke_color(base_color)
        p.stroke_rect(bx + 0.5, top + 0.5, (bw - 1.0).max(1.0), (bh - 1.0).max(1.0))
      } else {
        p.set_fill_color(base_color)
        p.fill_rect(bx, top, bw, bh)
      }
      if i % step == 0 {
        let _ = @text.draw_box_at(
          p,
          bx + bw / 2.0 - slot / 2.0,
          y1 + 3.0,
          slot,
          16.0,
          truncate_to(data[i].label, slot),
          f,
          @theme.theme_text_secondary(),
          align=@text.Center,
          valign=@text.Center,
          wrap=false,
        )
      }
      if hover == i {
        // 行内数值标注：正数在柱顶上方，负数在柱底下方
        let ly = if positive { top - 18.0 } else { top + bh + 2.0 }
        let _ = @text.draw_box_at(
          p,
          bx + bw / 2.0 - slot / 2.0,
          ly,
          slot,
          16.0,
          fmt_axis(data[i].value),
          f,
          @theme.theme_text_primary(),
          align=@text.Center,
          valign=@text.Center,
          wrap=false,
        )
      }
    }
  } else {
    let pad_l = 84.0
    let pad_r = 20.0
    let pad_t = 12.0
    let pad_b = 24.0
    let x0 = pad_l
    let x1 = w - pad_r
    let y0 = pad_t
    let y1 = h - pad_b
    if x1 <= x0 || y1 <= y0 {
      return
    }
    draw_vgrid(p, x0, y0, x1, y1, lo, hi, ticks)
    let xb = map_xv(0.0, lo, hi, x0, x1)
    let slot = (y1 - y0) / n.to_double()
    let step =
      if slot >= 22.0 { 1 } else { (22.0 / slot).ceil().to_int().max(1) }
    for i in 0..<n {
      let by = y0 + slot * i.to_double() + (slot - (slot - 4.0).max(1.0)) / 2.0
      let bh = (slot - 4.0).max(1.0)
      let vx = map_xv(data[i].value, lo, hi, x0, x1)
      let left = if vx < xb { vx } else { xb }
      let bw = (vx - xb).abs().max(1.0)
      let positive = data[i].value >= 0.0
      let base_color = if positive { @theme.theme_primary() } else { @theme.theme_danger() }
      let light_color =
        if positive { @theme.theme_primary_light() } else { @theme.theme_danger_light() }
      if hover == i {
        // 行内高亮：整行浅底 + 条描边
        p.set_fill_color(@theme.theme_fill_hover())
        p.fill_rect(x0 - 76.0, y0 + slot * i.to_double(), x1 - x0 + 76.0, slot)
        p.set_fill_color(light_color)
        p.fill_rect(left, by, bw, bh)
        p.set_stroke_color(base_color)
        p.stroke_rect(left + 0.5, by + 0.5, (bw - 1.0).max(1.0), (bh - 1.0).max(1.0))
      } else {
        p.set_fill_color(base_color)
        p.fill_rect(left, by, bw, bh)
      }
      if i % step == 0 {
        let _ = @text.draw_box_at(
          p,
          4.0,
          y0 + slot * i.to_double(),
          pad_l - 14.0,
          slot,
          truncate_to(data[i].label, pad_l - 14.0),
          f,
          @theme.theme_text_secondary(),
          align=@text.End,
          valign=@text.Center,
          wrap=false,
        )
      }
      if hover == i {
        // 行内数值标注：正数在条右端，负数在条左端
        let lx = if positive { left + bw + 4.0 } else { left - 64.0 }
        let _ = @text.draw_box_at(
          p,
          lx,
          y0 + slot * i.to_double(),
          60.0,
          slot,
          fmt_axis(data[i].value),
          f,
          @theme.theme_text_primary(),
          align=if positive { @text.Start } else { @text.End },
          valign=@text.Center,
          wrap=false,
        )
      }
    }
  }
}

///|
/// 内弧折线段数：按扫角约每 11° 一段（整圆 32 段，弦误差 <0.4px），至少 4 段。
pub fn ring_steps(a0 : Double, a1 : Double) -> Int {
  ((a1 - a0).abs() / (pi / 16.0)).ceil().to_int().max(4)
}

///|
/// 实心圆环段（外弧 a0→a1 走真 arc，内弧回程用折线近似后填充）。
/// 内弧不走逆时针 arc：那样跨平台语义不稳（旧链路记档过被规范化成长弧、
/// 环被填成实心饼），折线近似两侧行为一致、弦误差亚像素级。
pub fn fill_ring(
  p : @render.Painter,
  cx : Double,
  cy : Double,
  r_out : Double,
  r_in : Double,
  a0 : Double,
  a1 : Double,
) -> Unit {
  p.begin_path()
  p.arc(cx, cy, r_out, a0, a1)
  let steps = ring_steps(a0, a1)
  let last = steps + 1
  for k in 0..<last {
    let a = a1 - (a1 - a0) * k.to_double() / steps.to_double()
    p.line_to(cx + r_in * @math.cos(a), cy + r_in * @math.sin(a))
  }
  p.close_path()
  p.fill()
}

///|
/// 环形图绘制（扇区 + 中心汇总 + 图例；hover 扇区外扩 4px）。
pub fn draw_donut(
  p : @render.Painter,
  w : Double,
  h : Double,
  data : Array[DonutSlice],
  thickness : Double,
  center : String,
  hover : Int,
) -> Unit {
  let n = data.length()
  if n == 0 || w <= 0.0 || h <= 0.0 {
    return
  }
  let d = h - 16.0
  let cx = 8.0 + d / 2.0
  let cy = h / 2.0
  let r_out = d / 2.0
  let r_in = (r_out - thickness).max(1.0)
  let values : Array[Double] = []
  for s in data {
    values.push(s.value)
  }
  for i in 0..<n {
    match sector_angles(values, i) {
      None => ()
      Some((a0, a1)) => {
        if a1 - a0 < 1.0e-6 {
          continue
        }
        let ro = if hover == i { r_out + 4.0 } else { r_out }
        p.set_fill_color(donut_color(i))
        fill_ring(p, cx, cy, ro, r_in, a0, a1)
      }
    }
  }
  let total = {
    let mut t = 0.0
    for s in data {
      if s.value > 0.0 {
        t = t + s.value
      }
    }
    t
  }
  let center_txt = if center.length() > 0 { center } else { fmt_axis(total) }
  let _ = @text.draw_box_at(
    p,
    cx - 100.0,
    cy - 18.0,
    200.0,
    28.0,
    center_txt,
    @text.Font::new("", 20.0, weight=@text.SemiBold),
    @theme.theme_text_primary(),
    align=@text.Center,
    valign=@text.Center,
    wrap=false,
  )
  let _ = @text.draw_box_at(
    p,
    cx - 100.0,
    cy + 10.0,
    200.0,
    16.0,
    "总计",
    @text.Font::new("", 11.0),
    @theme.theme_text_secondary(),
    align=@text.Center,
    valign=@text.Center,
    wrap=false,
  )
  // 图例（右侧）：色块 + 标签 + 值(百分比)
  let legend_x = 8.0 + d + 20.0
  if legend_x + 60.0 < w {
    let f = label_font()
    let row_h = ((h - 16.0) / n.to_double()).min(24.0).max(14.0)
    for i in 0..<n {
      let ry = 8.0 + row_h * i.to_double()
      if ry + row_h > h - 4.0 {
        break
      }
      if hover == i {
        p.set_fill_color(@theme.theme_fill_hover())
        p.fill_rect(legend_x - 4.0, ry, w - legend_x, row_h)
      }
      p.set_fill_color(donut_color(i))
      p.fill_rect(legend_x, ry + (row_h - 10.0) / 2.0, 10.0, 10.0)
      let pct =
        if total > 0.0 { (data[i].value / total * 100.0).round().to_int() } else { 0 }
      let val_txt = "\{fmt_axis(data[i].value)} (\{pct}%)"
      let lab_w = (w - legend_x - 130.0).max(20.0)
      let _ = @text.draw_box_at(
        p,
        legend_x + 16.0,
        ry,
        lab_w,
        row_h,
        truncate_to(data[i].label, lab_w),
        f,
        @theme.theme_text_regular(),
        align=@text.Start,
        valign=@text.Center,
        wrap=false,
      )
      let _ = @text.draw_box_at(
        p,
        w - 118.0,
        ry,
        110.0,
        row_h,
        val_txt,
        f,
        @theme.theme_text_secondary(),
        align=@text.End,
        valign=@text.Center,
        wrap=false,
      )
    }
  }
}

///|
/// 仪表盘阈值分段取色：`thresholds` 按阈值升序给（阈值上限, 颜色），取第一个
/// 阈值 >= frac 段的颜色；越界取末段；空表用主题主色。
pub fn band_color(frac : Double, thresholds : Array[(Double, String)]) -> String {
  if thresholds.length() == 0 {
    return @theme.theme_primary()
  }
  for kv in thresholds {
    if frac <= kv.0 {
      return kv.1
    }
  }
  thresholds[thresholds.length() - 1].1
}

///|
/// 仪表盘绘制（`frac` 为显示值 0..1，已插值平滑）。
pub fn draw_gauge(
  p : @render.Painter,
  w : Double,
  h : Double,
  frac : Double,
  thresholds : Array[(Double, String)],
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let r = (w / 2.0 - 16.0).min((h - 26.0) / 1.8).max(10.0)
  let cx = w / 2.0
  let cy = r + 13.0
  let thick = (r * 0.26).max(8.0)
  let r_in = r - thick
  let a0 = gauge_angle(0.0)
  let a1 = gauge_angle(1.0)
  let av = gauge_angle(frac)
  p.set_fill_color(@theme.theme_info_light())
  fill_ring(p, cx, cy, r, r_in, a0, a1)
  p.set_fill_color(band_color(frac, thresholds))
  if av > a0 + 0.001 {
    fill_ring(p, cx, cy, r, r_in, a0, av)
  }
  let pct = (frac * 100.0).round().to_int()
  let _ = @text.draw_box_at(
    p,
    cx - 100.0,
    cy - 16.0,
    200.0,
    32.0,
    "\{pct}%",
    @text.Font::new("", 24.0, weight=@text.SemiBold),
    @theme.theme_text_primary(),
    align=@text.Center,
    valign=@text.Center,
    wrap=false,
  )
  let f = label_font()
  let _ = @text.draw_box_at(
    p,
    cx + (r + 4.0) * @math.cos(a0) - 16.0,
    cy + (r + 4.0) * @math.sin(a0) - 8.0,
    32.0,
    16.0,
    "0",
    f,
    @theme.theme_text_secondary(),
    align=@text.Center,
    valign=@text.Center,
    wrap=false,
  )
  let _ = @text.draw_box_at(
    p,
    cx + (r + 4.0) * @math.cos(a1) - 18.0,
    cy + (r + 4.0) * @math.sin(a1) - 8.0,
    36.0,
    16.0,
    "100",
    f,
    @theme.theme_text_secondary(),
    align=@text.Center,
    valign=@text.Center,
    wrap=false,
  )
}

///|
/// 散点图绘制（点列 + 可选最小二乘趋势线；绘制区裁剪）。
pub fn draw_scatter(
  p : @render.Painter,
  w : Double,
  h : Double,
  points : Array[(Double, Double)],
  trend : Bool,
  dot : Double,
) -> Unit {
  let pad_l = 46.0
  let pad_r = 14.0
  let pad_t = 12.0
  let pad_b = 24.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let ((xlo, xhi), (ylo, yhi)) = point_range(points)
  draw_hgrid(
    p,
    x0,
    y0,
    x1,
    y1,
    ylo,
    yhi,
    nice_ticks(ylo, yhi, count=4),
    label_w=pad_l - 12.0,
  )
  draw_vgrid(p, x0, y0, x1, y1, xlo, xhi, nice_ticks(xlo, xhi, count=5))
  if points.length() == 0 {
    let _ = @text.draw_box_at(
      p,
      x0,
      (y0 + y1) / 2.0 - 10.0,
      x1 - x0,
      20.0,
      "暂无数据",
      hint_font(),
      @theme.theme_text_secondary(),
      align=@text.Center,
      valign=@text.Center,
      wrap=false,
    )
    return
  }
  p.save()
  p.clip_rect(x0, y0, x1 - x0, y1 - y0)
  if trend {
    match linreg(points) {
      None => ()
      Some((k, b)) => {
        let ya = k * xlo + b
        let yb2 = k * xhi + b
        p.set_line_width(1.0)
        p.set_stroke_color(@theme.theme_danger())
        p.begin_path()
        p.move_to(map_xv(xlo, xlo, xhi, x0, x1), map_y(ya, ylo, yhi, y0, y1))
        p.line_to(map_xv(xhi, xlo, xhi, x0, x1), map_y(yb2, ylo, yhi, y0, y1))
        p.stroke()
      }
    }
  }
  let half = dot / 2.0
  p.set_fill_color(@theme.theme_primary())
  for pt in points {
    let px = map_xv(pt.0, xlo, xhi, x0, x1)
    let py = map_y(pt.1, ylo, yhi, y0, y1)
    if px < x0 - half || px > x1 + half || py < y0 - half || py > y1 + half {
      continue
    }
    p.fill_rect(px - half, py - half, dot, dot)
  }
  p.restore()
}
