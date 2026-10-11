// 图表组件层（新栈）：五种通用图，一律返回 `@core.Node`。
//
// 数据都走 `@core.Store`：换数据只请求重绘（`follow_store` 的订阅只为重绘，
// 退订随本代回收袋），绘制在 `on_draw` 里现取现值——不重建控件树。
// 悬停高亮（柱状/环形）由组件自己记索引：宿主只给「是否悬停」，给不了「第几根」，
// 而分槽几何必须与绘制同源（都用 `bar_hit`/扇区角度那套纯函数）。

///|
/// 折线/面积图：定长滚动窗口多序列（≤4，主题色循环），y 轴自适应或经 `y_range`
/// 手动指定；横向网格 + 左侧刻度；`area=true` 半透明填充；`show_last` 右端标最新值。
pub fn line_chart_t(
  series : @core.Store[Array[LineSeries]],
  area? : Bool = false,
  y_range? : (Double, Double)? = None,
  show_last? : Bool = true,
  width? : Double = 0.0,
  height? : Double = 200.0,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(series)
  let fill = area
  let yr = y_range
  let tail = show_last
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    @ui.watch_theme()
    w.node.set_height(@yoga.fixed(height))
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    } else {
      w.node.set_width(@yoga.percent(100.0))
      w.node.set_min_width(@yoga.fixed(120.0))
    }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      draw_line_chart(p, r.w, r.h, series.get(), fill, yr, tail)
    })
    handle(w)
    w
  })
}

///|
/// 柱状/条形图：`horizontal=true` 为横向条；正负值有基线，悬停那根换浅底 +
/// 描边并在行内标数值（自绘，无弹层）。
pub fn bar_chart_t(
  data : @core.Store[Array[BarItem]],
  horizontal? : Bool = false,
  y_range? : (Double, Double)? = None,
  width? : Double = 0.0,
  height? : Double = 200.0,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(data)
  let horiz = horizontal
  let yr = y_range
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    @ui.watch_theme()
    let hover : Ref[Int] = Ref(-1)
    w.node.set_height(@yoga.fixed(height))
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    } else {
      w.node.set_width(@yoga.percent(100.0))
      w.node.set_min_width(@yoga.fixed(120.0))
    }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      draw_bar_chart(p, r.w, r.h, data.get(), horiz, hover.val, y_range=yr)
    })
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Move => {
          let h = bar_hit(horiz, data.get().length(), self.rect.w, self.rect.h, ev.x, ev.y)
          if h != hover.val {
            hover.val = h
            @core.invalidate()
          }
          true
        }
        @core.Leave => {
          if hover.val != -1 {
            hover.val = -1
            @core.invalidate()
          }
          false
        }
        _ => false
      }
    })
    handle(w)
    w
  })
}

///|
/// 环形图：占比扇区 + 中心汇总（`center` 传空用总和）+ 右侧图例；悬停扇区外扩。
pub fn donut_chart_t(
  data : @core.Store[Array[DonutSlice]],
  thickness? : Double = 26.0,
  center? : String = "",
  width? : Double = 0.0,
  height? : Double = 180.0,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(data)
  let thick = thickness
  let mid = center
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    @ui.watch_theme()
    let hover : Ref[Int] = Ref(-1)
    w.node.set_height(@yoga.fixed(height))
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    } else {
      w.node.set_width(@yoga.percent(100.0))
      w.node.set_min_width(@yoga.fixed(160.0))
    }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      draw_donut(p, r.w, r.h, data.get(), thick, mid, hover.val)
    })
    // 命中：按极坐标判扇区（12 点起顺时针），中心孔与图例区不算
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Move => {
          let h = donut_hit(self.rect.h, data.get(), ev.x, ev.y)
          if h != hover.val {
            hover.val = h
            @core.invalidate()
          }
          true
        }
        @core.Leave => {
          if hover.val != -1 {
            hover.val = -1
            @core.invalidate()
          }
          false
        }
        _ => false
      }
    })
    handle(w)
    w
  })
}

