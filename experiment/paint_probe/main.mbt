// 组件级 paint 探针：native-app 全窗帧 ~230ms，但 NATIVE-APP-RENDER 实测文本
// 只占 ~15ms/帧——剩余大头在非文本绘制。本探针把「图表排 / 虚拟表格 /
// markdown / 纯填充」逐类隔离计时，定位剩下的钱花在哪。
// 跑法：moon run experiment/paint_probe

fn bench(name : String, build : () -> @core.Node, w : Int, h : Int, n : Int) -> Unit {
  let bm = @render.Bitmap::new(w, h)
  let root = @core.Widget::new()
  root.set_size(w.to_double(), h.to_double())
  root.set_column()
  let _ = (build().mount)(root)
  root.relayout(w.to_double(), h.to_double())
  let page = root.children()[0]
  let p = @render.Painter::new(bm)
  let t0 = @win.now_ms()
  let mut it = 0
  while it < n {
    page.paint(p)
    it += 1
  }
  let ms = @win.now_ms() - t0
  println("PAINT-PROB \{name} frames=\{n} \{ms}ms(\{ms / n.to_int64()}ms/帧) size=\{page.rect.w.round().to_int()}x\{page.rect.h.round().to_int()}")
  p.end()
}

fn main {
  let w = 1400
  let h = 900
  let n = 20
  // ① 图表排：native-app 图表页同款三图（折线 80 点 ×2 + 柱 29 根 + 环 3 段）
  let vals : Array[Double] = []
  let vals2 : Array[Double] = []
  for i = 0; i < 80; i = i + 1 {
    let _ = vals.push((i % 37).to_double())
    let _ = vals2.push(((i * 7) % 53).to_double())
  }
  let lin = @core.Store::new([
    @chart.LineSeries::make("负载", max_points=80).with_points(vals),
    @chart.LineSeries::make("延迟", max_points=80).with_points(vals2),
  ])
  let bar_arr : Array[@chart.BarItem] = []
  let mut i = 0
  while i < 29 {
    let _ = bar_arr.push(@chart.BarItem::make("c\{i}", ((i * 13) % 29).to_double() - 4.0))
    i += 1
  }
  let bars = @core.Store::new(bar_arr)
  let rings = @core.Store::new([
    @chart.DonutSlice::make("已完成", 46.0),
    @chart.DonutSlice::make("进行中", 33.0),
    @chart.DonutSlice::make("待办", 21.0),
  ])
  bench(
    "chart_row(折线80x2+柱29+环3, 330x130x2+210x130)",
    fn() -> @core.Node {
      @ui.view(
        [
          @chart.line_chart_it(lin, area=true, width=330.0, height=130.0),
          @chart.bar_chart_it(bars, width=330.0, height=130.0),
          @chart.donut_chart_it(rings, width=210.0, height=130.0),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
        align_items=@yoga.AlignItems::FlexStart,
      )
    },
    w,
    h,
    n,
  )
  // ② 虚拟表格：native-app 表格页同款（200 行只挂可见区间）
  let tb_arr : Array[@ui.TableRow] = []
  let mut i = 0
  while i < 200 {
    let _ = tb_arr.push(@ui.TableRow::make(["虚拟行 \{i}", "\{i} 处", if i % 3 == 0 { "待修" } else { "通过" }]))
    i += 1
  }
  let tb_rows = @core.Store::new(tb_arr)
  bench(
    "table_v(3列200行, 400x210)",
    fn() -> @core.Node {
      @ui.table_v(
        [
          @ui.TableColumn::make("名称", 160.0),
          @ui.TableColumn::make("数值", 100.0, align=@text.End),
          @ui.TableColumn::make("状态", 0.0, sortable=false),
        ],
        tb_rows,
        width=400.0,
        height=210.0,
        row_height=30.0,
      )
    },
    w,
    h,
    n,
  )
  // ③ markdown：native-app 文档块同款（17 种 block + GFM）
  bench(
    "markdown_view(420 宽全要素)",
    fn() -> @core.Node {
      @mdview.markdown_view(
        "# 原生 GUI 栈\n\n段落含 **粗体**、*斜体*、~~删除线~~、`行内码` 与 [链接](https://moonbit-libyue.pages.dev)。\n\n- 无序项\n- [ ] 待办\n- [x] 已办\n\n1. 第一\n2. 第二\n\n> 引用块一行\n\n```moonbit\nfn main {\n  println(\"hi\")\n}\n```\n\n| 列甲 | 列乙 |\n| --- | ---: |\n| a | 1 |\n\n---\n\n术语\n: 定义\n\n脚注引用[^n1]。\n\n[^n1]: 脚注定义一行",
        width=420.0,
      )
    },
    w,
    h,
    n,
  )
  // ④ 纯填充下限：60 张 400×120 圆角卡片底（典型页一屏的卡片密度）
  let bm = @render.Bitmap::new(w, h)
  let p = @render.Painter::new(bm)
  let t0 = @win.now_ms()
  let mut it = 0
  while it < n {
    let mut k = 0
    while k < 60 {
      p.set_fill_color("#20222b")
      p.fill_round_rect(
        ((k % 3) * 460).to_double(),
        ((k / 3) * 130).to_double(),
        400.0,
        120.0,
        6.0,
      )
      k += 1
    }
    it += 1
  }
  let ms = @win.now_ms() - t0
  println("PAINT-PROB fills(60张400x120圆角) frames=\{n} \{ms}ms(\{ms / n.to_int64()}ms/帧)")
  // ⑤ 对照：同尺寸直角 fill_rect（判定贵在圆角路径还是填充本身）
  let t1 = @win.now_ms()
  it = 0
  while it < n {
    let mut k = 0
    while k < 60 {
      p.set_fill_color("#20222b")
      p.fill_rect(((k % 3) * 460).to_double(), ((k / 3) * 130).to_double(), 400.0, 120.0)
      k += 1
    }
    it += 1
  }
  let ms2 = @win.now_ms() - t1
  println("PAINT-PROB fills_rect(60张400x120直角) frames=\{n} \{ms2}ms(\{ms2 / n.to_int64()}ms/帧)")
  // ⑥ 对照：单张大圆角矩形（量单张成本）
  let t2 = @win.now_ms()
  it = 0
  while it < n {
    p.set_fill_color("#20222b")
    p.fill_round_rect(0.0, 0.0, 400.0, 120.0, 6.0)
    it += 1
  }
  let ms3 = @win.now_ms() - t2
  println("PAINT-PROB round_rect_x1(400x120) frames=\{n} \{ms3}ms(\{ms3 / n.to_int64()}ms/帧)")
  // ⑦ 描边：60 张 400×120 圆角卡片描边（卡片 border 的实际密度）
  let t3 = @win.now_ms()
  it = 0
  while it < n {
    let mut k = 0
    while k < 60 {
      p.set_stroke_color("#3a3d4a")
      p.set_line_width(1.0)
      p.stroke_round_rect(((k % 3) * 460).to_double(), ((k / 3) * 130).to_double(), 400.0, 120.0, 6.0)
      k += 1
    }
    it += 1
  }
  let ms4 = @win.now_ms() - t3
  println("PAINT-PROB strokes_rr(60张400x120圆角描边) frames=\{n} \{ms4}ms(\{ms4 / n.to_int64()}ms/帧)")
  // ⑧ 折线：单条 80 段折线 stroke（图表线的实际形状）
  let t4 = @win.now_ms()
  it = 0
  while it < n {
    p.set_stroke_color("#2D68C4")
    p.set_line_width(2.0)
    p.begin_path()
    let mut i2 = 0
    while i2 < 80 {
      let xx = 20.0 + i2.to_double() * 5.0
      let yy = 20.0 + ((i2 * 17) % 90).to_double()
      if i2 == 0 {
        p.move_to(xx, yy)
      } else {
        p.line_to(xx, yy)
      }
      i2 += 1
    }
    p.stroke()
    it += 1
  }
  let ms5 = @win.now_ms() - t4
  println("PAINT-PROB polyline(80段2px折线) frames=\{n} \{ms5}ms(\{ms5 / n.to_int64()}ms/帧)")
  // ⑨ 圆弧：3 个 130 半径圆环（donut 同款）
  let t5 = @win.now_ms()
  it = 0
  while it < n {
    p.set_stroke_color("#2D68C4")
    p.set_line_width(14.0)
    let mut d2 = 0
    while d2 < 3 {
      p.begin_path()
      p.arc(220.0 + d2.to_double() * 300.0, 220.0, 60.0, 0.0, 4.7)
      p.stroke()
      d2 += 1
    }
    it += 1
  }
  let ms6 = @win.now_ms() - t5
  println("PAINT-PROB arcs(3个60半径14px圆弧) frames=\{n} \{ms6}ms(\{ms6 / n.to_int64()}ms/帧)")
  p.end()
}
