// 纯 MoonBit 光栅器的覆盖层：扫描线**逐带解析面积**填充 + 描边轮廓生成。
//
// 口径：
// - 纵向 `RASTER_AA_BANDS` 个带，每带内**解析积分**出「这条带与该像素列的精确
//   相交面积」（左右边界在带顶/带底各线性求一次 x，被积函数分段线性、断点只在
//   左右边界撞上列边界处，逐段梯形公式即精确），逐带**累加**——与 cairo 的解析
//   覆盖同档，边缘是连续灰度而不是几档台阶；
// - 历史口径两次都不对：最初是「4×4 数采样点」（覆盖只有 17 档），改「8 子行 +
//   横向精确宽度」后横向连续了，但满覆盖内段仍写 `cov[px] = 256`——那是**赋值**
//   且在带循环里，任何一带整列被包住就置满，纵向从未真正累加，所以近水平边（圆
//   的顶/底）还是一格一格的。现在一律 `+= 带面积`，行尾统一量化一次；
// - 非零环绕：跨点带方向（向下 +1），扫描累积非零即内（cairo_fill 默认同）；
// - 跨点的半开区间判定 (p.y <= ys) != (q.y <= ys)，避免顶点重复计（带心沿用
//   这一 ys 做激活与排序，口径与旧实现逐位等价）；
// - 描边 = 折线偏移轮廓（cairo 默认 miter join 上限 10）：开放折线两侧缝成一条
//   轮廓、两端 butt 帽；闭合折线（含首末点重合的整圆）两侧各成一条闭合轮廓，
//   外圈正向 + 内圈反向，靠非零环绕挖孔；设备线宽 = 用户线宽 × sqrt(|det|)
//   （非均匀缩放的笔帽按近似处理，容差带内，记档）。

///|
/// 纵向解析积分的带数（每带权重 = 256 / 本值）。带内已做精确面积，带数**不贡献
/// 量化台阶**，只影响「同一带内两条边交叉重排」的误差；4 带已把圆/弧/斜边做到
/// 与 cairo 解析覆盖同档，再多只是白花算力。
const RASTER_AA_BANDS : Int = 4

///|
/// 大到等于「无界」的坐标哨兵（不用科学计数法字面量，解析有坑）。
const RASTER_FAR : Double = 1000000000000000000.0

