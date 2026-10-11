// 图表交互变体（新栈，与 master 同源平移）：line_chart_it / bar_chart_it /
// donut_chart_it —— 三种通用图的交互版，数据类型复用原图表（LineSeries /
// BarItem / DonutSlice），组合方式不改 components.mbt 的静态版：
//   - 内置 hover 浮层：最近数据点/扇区显值 + 系列名（tooltip.mbt 的
//     ci_tooltip + 命中纯函数）
//   - 可点击图例：显隐系列/类目并重绘（interactive.mbt 的 ci_legend，
//     色经 color_at 现取，主题切换免重建）
//   - line/bar 支持 DataZoom：滚轮以鼠标为锚点缩放 + 左键拖拽平移
//     （interactive.mbt 的 ci_zoom；横向条的窗沿 y 轴，经 ci_tooltip 的
//     zoom_map 换算）
// 布局 = vbox（图例行 + 交互画布）；数据经 Store 驱动，显隐/缩放只
// 请求重绘，不重建控件树。纯函数（绘制区边距/环形几何/图例项/窗口定标）
// 在文件头部，charts_it_wbtest.mbt 白盒覆盖。

///|
/// line 绘制区（与 draw.mbt draw_line_chart 的边距同源：命中与缩放
/// 锚点必须和折线几何一致；若 draw_line_chart 改边距，此处须同步）。
fn ci_line_plot(show_last : Bool) -> (Double, Double) -> CiPlot {
  let pad_r = if show_last { 56.0 } else { 12.0 }
  fn(w, h) { CiPlot::make(46.0, 12.0, w - pad_r, h - 18.0) }
}

///|
/// bar 绘制区（与 draw.mbt draw_bar_chart 两形态的边距同源，同步义务
/// 同上）。
fn ci_bar_plot(horizontal : Bool) -> (Double, Double) -> CiPlot {
  if horizontal {
    fn(w, h) { CiPlot::make(84.0, 12.0, w - 20.0, h - 24.0) }
  } else {
    fn(w, h) { CiPlot::make(46.0, 14.0, w - 12.0, h - 24.0) }
  }
}

///|
/// 环形几何（与 draw_donut_core 同源）：(cx, cy, r_in, r_out)。
fn ci_donut_geom(
  h : Double,
  thickness : Double,
) -> (Double, Double, Double, Double) {
  let d = h - 16.0
  let cx = 8.0 + d / 2.0
  let cy = h / 2.0
  let r_out = d / 2.0
  let r_in = (r_out - thickness).max(1.0)
  (cx, cy, r_in, r_out)
}

///|
/// line 图例项：（名称, 原始序号）——色由 ci_legend 的 color_at 按原始
/// 序号现取，显隐切换不串色。
fn ci_line_items(all : Array[LineSeries]) -> Array[(String, Int)] {
  let out : Array[(String, Int)] = []
  for si, s in all {
    out.push((s.name, si))
  }
  out
}

///|
/// bar 图例项：（类目, 原始序号）——色按值正负现取（正数主色/负数
/// danger，与 draw_bar_chart 同色）。
fn ci_bar_items(all : Array[BarItem]) -> Array[(String, Int)] {
  let out : Array[(String, Int)] = []
  for i, it in all {
    out.push((it.label, i))
  }
  out
}

///|
/// donut 图例项：（标签, 原始序号）——色按原始序号现取，显隐切换不串色。
fn ci_donut_items(all : Array[DonutSlice]) -> Array[(String, Int)] {
  let out : Array[(String, Int)] = []
  for i, s in all {
    out.push((s.label, i))
  }
  out
}

///|
/// 序列窗口长度（各序列最长点数）：zoom 窗的定标基准，隐藏序列不改变
/// 时间轴窗口。
fn ci_win_len(all : Array[LineSeries]) -> Int {
  let mut m = 0
  for s in all {
    if s.points.length() > m {
      m = s.points.length()
    }
  }
  m
}

