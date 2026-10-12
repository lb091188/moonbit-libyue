// 热力图（新栈，与 master 同源平移）：二维数值矩阵逐格着色（低→高线性
// 映射到色带，色带起止色可选，默认主题浅主色→主色）、行列标签、格间距
// 可调、格内数值可选。纯函数（矩阵量程/值→色插值/格坐标）集中在文件
// 头部，heatmap_wbtest.mbt 白盒覆盖。

// ---------------------------------------------------------------------------
// 纯函数层：矩阵量程 / 值→颜色插值 / 格坐标（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 热力图数据（行列标签 + 二维数值矩阵）。values 外层为行（自上而下）、
/// 内层为列（自左向右），x_labels 对应列、y_labels 对应行；标签数量与
/// 矩阵维度不一致时绘制侧按索引兜底（缺的标签不画）。经 Store 驱动
/// heatmap_t，set 新 HeatGrid 即整表重绘。
pub(all) struct HeatGrid {
  x_labels : Array[String]
  y_labels : Array[String]
  values : Array[Array[Double]]
}

///|
/// 建热力图数据（x_labels 为列标签、y_labels 为行标签、values 为行×列
/// 矩阵）。
pub fn HeatGrid::make(
  x_labels : Array[String],
  y_labels : Array[String],
  values : Array[Array[Double]],
) -> HeatGrid {
  { x_labels, y_labels, values, }
}

///|
/// 矩阵量程：全部格子的 min/max（不加留白——热力图色带契约是最小值取
/// 色带起点、最大值取终点，两端必须被实际数据命中）；空矩阵（含空行）
/// 给 (0, 1)。等值退化不在此处撑开，由 [heat_color] 的中点规则消化
/// （全部同值时整表取色带中点色）。
pub fn heat_range(values : Array[Array[Double]]) -> (Double, Double) {
  let mut lo = 0.0
  let mut hi = 0.0
  let mut any = false
  for row in values {
    for v in row {
      if !any {
        lo = v
        hi = v
        any = true
      } else {
        if v < lo {
          lo = v
        }
        if v > hi {
          hi = v
        }
      }
    }
  }
  if !any {
    (0.0, 1.0)
  } else {
    (lo, hi)
  }
}

///|
/// 值 → 色带插值：v 在 [lo, hi] 内线性映射到 low→high 两色之间（低端取
/// low、高端取 high，RGB 逐通道线性），越界钳到端点色；值域退化
/// （hi - lo ≈ 0）取两色中点。非法色串沿用 mix_hex 的回退（原样返回
/// 高端色）。
pub fn heat_color(
  v : Double,
  lo : Double,
  hi : Double,
  low : String,
  high : String,
) -> String {
  let t = if hi - lo < 1.0e-12 {
    0.5
  } else {
    let f = (v - lo) / (hi - lo)
    if f < 0.0 {
      0.0
    } else if f > 1.0 {
      1.0
    } else {
      f
    }
  }
  // mix_hex(a, b, t)：t 为取 a 的比例——t=0 全 b、t=1 全 a，
  // 故 a 传高端色、b 传低端色
  @theme.mix_hex(high, low, t)
}

