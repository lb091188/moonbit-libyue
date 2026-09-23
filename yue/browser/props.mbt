// 便捷构造。

///|
/// 创建内嵌浏览器：html 与 url 二选一（两者都给时以 url 为准）。
pub fn Browser::make(url? : String = "", html? : String = "") -> Browser {
  let b = Browser::new()
  if url != "" {
    b.load_url(url)
  } else if html != "" {
    b.load_html(html)
  }
  b
}
