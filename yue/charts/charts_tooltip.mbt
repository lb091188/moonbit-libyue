// 图表交互层:hover 跟随浮层(Tooltip)与命中测试(EP Chart 对标)。
// 与其余图表同一渲染模型——单一自绘容器,on_draw 内现取 theme_* 色;
// 差别在交互面:
//   浮层不另起窗口,而画在图表容器自身 on_draw 内(图表之后绘制即在
//   最上层,无 z-order 问题),位置经 ci_tooltip_pos 钳制在画布内不
//   出界,锚点贴边时翻到对侧。事件面即容器自身。
// 命中(最近点/扇区)是与绘制共用几何的纯函数,charts_tooltip_wbtest.mbt
// 白盒覆盖。ci_zoom 的窗口数学在 charts_interactive.mbt,本文件的
// ci_tooltip 负责把 zoom 状态绑到滚轮/拖拽事件。

///|
/// 浮层底色(EP 语义,恒深底浅字不随主题:浮层像原生 tooltip 一样在
/// 深浅主题下都可读,与 apply_native_theme_css 的 tooltip 配色一致)。
let ci_tip_bg : String = "#303133"

///|
/// 浮层边框色。
let ci_tip_border : String = "#4C4D4F"

///|
/// 浮层文字色。
let ci_tip_fg : String = "#FFFFFF"

///|
/// 浮层行高(px)。
let ci_tip_line_h : Double = 18.0

///|
/// 浮层状态:锚点(画布坐标)+ 标题 + 多行内容。经 ci_tip_show /
/// ci_tip_hide 变更,on_draw 内由 ci_tip_draw 落位绘制。
pub(all) struct CiTip {
  mut visible : Bool
  mut x : Double
  mut y : Double
  mut title : String
  /// (色标色, 行文本);色标空串不画色标,文本不缩进
  mut rows : Array[(String, String)]
}

///|
/// 建隐藏态浮层。
pub fn CiTip::new() -> CiTip {
  { visible: false, x: 0.0, y: 0.0, title: "", rows: [], }
}

///|
/// 显示/更新浮层:锚点 (px,py) 为画布坐标(跟随鼠标),title 为标题行
/// (空串不画),rows 为多行内容(色标 + 文本)。
pub fn ci_tip_show(
  tip : CiTip,
  title : String,
  rows : Array[(String, String)],
  px : Double,
  py : Double,
) -> Unit {
  tip.visible = true
  tip.x = px
  tip.y = py
  tip.title = title
  tip.rows = rows
}

///|
/// 隐藏浮层。
pub fn ci_tip_hide(tip : CiTip) -> Unit {
  tip.visible = false
}

///|
/// 浮层内容尺寸估算:标题行 + 内容行,四边 8px 内边距;字符宽按 7px
/// 估算(与 truncate_to 同基准),行高 18。空内容给最小盒。
pub fn ci_tip_size(
  title : String,
  rows : Array[(String, String)],
) -> (Double, Double) {
  let mut w = title.length().to_double() * ci_char_w()
  for r in rows {
    let rw = 14.0 + r.1.length().to_double() * ci_char_w()
    if rw > w {
      w = rw
    }
  }
  let lines = rows.length() + (if title != "" { 1 } else { 0 })
  let n = if lines < 1 { 1 } else { lines }
  (w + 16.0, n.to_double() * ci_tip_line_h + 16.0)
}

///|
/// 浮层定位(防出界):锚点 (px,py) 右上方 offset 处落盒,右溢时翻到锚点
/// 左侧,再钳进画布 margin 内(上下以锚点垂直居中再钳);画布比盒还小时
/// 贴 margin。返回盒左上角坐标。
pub fn ci_tooltip_pos(
  px : Double,
  py : Double,
  canvas_w : Double,
  canvas_h : Double,
  tip_w : Double,
  tip_h : Double,
  offset? : Double = 14.0,
  margin? : Double = 6.0,
) -> (Double, Double) {
  let mut x = px + offset
  if x + tip_w > canvas_w - margin {
    x = px - offset - tip_w
  }
  let max_x = (canvas_w - margin - tip_w).max(margin)
  if x > max_x {
    x = max_x
  }
  if x < margin {
    x = margin
  }
  let mut y = py - tip_h / 2.0
  let max_y = (canvas_h - margin - tip_h).max(margin)
  if y > max_y {
    y = max_y
  }
  if y < margin {
    y = margin
  }
  (x, y)
}

