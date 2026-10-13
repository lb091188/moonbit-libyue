// 画布与富文本页：Painter 自绘 × AttributedText 富文本。
//
// G7 迁移记档（与 master 旧页的差）：
// ① 旧链路 `@declarative.view(on_draw=…, style=[("height",…)])` 换成
//    `@core.node_of_new` 自挂 on_draw + yoga 尺寸参数（样式字符串在本栈不存在）；
// ② 重绘从「容器 schedule_paint」换成进程级 `@core.invalidate()`（宿主装的
//    是 host_repaint_all：所有在窗置脏 + 唤醒平台泵）；
// ③ 「系统语义色」一行：旧链路 `@yue.system_color(Text/WindowBackground/Border)`
//    在本栈没有对应物，换成真实存在的两个系统读数——深浅（sys_color_scheme，
//    即共享 App 的 dark_mode 来源）与主色（sys_accent，即 accent 来源），
//    且走 bind 直连共享状态，跟随开关开着你拨系统配色它也跟着变；
// ④ 富文本段新增「渐变」能力演示（Painter.set_fill_gradient，旧页没有）。

///|
/// 画布页。页内私有状态（色相偏移/渐变开关/富文本两个格式开关）不进共享 App。
pub fn page_canvas(app : @shared.App) -> @core.Node {
  let hue : Ref[Int] = Ref(0)
  let grad_on : Ref[Bool] = Ref(false)
  // 富文本两个格式开关
  let rt_wrap : Ref[Bool] = Ref(true)
  let rt_ellipsis : Ref[Bool] = Ref(false)
  // 自绘场景（命令式语义：Ref + invalidate，不做响应式包装）
  let draw_scene = fn(p : @render.Painter, r : @core.Rect) -> Unit {
    p.set_fill_color("#20242C")
    p.fill_rect(0.0, 0.0, r.w, r.h)
    let colors = ["#E8B34B", "#4B8BE8", "#4BE888"]
    for i in 0..<3 {
      if grad_on.val && i == 1 {
        let g = @render.Gradient::linear(0.0, 0.0, r.w, r.h)
        g.add_stop(0.0, colors[(i + hue.val) % 3])
        g.add_stop(1.0, "#4BE888")
        p.set_fill_gradient(g)
      } else {
        p.set_fill_color(colors[(i + hue.val) % 3])
      }
      p.arc(
        r.w * (0.25 + 0.25 * i.to_double()),
        r.h * 0.43,
        60.0,
        0.0,
        6.28318,
      )
      p.fill()
    }
    p.set_stroke_color("#4A5060")
    p.set_line_width(1.0)
    for k in 0..<9 {
      p.stroke_rect(24.0, r.h * 0.68 + k.to_double() * 10.0, r.w - 48.0, 1.0)
    }
    // 文本走 text 自己的会话，与 Painter 会话交替前刷一次
    p.flush()
    let _ = @text.draw_box_at(
      p,
      24.0,
      r.h - 44.0,
      r.w - 48.0,
      30.0,
      "MoonBit × libyue 自绘文本",
      @text.Font::new("", 18.0),
      "#F0F0F0",
      align=@text.Center,
      valign=@text.Center,
      wrap=false,
    )
  }
  // 富文本对象：整段粗体 + 前 6 字 24px Black + 8..11 号红
  let rt = @text.AttributedText::new(
    "MoonBit 富文本：这段文字有范围着色与粗体。",
    wrap=rt_wrap.val,
    ellipsis=rt_ellipsis.val,
  )
  rt.set_font(@text.Font::new("", 20.0, weight=@text.Bold))
  rt.set_font_for(@text.Font::new("", 24.0, weight=@text.Black), 0, 6)
  rt.set_color("#356AA0")
  rt.set_color_for("#E5534B", 8, 11)
  @shared.page([
    @shared.section(
      "自绘",
      "Painter 自绘",
      "fill_rect / arc / fill / stroke_rect / draw_text 基础绘制 + 线性渐变填充。场景按控件实际尺寸画（缩放窗口不变形）；「旋转色相」循环三种主色，「渐变」给中间圆上线性渐变。",
      [
        @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
          w.node.set_width(@yoga.fixed(640.0))
          w.node.set_height(@yoga.fixed(300.0))
          w.on_draw = Some(fn(
            _self : @core.Widget,
            p : @render.Painter,
            r : @core.Rect,
          ) -> Unit {
            draw_scene(p, r)
          })
          w
        }),
        @ui.row(
          [
            @ui.button("旋转色相", on_click=fn() {
              hue.val = (hue.val + 1) % 3
              @core.invalidate()
            }),
            @ui.button("渐变开关", variant=@ui.Soft, on_click=fn() {
              grad_on.val = !grad_on.val
              @core.invalidate()
            }),
          ],
          column_gap=8.0,
        ),
      ],
      code=[
        "let draw = fn(p : @render.Painter, r : @core.Rect) -> Unit {",
        "  p.set_fill_color(\"#20242C\")",
        "  p.fill_rect(0.0, 0.0, r.w, r.h)",
        "  p.arc(r.w * 0.25, r.h * 0.43, 60.0, 0.0, 6.28318)",
        "  p.fill()",
        "  p.set_stroke_color(\"#4A5060\")",
        "  p.stroke_rect(24.0, 200.0, r.w - 48.0, 1.0)",
        "  p.flush() // 切 text 会话前刷一次",
        "  let _ = @text.draw_box_at(p, 24.0, r.h - 44.0, r.w - 48.0, 30.0,",
        "    \"自绘文本\", font, \"#F0F0F0\", align=@text.Center)",
        "}",
        "@core.node_of_new(fn(w) {",
        "  w.node.set_width(@yoga.fixed(640.0))",
        "  w.on_draw = Some(fn(_s, p, r) { draw(p, r) })",
        "  w",
        "})",
        "// 内容变了请求重画一帧（无宿主时是空操作）",
        "@core.invalidate()",
      ],
    ),
    @shared.section(
      "富文本",
      "富文本 AttributedText",
      "范围字体/颜色（0-6 号 24px Black、8-11 号红色）+ 换行/省略号开关 + 文本改写（属性保留）。",
      [
        @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
          w.node.set_width(@yoga.fixed(640.0))
          w.node.set_height(@yoga.fixed(120.0))
          w.on_draw = Some(fn(
            _self : @core.Widget,
            p : @render.Painter,
            r : @core.Rect,
          ) -> Unit {
            p.set_fill_color(@theme.theme_bg_panel())
            p.fill_rect(0.0, 0.0, r.w, r.h)
            p.set_stroke_color(@theme.theme_border())
            p.set_line_width(1.0)
            p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
            p.flush()
            let _ = rt.draw_at(p, 10.0, 20.0, r.w - 20.0, r.h - 30.0)
          })
          w
        }),
        @ui.row(
          [
            @ui.button("换行开关", on_click=fn() {
              rt_wrap.val = !rt_wrap.val
              rt.set_format({
                align: @text.Start,
                valign: @text.Start,
                wrap: rt_wrap.val,
                ellipsis: rt_ellipsis.val,
              })
              @core.invalidate()
            }),
            @ui.button("省略号开关", variant=@ui.Soft, on_click=fn() {
              rt_ellipsis.val = !rt_ellipsis.val
              rt.set_format({
                align: @text.Start,
                valign: @text.Start,
                wrap: true,
                ellipsis: rt_ellipsis.val,
              })
              @core.invalidate()
            }),
            @ui.button("改写文本", variant=@ui.Solid, on_click=fn() {
              rt.set_text("文本已替换 ✓（范围属性保留）")
              @core.invalidate()
            }),
          ],
          column_gap=8.0,
        ),
        // 系统读数走共享状态：dark_mode 的来源是 sys_color_scheme、
        // accent 的来源是 sys_accent（跟随开关开时每 2 秒被 main 的 tick 刷新）
        @ui.row(
          [
            @ui.bind_label(app.dark_mode, fn(d) {
              if d {
                "系统深浅：深色"
              } else {
                "系统深浅：浅色"
              }
            }),
            @ui.bind_label(app.accent, fn(a) {
              if a.length() == 0 {
                "系统主色：（无，回落内置）"
              } else {
                "系统主色：\{a}"
              }
            }),
          ],
          column_gap=16.0,
        ),
      ],
      code=[
        "let rt = @text.AttributedText::new(",
        "  \"MoonBit 富文本：这段文字有范围着色与粗体。\", wrap=true)",
        "rt.set_font(@text.Font::new(\"\", 20.0, weight=@text.Bold))",
        "rt.set_font_for(@text.Font::new(\"\", 24.0, weight=@text.Black), 0, 6)",
        "rt.set_color(\"#356AA0\")",
        "rt.set_color_for(\"#E5534B\", 8, 11)",
        "rt.set_format({",
        "  align: @text.Start, valign: @text.Start,",
        "  wrap: false, ellipsis: true,",
        "})",
        "rt.set_text(\"文本已替换 ✓（范围属性保留）\")",
        "// 画：Painter 会话里直接落位",
        "let _ = rt.draw_at(p, 10.0, 20.0, 600.0, 90.0)",
      ],
    ),
  ])
}
