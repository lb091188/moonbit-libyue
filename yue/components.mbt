// Element Plus 风格非表单组件（纯 MoonBit，构建在声明式层之上）。
// 样式约定：直角（无圆角）；hover/active 一律用背景色表达；
// 所有文字经 draw_text(valign=Center) 垂直居中；水平居中必须手动
// （测文本宽、x=(区域宽-文本宽)/2，GTK 端 DrawAttributedText 不实现
// 水平 align，见 docs/adaptation.md）。
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
pub let theme_primary : String = "#2D68C4"

///|
pub let theme_primary_light : String = "#E8F0FB"

///|
/// 实底类组件 hover 加深色(Solid/Danger 按钮等)。
pub let theme_primary_hover : String = "#2459A8"

///|
pub let theme_danger_hover : String = "#BC3440"

///|
pub let theme_success : String = "#2E9E5B"

///|
pub let theme_success_light : String = "#E9F5EE"

///|
pub let theme_warning : String = "#D9822B"

///|
pub let theme_warning_light : String = "#FBF3E8"

///|
pub let theme_danger : String = "#D64550"

///|
pub let theme_danger_light : String = "#FBEDED"

///|
pub let theme_info : String = "#6B7480"

///|
pub let theme_info_light : String = "#F0F2F4"

///|
pub let theme_text_primary : String = "#2A2F36"

///|
pub let theme_text_regular : String = "#4E5560"

///|
pub let theme_text_secondary : String = "#6B7480"

///|
pub let theme_border : String = "#D8DCE1"

///|
pub let theme_fill_hover : String = "#EFF1F3"

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
/// 焦点环:双层 1px 主题色描边(叠加近似 2px),聚焦的自绘交互项画在内容之上。
fn draw_focus_ring(p : Painter, w : Double, h : Double, color? : String = theme_primary) -> Unit {
  p.set_stroke_color(color)
  p.stroke_rect(0.5, 0.5, w - 1.0, h - 1.0)
  p.stroke_rect(1.5, 1.5, w - 3.0, h - 3.0)
}

///|
/// 自绘交互项的焦点接线:可聚焦(Tab 链由 GTK 按挂载顺序遍历)、
/// 聚焦变化时重绘、Enter/Space 触发激活。点击聚焦由各组件在
/// on_mouse_down 里调 focus()。
fn bind_focus(
  v : Container,
  repaint : () -> Unit,
  focused : Ref[Bool],
  on_activate : () -> Unit,
) -> Unit {
  v.set_focusable(true)
  v.on_focus_in(fn() {
    focused.val = true
    repaint()
    false
  })
  v.on_focus_out(fn() {
    focused.val = false
    repaint()
    false
  })
  v.on_key_down(fn(e) {
    if e.code == VKEY_RETURN || e.code == VKEY_SPACE {
      on_activate()
      true
    } else {
      false
    }
  })
}

