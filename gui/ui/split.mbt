// 可拖动分隔布局：`split`（direction=Horizontal 左右 / Vertical 上下）。
//
// 与 master 的一条差（记档）：旧链路拖动后**直写 bounds + 双写样式**（GTK 上运行期
// 改布局属性重排不落地，见其 probe-splitter 条）；本栈每帧从根重排、样式改完下一
// 帧就生效，所以只改样式即可，不需要第二套几何写入。
//
// 拖动期间靠宿主的**指针捕获**（按下即进入捕获期）：指针拖出把手范围仍投给把手，
// 位移按窗口坐标算，松手结束。

///|
/// 把手宽度（水平分隔）/高度（垂直分隔）。
const SPLITTER_HANDLE : Double = 8.0

///|
/// 把手绘制：常显点纹（不靠悬停也能找到），悬停浅灰底，拖动中主题色 + 白点。
fn splitter_handle_draw(
  p : @render.Painter,
  r : @core.Rect,
  horizontal : Bool,
  hovered : Bool,
  dragging : Bool,
) -> Unit {
  if dragging {
    p.set_fill_color(@theme.theme_primary())
  } else if hovered {
    p.set_fill_color(@theme.theme_fill_hover())
  } else {
    p.set_fill_color(@theme.theme_fill_zebra())
  }
  p.fill_rect(0.0, 0.0, r.w, r.h)
  // 三点纹：水平分隔竖排三点，垂直分隔横排三点
  let cx = r.w / 2.0
  let cy = r.h / 2.0
  let dot = if dragging { "#ffffff" } else { @theme.theme_text_secondary() }
  p.set_fill_color(dot)
  for i = -1; i <= 1; i = i + 1 {
    p.begin_path()
    if horizontal {
      p.arc(cx, cy + i.to_double() * 6.0, 1.6, 0.0, 6.283185307179586)
    } else {
      p.arc(cx + i.to_double() * 6.0, cy, 1.6, 0.0, 6.283185307179586)
    }
    p.fill()
  }
}

///|
/// 分隔布局实现：`horizontal=true` 左右两栏（把手纵向拖动改首栏宽），
/// `false` 上下两栏（把手横向拖动改首栏高）。
fn splitter_impl(
  class : Array[@style.Style],
  horizontal : Bool,
  first : @core.Node,
  second : @core.Node,
  ratio : Double,
  min_first : Double,
  min_second : Double,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let r0 = ratio.clamp(min=0.05, max=0.95)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(if horizontal {
      @yoga.Row
    } else {
      @yoga.Column
    })
    w.node.set_width(@yoga.percent(100.0))
    w.node.set_height(@yoga.percent(100.0))
    // 首栏：初始按比例（百分比），拖动后切成固定值
    let first_wrap = @core.Widget::new()
    first_wrap.node.set_flex_direction(if horizontal {
      @yoga.Column
    } else {
      @yoga.Row
    })
    if horizontal {
      first_wrap.node.set_width(@yoga.percent(r0 * 100.0))
    } else {
      first_wrap.node.set_height(@yoga.percent(r0 * 100.0))
    }
    first_wrap.node.set_flex_shrink(0.0)
    let _ = first.mount_into(first_wrap)
    let second_wrap = @core.Widget::new()
    second_wrap.node.set_flex_direction(if horizontal {
      @yoga.Column
    } else {
      @yoga.Row
    })
    second_wrap.node.set_flex_grow(1.0)
    second_wrap.node.set_min_width(@yoga.fixed(0.0))
    second_wrap.node.set_min_height(@yoga.fixed(0.0))
    let _ = second.mount_into(second_wrap)
    // 把手
    let bar = @core.Widget::new()
    if horizontal {
      bar.node.set_width(@yoga.fixed(SPLITTER_HANDLE))
      bar.node.set_align_self(Some(@yoga.AlignItems::Stretch))
    } else {
      bar.node.set_height(@yoga.fixed(SPLITTER_HANDLE))
      bar.node.set_align_self(Some(@yoga.AlignItems::Stretch))
    }
    bar.node.set_flex_shrink(0.0)
    // 横向分隔用左右箭头、纵向用上下箭头（宿主按命中路径下发）
    bar.cursor = if horizontal { @core.CURSOR_RESIZE_H } else { @core.CURSOR_RESIZE_V }
    let dragging = Ref(false)
    let drag_start : Ref[Double] = Ref(0.0)
    let drag_first0 : Ref[Double] = Ref(0.0)
    bar.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      splitter_handle_draw(p, r, horizontal, self.hovered, dragging.val)
    })
    bar.on_pointer = Some(fn(
      s : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      // 拖动量一律用**窗口坐标**（把手自己的局部坐标 + 把手的绝对位置）：
      // 把手本身会随首栏变宽而平移，用局部坐标做增量会把上一帧的位移从这一帧
      // 的增量里扣掉，实测表现为拖到一半又弹回来、不跟手。
      let at = if horizontal { ev.x } else { ev.y }
      let origin = if horizontal { s.rect.x } else { s.rect.y }
      let win = at + origin
      match ev.kind {
        @widget.PointerKind::Down => {
          dragging.val = true
          drag_start.val = win
          drag_first0.val = if horizontal {
            first_wrap.rect.w
          } else {
            first_wrap.rect.h
          }
          true
        }
        @widget.PointerKind::Move => {
          if dragging.val {
            let cur = win
            // 总量从三个控件的实际矩形读：不捕获父控件（父子互指是引用环）
            let total = if horizontal {
              first_wrap.rect.w + SPLITTER_HANDLE + second_wrap.rect.w
            } else {
              first_wrap.rect.h + SPLITTER_HANDLE + second_wrap.rect.h
            }
            let avail = (total - SPLITTER_HANDLE).max(0.0)
            let nw = (drag_first0.val + (cur - drag_start.val)).clamp(
              min=min_first,
              max=(avail - min_second).max(min_first),
            )
            if horizontal {
              first_wrap.node.set_width(@yoga.fixed(nw))
            } else {
              first_wrap.node.set_height(@yoga.fixed(nw))
            }
            @core.invalidate()
            true
          } else {
            false
          }
        }
        @widget.PointerKind::Up => {
          dragging.val = false
          true
        }
        @widget.PointerKind::Leave => false
      }
    })
    w.append_child(first_wrap)
    w.append_child(bar)
    w.append_child(second_wrap)
    fold_style(w, @style.empty_style(), class)
    handle(w)
    w
  })
}

///|
/// 分隔布局（§2 合并：原 `hsplit` / `vsplit` 一台）：`direction=Horizontal`
/// 左右两栏、把手左右拖动，`direction=Vertical` 上下两栏、把手上下拖动；
/// 首栏最小 `min_first`、次栏最小 `min_second`，拖动全程受这两个下限夹取
/// （缺省下限按方向取 80 / 60，同现状两档）。
pub(all) enum SplitDirection {
  Horizontal
  Vertical
}

///|
pub fn split(
  first : @core.Node,
  second : @core.Node,
  direction? : SplitDirection = Horizontal,
  ratio? : Double = 0.5,
  // 缺省下限按方向分档（同现状 hsplit 80 / vsplit 60）；None=未给,现场折算
  min_first? : Double = 0.0,
  min_second? : Double = 0.0,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let horiz = match direction {
    Horizontal => true
    Vertical => false
  }
  let mf = if min_first > 0.0 { min_first } else { if horiz { 80.0 } else { 60.0 } }
  let ms = if min_second > 0.0 { min_second } else { if horiz { 80.0 } else { 60.0 } }
  splitter_impl(class, horiz, first, second, ratio, mf, ms, handle=handle)
}


