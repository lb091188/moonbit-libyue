// 图表交互层(横切地基,EP Chart 对标):DataZoom 状态窗口 / VisualMap
// 色带 / markLine-markArea 绘制辅助 / 图例 / 导出封装。
// 与其余图表同一职责划分:纯函数(窗口数学/量程归一/色带/命中)集中在
// 文件头部,charts_interactive_wbtest.mbt 白盒覆盖;组件层(可点击
// 图例)在文件尾部。zoom 状态是独立可测的数据结构,绑到 View 事件
// (滚轮/拖拽)由 charts_tooltip.mbt 的 ci_tooltip 完成;mark 的
// line/area 供任意 on_draw 回调内调用。

///|
/// 字符宽估算(Sans 12px 每字符约 7px,与 truncate_to 同基准):浮层
/// 尺寸/图例项宽/标签宽的公共估计。
fn ci_char_w() -> Double {
  7.0
}

// ---------------------------------------------------------------------------
// DataZoom:状态窗口 + 窗口数学(缩放锚点/平移边界,白盒测试覆盖)
// ---------------------------------------------------------------------------

///|
/// DataZoom 状态窗口:x 轴可见范围起止百分比(0..100)。数据切片由绘制
/// 方按 [ci_zoom_visible] 取出后重绘;状态本身不依赖视图,独立可测。
/// 变更入口:[ci_zoom_set]/[ci_zoom_wheel](滚轮,以 anchor 为锚点)/
/// [ci_zoom_pan](拖拽平移)。
pub(all) struct CiZoom {
  mut start : Double
  mut end : Double
}

///|
/// 建 DataZoom(默认全窗);起止互换/越界/零跨度由 ci_zoom_normalize 归一。
pub fn ci_zoom_make(start? : Double = 0.0, end? : Double = 100.0) -> CiZoom {
  let (s, e) = ci_zoom_normalize(start, end)
  { start: s, end: e, }
}

///|
/// 归一起止百分比:互换保序、钳到 0..100、跨度下限 1%。起止相同(零
/// 跨度)不作全窗处理,与其它过窄窗一并以中点为心撑到 1% 再贴边
/// (零宽窗切不出数据,给全窗反而不是调用方预期)。
pub fn ci_zoom_normalize(start : Double, end : Double) -> (Double, Double) {
  let mut s = if start < 0.0 {
    0.0
  } else if start > 100.0 {
    100.0
  } else {
    start
  }
  let mut e = if end < 0.0 { 0.0 } else if end > 100.0 { 100.0 } else { end }
  if s > e {
    let t = s
    s = e
    e = t
  }
  if e - s < 1.0 {
    let mid = (s + e) / 2.0
    s = (mid - 0.5).max(0.0)
    e = s + 1.0
    if e > 100.0 {
      e = 100.0
      s = 99.0
    }
  }
  (s, e)
}

///|
/// 当前窗跨度(百分比)。
pub fn ci_zoom_span(z : CiZoom) -> Double {
  z.end - z.start
}

///|
/// 复位全窗(0..100)。
pub fn ci_zoom_reset(z : CiZoom) -> Unit {
  z.start = 0.0
  z.end = 100.0
}

///|
/// 最小跨度钳制:1..100(防 0/负把窗口夹死,也防 >100 的全屏跨度)。
fn ci_zoom_min_span(min_span : Double) -> Double {
  if min_span < 1.0 {
    1.0
  } else if min_span > 100.0 {
    100.0
  } else {
    min_span
  }
}

///|
/// 设窗(起止先归一;跨度不足 min_span 时以中点为心撑到 min_span 再
/// 贴边)。
pub fn ci_zoom_set(
  z : CiZoom,
  start : Double,
  end : Double,
  min_span? : Double = 5.0,
) -> Unit {
  let ms = ci_zoom_min_span(min_span)
  let (s, e) = ci_zoom_normalize(start, end)
  if e - s >= ms {
    z.start = s
    z.end = e
  } else {
    let mid = (s + e) / 2.0
    let mut s2 = (mid - ms / 2.0).max(0.0)
    let mut e2 = s2 + ms
    if e2 > 100.0 {
      e2 = 100.0
      s2 = e2 - ms
    }
    z.start = s2
    z.end = e2
  }
}

