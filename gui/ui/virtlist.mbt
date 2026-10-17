// 虚拟列表与虚拟表格：视口固定的行高列表，**只挂载可见区间（±overscan）的行**，
// 滚轮与滚动条都驱动同一个 `ScrollState`（与 `scroll_view` 同款，共用 `scroll_bar`）。
//
// 与「整列重建」的 `table` 相比，这里换掉的是「数据多大就挂多少行」：万行级数据
// 只挂十来个控件，命中/绘制/布局都只跟可见行有关。代价是行高必须固定（等距窗口
// 才能从偏移直接算出下标）；非等距行请回 `scroll_view` + 重建式列表。

///|
/// 虚拟列表：`items` 变、窗口滚过一行边界、视口尺寸变化都会重挂可见区间。
/// `row_of(i, item)` 造第 i 行的节点（`i` 是**源下标**，排序/过滤由调用方决定顺序）。
pub fn[T] virt_list(
  items : @base.Store[Array[T]],
  height : Double,
  row_height : Double,
  row_of : (Int, T) -> @widget.Node,
  width? : Double = 0.0,
  overscan? : Int = 2,
  rev? : @base.Store[Int],
  class? : Array[@style.Style] = [],
  handle? : (@widget.Widget) -> Unit = default_handle,
) -> @widget.Node {
  let rh = if row_height > 0.0 { row_height } else { 1.0 }
  @widget.node_of_new(fn(viewport : @widget.Widget) -> @widget.Widget {
    watch_theme()
    let lay = @style.empty_style()
    lay.flex_direction = Some(@yoga.Column)
    if width > 0.0 {
      lay.width = Some(width)
    }
    lay.height = Some(height)
    @style.apply(viewport, @style.merge_all([lay, @style.merge_all(class)]))
    let state = ScrollState::new()
    let inner = @widget.Widget::new()
    inner.node.set_flex_direction(@yoga.Column)
    inner.node.set_width(@yoga.percent(100.0))
    // 整块跟着偏移平移（与 `scroll_view` 同一套相对定位）：上占位只补「窗口第一行
    // 到内容原点」的差额，真偏移量由 top 承担——少了这步，占位会把可见行越推越下，
    // 视口上沿先空、随后整屏空白。
    inner.node.set_position(@yoga.Relative)
    inner.node.set_flex_shrink(0.0)
    inner.node.set_top(@yoga.fixed(0.0 - state.offset))
    viewport.append_child(inner)
    // 当前窗口（源下标区间）与窗口重建
    let win_first : Ref[Int] = Ref(-1)
    let win_last : Ref[Int] = Ref(-1)
    let total : Ref[Int] = Ref(0)
    let render_window = fn(force : Bool) -> Unit {
      // 偏移先落布局：窗口区间没变但偏移在行内变化（半行滚动）时也要跟手
      inner.node.set_top(@yoga.fixed(0.0 - state.offset))
      let count = items.get().length()
      total.val = count
      state.content_h = count.to_double() * rh
      // 视口高优先用已同步的真实值；首帧还没同步过就用声明的 height
      // （on_draw 里不能重建窗口——绘制遍历正在读 kids，改动子控件会踩迭代）
      let vh = if state.view_h > 0.0 { state.view_h } else { height }
      let first = ((state.offset / rh).to_int() - overscan).max(0)
      let last = (((state.offset + vh) / rh).ceil().to_int() + overscan).min(count)
      if !force && first == win_first.val && last == win_last.val {
        return
      }
      win_first.val = first
      win_last.val = last
      inner.clear_children()
      // 上占位：让第一行落在正确的滚动位置
      if first > 0 {
        let sp = @widget.Widget::new()
        sp.node.set_height(@yoga.fixed(first.to_double() * rh))
        inner.append_child(sp)
      }
      let data = items.get()
      for i = first; i < last; i = i + 1 {
        let node = row_of(i, data[i])
        let _ = node.mount_into(inner)
      }
      // 下占位：撑起剩余高度（滚动条比例与越界夹取吃 content_h，这里只是让
      // 内层高度与内容一致，避免「挂了几行就只高几行」）
      let rest = count - last
      if rest > 0 {
        let sp = @widget.Widget::new()
        sp.node.set_height(@yoga.fixed(rest.to_double() * rh))
        inner.append_child(sp)
      }
      @widget.invalidate()
    }

    state.apply.val = fn() -> Unit { render_window(false) }
    @style.apply(
      viewport,
      @style.merge_all([
        @style.style(border_color="border", border_width=1.0),
        paint_subset(class),
      ]),
    )
    viewport.on_draw = Some(fn(
      self : @widget.Widget,
      p : @render.Painter,
      r : @base.Rect,
    ) -> Unit {
      // 只同步几何（滚动条比例与夹取吃它），不在绘制里改子控件树
      state.view_h = r.h
      state.content_h = total.val.to_double() * rh
      if state.content_h > state.view_h {
        let st = @style.style_for(self)
                p.set_stroke_color(@style.color_of(st.border_color, @theme.theme_border()))
        p.set_line_width(@style.number_of(st.border_width, 1.0))
        p.stroke_rect(0.0, 0.0, r.w, r.h)
      }
    })
    viewport.on_scroll = Some(fn(ev : @widget.ScrollEvent) -> Bool {
      let before = state.offset
      state.scroll_by(0.0 - ev.dy * 30.0)
      state.offset != before
    })
    match rev {
      Some(r) => {
        // 外部改列宽等「行内容要重建」的变更：给一个 rev，变了就整窗重挂
        let rsid = r.signal().subscribe(fn(_v : Int) -> Unit {
          render_window(true)
        })
        @base.sub_bag_register(fn() { r.signal().remove(rsid) })
      }
      None => ()
    }
    let sid = items.signal().subscribe(fn(_v : Array[T]) -> Unit {
      // 数据变短时先把偏移拉回上界，再重挂窗口
      state.content_h = items.get().length().to_double() * rh
      if state.offset > state.max() {
        state.set_offset(state.max())
      } else {
        render_window(true)
      }
    })
    @base.sub_bag_register(fn() { items.signal().remove(sid) })
    viewport.append_child(scroll_bar(state))
    render_window(true)
    handle(viewport)
    viewport
  })
}

