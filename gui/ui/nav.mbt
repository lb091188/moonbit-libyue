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
/// `focusable` 时自动领号进 Tab 链：空格/回车触发 `on_click`，←/↑/→/↓ 调
/// `on_step(∓1)`（由调用方决定方向键换选谁），聚焦时画一圈主题色描边。
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
  focusable? : Bool = false,
  on_step? : (Int) -> Unit = fn(_d : Int) -> Unit { () },
  skin? : @style.Style = @style.empty_style(),
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let font = @text.Font::new("", size, weight=weight)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let tw = text_width(text, font)
    let box_w = if width > 0.0 { width } else { tw + pad_x * 2.0 }
    w.node.set_width(@yoga.fixed(box_w))
    w.node.set_height(@yoga.fixed(height))
    if focusable {
      w.focus_id = auto_focus_id(0)
      w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
        if !ev.press {
          return false
        }
        let ks = ev.keysym
        if ks == @core.KS_SPACE || ks == @core.KS_RETURN {
          on_click()
          @core.invalidate()
          true
        } else if ks == @core.KS_LEFT || ks == @core.KS_UP {
          on_step(-1)
          true
        } else if ks == @core.KS_RIGHT || ks == @core.KS_DOWN {
          on_step(1)
          true
        } else {
          false
        }
      })
    }
    @style.apply(w, skin)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      // 「选中 × 悬停」两轴的取色分支是数据态（不是状态桶，§1.5），留在调用方的
      // 调色回调里；样式槽给了同名属性就以样式为准（class 覆盖内置皮肤）
      let st = @style.style_for(self)
      let c = @style.color_of(st.background_color, bg(self))
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
        @style.color_of(st.color, fg(self)),
        align=@text.Center,
        valign=@text.Center,
      )
      if self.focused {
        p.set_stroke_color(@theme.theme_primary())
        p.set_line_width(1.0)
        p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      }
    })
    w.cursor = @core.CURSOR_HAND
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
/// 键盘口径：每段各自进 Tab 链，空格/回车选中本段，←/↑ 上一段、→/↓ 下一段
/// （到头环绕，选中随键走；焦点停在按键那一段）。
pub fn segmented(
  options : Array[String],
  selected : @core.Store[String],
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(selected)
  let items : Array[@core.Node] = []
  let n = options.length()
  for i = 0; i < n; i = i + 1 {
    let opt = options[i]
    let idx = i
    items.push(
      nav_item(
        opt,
        30.0,
        16.0,
        13.0,
        bg=fn(w : @core.Widget) -> String {
          if selected.get() == opt {
            @theme.theme_bg_panel()
          } else {
            hover_bg(w, @theme.theme_border())
          }
        },
        fg=fn(_w : @core.Widget) -> String {
          if selected.get() == opt {
            @theme.theme_primary()
          } else {
            @theme.theme_text_regular()
          }
        },
        on_click=fn() -> Unit { selected.set(opt) },
        focusable=true,
        on_step=fn(d : Int) -> Unit {
          selected.set(options[((idx + d) % n + n) % n])
        },
        skin=paint_subset(class),
      ),
    )
  }
  view(
    items,
    direction=@yoga.Row,
    column_gap=4.0,
    padding=2.0,
    align_items=@yoga.AlignItems::Center,
    background_color="border",
    class=class,
    handle=handle,
  )
}

///|
/// 面包屑（EP Breadcrumb）：层级之间插 `/`；**当前项**（就是导航状态里那个值）
/// 深色不可点，其余灰色可点、悬停变主题色。当前项按 `selected` 判、不按位置判——
/// 按位置判会让末项永远点不动，而末项未必是当前页。
pub fn breadcrumb(
  items : Array[String],
  selected : @core.Store[String],
  class? : Array[@style.Style] = [],
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
          skin=paint_subset(class),
        ),
      )
    }
    let mine = items[i]
    nodes.push(
      nav_item(
        mine,
        24.0,
        4.0,
        13.0,
        bg=fn(_w : @core.Widget) -> String { "" },
        fg=fn(w : @core.Widget) -> String {
          if selected.get() == mine {
            @theme.theme_text_primary()
          } else if w.hovered {
            @theme.theme_primary()
          } else {
            @theme.theme_text_secondary()
          }
        },
        on_click=fn() -> Unit {
          if selected.get() != mine {
            selected.set(mine)
          }
        },
        skin=paint_subset(class),
      ),
    )
  }
  view(
    nodes,
    direction=@yoga.Row,
    align_items=@yoga.AlignItems::Center,
    class=class,
    handle=handle,
  )
}

