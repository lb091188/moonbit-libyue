// 可拖动分隔布局:hsplit(水平排布,左右两栏)/ vsplit(垂直排布,
// 上下两栏)。桌面多栏界面的标配件(Qt QSplitter / GTK Paned 对位):
// 6px 自绘把手,悬停浅灰底、拖动中主题色 + 双列点纹;拖动经 set_capture
// 捕获鼠标(拖出把手范围事件不丢),window 坐标累计位移改写首栏
// flexbasis(像素),release_capture 收势;min_first/min_second 钳制
// 两栏最小尺寸。主题切换经 themed_container 自动重绘。

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
      let handle_w = 6.0
      let outer = themed_container(
        style=[("flex", 1.0)],
        style_str=[
          ("flexDirection", if horizontal { "row" } else { "column" }),
        ],
      )
      // 首栏包装容器:尺寸/布局打在包装上,内容 mount 其内(View 句柄
      // 不实现 ViewLike,不能直接设样式)
      let pane_a = themed_container(style_str=[("flexDirection", "column")])
      let basis_pct = (ratio * 100.0).to_string() + "%"
      ViewLike::set_style_str(pane_a, "flexbasis", basis_pct)
      ViewLike::set_style(pane_a, if horizontal { "minwidth" } else { "minheight" }, min_a)
      ignore((first.mount)(ViewLike::view(pane_a)))
      let handle = themed_container(style=[
        if horizontal {
          ("width", handle_w)
        } else {
          ("height", handle_w)
        },
      ])
      // 挂载序即排列序与 z 序:pane_a → 把手 → pane_b(把手在建好样式后
      // 立即挂入,pane_b 的 mount 随后追加)
      attach(ViewLike::view(outer), ViewLike::view(handle))
      let pane_b = themed_container(style_str=[("flexDirection", "column")])
      ViewLike::set_style(pane_b, "flex", 1.0)
      ViewLike::set_style(pane_b, if horizontal { "minwidth" } else { "minheight" }, min_b)
      ignore((second.mount)(ViewLike::view(pane_b)))
      attach(ViewLike::view(outer), ViewLike::view(pane_b))
      // 把手盖在两栏之间(z 序按挂载序),先挂 pane_a 再挂把手再挂 pane_b
      View::set_cursor(handle, Cursor::new(if horizontal { ResizeEW } else { ResizeNS }))
      handle.on_draw(fn(p) {
        let b = ViewLike::get_bounds(handle)
        if dragging.val {
          p.set_fill_color(theme_primary())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        } else if hover.val {
          p.set_fill_color(theme_fill_hover())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        // 双列点纹:横把手两列三点,竖把手两行三点(中间点用主题描边色)
        let cx = b.width / 2.0
        let cy = b.height / 2.0
        let dot_r = 1.0
        let gap = 3.5
        let c = if dragging.val { "#FFFFFF" } else { theme_border() }
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
      ViewLike::on_mouse_enter(handle,fn(_e) {
        hover.val = true
        ViewLike::schedule_paint(handle)
      })
      ViewLike::on_mouse_leave(handle,fn(_e) {
        hover.val = false
        ViewLike::schedule_paint(handle)
      })
      // 挂载序即排列序:pane_a、把手、pane_b
      attach(ViewLike::view(outer), ViewLike::view(pane_a))
      attach(parent, ViewLike::view(outer))
      ViewLike::view(outer)
    },
  }
}
