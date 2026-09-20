// 画布与富文本页:Painter / Image / AttributedText 演示。自绘场景是
// 命令式语义(Ref + schedule_paint),混合模式信息走 Store 手动回显。

///|
fn page_canvas(_app : App) -> @yue.Node {
  let canvas_hue = Ref(0)
  let canvas_blend = Ref(0)
  let canvas_blends = [
    @yue.BlendMode::Normal,
    @yue.Multiply,
    @yue.Screen,
    @yue.Difference,
    @yue.Xor,
  ]
  let canvas_blend_names = ["Normal", "Multiply", "Screen", "Difference", "Xor"]
  let canvas_info : @yue.Store[String] = @yue.Store::new("Normal")
  let canvas_ref : Ref[@yue.Container?] = Ref(None)
  let canvas_rt : Ref[@yue.Container?] = Ref(None)
  let canvas_img : Ref[@yue.Image?] = Ref(
    match @yue.read_binary_file("examples/showcase/icon.png") {
      Some(bytes) => {
        let img = @yue.Image::new_from_png(bytes)
        if img.is_empty() {
          None
        } else {
          Some(img)
        }
      }
      None => None
    },
  )
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
    match (canvas_ref.val, canvas_img.val) {
      (Some(c), Some(img)) => {
        painter.set_blend_mode(canvas_blends[canvas_blend.val])
        let b = c.get_bounds()
        painter.draw_image(img, b.width - 90.0, 10.0, 80.0, 80.0)
        painter.set_blend_mode(@yue.Normal)
      }
      (_, _) => ()
    }
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
  scroll_page([
    section(
      "自绘画布",
      "on_draw 自绘:圆环/网格/文本/PNG 叠加(混合模式)。",
      [
        @yue.container(
          on_draw=fn(p) { draw_canvas_scene(p) },
          handle=fn(c) {
            canvas_ref.val = Some(c)
            c.on_size_changed(fn() { c.schedule_paint() })
          },
          style=[("height", 300.0), ("marginBottom", 8.0), ("width", 640.0)],
        ),
        @yue.hbox([
          @yue.button_t("旋转色相", on_click=fn() {
            canvas_hue.val = (canvas_hue.val + 1) % 3
            canvas_repaint()
          }),
          @yue.button_t("切换混合模式", on_click=fn() {
            canvas_blend.val = (canvas_blend.val + 1) % canvas_blends.length()
            canvas_info.set(canvas_blend_names[canvas_blend.val])
            canvas_repaint()
          }),
          @yue.button_t("导出缩放图", variant=@yue.Solid, on_click=fn() {
            match canvas_img.val {
              Some(img) => {
                let half = img.resize(img.get_width() / 2.0, img.get_height() / 2.0)
                let ok = half.write_to_file("png", "/tmp/components_half.png")
                canvas_info.set(
                  if ok { "已导出 /tmp/components_half.png" } else { "导出失败" },
                )
              }
              None => canvas_info.set("无图片可导出")
            }
          }),
        ]),
        @yue.bind_label(canvas_info, fn(s) { "混合模式:\{s}" }, style=[("marginTop", 8.0)]),
      ],
    ),
    section(
      "富文本 AttributedText",
      "范围字体/颜色(0-6 号加粗、8-11 号红色);换行/省略号/改写。",
      [
        @yue.container(
          on_draw=fn(painter) {
            match canvas_rt.val {
              Some(c) => {
                let size = c.get_bounds()
                painter.fill_rect(0.0, 0.0, size.width, size.height)
                painter.draw_attributed_text(rt, 10.0, 20.0, size.width - 20.0, 100.0)
              }
              None => ()
            }
          },
          handle=fn(c) {
            canvas_rt.val = Some(c)
            c.on_size_changed(fn() { c.schedule_paint() })
          },
          style=[("height", 120.0), ("marginBottom", 8.0), ("width", 640.0)],
          style_str=[("backgroundcolor", "#F4F4F0")],
        ),
        @yue.hbox([
          @yue.button_t("换行开关", on_click=fn() {
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
          @yue.button_t("省略号开关", on_click=fn() {
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
          @yue.button_t("改写文本", variant=@yue.Solid, on_click=fn() {
            rt.set_text("文本已替换 ✓(属性保留)")
            match canvas_rt.val {
              Some(c) => c.schedule_paint()
              None => ()
            }
          }),
        ]),
        @yue.label_t(
          "系统语义色 Text=\{@yue.system_color(@yue.Text)} WindowBackground=\{@yue.system_color(@yue.WindowBackground)} Border=\{@yue.system_color(@yue.Border)}",
          role=@yue.Secondary,
          style=[("marginTop", 8.0)],
        ),
      ],
    ),
  ])
}
