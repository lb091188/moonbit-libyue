// 图表交互变体:line_chart_it / bar_chart_it / donut_chart_it —— 三个
// 现有图表的交互版(EP Chart 对标,数据类型复用原图表:LineSeries /
// BarItem / DonutSlice):
//   - 内置 hover tooltip:最近数据点/扇区显值 + 系列名(charts_tooltip.mbt
//     的 ci_tooltip + 命中纯函数)
//   - 可点击图例:显隐系列/类目并重绘(charts_interactive.mbt 的 ci_legend)
//   - line/bar 支持 DataZoom:滚轮以鼠标为锚点缩放 + 左键拖拽平移
//     (charts_interactive.mbt 的 ci_zoom;横向条的窗沿 y 轴,经
//     ci_tooltip 的 zoom_map 换算)
// 组合方式:不改 charts.mbt——折线/柱状按 zoom 窗切片后调原绘制原语
// (draw_line_chart / draw_bar_chart,同包私有可见);环形图的 draw_donut
// 图例内嵌且无开关、不可组合,抽取其扇区 + 中心部分为
// ci_draw_donut_sectors(逐行同源,改动 draw_donut 时须同步)。
// 布局 = vbox(图例行 + 交互画布);数据经 Store 驱动,显隐/缩放只
// schedule_paint 画布,不重建视图树;主题切换现取色,图例色板经
// on_theme_change 重建。Store 订阅与 on_theme_change 均在挂载期
// 注册——构造 Node 不产生订阅,未挂载即丢弃的 Node 无残留。
// 纯函数(绘制区边距/环形几何/图例项/窗口定标)在文件头部,
// charts_it_wbtest.mbt 白盒覆盖。

///|
/// line 绘制区(与 charts.mbt draw_line_chart 的边距同源:命中与缩放
/// 锚点必须和折线几何一致;若 draw_line_chart 改边距,此处须同步)。
fn ci_line_plot(show_last : Bool) -> (Double, Double) -> CiPlot {
  let pad_r = if show_last { 56.0 } else { 12.0 }
  fn(w, h) { CiPlot::make(46.0, 12.0, w - pad_r, h - 18.0) }
}

///|
/// bar 绘制区(与 charts.mbt draw_bar_chart 两形态的边距同源,同步义务
/// 同上)。
fn ci_bar_plot(horizontal : Bool) -> (Double, Double) -> CiPlot {
  if horizontal {
    fn(w, h) { CiPlot::make(84.0, 12.0, w - 20.0, h - 24.0) }
  } else {
    fn(w, h) { CiPlot::make(46.0, 14.0, w - 12.0, h - 24.0) }
  }
}

///|
/// 环形几何(与 charts.mbt draw_donut 同源):(cx, cy, r_in, r_out)。
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
/// line 图例项:(名称, 系列色)——色按原始序号取,显隐切换不串色。
fn ci_line_items(all : Array[LineSeries]) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  for si, s in all {
    out.push((s.name, series_color(si)))
  }
  out
}

///|
/// bar 图例项:(类目, 柱色)——正数主色/负数 danger,与 draw_bar_chart
/// 同色。
fn ci_bar_items(all : Array[BarItem]) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  for it in all {
    out.push(
      (it.label, if it.value >= 0.0 { theme_primary() } else { theme_danger() }),
    )
  }
  out
}

///|
/// donut 图例项:(标签, 扇区色)——色按原始序号取,显隐切换不串色。
fn ci_donut_items(all : Array[DonutSlice]) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  for i, s in all {
    out.push((s.label, donut_color(i)))
  }
  out
}

