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
/// 主题色板。经 [theme_apply] 定制（initialize 之后、mount 之前调用最佳）；
/// 组件每次绘制/挂载经 getter 读取当前值。
///|
fn theme_primary() -> String { theme_box.t.primary }

///|
fn theme_primary_light() -> String { theme_box.t.primary_light }

///|
fn theme_primary_hover() -> String { theme_box.t.primary_hover }

///|
fn theme_danger_hover() -> String { theme_box.t.danger_hover }

///|
fn theme_success() -> String { theme_box.t.success }

///|
fn theme_success_light() -> String { theme_box.t.success_light }

///|
fn theme_warning() -> String { theme_box.t.warning }

///|
fn theme_warning_light() -> String { theme_box.t.warning_light }

///|
fn theme_danger() -> String { theme_box.t.danger }

///|
fn theme_danger_light() -> String { theme_box.t.danger_light }

///|
fn theme_info() -> String { theme_box.t.info }

///|
fn theme_info_light() -> String { theme_box.t.info_light }

///|
fn theme_text_primary() -> String { theme_box.t.text_primary }

///|
fn theme_text_regular() -> String { theme_box.t.text_regular }

///|
fn theme_text_secondary() -> String { theme_box.t.text_secondary }

///|
fn theme_border() -> String { theme_box.t.border }

///|
fn theme_fill_hover() -> String { theme_box.t.fill_hover }

///|
/// 主题色板快照。用结构体更新语法做局部定制：
///
/// ```moonbit
/// @yue.theme_apply(
///   @yue.Theme::{ primary: "#1E4FA3", primary_light: "#E3EDFA", ..@yue.default_theme() },
/// )
/// ```
pub struct Theme {
  primary : String
  primary_light : String
  primary_hover : String
  danger_hover : String
  success : String
  success_light : String
  warning : String
  warning_light : String
  danger : String
  danger_light : String
  info : String
  info_light : String
  text_primary : String
  text_regular : String
  text_secondary : String
  border : String
  fill_hover : String
}

///|
/// 当前内置默认主题（深色高级变体）。
pub fn default_theme() -> Theme {
  {
    primary: "#2D68C4",
    primary_light: "#E8F0FB",
    primary_hover: "#2459A8",
    danger_hover: "#BC3440",
    success: "#2E9E5B",
    success_light: "#E9F5EE",
    warning: "#D9822B",
    warning_light: "#FBF3E8",
    danger: "#D64550",
    danger_light: "#FBEDED",
    info: "#6B7480",
    info_light: "#F0F2F4",
    text_primary: "#2A2F36",
    text_regular: "#4E5560",
    text_secondary: "#6B7480",
    border: "#D8DCE1",
    fill_hover: "#EFF1F3",
  }
}

///|
/// 内置暗色主题变体：深底浅字，语义 light 变体取深色调。
/// 注意：仅自绘组件即时生效；原生控件与挂载时定死的静态色不受影响。
pub fn dark_theme() -> Theme {
  {
    primary: "#5B8DEF",
    primary_light: "#1E3A5F",
    primary_hover: "#7BA4F4",
    danger_hover: "#E9707A",
    success: "#4CB878",
    success_light: "#1D3B2A",
    warning: "#E5A04C",
    warning_light: "#43351F",
    danger: "#E5646E",
    danger_light: "#45242A",
    info: "#9AA0A6",
    info_light: "#2A2D31",
    text_primary: "#E8EAED",
    text_regular: "#BDC1C6",
    text_secondary: "#9AA0A6",
    border: "#3C4043",
    fill_hover: "#2A2D31",
  }
}

///|
/// 主题存储：单个可变快照，theme_apply 整体替换。
priv struct ThemeBox {
  mut t : Theme
}

///|
let theme_box : ThemeBox = { t: default_theme() }

///|
/// 读取当前主题快照。
pub fn theme_current() -> Theme {
  theme_box.t
}

///|
/// 应用主题。推荐在 initialize() 之后、创建界面（mount）之前调用：
/// 已挂载的自绘交互组件重绘时读到新色（hover/选中立即生效），
/// 挂载时定死的静态色（Label 文字、边框等）需重建界面才生效。
pub fn theme_apply(t : Theme) -> Unit {
  theme_box.t = t
}

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
    Primary => theme_primary()
    Success => theme_success()
    Warning => theme_warning()
    Danger => theme_danger()
    Info => theme_info()
  }
}

///|
fn type_light_color(t : SemanticType) -> String {
  match t {
    Primary => theme_primary_light()
    Success => theme_success_light()
    Warning => theme_warning_light()
    Danger => theme_danger_light()
    Info => theme_info_light()
  }
}