///|
/// 折线/面积交互图（交互版 line_chart_t）：数据/参数语义同原图（area 面积、
/// y_range 手动值域、show_last 末端标注）；新增：
///   - hover 最近点：浮层标题「第 N 点」+ 各可见序列在该点的值，并画
///     竖直准线 + 各序列落点（4×4 色点）
///   - 图例点击显隐序列（不重算窗口长度，色彩按原始序号）
///   - zoom=true 时滚轮以鼠标为锚点缩放、左键拖拽平移（窗按最长序列
///     定标，短序列按同窗截取；y 轴随可见窗自适应，同 auto_y_range）
/// zoom_state 传调用方自建的 CiZoom 可拿到窗口句柄（外部复位/读数），
/// 缺省组件自建。
/// 布局 = vbox（图例 + 画布），总高比画布参数多图例行（24 + 6）。
pub fn line_chart_it(
  series : @core.Store[Array[LineSeries]],
  area? : Bool = false,
  y_range? : (Double, Double)? = None,
  show_last? : Bool = true,
  zoom? : Bool = true,
  zoom_state? : CiZoom? = None,
  width? : Double = 0.0,
  height? : Double = 260.0,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(series)
  let fill = area
  let yr = y_range
  let tail = show_last
  let do_zoom = zoom
  let zoom_z = match zoom_state {
    Some(z) => z
    None => ci_zoom_make()
  }
  let hover = Ref(-1)
  let visible = @core.Store::new(ci_fit_len([], series.get().length()))
  let items = @core.Store::new(ci_line_items(series.get()))
  // 数据整体更换：同步图例项与显隐位（items/visible 各自的订阅触发图例
  // 重绘，invalidate 兜画布）；退订随本代回收袋
  let sid = series.subscribe_id(fn(_s : Array[LineSeries]) -> Unit {
    items.set(ci_line_items(series.get()))
    visible.update(fn(vs) { ci_fit_len(vs, series.get().length()) })
    @core.invalidate()
  })
  @core.sub_bag_register(fn() { series.remove(sid) })

  fn draw(p : @render.Painter, w : Double, h : Double) -> Unit {
    let all = series.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let (vis_s, vis_idx) = ci_filter_visible(all, flags)
    let n_win = ci_win_len(all)
    let (i0, i1) = if do_zoom && n_win > 0 {
      ci_zoom_visible(zoom_z, n_win)
    } else {
      (0, n_win - 1)
    }
    let sliced = vis_s.map(fn(s) {
      {
        name: s.name,
        max_points: s.max_points,
        points: ci_slice_range(s.points, i0, i1),
      }
    })
    draw_line_chart(p, w, h, sliced, fill, yr, tail)
    // hover 竖直准线 + 各序列落点（x 各自按本序列切片均布，与折线同源）
    let g = hover.val
    if g >= i0 && g <= i1 && sliced.length() > 0 {
      let pl = ci_line_plot(tail)(w, h)
      let mut n_ref = 0
      for s in sliced {
        if s.points.length() > n_ref {
          n_ref = s.points.length()
        }
      }
      let loc = g - i0
      if loc >= 0 && loc < n_ref && n_ref > 0 {
        let x = map_idx(loc, n_ref, pl.x0, pl.x1)
        p.set_stroke_color(@theme.theme_border())
        p.begin_path()
        p.move_to(x, pl.y0)
        p.line_to(x, pl.y1)
        p.stroke()
        // y 值域与 draw_line_chart 同源（给定 manual range 优先，否则自适应切片）
        let (lo, hi) = match yr {
          Some((a, b)) => if a <= b { (a, b) } else { (b, a) }
          None => auto_y_range(sliced)
        }
        for k in 0..<sliced.length() {
          let s = sliced[k]
          if loc < s.points.length() {
            let xs = map_idx(loc, s.points.length(), pl.x0, pl.x1)
            let y = map_y(s.points[loc], lo, hi, pl.y0, pl.y1)
            p.set_fill_color(series_color(vis_idx[k]))
            p.fill_rect(xs - 2.0, y - 2.0, 4.0, 4.0)
          }
        }
      }
    }
  }

  fn hit(
    px : Double,
    py : Double,
    w : Double,
    h : Double,
  ) -> (String, Array[(String, String)])? {
    let all = series.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let (vis_s, vis_idx) = ci_filter_visible(all, flags)
    if vis_s.length() == 0 {
      hover.val = -1
      return None
    }
    let pl = ci_line_plot(tail)(w, h)
    if !pl.contains(px, py) {
      hover.val = -1
      return None
    }
    let n_win = ci_win_len(all)
    let (i0, i1) = if do_zoom && n_win > 0 {
      ci_zoom_visible(zoom_z, n_win)
    } else {
      (0, n_win - 1)
    }
    // 命中定标：最长可见序列的切片（等长窗口场景即各序列同一点）
    let mut n_ref = 0
    for s in vis_s {
      if s.points.length() > n_ref {
        n_ref = s.points.length()
      }
    }
    if n_ref <= 0 {
      hover.val = -1
      return None
    }
    let r1 = if i1 < n_ref - 1 { i1 } else { n_ref - 1 }
    if r1 < i0 {
      hover.val = -1
      return None
    }
    let loc = ci_nearest_idx(px, r1 - i0 + 1, pl.x0, pl.x1)
    if loc < 0 {
      hover.val = -1
      return None
    }
    let gidx = i0 + loc
    let rows : Array[(String, String)] = []
    let mut any = false
    for k in 0..<vis_s.length() {
      let s = vis_s[k]
      if gidx < s.points.length() {
        rows.push(
          (series_color(vis_idx[k]), "\{s.name}  \{fmt_axis(s.points[gidx])}"),
        )
        any = true
      }
    }
    if !any {
      hover.val = -1
      return None
    }
    hover.val = gidx
    Some(("第 \{gidx + 1} 点", rows))
  }

  @ui.vbox(
    [
      ci_legend(
        items~,
        color_at=fn(i) { series_color(i) },
        visible~,
        on_toggle=fn(_i) { @core.invalidate() },
      ),
      ci_tooltip(
        draw,
        hit,
        plot=ci_line_plot(tail),
        zoom=if do_zoom { Some(zoom_z) } else { None },
        pan=do_zoom,
        on_leave=fn() { hover.val = -1 },
        width~,
        height~,
      ),
    ],
    row_gap=6.0,
    width=if width > 0.0 { width } else { 0.0 },
    handle~,
  )
}

