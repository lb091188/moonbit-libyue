// 矩形树图组件（EP Chart Treemap 对标，纯 MoonBit 全自绘，Painter 承载）：
//   tm_chart_t   层级数据矩形树图：面积∝value 的正交切分（squarified
//                 宽高比优化），兄弟节点同色系不同明度，父子层级可展开
//                 两层（子项在父矩形内递归布局，可选），间隙留白，
//                 名称 + 数值双行标签（空间不足截断），hover 命中
//                 最深可见格
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （theme_apply 切换深浅即重绘跟随，兄弟明度色阶随主色现取重算）；
// 数据经 Store 驱动，set 后只 schedule_paint 画布，不重建视图树。
// 纯函数（节点计值 / 行最差宽高比 / squarified 行划分 / 矩形序列 /
// 层级布局 / 标签排布 / 兄弟取色）集中在文件头部，
// charts_treemap_wbtest.mbt 白盒覆盖。

// ---------------------------------------------------------------------------
// 纯函数层：节点计值 / 行判定 / squarified 切分 / 层级布局 / 标签 / 取色
// （白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 矩形树图节点（名称）：value 为自身量值，children 非空时该项为父节点
/// ——计值（矩形面积的量纲）自身 value > 0 时取之，否则子项递归合计，
/// 全零退化为 0（不参与布局）。
pub(all) struct TmItem {
  name : String
  value : Double
  children : Array[TmItem]
}

///|
/// 建矩形树图节点（value 默认 0，children 默认空）。
pub fn TmItem::make(
  name : String,
  value? : Double = 0.0,
  children? : Array[TmItem] = [],
) -> TmItem {
  { name, value, children, }
}

///|
/// 节点计值：自身 value > 0 取之，否则子项递归合计；全零给 0
/// （布局时按非正值跳过，不出矩形）。
pub fn tm_value_of(item : TmItem) -> Double {
  if item.value > 0.0 {
    return item.value
  }
  let mut tot = 0.0
  for c in item.children {
    tot = tot + tm_value_of(c)
  }
  tot
}

///|
/// 行的最差宽高比（squarified 行判定量）：areas 为本行各项的**像素面积**
/// （= 计值 × 定标，须与 side 同量纲；传值域会得错序）、side 为行所贴矩形
/// 的短边。行厚 = Σ/side，行长_i = area_i·side/Σ，取行内各项长厚比及其
/// 倒数的大者；空行或 side <= 0 给 0。
pub fn tm_row_worst(areas : Array[Double], side : Double) -> Double {
  if areas.length() == 0 || !(side > 0.0) {
    return 0.0
  }
  let mut sum = 0.0
  for a in areas {
    if a > 0.0 {
      sum = sum + a
    }
  }
  if !(sum > 0.0) {
    return 0.0
  }
  let mut worst = 0.0
  for a in areas {
    if a <= 0.0 {
      continue
    }
    let x = a * side * side / (sum * sum)
    let r = if x > 1.0 { x } else { 1.0 / x }
    if r > worst {
      worst = r
    }
  }
  worst
}

///|
/// squarified 行划分：values（下标保序，非正值剔除）在 w×h 容器内按
/// 宽高比最优切成行——行贴短边（行沿短边排开、厚沿长边），逐项试加入
/// 本行，最差宽高比不降（≤）才收；否则封行，余下矩形重新定向。判定量
/// 走像素面积（值 × 定标，见 [tm_row_worst]）。返回各行原下标表（按
/// 输入序）。空表、全非正值或退化容器给空。
pub fn tm_squarified_rows(
  values : Array[Double],
  w : Double,
  h : Double,
) -> Array[Array[Int]] {
  let rows : Array[Array[Int]] = []
  if !(w > 0.0) || !(h > 0.0) {
    return rows
  }
  // 正项合计（面积定标：容器面积 / 正项合计，切分中守恒）
  let mut total = 0.0
  for v in values {
    if v > 0.0 {
      total = total + v
    }
  }
  let mut rem : Array[Int] = []
  for i, v in values {
    if v > 0.0 {
      rem.push(i)
    }
  }
  if rem.length() == 0 || !(total > 0.0) {
    return rows
  }
  let scale = w * h / total
  let mut rw = w
  let mut rh = h
  // 行数 <= 正项数；兜底计数防浮点退化下的死循环
  let mut budget = rem.length() + 1
  while rem.length() > 0 && budget > 0 {
    budget = budget - 1
    let side = if rw >= rh { rh } else { rw }
    let row : Array[Int] = [rem[0]]
    let mut sum = values[rem[0]]
    let mut k = 1
    while k < rem.length() {
      let cand = values[rem[k]]
      let merged : Array[Double] = []
      for i in row {
        merged.push(values[i] * scale)
      }
      merged.push(cand * scale)
      let stay : Array[Double] = []
      for i in row {
        stay.push(values[i] * scale)
      }
      if tm_row_worst(merged, side) <= tm_row_worst(stay, side) {
        row.push(rem[k])
        sum = sum + cand
        k = k + 1
      } else {
        break
      }
    }
    rows.push(row)
    // 行厚沿长边走，扣掉后余下矩形重定向（area - Σ·scale = scale·(V-Σ)，
    // 定标守恒）——矮宽容器（rw >= rh）：行贴短边 rh，厚沿 x，扣 rw；
    // 瘦高容器：行贴短边 rw，厚沿 y，扣 rh
    if rw >= rh {
      let t = (sum * scale / rh).max(0.0).min(rw)
      rw = (rw - t).max(0.0)
    } else {
      let t = (sum * scale / rw).max(0.0).min(rh)
      rh = (rh - t).max(0.0)
    }
    let rest : Array[Int] = []
    for j in k..<rem.length() {
      rest.push(rem[j])
    }
    rem = rest
  }
  rows
}

