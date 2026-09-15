// Element Plus 风格非表单组件（纯 MoonBit，构建在声明式层之上）。
// 参照 deepin / 360 / 火绒等现代桌面软件的布局形态：
//   - side_menu  侧边导航菜单（选中高亮 + 强调条，页面联动）
//   - segmented  分段控制器 / 顶栏导航
//   - tag        彩色标签
//   - code_view  代码高亮视图（逐 token 自绘，绕开 Windows 区间设色缺陷）
// 组件间状态协调统一走 Store（订阅/派生），无任何平台代码。

///|
/// 彩色标签:圆角色块 + 白色文字,挂载时按文本测宽自适应。
pub fn tag(text : String, color : String, height? : Double = 22.0) -> Node {
  {
    mount: fn(parent) {
      let font = Font::new("Sans", 12.0)
      let probe = AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let w = text_w + 18.0
      let c = Container::make(
        style=[("width", w), ("height", height), ("marginRight", 8.0)],
      )
      c.on_draw(fn(p) {
        let r = 8.0
        let pi2 = 6.2831852
        p.set_fill_color(color)
        p.begin_path()
        p.move_to(r, 0.0)
        p.line_to(w - r, 0.0)
        p.arc(w - r, r, r, 4.712389, pi2)
        p.line_to(w, height - r)
        p.arc(w - r, height - r, r, 0.0, 1.5707963)
        p.line_to(r, height)
        p.arc(r, height - r, r, 1.5707963, 3.1415926)
        p.line_to(0.0, r)
        p.arc(r, r, r, 3.1415926, 4.712389)
        p.fill()
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
/// 分段控制器 / 顶栏导航：横排选项，选中项白底浮起（Element Plus 风格）。
/// selected 为共享状态，可与 side_menu 等组件订阅同一 Store 联动。
pub fn segmented(options : Array[String], selected : Store[String]) -> Node {
  let items : Array[Node] = []
  for opt in options {
    items.push(segmented_item(opt, selected))
  }
  hbox(
    items,
    style=[("padding", 3.0)],
    style_str=[("alignItems", "center")],
    handle=fn(c) { c.set_background_color("#E9EAEC") },
  )
}

///|
fn segmented_item(text : String, selected : Store[String]) -> Node {
  {
    mount: fn(parent) {
      let c = Container::make(
        style=[
          ("paddingLeft", 14.0),
          ("paddingRight", 14.0),
          ("height", 26.0),
        ],
        style_str=[("alignItems", "center")],
      )
      let l = Label::new(text)
      c.add_child(l)
      fn apply(active : Bool) {
        c.set_background_color(if active { "#FFFFFF" } else { "#E9EAEC" })
      }
      apply(selected.get() == text)
      selected.subscribe(fn(s) { apply(s == text) })
      c.on_mouse_down(fn(e) {
        if e.button == 1 {
          selected.set(text)
          true
        } else {
          false
        }
      })
      attach(parent, c.view())
      c.view()
    },
  }
}

///|
/// 侧边导航菜单：选中项强调条 + 主题浅蓝底（deepin / 火绒桌面软件风格）。
/// selected 为共享状态；主区页面可订阅同一 Store 做 set_visible 联动。
pub fn side_menu(items : Array[String], selected : Store[String]) -> Node {
  let nodes : Array[Node] = []
  for it in items {
    nodes.push(side_menu_item(it, selected))
  }
  vbox(
    nodes,
    style=[("width", 180.0), ("padding", 8.0)],
    handle=fn(c) { c.set_background_color("#F7F8FA") },
  )
}

///|
fn side_menu_item(text : String, selected : Store[String]) -> Node {
  {
    mount: fn(parent) {
      let row = Container::make(
        style=[("padding", 8.0), ("marginBottom", 2.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      let bar = Container::make(
        style=[("width", 3.0), ("height", 14.0), ("marginRight", 8.0)],
      )
      bar.set_background_color("#409EFF")
      row.add_child(bar)
      row.add_child(Label::new(text))
      fn apply(active : Bool) {
        bar.set_visible(active)
        row.set_background_color(if active { "#E8F3FF" } else { "#F7F8FA" })
      }
      apply(selected.get() == text)
      selected.subscribe(fn(s) { apply(s == text) })
      row.on_mouse_down(fn(e) {
        if e.button == 1 {
          selected.set(text)
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
/// 代码高亮的着色单元。
pub(all) struct Token {
  text : String
  color : String
}

///|
/// MoonBit 风格的极简着色器：关键字 / 数字 / 字符串 / 注释 / 普通文本。
/// 仅供演示；消费方可换成任意词法分析结果后直接用 code_view_tokens。
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
/// 代码高亮视图：逐 token 建 AttributedText（整段设色）+ 测宽后自绘排版。
/// 等价于「区间设色」的视觉效果，但全平台行为一致——Windows 上
/// AttributedText 区间字体/颜色是上游缺陷（见 docs/adaptation.md），此法绕开。
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

      // 挂载时预排版：逐 token 测宽，避免每次重绘重复分词/测量
      let line_h = make_at("Ag", "#FFFFFF").get_bounds_for(10000.0, 100.0).height + 5.0
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
