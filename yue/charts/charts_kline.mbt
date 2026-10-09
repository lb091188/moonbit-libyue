// K 线图（candlestick）：影线（high-low 竖线）+ 实体（open-close 矩形），
// x 等距排布，y 量程默认取全体 low/high 自动外扩（可经 y_range 手动
// 指定）；默认涨红跌绿（中国习惯，close >= open 记涨），可经
// up_color/down_color 覆盖；横向网格 + 左侧刻度复用 charts.mbt 公共层。
// 纯函数（量程/涨跌/槽位/几何）集中在文件头部，charts_kline_wbtest.mbt
// 白盒覆盖。

///|
/// K 线（一根）：开/高/低/收四个价位。
pub(all) struct Candle {
  open : Double
  high : Double
  low : Double
  close : Double
}

///|
/// 建 K 线（按 open、high、low、close 依次传入）。
pub fn Candle::make(
  open : Double,
  high : Double,
  low : Double,
  close : Double,
) -> Candle {
  { open, high, low, close, }
}

///|
/// K 线 y 量程：全体 low 的最小值 .. 全体 high 的最大值 + 8% 留白；
/// 空数据给 (0, 1)；等值退化（min==max）以值为中心撑开（|值|<10 时
/// 至少 ±1）；聚合完成后若 lo > hi（出现 low > high 的乱序根）交换
/// 聚合值——多根混合乱序由全局 min/max 自然兜住。open/close 不参算。
pub fn kline_range(candles : Array[Candle]) -> (Double, Double) {
  let mut lo = 0.0
  let mut hi = 0.0
  let mut any = false
  for c in candles {
    if !any {
      lo = c.low
      hi = c.high
      any = true
    } else {
      if c.low < lo {
        lo = c.low
      }
      if c.high > hi {
        hi = c.high
      }
    }
  }
  if !any {
    return (0.0, 1.0)
  }
  if lo > hi {
    let t = lo
    lo = hi
    hi = t
  }
  if hi - lo < 1.0e-12 {
    let pad = if lo.abs() < 10.0 { 1.0 } else { lo.abs() * 0.1 }
    (lo - pad, hi + pad)
  } else {
    let pad = (hi - lo) * 0.08
    (lo - pad, hi + pad)
  }
}

///|
/// 涨跌判定：close >= open 记涨（默认红），否则跌（默认绿）；平盘归涨。
pub fn kline_is_up(c : Candle) -> Bool {
  c.close >= c.open
}

///|
/// 第 i 根 K 线槽位（实体中心 cx 与实体宽 w）：n 根均分 [left, right]，
/// 中心过槽中点（影线同用此中心），实体宽为槽宽 × ratio（默认 0.7，
/// 钳到 [0, 1]），宽不足 1px 时钳到 1（密集根数仍可见）。
pub fn kline_slot(
  i : Int,
  n : Int,
  left : Double,
  right : Double,
  ratio? : Double = 0.7,
) -> (Double, Double) {
  if n <= 0 {
    return ((left + right) / 2.0, (right - left).max(1.0))
  }
  let r = if ratio < 0.0 { 0.0 } else if ratio > 1.0 { 1.0 } else { ratio }
  let slot = (right - left) / n.to_double()
  let w = (slot * r).max(1.0)
  let cx = left + slot * (i.to_double() + 0.5)
  (cx, w)
}

///|
/// 第 i 根 K 线实体矩形 (x, y, w, h)（画布坐标，y 向下）：取 open/close
/// 两像素值的上端与 |close-open| 像素高；平盘（open==close）高度钳到
/// >= 1 保持可见。
pub fn kline_body_rect(
  i : Int,
  n : Int,
  c : Candle,
  lo : Double,
  hi : Double,
  left : Double,
  right : Double,
  top : Double,
  bottom : Double,
  ratio? : Double = 0.7,
) -> (Double, Double, Double, Double) {
  let (cx, w) = kline_slot(i, n, left, right, ratio~)
  let y_open = map_y(c.open, lo, hi, top, bottom)
  let y_close = map_y(c.close, lo, hi, top, bottom)
  let y = if y_open < y_close { y_open } else { y_close }
  let h = (y_close - y_open).abs().max(1.0)
  (cx - w / 2.0, y, w, h)
}

