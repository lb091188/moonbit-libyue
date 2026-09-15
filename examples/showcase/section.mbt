// 小程序式分段的构建函数：每段 = 标题 + 一句说明 + 可交互演示区 + 分隔留白。
//
// 平台差异内容按 platform() 运行时条件组装：条件不满足就整段不创建，
// 效果等同"编译期隐藏"。不用 #cfg(platform=) 的原因与迁移信号见
// docs/adaptation.md「MoonBit cfg(platform=) 现状」。

///|
fn is_linux() -> Bool {
  @yue.platform() == "linux"
}

///|
fn is_macos() -> Bool {
  @yue.platform() == "macos"
}

///|
fn is_windows() -> Bool {
  @yue.platform() == "windows"
}

///|
let title_color : String = "#356AA0"

///|
let desc_color : String = "#8A9199"

///|
/// 一段演示。
fn section(
  title : String,
  desc : String,
  content : Array[@yue.Node],
) -> @yue.Node {
  let t = @yue.label(
    title,
    style_str=[("color", title_color)],
    style=[("marginBottom", 4.0)],
    handle=fn(l) { l.set_align(@yue.Start) },
  )
  let d = @yue.label(
    desc,
    style_str=[("color", desc_color)],
    style=[("marginBottom", 10.0)],
    handle=fn(l) { l.set_align(@yue.Start) },
  )
  let nodes : Array[@yue.Node] = [t, d]
  for c in content {
    nodes.push(c)
  }
  nodes.push(@yue.separator(style=[("marginTop", 4.0), ("marginBottom", 20.0)]))
  @yue.vbox(nodes, style=[("marginBottom", 6.0)])
}

///|
/// 一页 = 整页滚动区包住全部分段。flex 1 让 Scroll 填满页签的可用区域
/// （notebook 页区域由 GTK 分配,页容器是独立 yoga 子树的根）。
fn scroll_page(sections : Array[@yue.Node]) -> @yue.Node {
  @yue.scroll(@yue.vbox(sections, style=[("padding", 14.0)]), style=[
    ("flex", 1.0),
  ])
}

///|
/// 对可空句柄安全调用（Ref[T?] 里的句柄在挂载后才存在）。
fn[T] when_some(r : Ref[T?], f : (T) -> Unit) -> Unit {
  match r.val {
    Some(v) => f(v)
    None => ()
  }
}
