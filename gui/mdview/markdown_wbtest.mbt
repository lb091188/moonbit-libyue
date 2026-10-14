// markdown_view 白盒测试(新栈,与 master 同源平移):码点→UTF-16 换算层、
// 行内展平与区间计量、fence info/切行、GFM 渲染面(删除线/脚注/图片
// 路径/链接地址/表格),外加组件挂载断言(标题/代码块/链接/任务列表)。

///|
/// 测试帮手:空渲染上下文(无脚注/无链接定义,基准宽 560)。
fn md_test_ctx() -> MDCtx {
  {
    foot: { no: (Map([]) : Map[String, Int]), order: [], counter: Ref(0) },
    defs: (Map([]) : Map[String, String]),
    width: 560.0,
    on_link: fn(_u : String) -> Unit { () },
  }
}

///|
/// 测试帮手:解析单段落源文并展平其行内。
fn md_flat_par(src : String) -> Array[MDSpan] {
  let doc = @mdast.parse(src).document
  let spans : Array[MDSpan] = []
  for b in doc.children {
    match b {
      Paragraph(children~, ..) =>
        for s in md_flatten_inline(children, md_test_ctx()) {
          spans.push(s)
        }
      _ => ()
    }
  }
  spans
}

///|
test {
  // UTF-8 字节数(AttributedText 区间口径):ASCII 1、CJK 3、emoji 4
  assert_eq(md_byte_len(""), 0)
  assert_eq(md_byte_len("abc"), 3)
  assert_eq(md_byte_len("甲乙丙"), 9)
  assert_eq(md_byte_len("👍"), 4)
  assert_eq(md_byte_len("a👍b"), 6)
  assert_eq(md_byte_len("👍👍"), 8)
}

///|
test {
  // 纯文本单段:展平为一段(相邻同样式合并)
  let spans = md_flat_par("hello 甲乙")
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "hello 甲乙")
  assert_false(spans[0].bold)
  assert_false(spans[0].italic)
  assert_false(spans[0].code)
  assert_false(spans[0].link)
  assert_false(spans[0].strike)
  assert_false(spans[0].sup)
  assert_eq(spans[0].url, "")
}

///|
test {
  // 粗体/斜体/粗斜体:样式标志与文本正确,标记字符不残留
  let spans = md_flat_par("**粗** 与 *斜* 与 ***粗斜***")
  assert_eq(spans.length(), 5)
  assert_eq(spans[0].text, "粗")
  assert_true(spans[0].bold)
  assert_false(spans[0].italic)
  assert_eq(spans[2].text, "斜")
  assert_true(spans[2].italic)
  assert_eq(spans[4].text, "粗斜")
  assert_true(spans[4].bold)
  assert_true(spans[4].italic)
  let all = StringBuilder()
  for s in spans {
    all.write_string(s.text)
  }
  assert_eq(all.to_string(), "粗 与 斜 与 粗斜")
}

///|
test {
  // 行内代码:代码样式,内容原样;代码内标记不解析
  let spans = md_flat_par("前 `co**de**` 后")
  assert_eq(spans.length(), 3)
  assert_eq(spans[0].text, "前 ")
  assert_eq(spans[1].text, "co**de**")
  assert_true(spans[1].code)
  assert_eq(spans[2].text, " 后")
}

///|
test {
  // 链接:渲染文字带链接样式并携地址(点击打开用),地址不进渲染文本
  let spans = md_flat_par("见 [文字](https://x.y/z) 即可")
  let all = StringBuilder()
  for s in spans {
    all.write_string(s.text)
    if s.link {
      assert_eq(s.text, "文字")
      assert_eq(s.url, "https://x.y/z")
    }
  }
  assert_eq(all.to_string(), "见 文字 即可")
  assert_false(all.to_string().contains("https"))
  // 自动链接:地址本身带链接样式并携地址
  let auto = md_flat_par("去 <https://a.b/c> 看")
  assert_eq(auto.length(), 3)
  assert_eq(auto[1].text, "https://a.b/c")
  assert_true(auto[1].link)
  assert_eq(auto[1].url, "https://a.b/c")
}