///|
/// 浮层绘制:在图表容器 on_draw 内、图表内容之后调用(即盖在图表上)。
/// 底色 + 1px 边框 + 标题 + 多行(8×8 色标 + 文本),位置由
/// ci_tooltip_pos 钳制;不可见时无绘制开销。
pub fn ci_tip_draw(p : @yue.Painter, tip : CiTip, w : Double, h : Double) -> Unit {
  if !tip.visible {
    return
  }
  let (tw, th) = ci_tip_size(tip.title, tip.rows)
  let (x, y) = ci_tooltip_pos(tip.x, tip.y, w, h, tw, th)
  p.set_fill_color(ci_tip_bg)
  p.fill_rect(x, y, tw, th)
  p.set_stroke_color(ci_tip_border)
  p.stroke_rect(x + 0.5, y + 0.5, tw - 1.0, th - 1.0)
  let mut ly = y + 8.0
  if tip.title != "" {
    p.draw_text(
      tip.title,
      x + 8.0,
      ly,
      tw - 16.0,
      ci_tip_line_h,
      align=@yue.Start,
      valign=@yue.Center,
      color=ci_tip_fg,
      wrap=false,
    )
    ly = ly + ci_tip_line_h
  }
  for r in tip.rows {
    let tx = if r.0 != "" {
      p.set_fill_color(r.0)
      p.fill_rect(x + 8.0, ly + (ci_tip_line_h - 8.0) / 2.0, 8.0, 8.0)
      x + 22.0
    } else {
      x + 8.0
    }
    p.draw_text(
      r.1,
      tx,
      ly,
      tw - (tx - x) - 8.0,
      ci_tip_line_h,
      align=@yue.Start,
      valign=@yue.Center,
      color=ci_tip_fg,
      wrap=false,
    )
    ly = ly + ci_tip_line_h
  }
}