///|
/// 分页（EP Pagination）：`‹ 1 2 … ›`，当前页主题色实底白字，悬停浅底。
/// `current` 从 1 起；两侧箭头越界时夹到首/末页。
pub fn pagination(
  current : @core.Store[Int],
  pages : Int,
  class? : Array[@style.Style] = [],
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
      @style.apply(
        w,
        @style.style(color="text_regular").hover(background_color="primary_light")
      )
      @style.apply(w, paint_subset(class))
      w.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        // 悬停底色由 hover 桶供（样式没给就是不铺底）
        let st = @style.style_for(self)
        let bg = @style.color_of(st.background_color, "")
        if bg.length() > 0 {
          p.set_fill_color(bg)
          p.fill_rect(0.0, 0.0, r.w, r.h)
        }
        draw_chevron(
          p,
          r.w / 2.0,
          r.h / 2.0,
          4.0,
          right,
          @style.color_of(st.color, @theme.theme_text_regular()),
        )
      })
      w.cursor = @core.CURSOR_HAND
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
        skin=paint_subset(class),
      ),
    )
  }
  items.push(step(1))
  view(
    items,
    direction=@yoga.Row,
    column_gap=4.0,
    align_items=@yoga.AlignItems::Center,
    class=class,
    handle=handle,
  )
}

///|
/// 步骤条（EP Steps）：数字方块（已完成浅底 / 当前实底白字 / 待办灰底）+ 文字 +
/// 连线；`current` 是 0 起始的当前步下标。
pub fn steps(
  items : Array[String],
  current : @core.Store[Int],
  class? : Array[@style.Style] = [],
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
          @style.apply(w, paint_subset(class))
          w.on_draw = Some(fn(
            self : @core.Widget,
            p : @render.Painter,
            r : @core.Rect,
          ) -> Unit {
            let st = @style.style_for(self)
            p.set_fill_color(
              @style.color_of(
                st.background_color,
                if current.get() >= idx {
                  @theme.theme_primary()
                } else {
                  @theme.theme_border()
                },
              ),
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
        skin=paint_subset(class),
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
        @style.apply(w, paint_subset(class))
        w.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          let st = @style.style_for(self)
          let _ = @text.draw_box_at(
            p,
            0.0,
            0.0,
            r.w,
            r.h,
            mine,
            font,
            @style.color_of(
              st.color,
              if idx <= current.get() {
                @theme.theme_text_primary()
              } else {
                @theme.theme_text_secondary()
              },
            ),
            align=@text.Center,
            valign=@text.Center,
          )
        })
        w
      }),
    )
  }
  view(
    nodes,
    direction=@yoga.Row,
    column_gap=6.0,
    height=40.0,
    align_items=@yoga.AlignItems::Center,
    class=class,
    handle=handle,
  )
}

///|
/// 折叠面板（EP Collapse）：点标题行切换内容显隐，各面板独立开合，
/// 默认只有第一个展开。
pub fn collapse(
  panels : Array[(String, Array[@core.Node])],
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let blocks : Array[@core.Node] = []
  let n = panels.length()
  for i = 0; i < n; i = i + 1 {
    let input = panels[i]
    blocks.push(collapse_panel(input.0, input.1, i == 0, skin=paint_subset(class)))
  }
  view(blocks, row_gap=2.0, class=class, handle=handle)
}

