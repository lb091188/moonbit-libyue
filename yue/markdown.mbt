// L2 组件:markdown_view —— mizchi/markdown(mdast)解析 + AttributedText
// 范围属性渲染。块级:标题 1-6(ATX/Setext)、围栏(```/~~~)与缩进代码块
// (复用 code_view,语言取 info 串首词)、引用(子块递归)、GFM 提示块、
// 无序/有序(带 start)/任务列表(嵌套递归)、表格(行式降级)、定义列表、
// 分隔线;行内:**粗体**、*斜体*、~~删除线~~(内容保留)、`行内代码`、
// [链接](url)、自动链接、图片(渲染 alt 文本)、软换行→空格、硬换行→换行。
// 行内 HTML / HTML 块 / 脚注默认不渲染。区间字体/颜色经
// AttributedText::set_font_for/set_color_for,区间端点统一 UTF-16 code
// unit(md_utf16_len 换算,emoji 等非 BMP 字符后样式不错位),三平台一致
// (Windows 分段绘制,见 fork v0.15.6-mbt.9)。

///|
/// 行内片段:一段带样式的文本。
priv struct MDSpan {
  mut text : String
  bold : Bool
  italic : Bool
  code : Bool
  link : Bool
}

///|
/// 行内样式集:展平时随嵌套节点叠加(显式栈携带)。
priv struct MDStyle {
  bold : Bool
  italic : Bool
  code : Bool
  link : Bool
}

///|
/// 码点→UTF-16 code unit 换算:一段文本的 UTF-16 长度。BMP 内码点计 1,
/// 非 BMP(如 emoji)计 2。AttributedText 区间端点一律经此函数计量,
/// 禁止按码点数累计(两者在含非 BMP 字符时不等,错位即由此而来)。
fn md_utf16_len(text : String) -> Int {
  let mut n = 0
  for ch in text {
    n += if ch.to_int() >= 0x10000 {
      2
    } else {
      1
    }
  }
  n
}

///|
/// 行内树展平:嵌套 mdast 行内节点递归展平为扁平 spans。显式栈遍历,
/// 子节点随样式集叠加压栈;相邻同样式片段合并,减少区间数。
/// 映射:Text 逐段收样;Code 加代码样式;Link/RefLink 子树加链接样式
/// (地址不渲染);Autolink/WikiLink 渲染地址/标签并加链接样式;图片渲染
/// alt 文本并加链接样式;SoftBreak 渲染为空格;HardBreak 渲染为换行;
/// 删除线无渲染面,内容按原样式透传;行内 HTML/脚注引用/行内指令不渲染。
fn md_flatten_inline(inlines : Array[@markdown.Inline]) -> Array[MDSpan] {
  let spans : Array[MDSpan] = []
  let nodes : Array[@markdown.Inline] = []
  let styles : Array[MDStyle] = []
  fn same_style(a : MDSpan, st : MDStyle) -> Bool {
    a.bold == st.bold && a.italic == st.italic && a.code == st.code && a.link == st.link
  }

  fn emit(text : String, st : MDStyle) -> Unit {
    if text.length() == 0 {
      return
    }
    let n = spans.length()
    if n > 0 && same_style(spans[n - 1], st) {
      spans[n - 1].text = spans[n - 1].text + text
    } else {
      spans.push({ text, bold: st.bold, italic: st.italic, code: st.code, link: st.link })
    }
  }

  // 逆序压栈保持文档顺序
  fn push_all(arr : Array[@markdown.Inline], st : MDStyle) -> Unit {
    for i = arr.length() - 1; i >= 0; i = i - 1 {
      nodes.push(arr[i])
      styles.push(st)
    }
  }

  push_all(inlines, { bold: false, italic: false, code: false, link: false })
  while nodes.length() > 0 {
    let node = nodes.pop().unwrap()
    let st = styles.pop().unwrap()
    match node {
      Text(content~, ..) => emit(content, st)
      Code(content~, ..) => emit(content, { ..st, code: true })
      Strong(children~, ..) => push_all(children, { ..st, bold: true })
      Emphasis(children~, ..) => push_all(children, { ..st, italic: true })
      Strikethrough(children~, ..) => push_all(children, st)
      Link(children~, ..) | RefLink(children~, ..) => push_all(children, { ..st, link: true })
      Autolink(url~, ..) => emit(url, { ..st, link: true })
      WikiLink(label~, ..) => emit(label, { ..st, link: true })
      Image(alt~, ..) | RefImage(alt~, ..) => emit(alt, { ..st, link: true })
      SoftBreak(..) => emit(" ", st)
      HardBreak(..) => emit("\n", st)
      HtmlInline(..) | FootnoteReference(..) | Directive(..) => ()
    }
  }
  spans
}