///|
/// squarified 矩形序列：values（下标保序）在 rect 内切分，返回与输入同序
/// 的矩形表——正项面积∝value（行沿短边排开、厚沿长边；行内各项沿短边
/// 依序排），非正值给零面积矩形（占位不占面积）。空表、全非正值或退化
/// 矩形给同长零面积表。
pub fn tm_squarified_rects(
  values : Array[Double],
  rect : RectF,
) -> Array[RectF] {
  let n = values.length()
  let zero : RectF = { x: rect.x, y: rect.y, width: 0.0, height: 0.0, }
  if n == 0 {
    return []
  }
  if !(rect.width > 0.0) || !(rect.height > 0.0) {
    return Array::make(n, zero)
  }
  let mut total = 0.0
  for v in values {
    if v > 0.0 {
      total = total + v
    }
  }
  if !(total > 0.0) {
    return Array::make(n, zero)
  }
  let out = Array::make(n, zero)
  let scale = rect.width * rect.height / total
  let rows = tm_squarified_rows(values, rect.width, rect.height)
  let mut ox = rect.x
  let mut oy = rect.y
  let mut rw = rect.width
  let mut rh = rect.height
  for row in rows {
    let mut sum = 0.0
    for i in row {
      sum = sum + values[i]
    }
    if rw >= rh {
      // 矮宽矩形：行沿短边 y 排开，整行跨度 rh、厚 t 沿 x；行内各项
      // 沿 y 并排，每项长 = value·scale/t（= area·side/Σ，
      // 与 tm_row_worst 同源）
      let t = (sum * scale / rh).max(0.0).min(rw)
      let mut cy = oy
      for i in row {
        let hh = (values[i] * scale / t).max(0.0)
        out[i] = { x: ox, y: cy, width: t, height: hh, }
        cy = cy + hh
      }
      ox = ox + t
      rw = (rw - t).max(0.0)
    } else {
      // 瘦高矩形：行沿短边 x 排开，整行跨度 rw、厚 t 沿 y；行内各项
      // 沿 x 并排
      let t = (sum * scale / rw).max(0.0).min(rh)
      let mut cx = ox
      for i in row {
        let ww = (values[i] * scale / t).max(0.0)
        out[i] = { x: cx, y: oy, width: ww, height: t, }
        cx = cx + ww
      }
      oy = oy + t
      rh = (rh - t).max(0.0)
    }
  }
  out
}

///|
/// 层级布局：items 在 rect 内按 [tm_squarified_rects] 切分（正项计时值
/// 取 [tm_value_of]）。depth 为展开层数——1 只排顶层，2 顶层 + 子项在
/// 父矩形内递归（子层顶部留 18px 名称带、四边再内缩 gap/2），更大值
/// 继续递归；gap 为兄弟间隙（每格四边内缩 gap/2，相邻格间留 gap）。
/// 返回拍平的（项, 矩形）表——父项先出、其子项连续随后（深度优先序），
/// 非正值项与退化矩形不产出。
pub fn tm_layout(
  items : Array[TmItem],
  rect : RectF,
  depth? : Int = 2,
  gap? : Double = 4.0,
) -> Array[(TmItem, RectF)] {
  tm_layout_nest(items, rect, depth, gap)
}

///|
/// 子层名称带预留高（父矩形顶部留给名称标签一行）。
let tm_header_h : Double = 18.0

