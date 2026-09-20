// L2 组件:markdown_view —— 基于 AttributedText 范围属性的 Markdown
// 展示视图。块级语法:标题 1-6、围栏代码块(复用 code_view,语言随
// fence 标注)、引用、无序/有序列表、分隔线;行内语法:**粗体**、
// *斜体*、`行内代码`、[链接](url)(链接色文字)。区间字体/颜色经
// AttributedText::set_font_for/set_color_for,三平台一致(Windows
// 分段绘制,见 fork v0.15.6-mbt.9)。

///|
/// 行内片段:一段带样式的文本。
priv struct MDSpan {
  text : String
  bold : Bool
  italic : Bool
  code : Bool
  link : Bool
}

///|
/// 行内解析:识别 **粗体**、*斜体*、`代码`、[文本](url)。
/// 实现为标记切换的线性扫描:遇到成对标记翻转对应状态,代码段内部
/// 不再解析其他标记。
fn md_parse_inline(text : String) -> Array[MDSpan] {
  let spans : Array[MDSpan] = []
  let buf = Ref(StringBuilder())
  let bold = Ref(false)
  let italic = Ref(false)
  let code = Ref(false)
  let link_text = Ref(false) // [ ] 内部(链接文字段)
  let link_url = Ref(false)  // ( ) 内部(链接地址,不渲染)
  let cs : Array[Char] = []
  for ch in text {
    cs.push(ch)
  }
  let n = cs.length()
  fn flush() -> Unit {
    let t = buf.val.to_string()
    buf.val = StringBuilder()
    if t.length() > 0 {
      spans.push({
        text: t,
        bold: bold.val,
        italic: italic.val,
        code: code.val,
        link: link_text.val,
      })
    }
  }

  let mut i = 0
  while i < n {
    let ch = cs[i]
    if code.val {
      if ch == '`' {
        flush()
        code.val = false
      } else {
        buf.val.write_char(ch)
      }
      i += 1
      continue
    }
    if ch == '`' {
      flush()
      code.val = true
      i += 1
      continue
    }
    if ch == '*' && i + 1 < n && cs[i + 1] == '*' {
      flush()
      bold.val = !bold.val
      i += 2
      continue
    }
    if ch == '*' {
      flush()
      italic.val = !italic.val
      i += 1
      continue
    }
    if ch == '[' {
      flush()
      link_text.val = true
      i += 1
      continue
    }
    if ch == '(' && link_text.val {
      // 链接文字结束,进入地址(地址不渲染)
      flush()
      link_text.val = false
      link_url.val = true
      i += 1
      continue
    }
    if ch == ')' && link_url.val {
      link_url.val = false
      i += 1
      continue
    }
    if link_url.val {
      // 地址字符直接跳过
      i += 1
      continue
    }
    buf.val.write_char(ch)
    i += 1
  }
  flush()
  spans
}

///|
/// 块类型(解析结果)。
priv enum MDBlock {
  Heading(String, Int) // 文本,级别 1-6
  Para(String)
  CodeBlock(Array[String], String) // 行,语言
  Quote(Array[String])             // 行
  ListItem(String, String)         // 标记(•/数字),文本
  Rule
}

///|
/// 块级解析:逐行扫描成 MDBlock 序列。
fn md_parse_blocks(source : Array[String]) -> Array[MDBlock] {
  let blocks : Array[MDBlock] = []
  let para : Array[String] = []
  let quote : Array[String] = []
  let code : Array[String] = []
  let in_code = Ref(false)
  let code_lang = Ref("")
  fn flush_para() -> Unit {
    if para.length() > 0 {
      blocks.push(Para(para.join("\n")))
      para.clear()
    }
  }

  fn flush_quote() -> Unit {
    if quote.length() > 0 {
      blocks.push(Quote(quote.copy()))
      quote.clear()
    }
  }

  for line in source {
    if in_code.val {
      let trimmed = line.trim().to_owned()
      if trimmed.has_prefix("```") {
        in_code.val = false
        blocks.push(CodeBlock(code.copy(), code_lang.val))
        code.clear()
      } else {
        code.push(line)
      }
      continue
    }
    let t = line.trim().to_owned()
    if t.has_prefix("```") {
      flush_para()
      flush_quote()
      in_code.val = true
      code_lang.val = (t[3:]).to_owned()
      continue
    }
    if t.has_prefix("#") {
      let mut level = 0
      for ch in t {
        if ch == '#' && level < 6 {
          level += 1
        } else {
          break
        }
      }
      if level > 0 && t.length() > level && t.unsafe_get(level) == ' ' {
        flush_para()
        flush_quote()
        blocks.push(Heading((t[level + 1:]).to_owned(), level))
        continue
      }
    }
    if t == "---" || t == "***" || t == "___" {
      flush_para()
      flush_quote()
      blocks.push(Rule)
      continue
    }
    if t.has_prefix("> ") || t == ">" {
      flush_para()
      let body = if t == ">" { "" } else { (t[2:]).to_owned() }
      quote.push(body)
      continue
    }
    if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("+ ") {
      flush_para()
      flush_quote()
      blocks.push(ListItem("•", (t[2:]).to_owned()))
      continue
    }
    // 有序列表:数字. 或 数字)
    let mut oi = 0
    let mut is_ordered = false
    for ch in t {
      if ch >= '0' && ch <= '9' {
        oi += 1
      } else {
        break
      }
    }
    if oi > 0 && t.length() > oi + 1 {
      let sep = t.unsafe_get(oi)
      if (sep == '.' || sep == ')') && t.unsafe_get(oi + 1) == ' ' {
        is_ordered = true
      }
    }
    if is_ordered {
      flush_para()
      flush_quote()
      blocks.push(ListItem((t[:oi + 1]).to_owned(), (t[oi + 2:]).to_owned()))
      continue
    }
    if t == "" {
      flush_para()
      flush_quote()
      continue
    }
    // 引用内续行
    if quote.length() > 0 {
      quote.push(t)
      continue
    }
    para.push(t)
  }
  // 收尾
  if in_code.val {
    blocks.push(CodeBlock(code.copy(), code_lang.val))
  }
  flush_para()
  flush_quote()
  blocks
}

