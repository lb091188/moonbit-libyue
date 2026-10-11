// 导航族首批：分段控制器 / 面包屑 / 分页 / 步骤条 / 折叠面板。
//
// 与 master 的差两条（记档）：① CSS `style` 通道未接，只留类型化参数；
// ② master 那套 `stateful_item(自持 hover/focus)` 在这里换成「底色与文字色由回调
//    现取 + 悬停读宿主维护的 `Widget.hovered`」——交互态归宿主统一置位，组件不
//    再自己处理 enter/leave，也不会留下随重建漂移的私有状态。
// 选中态一律走 `@core.Store[T]`：画法现取 Store，所以外部 `set` 立刻换高亮，
// 订阅只为请求重绘（`follow_store`）。

///|
/// 折叠指示箭头：展开朝下、收起朝右（自绘三角，不吃字体字形）。
fn fold_arrow(
  p : @render.Painter,
  cx : Double,
  cy : Double,
  size : Double,
  open : Bool,
  color : String,
) -> Unit {
  p.set_fill_color(color)
  p.begin_path()
  if open {
    p.move_to(cx - size, cy - size / 2.0)
    p.line_to(cx, cy + size / 2.0)
    p.line_to(cx + size, cy - size / 2.0)
  } else {
    p.move_to(cx - size / 2.0, cy - size)
    p.line_to(cx + size / 2.0, cy)
    p.line_to(cx - size / 2.0, cy + size)
  }
  p.close_path()
  p.fill()
}

///|
/// 一行「文字 + 底色 + 点击」的导航项：底色与文字色由回调现取（入参是本控件，
/// 用来读宿主维护的 `hovered`），`width` 传 0 表示按文本测量定宽。
fn nav_item(
  text : String,
  height : Double,
  pad_x : Double,
  size : Double,
  weight? : @text.FontWeight = @text.Normal,
  width? : Double = 0.0,
  bg? : (@core.Widget) -> String = fn(_w : @core.Widget) -> String { "" },
  fg? : (@core.Widget) -> String = fn(_w : @core.Widget) -> String {
    @theme.theme_text_regular()
  },
  on_click? : () -> Unit = fn() -> Unit { () },
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let font = @text.Font::new("", size, weight=weight)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let tw = text_width(text, font)
    let box_w = if width > 0.0 { width } else { tw + pad_x * 2.0 }
    w.node.set_width(@yoga.fixed(box_w))
    w.node.set_height(@yoga.fixed(height))
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let c = bg(self)
      if c.length() > 0 {
        p.set_fill_color(c)
        p.fill_rect(0.0, 0.0, r.w, r.h)
      }
      let _ = @text.draw_box_at(
        p,
        0.0,
        0.0,
        r.w,
        r.h,
        text,
        font,
        fg(self),
        align=@text.Center,
        valign=@text.Center,
      )
    })
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => true
        @core.Up => {
          let inside = ev.x >= 0.0 && ev.x <= self.rect.w && ev.y >= 0.0 && ev.y <= self.rect.h
          if inside {
            on_click()
            @core.invalidate()
          }
          false
        }
        _ => false
      }
    })
    handle(w)
    w
  })
}

///|
/// 悬停才有的底色（未悬停给空串 = 不铺底）。
fn hover_bg(w : @core.Widget, color : String) -> String {
  if w.hovered { color } else { "" }
}

///|
/// 分段控制器 / 顶栏导航（EP Segmented）：选中面板底 + 主题色文字，悬停灰底。
pub fn segmented(
  options : Array[String],
  selected : @core.Store[String],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(selected)
  let items : Array[@core.Node] = []
  for opt in options {
    let mine = opt
    items.push(
      nav_item(
        mine,
        30.0,
        16.0,
        13.0,
        bg=fn(w : @core.Widget) -> String {
          if selected.get() == mine {
            @theme.theme_bg_panel()
          } else {
            hover_bg(w, @theme.theme_border())
          }
        },
        fg=fn(_w : @core.Widget) -> String {
          if selected.get() == mine {
            @theme.theme_primary()
          } else {
            @theme.theme_text_regular()
          }
        },
        on_click=fn() -> Unit { selected.set(mine) },
      ),
    )
  }
  container(
    items,
    direction=@yoga.Row,
    column_gap=4.0,
    padding=2.0,
    align_items=@yoga.AlignItems::Center,
    bg=@theme.theme_border(),
    handle=handle,
  )
}

