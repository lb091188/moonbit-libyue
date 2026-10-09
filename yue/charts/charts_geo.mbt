// 地图与飞线组件（EP Chart 对标，纯 MoonBit 全自绘，Painter 承载）：
//   geo_map_t    地理地图 + 飞线：等距圆柱投影的 GeoJSON 区域（填充 +
//                  描边 + 质心区域名标签），飞线为起终点之间的二次贝塞尔
//                   弧线（分段渐变虚线 + 端点圆点 + 末端箭头，静态表现）
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （theme_apply 切换深浅即重绘跟随）；regions 经 Store 驱动，set 后只
// schedule_paint 画布，不重建视图树。地图数据不内置——区域表由调用方
// 解析 GeoJSON 文本得到（geojson_parse，复用 vscode_history.mbt 的
// vsc_json 手写解析器，同包私有、未改动其代码）或自行构造。
// GeoJSON 解析（FeatureCollection/Feature/Polygon/MultiPolygon）、投影、
// 质心、布局适配与飞线几何（控制点/贝塞尔/采样）等纯函数集中在文件
// 头部，charts_geo_wbtest.mbt 白盒覆盖。

///|
/// 地图绘制区四边留白（px）。
let geo_map_pad : Double = 12.0

// ---------------------------------------------------------------------------
// 纯函数层：GeoJSON 解析（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 一个 GeoJSON 区域：name 取自 Feature.properties.name（裸几何为 None），
/// rings 为经纬度多边形环列表（Polygon 的外环+内环、MultiPolygon 的各多
/// 边形环按顺序拼接；点对为 (lon, lat)）。渲染层按区域的环填充+描边，
/// 无条件要求——调用方应保证环点数 >= 3。
pub(all) struct GeoRegion {
  name : String?
  rings : Array[Array[(Double, Double)]]
}

///|
/// 建区域（rings 为环列表，每环为 (lon, lat) 点对列表）。
pub fn GeoRegion::make(
  name : String?,
  rings : Array[Array[(Double, Double)]],
) -> GeoRegion {
  { name, rings, }
}

///|
/// GeoJSON 解析失败原因。
pub(all) enum GeoError {
  /// 文本不是合法 JSON（语法错误或有尾随内容）
  InvalidJson
  /// 根对象 type 不是可识别的 GeoJSON 类型
  UnknownRoot
  /// 几何结构不合规（缺 coordinates、环点数 < 3、坐标含非数值）
  BadGeometry
}

///|
pub impl Show for GeoError with fn output(self, logger) {
  match self {
    InvalidJson => logger.write_string("GeoError::InvalidJson")
    UnknownRoot => logger.write_string("GeoError::UnknownRoot")
    BadGeometry => logger.write_string("GeoError::BadGeometry")
  }
}

///|
pub extend GeoError with Show::{to_string, output}

///|
/// JSON 数值 → Double（整数/浮点均收；其余 None）。
fn geo_json_num(v : @yue.VscJson) -> Double? {
  match v {
    @yue.VscJInt(i) => Some(i.to_double())
    @yue.VscJFloat(f) => Some(f)
    @yue.VscJNull | @yue.VscJBool | @yue.VscJStr(_) | @yue.VscJArr(_) | @yue.VscJObj(_) => None
  }
}

///|
/// 坐标点 [lon, lat, ...] → (lon, lat)（高程等多余维度忽略；前两维
/// 非数值返回 None）。
fn geo_parse_pos(v : @yue.VscJson) -> (Double, Double)? {
  match v {
    @yue.VscJArr(a) if a.length() >= 2 =>
      match (geo_json_num(a[0]), geo_json_num(a[1])) {
        (Some(lon), Some(lat)) => Some((lon, lat))
        _ => None
      }
    _ => None
  }
}

