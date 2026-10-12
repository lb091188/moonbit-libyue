// 虚拟列表与虚拟表格：视口固定的行高列表，**只挂载可见区间（±overscan）的行**，
// 滚轮与滚动条都驱动同一个 `ScrollState`（与 `scroll_v` 同款，共用 `scroll_bar`）。
//
// 与「整列重建」的 `table_t` 相比，这里换掉的是「数据多大就挂多少行」：万行级数据
// 只挂十来个控件，命中/绘制/布局都只跟可见行有关。代价是行高必须固定（等距窗口
// 才能从偏移直接算出下标）；非等距行请回 `scroll_v` + 重建式列表。

///|
/// 虚拟列表：`items` 变、窗口滚过一行边界、视口尺寸变化都会重挂可见区间。
/// `row_of(i, item)` 造第 i 行的节点（`i` 是**源下标**，排序/过滤由调用方决定顺序）。
pub fn[T] virt_list(
  items : @core.Store[Array[T]],
  height : Double,
  row_height : Double,
  row_of : (Int, T) -> @core.Node,
  width? : Double = 0.0,
  overscan? : Int = 2,
  rev? : @core.Store[Int],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let rh = if row_height > 0.0 { row_height } else { 1.0 }
  @core.node_of_new(fn(viewport : @core.Widget) -> @core.Widget {
    watch_theme()
    viewport.node.set_flex_direction(@yoga.Column)
    if width > 0.0 {
      viewport.node.set_width(@yoga.fixed(width))
    }
    viewport.node.set_height(@yoga.fixed(height))
    let state = ScrollState::new()
    let inner = @core.Widget::new()
    inner.node.set_flex_direction(@yoga.Column)
    inner.node.set_width(@yoga.percent(100.0))
    inner.node.set_flex_shrink(0.0)
    viewport.append_child(inner)
    // 当前窗口（源下标区间）与窗口重建
    let win_first : Ref[Int] = Ref(-1)
    let win_last : Ref[Int] = Ref(-1)
    let total : Ref[Int] = Ref(0)
    let render_window = fn(force : Bool) -> Unit {
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
        let sp = @core.Widget::new()
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
        let sp = @core.Widget::new()
        sp.node.set_height(@yoga.fixed(rest.to_double() * rh))
        inner.append_child(sp)
      }
      @core.invalidate()
    }

    state.apply.val = fn() -> Unit { render_window(false) }
    viewport.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      // 只同步几何（滚动条比例与夹取吃它），不在绘制里改子控件树
      state.view_h = r.h
      state.content_h = total.val.to_double() * rh
      if state.content_h > state.view_h {
        p.set_stroke_color(@theme.theme_border())
        p.set_line_width(1.0)
        p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      }
    })
    viewport.on_scroll = Some(fn(ev : @core.ScrollEvent) -> Bool {
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
        @core.sub_bag_register(fn() { r.signal().remove(rsid) })
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
    @core.sub_bag_register(fn() { items.signal().remove(sid) })
    viewport.append_child(scroll_bar(state))
    render_window(true)
    handle(viewport)
    viewport
  })
}

///|
/// 虚拟表格（`table_t` 的万行级形态）：表头固定不滚，数据行走 `virt_list`，
/// 单元格画法与 `table_t` 完全一致（同一份 `table_row_widget`）。
pub fn table_v_t(
  columns : Array[TableColumn],
  rows : @core.Store[Array[TableRow]],
  width? : Double = 560.0,
  height? : Double = 360.0,
  row_height? : Double = 32.0,
  selection? : @core.Store[Array[Int]],
  sort? : @core.Store[TableSort],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i : Int, _r : TableRow) -> Unit { () },
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let head_h = 40.0
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
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
    let rev = @core.Store::new(0)
    w.on_draw = Some(fn(
      _s : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
    })
    let head = table_header(
      columns,
      widths,
      sort,
      head_h,
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
      fn(src : Int, row : TableRow) -> @core.Node {
        @core.node_of(table_row_widget(
          columns,
          widths.val,
          row,
          src,
          row_height,
          selection,
          on_row_click,
        ))
      },
      width=width - 2.0,
      rev=rev,
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
/// （与 `scroll_v` 同一套相对定位平移）；「当前组」不是靠滚动位置硬算，而是每帧
/// 布局后读各组控件的矩形反推——组高由内容决定（行数/换行都可能变），读布局结果
/// 比事先累加高度稳。
pub fn sticky_list(
  groups : Array[(String, Array[@core.Node])],
  st : StickyList,
  width? : Double = 0.0,
  height? : Double = 0.0,
  head_h? : Double = 28.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let state = st.scroll
  let hh = head_h
  @core.node_of_new(fn(viewport : @core.Widget) -> @core.Widget {
    watch_theme()
    viewport.node.set_flex_direction(@yoga.Column)
    if width > 0.0 {
      viewport.node.set_width(@yoga.fixed(width))
    }
    if height > 0.0 {
      viewport.node.set_height(@yoga.fixed(height))
    }
    // 内容：整块跟着偏移平移（相对定位偏移只改落位、不改流内占位）
    let content = @core.Widget::new()
    content.node.set_flex_direction(@yoga.Column)
    content.node.set_width(@yoga.percent(100.0))
    content.node.set_position(@yoga.Relative)
    content.node.set_flex_shrink(0.0)
    content.node.set_top(@yoga.fixed(0.0 - state.offset))
    let group_widgets : Array[@core.Widget] = []
    for g in groups {
      let title = g.0
      let rows = g.1
      let gw = @core.Widget::new()
      gw.node.set_flex_direction(@yoga.Column)
      gw.node.set_width(@yoga.percent(100.0))
      // 组标题（滚走的那一条，静态头）
      let head = @core.Widget::new()
      head.node.set_height(@yoga.fixed(hh))
      head.node.set_width(@yoga.percent(100.0))
      head.on_draw = Some(fn(
        _s : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        p.set_fill_color(@theme.theme_fill_zebra())
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
          @theme.theme_text_secondary(),
          align=@text.Start,
          valign=@text.Center,
        )
      })
      gw.append_child(head)
      @core.mount_children(gw, rows)
      content.append_child(gw)
      group_widgets.push(gw)
    }
    viewport.append_child(content)
    // 吸顶悬浮条
    let sticky_bar = @core.Widget::new()
    sticky_bar.node.set_position(@yoga.Absolute)
    sticky_bar.node.set_top(@yoga.fixed(0.0))
    sticky_bar.node.set_left(@yoga.fixed(0.0))
    sticky_bar.node.set_right(@yoga.fixed(0.0))
    sticky_bar.node.set_height(@yoga.fixed(hh))
    sticky_bar.on_draw = Some(fn(
      _s : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_fill_color(@theme.theme_border())
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
        @theme.theme_text_primary(),
        align=@text.Start,
        valign=@text.Center,
      )
    })
    viewport.append_child(sticky_bar)
    // 每帧布局后按「各组的实际矩形」反推当前组
    viewport.on_draw = Some(fn(
      _s : @core.Widget,
      _p : @render.Painter,
      r : @core.Rect,
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
      @core.invalidate()
    }
    viewport.on_scroll = Some(fn(ev : @core.ScrollEvent) -> Bool {
      let before = state.offset
      state.scroll_by(0.0 - ev.dy * 30.0)
      state.offset != before
    })
    viewport.append_child(scroll_bar(state))
    handle(viewport)
    viewport
  })
}
