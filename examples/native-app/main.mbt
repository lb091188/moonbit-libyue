// examples/native-app —— GUI 侧同类测试的**累积**示例（口径见 TODO.md 头部
// 「验证示例归口」条）：每完成一个特性批次，就在本文件里加一节演示与一行退出
// 状态，不为单个特性另开示例。`examples/native-window` 保持冻结，作为 G2–G5
// 的历史冒烟基准。
//
// 批次 1（App 宿主 + TextEditorHost 收口）：整窗由 `@core.App` 驱动——循环、
// 事件翻译、焦点栈、输入法四条件、脏标上屏都在宿主里，界面内容只是一棵
// `@core.Widget` 树。跑法：moon run examples/native-app（需显示服务），5 秒后
// 自动退出并打印状态行。
//
// 批次 3（字体）：末尾一行演示「族名回退 + 混排行高」，两个盒子的盒高都来自
// `@text.AttributedText::line_height`。

///|
const FONT : Double = 14.0

///|
priv struct Ctr {
  mut frames : Int
  mut clicks : Int
  mut blink : Bool
  // 批次 3（字体）的三个观测值
  mut fam_count : Int
  mut use_family : String
  mut lh_mixed : Int
  // 批次 5a：捕获带的三类事件计数
  mut down : Int
  mut up : Int
  mut moved : Int
  // 批次 5b：组件层按钮的点击数
  mut comp : Int
}

///|
priv struct Field {
  w : @core.Widget
  ed : @input.Editor
}

///|
/// 前缀宽：caret 的屏幕位置 = 已提交前缀的文本宽度（与编辑内核同用的字节下标口径）
fn prefix_width(ed : @input.Editor, upto : Int) -> Double {
  match @text.measure(ed.get_text_in_range(0, upto), FONT) {
    Some(m) => m.width.to_double()
    None => 0.0
  }
}

///|
/// 点击定位 caret：逐码点量前缀宽，取「不超过点击点」的最右边界
fn place_caret(ed : @input.Editor, local_x : Double) -> Unit {
  let n = ed.byte_len()
  let mut best = 0
  let mut k = 0
  while k < n {
    let next = ed.boundary_after(k + 1)
    if prefix_width(ed, next) + 4.0 <= local_x {
      best = next
    }
    if next <= k {
      k = n
    } else {
      k = next
    }
  }
  ed.select_range(best, best)
}

///|
/// 文本框控件：编辑器是文本状态的唯一权威，宿主只经五个回调接缝取放
/// （`on_key` / `on_commit` / `on_preedit` / `im_context` / `im_cursor`）——
/// 即 G5b 记档的 TextEditorHost 形态。
fn make_field(
  app : @core.App,
  ctr : Ctr,
  id : Int,
  text : String,
  top : Double,
) -> Field {
  let ed = @input.Editor::new()
  let _ = ed.insert_text(text)
  let w = @core.Widget::new()
  w.focus_id = id
  w.set_size(240.0, 26.0)
  w.set_margin(top, 0.0, 0.0, 0.0)
  w.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
    let focused = app.focus.is_focused(id)
    p.set_fill_color(@theme.theme_bg_panel())
    p.fill_rect(0.0, 0.0, r.w, r.h)
    p.set_stroke_color(if focused {
      @theme.theme_primary()
    } else {
      @theme.theme_border()
    })
    p.set_line_width(1.0)
    p.stroke_rect(0.0, 0.0, r.w, r.h)
    let lh = match @text.line_height(FONT) {
      Some(h) => h.to_double()
      None => FONT * 1.5
    }
    let ty = (r.h - lh) / 2.0
    // 文本走 yue/text 自己的 Cairo 会话，与 Painter 会话交替前刷一次
    p.flush()
    let _ = @text.draw_text_at(
      p,
      4.0,
      ty,
      ed.get_text(),
      FONT,
      @theme.theme_text_regular(),
    )
    let pe = ed.preedit_text()
    if pe.length() > 0 {
      let px = 4.0 + prefix_width(ed, ed.caret_pos())
      p.flush()
      let _ = @text.draw_text_at(p, px, ty, pe, FONT, @theme.theme_warning())
      let pw = match @text.measure(pe, FONT) {
        Some(m) => m.width.to_double()
        None => 0.0
      }
      p.set_fill_color(@theme.theme_warning())
      p.fill_rect(px, ty + lh - 1.0, pw, 1.0)
    }
    if focused && ctr.blink {
      let cx = 4.0 + prefix_width(ed, ed.caret_pos())
      p.set_fill_color(@theme.theme_text_primary())
      p.fill_rect(cx, 4.0, 1.0, r.h - 8.0)
    }
  })
  w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
    if !ev.press {
      return false
    }
    let handled = ed.handle_key(ev.keysym, ev.mods)
    if handled {
      ctr.blink = true
    }
    handled
  })
  w.on_commit = Some(fn(t : String) -> Bool {
    let _ = ed.insert_text(t)
    ctr.blink = true
    true
  })
  w.on_preedit = Some(fn(t : String, _caret : Int) -> Unit {
    ed.set_preedit(t)
  })
  w.im_context = Some(fn() -> (String, Int)? {
    Some((ed.get_text(), ed.caret_pos()))
  })
  w.im_cursor = Some(fn(self_rect : @core.Widget) -> @core.Rect? {
    let rect = self_rect.rect
    Some({
      x: rect.x + 4.0 + prefix_width(ed, ed.caret_pos()),
      y: rect.y + 2.0,
      w: 1.0,
      h: rect.h - 4.0,
    })
  })
  w.on_pointer = Some(fn(_widget : @core.Widget, ev : @core.PointerEvent) -> Bool {
    match ev.kind {
      @core.Down => {
        place_caret(ed, ev.x)
        true
      }
      _ => false
    }
  })
  { w, ed }
}