///|
/// 面包屑（EP Breadcrumb）：层级之间插 `/`；当前项深色不可点，其余灰色可点、
/// 悬停变主题色。
pub fn breadcrumb(
  items : Array[String],
  selected : @core.Store[String],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(selected)
  let nodes : Array[@core.Node] = []
  let n = items.length()
  for i = 0; i < n; i = i + 1 {
    if i > 0 {
      nodes.push(
        nav_item(
          "/",
          24.0,
          2.0,
          13.0,
          bg=fn(_w : @core.Widget) -> String { "" },
          fg=fn(_w : @core.Widget) -> String { @theme.theme_text_secondary() },
          on_click=fn() -> Unit { () },
        ),
      )
    }
    let mine = items[i]
    let is_last = i == n - 1
    nodes.push(
      nav_item(
        mine,
        24.0,
        4.0,
        13.0,
        bg=fn(_w : @core.Widget) -> String { "" },
        fg=fn(w : @core.Widget) -> String {
          if is_last || selected.get() == mine {
            @theme.theme_text_primary()
          } else if w.hovered {
            @theme.theme_primary()
          } else {
            @theme.theme_text_secondary()
          }
        },
        on_click=fn() -> Unit {
          if !is_last { selected.set(mine) }
        },
      ),
    )
  }
  container(
    nodes,
    direction=@yoga.Row,
    align_items=@yoga.AlignItems::Center,
    handle=handle,
  )
}

///|
/// 分页（EP Pagination）：`‹ 1 2 … ›`，当前页主题色实底白字，悬停浅底。
/// `current` 从 1 起；两侧箭头越界时夹到首/末页。
pub fn pagination(
  current : @core.Store[Int],
  pages : Int,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(current)
  let items : Array[@core.Node] = []
  let hi = if pages > 0 { pages } else { 1 }
  fn step(delta : Int) -> @core.Node {
    let right = delta > 0
    @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
      watch_theme()
      w.node.set_width(@yoga.fixed(28.0))
      w.node.set_height(@yoga.fixed(28.0))
      w.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        if self.hovered {
          p.set_fill_color(@theme.theme_primary_light())
          p.fill_rect(0.0, 0.0, r.w, r.h)
        }
        draw_chevron(
          p,
          r.w / 2.0,
          r.h / 2.0,
          4.0,
          right,
          @theme.theme_text_regular(),
        )
      })
      w.on_pointer = Some(fn(
        _self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Down => true
          @core.Up => {
            let v = current.get() + delta
            current.set(if v < 1 {
              1
            } else if v > hi {
              hi
            } else {
              v
            })
            @core.invalidate()
            false
          }
          _ => false
        }
      })
      w
    })
  }

  items.push(step(-1))
  for i = 1; i <= hi; i = i + 1 {
    let page = i
    items.push(
      nav_item(
        page.to_string(),
        28.0,
        0.0,
        13.0,
        width=28.0,
        bg=fn(w : @core.Widget) -> String {
          if current.get() == page {
            @theme.theme_primary()
          } else {
            hover_bg(w, @theme.theme_primary_light())
          }
        },
        fg=fn(_w : @core.Widget) -> String {
          if current.get() == page {
            "#ffffff"
          } else {
            @theme.theme_text_regular()
          }
        },
        on_click=fn() -> Unit { current.set(page) },
      ),
    )
  }
  items.push(step(1))
  container(
    items,
    direction=@yoga.Row,
    column_gap=4.0,
    align_items=@yoga.AlignItems::Center,
    handle=handle,
  )
}