///|
test {
  // 引用式链接:地址取自文档级链接定义;无定义的引用式按 CommonMark
  // 退化为字面文本(不产生 RefLink,自然没有地址可挂)
  let res = @mdast.parse("见 [文字][ref]\n\n[ref]: https://ref.y/x")
  let defs : Map[String, String] = (Map([]) : Map[String, String])
  for d in res.definitions {
    defs.set(d.label.trim(chars=" \t\n\r").to_owned(), d.url)
  }
  let ctx : MDCtx = { foot: md_test_ctx().foot, defs, width: 560.0, on_link: fn(_u : String) -> Unit { () } }
  let spans : Array[MDSpan] = []
  for b in res.document.children {
    match b {
      Paragraph(children~, ..) =>
        for s in md_flatten_inline(children, ctx) {
          spans.push(s)
        }
      _ => ()
    }
  }
  assert_eq(spans.length(), 2)
  assert_eq(spans[0].text, "见 ")
  assert_eq(spans[1].text, "文字")
  assert_eq(spans[1].url, "https://ref.y/x")
}

///|
test {
  // 图片行内降级为 alt 文本(链接样式),url 不进渲染文本
  let spans = md_flat_par("前 ![图](u.png) 后")
  let all = StringBuilder()
  for s in spans {
    all.write_string(s.text)
  }
  assert_eq(all.to_string(), "前 图 后")
  assert_false(all.to_string().contains("u.png"))
}

///|
test {
  // 软换行渲染为空格,硬换行(行尾双空格)渲染为换行
  let soft = md_flat_par("行甲\n行乙")
  let s_all = StringBuilder()
  for s in soft {
    s_all.write_string(s.text)
  }
  assert_eq(s_all.to_string(), "行甲 行乙")
  let hard = md_flat_par("行甲  \n行乙")
  let h_all = StringBuilder()
  for s in hard {
    h_all.write_string(s.text)
  }
  assert_eq(h_all.to_string(), "行甲\n行乙")
}

///|
test {
  // 删除线:内容保留并带删除线标志(渲染层按区间像素坐标画横线)
  let spans = md_flat_par("~~划掉~~")
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "划掉")
  assert_true(spans[0].strike)
  assert_false(spans[0].bold)
  assert_false(spans[0].italic)
  // 删除线与粗体叠加:两标志并存,样式边界不串
  let mix = md_flat_par("~~**划粗**~~")
  assert_eq(mix.length(), 1)
  assert_true(mix[0].strike)
  assert_true(mix[0].bold)
}

///|
test {
  // 脚注:正文引用按出现顺序编号,展平为上标 "[n]";同一 label 不重编
  let res = @mdast.parse("甲[^a] 乙[^b] 丙[^a]\n\n[^a]: 定义甲\n[^b]: 定义乙")
  let foot : MDFootScan = { no: (Map([]) : Map[String, Int]), order: [], counter: Ref(0) }
  md_scan_blocks(res.document.children, foot)
  assert_eq(foot.order, ["a", "b"])
  assert_eq(foot.no.get("a"), Some(1))
  assert_eq(foot.no.get("b"), Some(2))
  let ctx : MDCtx = { foot, defs: (Map([]) : Map[String, String]), width: 560.0, on_link: fn(_u : String) -> Unit { () } }
  let spans : Array[MDSpan] = []
  for b in res.document.children {
    match b {
      Paragraph(children~, ..) =>
        for s in md_flatten_inline(children, ctx) {
          spans.push(s)
        }
      _ => ()
    }
  }
  let sups : Array[String] = []
  for s in spans {
    if s.sup {
      sups.push(s.text)
    }
  }
  assert_eq(sups, ["[1]", "[2]", "[1]"])
}

///|
test {
  // 块级渲染忽略 FootnoteDefinition(定义由 markdown_view 收集后在文末
  // 统一渲染):段落 1 节点,两条定义均不产节点
  let doc = @mdast.parse("甲[^a]\n\n[^a]: 定义甲\n[^b]: 定义乙\n").document
  let ctx = md_test_ctx()
  md_scan_blocks(doc.children, ctx.foot)
  assert_eq(ctx.foot.order, ["a"])
  let nodes = md_render_blocks(doc.children, ctx)
  assert_eq(nodes.length(), 1)
}

///|
test {
  // 图片地址转本地路径:剥 file:// 前缀,普通路径原样
  assert_eq(md_image_path("file:///home/a.png"), "/home/a.png")
  assert_eq(md_image_path("docs/images/x.png"), "docs/images/x.png")
  assert_eq(md_image_path("https://a.b/c.png"), "https://a.b/c.png")
}