///|
/// 第 i 根 K 线影线段 (cx, y_high, y_low)（画布坐标）：竖线过实体中心
/// （与 [kline_slot] 同源），从 high 像素到 low 像素。
pub fn kline_wick_span(
  i : Int,
  n : Int,
  c : Candle,
  lo : Double,
  hi : Double,
  left : Double,
  right : Double,
  top : Double,
  bottom : Double,
  ratio? : Double = 0.7,
) -> (Double, Double, Double) {
  let (cx, _w) = kline_slot(i, n, left, right, ratio~)
  (cx, map_y(c.high, lo, hi, top, bottom), map_y(c.low, lo, hi, top, bottom))
}

///|
/// K 线绘制（画布坐标，candles 已由调用方取出）：影线 + 实体，涨红
/// （close >= open）跌绿；up_color/down_color 空串取主题 danger/success；
/// 横向网格 + 左侧刻度；空数据画「暂无数据」提示。
fn kline_draw(
  p : @yue.Painter,
  w : Double,
  h : Double,
  candles : Array[Candle],
  y_range : (Double, Double)?,
  up_color : String,
  down_color : String,
) -> Unit {
  let pad_l = 46.0
  let pad_r = 12.0
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
    None => kline_range(candles)
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
  let n = candles.length()
  if n == 0 {
    let at = @yue.AttributedText::new(
      "暂无数据",
      align=@yue.Center,
      valign=@yue.Center,
      wrap=false,
    )
    at.set_font(@yue.Font::new("Sans", 13.0))
    at.set_color(@yue.theme_text_secondary())
    let tw = at.get_bounds_for(400.0, 40.0).width
    p.draw_attributed_text(
      at,
      (x0 + x1) / 2.0 - tw / 2.0,
      (y0 + y1) / 2.0 - 10.0,
      tw + 4.0,
      20.0,
    )
    return
  }
  let up_c = if up_color != "" { up_color } else { @yue.theme_danger() }
  let down_c = if down_color != "" { down_color } else { @yue.theme_success() }
  for i in 0..<n {
    let c = candles[i]
    let color = if kline_is_up(c) { up_c } else { down_c }
    // 影线：high..low 竖线（先画，实体压其上）
    let (cx, wy_high, wy_low) = kline_wick_span(i, n, c, lo, hi, x0, x1, y0, y1)
    p.set_stroke_color(color)
    p.begin_path()
    p.move_to(cx, wy_high)
    p.line_to(cx, wy_low)
    p.stroke()
    // 实体：open..close 矩形（平盘高度钳 1 保持可见）
    let (bx, by, bw, bh) = kline_body_rect(i, n, c, lo, hi, x0, x1, y0, y1)
    p.set_fill_color(color)
    p.fill_rect(bx, by, bw, bh)
  }
}

///|
/// K 线图（candlestick）：影线（high-low 竖线）+ 实体（open-close 矩形），
/// x 等距排布；y 轴默认取全体 low/high 自适应（+8% 留白）或经 y_range
/// 手动指定；横向网格 + 左侧刻度。默认涨红跌绿（close >= open 记涨），
/// up_color/down_color 传十六进制色可覆盖（空串回主题色）。数据经 Store
/// 驱动，set 后只重绘画布不重建视图树；主题切换现取色自动跟随。
/// fill=true 不设固定宽度，横向铺满父容器（跟随窗口伸缩）。
pub fn candlestick_t(
  candles : @yue.Store[Array[Candle]],
  y_range? : (Double, Double)? = None,
  up_color? : String = "",
  down_color? : String = "",
  fill? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let size_style : Array[(String, &@yue.StyVal)] = if fill {
        [("height", 280.0)]
      } else {
        [("width", 560.0), ("height", 280.0)]
      }
      for kv in style {
        size_style.push(kv)
      }
      let cv = @yue.themed_container(style=size_style)
      handle(cv)
      @yue.set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(cv)
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        kline_draw(
          p,
          b.width,
          b.height,
          candles.get(),
          y_range,
          up_color,
          down_color,
        )
      })
      candles.subscribe(fn(_cs) { @yue.ViewLike::schedule_paint(cv) })
      @yue.attach(parent, @yue.ViewLike::view(cv))
      @yue.ViewLike::view(cv)
    },
  }
}