///|
/// 折叠面板的一块：标题行（底色 + 箭头 + 标题）+ 内容区（预建，靠显隐切换）。
fn collapse_panel(
  title : String,
  body : Array[@core.Node],
  open0 : Bool,
  skin~ : @style.Style = @style.empty_style(),
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
    body_w.set_padding(top=6.0, left=12.0)
    @core.mount_children(body_w, body)
    body_w.set_visible(open0)
    let head = @core.Widget::new()
    head.node.set_flex_direction(@yoga.Row)
    head.node.set_width(@yoga.percent(100.0))
    head.node.set_height(@yoga.fixed(34.0))
    // 常态底=info_light、悬停底=primary_light 交给样式桶；箭头是组件记号，留内置
    @style.apply(
      head,
      @style.style(color="text_primary", background_color="info_light")
        .hover(background_color="primary_light")
    )
    @style.apply(head, skin)
    head.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      p.set_fill_color(@style.color_of(st.background_color, @theme.theme_info_light()))
      p.fill_rect(0.0, 0.0, r.w, r.h)
      fold_arrow(p, 14.0, r.h / 2.0, 4.0, open.val, @theme.theme_primary())
      let _ = @text.draw_at(
        p,
        26.0,
        (r.h - 18.0) / 2.0,
        title,
        head_font,
        @style.color_of(st.color, @theme.theme_text_primary()),
      )
    })
    head.cursor = @core.CURSOR_HAND
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

// ---- 导航族次批：侧边菜单 / 分组侧边菜单 / 树 / 页签 ----

///|
/// 圆角矩形填充（4px 圆角档的共用入口）：实现已上收门面
/// `@render.Painter::fill_round_rect`，这里保留组件层惯用名。
pub fn fill_round_rect(
  p : @render.Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  r : Double,
) -> Unit {
  p.fill_round_rect(x, y, w, h, r)
}

///|
/// 侧边菜单一项：40 高、文字左对齐、可选图标、选中态带左缘 3px 强调条。
fn menu_item(
  text : String,
  width : Double,
  selected : @core.Store[String],
  icon : @icons.IconKind?,
  skin~ : @style.Style = @style.empty_style(),
  focusable~ : Bool = false,
  step~ : (Int) -> Unit = fn(_d : Int) { () },
) -> @core.Node {
  let font = @text.Font::new("", 13.0)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(width))
    w.node.set_height(@yoga.fixed(40.0))
    if focusable {
      // 导航菜单的键盘口径（与 segmented 同一条）：Tab 链内移动焦点，空格/
      // 回车选中本项，↑/← 上一项、↓/→ 下一项（到头环绕由 step 的取模保证）
      w.focus_id = auto_focus_id(0)
      w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
        if !ev.press {
          return false
        }
        if ev.keysym == @core.KS_SPACE || ev.keysym == @core.KS_RETURN {
          selected.set(text)
          @core.invalidate()
          true
        } else if ev.keysym == @core.KS_LEFT || ev.keysym == @core.KS_UP {
          step(-1)
          true
        } else if ev.keysym == @core.KS_RIGHT || ev.keysym == @core.KS_DOWN {
          step(1)
          true
        } else {
          false
        }
      })
    }
    // 常态文字色与悬停底走样式（选中态是数据态：底色/文字/强调条留内置配色）
    @style.apply(
      w,
      @style.style(color="text_primary", border_radius=4.0).hover(background_color="fill_hover")
    )
    @style.apply(w, skin)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      let rad = @style.number_of(st.border_radius, 4.0)
      let act = selected.get() == text
      let fg = if act {
        @theme.theme_primary()
      } else {
        @style.color_of(st.color, @theme.theme_text_primary())
      }
      let bg = @style.color_of(st.background_color, "")
      if act {
        p.set_fill_color(@theme.theme_primary_light())
        fill_round_rect(p, 0.0, 0.0, r.w, r.h, rad)
      } else if bg.length() > 0 {
        p.set_fill_color(bg)
        fill_round_rect(p, 0.0, 0.0, r.w, r.h, rad)
      }
      if act {
        p.set_fill_color(fg)
        p.fill_rect(0.0, 8.0, 3.0, r.h - 16.0)
      }
      let mut tx = 20.0
      match icon {
        Some(k) => {
          @icons.draw_icon(p, k, 22.0, r.h / 2.0, 6.72, fg)
          tx = 44.0
        }
        None => ()
      }
      let _ = @text.draw_box_at(
        p,
        tx,
        0.0,
        (r.w - tx).max(1.0),
        r.h,
        text,
        font,
        fg,
        align=@text.Start,
        valign=@text.Center,
      )
      // 聚焦时描一圈主题色（键盘可及性：能聚焦就得看得见焦点在哪）
      if self.focused {
        p.set_stroke_color(@theme.theme_primary())
        p.set_line_width(1.0)
        p.stroke_round_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0, 4.0)
      }
    })
    w.cursor = @core.CURSOR_HAND
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => true
        @core.Up => {
          let inside = ev.x >= 0.0 && ev.x <= self.rect.w && ev.y >= 0.0 && ev.y <= self.rect.h
          if inside {
            selected.set(text)
            @core.invalidate()
          }
          false
        }
        _ => false
      }
    })
    w
  })
}

