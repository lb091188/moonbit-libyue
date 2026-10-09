// 象形柱图（EP PictorialBar 对标，纯 MoonBit 全自绘，Painter 承载）：
//   pb_chart_t  象形柱图：以选定符号沿基线重复平铺（mode=PbRepeat，个数
//               = ceil 值/单位，见 pb_repeat_count）或整体拉伸
//               （mode=PbStretch，见 pb_stretch_scale）表达数值；纵向柱
//               与横向条两形态，坐标语义对齐 bar_chart_t（0 基线、正负
//               值、槽位、网格刻度、标签策略同源）；数值标签可选
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （主题切换重绘跟随）；数据经 Store 驱动，set 后只 schedule_paint
// 画布，不重建视图树；数据复用 charts.mbt 的 BarItem（label + value）。
// 纯函数（重复计数/平铺坐标/符号边长/stretch 缩放）集中在文件头部，
// charts_pictorialbar_wbtest.mbt 白盒覆盖。

// ---------------------------------------------------------------------------
// 纯函数层：重复计数 / 平铺坐标 / 符号边长 / stretch 缩放（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 象形符号形状：PbRect 矩形、PbCircle 圆形、PbTriangle 三角形（顶点
/// 朝杆轴值端方向），PbCustom 自定义绘制回调（入参 painer、盒矩形
/// x/y/w/h、填充色——回调在该盒内自绘，颜色自行 set_fill_color 使用）。
pub(all) enum PbSymbol {
  PbRect
  PbCircle
  PbTriangle
  PbCustom((@yue.Painter, Double, Double, Double, Double, String) -> Unit)
}

///|
/// 平铺模式：PbRepeat 沿基线向值端重复平铺单个符号（个数 = ceil 值/
/// 单位，符号边长按杆长均分自适应）；PbStretch 整体拉伸单个符号铺满
/// 基线到值端（沿杆轴缩放 = pb_stretch_scale）。
pub(all) enum PbMode {
  PbRepeat
  PbStretch
}

///|
/// 单杆平铺符号个数上限（防病态小 unit 把单帧绘制量打爆：槽长不足
/// 5px 后符号已不可辨，封顶不损失可读性）。
let pb_tile_max : Int = 64

///|
/// 符号重复个数：ceil(|值| / 单位)——PbRepeat 模式下沿杆轴平铺的符号
/// 个数；值为 0 时 0（不画）；单位 <= 0 时兜底 1（等价整体画一个，
/// 避免除零与无限平铺）；结果钳到 pb_tile_max 上限。
pub fn pb_repeat_count(value : Double, unit : Double) -> Int {
  let a = if value < 0.0 { -value } else { value }
  if a <= 0.0 {
    return 0
  }
  if !(unit > 0.0) {
    return 1
  }
  (a / unit - 1.0e-9).ceil().to_int().max(1).min(pb_tile_max)
}

///|
/// 平铺符号中心沿杆轴的偏移量（相对基线、向值端方向为正）：count 个
/// 符号均分杆长 len 后取各槽中心；count <= 0 或 len <= 0 时给空数组。
/// 首尾符号（配 pb_symbol_side 边长）不越杆轴两端，间距为符号间距。
pub fn pb_tile_centers(len : Double, count : Int) -> Array[Double] {
  let out : Array[Double] = []
  if count <= 0 || !(len > 0.0) {
    return out
  }
  let slot = len / count.to_double()
  for k in 0..<count {
    out.push(slot * (k.to_double() + 0.5))
  }
  out
}

///|
/// 平铺符号边长：杆轴槽长扣除符号间距 gap 后得到的绘制边长，不足 1px
/// 钳到 1（数值密集、槽长很小时间隔退化为零，符号仍可见）。
pub fn pb_symbol_side(slot_len : Double, gap? : Double = 1.5) -> Double {
  (slot_len - gap).max(1.0)
}

///|
/// Stretch 缩放系数：单符号沿杆轴的拉伸倍数 = 杆轴像素长 / 单位像素长
/// （= 值 / 单位）；杆长 <= 0 时 0（不画）；单位 <= 0 时兜底 1.0
/// （不缩放，画一个单位尺寸的符号）。
pub fn pb_stretch_scale(bar_len : Double, unit : Double) -> Double {
  if !(bar_len > 0.0) {
    return 0.0
  }
  if !(unit > 0.0) {
    return 1.0
  }
  bar_len / unit
}

