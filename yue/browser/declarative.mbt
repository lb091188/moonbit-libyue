// 声明式层接入：browser 节点与主包 declarative 的 vbox/hbox 同构。
// mount 时才实例化 Browser（构造器只建树，语义与主包 declarative 一致）。

///|
/// 内嵌浏览器节点（html 与 url 二选一，都给时以 url 为准）。
pub fn browser(
  url? : String = "",
  html? : String = "",
  handle? : (Browser) -> Unit = fn(_b) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let b = Browser::make(url~, html~)
      let node = @yue.node_of(b, style~, style_str~)
      handle(b)
      node.mount_into(parent)
    },
  }
}