///|
/// 把行内片段渲染为一个富文本 Label(范围字体/颜色,跟随主题)。
fn md_rich_label(spans : Array[MDSpan], size : Double, color : String) -> Node {
  {
    mount: fn(parent) {
      let regular = Font::new("Sans", size)
      let bold = Font::new("Sans", size, weight=Bold)
      let italic = Font::new("Sans", size, weight=Normal, style=Italic)
      let bold_italic = Font::new("Sans", size, weight=Bold, style=Italic)
      let mono = Font::new("Monospace", size - 1.0)
      fn build() -> AttributedText {
        // 区间端点按字符累计(与上游各平台码元语义对 BMP 文本一致)
        let parts : Array[String] = []
        let marks : Array[(Int, Int, MDSpan)] = []
        let pos = Ref(0)
        for span in spans {
          let start = pos.val
          for _ch in span.text {
            pos.val += 1
          }
          parts.push(span.text)
          marks.push((start, pos.val, span))
        }
        let at = AttributedText::new(parts.join(""), valign=Center)
        at.set_font(regular)
        for mark in marks {
          let (s, e, span) = mark
          if span.bold && span.italic {
            at.set_font_for(bold_italic, s, e)
          } else if span.bold {
            at.set_font_for(bold, s, e)
          } else if span.italic {
            at.set_font_for(italic, s, e)
          } else if span.code {
            at.set_font_for(mono, s, e)
          }
          if span.link || span.code {
            at.set_color_for(theme_primary(), s, e)
          }
        }
        at
      }

      let l = Label::make("")
      let at = build()
      at.set_color(color)
      l.set_attributed_text(at)
      fn apply() -> Unit {
        // 主题切换后重建(链接/代码的主题色随色板,基色随前景)
        let rebuilt = build()
        rebuilt.set_color(theme_text_regular())
        l.set_attributed_text(rebuilt)
        ViewLike::schedule_paint(l)
      }

      apply()
      on_theme_change(apply)
      bind_fg(l, fn() { theme_text_regular() })
      attach(parent, ViewLike::view(l))
      ViewLike::view(l)
    },
  }
}

///|
/// Markdown 展示视图:块级 + 行内语法渲染,代码块复用 code_view
/// (语言随 fence 标注,如 ```rust)。
pub fn markdown_view(source : String, width? : Double = 560.0) -> Node {
  let lines : Array[String] = []
  let cur = Ref(StringBuilder())
  for ch in source {
    if ch == '\n' {
      lines.push(cur.val.to_string())
      cur.val = StringBuilder()
    } else {
      cur.val.write_char(ch)
    }
  }
  lines.push(cur.val.to_string())
  let blocks = md_parse_blocks(lines)
  let nodes : Array[Node] = []
  for block in blocks {
    match block {
      Heading(text, level) => {
        let size = match level {
          1 => 22.0
          2 => 18.0
          3 => 16.0
          4 => 14.0
          5 => 13.0
          _ => 12.5
        }
        let spans = md_parse_inline(text)
        nodes.push(
          vbox(
            [md_rich_label(spans, size, "#FFFFFF")],
            style=[("marginTop", if level <= 2 { 10.0 } else { 6.0 }), ("marginBottom", 4.0)],
          ),
        )
      }
      Para(text) =>
        nodes.push(
          vbox(
            [md_rich_label(md_parse_inline(text), 13.0, "#FFFFFF")],
            style=[("marginBottom", 8.0)],
          ),
        )
      CodeBlock(code_lines, lang) =>
        nodes.push(
          vbox(
            [code_view(code_lines, lang=lang, width=width)],
            style=[("marginBottom", 10.0)],
          ),
        )
      Quote(qlines) => {
        let paras : Array[Node] = []
        for q in qlines {
          paras.push(md_rich_label(md_parse_inline(q), 13.0, "#FFFFFF"))
        }
        let bar = themed_container(style=[("width", 3.0)])
        bar.on_draw(fn(p) {
          let b = ViewLike::get_bounds(bar)
          p.set_fill_color(theme_primary())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        })
        nodes.push(
          hbox(
            [node_of(bar, style=[("height", 24.0)]), vbox(paras, style=[("marginLeft", 10.0)])],
            style=[("marginBottom", 10.0)],
          ),
        )
      }
      ListItem(marker, text) =>
        nodes.push(
          hbox(
            [
              label(marker, style=[("width", 18.0)]),
              md_rich_label(md_parse_inline(text), 13.0, "#FFFFFF"),
            ],
            style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
          ),
        )
      Rule =>
        nodes.push(separator(style=[("marginTop", 6.0), ("marginBottom", 10.0)]))
    }
  }
  vbox(nodes, style=[("width", width)])
}
