// Element Plus 风格非表单组件（纯 MoonBit，构建在声明式层之上）。
// 样式约定：直角（无圆角）；hover/active 一律用背景色表达；
// 所有文字经 draw_text(valign=Center) 垂直居中。
//   - side_menu   侧边导航菜单（对应 EP Menu）
//   - segmented   分段控制器 / 顶栏导航（对应 EP Segmented）
//   - tag / tag_of_type  标签（对应 EP Tag）
//   - breadcrumb  面包屑（对应 EP Breadcrumb）
//   - pagination  分页（对应 EP Pagination）
//   - alert       提示横幅（对应 EP Alert）
//   - badge_count 数字角标（对应 EP Badge）
//   - card        卡片（对应 EP Card，标题栏 + 边框）
//   - code_view   代码高亮视图（逐 token 自绘，绕开 Windows 区间设色缺陷）
// 渲染模型：交互项 on_draw 自绘（背景色矩形 + 文字），状态（选中/hover）
// 变化经 schedule_paint 触发重绘。组件间状态协调统一走 Store，无平台代码。

///|
/// 主题色板（Element Plus 默认色）。
pub let theme_primary : String = "#409EFF"

///|
pub let theme_primary_light : String = "#ECF5FF"

///|
pub let theme_success : String = "#67C23A"

///|
pub let theme_success_light : String = "#F0F9EB"

///|
pub let theme_warning : String = "#E6A23C"

///|
pub let theme_warning_light : String = "#FDF6EC"

///|
pub let theme_danger : String = "#F56C6C"

///|
pub let theme_danger_light : String = "#FEF0F0"

///|
pub let theme_info : String = "#909399"

///|
pub let theme_info_light : String = "#F4F4F5"

///|
pub let theme_text_primary : String = "#303133"

///|
pub let theme_text_regular : String = "#606266"

///|
pub let theme_text_secondary : String = "#909399"

///|
pub let theme_border : String = "#E4E7ED"

///|
pub let theme_fill_hover : String = "#F5F7FA"

///|
/// 语义类型（EP Tag/Alert 的 type）。
pub(all) enum SemanticType {
  Primary
  Success
  Warning
  Danger
  Info
}

///|
fn type_color(t : SemanticType) -> String {
  match t {
    Primary => theme_primary
    Success => theme_success
    Warning => theme_warning
    Danger => theme_danger
    Info => theme_info
  }
}

///|
fn type_light_color(t : SemanticType) -> String {
  match t {
    Primary => theme_primary_light
    Success => theme_success_light
    Warning => theme_warning_light
    Danger => theme_danger_light
    Info => theme_info_light
  }
}

