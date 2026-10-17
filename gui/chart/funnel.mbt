// 漏斗图（新栈，与 master 同源平移）：按 value 降序分层，每层一个梯形
// （宽度 ∝ value，居中/左对齐），同系列色自顶向下渐浅；画布足够宽时
// 右侧逐层标注 标签 + 数值 + 占比（相对首层（最大层）或全部正值总和，
// 参数可选）。纯函数（排序/层几何/梯形宽度/百分比）集中在文件头部，
// funnel_wbtest.mbt 白盒覆盖。

///|
/// 漏斗层水平对齐：居中（FunnelCenter，默认）或左缘对齐（FunnelLeft）。
pub(all) enum FunnelAlign {
  FunnelCenter
  FunnelLeft
}

///|
/// 漏斗层排序：按 value 降序稳定排（等值保持原次序），返回新数组，
/// 入参不变。
pub fn funnel_sort(items : Array[BarItem]) -> Array[BarItem] {
  let out = items.copy()
  out
  .mut_view()
  .sort_by(fn(a, b) {
    if a.value > b.value {
      -1
    } else if a.value < b.value {
      1
    } else {
      0
    }
  })
  out
}

///|
/// 第 i 层的 (y, 层高)：n 层均分 [top, bottom]，层间缝 gap 从槽内扣
/// （槽内居中），层高不足 1px 时钳到 1；n <= 0 或区间退化给 (top, 0)。
pub fn funnel_band(
  i : Int,
  n : Int,
  top : Double,
  bottom : Double,
  gap? : Double = 2.0,
) -> (Double, Double) {
  if n <= 0 || bottom <= top {
    return (top, 0.0)
  }
  let slot = (bottom - top) / n.to_double()
  let h = (slot - gap).max(1.0)
  (top + slot * i.to_double() + (slot - h) / 2.0, h)
}

///|
/// 第 i 层梯形的 (顶宽, 底宽)：顶宽 ∝ values[i]，底宽 ∝ values[i+1]
/// （末层收平：底宽 = 顶宽），按全部值的最大正值归一到 full；值 <= 0
/// 钳 0。i 越界、full 非正或无正值时给 (0, 0)。values 次序即层次序
/// （绘制路径传 funnel_sort 的输出）。
pub fn funnel_band_widths(
  values : Array[Double],
  i : Int,
  full : Double,
) -> (Double, Double) {
  if i < 0 || i >= values.length() || !(full > 0.0) {
    return (0.0, 0.0)
  }
  let pos = fn(x : Double) -> Double { if x > 0.0 { x } else { 0.0 } }
  let mut maxv = 0.0
  for v in values {
    let pv = pos(v)
    if pv > maxv {
      maxv = pv
    }
  }
  if maxv <= 0.0 {
    return (0.0, 0.0)
  }
  let tw = full * pos(values[i]) / maxv
  let next = if i + 1 < values.length() { values[i + 1] } else { values[i] }
  (tw, full * pos(next) / maxv)
}

///|
/// 占比百分比：of_total=true 相对全部正值总和，false 相对最大正值
/// （降序漏斗即首层，转化率口径）；基数 <= 0 或 v <= 0 时给 0。
pub fn funnel_pct(
  v : Double,
  values : Array[Double],
  of_total? : Bool = false,
) -> Double {
  let base = if of_total {
    let mut t = 0.0
    for x in values {
      if x > 0.0 {
        t = t + x
      }
    }
    t
  } else {
    let mut m = 0.0
    for x in values {
      if x > m {
        m = x
      }
    }
    m
  }
  if base <= 0.0 || !(v > 0.0) {
    0.0
  } else {
    v / base * 100.0
  }
}

///|
/// 第 i 层填充色：主题主色同系列按层提亮（顶层原色，向下逐层变浅，
/// 末层最浅），每次绘制现取主题色，主题切换自动跟随；单层即原色。
fn funnel_layer_color(i : Int, n : Int) -> String {
  let span = 0.34
  let t = if n <= 1 { 0.0 } else { i.to_double() / (n - 1).to_double() }
  @theme.lighten_hex(@theme.theme_primary(), span * t)
}

