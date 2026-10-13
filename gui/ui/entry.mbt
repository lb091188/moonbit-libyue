// 输入框（单行）全语义：选区、双击选词、拖动插入点、Shift+箭头、undo/redo、
// placeholder、只读、密码遮罩、输入法 commit/preedit 内联。
//
// 三条形态约定：
// ① 文本状态的唯一权威是 `@input.Editor`，组件不另存一份文本；Store 只是它的
//    对外投影（编辑后回写，外部 `set` 时同步进内核）；
// ② 与宿主的接缝是声明式地基那五个回调（`on_key`/`on_commit`/`on_preedit`/
//    `im_context`/`im_cursor`），输入法四条件由 `App::pump_ime` 统一满足；
// ③ 剪贴板走内核的**内部缓冲**（Ctrl+X/C/V 在框内自洽），系统剪贴板随系统
//    集成批次接进 `sys`——这是记档的降级，不是漏实现。
//
// 下标一律 UTF-8 字节下标且只落码点边界（与内核、IME 同口径）。

///|
/// 密码遮罩显示串（按码点打点，宽度均匀，caret 折算照旧走测量）。
pub fn mask_of(text : String) -> String {
  let mut out = ""
  for _ in text.to_array() {
    out = out + "•"
  }
  out
}

///|
/// 前缀像素宽（`upto` 字节下标，由调用方保证落在码点边界）。
fn prefix_width(ed : @input.Editor, upto : Int, font : @text.Font) -> Double {
  match @text.measure_font(ed.get_text_in_range(0, upto), font) {
    Some(m) => m.width.to_double()
    None => 0.0
  }
}

///|
/// 像素位置 → 字节下标：逐码点量前缀，取「不超过 x」的最右边界。`pad` 是文本起点。
fn byte_at_x(ed : @input.Editor, x : Double, pad : Double, font : @text.Font) -> Int {
  let n = ed.byte_len()
  let mut best = 0
  let mut k = 0
  while k < n {
    let next = ed.boundary_after(k + 1)
    if prefix_width(ed, next, font) + pad <= x {
      best = next
    }
    if next <= k {
      k = n
    } else {
      k = next
    }
  }
  best
}

///|
/// 选词：从 `at` 向两侧扩到字母/数字/下划线之外（与内核 `is_word_byte` 同口径，
/// 非 ASCII 一律算词内，中文因此整段连续可选）。
fn word_range(text : String, at : Int) -> (Int, Int) {
  let b = @utf8.encode(text)
  let n = b.length()
  let is_word = fn(i : Int) -> Bool {
    if i < 0 || i >= n {
      return false
    }
    let v = b[i].to_int()
    (v >= 48 && v <= 57) || (v >= 65 && v <= 90) || (v >= 97 && v <= 122) ||
      v == 95 || v >= 0x80
  }
  let clamped = if at > n { n } else if at < 0 { 0 } else { at }
  let mut start = clamped
  while start > 0 && is_word(start - 1) {
    start = start - 1
  }
  let mut end = clamped
  while end < n && is_word(end) {
    end = end + 1
  }
  (start, end)
}

