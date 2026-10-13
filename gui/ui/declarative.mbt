// 声明式层 L1 构造器：让页面与示例「调用点不变、只换实现」的那一层。
//
// 新栈的组件本身就返回 `@core.Node`，所以与组件**同名**的构造器（`label` /
// `button` / `input` / `checkbox` / `container` / `group` / `separator` /
// `image` / `icon` / `radio_group` / `slider` / `progress`）不再另包一层——
// 直接用组件即可。这里只补三类东西：
// ① 与 master 名字不同的构造器（`vbox`/`hbox`/`text_edit`/`picker`/`scroll`/
//    `tab`/`date_picker`），旧调用点原样跑在新栈上；
// ② 声明式入口（`mount_window`）与文本绑定（`bind_label`/`bind`）；
// ③ `hover_group`（悬停组）。
//
// 两条与 master 的机制差（记档）：
// - `hover_group` 在旧链路靠**全局指针轮询**（GTK 指针事件不冒泡，子控件的
//   事件窗口会独占，祖先容器收不到 enter）；本栈宿主的悬停态本来就是父链语义
//   （指针在子项上时父项也算悬停），所以这里没有定时器、没有轮询，读 `hovered` 即可。
// - `overlay_scroll`（旧链路的悬浮滚动条）在本栈就是 `scroll_view`：滚动条一直是
//   视口的绝对定位子控件、覆盖在内容之上，不需要第二套形态。
// - `cursor_group` 在旧链路要把光标递归设到组根与**全部子孙**（GTK 光标按原生
//   窗口生效，只设容器盖不住有独立窗口的子件）；本栈光标是窗口级的一层，宿主按
//   悬停路径取「最深的那个请求」，所以组只设自己一处，子孙没提请求时自然回退到它。

///|
/// 垂直布局容器（`container` 的 Column 形态）。
pub fn col(
  children : Array[@core.Node],
  row_gap? : Double = 0.0,
  padding? : Double = 0.0,
  width? : Double = 0.0,
  height? : Double = 0.0,
  grow? : Double = 0.0,
  bg? : String = "",
  border? : String = "",
  align_items? : @yoga.AlignItems = @yoga.AlignItems::Stretch,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  view(
    children,
    direction=@yoga.Column,
    row_gap=row_gap,
    padding=padding,
    width=width,
    height=height,
    grow=grow,
    bg=bg,
    border=border,
    align_items=align_items,
    handle=handle,
  )
}

///|
/// 水平布局容器（`container` 的 Row 形态）。
pub fn row(
  children : Array[@core.Node],
  column_gap? : Double = 0.0,
  padding? : Double = 0.0,
  width? : Double = 0.0,
  height? : Double = 0.0,
  grow? : Double = 0.0,
  bg? : String = "",
  border? : String = "",
  align_items? : @yoga.AlignItems = @yoga.AlignItems::Center,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  view(
    children,
    direction=@yoga.Row,
    column_gap=column_gap,
    padding=padding,
    width=width,
    height=height,
    grow=grow,
    bg=bg,
    border=border,
    align_items=align_items,
    handle=handle,
  )
}

///|
/// §2 合并:`text_edit` 就是真身(原声明式包装删除,调用点直接用 `@ui.textarea`)。

///|
/// 下拉选择器（`select_t` 的旧名）。
pub fn picker(
  options : Array[String],
  value : @core.Store[String],
  on_change? : (String) -> Unit = fn(_s : String) -> Unit { () },
  clearable? : Bool = false,
  placeholder? : String = "",
  width? : Double = 200.0,
  focus_id? : Int = 0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  select_t(
    options,
    value,
    on_change=on_change,
    clearable=clearable,
    placeholder=placeholder,
    width=width,
    focus_id=focus_id,
    handle=handle,
  )
}

///|
/// §2 合并:`scroll` 旧包装删除——滚动容器唯一入口就是 `ui/scroll.mbt` 的 `scroll_view`。

///|
/// 页签（`tabs` 的旧名）：`pages` 是 (标题, 内容)。
pub fn tab(
  pages : Array[(String, @core.Node)],
  selected? : @core.Store[Int],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  tabs(pages, selected?, handle=handle)
}

///|
/// §2 合并:`date_picker` 就是真身(原声明式包装删除,调用点直接用 `@ui.date_picker`)。

///|
/// 声明式文本绑定：初值 `f(store.get())`，之后每次 `set` 就地更新文本并重测
/// （只重算这一条链，不重建子树）。文本恒单行——旧链路那条「默认自动换行会在
/// hbox 里被压成两行」的坑在本栈同样成立，故 `wrap=false`。
pub fn[A] bind_label(
  store : @core.Store[A],
  f : (A) -> String,
  size? : Double = 13.0,
  color? : String = "",
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  bind(
    store.signal(),
    f,
    size=size,
    color=color,
    handle=handle,
  )
}

