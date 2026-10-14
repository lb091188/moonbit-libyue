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
  // 跨点暂存（跨行/跨子采样复用，**零分配**）：x / 环绕方向 / 该边 x 随 y 斜率
  // 三个刮擦数组 + 索引数组（Int 不装箱）。排序用 sort_by（O(n log n)）：描边
  // 轮廓的跨点数 = 2×边数，旧插入排序 O(n²) 在 160+ 跨点 × 4 子采样 × 每行
  // 重排下是折线/图表描边的主要开销；三元组直 push 会每跨点装箱一次（实测
  // 5.7 万次分配/帧），刮擦数组 + 索引排序把分配降为零。
  let mut total_edges = 0
  for poly in polys {
    let n = poly.pts.length()
    if n >= 2 {
      total_edges += n
    }
  }
  let sx : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let sw : FixedArray[Int] = FixedArray::make(total_edges + 1, 0)
  let sl : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let idx : Array[Int] = []
  for y = y0; y < y1; y = y + 1 {
    for i = x0; i < x1; i = i + 1 {
      cov[i] = 0
    }
    let mut ink_l = x1
    let mut ink_r = x0
    for sub = 0; sub < 4; sub = sub + 1 {
      let ys = y.to_double() + (sub.to_double() + 0.5) / 4.0
      idx.clear()
      let mut nc = 0
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
            sx[nc] = ax + (bx2 - ax) * t
            sw[nc] = if by2 > ay { 1 } else { -1 }
            sl[nc] = (bx2 - ax) / (by2 - ay)
            nc += 1
          }
        }
      }
      for i = 0; i < nc; i = i + 1 {
        let _ = idx.push(i)
      }
      if nc == 0 {
        continue
      }
      idx.sort_by(fn(a, b) { sx[a].compare(sx[b]) })
      // 扫描：非零区间计入覆盖（wind 回零处收区间）。
      // pixman 同款口径：跨点区间内「四样本全入」的整段像素直取 256（免逐
      // 样本判断），只有跨度两端的至多一个边界像素做采样；墨迹范围记录下来，
      // 合成只扫有墨区间（bbox 宽度里通常九成是空的）。
      let mut wind = 0
      let mut xa = 0.0
      for i2 = 0; i2 < nc; i2 = i2 + 1 {
        let ci = idx[i2]
        let xb = sx[ci]
        if wind != 0 && xb > xa {
          // 满覆盖内段：四样本全入的像素 [ceil(xa-0.125), ceil(xb-0.875))
          let s0 = (xa - 0.125).ceil().to_int()
          let s1 = (xb - 0.875).ceil().to_int() - 1
          let mut t0 = -1
          let mut t1 = -1
          if s0 > s1 {
            // 跨度不足一像素：单像素按采样计
            let p0 = raster_max_i(xa.floor().to_int(), x0)
            let p1 = raster_min_i(xa.floor().to_int() + 1, x1)
            for px = p0; px < p1; px = px + 1 {
              add_pixel_samples(cov, x0, x1, px, xa, xb)
            }
            if p1 > p0 {
              t0 = p0
              t1 = p1
            }
          } else {
            let a0 = raster_max_i(s0, x0)
            let a1 = raster_min_i(s1 + 1, x1)
            for px = a0; px < a1; px = px + 1 {
              cov[px] = 256
            }
            // 两端边界像素（各至多一个采样不满的像素）
            add_pixel_samples(cov, x0, x1, s0 - 1, xa, xb)
            add_pixel_samples(cov, x0, x1, s1 + 1, xa, xb)
            if s0 - 1 >= x0 && s0 - 1 < a0 {
              t0 = s0 - 1
            }
            if s1 + 1 < x1 && s1 + 1 > a1 - 1 {
              t1 = s1 + 1
            }
            if t0 < 0 {
              t0 = a0
            }
            if t1 < 0 {
              t1 = a1
            }
            if a1 > t1 {
              t1 = a1
            }
          }
          if t1 > t0 {
            if t0 < ink_l {
              ink_l = t0
            }
            if t1 > ink_r {
              ink_r = t1
            }
          }
        }
        wind = wind + sw[ci]
        xa = xb
      }
    }
    if ink_r > ink_l {
      composite_span(bm.data, width, y, ink_l, ink_r, cov, op, src)
    }
  }
}

///|
/// 单像素的 4 个 x 样本落入 [xa, xb) 的个数 ×16 计入覆盖（封顶 256）。
/// 越界像素与零样本不计。
fn add_pixel_samples(
  cov : FixedArray[Int],
  cx0 : Int,
  cx1 : Int,
  px : Int,
  xa : Double,
  xb : Double,
) -> Unit {
  if px < cx0 || px >= cx1 {
    return
  }
  let mut cnt = 0
  for j = 0; j < 4; j = j + 1 {
    let xs = px.to_double() + (j.to_double() + 0.5) / 4.0
    if xs >= xa && xs < xb {
      cnt = cnt + 1
    }
  }
  if cnt <= 0 {
    return
  }
  let nv = cov[px] + cnt * 16
  cov[px] = if nv > 256 { 256 } else { nv }
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