///|
/// 计数按钮：按下、或持焦点时回车/空格都 +1；同时是 Tab 环绕的可见证据。
fn make_button(app : @core.App, ctr : Ctr, id : Int, top : Double) -> @core.Widget {
  let w = @core.Widget::new()
  w.focus_id = id
  w.set_size(200.0, 28.0)
  w.set_margin(top, 0.0, 0.0, 0.0)
  w.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
    let focused = app.focus.is_focused(id)
    p.set_fill_color(if focused {
      @theme.theme_primary()
    } else {
      @theme.theme_fill_hover()
    })
    p.fill_rect(0.0, 0.0, r.w, r.h)
    p.flush()
    let _ = @text.draw_text_at(
      p,
      10.0,
      5.0,
      "计数 \{ctr.clicks}（点击或回车）",
      FONT,
      if focused { "#ffffff" } else { @theme.theme_text_regular() },
    )
  })
  w.on_pointer = Some(fn(_widget : @core.Widget, ev : @core.PointerEvent) -> Bool {
    match ev.kind {
      @core.Down => {
        ctr.clicks = ctr.clicks + 1
        true
      }
      _ => false
    }
  })
  w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
    if ev.press && (ev.keysym == @core.KS_RETURN || ev.keysym == 32) {
      ctr.clicks = ctr.clicks + 1
      true
    } else {
      false
    }
  })
  w
}

///|
fn text_line(
  text : String,
  color : String,
  top : Double,
  height : Double,
) -> @core.Widget {
  let w = @core.Widget::new()
  w.set_size(360.0, height)
  w.set_margin(top, 0.0, 0.0, 0.0)
  w.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, _r : @core.Rect) -> Unit {
    p.flush()
    let _ = @text.draw_text_at(p, 0.0, 0.0, text, FONT, color)
  })
  w
}

///|
/// 批次 3（字体枚举与回退 + 混排行高）：同一段文字画两次——左边只用基准字体，
/// 右边把末尾的「28」换成 28px。两个盒子的**盒高都取 `line_height()`**，
/// 混排那盒必须被抬起来，否则大字会被裁；族名走 `resolve_family`
/// （不存在的族退到 monospace）。
fn make_font_row(ctr : Ctr) -> @core.Widget {
  let w = @core.Widget::new()
  w.set_size(388.0, 72.0)
  w.set_margin(12.0, 0.0, 0.0, 0.0)
  w.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
    p.set_fill_color(@theme.theme_bg_panel())
    p.fill_rect(0.0, 0.0, r.w, r.h)
    let base = @text.AttributedText::new("基准 Base 28")
    let lh_base = match base.line_height() {
      Some(v) => v.to_double()
      None => FONT * 1.5
    }
    let mixed = @text.AttributedText::new("基准 Base 28")
    // 「28」是末尾两字节起、长 2 字节（字节下标口径，与编辑内核同源）
    let nb = @utf8.encode("基准 Base 28")
    let at = nb.length() - 2
    mixed.set_font_for(@text.Font::new("", 28.0), at, nb.length())
    let lh_mixed = match mixed.line_height() {
      Some(v) => v
      None => 0
    }
    ctr.lh_mixed = lh_mixed
    // 两个盒子的边框：右盒没被抬起来就是行高口径错了
    p.set_stroke_color(@theme.theme_border())
    p.set_line_width(1.0)
    p.stroke_rect(0.0, 0.0, 190.0, lh_base)
    p.stroke_rect(198.0, 0.0, 190.0, lh_mixed.to_double())
    p.flush()
    let _ = base.draw_at(p, 4.0, 0.0, 186.0, lh_base)
    let _ = mixed.draw_at(p, 202.0, 0.0, 186.0, lh_mixed.to_double())
    let fam = @text.resolve_family(["绝对没有的族 Qzz", "monospace"])
    let _ = @text.draw_at(
      p,
      4.0,
      52.0,
      "回退族名：" + fam + " 可用族 " + ctr.fam_count.to_string(),
      @text.Font::new(fam, 12.0),
      @theme.theme_text_regular(),
    )
  })
  w
}