///|
/// 焦点环:双层 1px 主题色描边(叠加近似 2px),聚焦的自绘交互项画在内容之上。
fn draw_focus_ring(p : Painter, w : Double, h : Double, color? : String = theme_primary()) -> Unit {
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
    theme_primary_light()
  } else if hov {
    theme_fill_hover()
  } else {
    ""
  }
}

///|
fn side_menu_fg(act : Bool, _hov : Bool) -> String {
  if act {
    theme_primary()
  } else {
    theme_text_primary()
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
        // 外层 vbox 有 padding 6,项宽 = 总宽 − 两侧 padding,防向右溢出
        [("width", width - 12.0), ("height", 40.0)],
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
    theme_primary()
  } else {
    theme_text_regular()
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
  tag(count.to_string(), theme_danger(), height=18.0)
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
    theme_primary()
  } else {
    theme_text_secondary()
  }
}

///|
fn crumb_fg_static(_act : Bool, _hov : Bool) -> String {
  theme_text_secondary()
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
            p.set_fill_color(theme_primary())
            p.fill_rect(0.0, 0.0, bd.width, bd.height)
          } else if hover.val {
            p.set_fill_color(theme_primary_light())
            p.fill_rect(0.0, 0.0, bd.width, bd.height)
          }
          p.draw_text(
            label,
            (bd.width - label_w) / 2.0,
            0.0,
            bd.width,
            bd.height,
            valign=Center,
            color=if act { "#FFFFFF" } else { theme_text_regular() },
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
      let title_at = AttributedText::new(title, valign=Center, wrap=false)
      title_at.set_font(Font::new("Sans", 14.0, weight=Bold))
      title_at.set_color(theme_text_primary())
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
pub fn badge_dot(color? : String = theme_danger()) -> Node {
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
          color=if hover.val { color } else { theme_text_secondary() },
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
                theme_primary()
              } else {
                theme_border()
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
              0 => theme_primary_light()
              1 => theme_primary()
              _ => theme_info_light()
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
              0 => theme_primary()
              1 => "#FFFFFF"
              _ => theme_text_secondary()
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
              theme_text_primary()
            } else {
              theme_text_secondary()
            },
          )
        })
        l.set_color(
          if i <= current.get() {
            theme_text_primary()
          } else {
            theme_text_secondary()
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
        head.set_background_color(theme_info_light())
        let head_focused = Ref(false)
        head.on_draw(fn(p) {
          if head_focused.val {
            let b = head.get_bounds()
            draw_focus_ring(p, b.width, b.height)
          }
        })
        // 自绘折叠指示(V 形折线,不依赖字体字形)
        let arrow = Container::make(
          style=[("width", 12.0), ("height", 12.0), ("marginRight", 5.0)],
        )
        arrow.on_draw(fn(p) {
          p.set_stroke_color(theme_primary())
          for off in [0.0, 0.6] {
            p.begin_path()
            if open.val {
              p.move_to(1.5 + off, 4.0)
              p.line_to(6.0 + off, 8.0)
              p.line_to(10.5 + off, 4.0)
            } else {
              p.move_to(4.0, 1.5 + off)
              p.line_to(8.0, 6.0 + off)
              p.line_to(4.0, 10.5 + off)
            }
            p.stroke()
          }
        })
        let title = Label::new(entry.0)
        title.set_color(theme_text_primary())
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
          arrow.schedule_paint()
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
            p.set_fill_color(theme_border())
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
        title.set_color(theme_text_primary())
        title.set_align(Start)
        let desc = Label::new(entry.1)
        desc.set_color(theme_text_secondary())
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
        k.set_color(theme_text_secondary())
        k.set_align(Start)
        let v = Label::new(kv.1)
        v.set_color(theme_text_primary())
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
      // 图标(76+16) + 标题 30 + 描述 24 + 按钮区(8+按钮高约 32)+ 底部留白
      let outer = Container::make(
        style=[("height", 208.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "column"), ("alignItems", "center")],
      )
      let icon = Container::make(style=[
        ("width", 76.0),
        ("height", 76.0),
        ("marginTop", 16.0),
      ])
      let color = type_color(t)
      let symbol = match t {
        Success => "✓"
        Danger => "✕"
        _ => "!"
      }
      let symbol_at = AttributedText::new(symbol, valign=Center, wrap=false)
      symbol_at.set_font(Font::new("Sans", 38.0, weight=Bold))
      symbol_at.set_color(color)
      let symbol_w = symbol_at.get_bounds_for(10000.0, 100.0).width

      icon.set_background_color(type_light_color(t))
      icon.on_draw(fn(p) {
        let b = icon.get_bounds()
        p.draw_attributed_text(
          symbol_at,
          (b.width - symbol_w) / 2.0,
          0.0,
          b.width,
          b.height,
        )
      })
      let big = Container::make(style=[("height", 30.0)], style_str=[
        ("alignItems", "center"),
      ])
      let t1 = Label::new(title)
      t1.set_font(Font::new("Sans", 18.0, weight=SemiBold))
      t1.set_color(theme_text_primary())
      big.add_child(t1)
      let sub = Container::make(style=[("height", 24.0)], style_str=[
        ("alignItems", "center"),
      ])
      let t2 = Label::new(desc)
      t2.set_color(theme_text_secondary())
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
        ("width", 96.0),
        ("height", 88.0),
        ("marginTop", 12.0),
      ])
      // 自绘简约空箱:盖 + 盒体,不依赖字体符号
      box.on_draw(fn(p) {
        let b = box.get_bounds()
        let cx = b.width / 2.0
        // 盒体
        p.set_fill_color(theme_fill_hover())
        p.fill_rect(cx - 26.0, 36.0, 52.0, 34.0)
        p.set_stroke_color(theme_border())
        p.stroke_rect(cx - 26.0, 36.0, 52.0, 34.0)
        // 盖(比体宽,略上叠)
        p.set_fill_color(theme_info_light())
        p.fill_rect(cx - 34.0, 22.0, 68.0, 14.0)
        p.stroke_rect(cx - 34.0, 22.0, 68.0, 14.0)
      })
      let cap = Container::make(style=[("height", 26.0), ("marginTop", 6.0)], style_str=[
        ("alignItems", "center"),
      ])
      let l = Label::new(desc)
      l.set_color(theme_text_secondary())
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
      num.set_color(theme_text_primary())
      let cap = Label::new(title)
      cap.set_color(theme_text_secondary())
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
      v.set_background_color(theme_info_light())
      v.on_draw(fn(p) {
        let b = v.get_bounds()
        let frac = value.get()
        if frac > 0.0 {
          p.set_fill_color(theme_primary())
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
    Title => theme_text_primary()
    Section => theme_text_primary()
    Body => theme_text_regular()
    Secondary => theme_text_secondary()
    Accent => theme_primary()
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
              theme_primary_hover()
            } else {
              theme_primary()
            }
          Soft =>
            if hover.val {
              theme_primary()
            } else {
              theme_primary_light()
            }
          Text =>
            if hover.val {
              theme_fill_hover()
            } else {
              ""
            }
          Danger =>
            if hover.val {
              theme_danger_hover()
            } else {
              theme_danger()
            }
        }
        let fg = match variant {
          Solid => "#FFFFFF"
          Soft => if hover.val { "#FFFFFF" } else { theme_primary() }
          Text => theme_primary()
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
              _ => theme_primary()
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
            theme_border()
          } else if state.val || hover.val {
            theme_primary()
          } else {
            theme_border()
          },
        )
        p.stroke_rect(3.5, by + 0.5, 13.0, 13.0)
        if state.val {
          p.set_fill_color(if disabled { theme_border() } else { theme_primary() })
          p.fill_rect(5.0, by + 2.0, 10.0, 10.0)
          // 白勾:折线两段,描两遍(错位 0.5px)近似 2px 线宽,不依赖字体
          p.set_stroke_color("#FFFFFF")
          for off in [0.0, 0.5] {
            p.begin_path()
            p.move_to(6.9 + off, by + 7.4)
            p.line_to(9.0 + off, by + 9.5)
            p.line_to(13.8 + off, by + 4.4)
            p.stroke()
          }
        }
        let at = AttributedText::new(title, valign=Center, wrap=false)
        at.set_font(font)
        at.set_color(if disabled { theme_border() } else { theme_text_regular() })
        p.draw_attributed_text(at, 25.0, 0.0, w, 24.0)
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
              theme_border()
            } else if act || hover.val {
              theme_primary()
            } else {
              theme_border()
            },
          )
          p.stroke_rect(3.5, 7.5, 13.0, 13.0)
          if act {
            p.set_fill_color(
              if disabled {
                theme_border()
              } else {
                theme_primary()
              },
            )
            p.fill_rect(7.0, 11.0, 6.0, 6.0)
          }
          let at = AttributedText::new(opt, valign=Center, wrap=false)
          at.set_font(font)
          at.set_color(
            if disabled {
              theme_border()
            } else if act {
              theme_text_primary()
            } else if hover.val {
              theme_primary()
            } else {
              theme_text_regular()
            },
          )
          p.draw_attributed_text(at, 25.0, 0.0, w, 28.0)
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
        p.set_fill_color(if on { theme_primary() } else { theme_border() })
        p.fill_rect(0.0, 0.0, b.width, b.height)
        let sx = if on { b.width - slider_w - 2.0 } else { 2.0 }
        p.set_fill_color(if disabled { theme_info_light() } else { "#FFFFFF" })
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