///|
/// 绘制区矩形(缩放锚点/平移量的换算基准,与绘制几何同源)。
pub(all) struct CiPlot {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
/// 建绘制区矩形。
pub fn CiPlot::make(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> CiPlot {
  { x0, y0, x1, y1, }
}

///|
/// 绘制区宽(退化时 1,避免除零)。
pub fn CiPlot::width(self : CiPlot) -> Double {
  let w = self.x1 - self.x0
  if w > 0.0 {
    w
  } else {
    1.0
  }
}

///|
/// 像素 x → 绘制区内分数 0..1(界外钳制;退化宽取 0.5)。
pub fn CiPlot::frac(self : CiPlot, px : Double) -> Double {
  let w = self.x1 - self.x0
  if !(w > 0.0) {
    return 0.5
  }
  let f = (px - self.x0) / w
  if f < 0.0 {
    0.0
  } else if f > 1.0 {
    1.0
  } else {
    f
  }
}

///|
/// 点是否在绘制区内(含边界)。
pub fn CiPlot::contains(self : CiPlot, px : Double, py : Double) -> Bool {
  px >= self.x0 && px <= self.x1 && py >= self.y0 && py <= self.y1
}

///|
/// 最近点命中:n 个点(序号 0..n-1)均布 [x0, x1] 时鼠标 px 的最近
/// 序号;绘制区外 -1(单点在区内为 0)。与 map_idx 同一套均布几何,
/// 命中与折线互为逆运算。
pub fn ci_nearest_idx(px : Double, n : Int, x0 : Double, x1 : Double) -> Int {
  if n <= 0 || !(x1 > x0) {
    return -1
  }
  if px < x0 || px > x1 {
    return -1
  }
  if n == 1 {
    return 0
  }
  let f = (px - x0) / (x1 - x0)
  let idx = (f * (n - 1).to_double()).round().to_int()
  if idx < 0 {
    0
  } else if idx >= n {
    n - 1
  } else {
    idx
  }
}

///|
/// 扇区命中:点 (px,py) 落在第几个扇区环带内(12 点方向起顺时针,
/// 与 sector_angles 同一构造;环带取 [r_in-4, r_out+4],容差 4 与
/// donut hover 外扩一致)。环带外 / 无正值扇区返回 -1;values 只按
/// 正值计占比,负值扇区零张角不可命中。
pub fn ci_sector_at(
  px : Double,
  py : Double,
  cx : Double,
  cy : Double,
  r_in : Double,
  r_out : Double,
  values : Array[Double],
) -> Int {
  let dx = px - cx
  let dy = py - cy
  let r = (dx * dx + dy * dy).sqrt()
  if r < r_in - 4.0 || r > r_out + 4.0 {
    return -1
  }
  let mut total = 0.0
  for v in values {
    if v > 0.0 {
      total = total + v
    }
  }
  if !(total > 0.0) {
    return -1
  }
  // 角度归一:atan2 ∈ (-pi, pi],+pi/2 后自 12 点方向起顺时针,再归到 [0, tau)
  let mut a = @math.atan2(dy, dx) + pi / 2.0
  while a < 0.0 {
    a = a + tau
  }
  while a >= tau {
    a = a - tau
  }
  let frac = a / tau
  let mut acc = 0.0
  for i in 0..<values.length() {
    let v = values[i]
    if v <= 0.0 {
      continue
    }
    acc = acc + v
    if frac < acc / total {
      return i
    }
  }
  -1
}

///|
/// 交互画布(图表交互层地基):自绘容器 = 图表绘制(draw)+ hover 浮层
/// (hit)+ 可选 DataZoom 绑定(zoom 非 None 时滚轮以鼠标为锚点缩放,
/// pan=true 时左键拖拽平移)。draw/hit/plot 三个回调把几何知识留在
/// 调用方(绘制与命中同源),本组件只管事件接线与浮层落位。
///   draw : (Painter, 宽, 高) -> Unit   图表内容(不含边框与浮层)
///   hit  : (x, y, 宽, 高) -> Option    命中 → Some((标题, 行));None 隐藏
///   plot : (宽, 高) -> CiPlot          绘制区矩形(缩放换算基准)
///   zoom : 非 None 时绑定的 DataZoom 状态(调用方持有,可读写)
///   zoom_map : (x, y, 宽, 高) -> 百分比  鼠标 → zoom 锚点映射(默认沿
///             x 轴取 plot 分数;横向条等类目轴在 y 的场景覆盖之)
pub fn ci_tooltip(
  draw : (@yue.Painter, Double, Double) -> Unit,
  hit : (Double, Double, Double, Double) -> (String, Array[(String, String)])?,
  plot? : (Double, Double) -> CiPlot = fn(_w, _h) {
    CiPlot::make(0.0, 0.0, 1.0, 1.0)
  },
  zoom? : CiZoom? = None,
  pan? : Bool = false,
  zoom_map? : ((Double, Double, Double, Double) -> Double)? = None,
  style? : Array[(String, &@yue.StyVal)] = [("width", 560.0), ("height", 280.0)],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let cv = @yue.themed_container(style~)
      handle(cv)
      @yue.set_panel_bg(cv)
      let tip = CiTip::new()
      // 滚轮回调不带坐标,锚点取最近一次鼠标位置(画布坐标)
      let cur_xy = Ref((0.0, 0.0))
      let dragging = Ref(false)
      let drag_a0 = Ref(0.0)
      let drag_s0 = Ref(0.0)
      // 仅在浮层显隐变化 / 跟随移动 / 拖拽缩放时重绘,静态移动不刷
      let was_vis = Ref(false)
      // 鼠标 → DataZoom 锚点百分比:默认沿 x 轴(plot 分数),横向条等
      // 类目轴在 y 的场景由 zoom_map 覆盖
      fn zmap(mx : Double, my : Double, w : Double, h : Double) -> Double {
        match zoom_map {
          Some(f) => f(mx, my, w, h)
          None => plot(w, h).frac(mx) * 100.0
        }
      }

      cv.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(cv)
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        draw(p, b.width, b.height)
        ci_tip_draw(p, tip, b.width, b.height)
      })
      @yue.ViewLike::on_mouse_move(cv, fn(e) {
        cur_xy.val = (e.view_x, e.view_y)
        let b = @yue.ViewLike::get_bounds(cv)
        match hit(e.view_x, e.view_y, b.width, b.height) {
          Some((title, rows)) =>
            ci_tip_show(tip, title, rows, e.view_x, e.view_y)
          None => ci_tip_hide(tip)
        }
        let mut need = tip.visible || tip.visible != was_vis.val
        match zoom {
          None => ()
          Some(z) =>
            if dragging.val {
              let d = zmap(e.view_x, e.view_y, b.width, b.height) - drag_a0.val
              ci_zoom_set(z, drag_s0.val + d, drag_s0.val + d + ci_zoom_span(z))
              need = true
            }
        }
        was_vis.val = tip.visible
        if need {
          @yue.ViewLike::schedule_paint(cv)
        }
      })
      @yue.ViewLike::on_mouse_leave(cv, fn(_e) {
        if was_vis.val {
          ci_tip_hide(tip)
          was_vis.val = false
          @yue.ViewLike::schedule_paint(cv)
        }
      })
      match zoom {
        None => ()
        Some(z) => {
          @yue.ViewLike::on_wheel(cv, fn(delta) {
            let b = @yue.ViewLike::get_bounds(cv)
            let (mx, my) = cur_xy.val
            // delta: +1 下滚(缩小)/ -1 上滚(放大);锚点 = 鼠标在类目轴的映射
            ci_zoom_wheel(z, zmap(mx, my, b.width, b.height), delta)
            @yue.ViewLike::schedule_paint(cv)
          })
          if pan {
            @yue.ViewLike::on_mouse_down(cv, fn(e) {
              if e.button != 1 {
                return false
              }
              let b = @yue.ViewLike::get_bounds(cv)
              dragging.val = true
              // 按下处的锚点百分比作基准,移动量为两次映射之差
              drag_a0.val = zmap(e.view_x, e.view_y, b.width, b.height)
              drag_s0.val = z.start
              @yue.ViewLike::set_capture(cv)
              true
            })
            @yue.ViewLike::on_mouse_up(cv, fn(_e) {
              if dragging.val {
                dragging.val = false
                @yue.ViewLike::release_capture(cv)
                true
              } else {
                false
              }
            })
          }
        }
      }
      @yue.attach(parent, @yue.ViewLike::view(cv))
      @yue.ViewLike::view(cv)
    },
  }
}