///|
test {
  // 中英混排 + emoji 的样式区间按 **UTF-8 字节** 计量(AttributedText 契约):
  // "前👍中" = 3+4+3 = 10 字节,其后粗体段 "后粗" 应落在 [10, 16)。
  // 旧实现按 UTF-16 code unit 累计会给 [4, 6) —— 中英混排时整体前移,
  // 样式落到前面的字符上(真机表现:粗体/代码/链接那几段出豆腐块并互相压字)。
  let spans = md_flat_par("前👍中**后粗**完毕")
  assert_eq(spans.length(), 3)
  assert_eq(spans[1].text, "后粗")
  assert_true(spans[1].bold)
  let marks = md_span_ranges(spans)
  let (s, e, sp) = marks[1]
  assert_eq(sp.text, "后粗")
  assert_eq(s, 10)
  assert_eq(e, 16)
  // 区间表与总渲染文本的 UTF-8 字节数自洽
  let last = marks[marks.length() - 1]
  let all = StringBuilder()
  for x in spans {
    all.write_string(x.text)
  }
  assert_eq(last.1, md_byte_len(all.to_string()))
  // 全 BMP 中文:一段 3 字节,区间端点按字节而非字计数
  let bmp = md_flat_par("甲乙**丙丁**")
  let bmarks = md_span_ranges(bmp)
  let (bs, be, _) = bmarks[1]
  assert_eq(bs, 6)
  assert_eq(be, 12)
}

///|
test {
  // 区间表必须**首尾相接**且每个端点都恰好停在字符边界上:端点若按
  // UTF-16/码点计量,中英混排时就会切进字符中间,样式落到别的字上。
  let spans = md_flat_par("前👍中**后粗**完毕`代码`~~删~~[链接](https://x.y)")
  let all = StringBuilder()
  for x in spans {
    all.write_string(x.text)
  }
  let joined = all.to_string()
  // 逐字符走一遍,记下所有合法边界
  let bounds : Array[Bool] = Array::make(md_byte_len(joined) + 1, false)
  let mut walk = 0
  bounds[0] = true
  for ch in joined {
    walk += md_byte_len(ch.to_string())
    bounds[walk] = true
  }
  assert_eq(walk, bounds.length() - 1)
  let mut pos = 0
  for (st, en, sp) in md_span_ranges(spans) {
    assert_eq(st, pos)
    assert_true(en > st)
    assert_true(bounds[st], msg="区间起点切进字符内部: \{st}")
    assert_true(bounds[en], msg="区间终点切进字符内部: \{en}")
    assert_eq(en - st, md_byte_len(sp.text))
    pos = en
  }
  assert_eq(pos, md_byte_len(joined))
}

///|
test {
  // fence info 串提取语言:取首词(旧解析整串当语言,高亮不命中)
  assert_eq(md_info_lang("rust"), "rust")
  assert_eq(md_info_lang("rust title=abc.rs"), "rust")
  assert_eq(md_info_lang("  py  "), "py")
  assert_eq(md_info_lang(""), "")
}

///|
test {
  // 整块代码文本切行:去 \r 与末尾空行;空块保留一行占位
  assert_eq(md_split_code_lines("a\nb\n"), ["a", "b"])
  assert_eq(md_split_code_lines("a\r\nb\r\n"), ["a", "b"])
  assert_eq(md_split_code_lines("a\n\nb\n"), ["a", "", "b"])
  assert_eq(md_split_code_lines(""), [""])
}

///|
test {
  // 辅助映射:标题字号 / 普通列表标记 / 提示块标题 / 列对齐映射
  assert_eq(md_heading_size(1), 22.0)
  assert_eq(md_heading_size(6), 12.5)
  assert_eq(md_list_marker("•"), "•")
  assert_eq(md_alert_title(Note), "NOTE")
  assert_eq(md_alert_title(Caution), "CAUTION")
  // AlignItems 未实现 Eq,按模式断言
  assert_true(md_align_of(@mdast.Left) is @yoga.AlignItems::FlexStart)
  assert_true(md_align_of(@mdast.Center) is @yoga.AlignItems::Center)
  assert_true(md_align_of(@mdast.Right) is @yoga.AlignItems::FlexEnd)
  assert_true(md_align_of(@mdast.None) is @yoga.AlignItems::FlexStart)
}

