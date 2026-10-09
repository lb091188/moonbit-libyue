// 画布与富文本页:Painter / AttributedText 演示。自绘场景是命令式
// 语义(Ref + schedule_paint)。

///|
pub fn page_canvas(_app : @ui.App) -> @yue.Node {
  let canvas_hue = Ref(0)
  let canvas_ref : Ref[@yue.Container?] = Ref(None)
  let canvas_rt : Ref[@yue.Container?] = Ref(None)
  let canvas_repaint = fn() -> Unit {
    match canvas_ref.val {
      Some(c) => c.schedule_paint()
      None => ()
    }
  }
  let draw_canvas_scene = fn(painter : @yue.Painter) -> Unit {
    painter.set_fill_color("#20242C")
    painter.fill_rect(0.0, 0.0, 640.0, 300.0)
    let colors = ["#E8B34B", "#4B8BE8", "#4BE888"]
    for i in 0..<3 {
      painter.set_fill_color(colors[(i + canvas_hue.val) % 3])
      painter.arc(160.0 + i.to_double() * 160.0, 130.0, 60.0, 0.0, 6.28318)
      painter.fill()
    }
    painter.set_stroke_color("#4A5060")
    for k in 0..<9 {
      painter.stroke_rect(24.0, 205.0 + k.to_double() * 10.0, 592.0, 1.0)
    }
    painter.draw_text(
      "MoonBit × libyue 自绘文本",
      24.0,
      262.0,
      592.0,
      30.0,
      align=@yue.TextAlign::Center,
      color="#F0F0F0",
    )
  }
  // 富文本对象
  let rt = @yue.AttributedText::new_with(
    "MoonBit 富文本:这段文字有范围着色与粗体。",
    @yue.TextAttributes::new(),
  )
  rt.set_font(@yue.Font::new("Sans", 20.0, weight=@yue.Bold))
  rt.set_font_for(@yue.Font::new("Sans", 24.0, weight=@yue.Black), 0, 6)
  rt.set_color("#356AA0")
  rt.set_color_for("#E5534B", 8, 11)
  let rt_wrap = Ref(true)
  let rt_ellipsis = Ref(false)
  @ui.page([
    @ui.section(
      "自绘",
      "Painter 自绘",
      "fill_rect / arc / stroke_rect / draw_text 等基础绘制;线条色 + 填充色 + 圆环 + 网格 + 文本同屏。",
      [
        @declarative.container(
          on_draw=fn(p) { draw_canvas_scene(p) },
          handle=fn(c) {
            canvas_ref.val = Some(c)
            c.on_size_changed(fn() { c.schedule_paint() })
          },
          style=[("height", 300.0), ("marginBottom", 8.0), ("width", 640.0)],
        ),
        @declarative.hbox([
          @components.button_t("旋转色相", on_click=fn() {
            canvas_hue.val = (canvas_hue.val + 1) % 3
            canvas_repaint()
          }),
        ]),
      ],
      code=[
        "@declarative.container(", "  on_draw=fn(p) {", "    p.set_fill_color(\"#4B8BE8\")",
        "    p.fill_rect(10.0, 10.0, 80.0, 60.0)", "    p.arc(200.0, 40.0, 30.0, 0.0, 6.28318)",
        "    p.fill()", "    p.set_stroke_color(\"#4A5060\")", "    p.stroke_rect(10.0, 90.0, 592.0, 1.0)",
        "    p.draw_text(\"自绘文本\", 24.0, 110.0, 592.0, 30.0,", "      align=@yue.TextAlign::Center)",
        "  },", "  handle=fn(c) { c.on_size_changed(fn() { c.schedule_paint() }) },",
        "  style=[(\"height\", 300.0), (\"width\", 640.0)],", ")",
      ],
    ),
    @ui.section(
      "富文本",
      "富文本 AttributedText",
      "范围字体/颜色(0-6 号加粗、8-11 号红色);换行/省略号/改写。",
      [
        @declarative.container(
          on_draw=fn(painter) {
            match canvas_rt.val {
              Some(c) => {
                let size = c.get_bounds()
                painter.fill_rect(0.0, 0.0, size.width, size.height)
                painter.draw_attributed_text(
                  rt,
                  10.0,
                  20.0,
                  size.width - 20.0,
                  100.0,
                )
              }
              None => ()
            }
          },
          handle=fn(c) {
            canvas_rt.val = Some(c)
            c.on_size_changed(fn() { c.schedule_paint() })
          },
          style=[
            ("height", 120.0),
            ("marginBottom", 8.0),
            ("width", 640.0),
            ("backgroundcolor", "#F4F4F0"),
          ],
        ),
        @declarative.hbox([
          @components.button_t("换行开关", on_click=fn() {
            rt_wrap.val = !rt_wrap.val
            rt.set_format({
              align: @yue.Start,
              valign: @yue.Start,
              wrap: rt_wrap.val,
              ellipsis: rt_ellipsis.val,
            })
            match canvas_rt.val {
              Some(c) => c.schedule_paint()
              None => ()
            }
          }),
          @components.button_t("省略号开关", on_click=fn() {
            rt_ellipsis.val = !rt_ellipsis.val
            rt.set_format({
              align: @yue.Start,
              valign: @yue.Start,
              wrap: true,
              ellipsis: rt_ellipsis.val,
            })
            match canvas_rt.val {
              Some(c) => c.schedule_paint()
              None => ()
            }
          }),
          @components.button_t("改写文本", variant=@components.Solid, on_click=fn() {
            rt.set_text("文本已替换 ✓(属性保留)")
            match canvas_rt.val {
              Some(c) => c.schedule_paint()
              None => ()
            }
          }),
        ]),
        @components.label_t(
          "系统语义色 Text=\{@yue.system_color(@yue.Text)} WindowBackground=\{@yue.system_color(@yue.WindowBackground)} Border=\{@yue.system_color(@yue.Border)}",
          role=@components.Secondary,
          style=[("marginTop", 8.0)],
        ),
      ],
      code=[
        "let rt = @yue.AttributedText::new_with(", "  \"MoonBit 富文本:这段文字有范围着色与粗体。\",",
        "  @yue.TextAttributes::new(),", ")", "rt.set_font(@yue.Font::new(\"Sans\", 20.0, weight=@yue.Bold))",
        "rt.set_font_for(@yue.Font::new(\"Sans\", 24.0, weight=@yue.Black), 0, 6)",
        "rt.set_color(\"#356AA0\")", "rt.set_color_for(\"#E5534B\", 8, 11)", "rt.set_format({",
        "  align: @yue.Start,", "  valign: @yue.Start,", "  wrap: true,", "  ellipsis: false,",
        "})", "painter.draw_attributed_text(rt, 10.0, 20.0, 600.0, 100.0)",
      ],
    ),
  ])
}