///|
/// 声明式文本绑定（信号版）：源信号或 `computed` 派生信号都能直接喂。
pub fn[A] bind(
  sig : @core.Signal[A],
  f : (A) -> String,
  size? : Double = 13.0,
  color? : String = "",
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let src = text_source(f(sig.get()), size=size, color=color, wrap=false)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    attach_text_measure(w, src)
    w.on_draw = Some(fn(
      _s : @core.Widget,
      p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let _ = draw_text_in(w, p, src)
    })
    let sid = sig.subscribe(fn(v : A) -> Unit { relabel(w, src, f(v)) })
    @core.sub_bag_register(fn() { sig.remove(sid) })
    handle(w)
    w
  })
}

///|
/// 悬停组：组内任意位置（含全部子控件）悬停即整组进入悬停态并换底色，
/// 点击（按下后松开仍在组内）触发 `on_click`。
///
/// 旧链路要靠全局指针轮询才做得到（GTK 的指针事件不冒泡，子控件的事件窗口
/// 独占事件，祖先收不到 enter）；本栈宿主的悬停态本身就是父链语义，
/// 所以这里既不排定时器也不查指针。
pub fn hover_group(
  children : Array[@core.Node],
  on_click? : () -> Unit = fn() -> Unit { () },
  padding? : Double = 8.0,
  row_gap? : Double = 4.0,
  width? : Double = 0.0,
  bg? : String = "",
  hover_bg? : String = "",
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let base_bg = bg
  let lit_bg = hover_bg
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(@yoga.Column)
    w.node.set_align_items(@yoga.AlignItems::FlexStart)
    if row_gap > 0.0 {
      w.node.set_gap(row_gap, 0.0)
    }
    if padding > 0.0 {
      w.set_padding_all(padding)
    }
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    }
    w.cursor = @core.CURSOR_HAND
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let fill = if self.hovered {
        if lit_bg.length() > 0 { lit_bg } else { @theme.theme_fill_hover() }
      } else if base_bg.length() > 0 {
        base_bg
      } else {
        @theme.theme_bg_panel()
      }
      p.set_fill_color(fill)
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
    })
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => true
        @core.Up => {
          if ev.x >= 0.0 && ev.x <= self.rect.w && ev.y >= 0.0 && ev.y <= self.rect.h {
            on_click()
          }
          false
        }
        _ => false
      }
    })
    @core.mount_children(w, children)
    handle(w)
    w
  })
}

///|
/// 声明一棵 UI 树并装进窗口：建宿主（窗口 + 事件循环 + 浮层图层 + 输入法通道
/// 都在 `App::new` 里就位）、挂载子节点、把宿主交给调用方 `run`。
/// 无显示服务时返回 None（调用方打印提示即可，与 `App::new` 同口径）。
///
/// 与 master 的一条差（记档）：旧链路的 `mount_window` 还管 `center`/`on_close`
/// （原生窗口有这两条通道）；本栈的窗口居中由 WM 决定、关闭只把宿主循环停下，
/// 故不提供这两个参数，退出后的收尾写在调用方 `run()` 之后。
pub fn mount_window(
  children : Array[@core.Node],
  title? : String = "",
  width? : Int = 800,
  height? : Int = 600,
  handle? : (@core.App) -> Unit = fn(_a : @core.App) -> Unit { () },
) -> @core.App? {
  match @core.App::new(width, height, title) {
    None => None
    Some(app) => {
      app.mount(children)
      handle(app)
      Some(app)
    }
  }
}

///|
/// 光标组：组内任意位置都用 `cursor` 指定的形状（默认手型）。
/// 宿主取的是悬停路径上**最深的那个非零请求**，所以组内某个子件自己提了形状
/// （比如卡片里那颗按钮）时以它为准，其余位置回退到组的形状——不需要像旧链路
/// 那样把光标递归设进每个子孙。
pub fn cursor_group(
  children : Array[@core.Node],
  direction? : @yoga.FlexDirection = @yoga.Column,
  row_gap? : Double = 0.0,
  column_gap? : Double = 0.0,
  padding? : Double = 0.0,
  width? : Double = 0.0,
  cursor? : Int = @core.CURSOR_HAND,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  view(
    children,
    direction=direction,
    row_gap=row_gap,
    column_gap=column_gap,
    padding=padding,
    width=width,
    handle=fn(w : @core.Widget) -> Unit {
      w.cursor = cursor
      handle(w)
    },
  )
}