///|
/// 象形柱原点（画布坐标）：cross 为柱槽宽方向的中心标量、base 为杆轴
/// 基线标量、along 为杆轴单位向量——纵向杆 along=(0,±1) 时原点取
/// (cross, base)，横向杆 along=(±1,0) 时取 (base, cross)。横竖两形态
/// 共用同一套符号平铺/拉伸逻辑，符号中心 = 原点 + along × 沿杆轴偏移。
pub fn pb_bar_origin(
  cross : Double,
  along : (Double, Double),
  base : Double,
) -> (Double, Double) {
  if along.0 != 0.0 {
    (base, cross)
  } else {
    (cross, base)
  }
}

///|
/// Stretch 模式符号半幅（沿杆轴半幅, 横轴半幅）：unit_px 为每个数值
/// 单位折算的像素长（单位 × 杆长 / |值|）；unit_px > 0 时沿杆轴半幅 =
/// pb_stretch_scale × unit_px / 2，横轴半幅钳制在槽宽内；unit_px <= 0
/// （单位 <= 0）兜底铺满杆长与槽宽（每根柱一个符号，不画零尺寸符号）。
pub fn pb_stretch_half(
  len : Double,
  unit_px : Double,
  bar_w : Double,
) -> (Double, Double) {
  if unit_px > 0.0 {
    let scale = pb_stretch_scale(len, unit_px)
    (scale * unit_px / 2.0, (unit_px.min(bar_w) / 2.0).max(0.5))
  } else {
    (len / 2.0, (bar_w / 2.0).max(0.5))
  }
}