///|
/// 边框输入框:外层自绘 1px 边框(聚焦变主题色)+ 白底,
/// 内部 Entry 去 native 边框只负责文字;margin 控制外边距,直角。
pub fn input_t(
  text? : String = "",
  password? : Bool = false,
  margin? : Double = 0.0,
  width? : Double = 280.0,
  height? : Double = 40.0,
) -> Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      // 外框比内部输入区大:Entry 四周留 margin,高度给足避免溢出
      let outer = Container::make(
        style=[
          ("width", width),
          ("height", height),
          ("marginTop", margin),
          ("marginBottom", margin),
        ],
      )
      outer.set_background_color("#FFFFFF")
      outer.on_draw(fn(p) {
        let b = outer.get_bounds()
        p.set_stroke_color(
          if focused.val { theme_primary() } else { theme_border() },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
      })
      let entry = match password {
        true => Entry::make(text~, entry_type=Password)
        false => Entry::make(text~, entry_type=Normal)
      }
      entry.set_borderless(true)
      entry.set_background_color("#FFFFFF")
      entry.set_style("flex", 1.0)
      entry.set_style("marginLeft", 10.0)
      entry.set_style("marginRight", 10.0)
      entry.set_style("marginTop", 4.0)
      entry.set_style("marginBottom", 4.0)
      entry.on_focus_in(fn() {
        focused.val = true
        outer.schedule_paint()
        false
      })
      entry.on_focus_out(fn() {
        focused.val = false
        outer.schedule_paint()
        false
      })
      outer.add_child(entry)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 数字输入器(EP InputNumber):-/+ 按钮步进,范围钳制,状态存 Store[Double]。
pub fn input_number(
  value : Store[Double],
  min? : Double = 0.0,
  max? : Double = 100.0,
  step? : Double = 1.0,
) -> Node {
  {
    mount: fn(parent) {
      let row = Container::make(
        style=[("height", 30.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let font = Font::new("Sans", 13.0)
      fn step_btn(label : String, dir : Double) -> Unit {
        let b = Container::make(
          style=[("width", 28.0), ("height", 28.0)],
          style_str=[("alignItems", "center")],
        )
        b.set_background_color(theme_info_light())
        let hover = Ref(false)
        b.on_draw(fn(p) {
          let bd = b.get_bounds()
          p.set_fill_color(if hover.val { theme_primary_light() } else { theme_info_light() })
          p.fill_rect(0.0, 0.0, bd.width, bd.height)
          p.draw_text(
            label,
            0.0,
            0.0,
            bd.width,
            bd.height,
            align=Center,
            valign=Center,
            color=theme_text_regular(),
          )
        })
        b.on_mouse_down(fn(e) {
          if e.button == 1 {
            value.update(fn(n) {
              let m = n + dir * step
              if m < min {
                min
              } else if m > max {
                max
              } else {
                m
              }
            })
            true
          } else {
            false
          }
        })
        b.on_mouse_enter(fn(_e) {
          hover.val = true
          b.schedule_paint()
        })
        b.on_mouse_leave(fn(_e) {
          hover.val = false
          b.schedule_paint()
        })
        row.add_child(b)
      }

      step_btn("-", -1.0)
      let num = Container::make(
        style=[("width", 64.0), ("height", 28.0), ("marginRight", 6.0)],
        style_str=[("alignItems", "center")],
      )
      num.set_background_color("#FFFFFF")
      let t = AttributedText::new(
        value.get().to_string(),
        valign=Center,
        wrap=false,
      )
      t.set_font(font)
      t.set_color(theme_text_primary())
      num.on_draw(fn(p) {
        // GTK 端 DrawAttributedText 不实现水平 align,手动测宽居中
        let b = num.get_bounds()
        let tw = t.get_bounds_for(10000.0, 100.0).width
        p.draw_attributed_text(t, (b.width - tw) / 2.0, 0.0, b.width, b.height)
      })
      value.subscribe(fn(v) {
        t.set_text(v.to_string())
        num.schedule_paint()
      })
      row.add_child(num)
      step_btn("+", 1.0)
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 表单项:左侧标签(灰,定宽)+ 右侧控件区,垂直居中。
pub fn form_item(label : String, control : Node, label_width? : Double = 90.0) -> Node {
  {
    mount: fn(parent) {
      let row = Container::make(
        style=[("marginBottom", 10.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let k = Label::new(label)
      k.set_font(Font::new("Sans", 13.0))
      k.set_color(theme_text_secondary())
      k.set_align(End)
      let kwrap = Container::make(style=[("width", label_width), ("marginRight", 12.0)])
      kwrap.add_child(k)
      row.add_child(kwrap)
      ignore((control.mount)(row.view()))
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 表单:分组标题 + 一组表单项。
pub fn form(title : String, items : Array[Node]) -> Node {
  let nodes : Array[Node] = [label_t(title, role=Section)]
  for it in items {
    nodes.push(it)
  }
  vbox(nodes, style=[("marginBottom", 14.0)])
}

///|
/// 链接文字:主题色,悬停加深并显示下划线色条,点击回调。
pub fn link(text : String, on_click : () -> Unit) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let row = Container::make(
        style=[("paddingRight", 6.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let l = Label::new(text)
      l.set_font(Font::new("Sans", 13.0))
      l.set_color(theme_primary())
      row.add_child(l)
      let underline = Container::make(style=[("height", 1.0)])
      underline.set_background_color(theme_primary())
      row.add_child(underline)
      fn apply() -> Unit {
        underline.set_visible(hover.val)
      }

      apply()
      row.on_mouse_enter(fn(_e) {
        hover.val = true
        apply()
      })
      row.on_mouse_leave(fn(_e) {
        hover.val = false
        apply()
      })
      row.on_mouse_down(fn(e) {
        if e.button == 1 {
          on_click()
          true
        } else {
          false
        }
      })
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 页头(EP PageHeader):返回链接 + 标题 + 弹性空白 + 右侧操作区。
pub fn page_header(
  title : String,
  on_back : () -> Unit,
  actions? : Array[Node] = [],
) -> Node {
  {
    mount: fn(parent) {
      let row = Container::make(
        style=[("height", 40.0), ("marginBottom", 12.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let back = Container::make(
        style=[("width", 56.0), ("height", 40.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let hover = Ref(false)
      back.on_draw(fn(p) {
        let b = back.get_bounds()
        p.draw_text(
          "‹ 返回",
          0.0,
          0.0,
          b.width,
          b.height,
          align=Start,
          valign=Center,
          color=if hover.val { theme_primary() } else { theme_text_regular() },
        )
      })
      back.on_mouse_down(fn(e) {
        if e.button == 1 {
          on_back()
          true
        } else {
          false
        }
      })
      back.on_mouse_enter(fn(_e) {
        hover.val = true
        back.schedule_paint()
      })
      back.on_mouse_leave(fn(_e) {
        hover.val = false
        back.schedule_paint()
      })
      row.add_child(back)
      let t = Label::new(title)
      t.set_font(Font::new("Sans", 15.0, weight=SemiBold))
      t.set_color(theme_text_primary())
      row.add_child(t)
      let spacer = Container::make(style=[("flex", 1.0), ("height", 1.0)])
      row.add_child(spacer)
      for a in actions {
        ignore((a.mount)(row.view()))
      }
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 树节点数据。
pub(all) struct TreeNode {
  label : String
  children : Array[TreeNode]
}

///|
/// 树形控件(EP Tree):缩进层级 + 点击展开/折叠(有子节点时箭头指示)。
pub fn tree(root : Array[TreeNode]) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(
        style=[("marginBottom", 10.0), ("paddingTop", 2.0)],
        style_str=[("flexDirection", "column")],
      )
      let font = Font::new("Sans", 13.0)
      // 实心小三角箭头(矢量自绘,不依赖字体字形,避免 Windows 端字符发虚)
      fn draw_caret(p : Painter, open : Bool) -> Unit {
        p.set_fill_color(theme_text_secondary())
        p.begin_path()
        if open {
          p.move_to(2.0, 3.5)
          p.line_to(8.0, 3.5)
          p.line_to(5.0, 7.5)
        } else {
          p.move_to(3.5, 2.0)
          p.line_to(7.5, 5.0)
          p.line_to(3.5, 8.0)
        }
        p.close_path()
        p.fill()
      }

      fn build(nodes : Array[TreeNode], level : Int, into : Container) -> Unit {
        for nd in nodes {
          let has_children = nd.children.length() > 0
          let open = Ref(false)
          let indent = level.to_double() * 18.0
          let row = Container::make(
            style=[("height", 32.0), ("marginLeft", indent)],
            style_str=[("flexDirection", "row"), ("alignItems", "center")],
          )
          let arrow = Container::make(
            style=[("width", 10.0), ("height", 10.0), ("marginRight", 3.0)],
          )
          arrow.on_draw(fn(p) {
            if has_children {
              draw_caret(p, open.val)
            }
          })
          let label = Label::new(" " + nd.label)
          label.set_font(font)
          label.set_color(theme_text_primary())
          row.add_child(arrow)
          row.add_child(label)
          let kids = Container::make(
            style_str=[("flexDirection", "column")],
          )
          kids.set_visible(false)
          if has_children {
            build(nd.children, level + 1, kids)
          }
          row.on_mouse_down(fn(e) {
            if e.button == 1 && has_children {
              open.val = !open.val
              arrow.schedule_paint()
              kids.set_visible(open.val)
              true
            } else {
              false
            }
          })
          into.add_child(row)
          into.add_child(kids)
        }
      }

      build(root, 0, outer)
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 穿梭框(EP Transfer):左右两列,点击行选中(实心方块标记),
/// 中间 ›/‹ 按钮把选中项在两列间移动。数据经双 Store 驱动。
pub fn transfer(
  left_items : Store[Array[String]],
  right_items : Store[Array[String]],
  width? : Double = 160.0,
) -> Node {
  {
    mount: fn(parent) {
      let row = Container::make(
        style=[("marginBottom", 10.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let font = Font::new("Sans", 13.0)
      // 选中集合(按值),用 Ref 可变数组
      let left_sel : Ref[Array[String]] = Ref([])
      let right_sel : Ref[Array[String]] = Ref([])
      let left_box = Container::make(
        style=[("width", width)],
        style_str=[("flexDirection", "column")],
      )
      let right_box = Container::make(
        style=[("width", width)],
        style_str=[("flexDirection", "column")],
      )
      fn contains(arr : Array[String], s : String) -> Bool {
        for x in arr {
          if x == s {
            return true
          }
        }
        false
      }

      fn remove_one(arr : Array[String], s : String) -> Array[String] {
        let out : Array[String] = []
        let mut removed = false
        for x in arr {
          if !removed && x == s {
            removed = true
          } else {
            out.push(x)
          }
        }
        out
      }

      let left_rows : Ref[Array[View]] = Ref([])
      let right_rows : Ref[Array[View]] = Ref([])
      fn clear_list(box : Container, rows : Ref[Array[View]]) -> Unit {
        for v in rows.val {
          ignore(box.remove_child_view(v))
        }
        rows.val = []
      }

      fn build_list(
        box : Container,
        items : Store[Array[String]],
        sel : Ref[Array[String]],
        rows : Ref[Array[View]],
      ) -> Unit {
        for it in items.get() {
          let it_ref = it
          let row = Container::make(
            style=[("height", 26.0), ("paddingLeft", 8.0)],
            style_str=[("flexDirection", "row"), ("alignItems", "center")],
          )
          let mark = Container::make(
            style=[("width", 10.0), ("height", 10.0), ("marginRight", 6.0)],
          )
          mark.on_draw(fn(p) {
            let is_sel = contains(sel.val, it_ref)
            p.set_stroke_color(if is_sel { theme_primary() } else { theme_border() })
            p.stroke_rect(0.5, 0.5, 9.0, 9.0)
            if is_sel {
              p.set_fill_color(theme_primary())
              p.fill_rect(3.0, 3.0, 4.0, 4.0)
            }
          })
          let l = Label::new(it_ref)
          l.set_font(font)
          l.set_color(theme_text_regular())
          row.add_child(mark)
          row.add_child(l)
          let mark_ref = mark
          row.on_mouse_down(fn(e) {
            if e.button == 1 {
              if contains(sel.val, it_ref) {
                sel.val = remove_one(sel.val, it_ref)
              } else {
                let grown = sel.val.copy()
                grown.push(it_ref)
                sel.val = grown
              }
              mark_ref.schedule_paint()
              true
            } else {
              false
            }
          })
          box.add_child(row)
          rows.val.push(row.view())
        }
      }

      fn move_items(from : Store[Array[String]], to : Store[Array[String]], sel : Ref[Array[String]]) -> Unit {
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

      fn render_all() -> Unit {
        clear_list(left_box, left_rows)
        clear_list(right_box, right_rows)
        build_list(left_box, left_items, left_sel, left_rows)
        build_list(right_box, right_items, right_sel, right_rows)
      }

      left_items.subscribe(fn(_v) { render_all() })
      right_items.subscribe(fn(_v) { render_all() })
      fn mid_btn(label : String, to_right : Bool) -> Unit {
        let b = Container::make(
          style=[("width", 32.0), ("height", 28.0), ("marginRight", 8.0)],
          style_str=[("alignItems", "center")],
        )
        b.set_background_color(theme_info_light())
        b.on_draw(fn(p) {
          let bd = b.get_bounds()
          p.draw_text(
            label,
            0.0,
            0.0,
            bd.width,
            bd.height,
            align=Center,
            valign=Center,
            color=theme_text_regular(),
          )
        })
        b.on_mouse_down(fn(e) {
          if e.button == 1 {
            if to_right {
              move_items(left_items, right_items, left_sel)
            } else {
              move_items(right_items, left_items, right_sel)
            }
            true
          } else {
            false
          }
        })
        row.add_child(b)
      }

      row.add_child(left_box)
      mid_btn("›", true)
      mid_btn("‹", false)
      row.add_child(right_box)
      render_all()
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 自动补全(EP Autocomplete):entry_t 输入,候选项经过滤后弹出。
/// Linux 用 Entry::set_completion(GTK 原生补全弹层,不抢键盘焦点);
/// Windows 用无边框置顶小窗口弹层(悬浮不裁剪);macOS 回退为内联列表。
pub fn autocomplete(
  options : Array[String],
  value : Store[String],
  width? : Double = 280.0,
) -> Node {
  {
    mount: fn(parent) {
      let outer = Container::make(
        style=[("width", width), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "column")],
      )
      let entry = Entry::make(entry_type=Normal)
      entry.set_font(Font::new("Sans", 13.0))
      entry.set_borderless(true)
      // Win32 单行 EDIT 文字贴顶绘制(无垂直居中样式),压低控件高度
      // 使文字近似垂直居中;GTK/macOS 原生居中,维持 30
      entry.set_style("height", if platform() == "windows" { 22.0 } else { 30.0 })
      entry.set_background_color("#FFFFFF")
      let font = Font::new("Sans", 13.0)
      fn make_row(
        opt : String,
        selected : Ref[Bool],
        on_pick : () -> Unit,
      ) -> Container {
        let row = Container::make(
          style=[("height", 28.0), ("paddingLeft", 10.0)],
          style_str=[("flexDirection", "row"), ("alignItems", "center")],
        )
        let l = Label::new(opt)
        l.set_font(font)
        l.set_color(theme_text_regular())
        row.add_child(l)
        let hover = Ref(false)
        row.on_draw(fn(p) {
          let b = row.get_bounds()
          if hover.val || selected.val {
            p.set_fill_color(theme_primary_light())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
        })
        row.on_mouse_enter(fn(_e) {
          hover.val = true
          row.schedule_paint()
        })
        row.on_mouse_leave(fn(_e) {
          hover.val = false
          row.schedule_paint()
        })
        row.on_mouse_down(fn(e) {
          if e.button == 1 {
            on_pick()
            true
          } else {
            false
          }
        })
        row
      }

      fn pick(opt : String) -> Unit {
        value.set(opt)
        entry.set_text(opt)
      }

      // Linux 走 GTK 原生补全(选中项的文本回填由弹层完成,这里只更新值);
      // Windows 走 shim 的无边框置顶小窗口弹层;macOS 暂回退内联列表
      let use_completion = platform() == "linux"
      let use_popover = platform() == "windows"
      let list = Container::make(
        style=[("marginTop", 4.0), ("width", width)],
        style_str=[("flexDirection", "column")],
      )
      let inline_rows : Ref[Array[Container]] = Ref([])
      let pop : Ref[Popover?] = Ref(None)
      // 键盘导航状态(Windows 替代弹层无原生键盘交互,焦点保持在输入框,
      // 由 entry.on_key_down 驱动):sel 为当前高亮行下标,-1 表示无
      let sel : Ref[Int] = Ref(-1)
      let pick_fns : Ref[Array[() -> Unit]] = Ref([])
      let sel_marks : Ref[Array[Ref[Bool]]] = Ref([])
      fn set_sel(i : Int) -> Unit {
        let n = sel_marks.val.length()
        let ni = if i < -1 { -1 } else if i > n - 1 { n - 1 } else { i }
        if ni == sel.val {
          return
        }
        if sel.val >= 0 && sel.val < n {
          sel_marks.val[sel.val].val = false
          inline_rows.val[sel.val].schedule_paint()
        }
        sel.val = ni
        if ni >= 0 {
          sel_marks.val[ni].val = true
          inline_rows.val[ni].schedule_paint()
        }
      }
      fn refresh(filter : String) -> Unit {
        // 清空已有候选
        for v in inline_rows.val {
          ignore(list.remove_child_view(v.view()))
        }
        inline_rows.val = []
        pick_fns.val = []
        sel_marks.val = []
        sel.val = -1
        let mut count = 0
        let picked = Ref(false)
        for opt in options {
          if filter != "" && !opt.contains(filter) {
            continue
          }
          count = count + 1
          let o = opt
          let mark = Ref(false)
          fn do_pick() -> Unit {
            picked.val = true
            pick(o)
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
            for v in inline_rows.val {
              ignore(list.remove_child_view(v.view()))
            }
            inline_rows.val = []
          }
          let row = make_row(o, mark, do_pick)
          list.add_child(row)
          inline_rows.val.push(row)
          sel_marks.val.push(mark)
          pick_fns.val.push(do_pick)
        }
        if use_popover {
          match pop.val {
            Some(p) => {
              if count > 0 && !picked.val {
                p.set_content(list)
                p.set_content_size(width, count.to_double() * 28.0 + 8.0)
                p.show_relative_to(entry)
              } else {
                p.close()
              }
            }
            None => ()
          }
        }
      }

      if use_completion {
        entry.set_completion(options, fn(opt) { value.set(opt) })
      }
      if use_popover {
        pop.val = Some(Popover::new())
        // 替代弹层无原生键盘导航(焦点保持在输入框),这里自行处理:
        // ↑↓ 移动高亮、回车选中当前项、Esc 收起
        entry.on_key_down(fn(e) {
          let n = pick_fns.val.length()
          if n == 0 {
            return false
          }
          match e.code {
            VKEY_DOWN => {
              set_sel(sel.val + 1)
              true
            }
            VKEY_UP => {
              set_sel(if sel.val < 0 { n - 1 } else { sel.val - 1 })
              true
            }
            VKEY_RETURN => {
              if sel.val >= 0 && sel.val < n {
                pick_fns.val[sel.val]()
                true
              } else {
                false
              }
            }
            VKEY_ESCAPE => {
              match pop.val {
                Some(p) => p.close()
                None => ()
              }
              sel.val = -1
              true
            }
            _ => false
          }
        })
      }
      value.subscribe(fn(v) {
        if !use_popover || !entry.has_focus() {
          entry.set_text(v)
        }
      })
      if !use_completion {
        entry.on_text_change(fn() {
          refresh(entry.get_text())
        })
      }
      // 输入框失焦(点击别处/窗口最小化)时收起弹层
      entry.on_focus_out(fn() {
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      outer.add_child(entry)
      if !use_popover && !use_completion {
        outer.add_child(list)
      }
      attach(parent, outer.view())
      outer.view()
    },
  }
}

///|
/// 日期字段:主题化行内标签 + 原生日期选择器。
pub fn date_picker_t(label : String, on_change? : () -> Unit = fn() {  }) -> Node {
  {
    mount: fn(parent) {
      let row = Container::make(
        style=[("height", 34.0), ("marginBottom", 10.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let k = Label::new(label)
      k.set_font(Font::new("Sans", 13.0))
      k.set_color(theme_text_secondary())
      k.set_align(End)
      let kwrap = Container::make(style=[("width", 90.0), ("marginRight", 12.0)])
      kwrap.add_child(k)
      row.add_child(kwrap)
      let dp = DatePicker::new()
      dp.set_font(Font::new("Sans", 13.0))
      // 显式给足宽度:Windows 主题按内容最小宽布局,过窄只显示年份
      dp.set_style("width", 130.0)
      dp.on_date_change(fn() { on_change() })
      row.add_child(dp)
      attach(parent, row.view())
      row.view()
    },
  }
}

///|
/// 返回顶部浮动按钮:配合 scroll 句柄使用,点击回滚到顶部。
/// 放置于 relative 容器内时经 absolute 定位悬浮右下。
pub fn backtop_t(on_click : () -> Unit, size? : Double = 36.0) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let b = Container::make(
        style=[("width", size), ("height", size)],
      )
      b.set_background_color(theme_primary())
      b.on_draw(fn(p) {
        p.draw_text(
          "↑",
          0.0,
          0.0,
          size,
          size,
          align=Center,
          valign=Center,
          color="#FFFFFF",
        )
      })
      b.on_mouse_down(fn(e) {
        if e.button == 1 {
          on_click()
          true
        } else {
          false
        }
      })
      b.on_mouse_enter(fn(_e) {
        hover.val = true
        b.set_background_color("#1E56A8")
      })
      b.on_mouse_leave(fn(_e) {
        hover.val = false
        b.set_background_color(theme_primary())
      })
      attach(parent, b.view())
      b.view()
    },
  }
}