///|
/// 展平片段 → 富文本区间表:[start, end) 为 UTF-16 code unit 端点
/// (AttributedText 区间语义),渲染与测试共用同一计量。
fn md_span_ranges(spans : Array[MDSpan]) -> Array[(Int, Int, MDSpan)] {
  let marks : Array[(Int, Int, MDSpan)] = []
  let pos = Ref(0)
  for span in spans {
    let start = pos.val
    pos.val += md_utf16_len(span.text)
    marks.push((start, pos.val, span))
  }
  marks
}

///|
/// 围栏 info 串提取语言:取空白分隔的首词("rust title=x" → "rust")。
fn md_info_lang(info : String) -> String {
  let t = info.trim(chars=" \t\n\r").to_owned()
  let sb = StringBuilder()
  for ch in t {
    if ch == ' ' || ch == '\t' {
      break
    }
    sb.write_char(ch)
  }
  sb.to_string()
}

///|
/// 整块代码文本按 \n 切行(顺去 \r 与末尾空行),供 code_view 使用。
fn md_split_code_lines(code : String) -> Array[String] {
  let lines : Array[String] = []
  let cur = Ref(StringBuilder())
  for ch in code {
    if ch == '\n' {
      lines.push(cur.val.to_string())
      cur.val = StringBuilder()
    } else if ch != '\r' {
      cur.val.write_char(ch)
    }
  }
  let tail = cur.val.to_string()
  if tail.length() > 0 || lines.length() == 0 {
    lines.push(tail)
  }
  lines
}

///|
/// 标题字号(级别 1-6)。
fn md_heading_size(level : Int) -> Double {
  match level {
    1 => 22.0
    2 => 18.0
    3 => 16.0
    4 => 14.0
    5 => 13.0
    _ => 12.5
  }
}

///|
/// 列表项标记:任务列表(GFM)按勾选态给 ☑/☐,普通项给基础标记。
fn md_list_marker(base : String, checked : Bool?) -> String {
  match checked {
    Some(true) => "☑"
    Some(false) => "☐"
    None => base
  }
}

///|
/// GFM 提示块标题文字。
fn md_alert_title(kind : @markdown.AlertKind) -> String {
  match kind {
    Note => "NOTE"
    Tip => "TIP"
    Important => "IMPORTANT"
    Warning => "WARNING"
    Caution => "CAUTION"
  }
}

///|
/// 列表项内容:段落直接展平(不套段落外距,行距与旧版一致),其余块递归。
fn md_item_content(children : Array[@markdown.Block]) -> Array[Node] {
  let nodes : Array[Node] = []
  for b in children {
    match b {
      Paragraph(children=inl, ..) => nodes.push(md_rich_label(md_flatten_inline(inl), 13.0))
      _ =>
        for n in md_render_blocks([b]) {
          nodes.push(n)
        }
    }
  }
  nodes
}

///|
/// 引用/提示块:主题色竖条 + 缩进内容。
fn md_quoted(content : Array[Node]) -> Node {
  let bar = themed_container(style=[("width", 3.0)])
  bar.on_draw(fn(p) {
    let b = ViewLike::get_bounds(bar)
    p.set_fill_color(theme_primary())
    p.fill_rect(0.0, 0.0, b.width, b.height)
  })
  hbox(
    [node_of(bar, style=[("height", 24.0)]), vbox(content, style=[("marginLeft", 10.0)])],
    style=[("marginBottom", 10.0)],
  )
}

///|
/// 表格行 → 单行富文本(单元格以两空格分隔,表头加粗)。表格降级为
/// 行式渲染,不做网格对齐。
fn md_table_row(cells : Array[@markdown.TableCell], head : Bool) -> Node {
  let spans : Array[MDSpan] = []
  for i, cell in cells {
    if i > 0 {
      spans.push({ text: "  ", bold: false, italic: false, code: false, link: false })
    }
    for s in md_flatten_inline(cell.children) {
      spans.push(if head { { ..s, bold: true } } else { s })
    }
  }
  vbox([md_rich_label(spans, 13.0)], style=[("marginBottom", 4.0)])
}

