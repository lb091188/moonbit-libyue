// mizchi/markdown 0.8.3 独立探针:parse / render_html / serialize 三调用
// 在当前构建目标(native)实证可用。纯控制台,不初始化 GUI。
// 用法:moon run examples/probe-markdown
// 通过标志:末行输出 PROBE-OK;任一断言失败输出 PROBE-FAIL 及明细。

///|
fn markdown_input() -> String {
  [
  "# 探针标题",
  "",
  "正文含 **粗体**、*斜体*、`行内代码` 与 [链接](https://example.com/a)。",
  "",
  "- 列表项一",
  "- 列表项二",
  "",
  "```moonbit",
  "fn main { println(\"探针\") }",
  "```",
  "",
  "> 引用一行",
  "",
  "| 列A | 列B |",
  "|-----|-----|",
  "| 甲  | 乙  |",
  "",
  ].join("\n")
}

///|
fn main {
  let src = markdown_input()
  let failures : Array[String] = []
  fn expect(cond : Bool, name : String) -> Unit {
    if !cond {
      failures.push(name)
    }
  }

  // 1. parse:源文 → mdast 文档,统计块型
  let parsed = @markdown.parse(src)
  let doc = parsed.document
  let mut n_heading = 0
  let mut n_code = 0
  let mut n_table = 0
  let mut n_quote = 0
  let mut n_list = 0
  for block in doc.children {
    match block {
      Heading(..) => n_heading += 1
      FencedCode(..) => n_code += 1
      Table(..) => n_table += 1
      Blockquote(..) => n_quote += 1
      BulletList(..) | OrderedList(..) => n_list += 1
      _ => ()
    }
  }
  println("[parse] 块总数=\{doc.children.length()} 标题=\{n_heading} 围栏代码=\{n_code} 表格=\{n_table} 引用=\{n_quote} 列表=\{n_list}")
  expect(n_heading == 1, "parse 标题数(期望 1)")
  expect(n_code == 1, "parse 围栏代码数(期望 1)")
  expect(n_table == 1, "parse 表格数(期望 1)")
  expect(n_quote == 1, "parse 引用数(期望 1)")
  expect(n_list == 1, "parse 列表数(期望 1)")

  // 2. render_html:mdast → HTML
  let html = @markdown.render_html(doc)
  println("[render_html] 长度=\{html.length()}")
  println(html)
  expect(html.contains("<h1"), "render_html 含 <h1>")
  expect(html.contains("<pre") || html.contains("<code"), "render_html 含代码块标签")
  expect(html.contains("<table"), "render_html 含 <table>")
  expect(html.contains("<blockquote"), "render_html 含 <blockquote>")
  expect(html.contains("<li>"), "render_html 含 <li>")
  expect(html.contains("https://example.com/a"), "render_html 保留链接地址")

  // 3. serialize:mdast → markdown 源文,并往返重解析重渲染
  let roundtrip_src = @markdown.serialize(doc)
  println("[serialize] 长度=\{roundtrip_src.length()}")
  println(roundtrip_src)
  expect(roundtrip_src.contains("moonbit"), "serialize 保留代码围栏 info")
  expect(roundtrip_src.contains("探针标题"), "serialize 保留标题文字")
  let reparsed = @markdown.parse(roundtrip_src)
  let html2 = @markdown.render_html(reparsed.document)
  expect(html2.contains("<h1"), "serialize 往返后仍渲染出 <h1>")
  expect(html2.contains("<table"), "serialize 往返后仍渲染出 <table>")

  if failures.length() == 0 {
    println("PROBE-OK")
  } else {
    for f in failures {
      println("PROBE-FAIL: \{f}")
    }
  }
}
