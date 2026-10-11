// 垂直滚动容器：视口裁剪 + 内容整块平移 + 自绘滚动条（滚轮、拖动、点轨道跳转）。
//
// 平移用布局引擎的相对定位（`position: relative` + `top: -offset`）而不是在
// 控件层另记一套偏移：相对偏移只改落位、不改常规流占位，正是滚动要的语义，
// 于是绘制与命中都跟着布局结果走（宿主每帧从 `collect_abs` 取绝对矩形），
// 组件层不需要第二份坐标换算。
//
// 滚动条是视口的**绝对定位子控件**（贴在右缘、覆盖在内容之上），不是画在视口
// 底色上——这样它才是命中路径上最深的那个控件，按下与拖动不会被内容里的按钮抢走。

///|
/// 滚动状态（引用语义）：偏移、内容高、视口高，以及组件挂上的「应用偏移」回调。
/// 调用方可以直接改它（`set_offset`/`scroll_to_bottom`），组件每帧按它现取。
pub(all) struct ScrollState {
  mut offset : Double
  mut content_h : Double
  mut view_h : Double
  /// 组件在挂载时写入：把当前 `offset` 落到内容节点的 `top` 并请求重绘。
  apply : Ref[() -> Unit]
}

///|
pub fn ScrollState::new() -> ScrollState {
  {
    offset: 0.0,
    content_h: 0.0,
    view_h: 0.0,
    apply: Ref(fn() { () }),
  }
}

///|
/// 可滚的最大偏移（内容高 - 视口高，不足一屏时为 0）。
pub fn ScrollState::max(self : ScrollState) -> Double {
  (self.content_h - self.view_h).max(0.0)
}

///|
/// 当前偏移（已夹过的值）。
pub fn ScrollState::offset_y(self : ScrollState) -> Double {
  self.offset
}

///|
/// 设偏移：越界一律夹到 `[0, max]`，随后把新值落到布局上并请求重绘。
pub fn ScrollState::set_offset(self : ScrollState, v : Double) -> Unit {
  let m = self.max()
  let nv = if v < 0.0 {
    0.0
  } else if v > m {
    m
  } else {
    v
  }
  if nv != self.offset {
    self.offset = nv
    (self.apply.val)()
  }
}

///|
/// 相对滚动（`dy` 正=向下）。
pub fn ScrollState::scroll_by(self : ScrollState, dy : Double) -> Unit {
  self.set_offset(self.offset + dy)
}

///|
/// 滚到底（内容变化后调用可以把已越界的偏移拉回来）。
pub fn ScrollState::scroll_to_bottom(self : ScrollState) -> Unit {
  self.set_offset(self.max())
}

///|
/// 是否已滚到底部（容差 1px，避免浮点抖动）。
pub fn ScrollState::at_bottom(self : ScrollState) -> Bool {
  self.offset >= self.max() - 1.0
}

///|
/// 滚动条宽度（轨道与拇指同宽）。
const SCROLL_BAR_W : Double = 8.0

///|
/// 滚动条控件（贴在视口右缘、与视口同高）：轨道 + 拇指（长度按视口/内容比例、
/// 下限 16px 便于抓），点轨道跳转、按住拖动（拇指中心跟随指针）、松手即止。
/// `scroll_v` 与 `virt_list` 共用。
fn scroll_bar(state : ScrollState) -> @core.Widget {
  let bar = @core.Widget::new()
  bar.node.set_position(@yoga.Absolute)
  bar.node.set_top(@yoga.fixed(0.0))
  bar.node.set_bottom(@yoga.fixed(0.0))
  bar.node.set_right(@yoga.fixed(0.0))
  bar.node.set_width(@yoga.fixed(SCROLL_BAR_W))
  let dragging = Ref(false)
  bar.on_draw = Some(fn(
    _self : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    let vh = state.view_h
    let ch = state.content_h
    // 只在真能滚的时候画（拇指长度按视口/内容比例）
    if ch > vh && vh > 0.0 {
      p.set_fill_color(@theme.theme_fill_zebra())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      let thumb = (r.h * vh / ch).max(16.0)
      let travel = (r.h - thumb).max(0.0)
      let ratio = state.offset / (ch - vh)
      p.set_fill_color(@theme.theme_border())
      p.fill_rect(1.0, ratio * travel, r.w - 2.0, thumb)
    }
  })
  bar.on_pointer = Some(fn(
    self : @core.Widget,
    ev : @core.PointerEvent,
  ) -> Bool {
    let vh = self.rect.h
    let m = state.max()
    let thumb = (vh * vh / state.content_h).max(16.0)
    let travel = (vh - thumb).max(0.0)
    // 把指针 y 换算成偏移：拇指中心跟随指针（写成闭包值，块中段不放裸 fn 声明）
    let y_to_offset : (Double) -> Double = fn(y : Double) -> Double {
      if travel <= 0.0 {
        0.0
      } else {
        ((y - thumb / 2.0) / travel).clamp(min=0.0, max=1.0) * m
      }
    }

    match ev.kind {
      @core.Down => {
        dragging.val = true
        state.set_offset(y_to_offset(ev.y))
        true
      }
      @core.Move => {
        if dragging.val {
          state.set_offset(y_to_offset(ev.y))
        }
        true
      }
      @core.Up => {
        dragging.val = false
        true
      }
      @core.Leave => false
    }
  })
  bar
}

///|
/// 垂直滚动容器：`height` 是视口高（0 = 由父容器给），内容按自然高度排布并可
/// 超出视口；超出部分被裁剪，滚动条画在右缘。
pub fn scroll_v(
  children : Array[@core.Node],
  state : ScrollState,
  width? : Double = 0.0,
  height? : Double = 0.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(viewport : @core.Widget) -> @core.Widget {
    watch_theme()
    viewport.node.set_flex_direction(@yoga.Column)
    if width > 0.0 {
      viewport.node.set_width(@yoga.fixed(width))
    }
    if height > 0.0 {
      viewport.node.set_height(@yoga.fixed(height))
    }
    let content = @core.Widget::new()
    content.node.set_flex_direction(@yoga.Column)
    content.node.set_width(@yoga.percent(100.0))
    content.node.set_position(@yoga.Relative)
    // 不收缩：内容必须按自然高度撑开，超出视口的部分才谈得上滚动
    content.node.set_flex_shrink(0.0)
    content.node.set_top(@yoga.fixed(0.0 - state.offset))
    @core.mount_children(content, children)
    viewport.append_child(content)
    state.apply.val = fn() -> Unit {
      content.node.set_top(@yoga.fixed(0.0 - state.offset))
      @core.invalidate()
    }

    viewport.append_child(scroll_bar(state))
    viewport.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      // 布局已定：把几何抄给状态（滚动条比例与夹取都用它），再画一层描边
      state.view_h = r.h
      state.content_h = content.rect.h
      if state.content_h > state.view_h {
        p.set_stroke_color(@theme.theme_border())
        p.set_line_width(1.0)
        p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      }
    })
    viewport.on_scroll = Some(fn(ev : @core.ScrollEvent) -> Bool {
      let before = state.offset
      // 一格滚 3 行（与常见桌面滚动量同量级），dy 正=向上滚
      state.scroll_by(0.0 - ev.dy * 30.0)
      state.offset != before
    })
    handle(viewport)
    viewport
  })
}