///|
fn raster_min_i(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn raster_max_i(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// 填充一组折线（open 的按自动闭线处理，cairo_fill 语义）。
/// clip 为设备空间整数裁剪区（x0,y0,x1,y1，半开）。
///
/// 覆盖算法（解析面积，与 cairo 同档）：每行先把跨本行的边收进**行内活跃表**，
/// 再用「抗锯齿带边界 ∪ 本行内每条边的端点」把这一行切成若干**切片**；切片内没有
/// 顶点，左右边界都是 y 的线性函数，于是「这条 span 与某个像素列在这段高度里的
/// 相交面积」有闭式解（见 `span_slice_cover`），逐片**累加**即精确覆盖。
/// `RASTER_AA_BANDS` 在这里只用来限制「两条边在同一片内交叉重排」的误差，
/// 不贡献量化台阶。
fn fill_polys(
  bm : Bitmap,
  polys : Array[Poly],
  clip : (Int, Int, Int, Int),
  op : BlendMode,
  src : RSource,
) -> Unit {
  let (cx0, cy0, cx1, cy1) = clip
  if cx1 <= cx0 || cy1 <= cy0 || polys.length() == 0 {
    return
  }
  // 路径包围盒（设备空间）
  let mut bx0 = RASTER_FAR
  let mut by0 = RASTER_FAR
  let mut bx1 = -RASTER_FAR
  let mut by1 = -RASTER_FAR
  for poly in polys {
    for p in poly.pts {
      let (px, py) = p
      if px < bx0 {
        bx0 = px
      }
      if py < by0 {
        by0 = py
      }
      if px > bx1 {
        bx1 = px
      }
      if py > by1 {
        by1 = py
      }
    }
  }
  let x0 = raster_max_i(bx0.floor().to_int(), cx0)
  let y0 = raster_max_i(by0.floor().to_int(), cy0)
  let x1 = raster_min_i((bx1 + 1.0).ceil().to_int(), cx1)
  let y1 = raster_min_i((by1 + 1.0).ceil().to_int(), cy1)
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let width = bm.width
  let cov : FixedArray[Int] = FixedArray::make(width, 0)
  // 覆盖按解析面积累进这条 Double 侧（0..256 制），行尾一次量化
  let cov_f : FixedArray[Double] = FixedArray::make(width, 0.0)
  // ---- 全局边表（GET）----
  // 只登记非水平边；gy_t/gy_b 是两端 y 的下/上，gx_t/gs/gx1/gy1 保存**原始遍历
  // 方向**的端点：x 一律按 `ax + (bx-ax)×t` 现算（同一数学值换写法会有末位差，
  // 边界像素覆盖会翻转，像素断言实测抓红），gw 是环绕方向 ±1。
  let mut total_edges = 0
  for poly in polys {
    let n = poly.pts.length()
    if n >= 2 {
      total_edges += n
    }
  }
  let gy_t : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let gy_b : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let gx_t : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let gs : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let gx1 : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let gy1 : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let gw : FixedArray[Int] = FixedArray::make(total_edges + 1, 0)
  let gidx : Array[Int] = []
  let mut ge = 0
  for poly in polys {
    let pts = poly.pts
    let n = pts.length()
    if n < 2 {
      continue
    }
    // fill 语义：open 折线自动闭到首点——末边 pts[n-1]→pts[0] 就是环绕边，
    // 两种形态都是 n 条边（open 写 n+1 会 pts[n] 越界，真窗口实测）
    for k = 0; k < n; k = k + 1 {
      let (ax, ay) = pts[k]
      let (bx2, by2) = pts[if k + 1 < n { k + 1 } else { 0 }]
      if ay == by2 {
        continue
      }
      gy_t[ge] = if ay < by2 { ay } else { by2 }
      gy_b[ge] = if ay < by2 { by2 } else { ay }
      gx_t[ge] = ax
      gs[ge] = ay
      gx1[ge] = bx2
      gy1[ge] = by2
      gw[ge] = if by2 > ay { 1 } else { -1 }
      ge += 1
    }
  }
  for i = 0; i < ge; i = i + 1 {
    let _ = gidx.push(i)
  }
  gidx.sort_by(fn(a, b) { gy_t[a].compare(gy_t[b]) })
  // 行内活跃表（跨本行的边）与切片用的三条 x（片顶/片底/片中）+ 环绕方向
  let row_e : FixedArray[Int] = FixedArray::make(total_edges + 1, 0)
  let mut row_len = 0
  let sl_e : FixedArray[Int] = FixedArray::make(total_edges + 1, 0)
  let sl_m : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let sl_t : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let sl_b : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let sl_w : FixedArray[Int] = FixedArray::make(total_edges + 1, 0)
  // 临界 y 缓冲：每条边贡献两个端点，加上带边界与行首尾
  let cuts : FixedArray[Double] = FixedArray::make(total_edges * 2 + 8, 0.0)
  let band_h = 1.0 / RASTER_AA_BANDS.to_double()
  let mut gp = 0 // GET 指针（gy_t 升序，随行单调推进）
  for y = y0; y < y1; y = y + 1 {
    for i = x0; i < x1; i = i + 1 {
      cov[i] = 0
      cov_f[i] = 0.0
    }
    let mut ink_l = x1
    let mut ink_r = x0
    let yr0 = y.to_double()
    let yr1 = yr0 + 1.0
    // 行内活跃表：先丢掉上端已过的边，再按 GET 收进下端未过行尾的边
    let mut w = 0
    for i = 0; i < row_len; i = i + 1 {
      let e = row_e[i]
      if gy_b[e] > yr0 {
        row_e[w] = e
        w += 1
      }
    }
    row_len = w
    while gp < ge {
      let e = gidx[gp]
      if gy_t[e] >= yr1 {
        break
      }
      if gy_b[e] > yr0 {
        row_e[row_len] = e
        row_len += 1
      }
      gp += 1
    }
    if row_len < 2 {
      continue
    }
    // 临界 y：行首末 + 带边界 + 每条活跃边被裁到本行内的两个端点
    let mut nc = 0
    cuts[nc] = yr0
    nc += 1
    for b = 1; b < RASTER_AA_BANDS; b = b + 1 {
      cuts[nc] = yr0 + band_h * b.to_double()
      nc += 1
    }
    cuts[nc] = yr1
    nc += 1
    for i = 0; i < row_len; i = i + 1 {
      let e = row_e[i]
      cuts[nc] = if gy_t[e] > yr0 { gy_t[e] } else { yr0 }
      nc += 1
      cuts[nc] = if gy_b[e] < yr1 { gy_b[e] } else { yr1 }
      nc += 1
    }
    // 临界值就地插入排序（数量 = 带边界 + 每边两个端点，行内近有序，几乎线性）
    let mut q = 1
    while q < nc {
      let vq = cuts[q]
      let mut jq = q - 1
      while jq >= 0 && cuts[jq] > vq {
        cuts[jq + 1] = cuts[jq]
        jq -= 1
      }
      cuts[jq + 1] = vq
      q += 1
    }
    // 逐切片扫描（相邻重复的临界值退化成零高，跳过）
    for k = 1; k < nc; k = k + 1 {
      let s0 = cuts[k - 1]
      let s1 = cuts[k]
      let sh = s1 - s0
      if sh <= 0.000000001 {
        continue
      }
      let mid = (s0 + s1) * 0.5
      let mut n_sl = 0
      for i = 0; i < row_len; i = i + 1 {
        let e = row_e[i]
        if gy_t[e] <= mid && gy_b[e] > mid {
          let dy = gy1[e] - gs[e]
          let kk = gx1[e] - gx_t[e]
          sl_e[n_sl] = e
          sl_m[n_sl] = gx_t[e] + kk * ((mid - gs[e]) / dy)
          sl_t[n_sl] = gx_t[e] + kk * ((s0 - gs[e]) / dy)
          sl_b[n_sl] = gx_t[e] + kk * ((s1 - gs[e]) / dy)
          sl_w[n_sl] = gw[e]
          n_sl += 1
        }
      }
      if n_sl < 2 {
        continue
      }
      // 按片中 x 插入排序（片内无顶点，序稳定；活跃表本就近有序，几乎线性）
      for i = 1; i < n_sl; i = i + 1 {
        let xm = sl_m[i]
        let ei = sl_e[i]
        let xt = sl_t[i]
        let xb2 = sl_b[i]
        let wi = sl_w[i]
        let mut j = i - 1
        while j >= 0 && sl_m[j] > xm {
          sl_m[j + 1] = sl_m[j]
          sl_e[j + 1] = sl_e[j]
          sl_t[j + 1] = sl_t[j]
          sl_b[j + 1] = sl_b[j]
          sl_w[j + 1] = sl_w[j]
          j -= 1
        }
        sl_m[j + 1] = xm
        sl_e[j + 1] = ei
        sl_t[j + 1] = xt
        sl_b[j + 1] = xb2
        sl_w[j + 1] = wi
      }
      // 非零环绕配对成 span：wind 累计到本条为止（左边界 = 上一条交叉边）
      let mut wind = 0
      for i2 = 1; i2 < n_sl; i2 = i2 + 1 {
        wind = wind + sl_w[i2 - 1]
        if wind == 0 {
          continue
        }
        let la0 = sl_t[i2 - 1]
        let la1 = sl_b[i2 - 1]
        let ra0 = sl_t[i2]
        let ra1 = sl_b[i2]
        // 不在这里过滤「片顶或片底两端重合」的退化 span：那正是顶点所在的片，
        // 面积是个三角形而非零，交给下面的解析积分（它含 la=ra 这个断点）
        let l_lo = if la0 < la1 { la0 } else { la1 }
        let l_hi = if la0 < la1 { la1 } else { la0 }
        let r_lo = if ra0 < ra1 { ra0 } else { ra1 }
        let r_hi = if ra0 < ra1 { ra1 } else { ra0 }
        let p0 = raster_max_i(l_lo.floor().to_int(), x0)
        let p1 = raster_min_i(r_hi.ceil().to_int(), x1)
        if p1 <= p0 {
          continue
        }
        if p0 < ink_l {
          ink_l = p0
        }
        if p1 > ink_r {
          ink_r = p1
        }
        // 片顶与片底都把整列包住的列 ⇒ 覆盖就是这片的高度，免逐列积分
        let f0 = raster_max_i(l_hi.ceil().to_int(), x0)
        let f1 = raster_min_i(r_lo.floor().to_int(), x1)
        let hs = sh * 256.0
        let mut px = p0
        while px < p1 {
          if px >= f0 && px < f1 {
            cov_f[px] = cov_f[px] + hs
          } else {
            cov_f[px] = cov_f[px] + span_slice_cover(px, la0, la1, ra0, ra1) * hs
          }
          px = px + 1
        }
      }
    }
    if ink_r > ink_l {
      let mut px = ink_l
      while px < ink_r {
        let v = cov_f[px]
        cov[px] =
          if v <= 0.0 {
            0
          } else if v >= 256.0 {
            256
          } else {
            v.round().to_int()
          }
        px = px + 1
      }
      composite_span(bm.data, width, y, ink_l, ink_r, cov, op, src)
    }
  }
}

///|
/// 一个切片内，span 的左右边界与像素列 [px, px+1) 的**精确相交面积占该片高度的
/// 比例**（0..1）。左右边界都是片内 y 的线性函数（la0→la1、ra0→ra1，s∈[0,1]），
/// 被积函数
///   f(s) = min(right(s), px+1) − max(left(s), px)
/// 分段线性，断点只可能出现在左右边界各撞上 px 或 px+1、以及两边重逢（span 收口）
/// 处；把这些 s 排进断点表后逐段用梯形公式积分**就是精确值**（线性段积分无误差）。
/// 整列被包住的情形由调用方走快路径，不进这里。
fn span_slice_cover(
  px : Int,
  la0 : Double,
  la1 : Double,
  ra0 : Double,
  ra1 : Double,
) -> Double {
  let c0 = px.to_double()
  let c1 = c0 + 1.0
  let dl = la1 - la0
  let dr = ra1 - ra0
  let pts : Array[Double] = [0.0, 1.0]
  if dl.abs() > 0.000000001 {
    let t0 = (c0 - la0) / dl
    let t1 = (c1 - la0) / dl
    if t0 > 0.0 && t0 < 1.0 {
      let _ = pts.push(t0)
    }
    if t1 > 0.0 && t1 < 1.0 {
      let _ = pts.push(t1)
    }
  }
  if dr.abs() > 0.000000001 {
    let t0 = (c0 - ra0) / dr
    let t1 = (c1 - ra0) / dr
    if t0 > 0.0 && t0 < 1.0 {
      let _ = pts.push(t0)
    }
    if t1 > 0.0 && t1 < 1.0 {
      let _ = pts.push(t1)
    }
  }
  let dd = dr - dl
  if dd.abs() > 0.000000001 {
    let t0 = (la0 - ra0) / dd
    if t0 > 0.0 && t0 < 1.0 {
      let _ = pts.push(t0)
    }
  }
  pts.sort()
  let mut area = 0.0
  for i = 1; i < pts.length(); i = i + 1 {
    let sa = pts[i - 1]
    let sb = pts[i]
    if sb > sa {
      let la = la0 + dl * sa
      let lb = la0 + dl * sb
      let ra = ra0 + dr * sa
      let rb = ra0 + dr * sb
      let fa = (if ra < c1 { ra } else { c1 }) - (if la > c0 { la } else { c0 })
      let fb = (if rb < c1 { rb } else { c1 }) - (if lb > c0 { lb } else { c0 })
      let d = (fa + fb) * 0.5 * (sb - sa)
      if d > 0.0 {
        area += d
      }
    }
  }
  if area > 1.0 {
    1.0
  } else {
    area
  }
}
///|
/// 折线一侧的**闭合**偏移轮廓：逐顶点求相邻两条偏移线的交点（miter，超限退
/// bevel）。零长边与重复点先剔除，末点回绕到首点，接缝顶点同样求交。
/// `hw` 取正为左侧、取负为右侧。顶点不足三个时返回空。
fn loop_offsets(
  pts : Array[(Double, Double)],
  hw : Double,
  miter2 : Double,
) -> Array[(Double, Double)] {
  let res : Array[(Double, Double)] = []
  let v : Array[(Double, Double)] = []
  for p in pts {
    let (px, py) = p
    match v.last() {
      None => v.push(p)
      Some((lx, ly)) => {
        if (px - lx).abs() > 0.000000001 || (py - ly).abs() > 0.000000001 {
          v.push(p)
        }
      }
    }
  }
  if v.length() > 1 {
    let (fx, fy) = v[0]
    match v.last() {
      None => ()
      Some((lx, ly)) => {
        if (lx - fx).abs() < 0.000000001 && (ly - fy).abs() < 0.000000001 {
          let _ = v.pop()
        }
      }
    }
  }
  let m = v.length()
  if m < 3 {
    return res
  }
  let ux : Array[Double] = []
  let uy : Array[Double] = []
  for i = 0; i < m; i = i + 1 {
    let (ax, ay) = v[i]
    let (bx, by) = v[(i + 1) % m]
    let dx = bx - ax
    let dy = by - ay
    let len = (dx * dx + dy * dy).sqrt()
    ux.push(dx / len)
    uy.push(dy / len)
  }
  for i = 0; i < m; i = i + 1 {
    let (ax, ay) = v[i]
    let (bx, by) = v[(i + 1) % m]
    let prev = (i + m - 1) % m
    let pux = ux[prev]
    let puy = uy[prev]
    let cu = ux[i]
    let cv = uy[i]
    let nx = -cv * hw
    let ny = cu * hw
    let pnx = -puy * hw
    let pny = pux * hw
    let det = pux * cv - puy * cu
    if det.abs() < 0.000000001 {
      res.push((ax + pnx, ay + pny))
    } else {
      let rx = nx - pnx
      let ry = ny - pny
      let s = (rx * cv - ry * cu) / det
      let mx = ax + pnx + pux * s
      let my = ay + pny + puy * s
      let d1x = mx - (ax + nx)
      let d1y = my - (ay + ny)
      if d1x * d1x + d1y * d1y > miter2 {
        res.push((ax + pnx, ay + pny))
        res.push((ax + nx, ay + ny))
      } else {
        res.push((mx, my))
      }
    }
    res.push((bx + nx, by + ny))
  }
  res
}

///|
/// 描边轮廓：折线 → 闭合填充多边形。开放折线两侧缝成一条轮廓并加 butt 端帽；
/// 闭合折线（含首末点重合的整圆）两侧各自成环，外圈正向、内圈反向。
fn stroke_polys(
  polys : Array[Poly],
  lw : Double,
) -> Array[Poly] {
  let out : Array[Poly] = []
  if lw <= 0.0 {
    return out
  }
  let half = lw / 2.0
  let miter2 = (10.0 * half) * (10.0 * half) // miter 长度²上限（limit 10）
  for poly in polys {
    let pts = poly.pts
    let n = pts.length()
    if n < 2 {
      continue
    }
    // 首末点重合的子路径（整圆 arc 不 close_path 就是这种）按闭线处理：接头求交、
    // 不加端帽，否则缝合处两个 butt 端帽之间留出一道缝
    let (fx, fy) = pts[0]
    let (lx, ly) = pts[n - 1]
    let is_loop =
      poly.closed ||
        (n >= 3 && (lx - fx).abs() < 0.000000001 && (ly - fy).abs() < 0.000000001)
    let edges = if is_loop { n } else { n - 1 }
    if edges < 1 {
      continue
    }
    if is_loop {
      // 闭合折线：两侧各自是一条闭合轮廓——外圈正向、内圈反向，非零环绕自动
      // 挖出中间的孔。早先把两条侧线缝成一条轮廓，缝合处两圈环绕相消，圆环
      // 上就出现沿线的空洞（radio 外圈缺口的根因）。
      let outer = loop_offsets(pts, half, miter2)
      let inner = loop_offsets(pts, -half, miter2)
      if outer.length() >= 3 && inner.length() >= 3 {
        out.push({ pts: outer, closed: true })
        let rev : Array[(Double, Double)] = []
        for i = inner.length() - 1; i >= 0; i = i - 1 {
          rev.push(inner[i])
        }
        out.push({ pts: rev, closed: true })
      }
      continue
    }
    let side_a : Array[(Double, Double)] = []
    let side_b : Array[(Double, Double)] = []
    // 首条有效边的偏移点
    let mut started = false
    let mut pdx = 0.0
    let mut pdy = 0.0 // 上一条边方向（单位）
    for k = 0; k < edges; k = k + 1 {
      let (ax, ay) = pts[k]
      let (bx2, by2) = pts[if k + 1 < n { k + 1 } else { 0 }]
      let dx = bx2 - ax
      let dy = by2 - ay
      let len = (dx * dx + dy * dy).sqrt()
      if len < 0.000000001 {
        continue // 零长边跳过
      }
      let ux = dx / len
      let uy = dy / len
      let nx = -uy * half // 当前边左法线偏移
      let ny = ux * half
      if !started {
        side_a.push((ax + nx, ay + ny))
        side_b.push((ax - nx, ay - ny))
        side_a.push((bx2 + nx, by2 + ny))
        side_b.push((bx2 - nx, by2 - ny))
        pdx = ux
        pdy = uy
        started = true
        continue
      }
      // 接头：prev 与当前偏移线交点（两侧对称：sideB 交点 = 2P − sideA 交点）
      let det = pdx * uy - pdy * ux
      if det.abs() < 0.000000001 {
        // 平行/共线：bevel（两侧角点）
        side_a.push((bx2 + nx, by2 + ny))
        side_b.push((bx2 - nx, by2 - ny))
      } else {
        // 两条偏移线求交：M = P + pn + s·prev（s 为沿 prev 的参数）。由
        // s·prev − t·cur = n − pn 两边叉乘 cur 解得 s = cross(r, cur)/det。
        let pnx = -pdy * half
        let pny = pdx * half
        let rx = nx - pnx
        let ry = ny - pny
        let s = (rx * uy - ry * ux) / det
        let mx1 = ax + pnx + pdx * s
        let my1 = ay + pny + pdy * s
        // miter 长度 = 偏移角点到交点的距离，超限（ratio > 10）→ bevel
        let d1x = mx1 - (ax + nx)
        let d1y = my1 - (ay + ny)
        if d1x * d1x + d1y * d1y > miter2 {
          side_a.push((ax + nx, ay + ny))
          side_a.push((bx2 + nx, by2 + ny))
          side_b.push((ax - nx, ay - ny))
          side_b.push((bx2 - nx, by2 - ny))
        } else {
          side_a.push((mx1, my1))
          side_b.push((ax * 2.0 - mx1, ay * 2.0 - my1))
        }
      }
      side_a.push((bx2 + nx, by2 + ny))
      side_b.push((bx2 - nx, by2 - ny))
      pdx = ux
      pdy = uy
    }
    if !started {
      continue
    }
    // 轮廓 = 侧 A 正向 + 侧 B 反向（butt 帽 = 两端直接连线）
    let outline : Array[(Double, Double)] = []
    for p in side_a {
      outline.push(p)
    }
    for i = side_b.length() - 1; i >= 0; i = i - 1 {
      outline.push(side_b[i])
    }
    if outline.length() >= 3 {
      out.push({ pts: outline, closed: true })
    }
  }
  out
}