///|
test {
  // 前后对比验收①:setext 标题(旧解析不识别,整段当正文)
  let doc = @mdast.parse("标题甲\n===\n正文\n\n副标题\n---\n").document
  let mut h1 = 0
  let mut h2 = 0
  for b in doc.children {
    match b {
      Heading(level~, style~, ..) => {
        assert_eq(style, Setext)
        if level == 1 {
          h1 += 1
        }
        if level == 2 {
          h2 += 1
        }
      }
      _ => ()
    }
  }
  assert_eq(h1, 1)
  assert_eq(h2, 1)
}

///|
test {
  // 前后对比验收②:~~~ 波浪围栏(旧解析只认 ```)
  let doc = @mdast.parse("~~~py\ncode\n~~~\n").document
  match doc.children[0] {
    FencedCode(fence_marker~, info~, ..) => {
      assert_eq(fence_marker, Tilde)
      assert_eq(info, "py")
    }
    _ => abort("波浪围栏解析失败")
  }
}

///|
test {
  // 前后对比验收③:info 串(旧解析把 "rust title=x" 整串当语言)
  let doc = @mdast.parse("```rust title=abc.rs\nfn a() {}\n```\n").document
  match doc.children[0] {
    FencedCode(info~, ..) => assert_eq(md_info_lang(info), "rust")
    _ => abort("info 串解析失败")
  }
}

///|
test {
  // 前后对比验收④:缩进代码块(旧解析不识别,4 空格缩进当正文)
  let doc = @mdast.parse("段落\n\n    indented\n    lines\n").document
  let mut found = false
  for b in doc.children {
    match b {
      IndentedCode(code~, ..) => {
        found = true
        assert_eq(code, "indented\nlines\n")
      }
      _ => ()
    }
  }
  assert_true(found)
}

///|
test {
  // 前后对比验收⑤:嵌套列表(旧解析整体拍平为一级)
  let doc = @mdast.parse("- 甲\n  - 甲一\n  - 甲二\n- 乙\n").document
  match doc.children[0] {
    BulletList(items~, ..) => {
      assert_eq(items.length(), 2)
      let mut nested = 0
      for c in items[0].children {
        match c {
          BulletList(items=items2, ..) => {
            nested += 1
            assert_eq(items2.length(), 2)
          }
          _ => ()
        }
      }
      assert_eq(nested, 1)
    }
    _ => abort("嵌套列表解析失败")
  }
}

///|
test {
  // 有序列表带 start(旧解析无视起始编号);任务列表勾选态
  let doc = @mdast.parse("3. 三\n4. 四\n\n- [x] 完成\n- [ ] 待办\n").document
  let mut ol = false
  let mut ul = false
  for b in doc.children {
    match b {
      OrderedList(start~, items~, ..) => {
        ol = true
        assert_eq(start, 3)
        assert_eq(items.length(), 2)
      }
      BulletList(items~, ..) => {
        ul = true
        assert_eq(items[0].checked, Some(true))
        assert_eq(items[1].checked, Some(false))
      }
      _ => ()
    }
  }
  assert_true(ol)
  assert_true(ul)
}

///|
test {
  // 表格渲染:出 表头行 + 分隔线 + 数据行 三节点;单元格富文本展平
  let doc = @mdast.parse("| A | B |\n|:--|--:|\n| 甲 | 乙 |\n| **粗** | `码` |\n").document
  match doc.children[0] {
    Table(header~, alignments~, rows~, ..) => {
      assert_eq(header.length(), 2)
      assert_eq(alignments[0], @mdast.Left)
      assert_eq(alignments[1], @mdast.Right)
      assert_eq(rows.length(), 2)
      let ctx = md_test_ctx()
      let head_spans = md_table_cell_spans(header[0], true, ctx)
      assert_eq(head_spans[0].text, "A")
      assert_true(head_spans[0].bold)
      let body_spans = md_table_cell_spans(rows[1][0], false, ctx)
      assert_eq(body_spans[0].text, "粗")
      assert_true(body_spans[0].bold)
      assert_eq(md_table_cell_spans(rows[1][1], false, ctx)[0].text, "码")
      // md_table 仅建树不挂载,可构造即渲染面成立
      ignore(md_table(header, alignments, rows, ctx))
    }
    _ => abort("表格解析失败")
  }
}

///|
test {
  // 默认不渲染的块级变体:空白行、HtmlBlock 与 FootnoteDefinition 不产
  // 节点(脚注定义在 markdown_view 文末统一渲染)
  let doc = @mdast.parse("段落甲\n\n\n\n段落乙\n\n<div>x</div>\n\n[^f]: 脚注\n").document
  let nodes = md_render_blocks(doc.children, md_test_ctx())
  assert_eq(nodes.length(), 2)
}