///|
/// 滚轮缩放:anchor 为鼠标在 x 轴上的锚点(0..100 百分比,窗外钳制),
/// delta 为滚轮增量(+1 下滚 / -1 上滚,平滑滚轮为累计值),step 为每
/// 次的缩放比(0.2 = 放大到 80% / 放大 1.2 倍)。
/// 锚点不变式:不触边界时,anchor 在窗内的相对位置缩放前后一致(以鼠标
/// 为中心);触边界(0 或 100)时贴边,锚点滑动。结果跨度钳到
/// [min_span, 100]。
pub fn ci_zoom_wheel(
  z : CiZoom,
  anchor : Double,
  delta : Double,
  min_span? : Double = 5.0,
  step? : Double = 0.2,
) -> Unit {
  let ms = ci_zoom_min_span(min_span)
  let span = ci_zoom_span(z)
  if !(span > 0.0) {
    return
  }
  let st = if step < 0.05 { 0.05 } else if step > 0.9 { 0.9 } else { step }
  // 上滚(delta<0)放大:跨度乘 (1-st);下滚放大跨度
  let f = if delta < 0.0 { 1.0 - st } else { 1.0 + st }
  let mut ns = span * f
  if ns < ms {
    ns = ms
  }
  if ns > 100.0 {
    ns = 100.0
  }
  let a = if anchor < 0.0 {
    0.0
  } else if anchor > 100.0 {
    100.0
  } else {
    anchor
  }
  let t = (a - z.start) / span
  let mut s2 = a - t * ns
  if s2 < 0.0 {
    s2 = 0.0
  }
  if s2 > 100.0 - ns {
    s2 = 100.0 - ns
  }
  z.start = s2
  z.end = s2 + ns
}

///|
/// 拖拽平移:dx 为百分比位移(正右移);窗跨度不变,贴 0 / 100 边界停住。
pub fn ci_zoom_pan(z : CiZoom, dx : Double) -> Unit {
  let span = ci_zoom_span(z)
  if !(span > 0.0) {
    return
  }
  let mut s = z.start + dx
  if s < 0.0 {
    s = 0.0
  }
  if s > 100.0 - span {
    s = 100.0 - span
  }
  z.start = s
  z.end = s + span
}

///|
/// 窗 → 可见序号闭区间 [i0, i1](n 个点按百分比定位;i0 向下取整、i1
/// 向上取整-1,保证窗口内点不漏)。n <= 0 返回 (0, -1)(空区间)。
pub fn ci_zoom_visible(z : CiZoom, n : Int) -> (Int, Int) {
  if n <= 0 {
    return (0, -1)
  }
  let f0 = z.start / 100.0 * n.to_double()
  let f1 = z.end / 100.0 * n.to_double()
  let mut i0 = f0.floor().to_int()
  let mut i1 = f1.ceil().to_int() - 1
  if i0 < 0 {
    i0 = 0
  }
  if i0 > n - 1 {
    i0 = n - 1
  }
  if i1 > n - 1 {
    i1 = n - 1
  }
  if i1 < i0 {
    i1 = i0
  }
  (i0, i1)
}

// ---------------------------------------------------------------------------
// VisualMap:value → 颜色线性映射(复 color.mbt 的 mix_hex)
// ---------------------------------------------------------------------------

///|
/// VisualMap:value → 颜色线性映射。两色带(min→max 由 low 渐变到 high)
/// 或三色带(min→mid→max 三段,mid 缺省取 min/max 中点)。非法色串的
/// 回退语义同 mix_hex(原样返回高端色)。
pub(all) struct CiVisualMap {
  min : Double
  mid : Double
  max : Double
  three : Bool
  low : String
  midc : String
  high : String
}

