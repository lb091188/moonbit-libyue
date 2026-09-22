// 传感器 / 磁盘 / 网络页共用的小部件：迷你曲线（sparkline）与自绘
// 数据行容器。行列表用「单容器 on_draw 遍历数据」而非每行一个节点：
// 行数随数据增减（热插拔传感器 / 挂载 / 网卡）不用重建视图树，1Hz
// 刷新只 schedule_paint 画布；主题切换经 on_theme_change 重绘。

///|
/// 行高（三页统一）。
fn row_h() -> Double {
  34.0
}

///|
/// 迷你曲线：定长窗口折线 + 末端圆点，lo/hi 为值域（调用方给固定域或
/// 窗口峰值，避免每帧因极值跳动而重算轴）。窗口不足 2 点只画末端点。
fn draw_sparkline(
  p : @yue.Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  values : Array[Double],
  lo : Double,
  hi : Double,
  color : String,
) -> Unit {
  let n = values.length()
  if n == 0 || w <= 0.0 || h <= 0.0 {
    return
  }
  let span = (hi - lo).max(1.0e-9)
  fn mapy(v : Double) -> Double {
    y + h - ((v - lo) / span).max(0.0).min(1.0) * h
  }

  if n >= 2 {
    p.begin_path()
    for i in 0..<n {
      let px = x + w * i.to_double() / (n - 1).to_double()
      let py = mapy(values[i])
      if i == 0 {
        p.move_to(px, py)
      } else {
        p.line_to(px, py)
      }
    }
    p.set_stroke_color(color)
    p.stroke()
  }
  let ly = mapy(values[n - 1])
  p.set_fill_color(color)
  p.fill_rect(x + w - 1.5, ly - 1.5, 3.0, 3.0)
}

///|
/// 自绘数据行容器：handle 里挂 on_draw 遍历当前数据作画，数据变化经
/// Store 订阅只重绘画布；行数变化时同步更新容器高度。draw 签名为
/// (painter, width)；rows 存当前行数（供定高与刷新触发）。
fn draw_rows(
  rows : @yue.Store[Int],
  draw : (@yue.Painter, Double) -> Unit,
) -> @yue.Node {
  @yue.vbox(
    [],
    handle=fn(c) {
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        draw(p, b.width)
      })
      rows.subscribe(fn(n) {
        @yue.ViewLike::set_style(c, "height", n.to_double() * row_h())
        c.schedule_paint()
      })
      // 主题切换后重绘（绘制时读 theme_current，与 themed 容器一致）
      @yue.on_theme_change(fn() { c.schedule_paint() })
    },
    style=[("height", rows.get().to_double() * row_h())],
    style_str=[("flexDirection", "column")],
  )
}

///|
/// 斑马纹底色（奇行浅灰）。
fn zebra_bg(i : Int) -> Bool {
  i % 2 == 1
}