///|
/// 自绘交互项通用挂载器:背景色表达 hover/active,文字垂直居中。
/// bg_of(active, hover) 返回背景色(空串表示透明);fg_of(active) 返回文字色。
/// align_start=false 时文字水平居中(分段/分页),true 时左对齐(菜单)。
fn stateful_item(
  text : String,
  style : Array[(String, Double)],
  selected : Store[String],
  bg_of : (Bool, Bool) -> String,
  fg_of : (Bool, Bool) -> String,
  pad_x? : Double = 0.0,
  align_start? : Bool = false,
  font_size? : Double = 13.0,
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      // 自绘文字不占布局空间:无显式 width 时按文本测宽自动定宽
      let font = Font::new("Sans", font_size)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let mut has_w = false
      for kv in style {
        if kv.0 == "width" {
          has_w = true
        }
      }
      let style2 = if has_w {
        style
      } else {
        {
          let copy = style.copy()
          copy.push(("width", text_w + pad_x * 2.0))
          copy
        }
      }
      let v = Container::make(style=style2)
      fn draw_item(p : Painter) -> Unit {
        let b = v.get_bounds()
        let w = b.width
        let h = b.height
        let act = selected.get() == text
        let bg = bg_of(act, hover.val)
        if bg != "" {
          p.set_fill_color(bg)
          p.fill_rect(0.0, 0.0, w, h)
        }
        // 文字:AttributedText 支持指定字号,垂直居中交给 valign=Center
        let at = AttributedText::new(
          text,
          align=if align_start { Start } else { Center },
          valign=Center,
          wrap=false,
        )
        at.set_font(font)
        at.set_color(fg_of(act, hover.val))
        p.draw_attributed_text(at, pad_x, 0.0, w, h)
      }

      v.on_draw(draw_item)
      v.on_mouse_down(fn(e) {
        if e.button == 1 {
          selected.set(text)
          true
        } else {
          false
        }
      })
      v.on_mouse_enter(fn(_e) {
        hover.val = true
        v.schedule_paint()
      })
      v.on_mouse_leave(fn(_e) {
        hover.val = false
        v.schedule_paint()
      })
      selected.subscribe(fn(_s) { v.schedule_paint() })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
fn side_menu_bg(act : Bool, hov : Bool) -> String {
  if act {
    theme_primary_light
  } else if hov {
    theme_fill_hover
  } else {
    ""
  }
}

///|
fn side_menu_fg(act : Bool, _hov : Bool) -> String {
  if act {
    theme_primary
  } else {
    theme_text_primary
  }
}

///|
/// 侧边导航菜单(对应 EP Menu):hover 浅蓝、选中浅蓝底 + 主题色文字,
/// 直角,文字垂直居中。selected 为共享状态,主区页面可订阅同一 Store
/// 做 set_visible 联动。
pub fn side_menu(
  items : Array[String],
  selected : Store[String],
  width? : Double = 180.0,
) -> Node {
  let nodes : Array[Node] = []
  for it in items {
    nodes.push(
      stateful_item(
        it,
        [("width", width), ("height", 40.0)],
        selected,
        side_menu_bg,
        side_menu_fg,
        pad_x=20.0,
        align_start=true,
      ),
    )
  }
  vbox(
    nodes,
    style=[("width", width), ("padding", 6.0)],
    handle=fn(c) { c.set_background_color("#FFFFFF") },
  )
}

///|
fn segmented_bg(act : Bool, hov : Bool) -> String {
  if act {
    "#FFFFFF"
  } else if hov {
    "#D9DCDF"
  } else {
    ""
  }
}

///|
fn segmented_fg(act : Bool, _hov : Bool) -> String {
  if act {
    theme_primary
  } else {
    theme_text_regular
  }
}

///|
/// 分段控制器 / 顶栏导航(对应 EP Segmented):选中白底 + 主题色文字,
/// hover 灰底,直角,文字垂直居中。
pub fn segmented(options : Array[String], selected : Store[String]) -> Node {
  let items : Array[Node] = []
  for opt in options {
    items.push(
      stateful_item(
        opt,
        [("height", 30.0)],
        selected,
        segmented_bg,
        segmented_fg,
        pad_x=16.0,
      ),
    )
  }
  hbox(
    items,
    style=[("padding", 2.0)],
    style_str=[("alignItems", "center")],
    handle=fn(c) { c.set_background_color("#DEE0E3") },
  )
}

///|
/// 标签(对应 EP Tag 的浅色变体):类型浅底 + 同族深字,直角,
/// 宽度按文本自适应,文字垂直居中。
pub fn tag_of_type(text : String, t : SemanticType) -> Node {
  {
    mount: fn(parent) {
      let font = Font::new("Sans", 12.0)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let w = text_w + 16.0
      let h = 24.0
      let c = Container::make(
        style=[("width", w), ("height", h), ("marginRight", 8.0)],
      )
      c.on_draw(fn(p) {
        p.set_fill_color(type_light_color(t))
        p.fill_rect(0.0, 0.0, w, h)
        p.draw_text(
          text,
          0.0,
          0.0,
          w,
          h,
          align=Center,
          valign=Center,
          color=type_color(t),
        )
      })
      attach(parent, c.view())
      c.view()
    },
  }
}

///|
/// 兼容旧用法的彩色实底标签(自定颜色)。
pub fn tag(text : String, color : String, height? : Double = 24.0) -> Node {
  {
    mount: fn(parent) {
      let font = Font::new("Sans", 12.0)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let w = text_w + 16.0
      let c = Container::make(
        style=[("width", w), ("height", height), ("marginRight", 8.0)],
      )
      c.on_draw(fn(p) {
        p.set_fill_color(color)
        p.fill_rect(0.0, 0.0, w, height)
        p.draw_text(
          text,
          0.0,
          0.0,
          w,
          height,
          align=Center,
          valign=Center,
          color="#FFFFFF",
        )
      })
      attach(parent, c.view())
      c.view()
    },
  }
}

///|
/// 数字角标(对应 EP Badge 的数字形态):红底白字小块,宽度自适应。
pub fn badge_count(count : Int) -> Node {
  tag(count.to_string(), theme_danger, height=18.0)
}

///|
fn crumb_bg(_act : Bool, _hov : Bool) -> String {
  ""
}

///|
/// 面包屑(对应 EP Breadcrumb):层级随选中态联动——当前项深色不可点,
/// 其余灰色可点、hover 变主题色。
pub fn breadcrumb(items : Array[String], selected : Store[String]) -> Node {
  let nodes : Array[Node] = []
  let mut i = 0
  for it in items {
    if i > 0 {
      nodes.push(
        stateful_item(
          "/",
          [("height", 24.0), ("marginRight", 4.0)],
          Store::new(""),
          crumb_bg,
          crumb_fg_static,
          font_size=13.0,
        ),
      )
    }
    nodes.push(
      stateful_item(
        it,
        [("height", 24.0), ("marginRight", 4.0)],
        selected,
        crumb_bg,
        crumb_fg,
        pad_x=4.0,
        font_size=13.0,
      ),
    )
    i = i + 1
  }
  hbox(nodes, style_str=[("alignItems", "center")])
}

///|
fn crumb_fg(_act : Bool, hov : Bool) -> String {
  if hov {
    theme_primary
  } else {
    theme_text_secondary
  }
}

///|
fn crumb_fg_static(_act : Bool, _hov : Bool) -> String {
  theme_text_secondary
}

///|
/// 提示横幅(对应 EP Alert):类型浅底 + 左侧 4px 色条 + 同族深字,
/// 全宽,文字垂直居中。
pub fn alert(text : String, t : SemanticType, height? : Double = 40.0) -> Node {
  {
    mount: fn(parent) {
      let v = Container::make(
        style=[("height", height), ("marginBottom", 10.0)],
      )
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let w = b.width
        let h = b.height
        p.set_fill_color(type_light_color(t))
        p.fill_rect(0.0, 0.0, w, h)
        p.set_fill_color(type_color(t))
        p.fill_rect(0.0, 0.0, 4.0, h)
        p.draw_text(
          text,
          16.0,
          0.0,
          w,
          h,
          align=Start,
          valign=Center,
          color=type_color(t),
        )
      })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 分页(对应 EP Pagination):‹ 页码 ›,当前页主题色底白字,
/// hover 浅蓝,28×28 直角。current 为共享状态(从 1 开始)。
pub fn pagination(current : Store[Int], pages : Int) -> Node {
  let items : Array[Node] = []
  let prev = stateful_item(
    "‹",
    [("width", 28.0), ("height", 28.0), ("marginRight", 4.0)],
    Store::new(""),
    nav_btn_bg,
    nav_btn_fg,
  )
  items.push(prev)
  let mut i = 1
  while i <= pages {
    let page = i.to_string()
    items.push(
      stateful_item(
        page,
        [("width", 28.0), ("height", 28.0), ("marginRight", 4.0)],
        int_store_adapter(current, pages),
        page_btn_bg,
        page_btn_fg,
      ),
    )
    i = i + 1
  }
  let next = stateful_item(
    "›",
    [("width", 28.0), ("height", 28.0)],
    Store::new(""),
    nav_btn_bg,
    nav_btn_fg,
  )
  items.push(next)
  hbox(items, style_str=[("alignItems", "center")])
}

///|
fn nav_btn_bg(_act : Bool, hov : Bool) -> String {
  if hov {
    theme_primary_light
  } else {
    ""
  }
}

///|
fn nav_btn_fg(_act : Bool, _hov : Bool) -> String {
  theme_text_regular
}

///|
fn page_btn_bg(act : Bool, hov : Bool) -> String {
  if act {
    theme_primary
  } else if hov {
    theme_primary_light
  } else {
    ""
  }
}

///|
fn page_btn_fg(act : Bool, _hov : Bool) -> String {
  if act {
    "#FFFFFF"
  } else {
    theme_text_regular
  }
}

///|
/// 把 Store[Int] 适配成 stateful_item 需要的 Store[String]
/// (页码 active 判定:store 值 == 页码文本)。
fn int_store_adapter(current : Store[Int], _pages : Int) -> Store[String] {
  current.map(fn(n) { n.to_string() })
}

///|
/// 卡片(对应 EP Card):白底 + 边框,标题栏(加粗、底部分隔线),
/// 内容区从标题栏下方开始。children 经内层容器挂载,自动留出标题高度。
pub fn card(
  title : String,
  children : Array[Node],
  height? : Double = 160.0,
) -> Node {
  {
    mount: fn(parent) {
      let head_h = 40.0
      let outer = Container::make(style=[("height", height)])
      outer.on_draw(fn(p) {
        let b = outer.get_bounds()
        let w = b.width
        let h = b.height
        // 边框
        p.set_stroke_color("#EBEEF5")
        p.stroke_rect(0.0, 0.0, w, h)
        // 标题栏底部分隔线
        p.set_fill_color("#EBEEF5")
        p.fill_rect(0.0, head_h, w, 1.0)
      })
      // 标题(加粗,垂直居中)
      let title_at = AttributedText::new(title, wrap=false)
      title_at.set_font(Font::new("Sans", 14.0, weight=Bold))
      title_at.set_color(theme_text_primary)
      let title = Container::make(
        style=[("height", head_h), ("paddingLeft", 16.0)],
      )
      title.on_draw(fn(p) {
        let b = title.get_bounds()
        p.draw_attributed_text(title_at, 0.0, 0.0, b.width, head_h)
      })
      outer.add_child(title)
      // 内容区
      let body = Container::make(
        style=[("padding", 14.0)],
        style_str=[("flexDirection", "column")],
      )
      for ch in children {
        ignore((ch.mount)(body.view()))
      }
      outer.add_child(body)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 代码高亮的着色单元。
pub(all) struct Token {
  text : String
  color : String
}

///|
/// MoonBit 风格的极简着色器:关键字 / 数字 / 字符串 / 注释 / 普通文本。
/// 仅供演示;消费方可换成任意词法分析结果后直接用 code_view。
pub fn tokenize_moonbit(line : String) -> Array[Token] {
  let keywords = [
    "fn", "let", "mut", "if", "else", "for", "while", "match", "return",
    "struct", "impl", "pub", "enum", "trait", "true", "false",
  ]
  let out : Array[Token] = []
  let cs : Array[Char] = []
  for ch in line {
    cs.push(ch)
  }
  let n = cs.length()
  let buf = Ref(StringBuilder())
  let in_string = Ref(false)
  fn flush() -> Unit {
    let s = buf.val.to_string()
    buf.val = StringBuilder()
    if s.length() > 0 {
      if in_string.val {
        out.push({ text: s, color: "#98C379" })
      } else {
        out.push(classify_token(s, keywords))
      }
    }
  }

  let mut i = 0
  while i < n {
    let ch = cs[i]
    if in_string.val {
      buf.val.write_char(ch)
      if ch == '"' {
        flush()
        in_string.val = false
      }
    } else if ch == '"' {
      flush()
      in_string.val = true
      buf.val.write_char(ch)
    } else if ch == '/' && i + 1 < n && cs[i + 1] == '/' {
      flush()
      // 余下整行是注释
      let comment = StringBuilder()
      while i < n {
        comment.write_char(cs[i])
        i = i + 1
      }
      out.push({ text: comment.to_string(), color: "#5C6370" })
      break
    } else if ch == ' ' {
      flush()
      out.push({ text: " ", color: "#ABB2BF" })
    } else {
      buf.val.write_char(ch)
    }
    i = i + 1
  }
  flush()
  out
}

///|
fn classify_token(word : String, keywords : Array[String]) -> Token {
  for k in keywords {
    if k == word {
      return { text: word, color: "#C678DD" }
    }
  }
  let is_num = word.length() > 0
  for i in 0..<word.length() {
    let c = word.unsafe_get(i).to_int()
    if !((c >= 48 && c <= 57) || c == 46) {
      return { text: word, color: "#ABB2BF" }
    }
  }
  if is_num {
    return { text: word, color: "#D19A66" }
  }
  { text: word, color: "#ABB2BF" }
}

///|
/// 代码高亮视图:逐 token 建 AttributedText(整段设色)+ 测宽后自绘排版。
/// 等价于「区间设色」的视觉效果,但全平台行为一致——Windows 上
/// AttributedText 区间字体/颜色是上游缺陷(见 docs/adaptation.md),此法绕开。
pub fn code_view(
  lines : Array[String],
  font_size? : Double = 13.0,
  width? : Double = 560.0,
) -> Node {
  {
    mount: fn(parent) {
      let font = Font::new("Monospace", font_size)
      fn make_at(text : String, color : String) -> AttributedText {
        let at = AttributedText::new(text, wrap=false)
        at.set_font(font)
        at.set_color(color)
        at
      }

      // 挂载时预排版:逐 token 测宽,避免每次重绘重复分词/测量
      let line_h = make_at(
        "Ag",
        "#FFFFFF",
      ).get_bounds_for(10000.0, 100.0).height + 5.0
      let laid : Array[(Array[(AttributedText, Double)], Double)] = []
      let mut max_line_w = 0.0
      for line in lines {
        let segs : Array[(AttributedText, Double)] = []
        let mut x = 0.0
        for tok in tokenize_moonbit(line) {
          let at = make_at(tok.text, tok.color)
          let w = at.get_bounds_for(10000.0, 100.0).width
          segs.push((at, x))
          x = x + w
        }
        if x > max_line_w {
          max_line_w = x
        }
        laid.push((segs, x))
      }
      let content_w = max_line_w + 32.0
      let view_w = if width > content_w { width } else { content_w }
      let view_h = line_h * laid.length().to_double() + 28.0
      let c = Container::make(style=[("width", view_w), ("height", view_h)])
      c.set_background_color("#282C34")
      c.on_draw(fn(p) {
        let mut y = 14.0
        for entry in laid {
          for seg in entry.0 {
            let w = seg.0.get_bounds_for(10000.0, 100.0).width
            p.draw_attributed_text(seg.0, seg.1 + 16.0, y, w + 4.0, line_h)
          }
          y = y + line_h
        }
      })
      attach(parent, c.view())
      c.view()
    },
  }
}