///|
/// 序列窗口长度(各序列最长点数):zoom 窗的定标基准,隐藏序列不改变
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
/// 折线/面积交互图(交互版 line_chart_t):数据/参数语义同原图(area 面积、
/// y_range 手动值域、show_last 末端标注、fill 铺满父容器);新增:
///   - hover 最近点:浮层标题「第 N 点」+ 各可见序列在该点的值,并画
///     竖直准线 + 各序列落点(4×4 色点)
///   - 图例点击显隐序列(不重算窗口长度,色彩按原始序号)
///   - zoom=true 时滚轮以鼠标为锚点缩放、左键拖拽平移(窗按最长序列
///     定标,短序列按同窗截取;y 轴随可见窗自适应,同 auto_y_range)
/// 布局 = vbox(图例 + 画布),总高比原图多图例行(30px)。
pub fn line_chart_it(
  series : Store[Array[LineSeries]],
  area? : Bool = false,
  y_range? : (Double, Double)? = None,
  show_last? : Bool = true,
  zoom? : Bool = true,
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  let chart : Ref[Container?] = Ref(None)
  let zoom_z = ci_zoom_make()
  let hover = Ref(-1)
  let visible = Store::new(ci_fit_len([], series.get().length()))
  let items = Store::new(ci_line_items(series.get()))
  fn repaint() -> Unit {
    match chart.val {
      Some(c) => ViewLike::schedule_paint(c)
      None => ()
    }
  }

  fn draw(p : Painter, w : Double, h : Double) -> Unit {
    let all = series.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let (vis_s, vis_idx) = ci_filter_visible(all, flags)
    let n_win = ci_win_len(all)
    let (i0, i1) = if zoom && n_win > 0 {
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
    draw_line_chart(p, w, h, sliced, area, y_range, show_last)
    // hover 竖直准线 + 各序列落点(x 各自按本序列切片均布,与折线同源)
    let g = hover.val
    if g >= i0 && g <= i1 && sliced.length() > 0 {
      let pl = ci_line_plot(show_last)(w, h)
      let mut n_ref = 0
      for s in sliced {
        if s.points.length() > n_ref {
          n_ref = s.points.length()
        }
      }
      let loc = g - i0
      if loc >= 0 && loc < n_ref && n_ref > 0 {
        let x = map_idx(loc, n_ref, pl.x0, pl.x1)
        p.set_stroke_color(theme_border())
        p.begin_path()
        p.move_to(x, pl.y0)
        p.line_to(x, pl.y1)
        p.stroke()
        // y 值域与 draw_line_chart 同源(给定 manual range 优先,否则自适应切片)
        let (lo, hi) = match y_range {
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
    let pl = ci_line_plot(show_last)(w, h)
    if !pl.contains(px, py) {
      hover.val = -1
      return None
    }
    let n_win = ci_win_len(all)
    let (i0, i1) = if zoom && n_win > 0 {
      ci_zoom_visible(zoom_z, n_win)
    } else {
      (0, n_win - 1)
    }
    // 命中定标:最长可见序列的切片(等长窗口场景即各序列同一点)
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

  let chart_style : Array[(String, &StyVal)] = if fill {
    [("height", 260.0)]
  } else {
    [("width", 560.0), ("height", 260.0)]
  }
  for kv in style {
    chart_style.push(kv)
  }
  let node = vbox(
    [
      ci_legend(items~, visible~, on_toggle=fn(_i) { repaint() }),
      ci_tooltip(
        draw,
        hit,
        plot=ci_line_plot(show_last),
        zoom=if zoom { Some(zoom_z) } else { None },
        pan=zoom,
        style=chart_style,
        handle=fn(c) { chart.val = Some(c) },
      ),
    ],
    style=if fill { [] } else { [("width", 560.0)] },
    handle~,
  )
  // 订阅与主题回调挂载期注册:构造而未挂载的 Node 不占用系列 Store 的
  // 订阅与全局主题回调(与其余图表 mount 期订阅同一模式)
  {
    mount: fn(parent) {
      series.subscribe(fn(_s) {
        items.set(ci_line_items(series.get()))
        visible.update(fn(vs) { ci_fit_len(vs, series.get().length()) })
        repaint()
      })
      // 图例色板随主题重建(系列色是 theme_* 现取名)
      ignore(on_theme_change(fn() { items.set(ci_line_items(series.get())) }))
      node.mount_into(parent)
    },
  }
}

///|
/// 柱状/条形交互图(交互版 bar_chart_t):数据/参数语义同原图(horizontal
/// 横向条、y_range 手动值域、fill 铺满);新增:
///   - hover 类目:浮层显类目标签 + 值(命中复用公共 bar_hit,与绘制
///     同源;柱体高亮由 draw_bar_chart 的 hover 参数承担)
///   - 图例点击显隐类目(色按正负取,同原图)
///   - zoom=true 时滚轮缩放 + 左键拖拽平移(窗按类目索引定标;横向条
///     的窗沿 y 轴,经 zoom_map 换算);y 值域按全量类目计算,缩放/显隐
///     切换时轴不动(同 ECharts dataZoom 语义)
/// 布局 = vbox(图例 + 画布),总高比原图多图例行(30px)。
pub fn bar_chart_it(
  data : Store[Array[BarItem]],
  horizontal? : Bool = false,
  y_range? : (Double, Double)? = None,
  zoom? : Bool = true,
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  let chart : Ref[Container?] = Ref(None)
  let zoom_z = ci_zoom_make()
  let hover = Ref(-1)
  let visible = Store::new(ci_fit_len([], data.get().length()))
  let items = Store::new(ci_bar_items(data.get()))
  fn repaint() -> Unit {
    match chart.val {
      Some(c) => ViewLike::schedule_paint(c)
      None => ()
    }
  }

  fn draw(p : Painter, w : Double, h : Double) -> Unit {
    let all = data.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let n_all = all.length()
    let (i0, i1) = if zoom && n_all > 0 {
      ci_zoom_visible(zoom_z, n_all)
    } else {
      (0, n_all - 1)
    }
    // 先按窗取类目,再过滤显隐(flags 仍按全量类目索引寻址)
    let (vis, _vis_idx) = ci_filter_visible_at(
      ci_slice_range(all, i0, i1),
      flags,
      i0,
    )
    let values : Array[Double] = []
    for it in all {
      values.push(it.value)
    }
    let yr = match y_range {
      Some(r) => r
      None => bar_range(values)
    }
    draw_bar_chart(p, w, h, vis, horizontal, hover.val, y_range=Some(yr))
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
    let (i0, i1) = if zoom && n_all > 0 {
      ci_zoom_visible(zoom_z, n_all)
    } else {
      (0, n_all - 1)
    }
    let windowed = ci_slice_range(all, i0, i1)
    let (vis, _vis_idx) = ci_filter_visible_at(windowed, flags, i0)
    let pos = bar_hit(horizontal, vis.length(), w, h, px, py)
    if pos < 0 {
      hover.val = -1
      return None
    }
    hover.val = pos
    let it = vis[pos]
    let color = if it.value >= 0.0 { theme_primary() } else { theme_danger() }
    Some((it.label, [(color, fmt_axis(it.value))]))
  }

  // zoom 锚点/平移量沿类目轴:横向条类目在 y,纵向柱在 x
  let zmap : (Double, Double, Double, Double) -> Double = if horizontal {
    fn(_mx, my, w, h) { ci_bar_plot(true)(w, h).frac(my) * 100.0 }
  } else {
    fn(mx, _my, w, h) { ci_bar_plot(false)(w, h).frac(mx) * 100.0 }
  }

  let chart_style : Array[(String, &StyVal)] = if fill {
    [("height", 280.0)]
  } else {
    [("width", 560.0), ("height", 280.0)]
  }
  for kv in style {
    chart_style.push(kv)
  }
  let node = vbox(
    [
      ci_legend(items~, visible~, on_toggle=fn(_i) { repaint() }),
      ci_tooltip(
        draw,
        hit,
        plot=ci_bar_plot(horizontal),
        zoom=if zoom { Some(zoom_z) } else { None },
        pan=zoom,
        zoom_map=Some(zmap),
        style=chart_style,
        handle=fn(c) { chart.val = Some(c) },
      ),
    ],
    style=if fill { [] } else { [("width", 560.0)] },
    handle~,
  )
  // 订阅与主题回调挂载期注册(同 line_chart_it)
  {
    mount: fn(parent) {
      data.subscribe(fn(_d) {
        items.set(ci_bar_items(data.get()))
        visible.update(fn(vs) { ci_fit_len(vs, data.get().length()) })
        repaint()
      })
      // 柱色(正负)与图例色板随主题重建
      ignore(on_theme_change(fn() { items.set(ci_bar_items(data.get())) }))
      node.mount_into(parent)
    },
  }
}

///|
/// 环形图扇区 + 中心汇总(交互版核心绘制):自 charts.mbt draw_donut 抽取
/// 扇区与中心两部分——原函数图例内嵌且无开关,不可组合,交互版图例由
/// ci_legend 承担。几何/填充与 fill_ring / sector_angles 逐行同源
/// (改动 draw_donut 时须同步此处);colors 与 data 平行(调用方按原始
/// 序号取色,显隐切换不串色)。
fn ci_draw_donut_sectors(
  p : Painter,
  w : Double,
  h : Double,
  data : Array[DonutSlice],
  colors : Array[String],
  thickness : Double,
  center : String,
  hover : Int,
) -> Unit {
  let n = data.length()
  if n == 0 || w <= 0.0 || h <= 0.0 {
    return
  }
  let (cx, cy, r_in, r_out) = ci_donut_geom(h, thickness)
  let values : Array[Double] = []
  for s in data {
    values.push(s.value)
  }
  for i in 0..<n {
    match sector_angles(values, i) {
      None => ()
      Some((a0, a1)) => {
        if a1 - a0 < 1.0e-6 {
          continue
        }
        let ro = if hover == i { r_out + 4.0 } else { r_out }
        p.set_fill_color(
          if i < colors.length() {
            colors[i]
          } else {
            theme_primary()
          },
        )
        fill_ring(p, cx, cy, ro, r_in, a0, a1)
      }
    }
  }
  // 中心汇总数值(默认正值总和,可用 center 覆盖文案)
  let total = {
    let mut t = 0.0
    for s in data {
      if s.value > 0.0 {
        t = t + s.value
      }
    }
    t
  }
  let center_txt = if center != "" { center } else { fmt_axis(total) }
  let at = AttributedText::new(
    center_txt,
    align=Center,
    valign=Center,
    wrap=false,
  )
  at.set_font(Font::new("Sans", 20.0, weight=SemiBold))
  at.set_color(theme_text_primary())
  let tw = at.get_bounds_for(400.0, 60.0).width
  p.draw_attributed_text(at, cx - tw / 2.0, cy - 18.0, tw + 4.0, 28.0)
  let cap = AttributedText::new(
    "总计",
    align=Center,
    valign=Center,
    wrap=false,
  )
  cap.set_font(Font::new("Sans", 11.0))
  cap.set_color(theme_text_secondary())
  let cw = cap.get_bounds_for(200.0, 20.0).width
  p.draw_attributed_text(cap, cx - cw / 2.0, cy + 10.0, cw + 4.0, 16.0)
}

///|
/// 环形图交互图(交互版 donut_chart_t):数据/参数语义同原图(thickness
/// 环厚、center 中心文案、fill 铺满);新增:
///   - hover 扇区:浮层显标签 + 值(占比按当前可见扇区重算,与 ECharts
///     legend 联动语义一致),扇区外扩 4px(同原图 hover)
///   - 图例点击显隐扇区(色按原始序号取,不串色)
/// 环形图无 x 轴,不提供 DataZoom。
/// 布局 = vbox(图例 + 画布),总高比原图多图例行(30px)。
pub fn donut_chart_it(
  data : Store[Array[DonutSlice]],
  thickness? : Double = 34.0,
  center? : String = "",
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  let chart : Ref[Container?] = Ref(None)
  let hover = Ref(-1)
  let visible = Store::new(ci_fit_len([], data.get().length()))
  let items = Store::new(ci_donut_items(data.get()))
  fn repaint() -> Unit {
    match chart.val {
      Some(c) => ViewLike::schedule_paint(c)
      None => ()
    }
  }

  fn draw(p : Painter, w : Double, h : Double) -> Unit {
    let all = data.get()
    let flags = ci_fit_len(visible.get(), all.length())
    let (vis, vis_idx) = ci_filter_visible(all, flags)
    if vis.length() == 0 {
      let at = AttributedText::new(
        "暂无数据",
        align=Center,
        valign=Center,
        wrap=false,
      )
      at.set_font(Font::new("Sans", 13.0))
      at.set_color(theme_text_secondary())
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
    let colors = vis_idx.map(fn(i) { donut_color(i) })
    ci_draw_donut_sectors(p, w, h, vis, colors, thickness, center, hover.val)
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
    let (cx, cy, r_in, r_out) = ci_donut_geom(h, thickness)
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

  let chart_style : Array[(String, &StyVal)] = if fill {
    [("height", 240.0)]
  } else {
    [("width", 480.0), ("height", 240.0)]
  }
  for kv in style {
    chart_style.push(kv)
  }
  let node = vbox(
    [
      ci_legend(items~, visible~, on_toggle=fn(_i) { repaint() }),
      ci_tooltip(draw, hit, style=chart_style, handle=fn(c) {
        chart.val = Some(c)
      }),
    ],
    style=if fill { [] } else { [("width", 480.0)] },
    handle~,
  )
  // 订阅与主题回调挂载期注册(同 line_chart_it)
  {
    mount: fn(parent) {
      data.subscribe(fn(_d) {
        items.set(ci_donut_items(data.get()))
        visible.update(fn(vs) { ci_fit_len(vs, data.get().length()) })
        repaint()
      })
      // 扇区色板随主题重建
      ignore(on_theme_change(fn() { items.set(ci_donut_items(data.get())) }))
      node.mount_into(parent)
    },
  }
}
