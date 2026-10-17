// W31 命名样式类注册表：define 可复用的样式块，resolve 按名查找并合并。
// 组件侧的 `class : Array[Style]` 仍按原样工作；新增 `class_of(names)` 把
// 命名类解析为 Style 数组，两种入口可以混用（散写匿名块优先级高、排尾）。

///|
pub(all) struct StyleClass {
  name : String
  style : Style
}

let registry : Map[String, StyleClass] = Map([])

///|
/// 定义/覆盖一个命名样式类。同名重复 define 以最后一次为准。
pub fn define_class(name : String, s : Style) -> Unit {
  let _ = registry.set(name, { name: name, style: s, })
}

///|
/// 查一个命名类；未注册返回 None。
pub fn lookup_class(name : String) -> StyleClass? {
  registry.get(name)
}

///|
/// 按名数组解析为 Style 数组（未注册的跳过），供组件 `class=` 消费：
/// `class = class_of(["btn-primary", "btn-large"])`。
pub fn class_of(names : Array[String]) -> Array[Style] {
  let out : Array[Style] = []
  for n in names {
    match registry.get(n) {
      Some(c) => out.push(c.style)
      None => ()
    }
  }
  out
}

///|
/// 列出所有已注册类名（诊断用）。
pub fn registered_classes() -> Array[String] {
  let out : Array[String] = []
  for (k, _) in registry {
    out.push(k)
  }
  out
}

///|
/// 清空注册表（测试用）。
pub fn reset_class_registry() -> Unit {
  for (k, _) in registry {
    let _ = registry.remove(k)
  }
}
