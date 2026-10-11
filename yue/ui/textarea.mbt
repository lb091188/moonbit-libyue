// 多行输入框（textarea）：换行布局 + 垂直滚动 + 与单行 `entry` 同源的编辑语义。
//
// 文本权威仍是 `@input.Editor`（组件不另存一份），`Store[String]` 是它的对外投影；
// 与宿主的接缝还是那五个回调（`on_key`/`on_commit`/`on_preedit`/`im_context`/
// `im_cursor`）。多行比单行多的只有两件事：**显示行**（按 `\n` 断行后再按盒宽折行）
// 与**垂直滚动**（复用 `scroll.mbt` 的 `ScrollState` 与滚动条控件）。
//
// 滚动偏移不进布局：显示行是本控件自己画的一层文字，不是子控件，所以平移发生在
// 绘制期（`y = 行序 × 行高 − 偏移`），滚动条则是视口的绝对定位子控件（与滚动容器
// 同一理由：压在内容之上才吃得到命中）。

///|
/// 一行显示行：`start`/`end` 是全文的字节下标（`end` 不含行尾换行符），
/// `width` 是该行的自然宽度（画选区与命中换算都用它）。
pub(all) struct TextLine {
  start : Int
  end : Int
  width : Double
}

///|
/// 折行断点单位（纯函数）：空格连续成一段、拉丁词（字母数字下划线）连续成一段、
/// 其余 ASCII 标点连续成一段、非 ASCII 码点各自一段（中日韩因此可逐字断行）。
/// 段是「不可拆的最小块」，断行只发生在段边界。
pub fn wrap_units(text : String, from : Int, to : Int) -> Array[(Int, Int)] {
  let b = @utf8.encode(text)
  let n = b.length()
  let lo = if from < 0 { 0 } else if from > n { n } else { from }
  let hi = if to > n { n } else if to < lo { lo } else { to }
  let units : Array[(Int, Int)] = []
  let mut i = lo
  while i < hi {
    let v = b[i].to_int()
    let is_space = v == 0x20
    let is_word = (v >= 48 && v <= 57) || (v >= 65 && v <= 90) || (v >= 97 && v <= 122) || v == 95
    let mut j = i + 1
    if v >= 0x80 {
      // 非 ASCII：一个码点即一段
      j = i + 1
      while j < hi && (b[j].to_int() & 0xc0) == 0x80 {
        j = j + 1
      }
    } else {
      let mut go = true
      while go && j < hi {
        let c = b[j].to_int()
        let same = if is_space {
          c == 0x20
        } else if is_word {
          (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
        } else {
          c >= 0x21 && c <= 0x7e && !((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95)
        }
        if same {
          j = j + 1
        } else {
          go = false
        }
      }
    }
    units.push((i, j))
    i = j
  }
  units
}

///|
/// 取字节下标 `[from,to)` 的子串（调用方保证落在码点边界；越界由切片夹住）。
fn byte_slice(text : String, from : Int, to : Int) -> String {
  if to <= from {
    ""
  } else {
    @utf8.decode_lossy(@utf8.encode(text)[from:to])
  }
}

///|
/// 一行文本的自然宽（测量失败按 0）。
fn seg_width(text : String, from : Int, to : Int, font : @text.Font) -> Double {
  if to <= from {
    0.0
  } else {
    match @text.measure_font(byte_slice(text, from, to), font) {
      Some(m) => m.width.to_double()
      None => 0.0
    }
  }
}

///|
/// 显示行布局（纯函数）：先按 `\n` 切逻辑行，再把每行按 `width` 贪心折行。
/// 空文本也给一行（插入点要有家）；单个断点段比一行还宽时**不拆词**（宁可溢出，
/// 与 CSS 的 `overflow-wrap: normal` 同口径）。
pub fn layout_lines(text : String, width : Double, font : @text.Font) -> Array[TextLine] {
  let b = @utf8.encode(text)
  let n = b.length()
  let avail = if width > 1.0 { width } else { 1.0 }
  let lines : Array[TextLine] = []
  let mut lo = 0
  let mut go = true
  while go {
    // 找这一逻辑行的末尾（下一个换行符之前）
    let mut k = lo
    let mut nl = -1
    while k < n {
      if b[k].to_int() == 0x0a {
        nl = k
        k = n
      } else {
        k = k + 1
      }
    }
    let to = if nl < 0 { n } else { nl }
    let units = wrap_units(text, lo, to)
    let mut start = lo
    let mut cur = 0.0
    for u in units {
      let uw = seg_width(text, u.0, u.1, font)
      if cur + uw > avail && u.0 > start {
        lines.push({ start, end: u.0, width: cur })
        // 断行处不留行首空格：跳过被折断的那一段空格
        let mut s = u.0
        while s < u.1 && b[s].to_int() == 0x20 {
          s = s + 1
        }
        start = s
        cur = seg_width(text, s, u.1, font)
      } else {
        cur = cur + uw
      }
    }
    lines.push({ start, end: to, width: cur })
    if nl < 0 {
      go = false
      lo = n
    } else {
      lo = nl + 1
      if lo > n {
        go = false
      }
    }
  }
  lines
}

///|
/// 字节下标落在第几行（越界夹到首末行）。
pub fn line_of_caret(lines : Array[TextLine], at : Int) -> Int {
  let n = lines.length()
  if n == 0 {
    0
  } else {
    let mut i = 0
    while i < n {
      if at <= lines[i].end {
        return i
      }
      i = i + 1
    }
    n - 1
  }
}

///|
/// 多行输入框。`rows` 只决定初始高度（每行 `row_height`）；`height` 传正数按它。
/// 键入、选区、拖动选词、undo/redo、Ctrl+A/C/V（内核内部剪贴板）、IME commit 与
/// preedit 内联与单行框同源；换行键插入 `\n`，上下键按**显示行**移动（记住起算 x，
/// 短行移动后仍回到该 x），Home/End 走行首行尾（带 Ctrl 仍是全文首末）。
pub fn textarea(
  store : @core.Store[String],
  placeholder? : String = "",
  rows? : Int = 3,
  width? : Double = 260.0,
  height? : Double = 0.0,
  size? : Double = 13.0,
  family? : String = "",
  read_only? : Bool = false,
  focus_id? : Int = 0,
  caret_on? : () -> Bool = fn() -> Bool { true },
  on_change? : (String) -> Unit = fn(_s : String) -> Unit { () },
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let ed = @input.Editor::new()
  attach_system_clipboard(ed)
  let _ = ed.insert_text(store.get())
  let font = @text.Font::new(family, size)
  let pad = 4.0
  let ro = read_only
  let ph = placeholder
  let change_cb = on_change
  let line_h = (@text.line_height_font(font).unwrap_or(18).to_double() + 2.0).max(14.0)
  let box_h = if height > 0.0 { height } else { line_h * rows.to_double() + pad * 2.0 }
  let st = ScrollState::new()
  // 布局缓存：文本或盒宽变了才重排显示行（每帧都重折一遍是白烧）
  let cache : Ref[(String, Double, Array[TextLine])] = Ref(("", -1.0, []))
  let lines_of = fn(text : String, w : Double) -> Array[TextLine] {
    let key = cache.val
    if key.0 == text && key.1 == w {
      key.2
    } else {
      let ls = layout_lines(text, w - pad * 2.0, font)
      cache.val = (text, w, ls)
      ls
    }
  }

  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let off = enabled_cell(None, false)
    let last_down = Ref(-1000000L)
    let last_xy = Ref((-1000.0, -1000.0))
    let dragging = Ref(false)
    let anchor = Ref(0)
    let pref_x : Ref[Double] = Ref(-1.0)
    w.focus_id = focus_id
    w.cursor = @core.CURSOR_TEXT
    w.node.set_width(@yoga.fixed(width))
    w.node.set_height(@yoga.fixed(box_h))
    w.node.set_flex_shrink(0.0)
    let text_of = fn() -> String { ed.get_text() }
    let caret_x_in = fn(lines : Array[TextLine], at : Int) -> Double {
      let i = line_of_caret(lines, at)
      if i < lines.length() {
        pad + seg_width(text_of(), lines[i].start, at, font)
      } else {
        pad
      }
    }
    let caret_y_in = fn(lines : Array[TextLine], at : Int) -> Double {
      pad + line_of_caret(lines, at).to_double() * line_h - st.offset
    }
    // 把插入点滚进可视区（键入、点击、上下移动后都调）
    let ensure_visible = fn(lines : Array[TextLine]) -> Unit {
      let i = line_of_caret(lines, ed.caret_pos())
      let top = i.to_double() * line_h
      let view = st.view_h
      if top < st.offset {
        st.set_offset(top)
      } else if top + line_h > st.offset + view {
        st.set_offset(top + line_h - view)
      }
    }
    // 像素 → 字节：先按 y 定行，再在行内逐段量到不超过 x 的最右边界
    let byte_at = fn(lines : Array[TextLine], x : Double, y : Double) -> Int {
      let t = text_of()
      if lines.length() == 0 {
        return 0
      }
      let i = (((y - pad + st.offset) / line_h).floor().to_int()).clamp(min=0, max=lines.length() - 1)
      let ln = lines[i]
      let b = @utf8.encode(t)
      let n = b.length()
      let mut best = ln.start
      let mut k = ln.start
      while k < ln.end {
        let next = if k + 1 < n && (b[k + 1].to_int() & 0xc0) == 0x80 {
          let mut j = k + 1
          while j < ln.end && (b[j].to_int() & 0xc0) == 0x80 {
            j = j + 1
          }
          j
        } else {
          k + 1
        }
        if seg_width(t, ln.start, next, font) + pad <= x {
          best = next
        }
        if next <= k {
          k = ln.end
        } else {
          k = next
        }
      }
      best
    }
    let push = fn() -> Unit {
      let t = ed.get_text()
      store.set(t)
      change_cb(t)
    }

    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let t = text_of()
      let lines = lines_of(t, r.w)
      // 几何抄进状态（滚动条比例与夹取都用它）：内容高 = 行数 × 行高
      st.view_h = (r.h - pad).max(1.0)
      st.content_h = lines.length().to_double() * line_h + pad * 2.0
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      let sel = ed.selection()
      let caret = ed.caret_pos()
      for i = 0; i < lines.length(); i = i + 1 {
        let ln = lines[i]
        let y = pad + i.to_double() * line_h - st.offset
        if y + line_h < 0.0 || y > r.h {
          continue
        }
        match sel {
          Some((s, e)) => {
            let a = s.max(ln.start)
            let b = e.min(ln.end)
            if b > a {
              p.set_fill_color(@theme.theme_primary_light())
              p.fill_rect(
                pad + seg_width(t, ln.start, a, font),
                y,
                seg_width(t, a, b, font).max(1.0),
                line_h,
              )
            }
          }
          None => ()
        }
        if t.length() == 0 && i == 0 && ph.length() > 0 {
          let _ = @text.draw_at(p, pad, y, ph, font, @theme.theme_text_secondary())
        } else if ln.end > ln.start {
          let _ = @text.draw_at(
            p,
            pad,
            y,
            byte_slice(t, ln.start, ln.end),
            font,
            if off.off { @theme.theme_text_secondary() } else { @theme.theme_text_regular() },
          )
        }
      }
      // preedit 画在插入点所在行的插入点处（组合串只此一份，内核不并入文本）
      let pe = ed.preedit_text()
      let cy = caret_y_in(lines, caret)
      let cx = caret_x_in(lines, caret)
      if pe.length() > 0 {
        let _ = @text.draw_at(p, cx, cy, pe, font, @theme.theme_warning())
        let pw = seg_width(pe, 0, pe.length(), font)
        p.set_fill_color(@theme.theme_warning())
        p.fill_rect(cx, cy + line_h - 2.0, pw, 1.0)
      }
      if self.focused && !off.off && caret_on() {
        p.set_fill_color(@theme.theme_text_primary())
        p.fill_rect(cx, cy, 1.0, line_h)
      }
      p.set_stroke_color(if self.focused {
        @theme.theme_primary()
      } else {
        @theme.theme_border()
      })
      p.set_line_width(1.0)
      p.stroke_rect(0.0, 0.0, r.w, r.h)
    })
    w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press || off.off {
        return false
      }
      let shift = (ev.mods & @core.MOD_SHIFT) != 0
      let ctrl = (ev.mods & @core.MOD_CTRL) != 0
      let t = text_of()
      let lines = lines_of(t, w.rect.w)
      if ev.keysym == @core.KS_RETURN {
        if ro {
          return false
        }
        let _ = ed.insert_text("\n")
        pref_x.val = -1.0
        push()
        ensure_visible(lines_of(ed.get_text(), w.rect.w))
        @core.invalidate()
        return true
      }
      if ev.keysym == @core.KS_UP || ev.keysym == @core.KS_DOWN {
        let caret = ed.caret_pos()
        let i = line_of_caret(lines, caret)
        let x = if pref_x.val >= 0.0 {
          pref_x.val
        } else {
          caret_x_in(lines, caret)
        }
        let j = if ev.keysym == @core.KS_UP { i - 1 } else { i + 1 }
        if j < 0 || j >= lines.length() {
          pref_x.val = -1.0
          return false
        }
        let ln = lines[j]
        let mut at = ln.start
        while at < ln.end && seg_width(t, ln.start, at + 1, font) + pad <= x {
          at = at + 1
        }
        // 逐字节推进可能停在码点中间：退回到码点起点（at 可能等于文本末尾，
        // 那里没有字节可读）
        let bs = @utf8.encode(t)
        let n = bs.length()
        while at > ln.start && at < n && (bs[at].to_int() & 0xc0) == 0x80 {
          at = at - 1
        }
        pref_x.val = x
        if shift {
          let a = match ed.selection() {
            Some((s, _)) => s
            None => caret
          }
          ed.select_range(a, at)
        } else {
          ed.select_range(at, at)
        }
        anchor.val = at
        ensure_visible(lines)
        @core.invalidate()
        return true
      }
      if !ctrl && (ev.keysym == @core.KS_HOME || ev.keysym == @core.KS_END) {
        let caret = ed.caret_pos()
        let ln = lines[line_of_caret(lines, caret)]
        let at = if ev.keysym == @core.KS_HOME { ln.start } else { ln.end }
        pref_x.val = -1.0
        if shift {
          let a = match ed.selection() {
            Some((s, _)) => s
            None => caret
          }
          ed.select_range(a, at)
        } else {
          ed.select_range(at, at)
        }
        ensure_visible(lines)
        @core.invalidate()
        return true
      }
      let editing = ev.keysym == @core.KS_BACKSPACE || ev.keysym == @core.KS_DELETE
      let nav = ctrl || (ev.keysym >= 65360 && ev.keysym <= 65367) || ev.keysym == @core.KS_TAB
      if ro && (editing || !nav) {
        return false
      }
      let before = ed.get_text()
      let handled = ed.handle_key(ev.keysym, ev.mods)
      if handled {
        pref_x.val = -1.0
        if ed.get_text() != before {
          push()
        }
        ensure_visible(lines_of(ed.get_text(), w.rect.w))
        @core.invalidate()
      }
      handled
    })
    w.on_commit = Some(fn(t : String) -> Bool {
      let _ = ed.insert_text(t)
      push()
      ensure_visible(lines_of(ed.get_text(), w.rect.w))
      @core.invalidate()
      true
    })
    w.on_preedit = Some(fn(t : String, _caret : Int) -> Unit {
      ed.set_preedit(t)
      @core.invalidate()
    })
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => {
          let lines = lines_of(text_of(), self.rect.w)
          let now = @core.now_ms()
          let dbl = (now - last_down.val) < 400L &&
            (ev.x - last_xy.val.0).abs() < 4.0 && (ev.y - last_xy.val.1).abs() < 4.0
          last_down.val = now
          last_xy.val = (ev.x, ev.y)
          dragging.val = true
          pref_x.val = -1.0
          let at = byte_at(lines, ev.x, ev.y)
          if dbl {
            let (s, e) = word_range(text_of(), at)
            ed.select_range(s, e)
          } else {
            ed.select_range(at, at)
            anchor.val = at
          }
          @core.invalidate()
          true
        }
        @core.Move => {
          if dragging.val {
            let lines = lines_of(text_of(), self.rect.w)
            ed.select_range(anchor.val, byte_at(lines, ev.x, ev.y))
            @core.invalidate()
          }
          dragging.val
        }
        @core.Up => {
          dragging.val = false
          false
        }
        @core.Leave => false
      }
    })
    w.on_scroll = Some(fn(ev : @core.ScrollEvent) -> Bool {
      let before = st.offset
      st.scroll_by(0.0 - ev.dy * line_h * 3.0)
      st.offset != before
    })
    w.im_context = Some(fn() -> (String, Int)? {
      Some((ed.get_text(), ed.caret_pos()))
    })
    w.im_cursor = Some(fn(self : @core.Widget) -> @core.Rect? {
      let lines = lines_of(text_of(), self.rect.w)
      let caret = ed.caret_pos()
      Some({
        x: self.rect.x + caret_x_in(lines, caret),
        y: self.rect.y + caret_y_in(lines, caret),
        w: 1.0,
        h: line_h,
      })
    })
    // 滚动条：视口的绝对定位子控件（贴右缘、压在文字之上，才吃得到命中）
    w.append_child(scroll_bar(st))
    // Store 被外部改动时回灌内核（内核才是文本权威）
    let sid = store.subscribe_id(fn(t : String) -> Unit {
      if t != ed.get_text() {
        ed.set_text(t)
        @core.invalidate()
      }
    })
    @core.sub_bag_register(fn() { store.remove(sid) })
    handle(w)
    w
  })
}