///|
/// 数值标签偏移（贴杆端外侧，与 draw_bar_chart 行内标注同源）：纵向
/// 正值在柱顶上方 18px、负值在柱底下方 2px；横向正值在值端右侧 4px、
/// 负值在值端左侧 64px（标签宽 60，负向不压杆）。偏移加在杆的值端
/// 像素坐标上（纵向加在值端 y，横向加在值端 x）。
pub fn pb_label_offset(horizontal : Bool, positive : Bool) -> (Double, Double) {
  match (horizontal, positive) {
    (true, true) => (4.0, 0.0)
    (true, false) => (-64.0, 0.0)
    (false, true) => (0.0, -18.0)
    (false, false) => (0.0, 2.0)
  }
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 象形柱图绘制（画布坐标，数据已由调用方取出）：坐标语义对齐
/// draw_bar_chart——相同内外边距、0 基线（正负值分居两侧）、bar_slot
/// 槽位几何、横向/竖直网格与刻度、类目标签抽稀截断策略。每根柱按
/// symbol 沿杆轴平铺（mode=PbRepeat）或整体拉伸（mode=PbStretch）；
/// unit 为每个符号代表的数值单位（符号像素尺寸按「单位 × 杆长/|值|」
/// 换算，并钳制在柱槽宽内）；show_values 时逐根标注数值（正值在杆端
/// 外侧、负值在反方向外侧，对齐柱状图行内标注位置）。
fn pb_draw(
  p : @yue.Painter,
  w : Double,
  h : Double,
  data : Array[BarItem],
  symbol : PbSymbol,
  mode : PbMode,
  unit : Double,
  horizontal : Bool,
  show_values : Bool,
  y_range : (Double, Double)?,
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
    // 类目标签抽稀：槽宽不足 26px 时每隔 step 个画一个（同柱状图）
    let step = if slot >= 26.0 {
      1
    } else {
      (26.0 / slot).ceil().to_int().max(1)
    }
    for i in 0..<n {
      let (bx, bw) = bar_slot(i, n, x0, x1, gap=slot * 0.25)
      let vy = map_y(data[i].value, lo, hi, y0, y1)
      let len = (vy - yb).abs()
      let positive = data[i].value >= 0.0
      let color = if positive { @yue.theme_primary() } else { @yue.theme_danger() }
      p.set_fill_color(color)
      pb_draw_bar(
        p,
        symbol,
        mode,
        data[i].value,
        bx + bw / 2.0,
        (0.0, if positive { -1.0 } else { 1.0 }),
        (1.0, 0.0),
        yb,
        len,
        bw,
        unit,
        color,
      )
      if i % step == 0 {
        p.draw_text(
          truncate_to(data[i].label, slot),
          bx + bw / 2.0 - slot / 2.0,
          y1 + 3.0,
          slot,
          16.0,
          align=@yue.Center,
          valign=@yue.Center,
          color=@yue.theme_text_secondary(),
        )
      }
      if show_values {
        // 行内数值标注：贴杆端外侧（正值柱顶上方、负值柱底下方）
        let (_, ldy) = pb_label_offset(false, positive)
        p.draw_text(
          fmt_axis(data[i].value),
          bx + bw / 2.0 - slot / 2.0,
          vy + ldy,
          slot,
          16.0,
          align=@yue.Center,
          valign=@yue.Center,
          color=@yue.theme_text_primary(),
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
    let step = if slot >= 22.0 {
      1
    } else {
      (22.0 / slot).ceil().to_int().max(1)
    }
    for i in 0..<n {
      let by = y0 + slot * i.to_double() + (slot - (slot - 4.0).max(1.0)) / 2.0
      let bh = (slot - 4.0).max(1.0)
      let vx = map_xv(data[i].value, lo, hi, x0, x1)
      let len = (vx - xb).abs()
      let positive = data[i].value >= 0.0
      let color = if positive { @yue.theme_primary() } else { @yue.theme_danger() }
      p.set_fill_color(color)
      pb_draw_bar(
        p,
        symbol,
        mode,
        data[i].value,
        by + bh / 2.0,
        (if positive { 1.0 } else { -1.0 }, 0.0),
        (0.0, 1.0),
        xb,
        len,
        bh,
        unit,
        color,
      )
      if i % step == 0 {
        p.draw_text(
          truncate_to(data[i].label, pad_l - 14.0),
          4.0,
          y0 + slot * i.to_double(),
          pad_l - 14.0,
          slot,
          align=@yue.End,
          valign=@yue.Center,
          color=@yue.theme_text_secondary(),
        )
      }
      if show_values {
        // 行内数值标注：贴杆端外侧（正值条右端、负值条左端）
        let (ldx, _) = pb_label_offset(true, positive)
        p.draw_text(
          fmt_axis(data[i].value),
          vx + ldx,
          y0 + slot * i.to_double(),
          60.0,
          slot,
          align=if positive { @yue.Start } else { @yue.End },
          valign=@yue.Center,
          color=@yue.theme_text_primary(),
        )
      }
    }
  }
}

///|
/// 单根象形柱（画布坐标）：cross 为柱槽宽方向的中心标量、base 为杆轴
/// 基线标量、along/cross_v 为两轴单位向量——纵向杆 along=(0,±1)，横向
/// 杆 along=(±1,0)，横竖两形态共用同一套符号平铺/拉伸逻辑；符号中心
/// 的画布坐标由 pb_bar_origin 定原点后沿 along 平移。len 为杆轴像素长，
/// bar_w 为槽宽（横轴尺寸上限）。PbRepeat：count = pb_repeat_count(值,
/// 单位) 个符号沿杆轴平铺（中心见 pb_tile_centers，边长 pb_symbol_side，
/// 横轴半幅 = min(边长, bar_w)/2 不越槽）；PbStretch：单个符号整体拉伸
/// （半幅见 pb_stretch_half，单位 <= 0 时兜底铺满杆长与槽宽）。杆长
/// <= 0.5px 时不画。
fn pb_draw_bar(
  p : @yue.Painter,
  symbol : PbSymbol,
  mode : PbMode,
  value : Double,
  cross : Double,
  along : (Double, Double),
  cross_v : (Double, Double),
  base : Double,
  len : Double,
  bar_w : Double,
  unit : Double,
  color : String,
) -> Unit {
  if !(len > 0.5) {
    return
  }
  let (ox, oy) = pb_bar_origin(cross, along, base)
  // 单位像素长：每个数值单位折算到的像素（单位 × 杆长 / |值|）
  let a = if value < 0.0 { -value } else { value }
  let unit_px = if a > 0.0 { unit * (len / a) } else { unit }
  match mode {
    PbRepeat => {
      let count = pb_repeat_count(value, unit)
      let side = pb_symbol_side(len / count.to_double())
      let half_cross = (side.min(bar_w) / 2.0).max(0.5)
      for off in pb_tile_centers(len, count) {
        pb_draw_symbol(
          p,
          symbol,
          ox + along.0 * off,
          oy + along.1 * off,
          side / 2.0,
          half_cross,
          along,
          cross_v,
          color,
        )
      }
    }
    PbStretch => {
      let (half_along, half_cross) = pb_stretch_half(len, unit_px, bar_w)
      pb_draw_symbol(
        p,
        symbol,
        ox + along.0 * (len / 2.0),
        oy + along.1 * (len / 2.0),
        half_along,
        half_cross,
        along,
        cross_v,
        color,
      )
    }
  }
}

///|
/// 在 (cx, cy) 处画一个符号：half_along 为沿杆轴半幅、half_cross 为
/// 横轴半幅；along/cross_v 为两轴单位向量（四个杆轴方向通用，三角形
/// 顶点取 along 正向即值端方向）。PbRect 走 fill_rect；PbCircle 以
/// 单位圆 + translate/scale 变换成盒内椭圆（stretch 时非正方形盒
/// 即拉伸态）；PbTriangle 三点路径填充；PbCustom 回调收盒矩形。
fn pb_draw_symbol(
  p : @yue.Painter,
  symbol : PbSymbol,
  cx : Double,
  cy : Double,
  half_along : Double,
  half_cross : Double,
  along : (Double, Double),
  cross_v : (Double, Double),
  color : String,
) -> Unit {
  let ax = along.0
  let ay = along.1
  let ux = cross_v.0
  let uy = cross_v.1
  let bx = (cx - ax * half_along - ux * half_cross).min(
    cx + ax * half_along + ux * half_cross,
  )
  let by = (cy - ay * half_along - uy * half_cross).min(
    cy + ay * half_along + uy * half_cross,
  )
  let bw = (ax * half_along + ux * half_cross).abs() * 2.0
  let bh = (ay * half_along + uy * half_cross).abs() * 2.0
  match symbol {
    PbRect => p.fill_rect(bx, by, bw, bh)
    PbCircle => {
      p.save()
      p.translate(bx + bw / 2.0, by + bh / 2.0)
      p.scale((bw / 2.0).max(0.1), (bh / 2.0).max(0.1))
      p.begin_path()
      p.arc(0.0, 0.0, 1.0, 0.0, tau)
      p.close_path()
      p.fill()
      p.restore()
    }
    PbTriangle => {
      // 顶点在杆轴值端，底边两点在对侧（沿杆轴方向拉开）
      p.begin_path()
      p.move_to(cx + ax * half_along, cy + ay * half_along)
      p.line_to(
        cx - ax * half_along + ux * half_cross,
        cy - ay * half_along + uy * half_cross,
      )
      p.line_to(
        cx - ax * half_along - ux * half_cross,
        cy - ay * half_along - uy * half_cross,
      )
      p.close_path()
      p.fill()
    }
    PbCustom(draw) => draw(p, bx, by, bw, bh, color)
  }
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 象形柱图（EP PictorialBar）：以 symbol 符号沿基线重复平铺
/// （mode=PbRepeat，个数 = ceil 值/unit，见 pb_repeat_count）或整体
/// 拉伸（mode=PbStretch）表达数值；坐标语义对齐 bar_chart_t——0 基线、
/// 正负值（正取主题主色向上/向右，负取 danger 色向下/向左）、槽位与
/// 网格刻度同源、类目标签过密抽稀截断；show_values=true 时逐根标注
/// 数值。unit 为每个符号代表的数值单位（符号像素尺寸按「单位 × 杆长
/// /|值|」换算并钳制在柱槽宽内；单位 <= 0 时每根柱一个符号）。数据经
/// Store 驱动：set 后只重绘画布不重建视图树；主题切换现取色自动跟随。
/// fill=true 不设固定宽度，横向铺满父容器（跟随窗口伸缩）。
pub fn pb_chart_t(
  data : @yue.Store[Array[BarItem]],
  symbol? : PbSymbol = PbRect,
  mode? : PbMode = PbRepeat,
  unit? : Double = 10.0,
  horizontal? : Bool = false,
  show_values? : Bool = false,
  y_range? : (Double, Double)? = None,
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
        pb_draw(
          p,
          b.width,
          b.height,
          data.get(),
          symbol,
          mode,
          unit,
          horizontal,
          show_values,
          y_range,
        )
      })
      data.subscribe(fn(_d) { @yue.ViewLike::schedule_paint(cv) })
      @yue.attach(parent, @yue.ViewLike::view(cv))
      @yue.ViewLike::view(cv)
    },
  }
}
