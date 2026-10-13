// examples/native-app —— GUI 侧同类测试的**累积**示例（口径见 TODO.md 头部
// 「验证示例归口」条）：每完成一个特性批次，就在本文件里加一节演示与一行退出
// 状态，不为单个特性另开示例。`examples/native-window` 保持冻结，作为 G2–G5
// 的历史冒烟基准。
//
// 批次 1（App 宿主 + TextEditorHost 收口）：整窗由 `@core.App` 驱动——循环、
// 事件翻译、焦点栈、输入法四条件、脏标上屏都在宿主里，界面内容只是一棵
// `@core.Widget` 树。跑法：moon run examples/native-app（需显示服务），12 秒后
// 自动退出并打印状态行（注入点位多，留够一轮全交互的时间）。
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
  // 批次 6a：提示条关闭热区被点的次数
  mut closed : Int
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
  w.set_margin(top=top)
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
    // 文本走 text 自己的 Cairo 会话，与 Painter 会话交替前刷一次
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
  w.set_margin(top=top)
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
  w.set_margin(top=top)
  w.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, _r : @core.Rect) -> Unit {
    p.flush()
    let _ = @text.draw_text_at(p, 0.0, 0.0, text, FONT, color)
  })
  w
}

///|
/// 每帧现读的一行状态字（多窗对照用：计数在闭包里读，画的是当下值）。
fn live_counter(text_of : () -> String, width? : Double = 560.0) -> @core.Widget {
  let w = @core.Widget::new()
  w.set_size(width, 22.0)
  w.on_draw = Some(fn(_w : @core.Widget, p : @render.Painter, _r : @core.Rect) -> Unit {
    p.flush()
    let _ = @text.draw_text_at(
      p,
      0.0,
      0.0,
      text_of(),
      FONT,
      @theme.theme_text_primary(),
    )
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
  w.set_margin(top=12.0)
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
      w.set_margin(top=10.0)
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
  w.set_margin(top=8.0)
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
/// 分隔布局 + 文本族区块：左右两栏可拖动分隔，两栏里各放一个主题化标签。
fn make_split_section(slot : Ref[@core.Widget?]) -> @core.Node {
  let pane = fn(title : String, role : @ui.TextRole, bg : String) -> @core.Node {
    @ui.view(
      [
        @ui.text(title, role=role, align=@text.Center, max_width=160.0),
        @ui.text(
          "标签按 max_width 折行；拖动中间把手改两栏宽度（退出状态行报首栏宽）",
          role=Secondary,
          max_width=160.0,
        ),
      ],
      padding=6.0,
      row_gap=4.0,
      align_items=@yoga.AlignItems::Center,
      bg=bg,
    )
  }

  @ui.view(
    [
      @ui.text("分隔布局与文本族：把手常显点纹，悬停浅底、拖动主题色", size=13.0),
      @ui.split(
        pane("左栏 Title", Title, @theme.theme_bg_panel()),
        pane("右栏 Accent", Accent, @theme.theme_fill_zebra()),
        ratio=0.5,
        min_first=120.0,
        min_second=120.0,
        handle=fn(w : @core.Widget) -> Unit { slot.val = Some(w) },
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 粘性列表区块：三组各四行，滚动时顶部吸顶条显示当前组。
fn make_sticky_section(st : @ui.StickyList, slot : Ref[@core.Widget?]) -> @core.Node {
  let rows_of = fn(prefix : String) -> Array[@core.Node] {
    let out : Array[@core.Node] = []
    for i = 1; i <= 4; i = i + 1 {
      out.push(
        @ui.view(
          [@ui.text(prefix + " 行 " + i.to_string(), size=12.0)],
          height=22.0,
          padding=4.0,
          bg=if i % 2 == 0 {
            @theme.theme_fill_zebra()
          } else {
            @theme.theme_bg_panel()
          },
        ),
      )
    }
    out
  }

  @ui.view(
    [
      @ui.text("粘性列表：滚过组边界时顶部吸顶条换组名（退出状态行报当前组）", size=13.0),
      @ui.sticky_list(
        [("组一", rows_of("甲")), ("组二", rows_of("乙")), ("组三", rows_of("丙"))],
        st,
        width=240.0,
        height=110.0,
        head_h=28.0,
        handle=fn(w : @core.Widget) -> Unit { slot.val = Some(w) },
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 把多行文本折平成一行打印（换行写成 `/`，插入点所在行写成序号）。
fn flat(text : String) -> String {
  let mut out = ""
  for ch in text.to_array() {
    out = out + (if ch == '\n' { "/" } else { ch.to_string() })
  }
  out
}

///|
/// 表单族余项区块：四型主题化按钮 + 链接 + 表单（错误行）+ 评分。
/// 按钮四型都记同一个点击数（点哪个都 +1），「危险」那颗另外把错误文案写进
/// `form_item` 的错误 Store，用来回证「错误出现不引起布局跳动」。
fn make_form_section(
  btn : Ref[Int],
  lnk : Ref[Int],
  rate : @core.Store[Int],
  err : @core.Store[String],
  btn_slot : Ref[@core.Widget?],
  row_slot : Ref[@core.Widget?],
  link_slot : Ref[@core.Widget?],
  rate_slot : Ref[@core.Widget?],
  item_slot : Ref[@core.Widget?],
  sel : @core.Store[String],
  col : @core.Store[String],
  pick : Ref[String],
  ta : @core.Store[String],
  ta_slot : Ref[@core.Widget?],
  cmb : @core.Store[String],
  cmb_slot : Ref[@core.Widget?],
  sel_slot : Ref[@core.Widget?],
  col_slot : Ref[@core.Widget?],
) -> @core.Node {
  let hit = fn() -> Unit { btn.val = btn.val + 1 }
  let hit_err = fn() -> Unit {
    btn.val = btn.val + 1
    err.set("必填项不能为空")
  }
  @ui.view(
    [
      @ui.text("表单族余项：四型按钮 / 链接 / 表单项错误行 / 评分（退出状态行报点击与值）", size=13.0),
      @ui.view(
        [
          @ui.button(
            "实心提交",
            on_click=hit,
            variant=Solid,
            focus_id=21,
            handle=fn(w : @core.Widget) -> Unit { btn_slot.val = Some(w) },
          ),
          @ui.button("柔和", on_click=hit, variant=Soft),
          @ui.button("文字", on_click=hit, variant=Text),
          @ui.button("危险并报错", on_click=hit_err, variant=Danger),
          @ui.link("查看详情", fn() -> Unit { lnk.val = lnk.val + 1 }, handle=fn(w : @core.Widget) -> Unit {
            link_slot.val = Some(w)
          }),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
        handle=fn(w : @core.Widget) -> Unit { row_slot.val = Some(w) },
      ),
      @ui.form(
        "表单分组",
        [
          @ui.form_item("昵称", @ui.text("（控件区）"), label_width=90.0),
          @ui.form_item(
            "备注",
            @ui.text("（错误文案在下方红字）"),
            label_width=90.0,
            error=err,
            handle=fn(w : @core.Widget) -> Unit { item_slot.val = Some(w) },
          ),
        ],
      ),
      @ui.view(
        [
          @ui.select(
            ["选项甲", "选项乙", "选项丙"],
            sel,
            on_change=fn(v : String) -> Unit {
              if v.length() > 0 {
                pick.val = v
              }
            },
            clearable=true,
            placeholder="请选择",
            width=160.0,
            focus_id=22,
            handle=fn(w : @core.Widget) -> Unit { sel_slot.val = Some(w) },
          ),
          @ui.select(
            ["组件甲", "组件乙", "组件丙"],
            cmb,
            placeholder="可输入过滤",
            width=150.0,
            focus_id=25,
            editable=true,
            handle=fn(w : @core.Widget) -> Unit { cmb_slot.val = Some(w) },
          ),
          @ui.color_picker(
            col,
            width=160.0,
            focus_id=23,
            handle=fn(w : @core.Widget) -> Unit { col_slot.val = Some(w) },
          ),
        ],
        direction=@yoga.Row,
        column_gap=10.0,
        align_items=@yoga.AlignItems::Center,
      ),
      @ui.view(
        [
          @ui.text("多行输入框：回车换行、上下键按显示行走、超出出滚动条", role=Secondary),
          @ui.textarea(
            ta,
            placeholder="写点什么",
            width=300.0,
            height=76.0,
            focus_id=24,
            handle=fn(w : @core.Widget) -> Unit { ta_slot.val = Some(w) },
          ),
        ],
        direction=@yoga.Column,
        row_gap=4.0,
        align_items=@yoga.AlignItems::FlexStart,
      ),
      @ui.rate(
        rate,
        max=5,
        handle=fn(w : @core.Widget) -> Unit { rate_slot.val = Some(w) },
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 声明式 L1 区块：vbox/hbox 排版 + bind_label 就地换文本 + hover_group 悬停组。
/// 点一次按钮只改 Store（不重建任何子树），标签宽度跟着文本重测；整卡悬停换底色。
fn make_decl_section(
  n : @core.Store[Int],
  card_slot : Ref[@core.Widget?],
  label_slot : Ref[@core.Widget?],
) -> @core.Node {
  @ui.col(
    [
      @ui.text("声明式 L1：vbox/hbox 排版 + bind_label 就地换文本 + hover_group 悬停组", size=13.0),
      @ui.hover_group(
        [
          @ui.row(
            [
              @ui.bind_label(
                n,
                fn(v : Int) -> String {
                  "计数 " + v.to_string() + (if v > 0 { "（已点）" } else { "" })
                },
                handle=fn(w : @core.Widget) -> Unit { label_slot.val = Some(w) },
              ),
              @ui.button(
                "加一",
                on_click=fn() -> Unit { n.set(n.get() + 1) },
                variant=@ui.Border,
                min_width=64.0,
              ),
            ],
            column_gap=10.0,
          ),
          @ui.text("整块卡片悬停换底色（靠宿主的父链悬停态，不轮询指针）", role=Secondary),
        ],
        width=340.0,
        padding=10.0,
        row_gap=6.0,
        handle=fn(w : @core.Widget) -> Unit { card_slot.val = Some(w) },
      ),
    ],
    row_gap=6.0,
    padding=8.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 图标与动图区块：主题取色的图标 + 图标按钮 + GIF 自转（退出状态行报换帧数）。
fn make_media_section(
  gh : @ui.GifHandle,
  ib : Ref[Int],
  gif_slot : Ref[@core.Widget?],
  ib_slot : Ref[@core.Widget?],
) -> @core.Node {
  @ui.view(
    [
      @ui.text("图标与动图：图标跟随主题取色，图标按钮悬停出底，GIF 按帧时长自转", size=13.0),
      @ui.row(
        [
          @ui.icon(@icons.CheckCircleFill, size=20.0),
          @ui.icon_button(
            @icons.Close2,
            on_click=fn() -> Unit { ib.val = ib.val + 1 },
            handle=fn(w : @core.Widget) -> Unit { ib_slot.val = Some(w) },
          ),
          @ui.gif(
            "examples/showcase/assets/dot.gif",
            width=48.0,
            height=48.0,
            state=gh,
            handle=fn(w : @core.Widget) -> Unit { gif_slot.val = Some(w) },
          ),
        ],
        column_gap=10.0,
        align_items=@yoga.AlignItems::Center,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// W20b 全局快捷键区块：注册/注销计数 + 最近触发次数与键名。
/// 真按键触发需人工（切到别的程序按 Ctrl+Alt+F9）——宿主每拍经
/// `@win.poll_global_shortcut` 抽取，命中即累加。
fn make_hotkey_section(
  hits : Ref[Int],
  last : Ref[String],
) -> @core.Node {
  @ui.view(
    [
      @ui.text(
        "全局快捷键（W20b）：注册 Ctrl+Alt+F9 / Ctrl+Alt+F10，切到别的程序按下应计数",
        size=13.0,
      ),
      @ui.row(
        [
          @core.node_of(live_counter(
            fn() -> String {
              "触发次数 " +
              hits.val.to_string() +
              "  最近 " +
              last.val
            },
            width=260.0,
          )),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// W20d 原生消息框区块：点按钮弹 Win32 `MessageBoxW`（模态，阻塞到点按），
/// 返回值编号与语义写进状态行。按钮组合走图表式切换（是/否/取消 与 错误图标）。
/// 真弹框是人触发（不是开机自弹）——避免冒烟期阻塞。
fn make_message_box_section(
  last : Ref[String],
  shots : Ref[Int],
) -> @core.Node {
  let on_confirm = fn() -> Unit {
    shots.val = shots.val + 1
    let r = @win.show_message_box(
      "libyue W20d",
      "原生 MessageBoxW：点「是」或「否」看状态行编号。",
      Information,
      YesNo,
    )
    last.val = msgbox_result_label(r)
  }
  let on_error = fn() -> Unit {
    shots.val = shots.val + 1
    let r = @win.show_message_box(
      "libyue W20d",
      "错误档 + 是/否/取消：三个按钮都能收回编号。",
      Error,
      YesNoCancel,
    )
    last.val = msgbox_result_label(r)
  }
  @ui.view(
    [
      @ui.text(
        "原生消息框（W20d）：点按钮弹 Win32 MessageBoxW，关掉后状态行报返回编号",
        size=13.0,
      ),
      @ui.row(
        [
          @ui.button("信息 是/否", on_click=on_confirm, variant=Solid),
          @ui.button("错误 是/否/取消", on_click=on_error, variant=Danger),
          @core.node_of(live_counter(
            fn() -> String { "弹框次数 " + shots.val.to_string() + "  最近 " + last.val },
            width=260.0,
          )),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// MessageBoxResult → 状态行可读标签（含编号，便于与 Win32 口径对照）。
fn msgbox_result_label(r : @win.MessageBoxResult) -> String {
  match r {
    Ok => "OK(1)"
    Cancel => "CANCEL(2)"
    Abort => "ABORT(3)"
    Retry => "RETRY(4)"
    Ignore => "IGNORE(5)"
    Yes => "YES(6)"
    No => "NO(7)"
    Failed => "FAILED(0)"
  }
}

///|
/// W21b 自绘消息框区块：三个按钮各弹一个不同种类/按钮集的**自绘**消息框——纯自绘
/// （不开原生 `MessageBoxW`），因此三平台同构；Esc 收起、Enter 走默认钮。响应编号
/// 落状态行（自绘档的编号由调用方给，与 W20d 原生档的 1..7 是两套口径）。
fn make_drawn_message_box_section(
  vis_info : @core.Store[Bool],
  vis_warn : @core.Store[Bool],
  vis_err : @core.Store[Bool],
  last : Ref[String],
  shots : Ref[Int],
) -> @core.Node {
  let respond = fn(code : Int) -> Unit {
    shots.val = shots.val + 1
    last.val = "编号 " + code.to_string()
  }
  let dismiss = fn() -> Unit {
    shots.val = shots.val + 1
    last.val = "关闭(✕/Esc)"
  }
  @ui.view(
    [
      @ui.text(
        "自绘消息框（W21b）：纯自绘、不吃原生 MessageBoxW，三平台同构；Esc 收起 / Enter 走默认钮",
        size=13.0,
      ),
      @ui.row(
        [
          @ui.button("信息 确定", on_click=fn() -> Unit { vis_info.set(true) }),
          @ui.button("警告 三钮", on_click=fn() -> Unit { vis_warn.set(true) }),
          @ui.button(
            "错误 是/否",
            variant=@ui.Danger,
            on_click=fn() -> Unit { vis_err.set(true) },
          ),
          @core.node_of(live_counter(
            fn() -> String { "弹框次数 " + shots.val.to_string() + "  最近 " + last.val },
            width=260.0,
          )),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
      @ui.message_box(
        vis_info,
        "构建完成",
        "3 个目标已产出。",
        kind=@ui.Information,
        buttons=[("确定", 1)],
        on_response=respond,
        on_dismiss=dismiss,
      ),
      @ui.message_box(
        vis_warn,
        "构建告警",
        "2 个目标有告警。",
        kind=@ui.Warning,
        informative="其中 1 个是缓存未命中，可忽略。",
        buttons=[("重试", 1), ("跳过", 2), ("取消", 3)],
        on_response=respond,
        on_dismiss=dismiss,
        width=460.0,
      ),
      @ui.message_box(
        vis_err,
        "构建失败",
        "3 个目标失败，是否继续？",
        kind=@ui.Error,
        buttons=[("是", 6), ("否", 7)],
        on_response=respond,
        on_dismiss=dismiss,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// W20a 原生菜单栏区块：把 MenuBar 模型翻译成 Win32 原生菜单（CreateMenu +
/// SetMenu），点菜单项经 WM_COMMAND 回收并派发到模型回调。跨平台模型在
/// `core/menu.mbt`，这里只做展示与状态行回证。
fn make_menu_section(
  hits : Ref[Int],
  last : Ref[String],
  applied : Ref[Bool],
) -> @core.Node {
  @ui.view(
    [
      @ui.text(
        "原生菜单栏（W20a）：菜单模型 → Win32 原生菜单，点「文件/编辑/查看」下的项应计数",
        size=13.0,
      ),
      @ui.row(
        [
          @core.node_of(live_counter(
            fn() -> String {
              (if applied.val { "已挂载" } else { "未挂载" }) +
              "  点击 " +
              hits.val.to_string() +
              "  最近 " +
              last.val
            },
            width=320.0,
          )),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 构建演示用菜单条：文件（新建/打开/保存 + 分隔 + 退出角色项）、
/// 编辑（复制/剪切/粘贴/全选角色项）、查看（自动换行勾选项 + 主题单选组）。
/// 点中任一项把标签写进状态行——证明 WM_COMMAND 已回收到模型回调。
fn build_demo_menu_bar(
  hits : Ref[Int],
  last : Ref[String],
) -> @core.MenuBar {
  let note = fn(label : String) -> Unit {
    hits.val = hits.val + 1
    last.val = label
  }
  let bar = @core.MenuBar::new()
  let file = bar.add_menu("文件")
  let _ = file.add_item("新建").set_on_click(fn() { note("文件/新建") })
  let _ = file.add_item("打开").set_on_click(fn() { note("文件/打开") })
  let _ = file.add_item("保存").set_on_click(fn() { note("文件/保存") })
  let _ = file.add_separator()
  let _ = file.add_role_item(@core.Quit).set_on_click(fn() { note("文件/退出") })
  let edit = bar.add_menu("编辑")
  let _ = edit.add_role_item(@core.Copy).set_on_click(fn() { note("编辑/复制") })
  let _ = edit.add_role_item(@core.Cut).set_on_click(fn() { note("编辑/剪切") })
  let _ = edit.add_role_item(@core.Paste).set_on_click(fn() { note("编辑/粘贴") })
  let _ = edit.add_role_item(@core.SelectAll).set_on_click(fn() { note("编辑/全选") })
  let view = bar.add_menu("查看")
  let wrap = view.add_check_item("自动换行")
  wrap.set_on_click(fn() { note("查看/自动换行") })
  let _ = view.add_radio_item("浅色主题").set_on_click(fn() { note("查看/浅色") })
  let _ = view.add_radio_item("深色主题").set_on_click(fn() { note("查看/深色") })
  bar
}

///|
/// W20e 演示图标像素（BGRA 小端、**预乘** alpha，与 `render` 的 Bitmap 同
/// 口径）：四象限各一色 + 中心实心圆。用来演示「像素直建窗口图标」（W20f 的
/// 像素通道），不依赖任何外部素材。
fn demo_icon_pixels(n : Int) -> FixedArray[Byte] {
  let px : FixedArray[Byte] = FixedArray::make(n * n * 4, b'\x00')
  let c = n / 2
  for y = 0; y < n; y = y + 1 {
    for x = 0; x < n; x = x + 1 {
      let off = (y * n + x) * 4
      let dx = x - c
      let dy = y - c
      let inside = dx * dx + dy * dy < c * c
      let (b, g, r) : (Int, Int, Int) = if inside {
        (230, 100, 40) // 中心圆：琥珀
      } else if x < c && y < c {
        (200, 120, 40)
      } else if x >= c && y < c {
        (120, 200, 60)
      } else if x < c {
        (200, 200, 60)
      } else {
        (200, 60, 160)
      }
      px[off] = b.to_byte()
      px[off + 1] = g.to_byte()
      px[off + 2] = r.to_byte()
      px[off + 3] = (255).to_byte() // 不透明（预乘即原色）
    }
  }
  px
}

///|
/// W20e 窗口增强区块：运行中改标题 / 用像素现建窗口图标（W20f）/ 无边框开关 /
/// 自绘标题栏拖拽区。最小尺寸在挂载时设定（不影响点击点位）；拖拽区与无边框
/// 由按钮触发（拖拽区会吃掉该区的点击，装出来会干扰注入验证）。
fn make_window_section(
  app : @core.App,
  icon_holder : Ref[@win.Icon?],
) -> @core.Node {
  let retitle = fn() -> Unit {
    app.window.set_title("libyue · 窗口增强(W20e)")
  }
  let apply_icon = fn() -> Unit {
    match @win.icon_from_bgra(demo_icon_pixels(16), 16, 16) {
      Some(ic) => {
        // 先设上新图标再释放旧的：窗口显示期间不能持悬垂 HICON
        app.window.set_icon(Some(ic))
        match icon_holder.val {
          Some(old) => old.free()
          None => ()
        }
        icon_holder.val = Some(ic)
      }
      None => ()
    }
  }
  let bl_on = fn() -> Unit { app.window.set_borderless(true) }
  let bl_off = fn() -> Unit { app.window.set_borderless(false) }
  // 顶部 24px 作为自绘标题栏拖拽带（按下即拖窗，该带内不再派发点击）
  let dr_on = fn() -> Unit { app.window.set_drag_rect(0, 0, 1400, 24) }
  let dr_off = fn() -> Unit { app.window.set_drag_rect(0, 0, 0, 0) }
  @ui.view(
    [
      @ui.text(
        "窗口增强（W20e）：改标题 / 像素现建窗口图标 / 无边框开关 / 顶部拖拽带",
        size=13.0,
      ),
      @ui.row(
        [
          @ui.button("改标题", on_click=retitle),
          @ui.button("自绘图标", on_click=apply_icon),
          @ui.button("无边框 开", on_click=bl_on),
          @ui.button("无边框 关", on_click=bl_off),
          @ui.button("拖拽带 开", on_click=dr_on),
          @ui.button("拖拽带 关", on_click=dr_off),
          @core.node_of(live_counter(
            fn() -> String {
              let (mw, mh) = app.window.min_size()
              let (dx, dy, dw, dh) = app.window.drag_rect()
              "min=" +
              mw.to_string() +
              "x" +
              mh.to_string() +
              " drag=" +
              dx.to_string() +
              "," +
              dy.to_string() +
              "," +
              dw.to_string() +
              "x" +
              dh.to_string() +
              " bl=" +
              (if app.window.is_borderless() { "1" } else { "0" })
            },
            width=420.0,
          )),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// §6.3 任务栏进度区块：七个按钮各驱动一次写入口（10%/50%/100%/错误/暂停/
/// 不确定/清除），末行 live_counter 现读最近一次操作的结果标签。
/// 真观感（任务栏按钮变绿条/红条/黄条）只能人看，归 `_人工测试清单.md`；
/// 后端不可用时按钮照旧可点（写失败会写进标签，不静默）。
fn make_taskbar_section(
  app : @core.App,
  last : Ref[String],
) -> @core.Node {
  let pct = fn(v : Int64, t : Int64, tag : String) -> Unit {
    last.val =
      if app.window.set_taskbar_progress(v, t) { tag } else { tag + " 写失败" }
  }
  let st = fn(s : @win.TaskbarState, tag : String) -> Unit {
    last.val =
      if app.window.set_taskbar_state(s) { tag } else { tag + " 写失败" }
  }
  @ui.view(
    [
      @ui.text(
        "任务栏进度（§6.3）：写任务栏按钮的进度条与状态（Win32 ITaskbarList3，只写不读）",
        size=13.0,
      ),
      @ui.row(
        [
          @ui.button("10%", on_click=fn() { pct(1, 10, "10%") }),
          @ui.button("50%", on_click=fn() { pct(5, 10, "50%") }),
          @ui.button("100%", on_click=fn() { pct(10, 10, "100%") }),
          @ui.button(
            "错误",
            on_click=fn() { st(@win.TaskbarState::Error, "error") },
          ),
          @ui.button(
            "暂停",
            on_click=fn() { st(@win.TaskbarState::Paused, "paused") },
          ),
          @ui.button(
            "不确定",
            on_click=fn() { st(@win.TaskbarState::Indeterminate, "indeterminate") },
          ),
          @ui.button(
            "清除",
            on_click=fn() { st(@win.TaskbarState::NoProgress, "clear") },
          ),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
      @core.node_of(live_counter(fn() -> String { "最近 " + last.val }, width=260.0)),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// W20c 托盘区块：建托盘（像素现建图标）/ 改提示 / 挂右键菜单 / 弹菜单 / 移除。
/// 左键与菜单项计数落在状态行——证明 `dispatch_tray_event` 与菜单派发链都通。
/// 后端不支持时（Linux 无 watcher、macOS 占位）建项给结构化错误，如实显示。
fn make_tray_section(
  tray : Ref[@core.Tray?],
  note : Ref[String],
  clicks : Ref[Int],
  icon_holder : Ref[@win.Icon?],
) -> @core.Node {
  let build_menu_and_run = fn() -> Unit {
    match tray.val {
      Some(t) => {
        let menu = @core.Menu::new()
        let _ = menu.add_item("打开主窗").set_on_click(fn() {
          clicks.val = clicks.val + 1
          note.val = "菜单/打开主窗"
        })
        let _ = menu.add_separator()
        let _ = menu.add_item("关于").set_on_click(fn() {
          clicks.val = clicks.val + 1
          note.val = "菜单/关于"
        })
        t.set_menu(menu)
        note.val = "已挂菜单"
      }
      None => note.val = "先建托盘"
    }
  }
  let create = fn() -> Unit {
    match @win.icon_from_bgra(demo_icon_pixels(32), 32, 32) {
      Some(ic) => {
        match @core.Tray::new("libyue-demo-tray", icon=Some(ic)) {
          Ok(t) => {
            t.set_tooltip("libyue", "W20c 托盘演示")
            t.on_click(fn() {
              clicks.val = clicks.val + 1
              note.val = "左键"
            })
            tray.val = Some(t)
            icon_holder.val = Some(ic)
            note.val = "已建(" + t.backend_name() + ")"
          }
          Err(@core.Unsupported) => {
            note.val = "后端不可用"
            ic.free()
          }
          Err(@core.IconLoadFailed) => {
            note.val = "图标加载失败"
            ic.free()
          }
          Err(@core.Backend(msg)) => {
            note.val = "后端失败: " + msg
            ic.free()
          }
        }
      }
      None => note.val = "建图标失败"
    }
  }
  let retip = fn() -> Unit {
    match tray.val {
      Some(t) => {
        t.set_tooltip("libyue", "改过的提示 · W20c")
        note.val = "已改提示"
      }
      None => note.val = "先建托盘"
    }
  }
  let popup = fn() -> Unit {
    match tray.val {
      Some(t) => {
        let picked = t.popup_menu()
        note.val = if picked { "菜单选中" } else { "菜单取消/无菜单" }
      }
      None => note.val = "先建托盘"
    }
  }
  let drop = fn() -> Unit {
    match tray.val {
      Some(t) => {
        t.remove()
        tray.val = None
        match icon_holder.val {
          Some(ic) => ic.free()
          None => ()
        }
        icon_holder.val = None
        note.val = "已移除"
      }
      None => note.val = "先建托盘"
    }
  }
  @ui.view(
    [
      @ui.text(
        "系统托盘（W20c）：建/提示/菜单/弹出/移除；左键与菜单项计数（图标 32px 由像素现建）",
        size=13.0,
      ),
      @ui.row(
        [
          @ui.button("建托盘", on_click=create),
          @ui.button("改提示", on_click=retip),
          @ui.button("挂菜单", on_click=build_menu_and_run),
          @ui.button("弹菜单", on_click=popup),
          @ui.button("移除", on_click=drop),
          @core.node_of(live_counter(
            fn() -> String {
              let state = match tray.val {
                Some(t) => t.backend_name()
                None => "-"
              }
              "supported=" +
              (if @core.Tray::is_supported() { "1" } else { "0" }) +
              " slot=" +
              state +
              " clicks=" +
              clicks.val.to_string() +
              " note=" +
              note.val
            },
            width=460.0,
          )),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// W21a 通知区块：发信息/警告/错误气泡、更新进度、关闭。状态行报后端、已发数、
/// 当前通知 id 与最后一次动作。后端不支持时（macOS 占位）给结构化错误，如实显示。
/// 通知图标句柄由 Ref 持住——气泡在用期间不能 free。
fn make_notify_section(
  nid : Ref[Int],
  sends : Ref[Int],
  note : Ref[String],
  icon_holder : Ref[@win.Icon?],
) -> @core.Node {
  // 通知图标按需现建（像素 32px），建好后挂进 Ref 直到进程退出
  let pick_icon = fn() -> Int {
    match icon_holder.val {
      Some(ic) => ic.handle
      None =>
        match @win.icon_from_bgra(demo_icon_pixels(32), 32, 32) {
          Some(ic) => {
            icon_holder.val = Some(ic)
            ic.handle
          }
          None => 0
        }
    }
  }
  let do_send = fn(kind : Int, title : String, body : String) -> Unit {
    match
      @core.notify_send(
        "libyue 演示",
        title,
        body,
        kind=kind,
        icon_handle=pick_icon(),
      ) {
      Ok(id) => {
        nid.val = id
        sends.val = sends.val + 1
        note.val = "已发#" + id.to_string()
      }
      Err(e) => note.val = "失败: " + e.to_string()
    }
  }
  let info = fn() -> Unit {
    do_send(0, "构建完成", "3 个目标已产出")
  }
  let warn = fn() -> Unit {
    do_send(1, "构建告警", "2 个目标有告警")
  }
  let err = fn() -> Unit {
    do_send(2, "构建失败", "3 个目标失败")
  }
  let progress = fn() -> Unit {
    if nid.val <= 0 {
      note.val = "先发一张"
    } else {
      match @core.notify_progress(nid.val, "libyue 演示", "构建中", "正在编译", 60) {
        Ok(pid) => {
          nid.val = pid
          note.val = "进度 60%"
        }
        Err(e) => note.val = "失败: " + e.to_string()
      }
    }
  }
  let close = fn() -> Unit {
    if nid.val <= 0 {
      note.val = "先发一张"
    } else {
      match @core.notify_close(nid.val) {
        Ok(_) => {
          nid.val = 0
          note.val = "已关闭"
        }
        Err(e) => note.val = "失败: " + e.to_string()
      }
    }
  }
  @ui.view(
    [
      @ui.text(
        "桌面通知（W21a）：发信息/警告/错误气泡 · 更新进度 · 关闭（Win32 托盘气泡；Linux 走 freedesktop）",
        size=13.0,
      ),
      @ui.row(
        [
          @ui.button("发信息", on_click=info),
          @ui.button("发警告", on_click=warn),
          @ui.button("发错误", on_click=err),
          @ui.button("进度 60%", on_click=progress),
          @ui.button("关闭", on_click=close),
          @core.node_of(live_counter(
            fn() -> String {
              "supported=" +
              (if @core.notify_supported() { "1" } else { "0" }) +
              " backend=" +
              @core.notify_backend_name() +
              " sends=" +
              sends.val.to_string() +
              " id=" +
              nid.val.to_string() +
              " note=" +
              note.val
            },
            width=460.0,
          )),
        ],
        column_gap=8.0,
        align_items=@yoga.AlignItems::Center,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// W21c 拖放区块：两个拖源（文本载荷 / 路径载荷）＋两个落点（全收 / 只收路径）。
/// 全自绘、**应用内**拖放，不碰任何平台接口——按下后拖过 4px 阈值才算拖，悬停
/// 时落点描主题主色，松手投递给落点；`accept` 判为拒的落点回调不跑。退出状态行
/// 报起的拖拽次数、投中次数与最近一次投递的载荷描述（真人交互时才对得上数）。
fn make_drag_section(
  drags : Ref[Int],
  drops : Ref[Int],
  last : Ref[String],
) -> @core.Node {
  let describe = fn(d : @core.DragData) -> String {
    match d {
      @core.DragData::Text(t) => "文本(" + t + ")"
      @core.DragData::Html(_) => "HTML"
      @core.DragData::Paths(ps) => "路径×" + ps.length().to_string()
      @core.DragData::Img(bs) => "图片 " + bs.length().to_string() + "B"
    }
  }
  // 拖源/落点的可见内容用「带底色的小盒 + 文案」——拖源里放展示件即可，别放按钮
  // （按钮会先把按下吃掉，拖不动它，见 `ui/drag.mbt` 的约束）
  let chip = fn(text : String, bgv : String) -> @core.Node {
    @ui.view(
      [@ui.text(text, size=12.0)],
      padding=8.0,
      bg=bgv,
      border=@theme.theme_border(),
    )
  }
  let src_text = @ui.drag_source(
    chip("拖我（文本载荷）", @theme.theme_bg_panel()),
    payload=fn() -> @core.DragData? {
      drags.val = drags.val + 1
      Some(@core.DragData::Text("拖源文本"))
    },
  )
  let src_paths = @ui.drag_source(
    chip("拖我（路径载荷）", @theme.theme_bg_panel()),
    payload=fn() -> @core.DragData? {
      drags.val = drags.val + 1
      Some(@core.DragData::Paths(["C:/tmp/a.txt", "C:/tmp/b.txt"]))
    },
  )
  let tgt_all = @ui.drop_target(
    chip("投这里（全收）", @theme.theme_bg_page()),
    on_drop=fn(d : @core.DragData, _x : Double, _y : Double) -> Unit {
      drops.val = drops.val + 1
      last.val = "全收 ← " + describe(d)
    },
  )
  let tgt_paths = @ui.drop_target(
    chip("投这里（只收路径）", @theme.theme_bg_page()),
    accept=fn(d : @core.DragData) -> Bool { d.kind() == @core.FilePaths },
    on_drop=fn(d : @core.DragData, _x : Double, _y : Double) -> Unit {
      drops.val = drops.val + 1
      last.val = "只收路径 ← " + describe(d)
    },
  )
  @ui.view(
    [
      @ui.text(
        "拖放（W21c）：应用内拖放全自绘、三平台同构；拖过 4px 才开拖，悬停落点描主色，松手投递（「只收路径」的落点会拒文本）",
        size=13.0,
      ),
      @ui.row(
        [src_text, src_paths, tgt_all, tgt_paths],
        column_gap=12.0,
        align_items=@yoga.AlignItems::Center,
      ),
      @core.node_of(live_counter(
        fn() -> String {
          "起拖=" +
          drags.val.to_string() +
          " 投中=" +
          drops.val.to_string() +
          " 拖拽中=" +
          (if @core.drag_active() { "1" } else { "0" }) +
          " 悬停=" +
          @core.drag_hover().to_string() +
          " 最近=" +
          last.val
        },
        width=460.0,
      )),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 交互图表区块：折线/柱状/环形三个交互版并排——hover 浮层、图例点击显隐、
/// 滚轮缩放（折线与柱状共用调用方持有的 CiZoom，退出状态行报窗口读数；
/// 环形无缩放）。
fn make_chart_it_section(
  lin : @core.Store[Array[@chart.LineSeries]],
  bars : @core.Store[Array[@chart.BarItem]],
  rings : @core.Store[Array[@chart.DonutSlice]],
  zoom : @chart.CiZoom,
  panel_w : Ref[@core.Widget?],
) -> @core.Node {
  let vals : Array[Double] = []
  for i = 0; i < 60; i = i + 1 {
    vals.push(((i * 17) % 41).to_double() + 3.0)
  }
  lin.set([
    @chart.LineSeries::make("负载", max_points=80).with_points(vals),
    @chart.LineSeries::make("延迟", max_points=80).with_points(
      vals.map(fn(v) { v * 0.6 }),
    ),
  ])
  let bar_items : Array[@chart.BarItem] = []
  for i = 0; i < 18; i = i + 1 {
    bar_items.push(
      @chart.BarItem::make("c\{i}", ((i * 13) % 29).to_double() - 4.0),
    )
  }
  bars.set(bar_items)
  rings.set([
    @chart.DonutSlice::make("已完成", 46.0),
    @chart.DonutSlice::make("进行中", 33.0),
    @chart.DonutSlice::make("待办", 21.0),
  ])
  @ui.view(
    [
      @ui.text(
        "交互图表：hover 浮层 + 图例点击显隐 + 滚轮缩放（退出状态行报缩放窗）",
        size=13.0,
      ),
      @ui.view(
        [
          @chart.line_chart_it(
            lin,
            area=true,
            width=330.0,
            height=130.0,
            zoom_state=Some(zoom),
            handle=fn(w : @core.Widget) -> Unit { panel_w.val = Some(w) },
          ),
          @chart.bar_chart_it(
            bars,
            width=330.0,
            height=130.0,
            zoom_state=Some(zoom),
          ),
          @chart.donut_chart_it(rings, width=210.0, height=130.0),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
        align_items=@yoga.AlignItems::FlexStart,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 专项图区块：箱线/漏斗/热力/雷达四图并排（首批专项平移）。
fn make_chart_special_section(
  sp_w : Ref[@core.Widget?],
  sp2_w : Ref[@core.Widget?],
  sp3_w : Ref[@core.Widget?],
  sp4_w : Ref[@core.Widget?],
) -> @core.Node {
  let box_groups = @core.Store::new([
    ("渲染", [12.0, 14.0, 15.0, 16.0, 18.0, 22.0, 48.0]),
    ("布局", [8.0, 10.0, 12.0, 13.0, 15.0, 17.0, 20.0]),
    ("输入", [20.0, 24.0, 26.0, 30.0, 33.0, 38.0, 90.0]),
  ])
  let funnel_data = @core.Store::new([
    @chart.BarItem::make("构建", 1000.0),
    @chart.BarItem::make("链接", 640.0),
    @chart.BarItem::make("加载", 420.0),
    @chart.BarItem::make("首帧", 180.0),
  ])
  let heat = @core.Store::new(
    @chart.HeatGrid::make(
      ["周一", "周二", "周三", "周四", "周五"],
      ["编译", "测试", "冒烟"],
      [
        [30.0, 42.0, 38.0, 55.0, 20.0],
        [12.0, 18.0, 15.0, 22.0, 8.0],
        [6.0, 9.0, 7.0, 11.0, 4.0],
      ],
    ),
  )
  let radar_inds = @core.Store::new([
    @chart.RadarIndicator::make("速度", 100.0),
    @chart.RadarIndicator::make("精度", 100.0),
    @chart.RadarIndicator::make("稳定", 100.0),
    @chart.RadarIndicator::make("生态", 100.0),
  ])
  let radar_sers = @core.Store::new([
    @chart.RadarSeries::make("本栈", [78.0, 92.0, 70.0, 58.0]),
    @chart.RadarSeries::make("对标", [60.0, 74.0, 86.0, 90.0]),
  ])
  let kline_data = @core.Store::new([
    @chart.Candle::make(10.0, 12.0, 9.0, 11.5),
    @chart.Candle::make(11.5, 13.2, 11.0, 12.8),
    @chart.Candle::make(12.8, 13.5, 11.5, 11.2),
    @chart.Candle::make(11.2, 11.9, 10.3, 11.7),
    @chart.Candle::make(11.7, 12.4, 11.0, 12.1),
    @chart.Candle::make(12.1, 12.6, 10.8, 11.0),
  ])
  let sankey_data = @core.Store::new(
    @chart.SankeyData::make(
      [
        @chart.SankeyNode::make("浏览"),
        @chart.SankeyNode::make("加购"),
        @chart.SankeyNode::make("下单"),
      ],
      [
        @chart.SankeyLink::make(0, 1, 100.0),
        @chart.SankeyLink::make(1, 2, 55.0),
      ],
    ),
  )
  let tm_items = @core.Store::new([
    @chart.TmItem::make("核心", value=52.0),
    @chart.TmItem::make("组件", value=28.0),
    @chart.TmItem::make("图表", value=12.0),
    @chart.TmItem::make("示例", value=8.0),
  ])
  let sun_root_item = @chart.SunItem::make("分布")
  sun_root_item.children.push(@chart.SunItem::make("核心", value=Some(40.0)))
  sun_root_item.children.push(@chart.SunItem::make("组件", value=Some(30.0)))
  sun_root_item.children.push(@chart.SunItem::make("图表", value=Some(20.0)))
  let sun_root = @core.Store::new(sun_root_item)
  let gph_data = @core.Store::new(
    @chart.GraphData::make(
      [
        @chart.GraphNode::make("core", value=30.0),
        @chart.GraphNode::make("ui", value=26.0),
        @chart.GraphNode::make("chart", value=18.0),
      ],
      [
        @chart.GraphEdge::make(0, 1, weight=5.0),
        @chart.GraphEdge::make(1, 2, weight=3.0),
      ],
    ),
  )
  let par_axes = @core.Store::new([
    @chart.ParAxis::make("吞吐"),
    @chart.ParAxis::make("延迟"),
    @chart.ParAxis::make("内存"),
  ])
  let par_rows = @core.Store::new([
    [10.0, 5.0, 40.0],
    [20.0, 3.0, 55.0],
    [15.0, 8.0, 35.0],
  ])
  let eff_points = @core.Store::new([
    @chart.EffPoint::make(1.0, 2.0, size=10.0),
    @chart.EffPoint::make(3.0, 5.0, size=16.0),
    @chart.EffPoint::make(5.0, 3.0, size=8.0),
    @chart.EffPoint::make(7.0, 8.0, size=12.0),
  ])
  let trv_names = @core.Store::new(["构建", "测试", "冒烟"])
  let trv_values = @core.Store::new([
    [4.0, 6.0, 5.0, 8.0, 7.0, 9.0],
    [2.0, 3.0, 5.0, 4.0, 6.0, 5.0],
    [1.0, 2.0, 2.0, 3.0, 2.0, 4.0],
  ])
  let geo_regions = match @chart.geojson_parse(
      "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"示例区\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[100,25],[112,25],[112,36],[100,36]]]}}]}",
    ) {
    Ok(rs) => @core.Store::new(rs)
    Err(_) => @core.Store::new([])
  }
  let pb_data = @core.Store::new([
    @chart.BarItem::make("甲", 24.0),
    @chart.BarItem::make("乙", 15.0),
    @chart.BarItem::make("丙", -9.0),
  ])
  let tree_root_item = @chart.TreeItem::make("yue")
  tree_root_item.children.push(@chart.TreeItem::make("core", value=Some(30.0)))
  tree_root_item.children.push(@chart.TreeItem::make("ui", value=Some(40.0)))
  tree_root_item.children.push(@chart.TreeItem::make("chart", value=Some(20.0)))
  let tree_root = @core.Store::new(tree_root_item)
  @ui.view(
    [
      @ui.text("专项图：箱线/漏斗/热力/雷达（同源自 master，四图并排）", size=13.0),
      @ui.view(
        [
          @chart.boxplot_t(box_groups, width=320.0, height=150.0),
          @chart.funnel_t(funnel_data, width=300.0, height=150.0),
          @chart.heatmap_t(
            heat,
            show_values=true,
            width=280.0,
            height=150.0,
            handle=fn(w : @core.Widget) -> Unit { sp_w.val = Some(w) },
          ),
          @chart.radar_chart_t(radar_inds, radar_sers, width=250.0, height=170.0),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
        align_items=@yoga.AlignItems::FlexStart,
      ),
      @ui.view(
        [
          @chart.candlestick_t(kline_data, width=300.0, height=150.0),
          @chart.sankey_t(
            sankey_data,
            width=300.0,
            height=150.0,
            handle=fn(w : @core.Widget) -> Unit { sp2_w.val = Some(w) },
          ),
          @chart.tm_chart_t(tm_items, width=280.0, height=150.0),
          @chart.tree_chart_t(tree_root, width=250.0, height=150.0),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
        align_items=@yoga.AlignItems::FlexStart,
      ),
      @ui.view(
        [
          @chart.sun_chart_t(sun_root, width=250.0, height=190.0),
          @chart.gph_chart_t(
            gph_data,
            width=260.0,
            height=190.0,
            handle=fn(w : @core.Widget) -> Unit { sp3_w.val = Some(w) },
          ),
          @chart.par_chart_t(par_axes, par_rows, width=280.0, height=190.0),
          @chart.pb_chart_t(
            pb_data,
            symbol=@chart.PbCircle,
            show_values=true,
            width=250.0,
            height=190.0,
          ),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
        align_items=@yoga.AlignItems::FlexStart,
      ),
      @ui.view(
        [
          @chart.eff_chart_t(
            eff_points,
            period_ms=1800,
            width=300.0,
            height=170.0,
            handle=fn(w : @core.Widget) -> Unit { sp4_w.val = Some(w) },
          ),
          @chart.trv_chart_t(
            trv_names,
            trv_values,
            width=300.0,
            height=170.0,
          ),
          @chart.geo_map_t(
            geo_regions,
            flights=[@chart.GeoFlight::make((105.0, 30.0), (120.0, 25.0))],
            width=260.0,
            height=170.0,
          ),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
        align_items=@yoga.AlignItems::FlexStart,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 图表区块：五种通用图并排 + 一颗「推点」按钮（点一次往折线序列推一个点，
/// 退出状态行报窗口长度与末值，回证 Store 驱动的换数据只重绘不重建）。
fn make_chart_section(
  lin : @core.Store[Array[@chart.LineSeries]],
  pushes : Ref[Int],
  btn_slot : Ref[@core.Widget?],
  line_slot : Ref[@core.Widget?],
) -> @core.Node {
  let vals : Array[Double] = []
  for i = 0; i < 24; i = i + 1 {
    vals.push(((i * 13) % 37).to_double() + 4.0)
  }
  lin.set([@chart.LineSeries::make("负载", max_points=40).with_points(vals)])
  let bars = @core.Store::new([
    @chart.BarItem::make("组件", 48.0),
    @chart.BarItem::make("布局", 30.0),
    @chart.BarItem::make("绘制", -12.0),
    @chart.BarItem::make("输入", 22.0),
  ])
  let rings = @core.Store::new([
    @chart.DonutSlice::make("已完成", 52.0),
    @chart.DonutSlice::make("进行中", 31.0),
    @chart.DonutSlice::make("待办", 17.0),
  ])
  let needle = @core.Store::new(0.68)
  let dots = @core.Store::new([
    (1.0, 2.0),
    (2.0, 3.4),
    (3.0, 4.1),
    (4.0, 6.2),
    (5.0, 5.3),
    (6.0, 7.1),
  ])
  @ui.view(
    [
      @ui.text("图表：折线/柱状/环形/仪表/散点全自绘，数据走 Store（退出状态行报推点数）", size=13.0),
      @ui.view(
        [
          @ui.view(
            [
              @chart.line_chart_t(lin, area=true, height=110.0, handle=fn(w : @core.Widget) -> Unit {
                line_slot.val = Some(w)
              }),
              @chart.bar_chart_t(bars, width=250.0, height=110.0),
            ],
            direction=@yoga.Row,
            column_gap=8.0,
            align_items=@yoga.AlignItems::Stretch,
            grow=1.0,
          ),
          @ui.view(
            [
              @chart.donut_chart_t(rings, width=360.0, height=130.0),
              @chart.gauge_t(needle, width=150.0, height=120.0),
              @chart.scatter_t(dots, trend=true, width=250.0, height=130.0),
              @ui.button(
                "推点",
                on_click=fn() -> Unit {
                  pushes.val = pushes.val + 1
                  @chart.series_push(lin, 0, (pushes.val * 7 % 29).to_double() + 2.0)
                },
                variant=@ui.Border,
                min_width=64.0,
                handle=fn(w : @core.Widget) -> Unit { btn_slot.val = Some(w) },
              ),
            ],
            direction=@yoga.Row,
            column_gap=8.0,
            align_items=@yoga.AlignItems::Center,
          ),
        ],
        direction=@yoga.Column,
        row_gap=8.0,
        align_items=@yoga.AlignItems::Stretch,
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 虚拟表格演示数据：200 行（几何验证页只挂可见的十来行）。
fn make_virt_rows() -> Array[@ui.TableRow] {
  let out : Array[@ui.TableRow] = []
  for i = 0; i < 200; i = i + 1 {
    out.push(
      @ui.TableRow::make([
        "虚拟行 " + i.to_string(),
        (i * 7 % 100).to_string(),
        if i % 2 == 0 { "就绪" } else { "排队" },
      ]),
    )
  }
  out
}

///|
/// 虚拟表格区块：200 行只挂可见区间，滚轮/滚动条驱动同一份偏移。
fn make_virt_section(
  rows : @core.Store[Array[@ui.TableRow]],
  sel : @core.Store[Array[Int]],
  sort : @core.Store[@ui.TableSort],
  clicks : Ref[Int],
  slot : Ref[@core.Widget?],
) -> @core.Node {
  @ui.view(
    [
      @ui.text("虚拟表格：200 行只挂可见区间（滚轮 / 拖滚动条，退出状态行报挂载数）", size=13.0),
      @ui.table_v(
        [
          @ui.TableColumn::make("名称", 160.0),
          @ui.TableColumn::make("数值", 100.0, align=@text.End),
          @ui.TableColumn::make("状态", 0.0, sortable=false),
        ],
        rows,
        width=400.0,
        height=210.0,
        row_height=30.0,
        selection=sel,
        sort=sort,
        on_row_click=fn(_i : Int, _r : @ui.TableRow) -> Unit { clicks.val = clicks.val + 1 },
        handle=fn(w : @core.Widget) -> Unit { slot.val = Some(w) },
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 表格演示数据（6 行 4 列）。
fn make_table_rows() -> Array[@ui.TableRow] {
  let out : Array[@ui.TableRow] = []
  for i = 1; i <= 6; i = i + 1 {
    out.push(
      @ui.TableRow::make([
        "组件 " + i.to_string(),
        (i * 12).to_string() + " 处",
        if i % 3 == 0 { "待修" } else { "通过" },
        "批次 " + (i % 2 + 1).to_string(),
      ]),
    )
  }
  out
}

///|
/// 表格区块：表头可排序、行可点选（选择与排序都写 Store，示例在退出状态行报出来）。
fn make_table_section(
  rows : @core.Store[Array[@ui.TableRow]],
  sel : @core.Store[Array[Int]],
  sort : @core.Store[@ui.TableSort],
  slot : Ref[@core.Widget?],
) -> @core.Node {
  @ui.view(
    [
      @ui.text("表格：点表头排序（新列升序 / 同列翻转 / 第三次取消）、点行选中", size=13.0),
      @ui.table(
        [
          @ui.TableColumn::make("组件", 140.0),
          @ui.TableColumn::make("规模", 100.0, align=@text.End),
          @ui.TableColumn::make("状态", 100.0),
          @ui.TableColumn::make("批次", 0.0, sortable=false),
        ],
        rows,
        width=520.0,
        selection=sel,
        sort=sort,
        handle=fn(w : @core.Widget) -> Unit { slot.val = Some(w) },
      ),
    ],
    padding=8.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::FlexStart,
    bg=@theme.theme_bg_page(),
    border=@theme.theme_border(),
  )
}

///|
/// 滚动容器里的 20 行内容（每行 22 高 → 内容 440，视口 120，可滚 320）。
fn make_scroll_rows() -> Array[@core.Node] {
  let rows : Array[@core.Node] = []
  for i = 0; i < 20; i = i + 1 {
    rows.push(
      @ui.view(
        [@ui.text("滚动行 " + i.to_string(), size=12.0)],
        height=22.0,
        padding=4.0,
        bg=if i % 2 == 0 {
          @theme.theme_bg_panel()
        } else {
          @theme.theme_fill_zebra()
        },
      ),
    )
  }
  rows
}

///|
/// 矩形转字符串（几何行用，四舍五入到整像素）。
fn rect_str(r : @core.Rect) -> String {
  r.x.round().to_int().to_string() +
    "," +
    r.y.round().to_int().to_string() +
    "," +
    r.w.round().to_int().to_string() +
    "x" +
    r.h.round().to_int().to_string()
}

///|
/// 主窗尺寸。**高 900 而不是「一屏装下整页」的 3520**：本页把十几页叠成一根
/// 数千像素高的长柱，早先直接开 3520 高（整页一屏可见），但那等于每帧都重画
/// 1400×3520 ≈ 490 万像素——真机实测单帧 300–500ms，而输入只能排在一帧之后，
/// 于是滚动/点击/悬浮全像卡住。`enable_root_scroll` 落地后长柱本来就能滚到，
/// 3520 这个尺寸只剩代价没有收益：降到 900（贴常见屏高）后每帧只画 126 万像素
/// （视口剔除只画屏内那部分），要「一屏看全」把这里改回 3520 即可。
const APP_WIN_W : Int = 1400
const APP_WIN_H : Int = 900

///|
fn main {
  // 输入框的 Ctrl+C/X/V 接系统剪贴板（默认关：测试里的 Ctrl+X 不该动使用者
  // 的剪贴板）；探测不可用（Linux 无 xclip 等）时自动保持内部剪贴板
  @ui.use_system_clipboard(true)
  let app = match @core.App::new(APP_WIN_W, APP_WIN_H, "MoonBit App 宿主 (批次1)") {
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
    closed: 0,
  }
  let root = app.root
  root.set_column()
  ctr.fam_count = match @text.families() {
    Some(list) => list.length()
    None => 0
  }
  ctr.use_family = @text.resolve_family(["绝对没有的族 Qzz", "monospace"])
  root.set_padding(top=12.0, left=16.0)
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
  // 批 A（多窗口宿主）：一宿主管 N 窗——每窗一棵控件树、一套焦点栈与输入法
  // 状态，共用同一个 Loop 与平台泵。开一扇「关于」窗：窗里的按钮只加**那扇窗**
  // 的计数、输入框只进那扇窗的焦点栈；关掉它主窗照旧活着。
  let mw_opened : Ref[Int] = Ref(0)
  let mw_closes : Ref[Int] = Ref(0)
  let mw_sub_clicks : Ref[Int] = Ref(0)
  let mw_main_clicks : Ref[Int] = Ref(0)
  let mw_sub_btn : Ref[@core.Widget?] = Ref(None)
  let mw_sub_close : Ref[@core.Widget?] = Ref(None)
  let mw_sub_entry : Ref[@core.Widget?] = Ref(None)
  let mw_sub_entry_max : Ref[Int] = Ref(0)
  let mw_open_btn : Ref[@core.Widget?] = Ref(None)
  let mw_sub_win : Ref[@core.App?] = Ref(None)
  let mw_sub_text : Ref[@core.Store[String]] = Ref(@core.Store::new(""))
  let open_about = fn(a : @core.App) -> Unit {
    match a.open_window(480, 300, "关于（第二窗）") {
      None => ()
      Some(win) => {
        mw_opened.val = mw_opened.val + 1
        mw_sub_win.val = Some(win)
        let mine : Ref[Int] = Ref(0)
        // 每窗自己的状态：两扇关于窗各持一份文本，不共用一个 Store
        let sub_text = @core.Store::new("")
        mw_sub_text.val = sub_text
        win.root.set_column()
        win.root.set_padding(top=12.0, left=16.0)
        win.root.on_draw = Some(fn(
          _w : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(@theme.theme_bg_page())
          p.fill_rect(0.0, 0.0, r.w, r.h)
        })
        // 本窗自己的焦点栈：101 只登记在这扇窗上
        let _ = win.focus.register(101)
        win.mount([
          @ui.text("关于窗：自己的控件树与焦点栈，共用宿主的循环与泵", size=13.0),
          @core.node_of(live_counter(fn() -> String {
            "本窗点击 " +
            mine.val.to_string() +
            " / 在窗 " +
            a.window_count().to_string() +
            " / 主窗点击 " +
            mw_main_clicks.val.to_string()
          }, width=440.0)),
          @ui.button(
            "点我计数（只加本窗）",
            on_click=fn() {
              mine.val = mine.val + 1
              mw_sub_clicks.val = mw_sub_clicks.val + 1
            },
            min_width=180.0,
            handle=fn(w : @core.Widget) -> Unit { mw_sub_btn.val = Some(w) },
          ),
          @ui.input(
            sub_text,
            placeholder="字打进这扇窗的栈里",
            focus_id=101,
            width=280.0,
            on_change=fn(t : String) -> Unit {
              if t.length() > mw_sub_entry_max.val {
                mw_sub_entry_max.val = t.length()
              }
            },
            handle=fn(w : @core.Widget) -> Unit { mw_sub_entry.val = Some(w) },
          ),
          @ui.button(
            "关闭这扇窗（主窗继续活着）",
            on_click=fn() {
              mw_closes.val = mw_closes.val + 1
              win.close_window()
            },
            min_width=180.0,
            handle=fn(w : @core.Widget) -> Unit { mw_sub_close.val = Some(w) },
          ),
        ])
      }
    }
  }
  app.mount([
    @ui.view(
      [
        @ui.text("多窗口（批 A）", size=13.0),
        @core.node_of(live_counter(fn() -> String {
          "在窗 " +
          app.window_count().to_string() +
          " / 开过 " +
          mw_opened.val.to_string() +
          " / 已关 " +
          mw_closes.val.to_string() +
          " / 主窗点击 " +
          mw_main_clicks.val.to_string() +
          " / 关于窗点击 " +
          mw_sub_clicks.val.to_string()
        })),
        @ui.button(
          "开一扇关于窗",
          on_click=fn() { open_about(app) },
          min_width=160.0,
          handle=fn(w : @core.Widget) -> Unit { mw_open_btn.val = Some(w) },
        ),
        @ui.button(
          "主窗计数（对照）",
          on_click=fn() { mw_main_clicks.val = mw_main_clicks.val + 1 },
          min_width=160.0,
        ),
      ],
      direction=@yoga.Row,
      column_gap=8.0,
      padding=6.0,
      bg=@theme.theme_bg_panel(),
      border=@theme.theme_border(),
    ),
  ])
  // 批次 5b（组件层首批）：一行全用 @ui 构造器，按钮经 store 计数。
  app.mount([
    @ui.view(
      [
        @ui.text("组件层", size=13.0),
        @ui.divider(vertical=true),
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
    @ui.view(
      [
        @ui.checkbox("同意", agreed),
        @ui.switch(sound, on_text="开", off_text="关"),
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
  // 批次 6a（显示族首批）：标签 / 徽标 / 头像 / 分隔线 / 提示条 / 折线进度。
  app.mount([
    @ui.view(
      [
        @ui.view(
          [
            @ui.tag_of_type("主色", @ui.Primary),
            @ui.tag_of_type("成功", @ui.Success),
            @ui.tag("自定色", @theme.theme_danger()),
            @ui.badge_count(7),
            @ui.badge_count(150),
            @ui.badge_dot(),
            @ui.avatar("刘"),
          ],
          direction=@yoga.Row,
          column_gap=6.0,
          align_items=@yoga.AlignItems::Center,
        ),
        @ui.divider(text="或"),
        @ui.alert(
          "提示条",
          description="关闭热区在右上角 24×24",
          t=@ui.Warning,
          closable=true,
          on_close=fn() { ctr.closed = ctr.closed + 1 },
        ),
        @ui.progress_line(level, max=100.0, width=300.0),
      ],
      padding=8.0,
      row_gap=8.0,
      bg=@theme.theme_bg_page(),
      border=@theme.theme_border(),
    ),
  ])
  // 批次 6b（显示族收尾）+ 6c（日期族首批）：三列并排——时间线一列、两条轮播
  // 一列、日历一列（并排是为了把整页压回一屏高，注入坐标仍按几何行取）。
  // 手动轮播 `interval_ms=0`（切页只由注入点击决定，退出状态才确定）；自转轮播
  // `interval_ms=800` 走宿主的进程级延时通道，示例每帧采样下标计次。
  let spin = @ui.CarouselHandle::make()
  let auto = @ui.CarouselHandle::make()
  let car_sample : Ref[(Int, Int)] = Ref((0, 0))
  let car_w : Ref[@core.Widget?] = Ref(None)
  let auto_w : Ref[@core.Widget?] = Ref(None)
  let picked_date : @core.Store[@ui.DateYMD?] = @core.Store::new(None)
  let cal_w : Ref[@core.Widget?] = Ref(None)
  let nav_seg : Ref[@core.Widget?] = Ref(None)
  let nav_crumb : Ref[@core.Widget?] = Ref(None)
  let nav_page : Ref[@core.Widget?] = Ref(None)
  let nav_fold : Ref[@core.Widget?] = Ref(None)
  let seg_sel = @core.Store::new("分段甲")
  let crumb_sel = @core.Store::new("首页")
  let page_cur = @core.Store::new(1)
  let step_cur = @core.Store::new(1)
  let menu_sel = @core.Store::new("首页")
  let tab_sel = @core.Store::new(0)
  let nav2_menu : Ref[@core.Widget?] = Ref(None)
  let nav2_tree : Ref[@core.Widget?] = Ref(None)
  let nav2_tabs : Ref[@core.Widget?] = Ref(None)
  let xfer_left = @core.Store::new(["甲", "乙", "丙"])
  let xfer_right : @core.Store[Array[String]] = @core.Store::new(["丁"])
  let nav2_xfer : Ref[@core.Widget?] = Ref(None)
  let scr = @ui.ScrollState::new()
  let scr_w : Ref[@core.Widget?] = Ref(None)
  let ov_pick = Ref(0)
  let ov_dd : Ref[@core.Widget?] = Ref(None)
  let ov_pop : Ref[@core.Widget?] = Ref(None)
  let ov_tip : Ref[@core.Widget?] = Ref(None)
  let dlg_open = @core.Store::new(false)
  let dlg_ok = Ref(0)
  let ctx_pick = Ref(0)
  let toast_n = Ref(0)
  let ov2_dlgbtn : Ref[@core.Widget?] = Ref(None)
  let ov2_ctx : Ref[@core.Widget?] = Ref(None)
  let ov2_toastbtn : Ref[@core.Widget?] = Ref(None)
  let toast_push = @ui.toast_layer(duration_ms=2000)
  let dpk : @core.Store[@ui.DateYMD?] = @core.Store::new(None)
  let drg : @core.Store[@ui.DateRange] = @core.Store::new({ start: None, end: None })
  let trg : @core.Store[@ui.TimeRange] = @core.Store::new({ start: None, end: None })
  let dpk_w : Ref[@core.Widget?] = Ref(None)
  let drg_w : Ref[@core.Widget?] = Ref(None)
  let trg_w : Ref[@core.Widget?] = Ref(None)
  // 表头点击只切「排序状态」这个 Store（组件**不替使用方排序**，口径见
  // ui/table.mbt 的 TableSort 注释）——不订阅它把行序写回去，表头箭头会动、
  // 行序不动（真机反馈的「表格排序不生效」正是漏了这一步）。`sort_rows` 是
  // 组件给的参考口径（前导数字优先比数值 + 稳定），一行接线即可。
  let tb_base = make_table_rows()
  let tb_rows = @core.Store::new(tb_base)
  let tb_sel : @core.Store[Array[Int]] = @core.Store::new([])
  let tb_sort : @core.Store[@ui.TableSort] = @core.Store::new({ column: -1, asc: true })
  let tb_w : Ref[@core.Widget?] = Ref(None)
  let _ = tb_sort.signal().subscribe(fn(s : @ui.TableSort) -> Unit {
    tb_rows.set(@ui.sort_rows(tb_base, s))
  })
  let vt_base = make_virt_rows()
  let vt_rows = @core.Store::new(vt_base)
  let vt_sel : @core.Store[Array[Int]] = @core.Store::new([])
  let vt_sort : @core.Store[@ui.TableSort] = @core.Store::new({ column: -1, asc: true })
  let vt_clicks = Ref(0)
  let vt_w : Ref[@core.Widget?] = Ref(None)
  let _ = vt_sort.signal().subscribe(fn(s : @ui.TableSort) -> Unit {
    vt_rows.set(@ui.sort_rows(vt_base, s))
  })
  let sticky = @ui.StickyList::new()
  let sticky_w : Ref[@core.Widget?] = Ref(None)
  let spl_w : Ref[@core.Widget?] = Ref(None)
  let frm_btn = Ref(0)
  let frm_lnk = Ref(0)
  let frm_rate = @core.Store::new(0)
  let frm_err = @core.Store::new("")
  let frm_btn_w : Ref[@core.Widget?] = Ref(None)
  let frm_row_w : Ref[@core.Widget?] = Ref(None)
  let frm_link_w : Ref[@core.Widget?] = Ref(None)
  let frm_rate_w : Ref[@core.Widget?] = Ref(None)
  let frm_item_w : Ref[@core.Widget?] = Ref(None)
  let frm_sel = @core.Store::new("")
  let frm_col = @core.Store::new("")
  let frm_ta_w : Ref[@core.Widget?] = Ref(None)
  let frm_sel_w : Ref[@core.Widget?] = Ref(None)
  let frm_col_w : Ref[@core.Widget?] = Ref(None)
  let frm_ov_max = Ref(0)
  let frm_pick = Ref("-")
  let frm_cmb = @core.Store::new("")
  let frm_cmb_w : Ref[@core.Widget?] = Ref(None)
  // 八行内容：76 高的框只放得下三行半，超出部分靠滚动（滚轮 / 滚动条）
  let frm_ta = @core.Store::new("行 1\n行 2\n行 3\n行 4\n行 5\n行 6\n行 7\n行 8")
  app.mount([make_table_section(tb_rows, tb_sel, tb_sort, tb_w)])
  app.mount([make_virt_section(vt_rows, vt_sel, vt_sort, vt_clicks, vt_w)])
  app.mount([make_sticky_section(sticky, sticky_w)])
  app.mount([make_split_section(spl_w)])
  let dcl_n = @core.Store::new(0)
  let dcl_card_w : Ref[@core.Widget?] = Ref(None)
  let dcl_label_w : Ref[@core.Widget?] = Ref(None)
  let dcl_w0_ref : Ref[Double] = Ref(-1.0)
  // 光标形状下发计数：手型 / 文本形 / 横向调整 / 纵向调整各被采到几拍
  let cur_seen : Ref[(Int, Int, Int, Int)] = Ref((0, 0, 0, 0))
  app.mount([make_decl_section(dcl_n, dcl_card_w, dcl_label_w)])
  let gif_h = @ui.GifHandle::make()
  let ib_hits = Ref(0)
  let gif_w : Ref[@core.Widget?] = Ref(None)
  let ib_w : Ref[@core.Widget?] = Ref(None)
  app.mount([make_media_section(gif_h, ib_hits, gif_w, ib_w)])
  // W20b（全局快捷键）：注册两个组合（较冷门，避免与系统/别的程序冲突）。
  // 注册失败（被占用/后端不支持）也照挂区块，退出状态行如实报 id=0。
  // W22 起改走 `@core.hotkey_*` 跨平台门面（回查表在门面里，状态行直接问它）。
  let hotkey_hits = Ref(0)
  let hotkey_last : Ref[String] = Ref("-")
  let hotkey_ids : Ref[(Int, Int)] = Ref((0, 0))
  for kv in [("Ctrl+Alt+F9", 0), ("Ctrl+Alt+F10", 1)] {
    match @core.hotkey_register(kv.0) {
      Ok(hk) =>
        if kv.1 == 0 {
          hotkey_ids.val = (hk.id, hotkey_ids.val.1)
        } else {
          hotkey_ids.val = (hotkey_ids.val.0, hk.id)
        }
      Err(_) => ()
    }
  }
  app.mount([make_hotkey_section(hotkey_hits, hotkey_last)])
  // §6.3（任务栏进度）：七个写入口按钮 + 退出状态行报后端可用性与最近一次操作。
  let taskbar_last : Ref[String] = Ref("-")
  app.mount([make_taskbar_section(app, taskbar_last)])
  // W20d（原生消息框）：按钮触发，退出状态行报弹框次数与最近一次的返回标签。
  let msgbow_shots = Ref(0)
  let msgbow_last : Ref[String] = Ref("-")
  app.mount([make_message_box_section(msgbow_last, msgbow_shots)])
  // W21b（自绘消息框）：三个 Store 各驱动一个自绘消息框；响应编号落状态行。
  // 另快照运行中的浮层数（关窗后浮层栈已清，退出时读不到真值，见 W20c 的坑）。
  let mb_shots = Ref(0)
  let mb_last : Ref[String] = Ref("-")
  let mb_vis_info = @core.Store::new(false)
  let mb_vis_warn = @core.Store::new(false)
  let mb_vis_err = @core.Store::new(false)
  let mb_ovl_snap : Ref[Int] = Ref(0)
  app.mount([
    make_drawn_message_box_section(
      mb_vis_info,
      mb_vis_warn,
      mb_vis_err,
      mb_last,
      mb_shots,
    ),
  ])
  // W20a（原生菜单栏）：MenuBar 模型翻译成 Win32 原生菜单挂到主窗。菜单点击经
  // WM_COMMAND 回收，宿主每拍调 `dispatch_menu_command` 派发到模型回调。
  // 后端不支持时 apply 返回 false，区块照挂（状态行如实报「未挂载」）。
  let menu_hits = Ref(0)
  let menu_last : Ref[String] = Ref("-")
  let menu_bar = build_demo_menu_bar(menu_hits, menu_last)
  let menu_applied = Ref(false)
  // 菜单挂到 App 持有的那扇原生窗（App.window 是只读公开字段）
  if menu_bar.apply_to(app.window) {
    menu_applied.val = true
  }
  app.mount([make_menu_section(menu_hits, menu_last, menu_applied)])
  // W20e（窗口增强）：最小尺寸挂载时设好（不挡点击点位），标题/图标/无边框/
  // 拖拽带由区块按钮触发；图标句柄由 Ref 持住（窗口显示期间不能 free）。
  let win_icon : Ref[@win.Icon?] = Ref(None)
  // 退出状态行在窗口关闭后才打印，那时后端槽已清空、现场读数全是 0。故每拍把
  // 窗口增强的现场读数快照进这个串，退出时打印最后一份「活着时的」读数。
  let win_snap : Ref[String] = Ref("-")
  app.window.set_min_size(900, 600)
  app.mount([make_window_section(app, win_icon)])
  // W20c（系统托盘）：Win32 走 Shell_NotifyIconW，Linux 走 SNI。左键/菜单项由
  // 主循环每拍 `dispatch_tray_event` 抽（与菜单命令同制）。托盘图标句柄由
  // Ref 持住——托盘在用期间不能 free。
  let tray : Ref[@core.Tray?] = Ref(None)
  let tray_note : Ref[String] = Ref("-")
  let tray_clicks = Ref(0)
  let tray_icon : Ref[@win.Icon?] = Ref(None)
  app.mount([make_tray_section(tray, tray_note, tray_clicks, tray_icon)])
  // W21a（桌面通知）：Win32 走托盘气泡（NIF_INFO），Linux 走 freedesktop 通知。
  // 通知 id 是后端内不透明的（Win32 = 托盘槽号、Linux = 服务端 u32），由 Ref 持住
  // 供「改进度 / 关闭」复用；`notify_snap` 每拍快照后端侧在用数（关窗后槽表清空，
  // 退出时读不到真值）。图标句柄同样 Ref 持住——气泡在用期间不能 free。
  let nid = Ref(0)
  let notify_sends = Ref(0)
  let notify_note : Ref[String] = Ref("-")
  let notify_icon : Ref[@win.Icon?] = Ref(None)
  let notify_snap : Ref[String] = Ref("-")
  app.mount([make_notify_section(nid, notify_sends, notify_note, notify_icon)])
  // W21c（拖放）：两个拖源 + 两个落点。全自绘、应用内拖放，拖源/落点都只是普通
  // 控件树节点，指针路由由宿主一并处理——不需要任何平台接口（跨应用系统级拖放
  // 随平台批，接口形状已定）。
  let drag_drags = Ref(0)
  let drag_drops = Ref(0)
  let drag_last : Ref[String] = Ref("-")
  app.mount([make_drag_section(drag_drags, drag_drops, drag_last)])
  let ch_lin = @core.Store::new([])
  let ch_pushes = Ref(0)
  let ch_btn_w : Ref[@core.Widget?] = Ref(None)
  let ch_line_w : Ref[@core.Widget?] = Ref(None)
  app.mount([make_chart_section(ch_lin, ch_pushes, ch_btn_w, ch_line_w)])
  let it_lin = @core.Store::new([])
  let it_bars = @core.Store::new([])
  let it_rings = @core.Store::new([])
  let it_zoom = @chart.ci_zoom_make()
  let it_panel_w : Ref[@core.Widget?] = Ref(None)
  app.mount([
    make_chart_it_section(it_lin, it_bars, it_rings, it_zoom, it_panel_w),
  ])
  let sp_w : Ref[@core.Widget?] = Ref(None)
  let sp2_w : Ref[@core.Widget?] = Ref(None)
  let sp3_w : Ref[@core.Widget?] = Ref(None)
  let sp4_w : Ref[@core.Widget?] = Ref(None)
  app.mount([make_chart_special_section(sp_w, sp2_w, sp3_w, sp4_w)])
  let cv_w : Ref[@core.Widget?] = Ref(None)
  let md_w : Ref[@core.Widget?] = Ref(None)
  app.mount([
    @ui.view(
      [
        @ui.text("Markdown：17 种 block + GFM（代码块复用 code_view、链接走 on_link 回调）", size=13.0),
        @ui.view(
          [
            @mdview.markdown_view(
              "# 原生 GUI 栈\n\n段落含 **粗体**、*斜体*、~~删除线~~、`行内码` 与 [链接](https://moonbit-libyue.pages.dev)。\n\n- 无序项\n- [ ] 待办\n- [x] 已办\n\n1. 第一\n2. 第二\n\n> 引用块一行\n\n```moonbit\nfn main {\n  println(\"hi\")\n}\n```\n\n| 列甲 | 列乙 |\n| --- | ---: |\n| a | 1 |\n\n---\n\n术语\n: 定义\n\n脚注引用[^n1]。\n\n[^n1]: 脚注定义一行",
              width=420.0,
              handle=fn(w : @core.Widget) -> Unit { md_w.val = Some(w) },
            ),
          ],
          direction=@yoga.Row,
          column_gap=8.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      padding=8.0,
      row_gap=6.0,
      align_items=@yoga.AlignItems::FlexStart,
      bg=@theme.theme_bg_page(),
      border=@theme.theme_border(),
    ),
  ])
  app.mount([
    @ui.view(
      [
        @ui.text("代码高亮：tokenize 多语言 + code_view 深底自绘", size=13.0),
        @ui.view(
          [
            @ui.code_view(
              [
                "fn chart_zoom(anchor : Double) -> Double {",
                "  let frac = anchor / 100.0",
                "  // 像素分数映射到窗口百分比",
                "  frac * span()",
                "}",
              ],
              lang="moonbit",
              line_numbers=true,
              handle=fn(w : @core.Widget) -> Unit { cv_w.val = Some(w) },
            ),
            @ui.code_view(
              [
                "def layout(node, depth):",
                "    for child in node.children:",
                "        yield measure(child, depth)",
              ],
              lang="python",
            ),
          ],
          direction=@yoga.Row,
          column_gap=8.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      padding=8.0,
      row_gap=6.0,
      align_items=@yoga.AlignItems::FlexStart,
      bg=@theme.theme_bg_page(),
      border=@theme.theme_border(),
    ),
  ])
  app.mount([
    make_form_section(
      frm_btn,
      frm_lnk,
      frm_rate,
      frm_err,
      frm_btn_w,
      frm_row_w,
      frm_link_w,
      frm_rate_w,
      frm_item_w,
      frm_sel,
      frm_col,
      frm_pick,
      frm_ta,
      frm_ta_w,
      frm_cmb,
      frm_cmb_w,
      frm_sel_w,
      frm_col_w,
    ),
  ])
  app.mount([
    @ui.view(
      [
        @ui.view(
          [
            @ui.text("显示族收尾", size=13.0),
            @ui.timeline(
              [
                ("构建", "编译通过", @ui.Success),
                ("打包", "静态库就位", @ui.Info),
                ("发布", "已上线", @ui.Danger),
              ],
              item_height=44.0,
            ),
          ],
          width=180.0,
          row_gap=6.0,
          padding=6.0,
          bg=@theme.theme_bg_panel(),
          border=@theme.theme_border(),
        ),
        @ui.view(
          [
            @ui.carousel(
              [
                @ui.text("轮播第一页：点右侧箭头或末指示点", size=13.0),
                @ui.text("轮播第二页", size=13.0),
                @ui.text("轮播第三页", size=13.0),
                @ui.text("轮播第四页", size=13.0),
              ],
              width=340.0,
              height=56.0,
              interval_ms=0,
              rotation=spin,
              handle=fn(w : @core.Widget) -> Unit { car_w.val = Some(w) },
            ),
            @ui.carousel(
              [
                @ui.text("自转页 A", size=13.0),
                @ui.text("自转页 B", size=13.0),
                @ui.text("自转页 C", size=13.0),
              ],
              width=200.0,
              height=36.0,
              interval_ms=800,
              rotation=auto,
              handle=fn(w : @core.Widget) -> Unit { auto_w.val = Some(w) },
            ),
          ],
          width=356.0,
          row_gap=6.0,
          padding=6.0,
          align_items=@yoga.AlignItems::FlexStart,
          bg=@theme.theme_bg_page(),
          border=@theme.theme_border(),
        ),
        @ui.view(
          [
            @ui.text("日期族首批", size=13.0),
            @ui.text_dyn(
              picked_date.signal().map(fn(v : @ui.DateYMD?) -> String {
                match v {
                  Some(x) => "已选 " + x.format()
                  None => "未选"
                }
              }),
              size=13.0,
            ),
            @ui.calendar(
              value=picked_date,
              today=@ui.today_date(),
              handle=fn(w : @core.Widget) -> Unit { cal_w.val = Some(w) },
            ),
          ],
          width=284.0,
          row_gap=6.0,
          padding=6.0,
          align_items=@yoga.AlignItems::FlexStart,
          bg=@theme.theme_bg_panel(),
          border=@theme.theme_border(),
        ),
        @ui.view(
          [
            @ui.text("导航族首批", size=13.0),
            @ui.segmented(
              ["分段甲", "分段乙"],
              seg_sel,
              handle=fn(w : @core.Widget) -> Unit { nav_seg.val = Some(w) },
            ),
            @ui.breadcrumb(
              ["首页", "列表", "详情"],
              crumb_sel,
              handle=fn(w : @core.Widget) -> Unit { nav_crumb.val = Some(w) },
            ),
            @ui.pagination(
              page_cur,
              4,
              handle=fn(w : @core.Widget) -> Unit { nav_page.val = Some(w) },
            ),
            @ui.steps(["下单", "付款", "发货"], step_cur),
            @ui.collapse(
              [
                ("折叠一", [@ui.text("第一块内容", size=12.0)]),
                ("折叠二", [@ui.text("第二块内容", size=12.0)]),
              ],
              handle=fn(w : @core.Widget) -> Unit { nav_fold.val = Some(w) },
            ),
          ],
          width=300.0,
          row_gap=6.0,
          padding=6.0,
          align_items=@yoga.AlignItems::FlexStart,
          bg=@theme.theme_bg_page(),
          border=@theme.theme_border(),
        ),
      ],
      direction=@yoga.Row,
      column_gap=8.0,
      padding=8.0,
      align_items=@yoga.AlignItems::FlexStart,
      bg=@theme.theme_bg_page(),
      border=@theme.theme_border(),
    ),
    // 第二排：浮层 / 滚动 / 导航族次批（竖屏 1440 宽放不下七列）
    @ui.view(
      [
        @ui.view(
          [
            @ui.text("浮层首批", size=13.0),
            @ui.dropdown(
              "操作",
              ["重命名", "复制", "-", "删除"],
              on_select=fn(i : Int) -> Unit { ov_pick.val = i + 1 },
              handle=fn(w : @core.Widget) -> Unit { ov_dd.val = Some(w) },
            ),
            @ui.popover(
              @ui.button("气泡", min_width=70.0),
              @ui.view(
                [@ui.text("气泡内容", size=12.0), @ui.text("点外面收起", size=11.0)],
                padding=6.0,
                row_gap=4.0,
              ),
              width=130.0,
              handle=fn(w : @core.Widget) -> Unit { ov_pop.val = Some(w) },
            ),
            @ui.tooltip(
              @ui.button("悬我", min_width=70.0),
              "延时 500ms 的自绘气泡",
              delay_ms=300,
              handle=fn(w : @core.Widget) -> Unit { ov_tip.val = Some(w) },
            ),
          ],
          width=180.0,
          row_gap=8.0,
          padding=6.0,
          align_items=@yoga.AlignItems::FlexStart,
          bg=@theme.theme_bg_page(),
          border=@theme.theme_border(),
        ),
        @ui.view(
          [
            @ui.text("滚动容器", size=13.0),
            @ui.scroll_view(
              make_scroll_rows(),
              scr,
              width=190.0,
              height=120.0,
              handle=fn(w : @core.Widget) -> Unit { scr_w.val = Some(w) },
            ),
            @ui.text("滚轮 / 拖滚动条都改偏移（退出状态行报 scr=偏移/上限）", size=12.0),
          ],
          width=210.0,
          row_gap=6.0,
          padding=6.0,
          align_items=@yoga.AlignItems::FlexStart,
          bg=@theme.theme_bg_page(),
          border=@theme.theme_border(),
        ),
        @ui.view(
          [
            @ui.text("导航族次批", size=13.0),
            @ui.menu(
              ["首页", "报表", "设置"],
              menu_sel,
              icons=[("报表", @icons.IconKind::Box)],
              width=190.0,
              handle=fn(w : @core.Widget) -> Unit { nav2_menu.val = Some(w) },
            ),
            @ui.tree(
              [
                {
                  label: "构建产物",
                  children: [
                    { label: "libyue 静态库", children: [] },
                    { label: "桩与 prebuild", children: [] },
                  ],
                },
                { label: "只读叶子", children: [] },
              ],
              handle=fn(w : @core.Widget) -> Unit { nav2_tree.val = Some(w) },
            ),
            @ui.transfer(
              xfer_left,
              xfer_right,
              width=64.0,
              handle=fn(w : @core.Widget) -> Unit { nav2_xfer.val = Some(w) },
            ),
            @ui.tabs(
              [
                ("页一", @ui.text("页一内容：随页签切换显隐", size=12.0)),
                ("页二", @ui.text("页二内容", size=12.0)),
              ],
              selected=tab_sel,
              handle=fn(w : @core.Widget) -> Unit { nav2_tabs.val = Some(w) },
            ),
          ],
          width=210.0,
          row_gap=6.0,
          padding=6.0,
          align_items=@yoga.AlignItems::FlexStart,
          bg=@theme.theme_bg_panel(),
          border=@theme.theme_border(),
        ),
        @ui.view(
          [
            @ui.text("日期族选择器", size=13.0),
            @ui.date_picker(
              dpk,
              today=@ui.today_date(),
              width=180.0,
              handle=fn(w : @core.Widget) -> Unit { dpk_w.val = Some(w) },
            ),
            @ui.date_range_picker_t(
              drg,
              today=@ui.today_date(),
              width=220.0,
              handle=fn(w : @core.Widget) -> Unit { drg_w.val = Some(w) },
            ),
            @ui.time_range_picker_t(
              trg,
              width=100.0,
              handle=fn(w : @core.Widget) -> Unit { trg_w.val = Some(w) },
            ),
          ],
          width=250.0,
          row_gap=10.0,
          padding=6.0,
          align_items=@yoga.AlignItems::FlexStart,
          bg=@theme.theme_bg_page(),
          border=@theme.theme_border(),
        ),
        @ui.view(
          [
            @ui.text("浮层次批", size=13.0),
            @ui.button(
              "弹窗",
              on_click=fn() -> Unit { dlg_open.set(true) },
              min_width=70.0,
              handle=fn(w : @core.Widget) -> Unit { ov2_dlgbtn.val = Some(w) },
            ),
            @ui.dialog(
              dlg_open,
              "确认操作",
              [@ui.text("对话框在浮层图层上开，遮罩铺满整窗", size=12.0)],
              on_confirm=fn() -> Unit { dlg_ok.val = dlg_ok.val + 1 },
            ),
            @ui.context_menu_for(
              @ui.view(
                [@ui.text("右键我", size=13.0)],
                padding=4.0,
                bg=@theme.theme_bg_panel(),
                height=28.0,
              ),
              [
                ("复制", fn() -> Unit { ctx_pick.val = 1 }),
                ("-", fn() -> Unit { () }),
                ("删除", fn() -> Unit { ctx_pick.val = 3 }),
              ],
              width=120.0,
              handle=fn(w : @core.Widget) -> Unit { ov2_ctx.val = Some(w) },
            ),
            @ui.button(
              "提示",
              on_click=fn() -> Unit {
                toast_push("保存成功", @ui.Success)
                toast_n.val = toast_n.val + 1
              },
              min_width=70.0,
              handle=fn(w : @core.Widget) -> Unit { ov2_toastbtn.val = Some(w) },
            ),
          ],
          width=220.0,
          row_gap=8.0,
          padding=6.0,
          align_items=@yoga.AlignItems::FlexStart,
          bg=@theme.theme_bg_page(),
          border=@theme.theme_border(),
        ),
      ],
      direction=@yoga.Row,
      column_gap=8.0,
      padding=8.0,
      align_items=@yoga.AlignItems::FlexStart,
      bg=@theme.theme_bg_page(),
      border=@theme.theme_border(),
    ),
  ])
  // 批次 5d（输入框全语义）：整只框由 `@ui.input` 提供——键入、选区、双击选词、
  // 拖动、undo、输入法提交与 preedit 都在组件里，宿主只按焦点投递。
  let t3 = @core.Store::new("组件框")
  let _ = (@ui.input(
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
  // 焦点栈只认注册过的 id（没注册时按下不改焦点，打字就进不去）：
  // 21=实心按钮、22=下拉、23=取色器、24=多行框
  let _ = app.focus.register(21)
  let _ = app.focus.register(22)
  let _ = app.focus.register(23)
  let _ = app.focus.register(24)
  let _ = app.focus.register(25)

  let ticker : Ref[() -> Unit] = Ref(fn() { () })
  ticker.val = fn() {
    if app.is_running() {
      ctr.frames = ctr.frames + 1
      // W20e：现场窗口增强读数快照（关窗后后端槽清空，退出时读不到真值）
      let (sw, sh) = app.window.min_size()
      let (sx, sy, sdw, sdh) = app.window.drag_rect()
      win_snap.val =
        "title='" +
        app.window.title() +
        "' min=" +
        sw.to_string() +
        "x" +
        sh.to_string() +
        " drag=" +
        sx.to_string() +
        "," +
        sy.to_string() +
        "," +
        sdw.to_string() +
        "x" +
        sdh.to_string() +
        " bl=" +
        (if app.window.is_borderless() { "1" } else { "0" }) +
        " icon=" +
        (match win_icon.val {
          Some(_) => "1"
          None => "0"
        })
      // 自转轮播的下标由宿主的延时通道推进：换了页就计一次
      // 浮层是瞬时的：退出时计数早已归零，故每拍记一次峰值（证明真窗口里确实开过层）
      let ck = app.cursor_kind
      let c0 = cur_seen.val
      cur_seen.val =
        if ck == 1 {
          (c0.0 + 1, c0.1, c0.2, c0.3)
        } else if ck == 2 {
          (c0.0, c0.1 + 1, c0.2, c0.3)
        } else if ck == 3 {
          (c0.0, c0.1, c0.2 + 1, c0.3)
        } else if ck == 4 {
          (c0.0, c0.1, c0.2, c0.3 + 1)
        } else {
          c0
        }
      // 声明式文本绑定的初值宽度：只在第一拍记一次
      if dcl_w0_ref.val < 0.0 {
        match dcl_label_w.val {
          Some(w) =>
            if w.rect.w > 0.0 {
              dcl_w0_ref.val = w.rect.w
            }
          None => ()
        }
      }
      let ov_now = @core.overlay_count()
      if ov_now > frm_ov_max.val {
        frm_ov_max.val = ov_now
      }
      let idx = auto.index()
      let s0 = car_sample.val
      if s0.0 != idx {
        car_sample.val = (idx, s0.1 + 1)
      }
      // W20b：抽已触发的全局快捷键（Win32 的 WM_HOTKEY 进线程队列，靠泵抽）。
      // W22 起走 `@core.hotkey_poll`——命中即给 id + 加速串（回查表在门面里）。
      match @core.hotkey_poll() {
        Some(hk) => {
          hotkey_hits.val = hotkey_hits.val + 1
          hotkey_last.val =
            if hk.spec != "" {
              hk.spec
            } else {
              "id=" + hk.id.to_string()
            }
        }
        None => ()
      }
      // W20a：派发菜单命令（Win32 的 WM_COMMAND 经后端进队列，这里按 id 找回调执行）
      let _ignored_hit = @core.dispatch_menu_command()
      // W20c：派发托盘左键/右键（Win32 的 WM_TRAY_CB 经后端进队列；右键无回调时
      // 自动弹已挂的菜单）。SNI 后端点击由 DBus 信号直达回调，不经此队列。
      let _ignored_tray = @core.dispatch_tray_event()
      // W21a：每拍快照后端侧在用通知数（关窗后槽表清空，退出时读不到真值）
      notify_snap.val = "count=" + @win.notify_count().to_string()
      // W21b：每拍快照运行中的浮层数（自绘消息框开在浮层图层上）
      mb_ovl_snap.val = @core.overlay_count()
      app.schedule_paint()
      let _ = app.timer(500, ticker.val)
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
  // 节拍 500ms（原 100ms）：纯光栅器后端上一帧整树重画是百毫秒级，100ms 的
  // 节拍会让消息泵持续饥饿（真机表现为窗口「未响应」）；500ms 下阻塞窗口远
  // 小于系统的判超时，读数行照样在退出时打齐
  let _ = app.timer(500, ticker.val)
  let _ = app.timer(500, blinker.val)
  // 跟随系统深浅/主色：每拍读一次，变了才 theme_apply（本机读不出主色时按亮色走）
  let stop_follow = app.follow_system_theme(interval_ms=1000)
  // 跟随逻辑的归属验证：跑一会儿后停表，之后不再读系统偏好
  let _ = app.timer(3000, fn() -> Unit { stop_follow() })
  // 累积验证页越排越宽，注入点位也跟着多——存活窗口给到 9 秒才够把全部
  // 交互注完一轮（原来 5 秒时后几击会赶上退出）
  // 自杀点：无人值守冒烟用（十分钟——人工按清单逐项验收够用；自动化跑法一律
  // 带超时/直接 kill 或优雅关窗，不等这一拍）
  let _ = app.timer(600000, fn() { app.quit() })
  // 全部页面已挂完：整页内容（数千像素高）搬进滚动视口——屏幕只有 1080p 时
  // 下面的表单/图表/日历/浮层页够不着，滚轮滚到哪测到哪
  app.enable_root_scroll()

  app.run()
  // 帧耗时分段账本：布局/绘制/上屏的实测占比（性能诊断，见 gui/core/prof.mbt）
  println("NATIVE-APP-PROF " + @core.paint_profile_summary())
  // 卸载前停转（自排链不认识视图已移除；本例循环已 quit，这里是示范正确收尾）
  @ui.carousel_stop(auto)
  @ui.carousel_stop(spin)
  let focus_str = match app.focus.current() {
    Some(i) => i.to_string()
    None => "-"
  }
  let tree_str = match nav2_tree.val {
    Some(w) => (if w.children()[1].visible { "1" } else { "0" })
    None => "-"
  }
  let split_first_w = match spl_w.val {
    Some(w) => w.children()[0].rect.w
    None => 0.0
  }

  let dpk_str = match dpk.get() {
    Some(x) => x.format()
    None => "-"
  }
  let ymd_or = fn(x : @ui.DateYMD?) -> String {
    match x {
      Some(v) => v.format()
      None => "-"
    }
  }

  let hm_or = fn(x : @ui.TimeHM?) -> String {
    match x {
      Some(v) => v.format()
      None => "-"
    }
  }

  let drg_str = ymd_or(drg.get().start) + "~" + ymd_or(drg.get().end)
  let trg_str = hm_or(trg.get().start)
  let fold_str = match nav_fold.val {
    Some(w) => {
      let blocks = w.children()
      let b0 = blocks[0].children()[1].visible
      let b1 = blocks[1].children()[1].visible
      (if b0 { "1" } else { "0" }) + (if b1 { "1" } else { "0" })
    }
    None => "-"
  }

  let date_str = match picked_date.get() {
    Some(x) => x.format()
    None => "-"
  }
  // bind_label 的宽度：挂载后首帧记一次初值，退出时再记一次（点过按钮就变宽）
  let dcl_w0 = if dcl_w0_ref.val < 0.0 { 0.0 } else { dcl_w0_ref.val }
  let dcl_w1 = match dcl_label_w.val {
    Some(w) => w.rect.w
    None => 0.0
  }
  // 多行框的插入点字节下标（内核句柄不外露，走 im_context 那条接缝）
  let ta_caret = match frm_ta_w.val {
    Some(w) => match w.im_context {
      Some(f) => f().unwrap_or(("", -1)).1
      None => -1
    }
    None => -1
  }
  println(
    "NATIVE-APP-OK frames=\{ctr.frames} clicks=\{ctr.clicks} t1='\{f1.ed.get_text()}' c1=\{f1.ed.caret_pos()} t2='\{f2.ed.get_text()}' focus=\{focus_str} fam=\{ctr.fam_count} use='\{ctr.use_family}' lhm=\{ctr.lh_mixed} decl=\{decl.get()} kids=\{root.children().length()}/\{decl_kids_before + 1} band=d\{ctr.down}/u\{ctr.up}/m\{ctr.moved} comp=\{ctr.comp} form=\{agreed.get()}/\{sound.get()}/\{level.get().round().to_int()}/\{count.get()} t3='\{t3.get()}' closed=\{ctr.closed} car=\{spin.index()} auto=\{car_sample.val.1} date='\{date_str}' seg='\{seg_sel.get()}' crumb='\{crumb_sel.get()}' page=\{page_cur.get()} step=\{step_cur.get()} fold='\{fold_str}' menu='\{menu_sel.get()}' tab=\{tab_sel.get()} tree=\{tree_str} xfer=\{xfer_left.get().length()}/\{xfer_right.get().length()} scr=\{scr.offset_y().round().to_int()}/\{scr.max().round().to_int()} ov=\{@core.overlay_count()} pick=\{ov_pick.val} dlg=\{dlg_ok.val} ctx=\{ctx_pick.val} toast=\{toast_n.val} dpk='\{dpk_str}' tsort=\{tb_sort.get().column}/\{tb_sort.get().asc} trow='\{if tb_rows.get().length() > 0 { @ui.cell_text(tb_rows.get()[0], 0) } else { "-" }}' tsel=\{tb_sel.get().length()} vt=\{vt_sel.get().length()}/\{vt_clicks.val} sticky='\{sticky.cur_group}' split=\{split_first_w.round().to_int()} drg='\{drg_str}' trg='\{trg_str}' btn=\{frm_btn.val} lnk=\{frm_lnk.val} rate=\{frm_rate.get()} ferr=\{if frm_err.get().length() > 0 { 1 } else { 0 }} sel='\{frm_pick.val}/\{frm_sel.get()}' cmb='\{frm_cmb.get()}' col='\{frm_col.get()}' ovmax=\{frm_ov_max.val} ta='\{flat(frm_ta.get())}' tacur=\{ta_caret} dcl=\{dcl_n.get()} lblw=\{dcl_w0.round().to_int()}/\{dcl_w1.round().to_int()} cur=\{cur_seen.val.0}/\{cur_seen.val.1}/\{cur_seen.val.2}/\{cur_seen.val.3} gif=\{gif_h.frame_count()} ib=\{ib_hits.val} sys='\{@core.sys_color_scheme()}/\{@core.sys_accent()}' fing=\{@theme.theme_fingerprint_of(@theme.theme_current())} ln=\{ch_lin.get()[0].points.length()}/\{ch_lin.get()[0].points[ch_lin.get()[0].points.length() - 1].round().to_int()} chp=\{ch_pushes.val}'"
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
  // 轮播的箭头与指示点是根控件的孙辈，几何行按根子项打印拿不到，单独给一行
  match car_w.val {
    Some(w) => {
      let stage_row = w.children()[0]
      let dots = w.children()[1]
      let dots_last = dots.children()[dots.children().length() - 1]
      println(
        "NATIVE-APP-CAR box=" +
          rect_str(w.rect) +
          " left=" +
          rect_str(stage_row.children()[0].rect) +
          " right=" +
          rect_str(stage_row.children()[2].rect) +
          " dot_last=" +
          rect_str(dots_last.rect),
      )
    }
    None => ()
  }
  match auto_w.val {
    Some(w) => println("NATIVE-APP-AUTO " + rect_str(w.rect))
    None => ()
  }
  // 导航族次批注入点：菜单第二项 / 树父行 / 页签第二页
  let menu2 = match nav2_menu.val {
    Some(w) => Some(w.children()[1])
    None => None
  }

  let tree0 = match nav2_tree.val {
    Some(w) => Some(w.children()[0])
    None => None
  }

  let tab2 = match nav2_tabs.val {
    Some(w) => Some(w.children()[0].children()[1])
    None => None
  }
  let xfer_row = match nav2_xfer.val {
    Some(w) => Some(w.children()[0].children()[0])
    None => None
  }
  let n2_xfer_row = match xfer_row {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let n2_xfer_btn = match nav2_xfer.val {
    Some(w) => rect_str(w.children()[1].rect)
    None => "-"
  }
  let n2_menu2 = match menu2 {
    Some(w) => rect_str(w.rect)
    None => "-"
  }

  let n2_tree0 = match tree0 {
    Some(w) => rect_str(w.rect)
    None => "-"
  }

  let n2_tab2 = match tab2 {
    Some(w) => rect_str(w.rect)
    None => "-"
  }

  println("NATIVE-APP-NAV2 menu2=" + n2_menu2 + " tree0=" + n2_tree0 + " tab2=" + n2_tab2 + " xrow=" + n2_xfer_row + " xbtn=" + n2_xfer_btn)
  let ov_dd_rect = match ov_dd.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let ov_pop_rect = match ov_pop.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let ov_tip_rect = match ov_tip.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let ov2_rect_of = fn(x : @core.Widget?) -> String {
    match x {
      Some(w) => rect_str(w.rect)
      None => "-"
    }
  }

  let dpk_rect = match dpk_w.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  let drg_rect = match drg_w.val {
    Some(w) => rect_str(w.rect)
    None => "-"
  }
  match spl_w.val {
    Some(w) => println(
      "NATIVE-APP-SPL first=" +
      rect_str(w.children()[0].rect) +
      " bar=" +
      rect_str(w.children()[1].rect),
    )
    None => ()
  }
  let frm_btns = match frm_row_w.val {
    Some(w) => {
      let mut acc = ""
      for c in w.children() {
        acc = acc + rect_str(c.rect) + " "
      }
      acc
    }
    None => "-"
  }
  println(
    "NATIVE-APP-CH line=" +
    ov2_rect_of(ch_line_w.val) +
    " btn=" +
    ov2_rect_of(ch_btn_w.val),
  )
  // 交互图表：折线面板（vbox）与画布 rect 给注入坐标依据；zoom 窗读数
  // 回证滚轮缩放真生效（全窗 0-100，注入上滚一格后应收窄到 10-90）
  let it_canvas = match it_panel_w.val {
    Some(w) => rect_str(w.children()[1].rect)
    None => "-"
  }
  println(
    "NATIVE-APP-CHIT panel=" +
    ov2_rect_of(it_panel_w.val) +
    " canvas=" +
    it_canvas +
    " zoom=" +
    it_zoom.start.round().to_int().to_string() +
    "-" +
    it_zoom.end.round().to_int().to_string(),
  )
  println(
    "NATIVE-APP-CHSP heat=" +
      ov2_rect_of(sp_w.val) +
      " sankey=" +
      ov2_rect_of(sp2_w.val) +
      " gph=" +
      ov2_rect_of(sp3_w.val) +
      " eff=" +
      ov2_rect_of(sp4_w.val) +
      " code=" +
      ov2_rect_of(cv_w.val) +
      " md=" +
      ov2_rect_of(md_w.val),
  )
  println(
    "NATIVE-APP-MEDIA gif=" +
    ov2_rect_of(gif_w.val) +
    " ib=" +
    ov2_rect_of(ib_w.val),
  )
  println(
    "NATIVE-APP-DC card=" +
    ov2_rect_of(dcl_card_w.val) +
    " label=" +
    ov2_rect_of(dcl_label_w.val),
  )
  println(
    "NATIVE-APP-FORM btn=" +
    ov2_rect_of(frm_btn_w.val) +
    " btns=" +
    frm_btns +
    " link=" +
    ov2_rect_of(frm_link_w.val) +
    " rate=" +
    ov2_rect_of(frm_rate_w.val) +
    " item=" +
    ov2_rect_of(frm_item_w.val) +
    " ta=" +
    ov2_rect_of(frm_ta_w.val) +
    " cmb=" +
    ov2_rect_of(frm_cmb_w.val) +
    " sel=" +
    ov2_rect_of(frm_sel_w.val) +
    " col=" +
    ov2_rect_of(frm_col_w.val),
  )
  match sticky.scroll.view_h {
    v =>
      println(
        "NATIVE-APP-STK box=" +
        (match sticky_w.val {
          Some(w) => rect_str(w.rect)
          None => "-"
        }) +
        " view=" + v.round().to_int().to_string() + " max=" +
        sticky.scroll.max().round().to_int().to_string() + " group=" +
        sticky.cur_group,
      )
  }
  let vt_line = match vt_w.val {
    Some(w) => {
      let list = w.children()[1]
      "NATIVE-APP-VT list=" +
      rect_str(list.rect) +
      " mounted=" +
      list.children()[0].children().length().to_string() +
      " total=200"
    }
    None => "NATIVE-APP-VT -"
  }
  println(vt_line)
  let tb_head0 = match tb_w.val {
    Some(w) => rect_str(w.children()[0].children()[0].rect)
    None => "-"
  }
  let tb_row1 = match tb_w.val {
    Some(w) => rect_str(w.children()[1].children()[1].rect)
    None => "-"
  }
  println("NATIVE-APP-TB head0=" + tb_head0 + " row1=" + tb_row1)
  let trg_rect = match trg_w.val {
    Some(w) => {
      let f = w.children()[0]
      rect_str(f.rect)
    }
    None => "-"
  }

  println("NATIVE-APP-DP dpk=" + dpk_rect + " drg=" + drg_rect + " trg_start=" + trg_rect)
  println(
    "NATIVE-APP-OV2 dlgbtn=" +
      ov2_rect_of(ov2_dlgbtn.val) +
      " ctx=" +
      ov2_rect_of(ov2_ctx.val) +
      " toastbtn=" +
      ov2_rect_of(ov2_toastbtn.val),
  )
  println(
    "NATIVE-APP-OV dd=" + ov_dd_rect + " pop=" + ov_pop_rect + " tip=" + ov_tip_rect,
  )
  // 导航族四个注入点：分段第二段 / 面包屑第二段 / 第 3 页 / 第二块标题行
  let mut nav_line = "NATIVE-APP-NAV"
  let seg2 = match nav_seg.val {
    Some(w) => Some(w.children()[1])
    None => None
  }

  let crumb2 = match nav_crumb.val {
    Some(w) => Some(w.children()[2])
    None => None
  }

  let page3 = match nav_page.val {
    Some(w) => Some(w.children()[3])
    None => None
  }

  let fold2 = match nav_fold.val {
    Some(w) => Some(w.children()[1].children()[0])
    None => None
  }
  let nav_targets : Array[(String, @core.Widget?)] = [
    ("seg2", seg2),
    ("crumb2", crumb2),
    ("page3", page3),
    ("fold2", fold2),
  ]
  for kv in nav_targets {
    match kv.1 {
      Some(w) => nav_line = nav_line + " " + kv.0 + "=" + rect_str(w.rect)
      None => ()
    }
  }
  println(nav_line)
  match scr_w.val {
    Some(w) => {
      println(
        "NATIVE-APP-SCR box=" +
          rect_str(w.rect) +
          " bar=" +
          rect_str(w.children()[1].rect) +
          " row0=" +
          rect_str(w.children()[0].children()[0].rect),
      )
    }
    None => ()
  }
  match cal_w.val {
    Some(w) => {
      // 第 14 格（本月第 11 天）给注入用；跨月格与它同列不同色，坐标够用
      let grid = w.children()[2]
      let c14 = grid.children()[2].children()[0]
      println("NATIVE-APP-CAL box=" + rect_str(w.rect) + " cell=" + rect_str(c14.rect))
    }
    None => ()
  }
  // 批 A（多窗口）回证：在窗数、开过/关过几扇、两窗各自的点击数，以及关于窗
  // 输入框的字数与那扇窗的焦点 id——焦点栈按窗独立，主窗的框不会被牵连。
  let sub_focus = match mw_sub_win.val {
    Some(win) =>
      match win.focus.current() {
        Some(id) => id.to_string()
        None => "0"
      }
    None => "-"
  }
  println(
    "NATIVE-APP-MW wins=" +
      app.window_count().to_string() +
      " opened=" +
      mw_opened.val.to_string() +
      " closes=" +
      mw_closes.val.to_string() +
      " main_clicks=" +
      mw_main_clicks.val.to_string() +
      " sub_clicks=" +
      mw_sub_clicks.val.to_string() +
      " sub_entry_bytes=" +
      mw_sub_entry_max.val.to_string() +
      " sub_focus=" +
      sub_focus,
  )
  match mw_open_btn.val {
    Some(w) => {
      // 关于窗的矩形是**那扇窗自己的**窗内坐标，注入前先 xwininfo 拿它的绝对位置
      let mut line = "NATIVE-APP-MW-GEO open=" + rect_str(w.rect)
      for kv in [
        ("sub_btn", mw_sub_btn),
        ("sub_entry", mw_sub_entry),
        ("sub_close", mw_sub_close),
      ] {
        match kv.1.val {
          Some(b) => line = line + " " + kv.0 + "=" + rect_str(b.rect)
          None => ()
        }
      }
      println(line)
    }
    None => println("NATIVE-APP-MW-GEO -")
  }
  // W20b（全局快捷键）回证：两个注册 id 与累计触发次数（真按键需人工）。
  println(
    "NATIVE-APP-HOTKEY id1=" +
      hotkey_ids.val.0.to_string() +
      " id2=" +
      hotkey_ids.val.1.to_string() +
      " hits=" +
      hotkey_hits.val.to_string() +
      " last=" +
      hotkey_last.val,
  )
  // §6.3（任务栏进度）回证：后端可用性与最近一次写入口的结果标签
  // （真观感——任务栏按钮的绿/红/黄条——需人工点按钮后看任务栏）。
  println(
    "NATIVE-APP-TASKBAR supported=" +
      (if @win.taskbar_supported() { "1" } else { "0" }) +
      " last=" +
      taskbar_last.val,
  )
  // W20d（原生消息框）回证：弹框次数与最近一次的返回标签（真弹框需人工点按钮）。
  println(
    "NATIVE-APP-MSGBOX shots=" +
      msgbow_shots.val.to_string() +
      " last=" +
      msgbow_last.val,
  )
  // W21b（自绘消息框）回证：弹框次数与最近一次的响应编号（自绘档编号由调用方给）；
  // ovl= 是运行中浮层数的末次快照（关窗后浮层栈已清，退出时读不到真值）。
  println(
    "NATIVE-APP-MSGBOX2 shots=" +
    mb_shots.val.to_string() +
    " last=" +
    mb_last.val +
    " ovl=" +
    mb_ovl_snap.val.to_string() +
    " native_ovl=" +
    @core.overlay_count().to_string(),
  )
  // W20a（原生菜单栏）回证：菜单是否挂上、菜单项被点几次、最近一项标签。
  println(
    "NATIVE-APP-MENU applied=" +
      (if menu_applied.val { "1" } else { "0" }) +
      " menus=" +
      menu_bar.menu_count().to_string() +
      " items=" +
      menu_bar.total_item_count().to_string() +
      " hits=" +
      menu_hits.val.to_string() +
      " last=" +
      menu_last.val,
  )
  // W20e（窗口增强）回证：最后一帧仍活着时快照的系统侧读数（标题/最小尺寸/
  // 拖拽区/无边框/图标；改标题、设图标、开无边框需人工点按钮）。
  println("NATIVE-APP-WIN " + win_snap.val)
  // W20c（系统托盘）回证：后端可用性、当前后端、在用槽数、左键/菜单项计数。
  // （建托盘/挂菜单/弹菜单需人工点按钮；不支持时如实报 supported=0。）
  println(
    "NATIVE-APP-TRAY supported=" +
    (if @core.Tray::is_supported() { "1" } else { "0" }) +
    " backend=" +
    (match tray.val {
      Some(t) => t.backend_name()
      None => "-"
    }) +
    " count=" +
    @win.tray_count().to_string() +
    " clicks=" +
    tray_clicks.val.to_string() +
    " note=" +
    tray_note.val,
  )
  // 退出前显式收掉托盘图标（进程退出系统也会清，但显式更干净、也让 count 归 0）
  match tray.val {
    Some(t) => t.remove()
    None => ()
  }
  // W21a（桌面通知）回证：后端可用性/后端名、已发数、当前通知 id 与关闭前的
  // 后端侧在用数快照。（发气泡/改进度/关闭需人工点按钮；不支持时如实报 supported=0。）
  println(
    "NATIVE-APP-NOTIFY supported=" +
    (if @core.notify_supported() { "1" } else { "0" }) +
    " backend=" +
    @core.notify_backend_name() +
    " sends=" +
    notify_sends.val.to_string() +
    " id=" +
    nid.val.to_string() +
    " " +
    notify_snap.val +
    " note=" +
    notify_note.val,
  )
  // 退出前显式收起还开着的气泡（Win32 无独立 dismiss，走 NIF_INFO 空正文 + NIM_DELETE）
  if nid.val > 0 {
    let _ = @core.notify_close(nid.val)
  }
  match notify_icon.val {
    Some(ic) => ic.free()
    None => ()
  }
  // W21c（拖放）回证：起的拖拽次数、投中次数、退出时是否还有拖拽在跑、最近一次
  // 投递的载荷描述（应用内拖放全自绘，真人拖一把数才对得上）。
  println(
    "NATIVE-APP-DRAG drags=" +
    drag_drags.val.to_string() +
    " drops=" +
    drag_drops.val.to_string() +
    " active=" +
    (if @core.drag_active() { "1" } else { "0" }) +
    " last=" +
    drag_last.val,
  )
  app.shutdown()
}