///|
/// 步骤条（EP Steps）：数字方块（已完成浅底 / 当前实底白字 / 待办灰底）+ 文字 +
/// 连线；`current` 是 0 起始的当前步下标。
pub fn steps(
  items : Array[String],
  current : @core.Store[Int],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(current)
  let nodes : Array[@core.Node] = []
  let n = items.length()
  for i = 0; i < n; i = i + 1 {
    if i > 0 {
      let idx = i
      nodes.push(
        @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
          watch_theme()
          w.node.set_flex_grow(1.0)
          w.node.set_min_width(@yoga.fixed(8.0))
          w.node.set_height(@yoga.fixed(2.0))
          w.on_draw = Some(fn(
            _self : @core.Widget,
            p : @render.Painter,
            r : @core.Rect,
          ) -> Unit {
            p.set_fill_color(
              if current.get() >= idx {
                @theme.theme_primary()
              } else {
                @theme.theme_border()
              },
            )
            p.fill_rect(0.0, 0.0, r.w, r.h)
          })
          w
        }),
      )
    }
    nodes.push(
      nav_item(
        (i + 1).to_string(),
        24.0,
        0.0,
        13.0,
        width=24.0,
        bg=fn(_w : @core.Widget) -> String {
          if i > current.get() {
            @theme.theme_info_light()
          } else if i == current.get() {
            @theme.theme_primary()
          } else {
            @theme.theme_primary_light()
          }
        },
        fg=fn(_w : @core.Widget) -> String {
          if i > current.get() {
            @theme.theme_text_secondary()
          } else if i == current.get() {
            "#ffffff"
          } else {
            @theme.theme_primary()
          }
        },
        on_click=fn() -> Unit { () },
      ),
    )
    let mine = items[i]
    let idx = i
    nodes.push(
      @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
        watch_theme()
        let font = @text.Font::new("", 13.0)
        // 宽度在挂载时按测量定（绘制回调里改布局会把 paint 变成布局的写入方）
        w.node.set_width(@yoga.fixed(text_width(mine, font) + 6.0))
        w.node.set_height(@yoga.fixed(24.0))
        w.on_draw = Some(fn(
          _self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          let _ = @text.draw_box_at(
            p,
            0.0,
            0.0,
            r.w,
            r.h,
            mine,
            font,
            if idx <= current.get() {
              @theme.theme_text_primary()
            } else {
              @theme.theme_text_secondary()
            },
            align=@text.Center,
            valign=@text.Center,
          )
        })
        w
      }),
    )
  }
  container(
    nodes,
    direction=@yoga.Row,
    column_gap=6.0,
    height=40.0,
    align_items=@yoga.AlignItems::Center,
    handle=handle,
  )
}

///|
/// 折叠面板（EP Collapse）：点标题行切换内容显隐，各面板独立开合，
/// 默认只有第一个展开。
pub fn collapse(
  panels : Array[(String, Array[@core.Node])],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let blocks : Array[@core.Node] = []
  let n = panels.length()
  for i = 0; i < n; i = i + 1 {
    let entry = panels[i]
    blocks.push(collapse_panel(entry.0, entry.1, i == 0))
  }
  container(blocks, row_gap=2.0, handle=handle)
}

///|
/// 折叠面板的一块：标题行（底色 + 箭头 + 标题）+ 内容区（预建，靠显隐切换）。
fn collapse_panel(
  title : String,
  body : Array[@core.Node],
  open0 : Bool,
) -> @core.Node {
  let open = Ref(open0)
  let head_font = @text.Font::new("", 13.0, weight=@text.SemiBold)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(@yoga.Column)
    w.node.set_width(@yoga.percent(100.0))
    let body_w = @core.Widget::new()
    body_w.node.set_flex_direction(@yoga.Column)
    body_w.node.set_width(@yoga.percent(100.0))
    body_w.set_padding(12.0, 6.0)
    @core.mount_children(body_w, body)
    body_w.set_visible(open0)
    let head = @core.Widget::new()
    head.node.set_flex_direction(@yoga.Row)
    head.node.set_width(@yoga.percent(100.0))
    head.node.set_height(@yoga.fixed(34.0))
    head.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(
        if self.hovered {
          @theme.theme_primary_light()
        } else {
          @theme.theme_info_light()
        },
      )
      p.fill_rect(0.0, 0.0, r.w, r.h)
      fold_arrow(p, 14.0, r.h / 2.0, 4.0, open.val, @theme.theme_primary())
      let _ = @text.draw_at(
        p,
        26.0,
        (r.h - 18.0) / 2.0,
        title,
        head_font,
        @theme.theme_text_primary(),
      )
    })
    head.on_pointer = Some(fn(
      _self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => true
        @core.Up => {
          open.val = !open.val
          body_w.set_visible(open.val)
          @core.invalidate()
          false
        }
        _ => false
      }
    })
    w.append_child(head)
    w.append_child(body_w)
    w
  })
}
