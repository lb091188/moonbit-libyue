// 共享层:页面壳与导航页。页面壳 = 标题 + 描述 + 自滚动正文,并返回
// 「刷新滚动范围」函数——GTK 的滚动范围取 set_content 时刻快照,页内
// 动态长高的内容(报告 set_text、播放器挂载)完成后必须调用,否则
// 滚动范围停在挂载瞬间(见 docs/zh/adaptation.md 惰性挂载小节)。

///|
/// 一页 = 标题 + 描述(可空)+ 自滚动正文。body 为正文构建函数,入参
/// 是「刷新滚动范围」闭包:页内动态长高(报告 set_text、播放器挂载)
/// 完成后调用,否则 GTK 滚动范围停在挂载瞬间(见文件头注释)。
pub fn page_shell(
  title : String,
  desc : String,
  body : (() -> Unit) -> Array[@yue.Node],
) -> @yue.Node {
  let scroll_ref : Ref[@yue.Scroll?] = Ref(None)
  fn refresh() -> Unit {
    match scroll_ref.val {
      Some(sc) => sc.refresh_content_size()
      None => ()
    }
  }
  let head : Array[@yue.Node] = [
    @components.label_t(title, role=@components.Section),
  ]
  if desc != "" {
    head.push(@components.label_t(desc, role=@components.Secondary))
  }
  let node = @declarative.vbox(
    [
      @declarative.vbox(head, style=[("padding", 14.0), ("gap", 8.0)]),
      @declarative.scroll(
        @declarative.vbox(body(refresh), style=[
          ("padding", 14.0),
          ("gap", 14.0),
        ]),
        style=[("flexgrow", 1.0), ("flexshrink", 1.0)],
        handle=fn(sc) { scroll_ref.val = Some(sc) },
      ),
    ],
    style=[("flex", 1.0)],
  )
  node
}

///|
/// 报告标签写入并强制长高:GTK 标签的 yoga 高度只在挂载时测量一次,
/// set_text 不标记重测——写入比占位文本更长的内容时按旧高度裁剪
/// (实测 16 行报告只显示第 1 行)。显隐切换经 shim 的 set_visible
/// 做根级重算,迫使重新测量标签高度;末尾刷新滚动范围(定案见
/// adaptation.md「报告标签 set_text 后不长高」条)。
pub fn report_set(
  label : @yue.Label,
  text : String,
  refresh : () -> Unit,
) -> Unit {
  label.set_text(text)
  label.set_visible(false)
  label.set_visible(true)
  refresh()
}

///|
/// 主区导航页:挂载后订阅导航状态做 set_visible 切换(侧栏菜单为同一
/// 导航 Store 的另一视图)。页面内容惰性挂载:未选中过的页只留空壳,
/// 首次选中才把 content 挂进占位(与 showcase 同机理)。
pub fn nav_page(
  name : String,
  selected : @yue.Store[String],
  content : @yue.Node,
) -> @yue.Node {
  let mounted : Ref[Bool] = Ref(false)
  @declarative.vbox([], style=[("flex", 1.0)], handle=fn(c) {
    fn ensure(s : String) -> Unit {
      if !mounted.val && s == name {
        mounted.val = true
        let _ = content.mount_into(c.view)
      }
      c.set_visible(s == name)
    }

    ensure(selected.get())
    selected.subscribe(ensure)
  })
}
