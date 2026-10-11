// 纯 MoonBit 光栅器的覆盖层：扫描线超采样填充 + 描边轮廓生成。
//
// 口径：
// - 4×4 超采样（每像素 16 个样本，覆盖 0..256，每样本 16）——同一输入的采样
//   与累加全是确定的纯 MoonBit 算术，三平台逐位一致；与 cairo 的解析覆盖差
//   落在 AA 容差带；
// - 非零环绕：跨点带方向（向下 +1），扫描累积非零即内（cairo_fill 默认同）；
// - 跨点的半开区间判定 (p.y <= ys) != (q.y <= ys)，避免顶点重复计；
// - 描边 = 折线偏移轮廓（cairo 默认 miter join 上限 10、butt cap）再走同一条
//   填充管线；设备线宽 = 用户线宽 × sqrt(|det|)（非均匀缩放的笔帽按近似处理，
//   容差带内，记档）。

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
  let cross_x : Array[Double] = []
  let cross_w : Array[Int] = []
  for y = y0; y < y1; y = y + 1 {
    for i = x0; i < x1; i = i + 1 {
      cov[i] = 0
    }
    for sub = 0; sub < 4; sub = sub + 1 {
      let ys = y.to_double() + (sub.to_double() + 0.5) / 4.0
      cross_x.clear()
      cross_w.clear()
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
          if (ay <= ys) != (by2 <= ys) {
            let t = (ys - ay) / (by2 - ay)
            cross_x.push(ax + (bx2 - ax) * t)
            cross_w.push(if by2 > ay { 1 } else { -1 })
          }
        }
      }
      let nc = cross_x.length()
      if nc == 0 {
        continue
      }
      // 插入排序（跨点数小）
      for i = 1; i < nc; i = i + 1 {
        let xv = cross_x[i]
        let wv = cross_w[i]
        let mut j = i - 1
        while j >= 0 && cross_x[j] > xv {
          cross_x[j + 1] = cross_x[j]
          cross_w[j + 1] = cross_w[j]
          j = j - 1
        }
        cross_x[j + 1] = xv
        cross_w[j + 1] = wv
      }
      // 扫描：非零区间计入覆盖（wind 回零处收区间）
      let mut wind = 0
      let mut xa = 0.0
      for i = 0; i < nc; i = i + 1 {
        if wind != 0 {
          add_span_samples(cov, x0, x1, xa, cross_x[i])
        }
        wind = wind + cross_w[i]
        xa = cross_x[i]
      }
    }
    composite_span(bm.data, width, y, x0, x1, cov, op, src)
  }
}

///|
/// 区间 [xa, xb) 内的 x 样本（每像素 4 个）计入该样本行覆盖。
fn add_span_samples(
  cov : FixedArray[Int],
  cx0 : Int,
  cx1 : Int,
  xa : Double,
  xb : Double,
) -> Unit {
  let px0 = raster_max_i(xa.floor().to_int(), cx0)
  let px1 = raster_min_i(xb.ceil().to_int(), cx1)
  if px1 <= px0 {
    return
  }
  for px = px0; px < px1; px = px + 1 {
    let mut cnt = 0
    for j = 0; j < 4; j = j + 1 {
      let xs = px.to_double() + (j.to_double() + 0.5) / 4.0
      if xs >= xa && xs < xb {
        cnt = cnt + 1
      }
    }
    if cnt > 0 {
      cov[px] = cov[px] + cnt * 16
    }
  }
}

///|
/// 描边轮廓：折线 → 闭合填充多边形（两侧偏移 + miter/bevel 接头 + butt 端帽）。
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
    let edges = if poly.closed { n } else { n - 1 }
    if edges < 1 {
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
        // 解 s·d1 = n − pn + t·d2：miter 点 = P + pn + s·d1（pn 为 prev 左法线）
        let pnx = -pdy * half
        let pny = pdx * half
        let rx = nx - pnx
        let ry = ny - pny
        let s = (ux * ry - uy * rx) / det
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