///|
/// 漏斗图绘制（画布坐标，data 已由调用方取出，内部按 value 降序重排）。
/// 画布扣除右侧标注列后仍 >= 100px 时逐层标注 标签（截断）+ 数值
/// (百分比)（对齐 donut 图例两段式）；过窄时省略标注只画梯形。
fn funnel_draw(
  p : @render.Painter,
  w : Double,
  h : Double,
  data : Array[BarItem],
  alignment : FunnelAlign,
  pct_of_total : Bool,
) -> Unit {
  let n = data.length()
  if n == 0 || w <= 0.0 || h <= 0.0 {
    return
  }
  let pad_l = 12.0
  let pad_r = 12.0
  let pad_t = 12.0
  let pad_b = 12.0
  let label_w = 128.0
  let has_label = w - pad_l - pad_r - label_w >= 100.0
  let full = if has_label {
    w - pad_l - pad_r - label_w
  } else {
    w - pad_l - pad_r
  }
  if full <= 0.0 || h - pad_t - pad_b <= 0.0 {
    return
  }
  let items = funnel_sort(data)
  let values : Array[Double] = []
  for it in items {
    values.push(it.value)
  }
  let cx = pad_l + full / 2.0
  for i in 0..<n {
    let (by, bh) = funnel_band(i, n, pad_t, h - pad_b)
    let (tw, bw) = funnel_band_widths(values, i, full)
    let (xt, xb) = match alignment {
      FunnelCenter => (cx - tw / 2.0, cx - bw / 2.0)
      FunnelLeft => (pad_l, pad_l)
    }
    p.set_fill_color(funnel_layer_color(i, n))
    p.begin_path()
    p.move_to(xt, by)
    p.line_to(xt + tw, by)
    p.line_to(xb + bw, by + bh)
    p.line_to(xb, by + bh)
    p.close_path()
    p.fill()
    if has_label {
      let label_avail = (label_w - 76.0).max(20.0)
      let pct = funnel_pct(values[i], values, of_total=pct_of_total)
        .round()
        .to_int()
      let _ = @text.draw_box_at(
        p,
        pad_l + full + 16.0,
        by,
        label_avail,
        bh,
        truncate_to(items[i].label, label_avail),
        label_font(),
        @theme.theme_text_regular(),
        align=@text.Start,
        valign=@text.Center,
        wrap=false,
      )
      let _ = @text.draw_box_at(
        p,
        w - pad_r - 72.0,
        by,
        72.0,
        bh,
        "\{fmt_axis(values[i])} (\{pct}%)",
        label_font(),
        @theme.theme_text_secondary(),
        align=@text.End,
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
/// 漏斗图：按 value 降序分层，每层一个梯形（宽度 ∝ value，alignment
/// 居中或左缘对齐），同系列色自顶向下渐浅；右侧逐层标注 标签 + 数值 +
/// 占比——pct_of_total=false 相对首层（最大层，转化率口径），true 相对
/// 全部正值总和。数据经 Store 驱动：set 后只重绘画布不重建视图树；
/// 主题切换现取色自动跟随。
pub fn funnel_t(
  data : @base.Store[Array[BarItem]],
  alignment? : FunnelAlign = FunnelCenter,
  pct_of_total? : Bool = false,
  width? : Double = 0.0,
  height? : Double = 280.0,
  handle? : (@widget.Widget) -> Unit = @ui.default_handle,
) -> @widget.Node {
  @ui.follow_store(data)
  let align = alignment
  let pct_total = pct_of_total
  @widget.node_of_new(fn(w : @widget.Widget) -> @widget.Widget {
    @ui.watch_theme()
    w.node.set_height(@yoga.fixed(height))
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    } else {
      w.node.set_width(@yoga.percent(100.0))
      w.node.set_min_width(@yoga.fixed(120.0))
    }
    w.on_draw = Some(fn(
      _self : @widget.Widget,
      p : @render.Painter,
      r : @base.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      funnel_draw(p, r.w, r.h, data.get(), align, pct_total)
    })
    handle(w)
    w
  })
}
