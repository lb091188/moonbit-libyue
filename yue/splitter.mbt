// 可拖动分隔布局:hsplit(水平排布,左右两栏)/ vsplit(垂直排布,
// 上下两栏)。桌面多栏界面的标配件(Qt QSplitter / GTK Paned 对位):
// 8px 自绘把手常显点纹(不靠 hover 也能找到),悬停浅灰底、拖动中
// 主题色 + 白点;拖动经 set_capture 捕获鼠标(拖出把手范围事件不丢),
// window 坐标累计位移改写首栏 flexbasis(像素),release_capture 收势;
// min_first/min_second 钳制两栏最小尺寸。挂载序即排列序与 z 序:
// pane_a → 把手 → pane_b,把手必须挂在两栏之间。主题切换经
// themed_container 自动重绘。

///|
/// 水平分隔:左右两栏,中间纵向把手左右拖动。
pub fn hsplit(
  first : Node,
  second : Node,
  ratio? : Double = 0.5,
  min_first? : Double = 80.0,
  min_second? : Double = 80.0,
) -> Node {
  splitter_impl(true, first, second, ratio, min_first, min_second)
}

///|
/// 垂直分隔:上下两栏,中间横向把手上/下拖动。
pub fn vsplit(
  first : Node,
  second : Node,
  ratio? : Double = 0.5,
  min_first? : Double = 60.0,
  min_second? : Double = 60.0,
) -> Node {
  splitter_impl(false, first, second, ratio, min_first, min_second)
}

///|
fn splitter_impl(
  horizontal : Bool,
  first : Node,
  second : Node,
  ratio : Double,
  min_a : Double,
  min_b : Double,
) -> Node {
  {
    mount: fn(parent) {
      let dragging = Ref(false)
      let hover = Ref(false)
      // 拖动起点:按下时的 window 坐标 + 首栏当时实际尺寸(比维护
      // 累计值准,中途窗口缩放/外部改布局都不漂)
      let start_pos = Ref(0.0)
      let start_basis = Ref(0.0)
      let handle_w = 8.0
      let outer = themed_container(
        style=[("flex", 1.0)],
        style_str=[
          ("flexDirection", if horizontal { "row" } else { "column" }),
        ],
      )
      // 首栏包装容器:尺寸/布局打在包装上,内容 mount 其内(View 句柄
      // 不实现 ViewLike,不能直接设样式)
      let pane_a = themed_container(style_str=[("flexDirection", "column")])
      ViewLike::set_style(pane_a, if horizontal { "minwidth" } else { "minheight" }, min_a)
      ignore((first.mount)(ViewLike::view(pane_a)))
      attach(ViewLike::view(outer), ViewLike::view(pane_a))
      let handle = themed_container(style=[
        if horizontal {
          ("width", handle_w)
        } else {
          ("height", handle_w)
        },
      ])
      attach(ViewLike::view(outer), ViewLike::view(handle))
      let pane_b = themed_container(style_str=[("flexDirection", "column")])
      ViewLike::set_style(pane_b, "flex", 1.0)
      ViewLike::set_style(pane_b, if horizontal { "minwidth" } else { "minheight" }, min_b)
      ignore((second.mount)(ViewLike::view(pane_b)))
      attach(ViewLike::view(outer), ViewLike::view(pane_b))
      // 初始比例:初次布局完成后按实际尺寸换算像素写 flexbasis。百分比
      // 字符串仅 GTK 端解析,Windows 端静默忽略(首栏被压到最小宽),
      // 统一走像素跨平台一致;与拖动写像素同一形态
      let apply_ratio = fn() -> Unit {
        let b = ViewLike::get_bounds(outer)
        let total = (if horizontal { b.width } else { b.height }) - handle_w
        if total > 0.0 {
          ViewLike::set_style(pane_a, "flexbasis", total * ratio)
          ViewLike::update_layout(outer)
        }
      }
      post_task(apply_ratio)
      View::set_cursor(handle, Cursor::new(if horizontal { ResizeEW } else { ResizeNS }))
      // 常显视觉:中间 1px 分隔线 + 双列点纹(border 色),不靠 hover;
      // hover 浅灰底、拖动主题色底白点(把手状态一眼可辨)
      handle.on_draw(fn(p) {
        let b = ViewLike::get_bounds(handle)
        if dragging.val {
          p.set_fill_color(theme_primary())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        } else if hover.val {
          p.set_fill_color(theme_fill_hover())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        let cx = b.width / 2.0
        let cy = b.height / 2.0
        if horizontal {
          p.set_stroke_color(theme_border())
          p.begin_path()
          p.move_to(cx, 2.0)
          p.line_to(cx, b.height - 2.0)
          p.stroke()
        } else {
          p.set_stroke_color(theme_border())
          p.begin_path()
          p.move_to(2.0, cy)
          p.line_to(b.width - 2.0, cy)
          p.stroke()
        }
        let dot_r = 1.0
        let gap = 3.0
        let c = if dragging.val { "#FFFFFF" } else { theme_text_secondary() }
        p.set_fill_color(c)
        for i in [-1, 0, 1] {
          if horizontal {
            icon_dot(p, cx - gap, cy + Double::from_int(i) * gap, dot_r)
            icon_dot(p, cx + gap, cy + Double::from_int(i) * gap, dot_r)
          } else {
            icon_dot(p, cx + Double::from_int(i) * gap, cy - gap, dot_r)
            icon_dot(p, cx + Double::from_int(i) * gap, cy + gap, dot_r)
          }
        }
      })
      ViewLike::on_mouse_enter(handle, fn(_e) {
        hover.val = true
        ViewLike::schedule_paint(handle)
      })
      ViewLike::on_mouse_leave(handle, fn(_e) {
        hover.val = false
        ViewLike::schedule_paint(handle)
      })
      ViewLike::on_mouse_down(handle, fn(e) {
        if e.button == 1 {
          dragging.val = true
          start_pos.val = if horizontal { e.window_x } else { e.window_y }
          let ab = ViewLike::get_bounds(pane_a)
          start_basis.val = if horizontal { ab.width } else { ab.height }
          ViewLike::set_capture(handle)
          ViewLike::schedule_paint(handle)
          true
        } else {
          false
        }
      })
      ViewLike::on_mouse_move(handle, fn(e) {
        if dragging.val {
          let cur = if horizontal { e.window_x } else { e.window_y }
          let total_b = ViewLike::get_bounds(outer)
          let span = if horizontal { total_b.width } else { total_b.height }
          let total = span - handle_w
          let lo = min_a
          let hi = if total - min_b < min_a {
            min_a
          } else {
            total - min_b
          }
          let raw = start_basis.val + (cur - start_pos.val)
          let next = if raw < lo {
            lo
          } else if raw > hi {
            hi
          } else {
            raw
          }
          ViewLike::set_style(pane_a, "flexbasis", next)
          ViewLike::update_layout(outer)
        }
      })
      ViewLike::on_mouse_up(handle, fn(_e) {
        if dragging.val {
          dragging.val = false
          ViewLike::release_capture(handle)
          ViewLike::schedule_paint(handle)
          true
        } else {
          false
        }
      })
      // 系统打断捕获(窗口切换等):复位拖动态,避免把手卡在拖动色
      ViewLike::on_capture_lost(handle, fn() {
        if dragging.val {
          dragging.val = false
          ViewLike::schedule_paint(handle)
        }
      })
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
    },
  }
}