///|
/// 单行输入框。文本经 `store` 双向投影；`focus_id` 决定它能否吃键盘焦点
/// （宿主的 Tab 环绕与按键投递都按它走）。
pub fn input(
  store : @core.Store[String],
  placeholder? : String = "",
  password? : Bool = false,
  read_only? : Bool = false,
  size? : Double = 13.0,
  family? : String = "",
  width? : Double = 0.0,
  focus_id? : Int = 0,
  caret_on? : () -> Bool = fn() -> Bool { true },
  on_enter? : () -> Unit = fn() { () },
  on_change? : (String) -> Unit = fn(_s : String) { () },
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let ed = @input.Editor::new()
  attach_system_clipboard(ed)
  let _ = ed.insert_text(store.get())
  let font = @text.Font::new(family, size)
  let pad = 4.0
  let mask = password
  let ro = read_only
  let ph = placeholder
  let enter_cb = on_enter
  let change_cb = on_change
  let last_down = Ref(-1000000L)
  let last_x = Ref(-1000.0)
  let dragging = Ref(false)
  let anchor = Ref(0)
  let push = fn() -> Unit {
    let t = ed.get_text()
    store.set(t)
    change_cb(t)
  }
  let show_text = fn() -> String {
    if mask { mask_of(ed.get_text()) } else { ed.get_text() }
  }
  let caret_x = fn() -> Double { pad + prefix_width(ed, ed.caret_pos(), font) }
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let off = enabled_cell(None, false)
    w.focus_id = focus_id
    w.cursor = @core.CURSOR_TEXT
    w.node.set_height(@yoga.fixed(@theme.control_height))
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    } else {
      w.node.set_min_width(@yoga.fixed(80.0))
    }
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let lh = @text.line_height_font(font).unwrap_or(18).to_double()
      let ty = ((r.h - lh) / 2.0).max(0.0)
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      match ed.selection() {
        Some((s, e)) => {
          let x0 = pad + prefix_width(ed, s, font)
          let x1 = pad + prefix_width(ed, e, font)
          p.set_fill_color(@theme.theme_primary_light())
          p.fill_rect(x0, ty, (x1 - x0).max(1.0), lh)
        }
        None => ()
      }
      p.set_stroke_color(if self.focused {
        @theme.theme_primary()
      } else {
        @theme.theme_border()
      })
      p.set_line_width(1.0)
      p.stroke_rect(0.0, 0.0, r.w, r.h)
      let txt = show_text()
      let pe = ed.preedit_text()
      // 占位符只在「没文本且没组合串」时画：少了组合串这一条，空框里打拼音
      // 屏幕上什么都不出现（组合照常在走），看起来就是「打不进字」——真机踩到。
      if txt.length() == 0 && ph.length() > 0 && pe.length() == 0 {
        let _ = @text.draw_at(p, pad, ty, ph, font, @theme.theme_text_secondary())
      } else {
        if txt.length() > 0 {
          let _ = @text.draw_at(p, pad, ty, txt, font, if off.off {
            @theme.theme_text_secondary()
          } else {
            @theme.theme_text_regular()
          })
        }
        if pe.length() > 0 {
          // 组合串画在 caret 处并加下划线，且只此一份（内核不并入文本）
          let px = caret_x()
          let _ = @text.draw_at(p, px, ty, pe, font, @theme.theme_warning())
          let pw = match @text.measure_font(pe, font) {
            Some(m) => m.width.to_double()
            None => 0.0
          }
          p.set_fill_color(@theme.theme_warning())
          p.fill_rect(px, ty + lh - 1.0, pw, 1.0)
        }
      }
      if self.focused && !off.off && caret_on() {
        p.set_fill_color(@theme.theme_text_primary())
        p.fill_rect(caret_x(), 4.0, 1.0, (r.h - 8.0).max(1.0))
      }
    })
    w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press || off.off {
        return false
      }
      if ev.keysym == @core.KS_RETURN {
        enter_cb()
        return true
      }
      // 导航键：方向/Home/End/PageUp-Down/Tab（65360..65367 是这一族）与带修饰的组合
      let nav = (ev.mods & (@core.MOD_CTRL | @core.MOD_SHIFT)) != 0 || (
        ev.keysym >= 65360 && ev.keysym <= 65367
      ) || ev.keysym == @core.KS_TAB
      let editing = ev.keysym == @core.KS_BACKSPACE || ev.keysym == @core.KS_DELETE
      if ro && (editing || !nav) {
        // 只读：导航与复制照旧，编辑类按键（含退格/删除/可打印字符）一律不吃
        return false
      }
      let before = ed.get_text()
      let handled = ed.handle_key(ev.keysym, ev.mods)
      if handled {
        if ed.get_text() != before {
          push()
        }
        @core.invalidate()
      }
      handled
    })
    w.on_commit = Some(fn(t : String) -> Bool {
      let _ = ed.insert_text(t)
      push()
      @core.invalidate()
      true
    })
    w.on_preedit = Some(fn(t : String, _caret : Int) -> Unit {
      ed.set_preedit(t)
      @core.invalidate()
    })
    w.on_pointer = Some(fn(_self : @core.Widget, ev : @core.PointerEvent) -> Bool {
      match ev.kind {
        @core.Down => {
          let now = @core.now_ms()
          let dbl = (now - last_down.val) < 400L && (ev.x - last_x.val).abs() < 4.0
          last_down.val = now
          last_x.val = ev.x
          dragging.val = true
          if dbl {
            let (s, e) = word_range(ed.get_text(), byte_at_x(ed, ev.x, pad, font))
            ed.select_range(s, e)
          } else {
            let at = byte_at_x(ed, ev.x, pad, font)
            ed.select_range(at, at)
            anchor.val = at
          }
          @core.invalidate()
          true
        }
        @core.Move => {
          if dragging.val {
            // 拖出的部分靠宿主的捕获期投递，选区可以越过框边缘继续走
            ed.select_range(anchor.val, byte_at_x(ed, ev.x, pad, font))
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
    w.im_context = Some(fn() -> (String, Int)? {
      Some((ed.get_text(), ed.caret_pos()))
    })
    w.im_cursor = Some(fn(self : @core.Widget) -> @core.Rect? {
      let rect = self.rect
      Some({
        x: rect.x + caret_x(),
        y: rect.y + 2.0,
        w: 1.0,
        h: (rect.h - 4.0).max(1.0),
      })
    })
    // Store 被外部改动时同步进内核（内核才是文本权威，这里只做投影回灌）
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
