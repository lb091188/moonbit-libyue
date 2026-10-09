// L2 组件:markdown_view —— mizchi/markdown(mdast)解析 + 富文本行
// 自绘渲染。块级:标题 1-6(ATX/Setext)、围栏(```/~~~)与缩进代码块
// (复用 code_view,语言取 info 串首词)、引用(子块递归)、GFM 提示块、
// 无序/有序(带 start)/任务列表(checkbox_t 复选框)、表格(等分列宽
// 网格,单元格富文本,列对齐随源标注)、定义列表、分隔线、脚注(正文
// 上标引用 + 文末定义)、块级图片(本地路径加载显示,失败降级 alt);
// 行内:**粗体**、*斜体*、~~删除线~~(横线自绘)、`行内代码`、
// [链接](url)(点击经默认浏览器打开,悬浮手型 + 地址提示)、自动链接、
// 引用式链接(取文档级链接定义)、图片(行内降级 alt)、软换行→空格、
// 硬换行→换行。行内 HTML / HTML 块默认不渲染。
// 富文本行挂载时自绘:逐段测宽得区间像素坐标,删除线横线、链接命中与
// 悬浮、上标小字均按此换算;样式区间端点统一 UTF-16 code unit
// (md_utf16_len 换算,emoji 等非 BMP 字符后样式不错位),三平台一致
// (Windows 分段绘制,见 fork v0.15.6-mbt.9)。

///|
/// 行内片段:一段带样式的文本。url 非空表示可点击链接(经默认浏览器
/// 打开);sup 为脚注上标引用(小一号字体);strike 为删除线(渲染层
/// 按区间像素坐标自画横线)。
priv struct MDSpan {
  mut text : String
  bold : Bool
  italic : Bool
  code : Bool
  link : Bool
  strike : Bool
  sup : Bool
  url : String
}

///|
/// 行内样式集:展平时随嵌套节点叠加(显式栈携带)。
priv struct MDStyle {
  bold : Bool
  italic : Bool
  code : Bool
  link : Bool
  strike : Bool
  sup : Bool
  url : String
}

///|
/// 无样式的片段(辅助构造)。
fn md_plain_span(text : String, link? : Bool = false) -> MDSpan {
  {
    text,
    bold: false,
    italic: false,
    code: false,
    link,
    strike: false,
    sup: false,
    url: "",
  }
}

///|
/// 全默认样式集。
fn md_style_default() -> MDStyle {
  {
    bold: false,
    italic: false,
    code: false,
    link: false,
    strike: false,
    sup: false,
    url: "",
  }
}

///|
/// 脚注扫描结果:no 为 label→正文序号(1 起),order 保存编号顺序。
priv struct MDFootScan {
  no : Map[String, Int]
  order : Array[String]
  counter : Ref[Int]
}

///|
/// 渲染上下文:脚注扫描结果、文档级链接定义(label→地址)、内容基准宽
/// (图片缩放上限)。
priv struct MDCtx {
  foot : MDFootScan
  defs : Map[String, String]
  width : Double
}