fn icon_for(icons : Array[(String, @icons.IconKind)], name : String) -> @icons.IconKind? {
  for kv in icons {
    if kv.0 == name {
      return Some(kv.1)
    }
  }
  None
}

///|
/// 侧边导航菜单（EP Menu）：悬停浅灰、选中主题浅底 + 主题色文字 + 左缘强调条。
/// `selected` 是共享状态，主区可以订阅同一个 Store 做页面联动。
pub fn menu(
  items : Array[String],
  selected : @core.Store[String],
  icons? : Array[(String, @icons.IconKind)] = [],
  width? : Double = 180.0,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(selected)
  let nodes : Array[@core.Node] = []
  for it in items {
    nodes.push(
      menu_item(
        it,
        width - 12.0,
        selected,
        icon_for(icons, it),
        skin=paint_subset(class),
      ),
    )
  }
  view(
    nodes,
    width=width,
    row_gap=2.0,
    padding=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    class=class,
    handle=handle,
  )
}

///|
/// 分组侧边菜单：组标题行（次要色小字 + 折叠箭头）+ 组内菜单项。
/// `foldable=true` 时点标题收起/展开组内项（默认全展开）。
pub fn menu_sections(
  sections : Array[(String, Array[String])],
  selected : @core.Store[String],
  icons? : Array[(String, @icons.IconKind)] = [],
  foldable? : Bool = true,
  width? : Double = 180.0,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(selected)
  let blocks : Array[@core.Node] = []
  for sec in sections {
    let title = sec.0
    let items = sec.1
    let nodes : Array[@core.Node] = []
    let skin = paint_subset(class)
    let n = items.length()
    for i = 0; i < n; i = i + 1 {
      let it = items[i]
      let idx = i
      nodes.push(
        menu_item(
          it,
          width - 12.0,
          selected,
          icon_for(icons, it),
          skin=skin,
          focusable=true,
          step=fn(d : Int) {
            // 组内环绕换选：方向键的落点与点击一致（换 selected 本身）
            selected.set(items[((idx + d) % n + n) % n])
            @core.invalidate()
          },
        ),
      )
    }
    let open = Ref(true)
    let head_font = @text.Font::new("", 12.0)
    // 组内项直接建控件（不是 Node）：标题行的收起回调要拿得到它
    let body = @core.Widget::new()
    body.node.set_flex_direction(@yoga.Column)
    body.node.set_gap(2.0, 0.0)
    body.node.set_align_items(@yoga.AlignItems::FlexStart)
    @core.mount_children(body, nodes)
    let head = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
      watch_theme()
      w.node.set_width(@yoga.fixed(width - 12.0))
      w.node.set_height(@yoga.fixed(24.0))
      @style.apply(w, @style.style(color="text_secondary"))
      @style.apply(w, paint_subset(class))
      w.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        let st = @style.style_for(self)
        let _ = @text.draw_box_at(
          p,
          4.0,
          0.0,
          r.w,
          r.h,
          title,
          head_font,
          @style.color_of(st.color, @theme.theme_text_secondary()),
          align=@text.Start,
          valign=@text.Center,
        )

        if foldable {
          fold_arrow(p, r.w - 10.0, r.h / 2.0, 3.5, open.val, @theme.theme_text_secondary())
        }
      })
      w.cursor = @core.CURSOR_HAND
      w.on_pointer = Some(fn(
        _self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Down => foldable
          @core.Up => {
            if foldable {
              open.val = !open.val
              body.set_visible(open.val)
              @core.invalidate()
            }
            false
          }
          _ => false
        }
      })
      w
    })
    blocks.push(head)
    blocks.push(@core.node_of(body))
  }
  view(blocks, row_gap=2.0, padding=6.0, width=width, class=class, handle=handle)
}

///|
/// 树节点（自引用：子节点表可为空）。
pub(all) struct TreeNode {
  label : String
  children : Array[TreeNode]
}