///|
/// 建两色带(min/max 无序时自动互换)。
pub fn ci_visual_map_make(
  min : Double,
  max : Double,
  low : String,
  high : String,
) -> CiVisualMap {
  let (mn, mx) = if min <= max { (min, max) } else { (max, min) }
  {
    min: mn,
    mid: (mn + mx) / 2.0,
    max: mx,
    three: false,
    low,
    midc: high,
    high,
  }
}

///|
/// 建三色带(min/mid/max 无序时按大小归位;mid 落在区间外或以端点身份
/// 落入时取 min/max 中点)。
pub fn ci_visual_map3_make(
  min : Double,
  mid : Double,
  max : Double,
  low : String,
  midc : String,
  high : String,
) -> CiVisualMap {
  let mn = min.min(mid).min(max)
  let mx = min.max(mid).max(max)
  let md = if mid > mn && mid < mx { mid } else { (mn + mx) / 2.0 }
  { min: mn, mid: md, max: mx, three: true, low, midc, high, }
}

///|
/// value → 归一分数 0..1(量程退化 hi<=lo 时 0;两端外钳制)。
pub fn ci_visual_map_frac(v : Double, lo : Double, hi : Double) -> Double {
  if !(hi > lo) {
    return 0.0
  }
  let f = (v - lo) / (hi - lo)
  if f < 0.0 {
    0.0
  } else if f > 1.0 {
    1.0
  } else {
    f
  }
}

///|
/// value → 颜色(两色带线性 mix;三色带两段各线性 mix,中点为 midc)。
pub fn CiVisualMap::color(self : CiVisualMap, v : Double) -> String {
  let t = ci_visual_map_frac(v, self.min, self.max)
  if !self.three {
    return mix_hex(self.high, self.low, t)
  }
  if t <= 0.5 {
    mix_hex(self.midc, self.low, t * 2.0)
  } else {
    mix_hex(self.high, self.midc, (t - 0.5) * 2.0)
  }
}

// ---------------------------------------------------------------------------
// markLine / markArea:任意 on_draw 回调内的阈值线与高亮域
// ---------------------------------------------------------------------------

///|
/// 虚线（6px 实 4px 空，自绘段模拟）。
fn ci_dash_line(
  p : Painter,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  let dx = x1 - x0
  let dy = y1 - y0
  let len = (dx * dx + dy * dy).sqrt()
  if !(len > 0.0) {
    return
  }
  let ux = dx / len
  let uy = dy / len
  let mut d = 0.0
  p.begin_path()
  while d < len {
    let e = (d + 6.0).min(len)
    p.move_to(x0 + ux * d, y0 + uy * d)
    p.line_to(x0 + ux * e, y0 + uy * e)
    d = e + 4.0
  }
  p.stroke()
}

///|
/// 阈值线(markLine):在绘制区 (x0,y0)-(x1,y1) 上画横(y=value)/纵
/// (x=value)阈值线 + 端标签(空串不画);dashed=true 虚线。value 超出
/// 值域 [lo,hi] 不画(轴外阈值无落点)。标签钳在绘制区内。
pub fn ci_mark_line(
  p : Painter,
  horizontal : Bool,
  value : Double,
  lo : Double,
  hi : Double,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  label? : String = "",
  color? : String = theme_danger(),
  dashed? : Bool = true,
) -> Unit {
  if value < lo || value > hi || !(hi > lo) {
    return
  }
  p.set_stroke_color(color)
  if horizontal {
    let ly = map_y(value, lo, hi, y0, y1)
    if dashed {
      ci_dash_line(p, x0, ly, x1, ly)
    } else {
      p.begin_path()
      p.move_to(x0, ly)
      p.line_to(x1, ly)
      p.stroke()
    }
    if label != "" {
      let lw = label.length().to_double() * ci_char_w() + 8.0
      let ty = (ly + 3.0).min((y1 - 14.0).max(y0))
      p.draw_text(
        label,
        x1 - lw,
        ty,
        lw,
        14.0,
        align=End,
        valign=Start,
        color~,
        wrap=false,
      )
    }
  } else {
    let lx = map_xv(value, lo, hi, x0, x1)
    if dashed {
      ci_dash_line(p, lx, y0, lx, y1)
    } else {
      p.begin_path()
      p.move_to(lx, y0)
      p.line_to(lx, y1)
      p.stroke()
    }
    if label != "" {
      let lw = label.length().to_double() * ci_char_w() + 8.0
      let tx = (lx - lw / 2.0).max(x0).min((x1 - lw).max(x0))
      p.draw_text(
        label,
        tx,
        y0 + 2.0,
        lw,
        14.0,
        align=Start,
        valign=Start,
        color~,
        wrap=false,
      )
    }
  }
}