///|
/// 环形图命中：返回指针下的扇区索引（中心孔、圆外、无数据都给 -1）。
/// 几何与 `draw_donut` 同源：直径 `h-16`、圆心 `(8+d/2, h/2)`、外扩只影响绘制。
pub fn donut_hit(h : Double, data : Array[DonutSlice], px : Double, py : Double) -> Int {
  let n = data.length()
  if n == 0 {
    return -1
  }
  let d = h - 16.0
  let cx = 8.0 + d / 2.0
  let cy = h / 2.0
  let r_out = d / 2.0
  let dx = px - cx
  let dy = py - cy
  let rad = (dx * dx + dy * dy).sqrt()
  if rad > r_out + 4.0 || rad < (r_out - 26.0).max(1.0) {
    return -1
  }
  let mut ang = @math.atan2(dy, dx) + pi / 2.0
  if ang < 0.0 {
    ang = ang + tau
  }
  let values : Array[Double] = []
  for s in data {
    values.push(s.value)
  }
  for i in 0..<n {
    match sector_angles(values, i) {
      None => ()
      Some((a0, a1)) => {
        let lo0 = a0 + pi / 2.0
        let hi0 = a1 + pi / 2.0
        if ang >= lo0 && ang <= hi0 {
          return i
        }
      }
    }
  }
  -1
}

///|
/// 仪表盘：单值百分比环 + 中心大数字 + 阈值分段着色。值一变就用定时器插值平滑
/// （非动画帧驱动），`smooth=false` 时直接跳到位。
pub fn gauge_t(
  value : @core.Store[Double],
  thresholds? : Array[(Double, String)] = [],
  width? : Double = 220.0,
  height? : Double = 180.0,
  smooth? : Bool = true,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(value)
  let bands = thresholds
  let do_smooth = smooth
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    @ui.watch_theme()
    let disp : Ref[Double] = Ref(value.get().clamp(min=0.0, max=1.0))
    let timer : Ref[Int] = Ref(0)
    let step : Ref[() -> Unit] = Ref(fn() { () })
    step.val = fn() -> Unit {
      timer.val = 0
      let target = value.get().clamp(min=0.0, max=1.0)
      let diff = target - disp.val
      if diff.abs() < 0.002 {
        disp.val = target
      } else {
        disp.val = disp.val + diff * 0.25
        timer.val = @core.set_timeout(30, fn() { (step.val)() })
      }
      @core.invalidate()
    }
    w.node.set_width(@yoga.fixed(width))
    w.node.set_height(@yoga.fixed(height))
    w.node.set_flex_shrink(0.0)
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      draw_gauge(p, r.w, r.h, disp.val, bands)
    })
    let sid = value.subscribe_id(fn(v : Double) -> Unit {
      let target = v.clamp(min=0.0, max=1.0)
      if !do_smooth {
        disp.val = target
      } else if timer.val == 0 {
        (step.val)()
      }
      @core.invalidate()
    })
    @core.sub_bag_register(fn() { value.remove(sid) })
    handle(w)
    w
  })
}

///|
/// 散点图：x/y 点列 + 可选最小二乘趋势线；绘制区裁剪，点用方块（不依赖字形）。
pub fn scatter_t(
  points : @core.Store[Array[(Double, Double)]],
  trend? : Bool = false,
  dot? : Double = 6.0,
  width? : Double = 0.0,
  height? : Double = 200.0,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(points)
  let line = trend
  let d = dot
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    @ui.watch_theme()
    w.node.set_height(@yoga.fixed(height))
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    } else {
      w.node.set_width(@yoga.percent(100.0))
      w.node.set_min_width(@yoga.fixed(160.0))
    }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      draw_scatter(p, r.w, r.h, points.get(), line, d)
    })
    handle(w)
    w
  })
}