///|
/// 批次 4（声明式地基）：一个 `Store` 驱动的 `bind_node`——点一下就把整棵子树
/// **原位**重挂（兄弟项位置不动、根控件的子项数不变），旧代订阅随重建退场。
/// 状态行的 `decl=` 是 store 的值，`kids=` 是根控件的直接子项数（应当恒定）。
fn make_decl_row(store : @core.Store[Int]) -> @core.Node {
  @core.bind_node(store.signal(), fn(v : Int) -> @core.Node {
    @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
      w.set_size(388.0, 30.0)
      w.set_margin(10.0, 0.0, 0.0, 0.0)
      w.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
        p.set_fill_color(if v % 2 == 0 {
          @theme.theme_fill_hover()
        } else {
          @theme.theme_bg_panel()
        })
        p.fill_rect(0.0, 0.0, r.w, r.h)
        p.flush()
        let _ = @text.draw_text_at(
          p,
          6.0,
          6.0,
          "声明式：第 \{v} 次点击（原位重挂，底色随奇偶换）",
          FONT,
          @theme.theme_text_regular(),
        )
      })
      w.on_pointer = Some(fn(_widget : @core.Widget, ev : @core.PointerEvent) -> Bool {
        match ev.kind {
          @core.Down => {
            store.update(fn(x : Int) -> Int { x + 1 })
            true
          }
          _ => false
        }
      })
      w
    })
  })
}

///|
/// 批次 5a（交互地基）的观测件：一条「捕获带」把按下/移动/抬起的次数记下来。
/// 宿主在按下后进入捕获期——指针离开这条带、在别处松手，抬起仍投给带本身
/// （`u` 照样 +1），这就是拖选/拖动插入点能成立的前提。
fn make_band(ctr : Ctr) -> @core.Widget {
  let w = @core.Widget::new()
  w.set_size(120.0, 22.0)
  w.set_margin(8.0, 0.0, 0.0, 0.0)
  w.on_draw = Some(fn(w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
    // 悬停/按下态由宿主统一维护，控件只读
    p.set_fill_color(if w.pressed {
      @theme.theme_warning()
    } else if w.hovered {
      @theme.theme_primary()
    } else {
      @theme.theme_fill_hover()
    })
    p.fill_rect(0.0, 0.0, r.w, r.h)
    p.flush()
    let _ = @text.draw_text_at(
      p,
      4.0,
      3.0,
      "捕获带 d\{ctr.down} u\{ctr.up} m\{ctr.moved}",
      12.0,
      @theme.theme_text_primary(),
    )
  })
  w.on_pointer = Some(fn(_widget : @core.Widget, ev : @core.PointerEvent) -> Bool {
    match ev.kind {
      @core.Down => {
        ctr.down = ctr.down + 1
        true
      }
      @core.Up => {
        ctr.up = ctr.up + 1
        true
      }
      @core.Move => {
        ctr.moved = ctr.moved + 1
        false
      }
      @core.Leave => false
    }
  })
  w
}