///|
/// 高亮域(markArea):横(from..to 的 y 值带)/纵(from..to 的 x 值带)
/// 半透明填充 + 带内端标签(空串不画)。from/to 自动交换;带与 [lo,hi]
/// 无交集不画,部分相交按交集裁剪。
pub fn ci_mark_area(
  p : Painter,
  horizontal : Bool,
  from : Double,
  to : Double,
  lo : Double,
  hi : Double,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  label? : String = "",
  color? : String = theme_warning(),
  alpha? : String = "26",
) -> Unit {
  if !(hi > lo) {
    return
  }
  let mut f = from
  let mut t2 = to
  if f > t2 {
    let tmp = f
    f = t2
    t2 = tmp
  }
  if t2 < lo || f > hi {
    return
  }
  let fc = if f < lo { lo } else { f }
  let tc = if t2 > hi { hi } else { t2 }
  p.set_fill_color(with_alpha(color, alpha))
  if horizontal {
    let ya = map_y(fc, lo, hi, y0, y1)
    let yb = map_y(tc, lo, hi, y0, y1)
    let top = ya.min(yb)
    let hgt = (yb - ya).abs()
    p.fill_rect(x0, top, x1 - x0, hgt)
    if label != "" {
      let lw = label.length().to_double() * ci_char_w() + 8.0
      p.draw_text(
        label,
        x0 + 4.0,
        top + 2.0,
        lw,
        14.0,
        align=Start,
        valign=Start,
        color~,
        wrap=false,
      )
    }
  } else {
    let xa = map_xv(fc, lo, hi, x0, x1)
    let xb = map_xv(tc, lo, hi, x0, x1)
    let left = xa.min(xb)
    let wdt = (xb - xa).abs()
    p.fill_rect(left, y0, wdt, y1 - y0)
    if label != "" {
      let lw = label.length().to_double() * ci_char_w() + 8.0
      p.draw_text(
        label,
        left + 2.0,
        y0 + 2.0,
        lw,
        14.0,
        align=Start,
        valign=Start,
        color~,
        wrap=false,
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 导出:Canvas 写文件 + 语义化错误(格式校验不触盘)
// ---------------------------------------------------------------------------

///|
/// 导出错误:格式不支持(带格式名)/ 写入失败(带格式与路径)。
pub(all) enum CiSaveError {
  UnsupportedFormat(String)
  WriteFailed(String)
}

///|
pub impl Show for CiSaveError with fn output(self, logger) {
  match self {
    UnsupportedFormat(f) =>
      logger.write_string("CiSaveError::UnsupportedFormat(\{f})")
    WriteFailed(m) => logger.write_string("CiSaveError::WriteFailed(\{m})")
  }
}

///|
pub extend CiSaveError with Show::{to_string, output}

///|
/// 合法导出格式("png"/"jpeg"/"jpg",与 Canvas::write_to_file 的 shim
/// 编码器对齐)。
fn ci_save_format_ok(format : String) -> Bool {
  format == "png" || format == "jpeg" || format == "jpg"
}

///|
/// 导出离屏画布为图片文件(默认 png):格式非法先行拒绝(不触盘);写失败
/// 带格式与路径。注意非 Windows 平台 libyue 未暴露 Canvas 跨平台导出
/// API(shim 恒失败),错误信息带平台提示——跨平台导出走打包/截图工具,
/// 不由本层解决。
pub fn ci_save(
  canvas : Canvas,
  path : String,
  format? : String = "png",
) -> Result[Unit, CiSaveError] {
  if !ci_save_format_ok(format) {
    return Err(UnsupportedFormat(format))
  }
  if canvas.write_to_file(format, path) {
    Ok(())
  } else {
    let hint = if platform() == "windows" {
      ""
    } else {
      "(本平台位图导出不可用:libyue 未暴露跨平台导出 API)"
    }
    Err(WriteFailed("写入 \{format} 失败: \{path}\{hint}"))
  }
}

///|
/// 把图表绘制回调离屏复渲染后导出:视图像素直采无 shim API,用与挂载时
/// 同一支 draw 画到离屏画布再落盘(尺寸 w/h 由调用方给)。
pub fn ci_save_chart(
  draw : (Painter, Double, Double) -> Unit,
  w : Double,
  h : Double,
  path : String,
  format? : String = "png",
) -> Result[Unit, CiSaveError] {
  if !(w > 0.0) || !(h > 0.0) {
    return Err(WriteFailed("导出尺寸非法: \{w}x\{h}"))
  }
  if !ci_save_format_ok(format) {
    return Err(UnsupportedFormat(format))
  }
  let cv = Canvas::new(w, h)
  let p = Canvas::get_painter(cv)
  draw(p, w, h)
  ci_save(cv, path, format~)
}

// ---------------------------------------------------------------------------
// 可点击图例 + 显隐位工具(白盒测试覆盖命中与补齐)
// ---------------------------------------------------------------------------

///|
/// 图例项宽度:色块 10 + 4 + 文本(封顶 140)+ 右距 16;与绘制同一累加
/// 几何(见 ci_legend_hit)。
fn ci_legend_item_w(name : String) -> Double {
  10.0 + 4.0 + (name.length().to_double() * ci_char_w()).min(140.0) + 16.0
}

///|
/// 图例命中:x 命中第几项(与绘制同一累加几何),界外 / 超过可见宽度
/// (width,项起点之后的项不绘制)返回 -1。
pub fn ci_legend_hit(
  x : Double,
  items : Array[(String, String)],
  width? : Double = 1.0e9,
) -> Int {
  let mut acc = 0.0
  for i, it in items {
    if acc >= width {
      return -1
    }
    acc = acc + ci_legend_item_w(it.0)
    if x < acc {
      return i
    }
  }
  -1
}

///|
/// 显隐位补齐到长度 n(缺省 true=可见):数据变长/变短后旧标志不丢。
pub fn ci_fit_len(flags : Array[Bool], n : Int) -> Array[Bool] {
  let out : Array[Bool] = []
  for i in 0..<n {
    out.push(if i < flags.length() { flags[i] } else { true })
  }
  out
}

///|
/// 翻转第 i 位(越界原样返回新副本)。
pub fn ci_toggle_flag(flags : Array[Bool], i : Int) -> Array[Bool] {
  let out = flags.copy()
  if i >= 0 && i < out.length() {
    out[i] = !out[i]
  }
  out
}

///|
/// 按显隐位过滤:返回(可见项, 各项原序号)——显隐切换后颜色/索引仍按
/// 原始数据定位,不致串色。
pub fn[T] ci_filter_visible(
  arr : Array[T],
  flags : Array[Bool],
) -> (Array[T], Array[Int]) {
  let out : Array[T] = []
  let idx : Array[Int] = []
  for i, a in arr {
    let on = if i < flags.length() { flags[i] } else { true }
    if on {
      out.push(a)
      idx.push(i)
    }
  }
  (out, idx)
}

///|
/// 按显隐位过滤(带索引偏移):flags 相对全量数组的 [base, base+arr.length)
/// 段生效,返回(可见项, 全量原序号)。base 用于「先按 zoom 窗切片、再
/// 过滤显隐」的场景:flags 仍按全量索引寻址,不随窗口漂移。
pub fn[T] ci_filter_visible_at(
  arr : Array[T],
  flags : Array[Bool],
  base : Int,
) -> (Array[T], Array[Int]) {
  let out : Array[T] = []
  let idx : Array[Int] = []
  for i, a in arr {
    let g = base + i
    let on = if g >= 0 && g < flags.length() { flags[g] } else { true }
    if on {
      out.push(a)
      idx.push(g)
    }
  }
  (out, idx)
}

///|
/// 切片闭区间 [i0, i1](越界自动收窄;空区间给空数组)。
pub fn[T] ci_slice_range(arr : Array[T], i0 : Int, i1 : Int) -> Array[T] {
  let out : Array[T] = []
  if arr.length() == 0 {
    return out
  }
  let lo = if i0 < 0 { 0 } else { i0 }
  let hi = if i1 >= arr.length() { arr.length() - 1 } else { i1 }
  if hi < lo {
    return out
  }
  for i in lo..<=hi {
    out.push(arr[i])
  }
  out
}

///|
/// 可点击图例(EP Legend 对标):系列色块 + 名称单行排布,hover 浅底,
/// 点击切换对应系列显隐(组件内翻转 visible)并回调 on_toggle(调用方
/// 重绘图表)。items 为 (名称, 色块色);visible 与 items 同长的显隐位
/// (不必预先对齐长度,绘制/点击时按 ci_fit_len 补齐)。两 Store 变化
/// 时自绘刷新——数据整体更换(系列数变化)只 set items 即可。
pub fn ci_legend(
  items~ : Store[Array[(String, String)]],
  visible~ : Store[Array[Bool]],
  on_toggle? : (Int) -> Unit = fn(_i) {  },
  style? : Array[(String, &StyVal)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &StyVal)] = [
        ("height", 24.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
        ("marginBottom", 6.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let c = themed_container(style=base)
      let hover = Ref(-1)
      c.on_draw(fn(p) {
        let b = ViewLike::get_bounds(c)
        let its = items.get()
        let flags = ci_fit_len(visible.get(), its.length())
        let mut x = 0.0
        for i, it in its {
          // 起点超出容器宽的项不绘制(与 ci_legend_hit 的 width 门槛同源)
          if x >= b.width {
            break
          }
          let iw = ci_legend_item_w(it.0)
          if hover.val == i {
            p.set_fill_color(theme_fill_hover())
            p.fill_rect(x - 4.0, 1.0, iw, b.height - 2.0)
          }
          let on = if i < flags.length() { flags[i] } else { true }
          p.set_fill_color(if on { it.1 } else { theme_border() })
          p.fill_rect(x, (b.height - 10.0) / 2.0, 10.0, 10.0)
          p.draw_text(
            it.0,
            x + 14.0,
            0.0,
            iw - 14.0,
            b.height,
            align=Start,
            valign=Center,
            color=if on { theme_text_regular() } else { theme_text_secondary() },
            wrap=false,
            ellipsis=true,
          )
          x = x + iw
        }
      })
      items.subscribe(fn(_i) { ViewLike::schedule_paint(c) })
      visible.subscribe(fn(_v) { ViewLike::schedule_paint(c) })
      ViewLike::on_mouse_move(c, fn(e) {
        let b = ViewLike::get_bounds(c)
        let idx = ci_legend_hit(e.view_x, items.get(), width=b.width)
        if idx != hover.val {
          hover.val = idx
          ViewLike::schedule_paint(c)
        }
      })
      ViewLike::on_mouse_leave(c, fn(_e) {
        if hover.val != -1 {
          hover.val = -1
          ViewLike::schedule_paint(c)
        }
      })
      ViewLike::on_mouse_down(c, fn(e) {
        if e.button != 1 {
          return false
        }
        let its = items.get()
        let b = ViewLike::get_bounds(c)
        let idx = ci_legend_hit(e.view_x, its, width=b.width)
        if idx < 0 || idx >= its.length() {
          return false
        }
        let n = its.length()
        visible.update(fn(vs) { ci_toggle_flag(ci_fit_len(vs, n), idx) })
        on_toggle(idx)
        ViewLike::schedule_paint(c)
        true
      })
      View::set_cursor(c, hand())
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
    },
  }
}