///|
/// 树形控件（EP Tree）：缩进层级 + 点击展开/收起（有子节点才画箭头）。
fn build_tree_rows(
  into : @core.Widget,
  nodes : Array[TreeNode],
  level : Int,
  skin~ : @style.Style = @style.empty_style(),
) -> Unit {
  let font = @text.Font::new("", 13.0)
  for nd in nodes {
    let has_kids = nd.children.length() > 0
    let open = Ref(false)
    let row = @core.Widget::new()
    row.node.set_flex_direction(@yoga.Row)
    row.node.set_width(@yoga.fixed(260.0))
    row.node.set_height(@yoga.fixed(32.0))
    row.set_margin(left=level.to_double() * 18.0)
    // 标签色与悬停底走样式（箭头记号与「有才悬停」的条件留组件语义）
    @style.apply(
      row,
      @style.style(color="text_primary").hover(background_color="fill_hover")
    )
    @style.apply(row, skin)
    row.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      let bg = @style.color_of(st.background_color, "")
      if has_kids && bg.length() > 0 {
        p.set_fill_color(bg)
        p.fill_rect(0.0, 0.0, r.w, r.h)
      }
      if has_kids {
        // 实心小三角：展开朝下、收起朝右
        p.set_fill_color(@theme.theme_text_secondary())
        p.begin_path()
        if open.val {
          p.move_to(2.0, 12.0)
          p.line_to(10.0, 12.0)
          p.line_to(6.0, 18.0)
        } else {
          p.move_to(4.0, 11.0)
          p.line_to(10.0, 16.0)
          p.line_to(4.0, 21.0)
        }
        p.close_path()
        p.fill()
      }
      let _ = @text.draw_box_at(
        p,
        14.0,
        0.0,
        (r.w - 14.0).max(1.0),
        r.h,
        nd.label,
        font,
        @style.color_of(st.color, @theme.theme_text_primary()),
        align=@text.Start,
        valign=@text.Center,
      )
    })
    let kids = @core.Widget::new()
    kids.node.set_flex_direction(@yoga.Column)
    kids.set_visible(false)
    if has_kids {
      build_tree_rows(kids, nd.children, level + 1, skin=skin)
    }
    row.cursor = @core.CURSOR_HAND
    row.on_pointer = Some(fn(
      _self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => has_kids
        @core.Up => {
          if has_kids {
            open.val = !open.val
            kids.set_visible(open.val)
            @core.invalidate()
          }
          false
        }
        _ => false
      }
    })
    into.append_child(row)
    into.append_child(kids)
  }
}

///|
/// 树形控件：`root` 是顶层节点表，逐层缩进，点有子节点的行展开/收起。
pub fn tree(
  root : Array[TreeNode],
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(@yoga.Column)
    w.node.set_width(@yoga.percent(100.0))
    build_tree_rows(w, root, 0, skin=paint_subset(class))
    fold_style(w, @style.empty_style(), class)
    handle(w)
    w
  })
}

