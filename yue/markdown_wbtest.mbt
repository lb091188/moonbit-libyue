// markdown_view 白盒测试:码点→UTF-16 换算层、行内展平与区间计量、
// fence info/切行,以及旧自写解析器 CommonMark 偏差清单的前后对比
// 验收用例(setext 标题 / ~~~ 围栏 / info 串 / 缩进代码块 / 嵌套列表)。

///|
/// 测试帮手:解析单段落源文并展平其行内。
fn md_flat_par(src : String) -> Array[MDSpan] {
  let doc = @markdown.parse(src).document
  let spans : Array[MDSpan] = []
  for b in doc.children {
    match b {
      Paragraph(children~, ..) =>
        for s in md_flatten_inline(children) {
          spans.push(s)
        }
      _ => ()
    }
  }
  spans
}

///|
test {
  // 码点→UTF-16 换算:BMP 内 1:1,emoji(非 BMP)1 码点 = 2 code unit
  assert_eq(md_utf16_len(""), 0)
  assert_eq(md_utf16_len("abc"), 3)
  assert_eq(md_utf16_len("甲乙丙"), 3)
  assert_eq(md_utf16_len("👍"), 2)
  assert_eq(md_utf16_len("a👍b"), 4)
  assert_eq(md_utf16_len("👍👍"), 4)
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
  // 链接:渲染文字带链接样式,地址不进渲染文本
  let spans = md_flat_par("见 [文字](https://x.y/z) 即可")
  let all = StringBuilder()
  for s in spans {
    all.write_string(s.text)
    if s.link {
      assert_eq(s.text, "文字")
    }
  }
  assert_eq(all.to_string(), "见 文字 即可")
  assert_false(all.to_string().contains("https"))
  // 自动链接:地址本身带链接样式
  let auto = md_flat_par("去 <https://a.b/c> 看")
  assert_eq(auto.length(), 3)
  assert_eq(auto[1].text, "https://a.b/c")
  assert_true(auto[1].link)
}

///|
test {
  // 图片降级为 alt 文本(链接样式),url 不进渲染文本
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
  // 删除线:AttributedText 无删除线渲染面,内容按原样式保留
  let spans = md_flat_par("~~划掉~~")
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "划掉")
  assert_false(spans[0].bold)
  assert_false(spans[0].italic)
}

///|
test {
  // emoji 样式区间不错位(核心验收):"前👍中" 为 3 码点 / 4 个
  // UTF-16 code unit,其后粗体区间按 UTF-16 计量应为 [4, 6);
  // 旧实现按码点累计会错成 [3, 5),emoji 之后样式整体前移。
  let spans = md_flat_par("前👍中**后粗**完毕")
  assert_eq(spans.length(), 3)
  assert_eq(spans[1].text, "后粗")
  assert_true(spans[1].bold)
  let marks = md_span_ranges(spans)
  let (s, e, sp) = marks[1]
  assert_eq(sp.text, "后粗")
  assert_eq(s, 4)
  assert_eq(e, 6)
  // 区间表与总渲染文本的 UTF-16 长度自洽
  let last = marks[marks.length() - 1]
  let all = StringBuilder()
  for x in spans {
    all.write_string(x.text)
  }
  assert_eq(last.1, md_utf16_len(all.to_string()))
  // 全 BMP 文本退化为码点计数,与旧行为一致
  let bmp = md_flat_par("甲乙**丙丁**")
  let bmarks = md_span_ranges(bmp)
  let (bs, be, _) = bmarks[1]
  assert_eq(bs, 2)
  assert_eq(be, 4)
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
  // 辅助映射:标题字号 / 列表任务勾选标记 / 提示块标题
  assert_eq(md_heading_size(1), 22.0)
  assert_eq(md_heading_size(6), 12.5)
  assert_eq(md_list_marker("•", None), "•")
  assert_eq(md_list_marker("•", Some(true)), "☑")
  assert_eq(md_list_marker("•", Some(false)), "☐")
  assert_eq(md_alert_title(Note), "NOTE")
  assert_eq(md_alert_title(Caution), "CAUTION")
}

///|
test {
  // 前后对比验收①:setext 标题(旧解析不识别,整段当正文)
  let doc = @markdown.parse("标题甲\n===\n正文\n\n副标题\n---\n").document
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
  let doc = @markdown.parse("~~~py\ncode\n~~~\n").document
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
  let doc = @markdown.parse("```rust title=abc.rs\nfn a() {}\n```\n").document
  match doc.children[0] {
    FencedCode(info~, ..) => assert_eq(md_info_lang(info), "rust")
    _ => abort("info 串解析失败")
  }
}

///|
test {
  // 前后对比验收④:缩进代码块(旧解析不识别,4 空格缩进当正文)
  let doc = @markdown.parse("段落\n\n    indented\n    lines\n").document
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
  let doc = @markdown.parse("- 甲\n  - 甲一\n  - 甲二\n- 乙\n").document
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
  // 有序列表带 start(旧解析无视起始编号);任务列表勾选态;表格
  let doc = @markdown.parse("3. 三\n4. 四\n\n- [x] 完成\n- [ ] 待办\n\n| A | B |\n|---|---|\n| 甲 | 乙 |\n").document
  let mut ol = false
  let mut ul = false
  let mut tb = false
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
      Table(header~, rows~, ..) => {
        tb = true
        assert_eq(header.length(), 2)
        assert_eq(rows.length(), 1)
        let spans = md_flatten_inline(rows[0][0].children)
        assert_eq(spans[0].text, "甲")
      }
      _ => ()
    }
  }
  assert_true(ol)
  assert_true(ul)
  assert_true(tb)
}

///|
test {
  // 默认不渲染的块级变体:空白行与 HtmlBlock 不产节点
  let doc = @markdown.parse("段落甲\n\n\n\n段落乙\n\n<div>x</div>\n").document
  let nodes = md_render_blocks(doc.children)
  assert_eq(nodes.length(), 2)
}
