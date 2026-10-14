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
  let y1 = raster_min_i((by1 + 1.0).ceil().to_int(), cx1)
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let width = bm.width
  let cov : FixedArray[Int] = FixedArray::make(width, 0)
  // ---- 增量活动边表（AET，pixman 同构）----
  // GET（全局边表）按 y_lo 排序一次；扫描线推进时每子采样只做「失活压缩 /
  // 新边激活 / x 全精度重算 + 近有序插入排序」，不再每子采样全边重扫（旧实
  // 现 O(行×4×全边) 的遍历 + O(n²) 插入排序都在这里）。边激活区间 [y_lo,
  // y_hi) 与旧跨点判定 (ay<=ys)!=(by<=ys) 逐位等价；水平边不跨样本行，建表
  // 即排除。gx_t/gs/gx1/gy1 保存**原始遍历方向**的端点 (ax, ay, bx2, by2)：
  // 激活/重算的 x 必须与旧跨点公式 ax + (bx-ax)×t 逐位一致（同一数学值的
  // 不同表达式会有末位差，边界像素覆盖量化翻转，像素断言实测抓红）。
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
  // AET 并行数组：边号 + 当前子采样行的 x
  let aet_e : FixedArray[Int] = FixedArray::make(total_edges + 1, 0)
  let aet_x : FixedArray[Double] = FixedArray::make(total_edges + 1, 0.0)
  let mut aet_len = 0
  let mut gp = 0 // GET 激活指针（y_lo 单调递增，只前进）
  for y = y0; y < y1; y = y + 1 {
    for i = x0; i < x1; i = i + 1 {
      cov[i] = 0
    }
    let mut ink_l = x1
    let mut ink_r = x0
    for sub = 0; sub < 4; sub = sub + 1 {
      let ys = y.to_double() + (sub.to_double() + 0.5) / 4.0
      // 老边重算 x：与旧跨点公式同式（x = ax + (bx-ax)×t）——不用增量步进，
      // 步进的浮点漂移会让边界像素覆盖量化翻转（像素断言实测抓红）；AET 的
      // 收益在「边不逐子采样全重扫」。
      for i = 0; i < aet_len; i = i + 1 {
        let e = aet_e[i]
        let t = (ys - gs[e]) / (gy1[e] - gs[e])
        aet_x[i] = gx_t[e] + (gx1[e] - gx_t[e]) * t
      }
      // 失活压缩：y_hi <= ys 的边出表
      let mut w2 = 0
      for i = 0; i < aet_len; i = i + 1 {
        let e = aet_e[i]
        if gy_b[e] > ys {
          aet_e[w2] = e
          aet_x[w2] = aet_x[i]
          w2 += 1
        }
      }
      aet_len = w2
      // 激活：y_lo <= ys 且 y_hi > ys（GET 按 y_lo 排序后的 gidx 走指针）
      while gp < ge {
        let e = gidx[gp]
        if gy_t[e] > ys {
          break
        }
        if gy_b[e] > ys {
          aet_e[aet_len] = e
          let t = (ys - gs[e]) / (gy1[e] - gs[e])
          aet_x[aet_len] = gx_t[e] + (gx1[e] - gx_t[e]) * t
          aet_len += 1
        }
        gp += 1
      }
      // 按 x 插入排序（AET 近有序，几乎线性；新激活边只在行首少量进入）
      for i = 1; i < aet_len; i = i + 1 {
        let xv = aet_x[i]
        let ei = aet_e[i]
        let mut j = i - 1
        while j >= 0 && aet_x[j] > xv {
          aet_x[j + 1] = aet_x[j]
          aet_e[j + 1] = aet_e[j]
          j -= 1
        }
        aet_x[j + 1] = xv
        aet_e[j + 1] = ei
      }
      // 环绕扫 span（非零环绕；口径与旧实现逐位一致）：满覆盖内段直取 256，
      // 跨度两端的边界像素按采样计，墨迹范围记录下来只合成有墨区间
      let mut wind = 0
      let mut xa = 0.0
      for i2 = 0; i2 < aet_len; i2 = i2 + 1 {
        let xb = aet_x[i2]
        if wind != 0 && xb > xa {
          let s0 = (xa - 0.125).ceil().to_int()
          let s1 = (xb - 0.875).ceil().to_int() - 1
          let mut t0 = -1
          let mut t1 = -1
          if s0 > s1 {
            // 跨度不足一像素：可能仍骑在两个像素上（如 [10.6, 11.4)），
            // 覆盖范围 = [floor(xa), ceil(xb))，逐像素按采样计
            let p0 = raster_max_i(xa.floor().to_int(), x0)
            let p1 = raster_min_i(xb.ceil().to_int(), x1)
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
            // 右边界像素 s1+1 的合成上界是**开区间** s1+2
            if s1 + 1 < x1 && s1 + 1 > a1 - 1 {
              t1 = s1 + 2
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
        wind = wind + gw[aet_e[i2]]
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