///|
/// 块级渲染:mdast Block 17 变体 → 节点序列。不渲染的变体:HtmlBlock、
/// FootnoteDefinition(行内脚注引用同样不渲染)、BlankLines。
fn md_render_blocks(blocks : Array[@markdown.Block]) -> Array[Node] {
  let nodes : Array[Node] = []
  for block in blocks {
    match block {
      Heading(level~, children~, ..) =>
        nodes.push(
          vbox(
            [md_rich_label(md_flatten_inline(children), md_heading_size(level))],
            style=[
              ("marginTop", if level <= 2 { 10.0 } else { 6.0 }),
              ("marginBottom", 4.0),
            ],
          ),
        )
      Paragraph(children~, ..) =>
        nodes.push(
          vbox(
            [md_rich_label(md_flatten_inline(children), 13.0)],
            style=[("marginBottom", 8.0)],
          ),
        )
      FencedCode(info~, code~, ..) =>
        nodes.push(
          vbox(
            [code_view(md_split_code_lines(code), lang=md_info_lang(info))],
            style=[("marginBottom", 10.0)],
          ),
        )
      IndentedCode(code~, ..) =>
        nodes.push(
          vbox([code_view(md_split_code_lines(code))], style=[("marginBottom", 10.0)]),
        )
      MathBlock(value~, ..) =>
        nodes.push(
          vbox(
            [code_view(md_split_code_lines(value), lang="math")],
            style=[("marginBottom", 10.0)],
          ),
        )
      Blockquote(children~, ..) =>
        // 引用收块:子块(段落/列表/嵌套引用)整体递归进竖条内容区
        nodes.push(md_quoted(md_render_blocks(children)))
      Alert(kind~, children~, ..) => {
        let content : Array[Node] = [label(md_alert_title(kind), style=[("marginBottom", 4.0)])]
        for n in md_render_blocks(children) {
          content.push(n)
        }
        nodes.push(md_quoted(content))
      }
      BulletList(items~, ..) =>
        for item in items {
          nodes.push(
            hbox(
              [
                label(md_list_marker("•", item.checked), style=[("width", 18.0)]),
                vbox(md_item_content(item.children)),
              ],
              style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
            ),
          )
        }
      OrderedList(start~, items~, ..) => {
        let mut no = start
        for item in items {
          nodes.push(
            hbox(
              [
                label("\{no}.", style=[("width", 18.0)]),
                vbox(md_item_content(item.children)),
              ],
              style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
            ),
          )
          no += 1
        }
      }
      Table(header~, rows~, ..) => {
        let rows_nodes : Array[Node] = [md_table_row(header, true)]
        rows_nodes.push(
          separator(style=[("marginTop", 2.0), ("marginBottom", 4.0)]),
        )
        for row in rows {
          rows_nodes.push(md_table_row(row, false))
        }
        nodes.push(vbox(rows_nodes, style=[("marginBottom", 10.0)]))
      }
      DefinitionList(items~, ..) =>
        for item in items {
          nodes.push(
            vbox(
              [md_rich_label(md_flatten_inline(item.term), 13.0)],
              style=[("marginBottom", 2.0)],
            ),
          )
          for def in item.definitions {
            nodes.push(
              hbox(
                [label("·", style=[("width", 18.0)]), md_rich_label(md_flatten_inline(def), 13.0)],
                style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
              ),
            )
          }
        }
      Directive(children~, ..) =>
        // 块级指令(:::note 等)渲染其内容
        for n in md_render_blocks(children) {
          nodes.push(n)
        }
      Attributed(block~, ..) =>
        for n in md_render_blocks([block]) {
          nodes.push(n)
        }
      ThematicBreak(..) =>
        nodes.push(
          separator(style=[("marginTop", 6.0), ("marginBottom", 10.0)]),
        )
      HtmlBlock(..) | BlankLines(..) | FootnoteDefinition(..) => ()
    }
  }
  nodes
}

///|
/// 把行内片段渲染为一个富文本 Label(范围字体/颜色,跟随主题前景与
/// 主色)。区间端点为 UTF-16 code unit(md_span_ranges 计量)。
fn md_rich_label(spans : Array[MDSpan], size : Double) -> Node {
  {
    mount: fn(parent) {
      let regular = Font::new("Sans", size)
      let bold = Font::new("Sans", size, weight=Bold)
      let italic = Font::new("Sans", size, weight=Normal, style=Italic)
      let bold_italic = Font::new("Sans", size, weight=Bold, style=Italic)
      let mono = Font::new("Monospace", size - 1.0)
      fn build() -> AttributedText {
        let parts : Array[String] = []
        for span in spans {
          parts.push(span.text)
        }
        let at = AttributedText::new(parts.join(""), valign=Center)
        at.set_font(regular)
        for mark in md_span_ranges(spans) {
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
      fn apply() -> Unit {
        // 主题切换后重建(链接/代码的主题色随色板,基色随前景)
        let rebuilt = build()
        rebuilt.set_color(theme_text_regular())
        l.set_attributed_text(rebuilt)
        ViewLike::schedule_paint(l)
      }

      on_theme_change(apply)
      apply()
      bind_fg(l, fn() { theme_text_regular() })
      attach(parent, ViewLike::view(l))
      ViewLike::view(l)
    },
  }
}

///|
/// Markdown 展示视图:mizchi/markdown(mdast)解析 + 块级/行内渲染,
/// 代码块复用 code_view(语言取 fence info 首词,```rust、~~~py、缩进块通用)。
pub fn markdown_view(
  source : String,
  style? : Array[(String, &StyVal)] = [],
) -> Node {
  let doc = @markdown.parse(source).document
  let nodes = md_render_blocks(doc.children)
  let base : Array[(String, &StyVal)] = [("width", 560.0)]
  for kv in style {
    base.push(kv)
  }
  vbox(nodes, style=base)
}