///|
/// 页签（EP Tabs，顶部形态）：页签头行（选中主题色文字 + 底部 2px 指示条，
/// 悬停变深）+ 内容区预建、靠显隐切换。`selected` 是页序号 Store（0 起始），
/// 不传则内部建一个。
pub fn tabs(
  pages : Array[(String, @core.Node)],
  selected? : @core.Store[Int],
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let n = pages.length()
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let sel = match selected {
      Some(s) => s
      None => @core.Store::new(0)
    }
    follow_store(sel)
    w.node.set_flex_direction(@yoga.Column)
    w.node.set_width(@yoga.percent(100.0))
    let font = @text.Font::new("", 13.0)
    let head = @core.Widget::new()
    head.node.set_flex_direction(@yoga.Row)
    head.node.set_height(@yoga.fixed(36.0))
    head.node.set_width(@yoga.percent(100.0))
    let panels : Array[@core.Widget] = []
    w.append_child(head)
    fn show(i : Int) -> Unit {
      // 先显示新页再隐藏旧页：反序会让「新页未显示、旧页已隐藏」的
      // 中间态把外层容器按 0 内容算高
      if i >= 0 && i < n {
        panels[i].set_visible(true)
      }
      for j = 0; j < n; j = j + 1 {
        if j != i {
          panels[j].set_visible(false)
        }
      }
      @core.invalidate()
    }

    for i = 0; i < n; i = i + 1 {
      let idx = i
      let title = pages[i].0
      let tw = text_width(title, font)
      let tab = @core.Widget::new()
      tab.node.set_width(@yoga.fixed(tw + 28.0))
      tab.node.set_height(@yoga.fixed(36.0))
      tab.set_margin(right=8.0)
      // 未选中文字的常态色/悬停色交给样式基块与 hover 桶；选中态（含下划线）是数据态
      @style.apply(
        tab,
        @style.style(color="text_secondary").hover(color="text_regular")
      )
      @style.apply(tab, paint_subset(class))
      tab.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        let st = @style.style_for(self)
        let act = sel.get() == idx
        let color = if act {
          @theme.theme_primary()
        } else {
          @style.color_of(st.color, @theme.theme_text_secondary())
        }
        let _ = @text.draw_box_at(
          p,
          14.0,
          0.0,
          (r.w - 14.0).max(1.0),
          r.h,
          title,
          font,
          color,
          align=@text.Start,
          valign=@text.Center,
        )

        if act {
          p.set_fill_color(@theme.theme_primary())
          p.fill_rect(0.0, r.h - 2.0, r.w, 2.0)
        }
      })
      tab.cursor = @core.CURSOR_HAND
      tab.on_pointer = Some(fn(
        _self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Down => true
          @core.Up => {
            sel.set(idx)
            false
          }
          _ => false
        }
      })
      head.append_child(tab)
      let page = @core.Widget::new()
      page.node.set_flex_direction(@yoga.Column)
      page.node.set_width(@yoga.percent(100.0))
      page.set_padding(top=6.0, left=6.0)
      let _ = (pages[i].1.mount)(page)
      page.set_visible(sel.get() == idx)
      w.append_child(page)
      panels.push(page)
    }
    let sid = sel.signal().subscribe(fn(i : Int) -> Unit { show(i) })
    @core.sub_bag_register(fn() { sel.signal().remove(sid) })
    fold_style(w, @style.empty_style(), class)
    handle(w)
    w
  })
}

