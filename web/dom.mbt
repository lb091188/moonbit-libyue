// DOM 抓取：只要渲染后的结构，不碰网络响应层（方案 §4.2 第 2 条）。
//
// 形态是「脚本生成 + 结构化解析」两只纯函数：脚本决定页面上取哪些字段并
// `JSON.stringify` 回来，解析把那段 JSON 折成本栈的数据结构。载荷不再是旧链
// 那套 `[ok][len][bytes]` 裸字节 ABI（CORE1 越界读教训的出处），所以越界与
// 半包这类问题在结构上不存在。

///|
/// 抓取档位。四档都返回同一种 JSON 形态（title/url + 各自的那一块）。
pub(all) enum DomKind {
  PageText
  Links
  Meta
  Structure
}

///|
/// 统一的包裹：`JSON.stringify({title,url,<字段>})`。括号由这一处闭合，四档只写
/// 自己的字段——散在各处的 `}})` 是语法错最容易出现的地方（本批实测踩过一次）。
fn dom_wrap(fields : String) -> String {
  "JSON.stringify({title:document.title,url:location.href," + fields + "})"
}

///|
/// 生成抓取脚本（交给 `Webview::evaluate_javascript`，回包是 JSON 文本）。
/// 列表一律截断：抓取的是「这一页长什么样」，不是把整站搬回来。
pub fn dom_script(k : DomKind) -> String {
  match k {
    PageText =>
      dom_wrap("text:((document.body||{}).innerText||'').slice(0,4000)")
    Links =>
      dom_wrap(
        "links:[].slice.call(document.querySelectorAll('a'),0,200)" +
          ".map(function(a){return {href:a.href,text:(a.textContent||'').trim().slice(0,80)}})",
      )
    Meta =>
      dom_wrap(
        "meta:[].slice.call(document.querySelectorAll('meta[name],meta[property]'),0,100)" +
          ".map(function(m){return {k:m.getAttribute('name')||m.getAttribute('property')||''," +
          "v:m.getAttribute('content')||''}})",
      )
    Structure =>
      dom_wrap(
        "count:document.querySelectorAll('*').length," +
          "headings:[].slice.call(document.querySelectorAll('h1,h2,h3'),0,50)" +
          ".map(function(h){return {k:h.tagName,v:(h.textContent||'').trim().slice(0,80)}})",
      )
  }
}

///|
/// 一个链接。
pub(all) struct DomLink {
  href : String
  text : String
}

///|
/// 一次抓取的结构化结果。`ok=false` 时 `raw` 留着原文供诊断（不静默吞掉）。
pub(all) struct DomSnapshot {
  kind : DomKind
  mut title : String
  mut url : String
  mut text : String
  links : Array[DomLink]
  meta : Array[(String, String)]
  headings : Array[(String, String)]
  mut elements : Int
  raw : String
  mut ok : Bool
}

///|
fn empty_snapshot(k : DomKind, raw : String) -> DomSnapshot {
  {
    kind: k,
    title: "",
    url: "",
    text: "",
    links: [],
    meta: [],
    headings: [],
    elements: 0,
    raw,
    ok: false,
  }
}

///|
fn j_text(v : @sys.VscJson?, key : String) -> String {
  match v {
    None => ""
    Some(o) =>
      match @sys.vsc_json_str(@sys.vsc_json_get(o, key)) {
        Some(s) => s
        None => ""
      }
  }
}

///|
fn j_int(v : @sys.VscJson?, key : String) -> Int {
  match v {
    None => 0
    Some(o) =>
      match @sys.vsc_json_int64(@sys.vsc_json_get(o, key)) {
        Some(n) => n.to_int()
        None => 0
      }
  }
}

///|
fn j_arr(v : @sys.VscJson?, key : String) -> Array[@sys.VscJson] {
  match v {
    None => []
    Some(o) =>
      match @sys.vsc_json_get(o, key) {
        Some(@sys.VscJArr(items)) => items
        _ => []
      }
  }
}

///|
/// 解析抓取回包。JS 求值出错时 `jsc_value_to_string` 给的是错误文本而不是 JSON，
/// 那时 `ok=false` 且 `raw` 就是那段文本。
pub fn dom_parse(k : DomKind, raw : String) -> DomSnapshot {
  match @sys.vsc_json_parse(raw) {
    None => empty_snapshot(k, raw)
    Some(root) => {
      let snap = empty_snapshot(k, raw)
      snap.ok = true
      snap.title = j_text(Some(root), "title")
      snap.url = j_text(Some(root), "url")
      snap.text = j_text(Some(root), "text")
      snap.elements = j_int(Some(root), "count")
      for it in j_arr(Some(root), "links") {
        snap.links.push({ href: j_text(Some(it), "href"), text: j_text(Some(it), "text") })
      }
      for it in j_arr(Some(root), "meta") {
        snap.meta.push((j_text(Some(it), "k"), j_text(Some(it), "v")))
      }
      for it in j_arr(Some(root), "headings") {
        snap.headings.push((j_text(Some(it), "k"), j_text(Some(it), "v")))
      }
      snap
    }
  }
}

///|
/// 抓一次 DOM（异步：回包经排期泵回来再解析）。返回 false = 还没挂载。
pub fn Webview::capture_dom(
  self : Webview,
  k : DomKind,
  done : (DomSnapshot) -> Unit,
) -> Bool {
  let seq = self.execute_javascript_with_result(dom_script(k), fn(raw : String) -> Unit {
    done(dom_parse(k, raw))
  })
  seq > 0L
}