///|
/// 引用式链接/图片取地址:按 label 查文档级链接定义,查不到返回空串
/// (渲染为无点击的链接样式)。
fn md_def_url(label : String, ctx : MDCtx) -> String {
  match ctx.defs.get(label.trim(chars=" \t\n\r").to_owned()) {
    Some(u) => u
    None => ""
  }
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
/// 映射:Text 逐段收样;Code 加代码样式;Strong/Emphasis 子树加粗/斜;
/// Strikethrough 子树加删除线;Link 子树加链接样式并携地址;RefLink
/// 查链接定义取地址;Autolink 渲染地址;WikiLink 渲染标签(地址非
/// http 不挂点击);图片渲染 alt 并加链接样式(块级单图段落才显示图片);
/// FootnoteReference 渲染为上标 "[n]"(编号取脚注扫描);SoftBreak 渲染
/// 为空格;HardBreak 渲染为换行;行内 HTML/行内指令不渲染。
fn md_flatten_inline(inlines : Array[@markdown.Inline], ctx : MDCtx) -> Array[MDSpan] {
  let spans : Array[MDSpan] = []
  let nodes : Array[@markdown.Inline] = []
  let styles : Array[MDStyle] = []
  fn same_style(a : MDSpan, st : MDStyle) -> Bool {
    a.bold == st.bold && a.italic == st.italic && a.code == st.code && a.link == st.link && a.strike == st.strike && a.sup == st.sup && a.url == st.url
  }

  fn emit(text : String, st : MDStyle) -> Unit {
    if text.length() == 0 {
      return
    }
    let n = spans.length()
    if n > 0 && same_style(spans[n - 1], st) {
      spans[n - 1].text = spans[n - 1].text + text
    } else {
      spans.push({
        text,
        bold: st.bold,
        italic: st.italic,
        code: st.code,
        link: st.link,
        strike: st.strike,
        sup: st.sup,
        url: st.url,
      })
    }
  }

  // 逆序压栈保持文档顺序
  fn push_all(arr : Array[@markdown.Inline], st : MDStyle) -> Unit {
    for i = arr.length() - 1; i >= 0; i = i - 1 {
      nodes.push(arr[i])
      styles.push(st)
    }
  }

  push_all(inlines, md_style_default())
  while nodes.length() > 0 {
    let node = nodes.pop().unwrap()
    let st = styles.pop().unwrap()
    match node {
      Text(content~, ..) => emit(content, st)
      Code(content~, ..) => emit(content, { ..st, code: true })
      Strong(children~, ..) => push_all(children, { ..st, bold: true })
      Emphasis(children~, ..) => push_all(children, { ..st, italic: true })
      Strikethrough(children~, ..) => push_all(children, { ..st, strike: true })
      Link(children~, url~, ..) => push_all(children, { ..st, link: true, url })
      RefLink(children~, label~, ..) =>
        push_all(children, { ..st, link: true, url: md_def_url(label, ctx) })
      Autolink(url~, ..) => emit(url, { ..st, link: true, url })
      WikiLink(label~, ..) => emit(label, { ..st, link: true })
      Image(alt~, ..) | RefImage(alt~, ..) => emit(alt, { ..st, link: true })
      FootnoteReference(label~, ..) =>
        match ctx.foot.no.get(label) {
          Some(n) => emit("[\{n}]", { ..st, sup: true })
          None => ()
        }
      SoftBreak(..) => emit(" ", st)
      HardBreak(..) => emit("\n", st)
      HtmlInline(..) | Directive(..) => ()
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
/// 普通列表项标记(任务列表走 checkbox_t,不经此)。
fn md_list_marker(base : String) -> String {
  base
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
/// 表格列对齐:mdast TableAlign → 文本对齐(None 归左)。
fn md_align_of(a : @markdown.TableAlign) -> String {
  match a {
    @markdown.Center => "center"
    @markdown.Right => "flex-end"
    _ => "flex-start"
  }
}

///|
/// 图片地址转本地路径:剥 file:// 前缀,其余原样(相对进程工作目录)。
fn md_image_path(url : String) -> String {
  if url.has_prefix("file://") {
    let sb = StringBuilder()
    let mut i = 0
    for ch in url {
      if i >= 7 {
        sb.write_char(ch)
      }
      i += 1
    }
    sb.to_string()
  } else {
    url
  }
}

///|
/// 脚注引用行内预扫描:行内树递归,遇 FootnoteReference 按出现顺序编号
/// (同一 label 只编号一次)。
fn md_scan_inline(inlines : Array[@markdown.Inline], s : MDFootScan) -> Unit {
  for node in inlines {
    match node {
      FootnoteReference(label~, ..) =>
        if s.no.get(label) is None {
          s.counter.val += 1
          s.no.set(label, s.counter.val)
          s.order.push(label)
        }
      Strong(children~, ..)
      | Emphasis(children~, ..)
      | Strikethrough(children~, ..)
      | Link(children~, ..)
      | RefLink(children~, ..) => md_scan_inline(children, s)
      Text(..)
      | SoftBreak(..)
      | HardBreak(..)
      | Code(..)
      | Directive(..)
      | WikiLink(..)
      | Autolink(..)
      | Image(..)
      | RefImage(..)
      | HtmlInline(..) => ()
    }
  }
}

///|
/// 脚注引用块级预扫描:遍历全部块(含嵌套列表/引用/表格单元格);
/// FootnoteDefinition 自身跳过(定义内的引用不参与编号)。
fn md_scan_blocks(blocks : Array[@markdown.Block], s : MDFootScan) -> Unit {
  for b in blocks {
    match b {
      Heading(children~, ..) | Paragraph(children~, ..) => md_scan_inline(children, s)
      Blockquote(children~, ..) | Alert(children~, ..) | Directive(children~, ..) =>
        md_scan_blocks(children, s)
      BulletList(items~, ..) | OrderedList(items~, ..) =>
        for it in items {
          md_scan_blocks(it.children, s)
        }
      Table(header~, rows~, ..) => {
        for c in header {
          md_scan_inline(c.children, s)
        }
        for row in rows {
          for c in row {
            md_scan_inline(c.children, s)
          }
        }
      }
      DefinitionList(items~, ..) =>
        for it in items {
          md_scan_inline(it.term, s)
          for d in it.definitions {
            md_scan_inline(d, s)
          }
        }
      Attributed(block~, ..) => md_scan_blocks([block], s)
      FencedCode(..)
      | IndentedCode(..)
      | MathBlock(..)
      | ThematicBreak(..)
      | HtmlBlock(..)
      | BlankLines(..)
      | FootnoteDefinition(..) => ()
    }
  }
}

///|
/// 列表项内容:段落直接展平(不套段落外距,行距一致),其余块递归。
fn md_item_content(children : Array[@markdown.Block], ctx : MDCtx) -> Array[Node] {
  let nodes : Array[Node] = []
  for b in children {
    match b {
      Paragraph(children=inl, ..) => nodes.push(md_rich_label(md_flatten_inline(inl, ctx), 13.0))
      _ =>
        for n in md_render_blocks([b], ctx) {
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
/// 块级图片:本地路径加载显示(等比缩放,宽度上限取 ctx.width,alt 做
/// 悬浮提示);加载失败或网络地址降级为 alt 富文本(链接样式)——富文本
/// 行不支持行内嵌图。
fn md_image(url : String, alt : String, ctx : MDCtx) -> Node {
  {
    mount: fn(parent) {
      let img = Image::new_from_file(md_image_path(url))
      if img.is_empty() {
        md_rich_label([md_plain_span(alt, link=true)], 13.0).mount_into(parent)
      } else {
        let iw = img.get_width()
        let ih = img.get_height()
        let w = if iw > 1.0 { iw.min(ctx.width) } else { 1.0 }
        let h = if iw > 1.0 { (w * ih / iw).max(1.0) } else { 1.0 }
        let c = themed_container(style=[
          ("width", w),
          ("height", h),
          ("marginBottom", 10.0),
        ])
        if alt != "" {
          ViewLike::set_tooltip(c, alt)
        }
        c.on_draw(fn(p) { p.draw_image(img, 0.0, 0.0, w, h) })
        attach(parent, ViewLike::view(c))
        ViewLike::view(c)
      }
    },
  }
}

///|
/// 表格单元格 → 展平片段(表头加粗)。
fn md_table_cell_spans(cell : @markdown.TableCell, head : Bool, ctx : MDCtx) -> Array[MDSpan] {
  if head {
    let spans : Array[MDSpan] = []
    for s in md_flatten_inline(cell.children, ctx) {
      spans.push({ ..s, bold: true })
    }
    spans
  } else {
    md_flatten_inline(cell.children, ctx)
  }
}

///|
/// 表格:等分列宽网格(格子宽按列数均分百分比,行容器撑满内容宽),
/// 表头加粗、表头下分隔线,列对齐随源标注(:--- / :---: / ---:)经
/// 格子容器 alignItems 落地;单元格为富文本(粗体/代码/链接可用)。
fn md_table(
  header : Array[@markdown.TableCell],
  alignments : Array[@markdown.TableAlign],
  rows : Array[Array[@markdown.TableCell]],
  ctx : MDCtx,
) -> Node {
  let n = header.length().max(1)
  let col_w = "\{100.0 / n.to_double()}%"
  let cells_of = fn(row : Array[@markdown.TableCell], head : Bool) -> Array[Node] {
    let cells : Array[Node] = []
    for i, cell in row {
      let al = match alignments.get(i) {
        Some(a) => md_align_of(a)
        None => "flex-start"
      }
      cells.push(
        vbox(
          [md_rich_label(md_table_cell_spans(cell, head, ctx), 13.0)],
          style=[("width", col_w), ("alignItems", al)],
        ),
      )
    }
    cells
  }
  let nodes : Array[Node] = [hbox(cells_of(header, true))]
  nodes.push(separator(style=[("marginTop", 2.0), ("marginBottom", 4.0)]))
  for row in rows {
    nodes.push(hbox(cells_of(row, false), style=[("marginBottom", 2.0)]))
  }
  vbox(nodes, style=[("marginBottom", 10.0)])
}

///|
/// 块级渲染:mdast Block 17 变体 → 节点序列。不渲染的变体:HtmlBlock、
/// BlankLines、FootnoteDefinition(定义在 markdown_view 文末统一渲染)。
fn md_render_blocks(blocks : Array[@markdown.Block], ctx : MDCtx) -> Array[Node] {
  let nodes : Array[Node] = []
  for block in blocks {
    match block {
      Heading(level~, children~, ..) =>
        nodes.push(
          vbox(
            [md_rich_label(md_flatten_inline(children, ctx), md_heading_size(level))],
            style=[
              ("marginTop", if level <= 2 { 10.0 } else { 6.0 }),
              ("marginBottom", 4.0),
            ],
          ),
        )
      Paragraph(children~, ..) => {
        // 块级图片:段落恰为一张图时显示图片(引用式图片查链接定义取地址)
        let mut img : (String, String) = ("", "")
        if children.length() == 1 {
          match children[0] {
            Image(alt~, url~, ..) => img = (url, alt)
            RefImage(alt~, label~, ..) => {
              let u = md_def_url(label, ctx)
              if u != "" {
                img = (u, alt)
              }
            }
            _ => ()
          }
        }
        if img.0 != "" {
          nodes.push(md_image(img.0, img.1, ctx))
        } else {
          nodes.push(
            vbox(
              [md_rich_label(md_flatten_inline(children, ctx), 13.0)],
              style=[("marginBottom", 8.0)],
            ),
          )
        }
      }
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
        nodes.push(md_quoted(md_render_blocks(children, ctx)))
      Alert(kind~, children~, ..) => {
        let content : Array[Node] = [label(md_alert_title(kind), style=[("marginBottom", 4.0)])]
        for n in md_render_blocks(children, ctx) {
          content.push(n)
        }
        nodes.push(md_quoted(content))
      }
      BulletList(items~, ..) =>
        for item in items {
          match item.checked {
            // GFM 任务列表:真复选框(可勾选),内容并排
            Some(ck) =>
              nodes.push(
                hbox(
                  [
                    checkbox_t("", checked=ck, style=[("width", 24.0)]),
                    vbox(md_item_content(item.children, ctx)),
                  ],
                  style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
                ),
              )
            None =>
              nodes.push(
                hbox(
                  [
                    label(md_list_marker("•"), style=[("width", 18.0)]),
                    vbox(md_item_content(item.children, ctx)),
                  ],
                  style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
                ),
              )
          }
        }
      OrderedList(start~, items~, ..) => {
        let mut no = start
        for item in items {
          nodes.push(
            hbox(
              [
                label("\{no}.", style=[("width", 18.0)]),
                vbox(md_item_content(item.children, ctx)),
              ],
              style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
            ),
          )
          no += 1
        }
      }
      Table(header~, alignments~, rows~, ..) => nodes.push(md_table(header, alignments, rows, ctx))
      DefinitionList(items~, ..) =>
        for item in items {
          nodes.push(
            vbox(
              [md_rich_label(md_flatten_inline(item.term, ctx), 13.0)],
              style=[("marginBottom", 2.0)],
            ),
          )
          for def in item.definitions {
            nodes.push(
              hbox(
                [
                  label("·", style=[("width", 18.0)]),
                  md_rich_label(md_flatten_inline(def, ctx), 13.0),
                ],
                style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
              ),
            )
          }
        }
      Directive(children~, ..) =>
        // 块级指令(:::note 等)渲染其内容
        for n in md_render_blocks(children, ctx) {
          nodes.push(n)
        }
      Attributed(block~, ..) =>
        for n in md_render_blocks([block], ctx) {
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
/// 富文本行(自绘):挂载时逐段测宽得区间像素坐标,整段拼一个
/// AttributedText 画底,删除线段补画横线;区间端点为 UTF-16 code unit
/// (md_span_ranges 计量)。带地址的链接段可点击(命中按像素区间换算,
/// 经 open_url 走默认浏览器),悬浮手型光标 + 地址矩形提示;sup 段用
/// 小一号字体;链接/代码段主题色,跟随主题切换重建。
fn md_rich_label(spans : Array[MDSpan], size : Double) -> Node {
  {
    mount: fn(parent) {
      let regular = Font::new("Sans", size)
      let bold = Font::new("Sans", size, weight=Bold)
      let italic = Font::new("Sans", size, weight=Normal, style=Italic)
      let bold_italic = Font::new("Sans", size, weight=Bold, style=Italic)
      let mono = Font::new("Monospace", size - 1.0)
      let sup_font = Font::new("Sans", (size - 4.0).max(8.0))
      fn font_of(span : MDSpan) -> Font {
        if span.sup {
          sup_font
        } else if span.code {
          mono
        } else if span.bold && span.italic {
          bold_italic
        } else if span.bold {
          bold
        } else if span.italic {
          italic
        } else {
          regular
        }
      }

      // 逐段测宽(同字体独立测量,与整体拼接排版像素宽一致量级),
      // xs/ws 为文本自身坐标系(0 起)的段起点与段宽
      let xs : Array[Double] = []
      let ws : Array[Double] = []
      let mut x = 0.0
      for span in spans {
        let probe = AttributedText::new(span.text, wrap=false)
        probe.set_font(font_of(span))
        let w = probe.get_bounds_for(10000.0, 100.0).width
        xs.push(x)
        ws.push(w)
        x += w
      }
      let row_w = if x < 1.0 { 1.0 } else { x }

      fn build() -> AttributedText {
        let parts : Array[String] = []
        for span in spans {
          parts.push(span.text)
        }
        let at = AttributedText::new(parts.join(""), valign=Center)
        at.set_font(regular)
        for mark in md_span_ranges(spans) {
          let (s, e, span) = mark
          if span.sup {
            at.set_font_for(sup_font, s, e)
          } else if span.bold && span.italic {
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

      let at = Ref(build())
      let line_h = at.val.get_one_line_height().max(1.0)
      let c = themed_container(style=[("width", row_w), ("height", line_h)])
      c.on_draw(fn(p) {
        p.draw_attributed_text(at.val, 0.0, 0.0, row_w, line_h)
        p.set_stroke_color(theme_text_regular())
        for i, span in spans {
          if span.strike {
            let y = line_h * 0.5
            p.move_to(xs[i], y)
            p.line_to(xs[i] + ws[i], y)
            p.stroke()
          }
        }
      })

      // 链接交互:命中像素区间 → 打开地址;悬浮换手型 + 地址提示
      let mut has_link = false
      for s in spans {
        if s.url != "" {
          has_link = true
        }
      }
      if has_link {
        fn hit_url(mx : Double) -> String {
          for i, s in spans {
            if s.url != "" && mx >= xs[i] && mx < xs[i] + ws[i] {
              return s.url
            }
          }
          ""
        }

        ViewLike::on_mouse_down(c, fn(e) {
          let u = hit_url(e.view_x)
          if u != "" {
            let _ = open_url(u)
            true
          } else {
            false
          }
        })
        let on_link = Ref(false)
        fn sync_cursor(mx : Double) -> Unit {
          let hit = hit_url(mx) != ""
          if hit != on_link.val {
            on_link.val = hit
            View::set_cursor(c, if hit { hand() } else { Cursor::new(Default) })
          }
        }

        ViewLike::on_mouse_move(c, fn(e) { sync_cursor(e.view_x) })
        ViewLike::on_mouse_leave(c, fn(_e) {
          if on_link.val {
            on_link.val = false
            View::set_cursor(c, Cursor::new(Default))
          }
        })
        for i, s in spans {
          if s.url != "" {
            let _ = ViewLike::add_tooltip_for_rect(
              c,
              s.url,
              { x: xs[i], y: 0.0, width: ws[i].max(1.0), height: line_h },
            )
          }
        }
      }

      fn apply() -> Unit {
        // 主题切换后重建(链接/代码的主题色随色板,基色随前景)
        at.val = build()
        ViewLike::schedule_paint(c)
      }

      ignore(on_theme_change(apply))
      apply()
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
    },
  }
}

///|
/// Markdown 展示视图:mizchi/markdown(mdast)解析 + 块级/行内渲染,
/// 代码块复用 code_view(语言取 fence info 首词,```rust、~~~py、缩进块
/// 通用);正文脚注引用按出现顺序编号,文末分隔线后逐条渲染被引用的
/// 脚注定义。
pub fn markdown_view(
  source : String,
  style? : Array[(String, &StyVal)] = [],
) -> Node {
  let res = @markdown.parse(source)
  let doc = res.document
  let foot : MDFootScan = { no: (Map([]) : Map[String, Int]), order: [], counter: Ref(0) }
  md_scan_blocks(doc.children, foot)
  let defs : Map[String, String] = (Map([]) : Map[String, String])
  for d in res.definitions {
    defs.set(d.label.trim(chars=" \t\n\r").to_owned(), d.url)
  }
  let ctx : MDCtx = { foot, defs, width: 560.0 }
  let nodes = md_render_blocks(doc.children, ctx)
  if foot.order.length() > 0 {
    let fd : Map[String, Array[@markdown.Block]] = (Map([]) : Map[String, Array[@markdown.Block]])
    for b in doc.children {
      match b {
        FootnoteDefinition(label~, children~, ..) => fd.set(label, children)
        _ => ()
      }
    }
    if fd.length() > 0 {
      nodes.push(separator(style=[("marginTop", 6.0), ("marginBottom", 8.0)]))
      for lbl in foot.order {
        match fd.get(lbl) {
          Some(children) => {
            let num = match foot.no.get(lbl) {
              Some(n) => n
              None => 0
            }
            nodes.push(
              hbox(
                [
                  label("\{num}.", style=[("width", 24.0)]),
                  vbox(md_item_content(children, ctx)),
                ],
                style=[("marginBottom", 4.0), ("marginLeft", 8.0)],
              ),
            )
          }
          None => ()
        }
      }
    }
  }
  let base : Array[(String, &StyVal)] = [("width", 560.0)]
  for kv in style {
    base.push(kv)
  }
  vbox(nodes, style=base)
}