///|
fn main {
  let app = match @core.App::new(560, 424, "MoonBit App 宿主 (批次1)") {
    Some(a) => a
    None => {
      println("NATIVE-APP-SKIP: 本平台无窗口后端或没有显示服务")
      return
    }
  }
  let ctr : Ctr = {
    frames: 0,
    clicks: 0,
    blink: true,
    fam_count: 0,
    use_family: "",
    lh_mixed: 0,
    down: 0,
    up: 0,
    moved: 0,
    comp: 0,
  }
  let root = app.root
  root.set_column()
  ctr.fam_count = match @text.families() {
    Some(list) => list.length()
    None => 0
  }
  ctr.use_family = @text.resolve_family(["绝对没有的族 Qzz", "monospace"])
  root.set_padding(16.0, 12.0)
  root.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
    p.set_fill_color(@theme.theme_bg_page())
    p.fill_rect(0.0, 0.0, r.w, r.h)
  })
  root.append_child(
    text_line("App 宿主：循环/焦点/输入法/上屏都在一处", @theme.theme_text_primary(), 0.0, 22.0),
  )
  let f1 = make_field(app, ctr, 1, "hello", 8.0)
  let f2 = make_field(app, ctr, 2, "第二个框", 8.0)
  let btn = make_button(app, ctr, 3, 12.0)
  root.append_child(f1.w)
  root.append_child(f2.w)
  root.append_child(btn)
  root.append_child(make_font_row(ctr))
  root.append_child(make_band(ctr))
  // 批次 5b（组件层首批）：一行全用 @ui 构造器，按钮经 store 计数。
  app.mount([
    @ui.container(
      [
        @ui.label("组件层", size=13.0),
        @ui.separator(vertical=true),
        @ui.icon(
          @icons.IconKind::MediumCircleFill, size=18.0, color=@theme.theme_success(),
        ),
        @ui.button(
          "加一",
          on_click=fn() { ctr.comp = ctr.comp + 1 },
          min_width=64.0,
        ),
        @ui.button("禁用", disabled=true),
      ],
      direction=@yoga.Row,
      column_gap=8.0,
      padding=6.0,
      align_items=@yoga.AlignItems::Center,
      bg=@theme.theme_bg_page(),
      border=@theme.theme_border(),
    ),
  ])
  // 批次 5c（表单控件）：一行组件化表单——复选 / 开关 / 滑块 / 步进 / 进度。
  // 状态都在 Store 里，滑块拖动同时驱动进度条（两个组件共享一个 Store）。
  let agreed = @core.Store::new(false)
  let sound = @core.Store::new(true)
  let level = @core.Store::new(25.0)
  let count = @core.Store::new(0)
  app.mount([
    @ui.container(
      [
        @ui.checkbox("同意", agreed),
        @ui.switch_t(sound, on_text="开", off_text="关"),
        @ui.slider(level, width=120.0, step=5.0),
        @ui.stepper(count, min=0, max=3),
        @ui.progress(level, width=80.0, max=100.0),
      ],
      direction=@yoga.Row,
      column_gap=10.0,
      padding=6.0,
      align_items=@yoga.AlignItems::Center,
      bg=@theme.theme_bg_panel(),
      border=@theme.theme_border(),
    ),
  ])
  // 批次 5d（输入框全语义）：整只框由 `@ui.entry` 提供——键入、选区、双击选词、
  // 拖动、undo、输入法提交与 preedit 都在组件里，宿主只按焦点投递。
  let t3 = @core.Store::new("组件框")
  let _ = (@ui.entry(
    t3,
    width=200.0,
    focus_id=4,
    placeholder="说点什么",
    caret_on=fn() -> Bool { ctr.blink },
  )).mount_into(root)
  let decl = @core.Store::new(0)
  let decl_kids_before = root.children().length()
  app.mount([make_decl_row(decl)])
  let _ = app.focus.register(1)
  let _ = app.focus.register(2)
  let _ = app.focus.register(3)
  let _ = app.focus.register(4)

  let ticker : Ref[() -> Unit] = Ref(fn() { () })
  ticker.val = fn() {
    if app.is_running() {
      ctr.frames = ctr.frames + 1
      app.schedule_paint()
      let _ = app.timer(100, ticker.val)
    }
  }
  let blinker : Ref[() -> Unit] = Ref(fn() { () })
  blinker.val = fn() {
    if app.is_running() {
      ctr.blink = !ctr.blink
      app.schedule_paint()
      let _ = app.timer(500, blinker.val)
    }
  }
  let _ = app.timer(100, ticker.val)
  let _ = app.timer(500, blinker.val)
  let _ = app.timer(5000, fn() { app.quit() })

  app.run()
  let focus_str = match app.focus.current() {
    Some(i) => i.to_string()
    None => "-"
  }
  println(
    "NATIVE-APP-OK frames=\{ctr.frames} clicks=\{ctr.clicks} t1='\{f1.ed.get_text()}' c1=\{f1.ed.caret_pos()} t2='\{f2.ed.get_text()}' focus=\{focus_str} fam=\{ctr.fam_count} use='\{ctr.use_family}' lhm=\{ctr.lh_mixed} decl=\{decl.get()} kids=\{root.children().length()}/\{decl_kids_before + 1} band=d\{ctr.down}/u\{ctr.up}/m\{ctr.moved} comp=\{ctr.comp} form=\{agreed.get()}/\{sound.get()}/\{level.get().round().to_int()}/\{count.get()} t3='\{t3.get()}'"
  )
  // 机器可读的几何行：本例是 GUI 侧的**累积验证页**，后续每加一节都要靠
  // xdotool 按坐标注入回证，这一行就是坐标依据（免得按截图猜点位）
  let mut rects = ""
  let kids = app.root.children()
  for i = 0; i < kids.length(); i = i + 1 {
    let r = kids[i].rect
    let rx = r.x.round().to_int().to_string()
    let ry = r.y.round().to_int().to_string()
    let rw = r.w.round().to_int().to_string()
    let rh = r.h.round().to_int().to_string()
    rects = rects + i.to_string() + ":" + rx + "," + ry + "," + rw + "x" + rh + " "
  }
  println("NATIVE-APP-RECTS " + rects)
  app.shutdown()
}