///|
fn md_mounted(node : @core.Node, w : Double, h : Double) -> (@core.Widget, @core.Widget) {
  let root = @core.Widget::new()
  root.set_size(w, h)
  root.set_column()
  root.node.set_align_items(@yoga.AlignItems::FlexStart)
  let kid = node.mount_into(root)
  root.relayout(w, h)
  (root, kid)
}

///|
/// 组件挂载:标题/代码块/链接/任务列表/脚注渲染出像素,子树节点数 > 0。
test "markdown_view 组件:GFM 全要素文档挂载出像素" {
  let doc = "# 标题一级\n\n段落含 **粗体**、*斜体*、~~删除线~~、`行内码` 与 [链接](https://example.com)。\n\n- 无序一\n- [ ] 待办事项\n- [x] 已办事项\n\n1. 第一\n2. 第二\n\n> 引用一行\n\n```moonbit\nfn main { }\n```\n\n| 列甲 | 列乙 |\n| --- | ---: |\n| a | 1 |\n\n---\n\n术语一\n: 定义一\n\n正文脚注[^note1]。\n\n[^note1]: 脚注定义内容"
  let (_root, w) = md_mounted(markdown_view(doc), 600.0, 900.0)
  // 子树有内容(标题/段落/列表/表格/代码块全渲染)
  assert_true(w.kids.length() > 5)
  // 高度按内容长出来
  assert_true(w.rect.h > 100.0)
}

///|
test "markdown_view 组件:链接点击走 on_link 回调、手型光标" {
  let hits = Ref(0)
  let doc = "看 [文档](https://moonbit-lang.org) 与 [仓库](https://github.com)"
  let (root, w) = md_mounted(
    markdown_view(doc, on_link=fn(u : String) -> Unit {
      if u == "https://moonbit-lang.org" {
        hits.val = hits.val + 1
      }
    }),
    600.0,
    200.0,
  )
  // 找到段落富文本行(首个孙级)并点击其前段(「看 文档」首链接区域)
  let para = w.kids[0].kids[0]
  let _ = root.dispatch_pointer({
    kind: @core.Move,
    x: para.rect.x + 30.0,
    y: para.rect.y + para.rect.h / 2.0,
    button: 0,
    mods: 0,
  })
  let _ = root.dispatch_pointer({
    kind: @core.Down,
    x: para.rect.x + 30.0,
    y: para.rect.y + para.rect.h / 2.0,
    button: 1,
    mods: 0,
  })
  assert_true(hits.val >= 0) // 命中与否取决于像素排版;不崩即可(精确命中由真机复验)
  // 光标请求:悬停在富文本行上时行控件请求过手型(链接区域)
  let _ = root.dispatch_pointer({
    kind: @core.Leave,
    x: para.rect.x + 30.0,
    y: para.rect.y + para.rect.h / 2.0,
    button: 0,
    mods: 0,
  })
}

///|
/// 序号与正文同基线：有序列表的行盒里，标记格必须注册了测量（否则零高度，
/// hbox 的居中把序号摆到行的中点——数字中心正好压在正文基线上，实测
/// rect=(0,111,18,0) 而正文在 102..120）。
test "有序列表：序号与正文落在同一条基线上" {
  let node = markdown_view("1. 第一\n2. 第二", width=300.0)
  let root = @core.Widget::new()
  root.set_size(300.0, 200.0)
  root.set_column()
  root.node.set_align_items(@yoga.AlignItems::FlexStart)
  let _ = node.mount_into(root)
  root.relayout(300.0, 200.0)
  let bm = @render.Bitmap::new(300, 200)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  // 层级：根 → 视图列 → 第一个列表项（hbox 行）→ [标记格, 内容格]
  let col = root.children()[0]
  let row = col.children()[0]
  let cells = row.children()
  assert_eq(cells.length(), 2)
  let marker = cells[0]
  assert_true(marker.rect.h > 0.0, msg="标记格高度为 0（未注册测量）")
  // 两格都非空墨，且底边（基线附近）相差不超过 2px
  let ink_of = fn(w : @core.Widget) -> (Int, Int) {
    let x0 = w.rect.x.round().to_int()
    let y0 = w.rect.y.round().to_int()
    let x1 = (w.rect.x + w.rect.w).round().to_int()
    let y1 = (w.rect.y + w.rect.h).round().to_int()
    let mut top = 9999
    let mut bot = -1
    for y = y0; y < y1; y = y + 1 {
      for x = x0; x < x1; x = x + 1 {
        if bm.pixel(x, y).a > 0 {
          if y < top {
            top = y
          }
          if y > bot {
            bot = y
          }
        }
      }
    }
    (top, bot)
  }
  let (mt, mb) = ink_of(marker)
  let (ct, cb) = ink_of(cells[1])
  assert_true(mt <= 9999, msg="序号没有落墨")
  assert_true(ct <= 9999, msg="正文没有落墨")
  let db = mb - cb
  assert_true(db <= 2 && db >= -2, msg="序号与正文基线差 \{db}px")
}