///|
fn tm_layout_nest(
  items : Array[TmItem],
  rect : RectF,
  depth : Int,
  gap : Double,
) -> Array[(TmItem, RectF)] {
  let out : Array[(TmItem, RectF)] = []
  if items.length() == 0 || depth < 1 {
    return out
  }
  if !(rect.width > 0.0) || !(rect.height > 0.0) {
    return out
  }
  let vals : Array[Double] = []
  for it in items {
    vals.push(tm_value_of(it))
  }
  let raw = tm_squarified_rects(vals, rect)
  for i, it in items {
    if !(vals[i] > 0.0) {
      continue
    }
    let r0 = raw[i]
    let cell : RectF = if gap > 0.0 {
      {
        x: r0.x + gap / 2.0,
        y: r0.y + gap / 2.0,
        width: (r0.width - gap).max(0.0),
        height: (r0.height - gap).max(0.0),
      }
    } else {
      r0
    }
    out.push((it, cell))
    if depth > 1 && it.children.length() > 0 {
      let header = if cell.height > tm_header_h { tm_header_h } else { 0.0 }
      let inner : RectF = {
        x: cell.x + gap / 2.0,
        y: cell.y + header + gap / 2.0,
        width: (cell.width - gap).max(0.0),
        height: (cell.height - header - gap).max(0.0),
      }
      let kids = tm_layout_nest(it.children, inner, depth - 1, gap)
      for e in kids {
        out.push(e)
      }
    }
  }
  out
}

///|
/// 标签排布：h >= 30 给名称 + 数值两行（16..30 只给名称，以下不显示）；
/// 可用宽不足 8px 一律不显示。名称按可用宽截断（等宽估算，复用 charts 的
/// truncate_to 手法），数值走 fmt_axis 多级单位缩写。
pub fn tm_label_lines(
  name : String,
  value : Double,
  w : Double,
  h : Double,
) -> (String, String) {
  let nm = truncate_to(name, (w - 8.0).max(0.0))
  if h < 16.0 || nm == "" {
    ("", "")
  } else if h >= 30.0 {
    (nm, fmt_axis(value))
  } else {
    (nm, "")
  }
}