///|
/// 穿梭框（EP Transfer）：左右两列，点行选中（方块标记），中间 `›`/`‹` 把选中项
/// 在两列间移动。两列面板至少 `height` 高（项多了自己长高，不会被裁），默认
/// 200×160——原来 160×60 小得不像可操作的列表。两列数据各由一个 `Store[Array[String]]` 驱动，外部改数据即整列
/// 重建；重建式列表的行不持订阅（选中集合是自持的两张表），所以重建次数不会
/// 累积死订阅。
pub fn transfer(
  left_items : @core.Store[Array[String]],
  right_items : @core.Store[Array[String]],
  width? : Double = 200.0,
  height? : Double = 160.0,
  item_height? : Double = 24.0,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(@yoga.Row)
    w.node.set_align_items(@yoga.AlignItems::Center)
    w.node.set_gap(0.0, 6.0)
    let font = @text.Font::new("", 13.0)
    let left_sel : Ref[Array[String]] = Ref([])
    let right_sel : Ref[Array[String]] = Ref([])
    let left_box = @core.Widget::new()
    let right_box = @core.Widget::new()
    left_box.node.set_flex_direction(@yoga.Column)
    right_box.node.set_flex_direction(@yoga.Column)
    for box in [left_box, right_box] {
      box.node.set_width(@yoga.fixed(width))
      box.node.set_min_height(@yoga.fixed(height))
      @style.apply(
        box,
        @style.style(background_color="bg_panel", border_color="border", border_width=1.0)
      )
      @style.apply(box, paint_subset(class))
      box.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        let st = @style.style_for(self)
        p.set_fill_color(@style.color_of(st.background_color, @theme.theme_bg_panel()))
        p.fill_rect(0.0, 0.0, r.w, r.h)
        p.set_stroke_color(@style.color_of(st.border_color, @theme.theme_border()))
        p.set_line_width(@style.number_of(st.border_width, 1.0))
        p.stroke_rect(0.0, 0.0, r.w, r.h)
      })
    }

    fn contains(arr : Array[String], s : String) -> Bool {
      for x in arr {
        if x == s {
          return true
        }
      }
      false
    }

    fn without(arr : Array[String], s : String) -> Array[String] {
      let out : Array[String] = []
      for x in arr {
        if x != s {
          out.push(x)
        }
      }
      out
    }

    fn with_added(arr : Array[String], s : String) -> Array[String] {
      let out = arr.copy()
      out.push(s)
      out
    }

    fn build_list(
      box : @core.Widget,
      items : @core.Store[Array[String]],
      sel : Ref[Array[String]],
    ) -> Unit {
      for name in items.get() {
        let mine = name
        let row_w = @core.Widget::new()
        row_w.node.set_width(@yoga.percent(100.0))
        row_w.node.set_height(@yoga.fixed(item_height))
        @style.apply(
          row_w,
          @style.style(color="text_regular").hover(background_color="fill_hover")
        )
        @style.apply(row_w, paint_subset(class))
        row_w.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          let st = @style.style_for(self)
          let on = contains(sel.val, mine)
          let bg = @style.color_of(st.background_color, "")
          if bg.length() > 0 {
            p.set_fill_color(bg)
            p.fill_rect(0.0, 0.0, r.w, r.h)
          }
          p.set_fill_color(
            if on {
              @theme.theme_primary()
            } else {
              @theme.theme_border()
            },
          )
          p.fill_rect(6.0, (r.h - 8.0) / 2.0, 8.0, 8.0)
          let _ = @text.draw_box_at(
            p,
            20.0,
            0.0,
            (r.w - 20.0).max(1.0),
            r.h,
            mine,
            font,
            @style.color_of(st.color, @theme.theme_text_regular()),
            align=@text.Start,
            valign=@text.Center,
          )
        })
        row_w.cursor = @core.CURSOR_HAND
        row_w.on_pointer = Some(fn(
          _self : @core.Widget,
          ev : @core.PointerEvent,
        ) -> Bool {
          match ev.kind {
            @core.Down => true
            @core.Up => {
              sel.val = if contains(sel.val, mine) {
                without(sel.val, mine)
              } else {
                with_added(sel.val, mine)
              }
              @core.invalidate()
              false
            }
            _ => false
          }
        })
        box.append_child(row_w)
      }
    }

    fn render_all() -> Unit {
      left_box.clear_children()
      right_box.clear_children()
      build_list(left_box, left_items, left_sel)
      build_list(right_box, right_items, right_sel)
      @core.invalidate()
    }

    let sid_l = left_items.signal().subscribe(fn(_v : Array[String]) -> Unit {
      render_all()
    })
    @core.sub_bag_register(fn() { left_items.signal().remove(sid_l) })
    let sid_r = right_items.signal().subscribe(fn(_v : Array[String]) -> Unit {
      render_all()
    })
    @core.sub_bag_register(fn() { right_items.signal().remove(sid_r) })

    fn move_items(
      from : @core.Store[Array[String]],
      to : @core.Store[Array[String]],
      sel : Ref[Array[String]],
    ) -> Unit {
      let moving = sel.val
      let remain : Array[String] = []
      for x in from.get() {
        if !contains(moving, x) {
          remain.push(x)
        }
      }
      let merged = to.get().copy()
      for x in moving {
        merged.push(x)
      }
      from.set(remain)
      to.set(merged)
      sel.val = []
    }

    fn mid_btn(to_right : Bool) -> @core.Widget {
      let b = @core.Widget::new()
      b.node.set_width(@yoga.fixed(32.0))
      b.node.set_height(@yoga.fixed(28.0))
      @style.apply(
        b,
        @style.style(color="text_regular", background_color="info_light")
          .hover(background_color="primary_light")
      )
      @style.apply(b, paint_subset(class))
      b.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        let st = @style.style_for(self)
        p.set_fill_color(@style.color_of(st.background_color, @theme.theme_info_light()))
        p.fill_rect(0.0, 0.0, r.w, r.h)
        draw_chevron(p, r.w / 2.0, r.h / 2.0, 4.0, to_right, @style.color_of(st.color, @theme.theme_text_regular()))
      })
      b.cursor = @core.CURSOR_HAND
      b.on_pointer = Some(fn(
        _self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Down => true
          @core.Up => {
            if to_right {
              move_items(left_items, right_items, left_sel)
            } else {
              move_items(right_items, left_items, right_sel)
            }
            false
          }
          _ => false
        }
      })
      b
    }

    w.append_child(left_box)
    w.append_child(mid_btn(true))
    w.append_child(mid_btn(false))
    w.append_child(right_box)
    render_all()
    fold_style(w, @style.empty_style(), class)
    handle(w)
    w
  })
}