///|
/// 格矩形 (x, y, w, h)：网格区 [x0, x1]×[y0, y1] 均分为 cols×rows 槽位，
/// 每槽四周留 gap/2 间距（槽内居中），宽/高不足 1px 时钳到 1（大矩阵
/// 窄格仍可见）；cols/rows <= 0 时退化为整块网格区。行列索引均自 0 起，
/// 行 0 在顶部（与矩阵展示方向一致）。
pub fn heat_cell_rect(
  col : Int,
  row : Int,
  cols : Int,
  rows : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  gap? : Double = 2.0,
) -> (Double, Double, Double, Double) {
  if cols <= 0 || rows <= 0 {
    return (x0, y0, (x1 - x0).max(1.0), (y1 - y0).max(1.0))
  }
  let sw = (x1 - x0) / cols.to_double()
  let sh = (y1 - y0) / rows.to_double()
  let cw = (sw - gap).max(1.0)
  let ch = (sh - gap).max(1.0)
  let cx = x0 + sw * col.to_double() + (sw - cw) / 2.0
  let cy = y0 + sh * row.to_double() + (sh - ch) / 2.0
  (cx, cy, cw, ch)
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 热力图绘制（画布坐标，数据已由调用方取出）：逐格填色 + 行列标签 +
/// 可选格内数值。空矩阵画「暂无数据」占位。列标签过密时按槽宽抽稀、
/// 行标签超宽截断（对齐柱状图标签策略）。
fn heat_draw(
  p : @render.Painter,
  w : Double,
  h : Double,
  grid : HeatGrid,
  low : String,
  high : String,
  gap : Double,
  show_values : Bool,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let pad_l = 72.0
  let pad_r = 12.0
  let pad_t = 12.0
  let pad_b = 24.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let rows = grid.values.length()
  // 列数取最长行（参差行按各自长度画，短行右侧留空）
  let mut cols = 0
  for row in grid.values {
    if row.length() > cols {
      cols = row.length()
    }
  }
  if rows == 0 || cols == 0 {
    let _ = @text.draw_box_at(
      p,
      (x0 + x1) / 2.0 - 100.0,
      (y0 + y1) / 2.0 - 10.0,
      200.0,
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
  let (lo, hi) = heat_range(grid.values)
  for r in 0..<rows {
    let row = grid.values[r]
    for c in 0..<row.length() {
      let v = row[c]
      let (cx, cy, cw, ch) = heat_cell_rect(
        c,
        r,
        cols,
        rows,
        x0,
        y0,
        x1,
        y1,
        gap~,
      )
      p.set_fill_color(heat_color(v, lo, hi, low, high))
      p.fill_rect(cx, cy, cw, ch)
      if show_values && cw >= 30.0 && ch >= 14.0 {
        let _ = @text.draw_box_at(
          p,
          cx,
          cy,
          cw,
          ch,
          fmt_axis(v),
          label_font(),
          @theme.theme_text_primary(),
          align=@text.Center,
          valign=@text.Center,
          wrap=false,
        )
      }
    }
  }
  // 行标签（左侧右对齐贴轴），行高不足时抽稀
  let slot_h = (y1 - y0) / rows.to_double()
  let step_r = if slot_h >= 18.0 {
    1
  } else {
    (18.0 / slot_h).ceil().to_int().max(1)
  }
  for r in 0..<rows {
    if r % step_r == 0 && r < grid.y_labels.length() {
      let _ = @text.draw_box_at(
        p,
        4.0,
        y0 + slot_h * r.to_double(),
        pad_l - 14.0,
        slot_h,
        truncate_to(grid.y_labels[r], pad_l - 14.0),
        label_font(),
        @theme.theme_text_secondary(),
        align=@text.End,
        valign=@text.Center,
        wrap=false,
      )
    }
  }
  // 列标签（底部居中贴轴），槽宽不足时抽稀
  let slot_w = (x1 - x0) / cols.to_double()
  let step_c = if slot_w >= 26.0 {
    1
  } else {
    (26.0 / slot_w).ceil().to_int().max(1)
  }
  for c in 0..<cols {
    if c % step_c == 0 && c < grid.x_labels.length() {
      let _ = @text.draw_box_at(
        p,
        x0 + slot_w * c.to_double(),
        y1 + 3.0,
        slot_w,
        16.0,
        truncate_to(grid.x_labels[c], slot_w),
        label_font(),
        @theme.theme_text_secondary(),
        align=@text.Center,
        valign=@text.Center,
        wrap=false,
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层
// ---------------------------------------------------------------------------

///|
/// 热力图：二维数值矩阵逐格着色（矩阵 min/max 自动量程，低值取色带
/// 起点、高值取终点，线性映射）；色带起止色可选（默认主题浅主色→
/// 主色，主题切换自动跟随），格间距 gap 可调；行标签居左、列标签居底，
/// 过密自动抽稀截断；show_values=true 时格内居中标注数值（格子足够大
/// 才画）。数据经 Store 驱动，set 后只重绘画布。
pub fn heatmap_t(
  data : @core.Store[HeatGrid],
  low_color? : String = "",
  high_color? : String = "",
  gap? : Double = 2.0,
  show_values? : Bool = false,
  width? : Double = 0.0,
  height? : Double = 300.0,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(data)
  let lc = low_color
  let hc = high_color
  let g = gap
  let sv = show_values
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    @ui.watch_theme()
    w.node.set_height(@yoga.fixed(height))
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    } else {
      w.node.set_width(@yoga.percent(100.0))
      w.node.set_min_width(@yoga.fixed(120.0))
    }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      // 空串 = 跟随主题（on_draw 内现取，theme_apply 切换即重绘跟随）
      let low = if lc != "" { lc } else { @theme.theme_primary_light() }
      let high = if hc != "" { hc } else { @theme.theme_primary() }
      heat_draw(p, r.w, r.h, data.get(), low, high, g, sv)
    })
    handle(w)
    w
  })
}