///|
/// 柱状/条形交互图（交互版 bar_chart_t）：数据/参数语义同原图（horizontal
/// 横向条、y_range 手动值域）；新增：
///   - hover 类目：浮层显类目标签 + 值（命中复用公共 bar_hit，与绘制
///     同源；柱体高亮由 draw_bar_chart 的 hover 参数承担）
///   - 图例点击显隐类目（色按正负现取，同原图）
///   - zoom=true 时滚轮缩放 + 左键拖拽平移（窗按类目索引定标；横向条
///     的窗沿 y 轴，经 zoom_map 换算）；y 值域按全量类目计算，缩放/显隐
///     切换时轴不动（同 ECharts dataZoom 语义）
/// zoom_state 传调用方自建的 CiZoom 可拿到窗口句柄（外部复位/读数），
/// 缺省组件自建。
/// 布局 = vbox（图例 + 画布），总高比画布参数多图例行（24 + 6）。
pub fn bar_chart_it(
  data : @core.Store[Array[BarItem]],
  horizontal? : Bool = false,
  y_range? : (Double, Double)? = None,
  zoom? : Bool = true,
  zoom_state? : CiZoom? = None,
  width? : Double = 0.0,
  height? : Double = 280.0,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(data)
  let horiz = horizontal
  let yr = y_range
  let do_zoom = zoom
  let zoom_z = match zoom_state {
    Some(z) => z
    None => ci_zoom_make()
  }
  let hover = Ref(-1)
  let visible = @core.Store::new(ci_fit_len([], data.get().length()))
  let items = @core.Store::new(ci_bar_items(data.get()))
  let sid = data.subscribe_id(fn(_d : Array[BarItem]) -> Unit {
    items.set(ci_bar_items(data.get()))
    visible.update(fn(vs) { ci_fit_len(vs, data.get().length()) })
    @core.invalidate()
  })
  @core.sub_bag_register(fn() { data.remove(sid) })

  fn draw(p : @render.Painter, w : Double, h : Double) -> Unit {
    let all = data.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let n_all = all.length()
    let (i0, i1) = if do_zoom && n_all > 0 {
      ci_zoom_visible(zoom_z, n_all)
    } else {
      (0, n_all - 1)
    }
    // 先按窗取类目，再过滤显隐（flags 仍按全量类目索引寻址）
    let (vis, _vis_idx) = ci_filter_visible_at(
      ci_slice_range(all, i0, i1),
      flags,
      i0,
    )
    let values : Array[Double] = []
    for it in all {
      values.push(it.value)
    }
    let yr2 = match yr {
      Some(r) => r
      None => bar_range(values)
    }
    draw_bar_chart(p, w, h, vis, horiz, hover.val, y_range=Some(yr2))
  }

  fn hit(
    px : Double,
    py : Double,
    w : Double,
    h : Double,
  ) -> (String, Array[(String, String)])? {
    let all = data.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let n_all = all.length()
    let (i0, i1) = if do_zoom && n_all > 0 {
      ci_zoom_visible(zoom_z, n_all)
    } else {
      (0, n_all - 1)
    }
    let windowed = ci_slice_range(all, i0, i1)
    let (vis, _vis_idx) = ci_filter_visible_at(windowed, flags, i0)
    let pos = bar_hit(horiz, vis.length(), w, h, px, py)
    if pos < 0 {
      hover.val = -1
      return None
    }
    hover.val = pos
    let it = vis[pos]
    let color = if it.value >= 0.0 {
      @theme.theme_primary()
    } else {
      @theme.theme_danger()
    }
    Some((it.label, [(color, fmt_axis(it.value))]))
  }

  // zoom 锚点/平移量沿类目轴：横向条类目在 y，纵向柱在 x
  let zmap : (Double, Double, Double, Double) -> Double = if horiz {
    fn(_mx, my, w, h) { ci_bar_plot(true)(w, h).frac(my) * 100.0 }
  } else {
    fn(mx, _my, w, h) { ci_bar_plot(false)(w, h).frac(mx) * 100.0 }
  }

  @ui.vbox(
    [
      ci_legend(
        items~,
        color_at=fn(i) {
          let all = data.get()
          if i >= 0 && i < all.length() && all[i].value < 0.0 {
            @theme.theme_danger()
          } else {
            @theme.theme_primary()
          }
        },
        visible~,
        on_toggle=fn(_i) { @core.invalidate() },
      ),
      ci_tooltip(
        draw,
        hit,
        plot=ci_bar_plot(horiz),
        zoom=if do_zoom { Some(zoom_z) } else { None },
        pan=do_zoom,
        zoom_map=Some(zmap),
        on_leave=fn() { hover.val = -1 },
        width~,
        height~,
      ),
    ],
    row_gap=6.0,
    width=if width > 0.0 { width } else { 0.0 },
    handle~,
  )
}

