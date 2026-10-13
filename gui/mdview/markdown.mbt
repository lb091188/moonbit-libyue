// Markdown 展示视图（新栈）：mizchi/markdown(mdast) 解析 + 富文本行自绘
// 渲染，与 master 的 yue/markdown 同源平移，渲染层换新栈组件面。
// 块级:标题 1-6(ATX/Setext)、围栏(```/~~~)与缩进代码块(复用
// @ui.code_view,语言取 info 串首词)、引用(子块递归)、GFM 提示块、
// 无序/有序(带 start)/任务列表(checkbox 复选框)、表格(等分列宽
// 网格,单元格富文本,列对齐随源标注)、定义列表、分隔线、脚注(正文
// 上标引用 + 文末定义)、块级图片(本地路径加载显示,失败降级 alt);
// 行内:**粗体**、*斜体*、~~删除线~~(横线自绘)、`行内代码`、
// [链接](url)(点击经 on_link 回调交调用方处理——open_url 属系统能力
// 线,接入后由调用方转接)、自动链接、引用式链接、图片(行内降级
// alt)、软换行→空格、硬换行→换行。行内 HTML / HTML 块默认不渲染。
// 富文本行自绘:逐段测宽得区间像素坐标,删除线横线、链接命中与悬浮
// 手型均按此换算;样式区间端点统一 UTF-16 code unit(md_utf16_len
// 换算,emoji 等非 BMP 字符后样式不错位)。

