// 画布与绘制页：container 自绘 + 图片叠加 + 混合模式 + 富文本 AttributedText。

///|
fn page_canvas() -> @yue.Node {
  let hue = Ref(0)
  let blend_i = Ref(0)
  let blends = [
    @yue.BlendMode::Normal,
    @yue.Multiply,
    @yue.Screen,
    @yue.Difference,
    @yue.Xor,
  ]
  let blend_names = ["Normal", "Multiply", "Screen", "Difference", "Xor"]
  let blend_info : @yue.Store[String] = @yue.Store::new("Normal")
  let canvas : Ref[@yue.Container?] = Ref(None)
  let icon_img : @yue.Image? = match
    @yue.read_binary_file("examples/showcase/drag.png") {
    Some(bytes) => {
      let img = @yue.Image::new_from_png(bytes)
      if img.is_empty() {
        None
      } else {
        Some(img)
      }
    }
    None => None
  }
  let repaint = fn() { when_some(canvas, fn(c) { c.schedule_paint() }) }
  let draw_scene = fn(painter : @yue.Painter) -> Unit {
    painter.set_fill_color("#20242C")
    painter.fill_rect(0.0, 0.0, 640.0, 320.0)
    // 三色圆环（色相旋转演示重绘）
    let colors = ["#E8B34B", "#4B8BE8", "#4BE888"]
    for i in 0..<3 {
      painter.set_fill_color(colors[(i + hue.val) % 3])
      painter.arc(160.0 + i.to_double() * 160.0, 140.0, 60.0, 0.0, 6.28318)
      painter.fill()
    }
    // 网格线
    painter.set_stroke_color("#4A5060")
    for k in 0..<9 {
      painter.stroke_rect(24.0, 220.0 + k.to_double() * 10.0, 592.0, 1.0)
    }
    painter.draw_text(
      "MoonBit × libyue 自绘文本",
      24.0,
      276.0,
      592.0,
      30.0,
      align=@yue.TextAlign::Center,
      color="#F0F0F0",
    )
    // 图片叠加（混合模式对它生效）
    match (canvas.val, icon_img) {
      (Some(c), Some(img)) => {
        painter.set_blend_mode(blends[blend_i.val])
        let b = c.get_bounds()
        painter.draw_image(img, b.width - 90.0, 10.0, 80.0, 80.0)
        painter.set_blend_mode(@yue.Normal)
      }
      (_, _) => ()
    }
  }
  // 富文本：范围属性在 Windows 由库内降级为全文应用，说明按平台切换
  let at = @yue.AttributedText::new_with(
    "MoonBit 富文本：这段文字有范围着色与粗体。",
    @yue.TextAttributes::new(),
  )
  at.set_font(@yue.Font::new("Sans", 20.0, weight=@yue.Bold))
  at.set_font_for(@yue.Font::new("Sans", 24.0, weight=@yue.Black), 0, 6)
  at.set_color("#356AA0")
  at.set_color_for("#E5534B", 8, 11)
  let wrap = Ref(true)
  let ellipsis = Ref(false)
  let rt_canvas : Ref[@yue.Container?] = Ref(None)
  let repaint_rt = fn() { when_some(rt_canvas, fn(c) { c.schedule_paint() }) }
  let range_desc = if is_windows() {
    "范围属性（set_font_for/set_color_for）Windows 上由库内降级为全文应用，效果为整行统一格式。"
  } else {
    "范围属性：0-6 号字符 Black 24 号字，8-11 号字符红色（set_font_for/set_color_for）。"
  }
  scroll_page([
    section(
      "自绘画布",
      "container 节点 on_draw 自绘：圆环 / 网格 / 文本 / 图片叠加（混合模式）；schedule_paint 触发重绘；PNG 经 Image::new_from_png 解码。",
      [
        @yue.container(
          on_draw=fn(p) { draw_scene(p) },
          handle=fn(c) {
            canvas.val = Some(c)
            c.on_size_changed(fn() { c.schedule_paint() })
          },
          style=[("height", 320.0), ("marginBottom", 8.0)],
        ),
        @yue.hbox(
          [
            @yue.button("旋转色相", on_click=fn() {
              hue.val = (hue.val + 1) % 3
              repaint()
            }),
            @yue.button("切换混合模式", on_click=fn() {
              blend_i.val = (blend_i.val + 1) % blends.length()
              blend_info.set(blend_names[blend_i.val])
              repaint()
            }),
            @yue.button("导出缩放图", on_click=fn() {
              match icon_img {
                Some(img) => {
                  let half = img.resize(
                    img.get_width() / 2.0,
                    img.get_height() / 2.0,
                  )
                  let ok = half.write_to_file("png", "/tmp/showcase_half.png")
                  blend_info.set("导出 /tmp/showcase_half.png ok=\{ok}")
                }
                None => blend_info.set("无图片可导出")
              }
            }),
          ],
          style=[("marginBottom", 8.0)],
        ),
        @yue.bind_label(blend_info, fn(s) { "混合模式：\{s}" }),
      ],
    ),
    section("富文本 AttributedText", range_desc, [
      @yue.container(
        on_draw=fn(painter) {
          when_some(rt_canvas, fn(c) {
            let size = c.get_bounds()
            painter.fill_rect(0.0, 0.0, size.width, size.height)
            painter.draw_attributed_text(
              at,
              10.0,
              20.0,
              size.width - 20.0,
              100.0,
            )
          })
        },
        handle=fn(c) {
          rt_canvas.val = Some(c)
          c.on_size_changed(fn() { c.schedule_paint() })
        },
        style=[("height", 120.0), ("marginBottom", 8.0)],
        style_str=[("backgroundcolor", "#F4F4F0")],
      ),
      @yue.hbox(
        [
          @yue.button("换行开关", on_click=fn() {
            wrap.val = !wrap.val
            at.set_format({
              align: @yue.Start,
              valign: @yue.Start,
              wrap: wrap.val,
              ellipsis: ellipsis.val,
            })
            repaint_rt()
          }),
          @yue.button("省略号开关", on_click=fn() {
            ellipsis.val = !ellipsis.val
            at.set_format({
              align: @yue.Start,
              valign: @yue.Start,
              wrap: true,
              ellipsis: ellipsis.val,
            })
            repaint_rt()
          }),
          @yue.button("改写文本", on_click=fn() {
            at.set_text("文本已替换 ✓（属性保留）")
            repaint_rt()
          }),
        ],
        style=[("marginBottom", 8.0)],
      ),
      @yue.label_t(
        "系统语义色 Text=\{@yue.system_color(@yue.Text)} WindowBackground=\{@yue.system_color(@yue.WindowBackground)} Border=\{@yue.system_color(@yue.Border)}",
        role=@yue.Secondary,
      ),
    ]),
  ])
}