///|
/// 环形图交互图（交互版 donut_chart_t）：数据/参数语义同原图（thickness
/// 环厚、center 中心文案）；新增：
///   - hover 扇区：浮层显标签 + 值（占比按当前可见扇区重算，与 ECharts
///     legend 联动语义一致），扇区外扩 4px（同原图 hover）
///   - 图例点击显隐扇区（色按原始序号现取，不串色）
/// 环形图无 x 轴，不提供 DataZoom。
/// 布局 = vbox（图例 + 画布），总高比画布参数多图例行（24 + 6）。
pub fn donut_chart_it(
  data : @core.Store[Array[DonutSlice]],
  thickness? : Double = 34.0,
  center? : String = "",
  width? : Double = 0.0,
  height? : Double = 240.0,
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  @ui.follow_store(data)
  let thick = thickness
  let mid = center
  let hover = Ref(-1)
  let visible = @core.Store::new(ci_fit_len([], data.get().length()))
  let items = @core.Store::new(ci_donut_items(data.get()))
  let sid = data.subscribe_id(fn(_d : Array[DonutSlice]) -> Unit {
    items.set(ci_donut_items(data.get()))
    visible.update(fn(vs) { ci_fit_len(vs, data.get().length()) })
    @core.invalidate()
  })
  @core.sub_bag_register(fn() { data.remove(sid) })

  fn draw(p : @render.Painter, w : Double, h : Double) -> Unit {
    let all = data.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let (vis, vis_idx) = ci_filter_visible(all, flags)
    if vis.length() == 0 {
      let _ = @text.draw_box_at(
        p,
        0.0,
        h / 2.0 - 10.0,
        w,
        20.0,
        "暂无数据",
        label_font(),
        @theme.theme_text_secondary(),
        align=@text.Center,
        valign=@text.Center,
        wrap=false,
      )
      return
    }
    // 色按原始序号取（显隐切换不串色）
    draw_donut_core(
      p,
      w,
      h,
      vis,
      fn(i) { donut_color(vis_idx[i]) },
      thick,
      mid,
      hover.val,
    )
  }

  fn hit(
    px : Double,
    py : Double,
    _w : Double,
    h : Double,
  ) -> (String, Array[(String, String)])? {
    let all = data.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let (vis, vis_idx) = ci_filter_visible(all, flags)
    if vis.length() == 0 {
      hover.val = -1
      return None
    }
    let (cx, cy, r_in, r_out) = ci_donut_geom(h, thick)
    let values = vis.map(fn(s) { s.value })
    let pos = ci_sector_at(px, py, cx, cy, r_in, r_out, values)
    if pos < 0 {
      hover.val = -1
      return None
    }
    hover.val = pos
    let it = vis[pos]
    let mut total = 0.0
    for s in vis {
      if s.value > 0.0 {
        total = total + s.value
      }
    }
    let pct = if total > 0.0 {
      (it.value / total * 100.0).round().to_int()
    } else {
      0
    }
    Some(
      (
        it.label,
        [(donut_color(vis_idx[pos]), "\{fmt_axis(it.value)} (\{pct}%)")],
      ),
    )
  }

  @ui.vbox(
    [
      ci_legend(
        items~,
        color_at=fn(i) { donut_color(i) },
        visible~,
        on_toggle=fn(_i) { @core.invalidate() },
      ),
      ci_tooltip(draw, hit, on_leave=fn() { hover.val = -1 }, width~, height~),
    ],
    row_gap=6.0,
    width=if width > 0.0 { width } else { 0.0 },
    handle~,
  )
}