///|
/// 线环（坐标点数组）→ 点对数组；点数 < 3 或含非数值坐标返回 None。
fn geo_parse_ring(v : @yue.VscJson) -> Array[(Double, Double)]? {
  match v {
    @yue.VscJArr(a) => {
      if a.length() < 3 {
        return None
      }
      let out : Array[(Double, Double)] = []
      for p in a {
        match geo_parse_pos(p) {
          Some(pt) => out.push(pt)
          None => return None
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
/// Polygon 的 coordinates（环数组）→ 环列表；coordinates 缺失或任一环
/// 不合规返回 None。
fn geo_parse_rings(v : @yue.VscJson) -> Array[Array[(Double, Double)]]? {
  match v {
    @yue.VscJArr(rings) => {
      let out : Array[Array[(Double, Double)]] = []
      for r in rings {
        match geo_parse_ring(r) {
          Some(ring) => out.push(ring)
          None => return None
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
/// 几何对象 → 环列表：Polygon 取 coordinates；MultiPolygon 按顺序拼接
/// 各多边形的环；其余类型（Point/LineString/GeometryCollection 等）返回
/// None。
fn geo_parse_geometry(v : @yue.VscJson) -> Array[Array[(Double, Double)]]? {
  match @yue.vsc_json_str(@yue.vsc_json_get(v, "type")) {
    Some("Polygon") =>
      match @yue.vsc_json_get(v, "coordinates") {
        Some(c) => geo_parse_rings(c)
        None => None
      }
    Some("MultiPolygon") =>
      match @yue.vsc_json_get(v, "coordinates") {
        Some(@yue.VscJArr(polys)) => {
          let out : Array[Array[(Double, Double)]] = []
          for poly in polys {
            match geo_parse_rings(poly) {
              Some(rings) =>
                for r in rings {
                  out.push(r)
                }
              None => return None
            }
          }
          Some(out)
        }
        _ => None
      }
    _ => None
  }
}

///|
/// Feature → 区域：name 取 properties.name；geometry 缺失或为 null
/// （GeoJSON 合法）不产出区域（Ok(None)）；几何是非多边形类型或坐标
/// 不合规返回 Err(BadGeometry)。
fn geo_parse_feature(f : @yue.VscJson) -> Result[GeoRegion?, GeoError] {
  match @yue.vsc_json_get(f, "geometry") {
    Some(@yue.VscJNull) => Ok(None)
    None => Ok(None)
    Some(g) =>
      match geo_parse_geometry(g) {
        None => Err(BadGeometry)
        Some(rings) =>
          if rings.length() == 0 {
            Ok(None)
          } else {
            let name = match @yue.vsc_json_get(f, "properties") {
              Some(props) => @yue.vsc_json_str(@yue.vsc_json_get(props, "name"))
              None => None
            }
            Ok(Some({ name, rings, }))
          }
      }
  }
}

///|
/// 解析 GeoJSON 文本 → 区域表：
/// - FeatureCollection 取 features（geometry 为 null 的 Feature 跳过，
///   不产出区域）；
/// - 单个 Feature 视为单区域；
/// - 裸 Polygon / MultiPolygon 视为单区域（无名称）。
/// 数据由调用方传入，本模块不内置地图数据集。文本非 JSON、根 type 不
/// 可识别、几何坐标不合规分别返回 InvalidJson / UnknownRoot /
/// BadGeometry。
pub fn geojson_parse(text : String) -> Result[Array[GeoRegion], GeoError] {
  let root = match @yue.vsc_json_parse(text) {
    Some(j) => j
    None => return Err(InvalidJson)
  }
  match @yue.vsc_json_str(@yue.vsc_json_get(root, "type")) {
    Some("FeatureCollection") =>
      match @yue.vsc_json_get(root, "features") {
        Some(@yue.VscJArr(feats)) => {
          let out : Array[GeoRegion] = []
          for f in feats {
            match geo_parse_feature(f) {
              Ok(Some(r)) => out.push(r)
              Ok(None) => ()
              Err(e) => return Err(e)
            }
          }
          Ok(out)
        }
        _ => Err(BadGeometry)
      }
    Some("Feature") =>
      match geo_parse_feature(root) {
        Ok(Some(r)) => Ok([r])
        Ok(None) => Ok([])
        Err(e) => Err(e)
      }
    Some(ty) if ty == "Polygon" || ty == "MultiPolygon" =>
      match geo_parse_geometry(root) {
        Some(rings) if rings.length() > 0 => Ok([{ name: None, rings, }])
        _ => Err(BadGeometry)
      }
    _ => Err(UnknownRoot)
  }
}

// ---------------------------------------------------------------------------
// 纯函数层：投影 / 质心 / 布局（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 等距圆柱投影（equirectangular）：lon [-180, 180] 线性映射到 rect 横向
/// （左→右），lat [-90, 90] 线性映射到 rect 纵向（上→下，北半球在上）；
/// 输入越界先钳制，输出不超出 rect。
pub fn geo_project(
  lon : Double,
  lat : Double,
  rect : @yue.RectF,
) -> (Double, Double) {
  let lo = if lon < -180.0 { -180.0 } else if lon > 180.0 { 180.0 } else { lon }
  let la = if lat < -90.0 { -90.0 } else if lat > 90.0 { 90.0 } else { lat }
  let x = rect.x + (lo + 180.0) / 360.0 * rect.width
  let y = rect.y + (90.0 - la) / 180.0 * rect.height
  (x, y)
}

///|
/// 点表包围盒 (min_lon, min_lat, max_lon, max_lat)；空表返回 None。
/// 同经/同纬的退化输入该轴 min == max。
pub fn geo_bbox_points(
  points : Array[(Double, Double)],
) -> (Double, Double, Double, Double)? {
  let mut x0 = 0.0
  let mut y0 = 0.0
  let mut x1 = 0.0
  let mut y1 = 0.0
  let mut any = false
  for pt in points {
    if !any {
      x0 = pt.0
      y0 = pt.1
      x1 = pt.0
      y1 = pt.1
      any = true
    } else {
      if pt.0 < x0 {
        x0 = pt.0
      }
      if pt.1 < y0 {
        y0 = pt.1
      }
      if pt.0 > x1 {
        x1 = pt.0
      }
      if pt.1 > y1 {
        y1 = pt.1
      }
    }
  }
  if any {
    Some((x0, y0, x1, y1))
  } else {
    None
  }
}

///|
/// 区域表包围盒（所有区域所有环的所有点）；空表或无环返回 None。
pub fn geo_bbox(
  regions : Array[GeoRegion],
) -> (Double, Double, Double, Double)? {
  let points : Array[(Double, Double)] = []
  for r in regions {
    for ring in r.rings {
      for pt in ring {
        points.push(pt)
      }
    }
  }
  geo_bbox_points(points)
}

///|
/// 包围盒适配：把经纬度包围盒 (min_lon, min_lat, max_lon, max_lat) 按
/// 自身长宽比居中缩进 w×h（保持形状不变形，返回的矩形落在 (0,0)-
/// (w,h) 内，调用方自行平移到目标位置）；退化轴（宽或高为 0）给 1 度
/// 最小跨度，w/h 非正时退化为 0 尺寸。
pub fn geo_fit_rect(
  bbox : (Double, Double, Double, Double),
  w : Double,
  h : Double,
) -> @yue.RectF {
  let (x0, y0, x1, y1) = bbox
  let bw = if x1 - x0 < 1.0e-9 { 1.0 } else { x1 - x0 }
  let bh = if y1 - y0 < 1.0e-9 { 1.0 } else { y1 - y0 }
  let scale = (w / bw).min(h / bh).max(0.0)
  let rw = bw * scale
  let rh = bh * scale
  { x: (w - rw) / 2.0, y: (h - rh) / 2.0, width: rw, height: rh, }
}

///|
/// 地图绘制区：画布四边各留 geo_map_pad 边距；画布过小时贴边收敛，
/// 绘制区最小 1px（超出部分由绘制区外跳过自然裁掉）。
pub fn geo_map_layout(w : Double, h : Double) -> @yue.RectF {
  let px = geo_map_pad.min((w / 2.0).max(0.0))
  let py = geo_map_pad.min((h / 2.0).max(0.0))
  {
    x: px,
    y: py,
    width: (w - px * 2.0).max(1.0),
    height: (h - py * 2.0).max(1.0),
  }
}

///|
/// 环的有向面积（shoelace 公式，经纬度平方度）：逆时针为正、顺时针为
/// 负；点数 < 3 返回 0。绝对值用于选区域的主轴环。
pub fn geo_shoelace(ring : Array[(Double, Double)]) -> Double {
  let n = ring.length()
  if n < 3 {
    return 0.0
  }
  let mut s = 0.0
  for i in 0..<n {
    let (x0, y0) = ring[i]
    let (x1, y1) = ring[(i + 1) % n]
    s = s + x0 * y1 - x1 * y0
  }
  s / 2.0
}

///|
/// 环的质心（面积质心；面积退化如共线时退化为顶点均值）；空环返回
/// (0, 0)。与环的绕向无关。
pub fn geo_ring_centroid(ring : Array[(Double, Double)]) -> (Double, Double) {
  let n = ring.length()
  if n == 0 {
    return (0.0, 0.0)
  }
  let mut sx = 0.0
  let mut sy = 0.0
  for pt in ring {
    sx = sx + pt.0
    sy = sy + pt.1
  }
  let mean = (sx / n.to_double(), sy / n.to_double())
  let a2 = geo_shoelace(ring)
  if a2.abs() < 1.0e-12 {
    return mean
  }
  let mut cx = 0.0
  let mut cy = 0.0
  for i in 0..<n {
    let (x0, y0) = ring[i]
    let (x1, y1) = ring[(i + 1) % n]
    let cross = x0 * y1 - x1 * y0
    cx = cx + (x0 + x1) * cross
    cy = cy + (y0 + y1) * cross
  }
  (cx / (6.0 * a2), cy / (6.0 * a2))
}

///|
/// 区域质心：取 |面积| 最大环（主轴环，避免小内环把标签拉偏）的质心；
/// 区域无环返回 None。
pub fn geo_region_centroid(region : GeoRegion) -> (Double, Double)? {
  let mut best : Array[(Double, Double)]? = None
  let mut best_a = -1.0
  for ring in region.rings {
    let a = geo_shoelace(ring).abs()
    if a > best_a {
      best_a = a
      best = Some(ring)
    }
  }
  match best {
    Some(ring) => Some(geo_ring_centroid(ring))
    None => None
  }
}

///|
/// 区域名标签是否放得下：以 (cx, cy) 为中心的 lw×lh 标签盒完整落在
/// rect 内（超出绘制区的标签不画，避免半截文字）。
pub fn geo_label_fits(
  cx : Double,
  cy : Double,
  lw : Double,
  lh : Double,
  rect : @yue.RectF,
) -> Bool {
  cx - lw / 2.0 >= rect.x &&
  cx + lw / 2.0 <= rect.x + rect.width &&
  cy - lh / 2.0 >= rect.y &&
  cy + lh / 2.0 <= rect.y + rect.height
}

// ---------------------------------------------------------------------------
// 纯函数层：飞线几何（控制点 / 二次贝塞尔 / 弧线采样，白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 飞线：from/to 为起终点的经纬度点对 (lon, lat)。
pub(all) struct GeoFlight {
  from : (Double, Double)
  to : (Double, Double)
}

///|
/// 建飞线（from/to 为经纬度点对）。
pub fn GeoFlight::make(
  from : (Double, Double),
  to : (Double, Double),
) -> GeoFlight {
  { from, to, }
}

///|
/// 飞线二次贝塞尔控制点：起终方向向量的法向 ((dy, -dx) 单位化，画布 y
/// 向下时弧凸向上) 叠加到起终中点，偏移量 = bend × 起终距离（bend 默认
/// 0.2）；起终重合时返回中点。坐标系任意（经纬度/画布均适用），绘制层
/// 在投影后的画布坐标上调用，使弧凸量在视觉上均匀。
pub fn geo_flight_ctrl(
  from : (Double, Double),
  to : (Double, Double),
  bend? : Double = 0.2,
) -> (Double, Double) {
  let mid = ((from.0 + to.0) / 2.0, (from.1 + to.1) / 2.0)
  let dx = to.0 - from.0
  let dy = to.1 - from.1
  let len = @math.pow(dx * dx + dy * dy, 0.5)
  if len < 1.0e-9 {
    return mid
  }
  let off = len * bend
  (mid.0 + dy / len * off, mid.1 - dx / len * off)
}

///|
/// 二次贝塞尔取点：B(t) = (1-t)²·p0 + 2(1-t)t·c + t²·p1（t 不钳制，
/// 外插由调用方决定；绘制层只取 0..1）。
pub fn geo_quad_bezier(
  p0 : (Double, Double),
  c : (Double, Double),
  p1 : (Double, Double),
  t : Double,
) -> (Double, Double) {
  let u = 1.0 - t
  let w0 = u * u
  let w1 = 2.0 * u * t
  let w2 = t * t
  (w0 * p0.0 + w1 * c.0 + w2 * p1.0, w0 * p0.1 + w1 * c.1 + w2 * p1.1)
}

///|
/// 飞线弧线采样点：steps 段等参采样，首点为 from、末点为 to（共
/// steps+1 点）；steps < 1 按 1 段。绘制层先投影再调用，或直接对投影
/// 后的画布坐标调用。
pub fn geo_flight_points(
  from : (Double, Double),
  to : (Double, Double),
  bend? : Double = 0.2,
  steps? : Int = 48,
) -> Array[(Double, Double)] {
  let n = if steps < 1 { 1 } else { steps }
  let c = geo_flight_ctrl(from, to, bend~)
  let out : Array[(Double, Double)] = []
  for i in 0..<=n {
    out.push(geo_quad_bezier(from, c, to, i.to_double() / n.to_double()))
  }
  out
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 字符串哈希（FNV-1a 32 位）：区域填充明度微调随区域名稳定（同名同色，
/// 换主题/缩放不变）。
fn geo_name_hash(s : String) -> Int {
  let mut h : Int64 = 0x811C9DC5L
  for ch in s {
    h = (h ^ ch.to_int().to_int64()) * 0x01000193L
    h = (h % 4294967296L + 4294967296L) % 4294967296L
  }
  (h % 2147483647L).to_int()
}

///|
/// 区域填充色：主题主色为底，按区域名哈希做 ±0.06 明度微调（同色系，
/// 相邻区域可分辨）；无名区域（None）不微调。
fn geo_region_color(name : String?) -> String {
  let d = match name {
    Some(n) if n != "" => (geo_name_hash(n) % 13).to_double() / 12.0
    _ => 0.5
  }
  let amount = d * 0.12 - 0.06
  let base = @yue.theme_primary()
  if amount >= 0.0 {
    @yue.lighten_hex(base, amount)
  } else {
    @yue.darken_hex(base, -amount)
  }
}

///|
/// 飞线弧线段颜色：起端主色 → 末端 info 色的分段线性渐变（t 为弧线
/// 归一化位置，0 在起点）；流动感靠分段虚线表达，动画未做。
fn geo_flight_seg_color(t : Double) -> String {
  @yue.mix_hex(@yue.theme_primary(), @yue.theme_info(), 1.0 - t)
}

///|
/// 实心小圆（飞线端点圆点用；整圆 0..tau 一段 arc）。
fn geo_fill_dot(p : @yue.Painter, cx : Double, cy : Double, r : Double) -> Unit {
  p.begin_path()
  p.arc(cx, cy, r, 0.0, tau)
  p.close_path()
  p.fill()
}

///|
/// 末端箭头：沿 (p_from → p_to) 切线方向的小三角（sim 边长 8px，静态）。
fn geo_draw_arrow(
  p : @yue.Painter,
  p_from : (Double, Double),
  p_to : (Double, Double),
  color : String,
) -> Unit {
  let dx = p_to.0 - p_from.0
  let dy = p_to.1 - p_from.1
  let len = @math.pow(dx * dx + dy * dy, 0.5)
  if len < 1.0e-9 {
    return
  }
  let ux = dx / len
  let uy = dy / len
  let s = 8.0
  let back_x = p_to.0 - ux * s
  let back_y = p_to.1 - uy * s
  p.set_fill_color(color)
  p.begin_path()
  p.move_to(p_to.0, p_to.1)
  p.line_to(back_x - uy * s * 0.5, back_y + ux * s * 0.5)
  p.line_to(back_x + uy * s * 0.5, back_y - ux * s * 0.5)
  p.close_path()
  p.fill()
}

///|
/// 区域绘制（画布坐标）：每环按 geo_region_color 半透明填充 + 同色描边；
/// show_labels 时在区域质心画区域名（按可用宽截断，标签盒放得下才画，
/// 无名区域不画）。
fn geo_draw_regions(
  p : @yue.Painter,
  rect : @yue.RectF,
  regions : Array[GeoRegion],
  show_labels : Bool,
) -> Unit {
  for region in regions {
    let color = geo_region_color(region.name)
    for ring in region.rings {
      if ring.length() < 3 {
        continue
      }
      p.set_fill_color(@yue.with_alpha(color, "33"))
      p.begin_path()
      let first = geo_project(ring[0].0, ring[0].1, rect)
      p.move_to(first.0, first.1)
      for i in 1..<ring.length() {
        let pt = geo_project(ring[i].0, ring[i].1, rect)
        p.line_to(pt.0, pt.1)
      }
      p.close_path()
      p.fill()
      p.set_stroke_color(color)
      p.stroke()
    }
    if show_labels {
      match region.name {
        Some(name) if name != "" =>
          match geo_region_centroid(region) {
            Some((clon, clat)) => {
              let (cx, cy) = geo_project(clon, clat, rect)
              let lw = 120.0.min((rect.width - 4.0).max(8.0))
              let text = truncate_to(name, lw)
              if text != "" && geo_label_fits(cx, cy, lw, 16.0, rect) {
                p.draw_text(
                  text,
                  cx - lw / 2.0,
                  cy - 8.0,
                  lw,
                  16.0,
                  align=@yue.Center,
                  valign=@yue.Center,
                  color=@yue.theme_text_primary(),
                  wrap=false,
                )
              }
            }
            None => ()
          }
        _ => ()
      }
    }
  }
}

///|
/// 飞线绘制（画布坐标）：弧线按「3 段可见、3 段隐藏」的虚线分段，逐段
/// 取渐变色（起端主色 → 末端 info 色）；两端画实心圆点（起点主色、终点
/// info 色），末端按切线画小三角箭头。
fn geo_draw_flights(
  p : @yue.Painter,
  rect : @yue.RectF,
  flights : Array[GeoFlight],
) -> Unit {
  for f in flights {
    // 弧线在投影后的画布坐标上采样（控制点法向偏移量与视觉弧凸一致）
    let pts = geo_flight_points(f.from, f.to, bend=0.2, steps=48)
    let cp : Array[(Double, Double)] = []
    for pt in pts {
      cp.push(geo_project(pt.0, pt.1, rect))
    }
    let n = cp.length()
    if n < 2 {
      continue
    }
    let last = n - 1
    for i in 0..<last {
      if i % 6 >= 3 {
        continue
      }
      p.set_stroke_color(geo_flight_seg_color(i.to_double() / last.to_double()))
      p.begin_path()
      p.move_to(cp[i].0, cp[i].1)
      p.line_to(cp[i + 1].0, cp[i + 1].1)
      p.stroke()
    }
    p.set_fill_color(@yue.theme_primary())
    geo_fill_dot(p, cp[0].0, cp[0].1, 3.0)
    p.set_fill_color(@yue.theme_info())
    geo_fill_dot(p, cp[last].0, cp[last].1, 3.0)
    geo_draw_arrow(p, cp[last - 1], cp[last], @yue.theme_info())
  }
}

///|
/// 地图绘制（画布坐标，数据已由调用方取出）：绘制区取 geo_map_layout；
/// 投影矩形 = 区域环与飞线端点的合并包围盒经 geo_fit_rect 适配（保持
/// 形状不变形，飞线两端落在区域外也完整可见），无数据时铺满绘制区并画
/// 「暂无数据」提示；区域先画（填充+描边+质心名标签），飞线后画（弧线
/// 盖在区域之上）。
fn geo_draw_map(
  p : @yue.Painter,
  w : Double,
  h : Double,
  regions : Array[GeoRegion],
  flights : Array[GeoFlight],
  show_labels : Bool,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let plot = geo_map_layout(w, h)
  let points : Array[(Double, Double)] = []
  for r in regions {
    for ring in r.rings {
      for pt in ring {
        points.push(pt)
      }
    }
  }
  for f in flights {
    points.push(f.from)
    points.push(f.to)
  }
  let rect : @yue.RectF = match geo_bbox_points(points) {
    Some(b) => {
      let fit = geo_fit_rect(b, plot.width, plot.height)
      {
        x: plot.x + fit.x,
        y: plot.y + fit.y,
        width: fit.width,
        height: fit.height,
      }
    }
    None => plot
  }
  if points.length() == 0 {
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
      w / 2.0 - tw / 2.0,
      h / 2.0 - 10.0,
      tw + 4.0,
      20.0,
    )
    return
  }
  geo_draw_regions(p, rect, regions, show_labels)
  geo_draw_flights(p, rect, flights)
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 地图与飞线（EP Map + Lines）：GeoJSON 区域表按等距圆柱投影绘制（区域
/// 填充 + 描边，同色系按区域名哈希微调明度），区域名标签画在质心（按
/// 可用宽截断，放得下才画，show_labels=false 关闭）；飞线为起终经纬度
/// 点对间的二次贝塞尔弧线（控制点取中点法向偏移，分段渐变虚线 + 端点
/// 圆点 + 末端箭头，静态表现，无动画）。hover 高亮未做。数据不内置：
/// regions 经 Store 驱动（set 后只重绘画布不重建视图树），文本解析走
/// [geojson_parse]；主题切换现取色自动跟随。fill=true 不设固定宽度，
/// 横向铺满父容器（跟随窗口伸缩）。
pub fn geo_map_t(
  regions : @yue.Store[Array[GeoRegion]],
  flights? : Array[GeoFlight] = [],
  show_labels? : Bool = true,
  fill? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let size_style : Array[(String, &@yue.StyVal)] = if fill {
        [("height", 360.0)]
      } else {
        [("width", 560.0), ("height", 360.0)]
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
        geo_draw_map(p, b.width, b.height, regions.get(), flights, show_labels)
      })
      regions.subscribe(fn(_r) { @yue.ViewLike::schedule_paint(cv) })
      @yue.attach(parent, @yue.ViewLike::view(cv))
      @yue.ViewLike::view(cv)
    },
  }
}