///|
/// 自绘交互项通用挂载器:背景色表达 hover/active,文字垂直居中。
/// bg_of(active, hover) 返回背景色(空串表示透明);fg_of(active) 返回文字色。
/// align_start=false 时文字水平居中(分段/分页),true 时左对齐(菜单)。
/// (GTK 端水平 align 未实现,居中一律手动:测文本宽、x=(w-文本宽)/2。)
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
      let focused = Ref(false)
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
        let copy = style.copy()
        copy.push(("width", text_w + pad_x * 2.0))
        copy
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
        // 文字:AttributedText 支持指定字号,垂直居中交给 valign=Center;
        // 水平位置手动计算(见函数注释)
        let at = AttributedText::new(text, valign=Center, wrap=false)
        at.set_font(font)
        at.set_color(fg_of(act, hover.val))
        p.draw_attributed_text(
          at,
          if align_start {
            pad_x
          } else {
            (w - text_w) / 2.0
          },
          0.0,
          w,
          h,
        )
        if focused.val {
          draw_focus_ring(p, w, h)
        }
      }

      v.on_draw(draw_item)
      v.on_mouse_down(fn(e) {
        if e.button == 1 {
          v.focus()
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
      bind_focus(v, fn() { v.schedule_paint() }, focused, fn() {
        selected.set(text)
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
  vbox(nodes, style=[("width", width), ("padding", 6.0)], handle=fn(c) {
    c.set_background_color("#FFFFFF")
  })
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
  hbox(items, style=[("padding", 2.0)], style_str=[("alignItems", "center")], handle=fn(
    c,
  ) {
    c.set_background_color("#DEE0E3")
  })
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
      let c = Container::make(style=[
        ("width", w),
        ("height", h),
        ("marginRight", 8.0),
      ])
      c.on_draw(fn(p) {
        p.set_fill_color(type_light_color(t))
        p.fill_rect(0.0, 0.0, w, h)
        // 水平手动居中(GTK 端 DrawAttributedText 不实现水平 align)
        p.draw_text(
          text,
          (w - text_w) / 2.0,
          0.0,
          w,
          h,
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
      let c = Container::make(style=[
        ("width", w),
        ("height", height),
        ("marginRight", 8.0),
      ])
      c.on_draw(fn(p) {
        p.set_fill_color(color)
        p.fill_rect(0.0, 0.0, w, height)
        p.draw_text(
          text,
          (w - text_w) / 2.0,
          0.0,
          w,
          height,
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
      let v = Container::make(style=[("height", height), ("marginBottom", 10.0)])
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
/// 分页(EP Pagination):‹ 页码 ›,当前页主题色实底白字,
/// 悬停浅蓝,28×28 直角,文字垂直居中。current 为共享状态(从 1 开始),
/// 点击直接写源 Store,全部按钮同步高亮。
pub fn pagination(current : Store[Int], pages : Int) -> Node {
  {
    mount: fn(parent) {
      let row = Container::make(style=[("height", 30.0)], style_str=[
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ])
      fn add_btn(label : String, target : Int, is_page : Bool) -> Unit {
        let hover = Ref(false)
        let focused = Ref(false)
        let probe = AttributedText::new(label, wrap=false)
        let label_w = probe.get_bounds_for(10000.0, 100.0).width
        let b = Container::make(style=[
          ("width", 28.0),
          ("height", 28.0),
          ("marginRight", 4.0),
        ])
        let activate = fn() -> Unit {
          if is_page {
            current.set(target)
          } else {
            current.update(fn(n) {
              let m = n + target
              if m < 1 {
                1
              } else if m > pages {
                pages
              } else {
                m
              }
            })
          }
        }

        b.on_draw(fn(p) {
          let bd = b.get_bounds()
          let cur = current.get()
          let act = is_page && cur == target
          if act {
            p.set_fill_color(theme_primary)
            p.fill_rect(0.0, 0.0, bd.width, bd.height)
          } else if hover.val {
            p.set_fill_color(theme_primary_light)
            p.fill_rect(0.0, 0.0, bd.width, bd.height)
          }
          p.draw_text(
            label,
            (bd.width - label_w) / 2.0,
            0.0,
            bd.width,
            bd.height,
            valign=Center,
            color=if act { "#FFFFFF" } else { theme_text_regular },
          )
          if focused.val {
            draw_focus_ring(p, bd.width, bd.height, color="#FFFFFF")
          }
        })
        b.on_mouse_down(fn(e) {
          if e.button == 1 {
            b.focus()
            activate()
            true
          } else {
            false
          }
        })
        bind_focus(b, fn() { b.schedule_paint() }, focused, activate)
        b.on_mouse_enter(fn(_e) {
          hover.val = true
          b.schedule_paint()
        })
        b.on_mouse_leave(fn(_e) {
          hover.val = false
          b.schedule_paint()
        })
        current.subscribe(fn(_v) { b.schedule_paint() })
        row.add_child(b)
      }

      add_btn("‹", -1, false)
      let mut i = 1
      while i <= pages {
        add_btn(i.to_string(), i, true)
        i = i + 1
      }
      add_btn("›", 1, false)
      attach(parent, row.view())
      row.view()
    },
  }
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
      let title = Container::make(style=[
        ("height", head_h),
        ("paddingLeft", 16.0),
      ])
      title.on_draw(fn(p) {
        let b = title.get_bounds()
        p.draw_attributed_text(title_at, 0.0, 0.0, b.width, head_h)
      })
      outer.add_child(title)
      // 内容区
      let body = Container::make(style=[("padding", 14.0)], style_str=[
        ("flexDirection", "column"),
      ])
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
    "fn", "let", "mut", "if", "else", "for", "while", "match", "return", "struct",
    "impl", "pub", "enum", "trait", "true", "false",
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
        out.push({ text: s, color: "#98C379", })
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
      out.push({ text: comment.to_string(), color: "#5C6370", })
      break
    } else if ch == ' ' {
      flush()
      out.push({ text: " ", color: "#ABB2BF", })
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
      return { text: word, color: "#C678DD", }
    }
  }
  let is_num = word.length() > 0
  for i in 0..<word.length() {
    let c = word.unsafe_get(i).to_int()
    if !((c >= 48 && c <= 57) || c == 46) {
      return { text: word, color: "#ABB2BF", }
    }
  }
  if is_num {
    return { text: word, color: "#D19A66", }
  }
  { text: word, color: "#ABB2BF", }
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
      let line_h = make_at("Ag", "#FFFFFF").get_bounds_for(10000.0, 100.0).height +
        5.0
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

///|
/// 头像:方形实底 + 白字居中(EP Avatar 的 square 形态)。
pub fn avatar(letter : String, color : String, size? : Double = 36.0) -> Node {
  {
    mount: fn(parent) {
      let probe = AttributedText::new(letter, wrap=false)
      let letter_w = probe.get_bounds_for(10000.0, 100.0).width
      let c = Container::make(style=[
        ("width", size),
        ("height", size),
        ("marginRight", 8.0),
      ])
      c.set_background_color(color)
      c.on_draw(fn(p) {
        let b = c.get_bounds()
        p.draw_text(
          letter,
          (b.width - letter_w) / 2.0,
          0.0,
          b.width,
          b.height,
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
/// 圆点徽标(EP Badge 的 dot 形态):8×8 色点。
pub fn badge_dot(color? : String = theme_danger) -> Node {
  container(
    on_draw=fn(p) {
      p.set_fill_color(color)
      p.fill_rect(0.0, 0.0, 10000.0, 10000.0)
    },
    style=[("width", 8.0), ("height", 8.0), ("marginRight", 6.0)],
  )
}

///|
/// 可关闭横幅:alert + 右侧关闭钮(点击整条隐藏)。
pub fn alert_closeable(text : String, t : SemanticType) -> Node {
  {
    mount: fn(parent) {
      let v = Container::make(
        style=[("height", 40.0), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let color = type_color(t)
      v.set_background_color(type_light_color(t))
      let label = Label::new("  " + text)
      label.set_color(color)
      v.add_child(label)
      // 弹性空白把关闭钮推到右端
      let spacer = Container::make(style=[("flex", 1.0), ("height", 1.0)])
      v.add_child(spacer)
      let close = Container::make(style=[("width", 32.0), ("height", 40.0)])
      let hover = Ref(false)
      let close_focused = Ref(false)
      let close_probe = AttributedText::new("✕", wrap=false)
      let close_w = close_probe.get_bounds_for(10000.0, 100.0).width
      let close_it = fn() -> Unit {
        v.set_visible(false)
      }

      close.on_draw(fn(p) {
        let b = close.get_bounds()
        p.draw_text(
          "✕",
          (b.width - close_w) / 2.0,
          0.0,
          b.width,
          b.height,
          valign=Center,
          color=if hover.val { color } else { theme_text_secondary },
        )
        if close_focused.val {
          draw_focus_ring(p, b.width, b.height)
        }
      })
      close.on_mouse_down(fn(e) {
        if e.button == 1 {
          close.focus()
          close_it()
          true
        } else {
          false
        }
      })
      bind_focus(close, fn() { close.schedule_paint() }, close_focused, close_it)
      close.on_mouse_enter(fn(_e) {
        hover.val = true
        close.schedule_paint()
      })
      close.on_mouse_leave(fn(_e) {
        hover.val = false
        close.schedule_paint()
      })
      v.add_child(close)
      // 让关闭钮靠右:中间垫一个弹性空白
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 步骤条(EP Steps):数字方块(完成浅蓝/当前实底/待办灰)+ 文字 + 连线。
pub fn steps(items : Array[String], current : Store[Int]) -> Node {
  {
    mount: fn(parent) {
      let row = Container::make(
        style=[("height", 40.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let font = Font::new("Sans", 13.0)
      let n = items.length()
      // 数字方块们,重绘时按 current 着色
      let boxes : Array[Container] = []
      for i in 0..<n {
        if i > 0 {
          let line = Container::make(style=[
            ("flex", 1.0),
            ("height", 2.0),
            ("marginRight", 6.0),
          ])
          let idx = i
          line.on_draw(fn(p) {
            let b = line.get_bounds()
            p.set_fill_color(
              if current.get() >= idx {
                theme_primary
              } else {
                theme_border
              },
            )
            p.fill_rect(0.0, 0.0, b.width, b.height)
          })
          row.add_child(line)
        }
        let bx = Container::make(style=[
          ("width", 24.0),
          ("height", 24.0),
          ("marginRight", 6.0),
        ])
        let num_probe = AttributedText::new((i + 1).to_string(), wrap=false)
        let num_w = num_probe.get_bounds_for(10000.0, 100.0).width
        bx.on_draw(fn(p) {
          let b = bx.get_bounds()
          let cur = current.get()
          let st = if i < cur {
            0 // done
          } else if i == cur {
            1 // active
          } else {
            2 // todo
          }
          p.set_fill_color(
            match st {
              0 => theme_primary_light
              1 => theme_primary
              _ => theme_info_light
            },
          )
          p.fill_rect(0.0, 0.0, b.width, b.height)
          p.draw_text(
            (i + 1).to_string(),
            (b.width - num_w) / 2.0,
            0.0,
            b.width,
            b.height,
            valign=Center,
            color=match st {
              0 => theme_primary
              1 => "#FFFFFF"
              _ => theme_text_secondary
            },
          )
        })
        current.subscribe(fn(_v) { bx.schedule_paint() })
        row.add_child(bx)
        boxes.push(bx)
      }
      for i in 0..<n {
        let l = Label::new(items[i])
        l.set_font(font)
        let cur_ref = current
        cur_ref.subscribe(fn(v) {
          l.set_color(
            if i <= v {
              theme_text_primary
            } else {
              theme_text_secondary
            },
          )
        })
        l.set_color(
          if i <= current.get() {
            theme_text_primary
          } else {
            theme_text_secondary
          },
        )
        row.add_child(l)
      }
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 折叠面板(EP Collapse):点击标题行切换内容显隐,各面板独立开合,
/// 初始仅第一面板展开。
pub fn collapse(panels : Array[(String, Array[Node])]) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(style=[("marginBottom", 12.0)], style_str=[
        ("flexDirection", "column"),
      ])
      let mut first = true
      for entry in panels {
        let open = Ref(first)
        first = false
        let head = Container::make(
          style=[("height", 34.0), ("paddingLeft", 12.0)],
          style_str=[("flexDirection", "row"), ("alignItems", "center")],
        )
        head.set_background_color(theme_info_light)
        let head_focused = Ref(false)
        head.on_draw(fn(p) {
          if head_focused.val {
            let b = head.get_bounds()
            draw_focus_ring(p, b.width, b.height)
          }
        })
        let arrow = Label::new(if open.val { "− " } else { "+ " })
        arrow.set_color(theme_primary)
        let title = Label::new(entry.0)
        title.set_color(theme_text_primary)
        head.add_child(arrow)
        head.add_child(title)
        let body = Container::make(style=[("padding", 10.0)], style_str=[
          ("flexDirection", "column"),
        ])
        body.set_background_color("#FFFFFF")
        for ch in entry.1 {
          ignore((ch.mount)(body.view()))
        }
        let apply = fn() -> Unit {
          body.set_visible(open.val)
          arrow.set_text(if open.val { "− " } else { "+ " })
        }
        let toggle = fn() -> Unit {
          open.val = !open.val
          apply()
        }

        apply()
        head.on_mouse_down(fn(e) {
          if e.button == 1 {
            head.focus()
            toggle()
            true
          } else {
            false
          }
        })
        bind_focus(head, fn() { head.schedule_paint() }, head_focused, toggle)
        let panel = Container::make(style=[("marginBottom", 6.0)], style_str=[
          ("flexDirection", "column"),
        ])
        panel.add_child(head)
        panel.add_child(body)
        outer.add_child(panel)
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 时间线(EP Timeline):左列色点+竖线,右列标题+描述。item 高固定 56。
pub fn timeline(items : Array[(String, String, SemanticType)]) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(style=[("marginBottom", 12.0)], style_str=[
        ("flexDirection", "column"),
      ])
      let n = items.length()
      let mut i = 0
      for entry in items {
        let is_last = i == n - 1
        let row = Container::make(style=[("height", 56.0)], style_str=[
          ("flexDirection", "row"),
        ])
        let node_col = Container::make(style=[("width", 20.0), ("height", 56.0)])
        let color = type_color(entry.2)
        node_col.on_draw(fn(p) {
          // 竖线贯穿(末项无线),节点色块居中
          let b = node_col.get_bounds()
          if !is_last {
            p.set_fill_color(theme_border)
            p.fill_rect(9.0, 0.0, 2.0, b.height)
          }
          p.set_fill_color(color)
          p.fill_rect(5.0, b.height / 2.0 - 5.0, 10.0, 10.0)
        })
        let text_col = Container::make(
          style=[("paddingLeft", 8.0), ("flex", 1.0)],
          style_str=[("flexDirection", "column")],
        )
        let title = Label::new(entry.0)
        title.set_color(theme_text_primary)
        title.set_align(Start)
        let desc = Label::new(entry.1)
        desc.set_color(theme_text_secondary)
        desc.set_align(Start)
        text_col.add_child(title)
        text_col.add_child(desc)
        row.add_child(node_col)
        row.add_child(text_col)
        outer.add_child(row)
        i = i + 1
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 描述列表(EP Descriptions):键灰值深的两列网格。
pub fn descriptions(pairs : Array[(String, String)]) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(style=[("marginBottom", 12.0)], style_str=[
        ("flexDirection", "column"),
      ])
      for kv in pairs {
        let row = Container::make(style=[("height", 26.0)], style_str=[
          ("flexDirection", "row"),
          ("alignItems", "center"),
        ])
        let k = Label::new(kv.0)
        k.set_color(theme_text_secondary)
        k.set_align(Start)
        let v = Label::new(kv.1)
        v.set_color(theme_text_primary)
        v.set_align(Start)
        let key_wrap = Container::make(style=[("width", 110.0)])
        key_wrap.add_child(k)
        row.add_child(key_wrap)
        row.add_child(v)
        outer.add_child(row)
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 结果页(EP Result):大色块符号 + 标题 + 描述 + 自定义按钮区。
pub fn result(
  t : SemanticType,
  title : String,
  desc : String,
  children : Array[Node],
) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(
        style=[("height", 180.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "column"), ("alignItems", "center")],
      )
      let icon = Container::make(style=[
        ("width", 56.0),
        ("height", 56.0),
        ("marginTop", 16.0),
      ])
      let color = type_color(t)
      let symbol = match t {
        Success => "✓"
        Danger => "✕"
        _ => "!"
      }
      let symbol_probe = AttributedText::new(symbol, wrap=false)
      let symbol_w = symbol_probe.get_bounds_for(10000.0, 100.0).width

      icon.set_background_color(type_light_color(t))
      icon.on_draw(fn(p) {
        let b = icon.get_bounds()
        p.draw_text(
          symbol,
          (b.width - symbol_w) / 2.0,
          0.0,
          b.width,
          b.height,
          valign=Center,
          color~,
        )
      })
      let big = Container::make(style=[("height", 30.0)], style_str=[
        ("alignItems", "center"),
      ])
      let t1 = Label::new(title)
      t1.set_font(Font::new("Sans", 18.0, weight=SemiBold))
      t1.set_color(theme_text_primary)
      big.add_child(t1)
      let sub = Container::make(style=[("height", 24.0)], style_str=[
        ("alignItems", "center"),
      ])
      let t2 = Label::new(desc)
      t2.set_color(theme_text_secondary)
      sub.add_child(t2)
      let btns = Container::make(style=[("marginTop", 8.0)], style_str=[
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ])
      for ch in children {
        ignore((ch.mount)(btns.view()))
      }
      outer.add_child(icon)
      outer.add_child(big)
      outer.add_child(sub)
      outer.add_child(btns)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 空状态(EP Empty):灰块占位 + 居中说明。
pub fn empty(desc : String) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(
        style=[("height", 140.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "column"), ("alignItems", "center")],
      )
      let box = Container::make(style=[
        ("width", 64.0),
        ("height", 64.0),
        ("marginTop", 14.0),
      ])
      box.set_background_color(theme_info_light)
      let empty_probe = AttributedText::new("∅", wrap=false)
      let empty_w = empty_probe.get_bounds_for(10000.0, 100.0).width
      box.on_draw(fn(p) {
        let b = box.get_bounds()
        p.draw_text(
          "∅",
          (b.width - empty_w) / 2.0,
          0.0,
          b.width,
          b.height,
          valign=Center,
          color=theme_text_secondary,
        )
      })
      let cap = Container::make(style=[("height", 26.0), ("marginTop", 6.0)], style_str=[
        ("alignItems", "center"),
      ])
      let l = Label::new(desc)
      l.set_color(theme_text_secondary)
      cap.add_child(l)
      outer.add_child(box)
      outer.add_child(cap)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 数值统计(EP Statistic):大号数值(响应式)+ 灰色标题。
pub fn statistic(title : String, value : Store[String]) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(style=[("marginRight", 24.0)], style_str=[
        ("flexDirection", "column"),
      ])
      let num = Label::new(value.get())
      num.set_font(Font::new("Sans", 24.0, weight=SemiBold))
      num.set_color(theme_text_primary)
      let cap = Label::new(title)
      cap.set_color(theme_text_secondary)
      value.subscribe(fn(v) { num.set_text(v) })
      outer.add_child(num)
      outer.add_child(cap)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 线性进度条(EP Progress):背景浅灰轨道 + 主题色填充,
/// value 为 Store(0..1),变化自动重绘。
pub fn progress_line(value : Store[Double], height? : Double = 8.0) -> Node {
  {
    mount: fn(parent) {
      let v = Container::make(style=[("flex", 1.0), ("height", height)])
      v.set_background_color(theme_info_light)
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let frac = value.get()
        if frac > 0.0 {
          p.set_fill_color(theme_primary)
          p.fill_rect(0.0, 0.0, b.width * frac, b.height)
        }
      })
      value.subscribe(fn(_x) { v.schedule_paint() })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 文字角色(主题排版体系):字号与颜色随角色统一。
pub(all) enum TextRole {
  Title
  Section
  Body
  Secondary
  Accent
}

///|
fn role_font(role : TextRole) -> Font {
  match role {
    Title => Font::new("Sans", 18.0, weight=SemiBold)
    Section => Font::new("Sans", 14.0, weight=SemiBold)
    Body => Font::new("Sans", 13.0)
    Secondary => Font::new("Sans", 12.0)
    Accent => Font::new("Sans", 13.0, weight=SemiBold)
  }
}

///|
fn role_color(role : TextRole) -> String {
  match role {
    Title => theme_text_primary
    Section => theme_text_primary
    Body => theme_text_regular
    Secondary => theme_text_secondary
    Accent => theme_primary
  }
}

///|
/// 主题化标签:文字角色统一字号/颜色,左对齐。
pub fn label_t(text : String, role? : TextRole = Body) -> Node {
  {
    mount: fn(parent) {
      let l = Label::new(text)
      l.set_font(role_font(role))
      l.set_color(role_color(role))
      l.set_align(Start)
      attach(parent, l.view())
      l.view()
    },
  }
}

///|
/// 按钮变体:Solid 主题色实底白字 / Soft 浅底主题色字 /
/// Text 透明底主题色字 / Danger 红色实底白字。
pub(all) enum ButtonVariant {
  Solid
  Soft
  Text
  Danger
}

///|
/// 主题化按钮(自绘,hover 全程收敛在主题内,不交给原生样式):
/// Solid hover 加深 / Soft hover 变实底白字 / Text hover 浅灰底 /
/// Danger hover 加深。
pub fn button_t(
  text : String,
  on_click? : () -> Unit = fn() {  },
  variant? : ButtonVariant = Soft,
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let focused = Ref(false)
      let font = Font::new("Sans", 13.0)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let w = text_w + 32.0
      let v = Container::make(style=[
        ("width", w),
        ("height", 32.0),
        ("marginRight", 8.0),
      ])
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let bg = match variant {
          Solid =>
            if hover.val {
              theme_primary_hover
            } else {
              theme_primary
            }
          Soft =>
            if hover.val {
              theme_primary
            } else {
              theme_primary_light
            }
          Text =>
            if hover.val {
              theme_fill_hover
            } else {
              ""
            }
          Danger =>
            if hover.val {
              theme_danger_hover
            } else {
              theme_danger
            }
        }
        let fg = match variant {
          Solid => "#FFFFFF"
          Soft => if hover.val { "#FFFFFF" } else { theme_primary }
          Text => theme_primary
          Danger => "#FFFFFF"
        }
        if bg != "" {
          p.set_fill_color(bg)
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        // GTK 端 DrawAttributedText 只实现 valign,水平 align 无效——
        // 用 mount 时测的文本宽手动水平居中。
        let at = AttributedText::new(text, valign=Center, wrap=false)
        at.set_font(font)
        at.set_color(fg)
        p.draw_attributed_text(
          at,
          (b.width - text_w) / 2.0,
          0.0,
          b.width,
          b.height,
        )
        // 实底变体上主题色环不可见,焦点环用白色
        if focused.val {
          draw_focus_ring(
            p,
            b.width,
            b.height,
            color=match variant {
              Solid => "#FFFFFF"
              Danger => "#FFFFFF"
              _ => theme_primary
            },
          )
        }
      })
      v.on_mouse_down(fn(e) {
        if e.button == 1 {
          v.focus()
          on_click()
          true
        } else {
          false
        }
      })
      bind_focus(v, fn() { v.schedule_paint() }, focused, on_click)
      v.on_mouse_enter(fn(_e) {
        hover.val = true
        v.schedule_paint()
      })
      v.on_mouse_leave(fn(_e) {
        hover.val = false
        v.schedule_paint()
      })
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 主题化单行输入:统一字体与前景色。
pub fn entry_t(
  text? : String = "",
  password? : Bool = false,
  on_input? : (String) -> Unit = fn(_s) {  },
) -> Node {
  {
    mount: fn(parent) {
      let e = match password {
        true => Entry::make(text~, entry_type=Password)
        false => Entry::make(text~, entry_type=Normal)
      }
      // 注:GTK Entry 上 set_color 会连带渲染背景变黑,故只统一字体
      e.set_font(Font::new("Sans", 13.0))
      e.on_text_change(fn() { on_input(e.get_text()) })
      attach(parent, e.view())
      e.view()
    },
  }
}

///|
/// 主题化复选框(自绘,替代原生控件:GTK 原生 Checkbox 的 hover 高亮圈
/// 与直角主题冲突):14x14 直角方框,选中实心主题色 + 白勾,
/// hover 边框变主题色,含禁用态。
pub fn checkbox_t(
  title : String,
  checked? : Bool = false,
  disabled? : Bool = false,
  on_change? : (Bool) -> Unit = fn(_v) {  },
) -> Node {
  {
    mount: fn(parent) {
      let state = Ref(checked)
      let hover = Ref(false)
      let focused = Ref(false)
      let font = Font::new("Sans", 13.0)
      let probe = AttributedText::new(title, wrap=false)
      probe.set_font(font)
      let w = probe.get_bounds_for(10000.0, 100.0).width + 30.0
      let v = Container::make(style=[
        ("width", w),
        ("height", 24.0),
        ("marginBottom", 6.0),
      ])
      let activate = fn() -> Unit {
        state.val = !state.val
        on_change(state.val)
        v.schedule_paint()
      }

      v.on_draw(fn(p) {
        let by = 5.0
        p.set_stroke_color(
          if disabled {
            theme_border
          } else if state.val || hover.val {
            theme_primary
          } else {
            theme_border
          },
        )
        p.stroke_rect(0.5, by + 0.5, 13.0, 13.0)
        if state.val {
          p.set_fill_color(if disabled { theme_border } else { theme_primary })
          p.fill_rect(2.0, by + 2.0, 10.0, 10.0)
          let check = AttributedText::new("✓", wrap=false)
          check.set_font(font)
          check.set_color("#FFFFFF")
          let check_w = check.get_bounds_for(10000.0, 100.0).width
          p.draw_attributed_text(
            check,
            (14.0 - check_w) / 2.0,
            by,
            14.0,
            14.0,
          )
        }
        let at = AttributedText::new(title, valign=Center, wrap=false)
        at.set_font(font)
        at.set_color(if disabled { theme_border } else { theme_text_regular })
        p.draw_attributed_text(at, 22.0, 0.0, w, 24.0)
        if focused.val {
          draw_focus_ring(p, w, 24.0)
        }
      })
      let repaint = fn() -> Unit {
        if !disabled {
          v.schedule_paint()
        }
      }
      v.on_mouse_down(fn(e) {
        if e.button == 1 && !disabled {
          v.focus()
          activate()
          true
        } else {
          false
        }
      })
      v.on_mouse_enter(fn(_e) {
        hover.val = true
        repaint()
      })
      v.on_mouse_leave(fn(_e) {
        hover.val = false
        repaint()
      })
      if !disabled {
        bind_focus(v, repaint, focused, activate)
      }
      attach(parent, v.view())
      v.view()
    },
  }
}

///|
/// 单选组:选中项实心方块 + 主题色文字,未选中空心方块,点击互斥。
/// 整行自绘(文字不挂子件,hover 全行生效);GTK 端原生 Radio 不共享组
/// 无法互斥,故自绘指示器。
pub fn radio_group(
  options : Array[String],
  selected : Store[String],
  disabled? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(style=[("marginBottom", 10.0)], style_str=[
        ("flexDirection", "column"),
      ])
      let font = Font::new("Sans", 13.0)
      let rows : Array[Container] = []
      let mut idx = 0
      for opt in options {
        let i = idx
        let probe = AttributedText::new(opt, wrap=false)
        probe.set_font(font)
        let w = probe.get_bounds_for(10000.0, 100.0).width + 30.0
        let hover = Ref(false)
        let focused = Ref(false)
        let row = Container::make(style=[("width", w), ("height", 28.0)])
        let activate = fn() -> Unit {
          selected.set(opt)
        }

        row.on_draw(fn(p) {
          let act = selected.get() == opt
          p.set_stroke_color(
            if disabled {
              theme_border
            } else if act || hover.val {
              theme_primary
            } else {
              theme_border
            },
          )
          p.stroke_rect(0.5, 7.5, 13.0, 13.0)
          if act {
            p.set_fill_color(
              if disabled {
                theme_border
              } else {
                theme_primary
              },
            )
            p.fill_rect(4.0, 11.0, 6.0, 6.0)
          }
          let at = AttributedText::new(opt, valign=Center, wrap=false)
          at.set_font(font)
          at.set_color(
            if disabled {
              theme_border
            } else if act {
              theme_text_primary
            } else if hover.val {
              theme_primary
            } else {
              theme_text_regular
            },
          )
          p.draw_attributed_text(at, 22.0, 0.0, w, 28.0)
          if focused.val {
            draw_focus_ring(p, w, 28.0)
          }
        })
        let repaint = fn() -> Unit {
          if !disabled {
            row.schedule_paint()
          }
        }
        row.on_mouse_down(fn(e) {
          if e.button == 1 && !disabled {
            row.focus()
            activate()
            true
          } else {
            false
          }
        })
        row.on_mouse_enter(fn(_e) {
          hover.val = true
          repaint()
        })
        row.on_mouse_leave(fn(_e) {
          hover.val = false
          repaint()
        })
        if !disabled {
          row.set_focusable(true)
          row.on_focus_in(fn() {
            focused.val = true
            repaint()
            false
          })
          row.on_focus_out(fn() {
            focused.val = false
            repaint()
            false
          })
          // Enter/Space 选中;方向键在组内移动选中并跟随焦点
          row.on_key_down(fn(e) {
            if e.code == VKEY_RETURN || e.code == VKEY_SPACE {
              activate()
              true
            } else if e.code == VKEY_DOWN || e.code == VKEY_RIGHT {
              if i + 1 < options.length() {
                selected.set(options[i + 1])
                rows[i + 1].focus()
                true
              } else {
                false
              }
            } else if e.code == VKEY_UP || e.code == VKEY_LEFT {
              if i > 0 {
                selected.set(options[i - 1])
                rows[i - 1].focus()
                true
              } else {
                false
              }
            } else {
              false
            }
          })
        }
        selected.subscribe(fn(_s) { repaint() })
        rows.push(row)
        outer.add_child(row)
        idx = idx + 1
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 开关(EP Switch 的直角形态):轨道 + 滑块,开=主题蓝轨道滑块靠右,
/// 关=浅灰轨道滑块靠左;点击切换,状态存于 Store[Bool]。
pub fn switch_t(checked : Store[Bool], disabled? : Bool = false) -> Node {
  {
    mount: fn(parent) {
      let v = Container::make(style=[("width", 40.0), ("height", 18.0)])
      let focused = Ref(false)
      let activate = fn() -> Unit {
        checked.set(!checked.get())
      }

      let slider_w = 14.0
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let on = checked.get()
        p.set_fill_color(if on { theme_primary } else { theme_border })
        p.fill_rect(0.0, 0.0, b.width, b.height)
        let sx = if on { b.width - slider_w - 2.0 } else { 2.0 }
        p.set_fill_color(if disabled { theme_info_light } else { "#FFFFFF" })
        p.fill_rect(sx, 2.0, slider_w, b.height - 4.0)
        if focused.val {
          draw_focus_ring(p, b.width, b.height)
        }
      })
      v.on_mouse_down(fn(e) {
        if e.button == 1 && !disabled {
          v.focus()
          activate()
          true
        } else {
          false
        }
      })
      checked.subscribe(fn(_v) { v.schedule_paint() })
      if !disabled {
        bind_focus(v, fn() { v.schedule_paint() }, focused, activate)
      }
      attach(parent, v.view())
      v.view()
    },
  }
}