///|
/// 虚拟表格（`table` 的万行级形态）：表头固定不滚，数据行走 `virt_list`，
/// 单元格画法与 `table` 完全一致（同一份 `table_row_widget`）。
pub fn table_v(
  columns : Array[TableColumn],
  rows : @base.Store[Array[TableRow]],
  width? : Double = 560.0,
  height? : Double = 360.0,
  row_height? : Double = 32.0,
  selection? : @base.Store[Array[Int]],
  sort? : @base.Store[TableSort],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i : Int, _r : TableRow) -> Unit { () },
  class? : Array[@style.Style] = [],
  handle? : (@widget.Widget) -> Unit = default_handle,
) -> @widget.Node {
  let head_h = 40.0
  @widget.node_of_new(fn(w : @widget.Widget) -> @widget.Widget {
    watch_theme()
    match selection {
      Some(s) => follow_store(s)
      None => ()
    }
    match sort {
      Some(s) => follow_store(s)
      None => ()
    }

    w.node.set_flex_direction(@yoga.Column)
    // 表头宽度扣掉滚动条（8px）与左右边框：数据行的列宽与表头一致
    w.node.set_width(@yoga.fixed(width))
    let widths : Ref[Array[Double]] = Ref(table_widths(columns, width - 10.0))
    let rev = @base.Store::new(0)
    @style.apply(
      w,
      @style.merge_all([
        @style.style(background_color="bg_panel", border_color="border", border_width=1.0),
        @style.merge_all(class),
      ]),
    )
    w.on_draw = Some(fn(
      self : @widget.Widget,
      p : @render.Painter,
      r : @base.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      p.set_fill_color(@style.color_of(st.background_color, @theme.theme_bg_panel()))
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_stroke_color(@style.color_of(st.border_color, @theme.theme_border()))
      p.set_line_width(@style.number_of(st.border_width, 1.0))
      p.stroke_rect(0.0, 0.0, r.w, r.h)
    })
    let head = table_header(
      columns,
      widths,
      sort,
      head_h,
      skin=paint_subset(class),
      on_resize=Some(fn(_j : Int, _nw : Double) -> Unit {
        // 虚拟表只管表头两格；数据行靠 rev 整窗重挂（可见行才十来个，重建便宜）
        rev.set(rev.get() + 1)
      }),
    )
    head.node.set_flex_shrink(0.0)
    w.append_child(head)
    let list = virt_list(
      rows,
      height,
      row_height,
      fn(src : Int, row : TableRow) -> @widget.Node {
        @widget.node_of(table_row_widget(
          columns,
          widths.val,
          row,
          src,
          row_height,
          selection,
          on_row_click,
          skin=paint_subset(class),
        ))
      },
      width=width - 2.0,
      rev=rev,
      class=class,
    )
    let _ = list.mount_into(w)
    handle(w)
    w
  })
}

