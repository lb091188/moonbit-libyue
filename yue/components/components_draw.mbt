// 自绘基建:小图标字形、清除 ✕、stateful_item 交互项通用挂载器。

///|
/// 焦点环:单层 1px 淡主色描边(默认 40% 透明,不喧宾夺主;
/// 需在深色实底上使用时可传实底友好的颜色,如白色)。

///|
/// 清空按钮 ✕(矢量自绘,不依赖字体字形):中心 (cx,cy),半径 r。
/// 供 clearable 形态的字段在「有值且悬停」时画在右侧清空带内。
fn draw_clear_x(
  p : @yue.Painter,
  cx : Double,
  cy : Double,
  r? : Double = 4.0,
  color? : String = @yue.theme_text_secondary(),
) -> Unit {
  p.set_stroke_color(color)
  p.begin_path()
  p.move_to(cx - r, cy - r)
  p.line_to(cx + r, cy + r)
  p.move_to(cx + r, cy - r)
  p.line_to(cx - r, cy + r)
  p.stroke()
}

///|
/// 自绘小图标(矢量,不依赖字体字形——字形图标 Windows 渲染发虚且
/// 跨平台不一致,库内一律矢量;GTK 端 align=Center 无效,顺带解决
/// 字形居中问题)。中心 (cx,cy),s 为半径。

///|
/// + 号(步进按钮)
fn draw_glyph_plus(
  p : @yue.Painter,
  cx : Double,
  cy : Double,
  s : Double,
  color : String,
) -> Unit {
  p.set_stroke_color(color)
  p.begin_path()
  p.move_to(cx - s, cy)
  p.line_to(cx + s, cy)
  p.move_to(cx, cy - s)
  p.line_to(cx, cy + s)
  p.stroke()
}

///|
/// − 号(步进按钮)
fn draw_glyph_minus(
  p : @yue.Painter,
  cx : Double,
  cy : Double,
  s : Double,
  color : String,
) -> Unit {
  p.set_stroke_color(color)
  p.begin_path()
  p.move_to(cx - s, cy)
  p.line_to(cx + s, cy)
  p.stroke()
}

///|
/// ‹ 朝左三角(实心)
fn draw_glyph_left(
  p : @yue.Painter,
  cx : Double,
  cy : Double,
  s : Double,
  color : String,
) -> Unit {
  p.set_fill_color(color)
  p.begin_path()
  p.move_to(cx + s / 2.0, cy - s)
  p.line_to(cx + s / 2.0, cy + s)
  p.line_to(cx - s / 2.0 - 1.0, cy)
  p.close_path()
  p.fill()
}

///|
/// › 朝右三角(实心)
fn draw_glyph_right(
  p : @yue.Painter,
  cx : Double,
  cy : Double,
  s : Double,
  color : String,
) -> Unit {
  p.set_fill_color(color)
  p.begin_path()
  p.move_to(cx - s / 2.0, cy - s)
  p.line_to(cx - s / 2.0, cy + s)
  p.line_to(cx + s / 2.0 + 1.0, cy)
  p.close_path()
  p.fill()
}

///|
/// 自绘交互项的焦点接线:可聚焦(Tab 链由 GTK 按挂载顺序遍历)、
/// 聚焦变化时重绘、Enter/Space 触发激活。点击聚焦由各组件在
/// on_mouse_down 里调 focus()。

///|
/// 圆角矩形填充(bezier 控制点按圆率 0.5522 近似四角)。r 自动钳到
/// w/2、h/2 以内,窄条也不会画出负半径。

///|
/// 自绘交互项通用挂载器:背景色表达 hover/active,文字垂直居中。
/// bg_of(active, hover) 返回背景色(空串表示透明);fg_of(active) 返回文字色。
/// align_start=false 时文字水平居中(分段/分页),true 时左对齐(菜单)。
/// (GTK 端水平 align 未实现,居中一律手动:测文本宽、x=(w-文本宽)/2。)
/// icon 非空时画在 pad_x 起(16px,文字右移 24);accent 时选中态左缘
/// 画 3px 强调条(与文字同色);rounded 时背景画 4px 圆角。
fn stateful_item(
  text : String,
  style : Array[(String, &@yue.StyVal)],
  selected : @yue.Store[String],
  bg_of : (Bool, Bool) -> String,
  fg_of : (Bool, Bool) -> String,
  pad_x? : Double = 0.0,
  align_start? : Bool = false,
  font_size? : Double = 13.0,
  icon? : @icons.IconKind? = None,
  accent? : Bool = false,
  rounded? : Bool = false,
) -> @yue.Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let focused = Ref(false)
      // 自绘文字不占布局空间:无显式 width 时按文本测宽自动定宽
      let font = @yue.Font::new("Sans", font_size)
      let probe = @yue.AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let mut has_w = false
      for kv in style {
        if kv.0 == "width" {
          has_w = true
        }
      }
      let style2 = if has_w {
        style
      } else {
        let copy = style.copy()
        copy.push(("width", text_w + pad_x * 2.0))
        copy
      }
      let v = @yue.themed_container(style=style2)
      fn draw_item(p : @yue.Painter) -> Unit {
        let b = @yue.ViewLike::get_bounds(v)
        let w = b.width
        let h = b.height
        let act = selected.get() == text
        let bg = bg_of(act, hover.val)
        if bg != "" {
          p.set_fill_color(bg)
          if rounded {
            @yue.fill_round_rect(p, 0.0, 0.0, w, h, 4.0)
          } else {
            p.fill_rect(0.0, 0.0, w, h)
          }
        }
        if accent && act {
          p.set_fill_color(fg_of(act, hover.val))
          p.fill_rect(0.0, 8.0, 3.0, h - 16.0)
        }
        // 图标在 pad_x 起(16px),文字右移;无图标按 align_start/居中排
        let text_x = match icon {
          Some(k) => {
            @icons.draw_icon(
              p,
              k,
              pad_x + 8.0,
              h / 2.0,
              16.0 * 0.42,
              fg_of(act, hover.val),
            )
            pad_x + 24.0
          }
          None => if align_start { pad_x } else { (w - text_w) / 2.0 }
        }
        // 文字:AttributedText 支持指定字号,垂直居中交给 valign=Center;
        // 水平位置手动计算(见函数注释)
        let at = @yue.AttributedText::new(text, valign=@yue.Center, wrap=false)
        at.set_font(font)
        at.set_color(fg_of(act, hover.val))
        p.draw_attributed_text(at, text_x, 0.0, w, h)
        if focused.val {
          @yue.draw_focus_ring(p, w, h)
        }
      }

      v.on_draw(draw_item)
      @yue.View::set_cursor(v, @yue.hand())
      @yue.ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(v)
          selected.set(text)
          true
        } else {
          false
        }
      })
      @yue.ViewLike::on_mouse_enter(v, fn(_e) {
        hover.val = true
        @yue.ViewLike::schedule_paint(v)
      })
      @yue.ViewLike::on_mouse_leave(v, fn(_e) {
        hover.val = false
        @yue.ViewLike::schedule_paint(v)
      })
      @yue.bind_focus(v, fn() { @yue.ViewLike::schedule_paint(v) }, focused, fn() {
        selected.set(text)
      })
      selected.subscribe(fn(_s) { @yue.ViewLike::schedule_paint(v) })
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}
