// 画布与富文本页:Painter / Image / AttributedText 演示。自绘场景是
// 命令式语义(Ref + schedule_paint),混合模式信息走 Store 手动回显。

///|
pub fn page_canvas(_app : @ui.App) -> @yue.Node {
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
    match @yue.read_binary_file("examples/showcase/assets/icon.png") {
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
  @ui.page([
    @ui.section(
      "自绘",
      "自绘原语(Painter)",
      "fill_rect / arc / stroke_rect / draw_text 等基础绘制;线条色 + 填充色 + 圆环 + 网格 + 文本同屏。",
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
            // Windows 的 GDI+ 合成只有 SourceOver/SourceCopy 两种,
            // 其余混合模式静默无效(见 adaptation.md),回显里如实提示
            let note = if @yue.platform() == "windows" && canvas_blend.val != 0 {
              "(此平台仅 Normal 生效)"
            } else {
              ""
            }
            canvas_info.set(canvas_blend_names[canvas_blend.val] + note)
            canvas_repaint()
          }),
          @yue.button_t("导出缩放图", variant=@yue.Solid, on_click=fn() {
            match canvas_img.val {
              Some(img) => {
                let half = img.resize(
                  img.get_width() / 2.0,
                  img.get_height() / 2.0,
                )
                let ok = half.write_to_file("png", "build/components_half.png")
                canvas_info.set(
                  if ok {
                    "已导出 build/components_half.png"
                  } else {
                    "导出失败"
                  },
                )
              }
              None => canvas_info.set("无图片可导出")
            }
          }),
        ]),
        @yue.bind_label(canvas_info, fn(s) { "混合模式:\{s}" }, style=[
          ("marginTop", 8.0),
        ]),
      ],
      code=[
        "// container on_draw 里拿 Painter 自绘;改状态后 schedule_paint",
        "@yue.container(",
        "  on_draw=fn(p) {",
        "    // set_fill_color(色值):设填充色;8 位 hex 的 alpha 在前,即 #AARRGGBB",
        "    // (与 CSS 的 #RRGGBBAA 相反);要透明度用 @yue.with_alpha,勿手拼后缀",
        "    p.set_fill_color(\"#4B8BE8\")",
        "    // fill_rect(x, y, 宽, 高):按当前填充色画实心矩形(逻辑像素)",
        "    p.fill_rect(10.0, 10.0, 80.0, 60.0)",
        "    // arc(圆心x, 圆心y, 半径, 起始角, 终止角):顺时针弧,弧度、0 指向右",
        "    p.arc(200.0, 40.0, 30.0, 0.0, 6.28318)",
        "    // fill():把当前路径按填充色填充",
        "    p.fill()",
        "    // set_stroke_color(色值):设线色,与填充色相互独立",
        "    p.set_stroke_color(\"#4A5060\")",
        "    // stroke_rect(x, y, 宽, 高):按当前线色描边矩形轮廓",
        "    p.stroke_rect(10.0, 90.0, 592.0, 1.0)",
        "    // draw_text(文本, x, y, 宽, 高):在矩形内画文本,可带命名参数:",
        "    p.draw_text(\"自绘文本\", 24.0, 110.0, 592.0, 30.0,",
        "      // align/valign:Start/Center/End(默认 Start)、color(默认 \"#000\")、",
        "      // wrap(默认 true 自动换行)、ellipsis(默认 false 超宽截断加省略号)",
        "      align=@yue.TextAlign::Center)",
        "  },",
        "  // handle 拿 Container 句柄;on_size_changed 在首次布局/窗口缩放时回调",
        "  handle=fn(c) { c.on_size_changed(fn() { c.schedule_paint() }) },",
        "  // style:数值样式对(属性名, 值);style_str:字符串样式对(如背景色)",
        "  style=[(\"height\", 300.0), (\"width\", 640.0)],",
        ")",
      ],
    ),
    @ui.section(
      "图像",
      "图像与混合模式",
      "draw_image 叠 PNG(右下角)+ blend_mode(Normal/Multiply/Screen/Difference/Xor);导出缩略图到运行目录 build/。Windows 的 GDI+ 合成仅支持 Normal/Copy,其余模式无效果(Linux/macOS 完整)。",
      [
        @yue.descriptions([
          ("Normal", "默认覆盖"),
          ("Multiply", "正片叠底,暗部加深"),
          ("Screen", "滤色,亮部提亮"),
          ("Difference", "差值,反相差异"),
          ("Xor", "异或,重叠区挖空"),
        ]),
        @yue.label_t(
          "拖动/缩放图像由 Container on_size_changed + schedule_paint 驱动(本示例固定尺寸)。",
          role=@yue.Secondary,
          style=[("marginTop", 6.0)],
        ),
      ],
      code=[
        "// 读 PNG → draw_image 叠加;blend_mode 切混合",
        "// read_binary_file(路径):读整个二进制文件,成功返回 Bytes,失败 None",
        "match @yue.read_binary_file(\"examples/showcase/assets/icon.png\") {",
        "  Some(bytes) => {",
        "    // 从内存解码图片(PNG/JPEG);scale 为像素密度系数,默认 1.0",
        "    let img = @yue.Image::new_from_png(bytes)",
        "    // set_blend_mode(模式):设混合模式,对其后所有绘制生效",
        "    p.set_blend_mode(@yue.Multiply)   // Multiply/Screen/Difference/Xor",
        "    // draw_image(图, x, y, 宽, 高):把图片拉伸画到目标矩形",
        "    p.draw_image(img, 10.0, 10.0, 80.0, 80.0)",
        "    // 用完恢复 Normal(默认覆盖),不影响后续绘制",
        "    p.set_blend_mode(@yue.Normal)",
        "  }",
        "  None => ()",
        "}",
        "// 导出缩放图:resize(宽, 高, scale=默认 1.0) 返回新图(原图不变);宽高为像素",
        "let half = img.resize(img.get_width() / 2.0, img.get_height() / 2.0)",
        "// write_to_file(格式, 路径):\"png\" 等,返回是否成功;Windows/Linux 支持,",
        "// macOS 恒失败(发行包未编译进导出实现)",
        "half.write_to_file(\"png\", \"build/half.png\")",
      ],
    ),
    @ui.section(
      "富文本",
      "富文本 AttributedText",
      "范围字体/颜色(0-6 号加粗、8-11 号红色);换行/省略号/改写。",
      [
        @yue.container(
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
      code=[
        "// 范围字体/颜色:_for 后缀按字符下标区间应用",
        "// new_with(文本, 属性):按 TextAttributes 创建富文本;new() 为默认属性",
        "// (start 对齐、自动换行、无省略号、不覆盖字体/颜色)",
        "let rt = @yue.AttributedText::new_with(",
        "  \"MoonBit 富文本:这段文字有范围着色与粗体。\",",
        "  @yue.TextAttributes::new(),",
        ")",
        "// Font::new(族名, 字号, weight=字重(默认 Normal), style=Roman/Italic)",
        "// set_font(字体):对全文设字体(按区间用 set_font_for)",
        "rt.set_font(@yue.Font::new(\"Sans\", 20.0, weight=@yue.Bold))",
        "// set_font_for(字体, start, end):对 [start, end) 字符区间设字体",
        "rt.set_font_for(@yue.Font::new(\"Sans\", 24.0, weight=@yue.Black), 0, 6)",
        "// set_color(色值) 全文设色;set_color_for(色值, start, end) 区间设色",
        "rt.set_color(\"#356AA0\")",
        "rt.set_color_for(\"#E5534B\", 8, 11)",
        "// 换行/省略号经 set_format:整体重设 TextFormat,四个字段都须给出",
        "rt.set_format({",
        "  align: @yue.Start,",
        "  valign: @yue.Start,",
        "  wrap: true,",
        "  ellipsis: false,",
        "})",
        "// draw_attributed_text(富文本对象, x, y, 宽, 高):在目标矩形内绘制,",
        "// 常写在 container 的 on_draw 里",
        "painter.draw_attributed_text(rt, 10.0, 20.0, 600.0, 100.0)",
      ],
    ),
  ])
}
