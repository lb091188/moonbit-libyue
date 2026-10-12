// DOM 抓取的无头回归：脚本形态（四档都返回 JSON、都带 title/url 头）与结构化解析
// （字段各归各位、解析失败不静默）。真页面抓取由 modules/gui-examples/native-web 回证。

///|
test "抓取脚本：四档都 stringify 且都带 title/url 头" {
  for k in [PageText, Links, Meta, Structure] {
    let s = dom_script(k)
    assert_true(s.has_prefix("JSON.stringify("))
    assert_true(s.contains("document.title"))
    assert_true(s.contains("location.href"))
  }
  assert_true(dom_script(PageText).contains("innerText"))
  assert_true(dom_script(Links).contains("querySelectorAll('a')"))
  assert_true(dom_script(Meta).contains("meta[name],meta[property]"))
  assert_true(dom_script(Structure).contains("querySelectorAll('*')"))
  assert_true(dom_script(Structure).contains("h1,h2,h3"))
}

///|
fn count_byte(s : String, target : Byte) -> Int {
  let bytes = @utf8.encode(s)
  let mut n = 0
  for b in bytes {
    if b == target {
      n = n + 1
    }
  }
  n
}

///|
test "抓取脚本括号配平：多一个右括号就是页面侧 SyntaxError" {
  // 真窗口里踩过的形态：回包是「SyntaxError: Unexpected token '}'」而不是崩溃，
  // 解析归假是对的，但脚本本身必须配平——所以这条断言钉的是生成器
  for k in [PageText, Links, Meta, Structure] {
    let s = dom_script(k)
    assert_eq(count_byte(s, b'{'), count_byte(s, b'}'))
    assert_eq(count_byte(s, b'('), count_byte(s, b')'))
    assert_true(s.has_suffix("})"))
  }
}

///|
test "结构化解析：标题/地址/正文与计数各归各位" {
  let raw =
    "{\"title\":\"标题甲\",\"url\":\"https://e.x/a\",\"text\":\"正文一二三\",\"count\":42}"
  let snap = dom_parse(Structure, raw)
  assert_eq(snap.ok, true)
  assert_eq(snap.title, "标题甲")
  assert_eq(snap.url, "https://e.x/a")
  assert_eq(snap.text, "正文一二三")
  assert_eq(snap.elements, 42)
  assert_eq(snap.links.length(), 0)
}

///|
test "结构化解析：链接表 / meta / 标题层级按档取" {
  let links =
    "{\"title\":\"t\",\"url\":\"u\",\"links\":[{\"href\":\"https://a\",\"text\":\"甲\"}," +
    "{\"href\":\"https://b\",\"text\":\"\"}]}"
  let s1 = dom_parse(Links, links)
  assert_eq(s1.links.length(), 2)
  assert_eq((s1.links[0].href, s1.links[0].text), ("https://a", "甲"))
  assert_eq((s1.links[1].href, s1.links[1].text), ("https://b", ""))

  let meta = "{\"meta\":[{\"k\":\"description\",\"v\":\"一句话\"}]}"
  let s2 = dom_parse(Meta, meta)
  assert_eq(s2.meta.length(), 1)
  assert_eq(s2.meta[0], ("description", "一句话"))

  let heads = "{\"headings\":[{\"k\":\"H1\",\"v\":\"大标题\"}]}"
  let s3 = dom_parse(Structure, heads)
  assert_eq(s3.headings.length(), 1)
  assert_eq(s3.headings[0], ("H1", "大标题"))
}

///|
test "解析失败不静默：ok 归假且 raw 原样留着" {
  // JS 求值出错时回包是错误文本而不是 JSON
  let bad = "ReferenceError: foo is not defined"
  let snap = dom_parse(PageText, bad)
  assert_eq(snap.ok, false)
  assert_eq(snap.raw, bad)
  assert_eq(snap.title, "")
  // 半包（语法不完整）同样归假，而不是给一个「看起来成功」的空快照
  assert_eq(dom_parse(Links, "{\"title\":\"甲\"").ok, false)
}