///|
/// 兄弟节点取色：同一父节点下的子项沿主题主色的 HSL 明度轴均摊（i 越小
/// 越亮、越大越暗，色相与饱和度跟随主色，主题切换现取）；n <= 1 直接取
/// 主色；主色不可解析时退化为主题主色。
pub fn tm_sibling_color(i : Int, n : Int) -> String {
  let base = theme_primary()
  if n <= 1 {
    return base
  }
  match parse_hex(base) {
    None => base
    Some((r, g, b)) => {
      let (h, s, l) = rgb_to_hsl(r, g, b)
      // 明度摆幅随主色明度自适应：两端各留 0.10 余量，色不糊不焦
      let room = (0.90 - l).min(l - 0.10).max(0.02)
      let t = if i < 0 {
        0.0
      } else if i >= n {
        1.0
      } else {
        i.to_double() / (n - 1).to_double()
      }
      let nl = (l + (0.5 - t) * 2.0 * room).max(0.10).min(0.90)
      from_hsl(h, s.max(0.25), nl)
    }
  }
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 父节点框底色：主色低透叠面板底（深浅主题下跟随，子格盖上去后仅在
/// 间隙与名称带可见）。
fn tm_parent_fill() -> String {
  mix_hex(theme_primary(), theme_bg_panel(), 0.12)
}

///|
/// 矩形树图绘制（递归，画布坐标）：levels 为展开层数（1=只排顶层，
/// >1 才把父矩形让给子项），gap 为兄弟间隙。本层按 [tm_layout] 切分后
/// 逐格绘制——父格先画浅底 + 描边 + 名称带，子格后画盖上；叶子格按兄弟
/// 序取 [tm_sibling_color] 填色 + 名称/数值标签（空间不足按
/// [tm_label_lines] 截断），hover 格提亮 + 描边。拍平画卷
/// (项, 矩形, 兄弟序, 兄弟数) 追加进 flat——hover 命中与绘制同源。
fn tm_draw_nodes(
  p : Painter,
  items : Array[TmItem],
  rect : RectF,
  levels : Int,
  gap : Double,
  hover : Int,
  flat : Array[(TmItem, RectF, Int, Int)],
) -> Unit {
  if items.length() == 0 || levels < 1 {
    return
  }
  if !(rect.width > 0.0) || !(rect.height > 0.0) {
    return
  }
  let cells = tm_layout(items, rect, depth=1, gap~)
  let n = cells.length()
  for i in 0..<n {
    let (item, cell) = cells[i]
    let key = flat.length()
    flat.push((item, cell, i, n))
    let v = tm_value_of(item)
    let expand = item.children.length() > 0 && levels > 1
    let color = if expand { tm_parent_fill() } else { tm_sibling_color(i, n) }
    let hot = hover == key
    p.set_fill_color(
      if hot && !expand {
        lighten_hex(color, 0.10)
      } else {
        color
      },
    )
    p.fill_rect(cell.x, cell.y, cell.width, cell.height)
    if hot {
      p.set_stroke_color(theme_text_primary())
      p.stroke_rect(
        cell.x + 0.5,
        cell.y + 0.5,
        (cell.width - 1.0).max(0.0),
        (cell.height - 1.0).max(0.0),
      )
    } else if expand {
      p.set_stroke_color(theme_border())
      p.stroke_rect(
        cell.x + 0.5,
        cell.y + 0.5,
        (cell.width - 1.0).max(0.0),
        (cell.height - 1.0).max(0.0),
      )
    }
    let header = if cell.height > tm_header_h { tm_header_h } else { 0.0 }
    if expand {
      // 名称带（顶部一行，垂直居中于带内）
      let name = truncate_to(item.name, (cell.width - 8.0).max(0.0))
      if name != "" && header > 0.0 {
        p.draw_text(
          name,
          cell.x + 4.0,
          cell.y + (header - 16.0) / 2.0,
          (cell.width - 8.0).max(0.0),
          16.0,
          align=Start,
          valign=Center,
          color=theme_text_primary(),
          wrap=false,
        )
      }
      let inner : RectF = {
        x: cell.x + gap / 2.0,
        y: cell.y + header + gap / 2.0,
        width: (cell.width - gap).max(0.0),
        height: (cell.height - header - gap).max(0.0),
      }
      tm_draw_nodes(p, item.children, inner, levels - 1, gap, hover, flat)
    } else {
      let (nm, val) = tm_label_lines(item.name, v, cell.width, cell.height)
      if nm != "" {
        p.draw_text(
          nm,
          cell.x + 4.0,
          cell.y + 2.0,
          (cell.width - 8.0).max(0.0),
          16.0,
          align=Start,
          valign=Center,
          color=theme_text_primary(),
          wrap=false,
        )
      }
      if val != "" {
        p.draw_text(
          val,
          cell.x + 4.0,
          cell.y + 18.0,
          (cell.width - 8.0).max(0.0),
          16.0,
          align=Start,
          valign=Center,
          color=theme_text_secondary(),
          wrap=false,
        )
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 矩形树图（EP Treemap 对标）：层级数据按面积∝value 正交切分
/// （squarified 宽高比优化，拍平画卷与绘制同源）；兄弟节点同色系不同
/// 明度（明度色阶沿主题主色现取，主题切换自动跟随）；levels 为展开层数
/// （默认 2=顶层+子项在父矩形内递归，1=只排顶层），gap 为兄弟间隙留白；
/// 单元格名称 + 数值双行标签（空间不足截断）。hover 命中最后一层可见格
/// （提亮 + 描边），命中表在每次 on_draw 重建、与绘制用同一 layout。
/// 数据经 Store 驱动，set 后只重绘画布不重建视图树。fill=true 不设固定
/// 宽度，横向铺满父容器（跟随窗口伸缩）。
pub fn tm_chart_t(
  items : Store[Array[TmItem]],
  levels? : Int = 2,
  gap? : Double = 4.0,
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  {
    mount: fn(parent) {
      // 拍平画卷（on_draw 重建）：(项, 矩形, 兄弟序, 兄弟数)
      let flat : Array[(TmItem, RectF, Int, Int)] = []
      let hover = Ref(-1)
      let size_style : Array[(String, &StyVal)] = if fill {
        [("height", 360.0)]
      } else {
        [("width", 560.0), ("height", 360.0)]
      }
      for kv in style {
        size_style.push(kv)
      }
      let cv = themed_container(style=size_style)
      handle(cv)
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        flat.clear()
        let pad = 10.0
        let rect : RectF = {
          x: pad,
          y: pad,
          width: (b.width - 2.0 * pad).max(0.0),
          height: (b.height - 2.0 * pad).max(0.0),
        }
        tm_draw_nodes(p, items.get(), rect, levels, gap, hover.val, flat)
      })
      items.subscribe(fn(_d) { ViewLike::schedule_paint(cv) })
      // hover 命中倒序取最深（子项在父项之后入卷，后命中即更深）
      ViewLike::on_mouse_move(cv, fn(e) {
        let mut hit = -1
        for k in 0..<flat.length() {
          let cell = flat[k].1
          if e.view_x >= cell.x &&
            e.view_x < cell.x + cell.width &&
            e.view_y >= cell.y &&
            e.view_y < cell.y + cell.height {
            hit = k
          }
        }
        if hit != hover.val {
          hover.val = hit
          ViewLike::schedule_paint(cv)
        }
      })
      ViewLike::on_mouse_leave(cv, fn(_e) {
        if hover.val != -1 {
          hover.val = -1
          ViewLike::schedule_paint(cv)
        }
      })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