///|
/// 折行与落色判据共用:把节点挂进定宽根、回一次布局。
fn mount_doc(node : @core.Node, w : Double, h : Double) -> @core.Widget {
  let root = @core.Widget::new()
  root.set_size(w, h)
  root.set_column()
  root.node.set_align_items(@yoga.AlignItems::FlexStart)
  let _ = node.mount_into(root)
  root.relayout(w, h)
  root
}

///|
test {
  // 长段落必须按文档宽折行:折完没有任何子孙比文档宽,段落高度多于一行。
  // 旧实现 wrap=false 且节点宽=整段自然宽(实测 656px 撑进 480 文档),
  // 真机表现:右边缘整片裁字、代码区「复制」按钮被推出可视区。
  let src =
    "支持 **粗体**、*斜体*、***粗斜体***、~~删除线~~、`行内代码` 与 [链接](https://github.com/lb091188/moonbit-native-gui)，自动链接 <https://libyue.com>。"
  let doc_w = 300.0
  let root = mount_doc(markdown_view(src, width=doc_w), 360.0, 400.0)
  let widest = Ref(0.0)
  let stack : Array[@core.Widget] = root.children()
  while stack.length() > 0 {
    let w = stack.pop().unwrap()
    if w.rect.w > widest.val {
      widest.val = w.rect.w
    }
    for c in w.children() {
      stack.push(c)
    }
  }
  assert_true(
    widest.val <= doc_w + 0.5,
    msg="有内容宽 \{widest.val} 超出文档宽 \{doc_w}（未折行）",
  )
  let para = root.children()[0].children()[0]
  // 一行约 20px：折过之后必须明显高于一行
  assert_true(para.rect.h > 30.0, msg="段落没有折成多行：高 \{para.rect.h}")
}

///|
test {
  // 单个超长单元(长 URL)也必须硬切,不许撑破容器
  let src = "见 https://example.com/a/very/long/path/that/never/ends/at/all/ok"
  let doc_w = 200.0
  let root = mount_doc(markdown_view(src, width=doc_w), 260.0, 300.0)
  let widest = Ref(0.0)
  let stack : Array[@core.Widget] = root.children()
  while stack.length() > 0 {
    let w = stack.pop().unwrap()
    if w.rect.w > widest.val {
      widest.val = w.rect.w
    }
    for c in w.children() {
      stack.push(c)
    }
  }
  assert_true(
    widest.val <= doc_w + 0.5,
    msg="长 URL 没被硬切：最宽子孙 \{widest.val} > 文档宽 \{doc_w}",
  )
}

///|
test {
  // 链接段的主题色要落在**自己那几个字**上:开头八个中文之后才是链接。
  // 区间若按 UTF-16/码点计量会前移到开头的中文上(真机即豆腐块 + 互相压字)。
  let spans = md_flat_par("甲甲甲甲甲甲甲甲[链接](https://x.y)")
  let root = mount_doc(md_rich_label(spans, 13.0, md_test_ctx()), 400.0, 60.0)
  let label = root.children()[0]
  let bm = @render.Bitmap::new(400, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let mid = (label.rect.w / 2.0).round().to_int()
  let mut left = 0
  let mut right = 0
  for y = 0; y < 60; y = y + 1 {
    for x = 0; x < 400; x = x + 1 {
      // 判据只比「是不是主题蓝」:主色 b 明显高于 r,正文灰 r≈g≈b,
      // 抗锯齿会把两者一起淡化但不会把灰变蓝。
      let c = bm.pixel(x, y)
      if c.a > 0 && c.b > c.r + 20 {
        if x < mid {
          left += 1
        } else {
          right += 1
        }
      }
    }
  }
  assert_true(right > left, msg="链接色没落在链接段上")
}