///|
/// 行内片段:一段带样式的文本。url 非空表示可点击链接(经 on_link
/// 回调交给调用方);sup 为脚注上标引用(小一号字体);strike 为删除线
/// (渲染层按区间像素坐标自画横线)。
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
/// (图片缩放上限)、链接点击回调(open_url 属系统能力线,由调用方接入)。
priv struct MDCtx {
  foot : MDFootScan
  defs : Map[String, String]
  width : Double
  on_link : (String) -> Unit
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
fn md_flatten_inline(inlines : Array[@mdast.Inline], ctx : MDCtx) -> Array[MDSpan] {
  let spans : Array[MDSpan] = []
  let nodes : Array[@mdast.Inline] = []
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
  fn push_all(arr : Array[@mdast.Inline], st : MDStyle) -> Unit {
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
/// 普通列表项标记(任务列表走 checkbox,不经此)。
fn md_list_marker(base : String) -> String {
  base
}

///|
/// GFM 提示块标题文字。
fn md_alert_title(kind : @mdast.AlertKind) -> String {
  match kind {
    Note => "NOTE"
    Tip => "TIP"
    Important => "IMPORTANT"
    Warning => "WARNING"
    Caution => "CAUTION"
  }
}

///|
/// 表格列对齐:mdast TableAlign → 容器对齐(None 归左)。
fn md_align_of(a : @mdast.TableAlign) -> @yoga.AlignItems {
  match a {
    @mdast.Center => @yoga.AlignItems::Center
    @mdast.Right => @yoga.AlignItems::FlexEnd
    _ => @yoga.AlignItems::FlexStart
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
fn md_scan_inline(inlines : Array[@mdast.Inline], s : MDFootScan) -> Unit {
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
fn md_scan_blocks(blocks : Array[@mdast.Block], s : MDFootScan) -> Unit {
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
fn md_item_content(children : Array[@mdast.Block], ctx : MDCtx) -> Array[@core.Node] {
  let nodes : Array[@core.Node] = []
  for b in children {
    match b {
      Paragraph(children=inl, ..) => nodes.push(md_rich_label(md_flatten_inline(inl, ctx), 13.0, ctx))
      _ =>
        for n in md_render_blocks([b], ctx) {
          nodes.push(n)
        }
    }
  }
  nodes
}

///|
/// 定宽标记列(列表圆点/序号/定义点)。
fn md_marker(text : String, w : Double) -> @core.Node {
  @core.node_of_new(fn(mk : @core.Widget) -> @core.Widget {
    mk.node.set_width(@yoga.fixed(w))
    // 行盒高度必须注册测量：这个格子只有绘制、没有子件，不注册就是**零高度**，
    // 而 hbox 默认 align_items=Center——0 高的格子被摆到行的中点，序号整个
    // 掉到文字基线上（实测 rect=(0,111,18,0) 而正文在 102..120，数字中心正好
    // 压在基线上）。测一次自己的文本，拿到与正文同源的行盒高。
    mk.node.set_measure(fn(_aw : Double?, _ah : Double?) -> (Double, Double) {
      match @text.measure(text, 13.0) {
        Some(m) => (m.width.to_double(), m.height.to_double())
        None => (w, 18.0)
      }
    })
    mk.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let _ = @text.draw_box_at(
        p,
        0.0,
        0.0,
        r.w,
        r.h,
        text,
        @text.Font::new("", 13.0),
        @theme.theme_text_regular(),
        align=@text.Start,
        // 贴**首行**顶对齐（不是整盒居中）：列表项盒子常有一行多高，居中会把
        // 序号摆到中间——数字的中心正好压在首行基线上，看着像掉到基线下面
        valign=@text.Start,
        wrap=false,
      )
    })
    mk
  })
}

///|
/// 引用/提示块:主题色竖条 + 缩进内容。
fn md_quoted(content : Array[@core.Node]) -> @core.Node {
  let bar = @core.node_of_new(fn(b : @core.Widget) -> @core.Widget {
    b.node.set_width(@yoga.fixed(3.0))
    b.node.set_min_height(@yoga.fixed(24.0))
    b.node.set_align_self(Some(@yoga.AlignItems::Stretch))
    b.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_primary())
      p.fill_rect(0.0, 0.0, r.w, r.h)
    })
    b
  })
  @ui.row([bar, @ui.col(content)], column_gap=10.0)
}

///|
/// 块级图片:本地路径加载显示(等比缩放,宽度上限取 ctx.width);加载
/// 失败或网络地址降级为 alt 富文本(链接样式)——富文本行不支持行内
/// 嵌图。
fn md_image(url : String, alt : String, ctx : MDCtx) -> @core.Node {
  let img = @render.Image::new_from_file(md_image_path(url))
  if img.is_empty() {
    md_rich_label([md_plain_span(alt, link=true)], 13.0, ctx)
  } else {
    let iw = img.get_width()
    let ih = img.get_height()
    let w = if iw > 1.0 { iw.min(ctx.width) } else { 1.0 }
    let h = if iw > 1.0 { (w * ih / iw).max(1.0) } else { 1.0 }
    @core.node_of_new(fn(c : @core.Widget) -> @core.Widget {
      c.node.set_width(@yoga.fixed(w))
      c.node.set_height(@yoga.fixed(h))
      c.node.set_margin_bottom(@yoga.fixed(10.0))
      c.on_draw = Some(fn(
        _self : @core.Widget,
        p : @render.Painter,
        _r : @core.Rect,
      ) -> Unit {
        let _ = p.draw_image(img, 0.0, 0.0, w, h)
      })
      c
    })
  }
}

///|
/// 表格单元格 → 展平片段(表头加粗)。
fn md_table_cell_spans(cell : @mdast.TableCell, head : Bool, ctx : MDCtx) -> Array[MDSpan] {
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
/// 表格:等分列宽网格(格子宽按列数均分百分比),表头加粗、表头下
/// 分隔线,列对齐随源标注(:--- / :---: / ---:)经格子容器 align_items
/// 落地;单元格为富文本(粗体/代码/链接可用)。
fn md_table(
  header : Array[@mdast.TableCell],
  alignments : Array[@mdast.TableAlign],
  rows : Array[Array[@mdast.TableCell]],
  ctx : MDCtx,
) -> @core.Node {
  let n = header.length().max(1)
  let cells_of = fn(row : Array[@mdast.TableCell], head : Bool) -> Array[@core.Node] {
    let cells : Array[@core.Node] = []
    for i, cell in row {
      let al = match alignments.get(i) {
        Some(a) => md_align_of(a)
        None => @yoga.AlignItems::FlexStart
      }
      cells.push(
        @ui.view(
          [md_rich_label(md_table_cell_spans(cell, head, ctx), 13.0, ctx)],
          align_items=al,
          handle=fn(cw : @core.Widget) -> Unit {
            cw.node.set_width(@yoga.percent(100.0 / n.to_double()))
          },
        ),
      )
    }
    cells
  }
  let nodes : Array[@core.Node] = [@ui.row(cells_of(header, true))]
  nodes.push(@ui.divider())
  for row in rows {
    nodes.push(@ui.row(cells_of(row, false)))
  }
  @ui.col(nodes)
}

///|
/// 块级渲染:mdast Block 17 变体 → 节点序列。不渲染的变体:HtmlBlock、
/// BlankLines、FootnoteDefinition(定义在 markdown_view 文末统一渲染)。
fn md_render_blocks(blocks : Array[@mdast.Block], ctx : MDCtx) -> Array[@core.Node] {
  let nodes : Array[@core.Node] = []
  for block in blocks {
    match block {
      Heading(level~, children~, ..) =>
        nodes.push(
          @ui.col([
          md_rich_label(
            md_flatten_inline(children, ctx),
            md_heading_size(level),
            ctx,
          ),
        ]),
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
          @ui.col([md_rich_label(md_flatten_inline(children, ctx), 13.0, ctx)]),
        )
        }
      }
      FencedCode(info~, code~, ..) =>
        nodes.push(
          @ui.code_view(md_split_code_lines(code), lang=md_info_lang(info)),
        )
      IndentedCode(code~, ..) =>
        nodes.push(@ui.code_view(md_split_code_lines(code)))
      MathBlock(value~, ..) =>
        nodes.push(@ui.code_view(md_split_code_lines(value), lang="math"))
      Blockquote(children~, ..) =>
        // 引用收块:子块(段落/列表/嵌套引用)整体递归进竖条内容区
        nodes.push(md_quoted(md_render_blocks(children, ctx)))
      Alert(kind~, children~, ..) => {
        let content : Array[@core.Node] = [
          @ui.text(md_alert_title(kind), weight=@text.SemiBold),
        ]
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
                @ui.row([
                  @ui.checkbox("", @core.Store::new(ck)),
                  @ui.col(md_item_content(item.children, ctx)),
                ]),
              )
            None =>
              nodes.push(
                @ui.row([
                  md_marker(md_list_marker("•"), 18.0),
                  @ui.col(md_item_content(item.children, ctx)),
                ]),
              )
          }
        }
      OrderedList(start~, items~, ..) => {
        let mut no = start
        for item in items {
          nodes.push(
            @ui.row([
              md_marker("\{no}.", 18.0),
              @ui.col(md_item_content(item.children, ctx)),
            ]),
          )
          no += 1
        }
      }
      Table(header~, alignments~, rows~, ..) => nodes.push(md_table(header, alignments, rows, ctx))
      DefinitionList(items~, ..) =>
        for item in items {
          nodes.push(
            @ui.col([md_rich_label(md_flatten_inline(item.term, ctx), 13.0, ctx)]),
          )
          for def in item.definitions {
            nodes.push(
              @ui.row([
                md_marker("·", 18.0),
                md_rich_label(md_flatten_inline(def, ctx), 13.0, ctx),
              ]),
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
      ThematicBreak(..) => nodes.push(@ui.divider())
      HtmlBlock(..) | BlankLines(..) | FootnoteDefinition(..) => ()
    }
  }
  nodes
}

///|
/// 富文本行(自绘):构造期逐段测宽得区间像素坐标,整段拼一个
/// AttributedText 画底,删除线段补画横线;区间端点为 UTF-16 code unit
/// (md_span_ranges 计量)。带地址的链接段可点击(命中按像素区间换算,
/// 经 ctx.on_link 回调交调用方),悬浮手型光标;sup 段用小一号字体;
/// 链接/代码段主题色,主题指纹变化时重建(避免每帧重建)。
fn md_rich_label(
  spans : Array[MDSpan],
  size : Double,
  ctx : MDCtx,
) -> @core.Node {
  let regular = @text.Font::new("", size)
  let bold = @text.Font::new("", size, weight=@text.Bold)
  let italic = @text.Font::new("", size, style=@text.Italic)
  let bold_italic = @text.Font::new("", size, weight=@text.Bold, style=@text.Italic)
  let mono = @text.Font::new("Monospace", size - 1.0)
  let sup_font = @text.Font::new("", (size - 4.0).max(8.0))
  fn font_of(span : MDSpan) -> @text.Font {
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
    let probe = @text.AttributedText::new(span.text, wrap=false)
    probe.set_font(font_of(span))
    let w = probe.get_bounds_for(10000.0, 100.0).width
    xs.push(x)
    ws.push(w)
    x += w
  }
  let row_w = if x < 1.0 { 1.0 } else { x }

  fn build() -> @text.AttributedText {
    let parts : Array[String] = []
    for span in spans {
      parts.push(span.text)
    }
    let at = @text.AttributedText::new(parts.join(""), valign=@text.Center, wrap=false)
    at.set_font(regular)
    at.set_color(@theme.theme_text_regular())
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
        at.set_color_for(@theme.theme_primary(), s, e)
      }
    }
    at
  }

  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    @ui.watch_theme()
    // 主题指纹缓存:指纹变了才重建 AttributedText(链接/代码色随主题)
    let at = Ref(build())
    let fp = Ref("")
    let line_h = match at.val.line_height() {
      Some(h) => h.to_double().max(1.0)
      None => size * 1.5
    }
    w.node.set_width(@yoga.fixed(row_w))
    w.node.set_height(@yoga.fixed(line_h))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let cur = @theme.theme_fingerprint_of(@theme.theme_current())
      if cur != fp.val {
        fp.val = cur
        at.val = build()
      }
      let _ = at.val.draw_at(p, 0.0, 0.0, row_w, line_h)
      p.set_stroke_color(@theme.theme_text_regular())
      for i, span in spans {
        if span.strike {
          let y = line_h * 0.5
          p.begin_path()
          p.move_to(xs[i], y)
          p.line_to(xs[i] + ws[i], y)
          p.stroke()
        }
      }
    })
    // 链接交互:命中像素区间 → on_link 回调;悬浮换手型
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
      let hover = Ref(false)
      w.on_pointer = Some(fn(
        _self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Down => {
            let u = hit_url(ev.x)
            if u != "" {
              (ctx.on_link)(u)
              true
            } else {
              false
            }
          }
          @core.Move => {
            let hit = hit_url(ev.x) != ""
            if hit != hover.val {
              hover.val = hit
              w.cursor = if hit { @core.CURSOR_HAND } else { 0 }
            }
            true
          }
          @core.Leave => {
            if hover.val {
              hover.val = false
              w.cursor = 0
            }
            false
          }
          @core.Up => false
        }
      })
    }
    w
  })
}