///|
/// 粘性列表的状态：滚动偏移 + 当前吸顶的分组（组件在每帧布局后写入，
/// 调用方与测试直接读 `cur_group`）。
pub(all) struct StickyList {
  scroll : ScrollState
  mut cur_group : String
  mut cur_start : Double
}

///|
pub fn StickyList::new() -> StickyList {
  { scroll: ScrollState::new(), cur_group: "", cur_start: 0.0 }
}

///|
/// 粘性列表：分组标题在滚动时吸顶（悬浮在视口顶部的那一条始终显示「当前组」的
/// 标题，滚过组边界就换文字），组内行照常滚走。
///
/// 实现口径：吸顶标题是视口里的一个**绝对定位悬浮条**，内容整块跟着偏移走
/// （与 `scroll_view` 同一套相对定位平移）；「当前组」不是靠滚动位置硬算，而是每帧
/// 布局后读各组控件的矩形反推——组高由内容决定（行数/换行都可能变），读布局结果
/// 比事先累加高度稳。
pub fn sticky_list(
  groups : Array[(String, Array[@widget.Node])],
  st : StickyList,
  width? : Double = 0.0,
  height? : Double = 0.0,
  head_h? : Double = 28.0,
  class? : Array[@style.Style] = [],
  handle? : (@widget.Widget) -> Unit = default_handle,
) -> @widget.Node {
  let state = st.scroll
  let hh = head_h
  @widget.node_of_new(fn(viewport : @widget.Widget) -> @widget.Widget {
    watch_theme()
    let lay = @style.empty_style()
    lay.flex_direction = Some(@yoga.Column)
    if width > 0.0 {
      lay.width = Some(width)
    }
    if height > 0.0 {
      lay.height = Some(height)
    }
    @style.apply(viewport, @style.merge_all([lay, @style.merge_all(class)]))
    // 内容：整块跟着偏移平移（相对定位偏移只改落位、不改流内占位）
    let content = @widget.Widget::new()
    content.node.set_flex_direction(@yoga.Column)
    content.node.set_width(@yoga.percent(100.0))
    content.node.set_position(@yoga.Relative)
    content.node.set_flex_shrink(0.0)
    content.node.set_top(@yoga.fixed(0.0 - state.offset))
    let group_widgets : Array[@widget.Widget] = []
    for g in groups {
      let title = g.0
      let rows = g.1
      let gw = @widget.Widget::new()
      gw.node.set_flex_direction(@yoga.Column)
      gw.node.set_width(@yoga.percent(100.0))
      // 组标题（滚走的那一条，静态头）
      let head = @widget.Widget::new()
      head.node.set_height(@yoga.fixed(hh))
      head.node.set_width(@yoga.percent(100.0))
      @style.apply(
        head,
        @style.merge_all([
          @style.style(background_color="fill_zebra", color="text_secondary"),
          paint_subset(class),
        ]),
      )
      head.on_draw = Some(fn(
        self : @widget.Widget,
        p : @render.Painter,
        r : @base.Rect,
      ) -> Unit {
        let hs = @style.style_for(self)
        p.set_fill_color(@style.color_of(hs.background_color, @theme.theme_fill_zebra()))
        p.fill_rect(0.0, 0.0, r.w, r.h)
        let f = @text.Font::new("", 12.0, weight=@text.SemiBold)
        let _ = @text.draw_box_at(
          p,
          8.0,
          0.0,
          (r.w - 12.0).max(1.0),
          r.h,
          title,
          f,
          @style.color_of(hs.color, @theme.theme_text_secondary()),
          align=@text.Start,
          valign=@text.Center,
        )
      })
      gw.append_child(head)
      @widget.mount_children(gw, rows)
      content.append_child(gw)
      group_widgets.push(gw)
    }
    viewport.append_child(content)
    // 吸顶悬浮条
    let sticky_bar = @widget.Widget::new()
    sticky_bar.node.set_position(@yoga.Absolute)
    sticky_bar.node.set_top(@yoga.fixed(0.0))
    sticky_bar.node.set_left(@yoga.fixed(0.0))
    sticky_bar.node.set_right(@yoga.fixed(0.0))
    sticky_bar.node.set_height(@yoga.fixed(hh))
    @style.apply(
      sticky_bar,
      @style.merge_all([
        @style.style(background_color="bg_panel", border_color="border", color="text_primary"),
        paint_subset(class),
      ]),
    )
    sticky_bar.on_draw = Some(fn(
      self : @widget.Widget,
      p : @render.Painter,
      r : @base.Rect,
    ) -> Unit {
      let bs = @style.style_for(self)
      p.set_fill_color(@style.color_of(bs.background_color, @theme.theme_bg_panel()))
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_fill_color(@style.color_of(bs.border_color, @theme.theme_border()))
      p.fill_rect(0.0, r.h - 1.0, r.w, 1.0)
      let f = @text.Font::new("", 12.0, weight=@text.SemiBold)
      let _ = @text.draw_box_at(
        p,
        8.0,
        0.0,
        (r.w - 12.0).max(1.0),
        r.h,
        st.cur_group,
        f,
        @style.color_of(bs.color, @theme.theme_text_primary()),
        align=@text.Start,
        valign=@text.Center,
      )
    })
    viewport.append_child(sticky_bar)
    // 每帧布局后按「各组的实际矩形」反推当前组
    viewport.on_draw = Some(fn(
      _s : @widget.Widget,
      _p : @render.Painter,
      r : @base.Rect,
    ) -> Unit {
      st.scroll.view_h = r.h
      st.scroll.content_h = content.rect.h
      let top = state.offset
      let mut idx = 0
      for i = 0; i < group_widgets.length(); i = i + 1 {
        let gy = group_widgets[i].rect.y - content.rect.y
        if gy <= top + 0.5 {
          idx = i
        }
      }
      if group_widgets.length() > 0 {
        st.cur_group = groups[idx].0
        st.cur_start = group_widgets[idx].rect.y - content.rect.y
      }
    })
    st.scroll.apply.val = fn() -> Unit {
      content.node.set_top(@yoga.fixed(0.0 - state.offset))
      @widget.invalidate()
    }
    viewport.on_scroll = Some(fn(ev : @widget.ScrollEvent) -> Bool {
      let before = state.offset
      state.scroll_by(0.0 - ev.dy * 30.0)
      state.offset != before
    })
    viewport.append_child(scroll_bar(state))
    handle(viewport)
    viewport
  })
}