///|
/// Markdown 展示视图:mizchi/markdown(mdast)解析 + 块级/行内渲染,
/// 代码块复用 @ui.code_view(语言取 fence info 首词,```rust、~~~py、
/// 缩进块通用);正文脚注引用按出现顺序编号,文末分隔线后逐条渲染被
/// 引用的脚注定义;链接点击经 on_link 回调交调用方(open_url 属系统
/// 能力线,接入后由调用方转接默认浏览器)。
pub fn markdown_view(
  source : String,
  width? : Double = 560.0,
  on_link? : (String) -> Unit = fn(_u : String) -> Unit { () },
  handle? : (@core.Widget) -> Unit = @ui.default_handle,
) -> @core.Node {
  let res = @mdast.parse(source)
  let doc = res.document
  let foot : MDFootScan = { no: (Map([]) : Map[String, Int]), order: [], counter: Ref(0) }
  md_scan_blocks(doc.children, foot)
  let defs : Map[String, String] = (Map([]) : Map[String, String])
  for d in res.definitions {
    defs.set(d.label.trim(chars=" \t\n\r").to_owned(), d.url)
  }
  let ctx : MDCtx = { foot, defs, width, on_link }
  let nodes = md_render_blocks(doc.children, ctx)
  if foot.order.length() > 0 {
    let fd : Map[String, Array[@mdast.Block]] = (Map([]) : Map[String, Array[@mdast.Block]])
    for b in doc.children {
      match b {
        FootnoteDefinition(label~, children~, ..) => fd.set(label, children)
        _ => ()
      }
    }
    if fd.length() > 0 {
      nodes.push(@ui.divider())
      for lbl in foot.order {
        match fd.get(lbl) {
          Some(children) => {
            let num = match foot.no.get(lbl) {
              Some(n) => n
              None => 0
            }
            nodes.push(
              @ui.row([
                md_marker("\{num}.", 24.0),
                @ui.col(md_item_content(children, ctx)),
              ]),
            )
          }
          None => ()
        }
      }
    }
  }
  @ui.col(nodes, width=width, handle~)
}
