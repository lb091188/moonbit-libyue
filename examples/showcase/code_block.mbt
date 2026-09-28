// 页面分「段」展示:顶部 segmented 列出各段短名(如 主题|按钮|文字|…),
// 正文区显示选中段的 标题/演示/说明/代码 四件同屏,不做二次切换;切换
// 段只切容器可见性,不重建视图树。代码区顶行常驻「复制」,点击写入
// 剪贴板并经全局 toast 回显。

///|
/// 全局 toast 推送钩子:main 创建 toast_layer 后注入,复制回显用。
let code_toast : Ref[((String, @yue.SemanticType) -> Unit)?] = Ref(None)

///|
/// 一段演示:name 进页面顶部 segmented 标签列表(短名,页内唯一);
/// title/desc/content/code 为该段正文四件套。
struct Section {
  name : String
  title : String
  desc : String
  content : Array[@yue.Node]
  code : Array[String]
}

///|
/// 选中段的正文:标题 + 演示 + 说明 + 代码(带复制行);容器随页面
/// selected 切换显隐。
fn section_body(s : Section, selected : @yue.Store[String]) -> @yue.Node {
  let inner : Array[@yue.Node] = [
    @yue.label_t(s.title, role=@yue.Section, style=[("marginBottom", 8.0)]),
  ]
  for c in s.content {
    inner.push(c)
  }
  if s.desc != "" {
    inner.push(
      @yue.label_t(s.desc, role=@yue.Secondary, style=[("marginTop", 10.0)]),
    )
  }
  if s.code.length() > 0 {
    inner.push(code_copy_row(s.code))
    inner.push(
      @yue.code_view(s.code, lang="moonbit", line_numbers=true, width=1000.0),
    )
  }
  @yue.vbox([@yue.vbox(inner)], style=[("marginBottom", 6.0)], handle=fn(c) {
    fn apply(name : String) -> Unit {
      c.set_visible(name == s.name)
    }

    apply(selected.get())
    selected.subscribe(apply)
  })
}

///|
/// 代码区顶行:左「代码」小标,右「复制」按钮(toast 回显)。
fn code_copy_row(lines : Array[String]) -> @yue.Node {
  @yue.hbox(
    [
      @yue.label_t("代码", role=@yue.Secondary),
      @yue.label_t("", role=@yue.Secondary, style=[("flex", 1.0)]),
      @yue.button_t("复制", variant=@yue.Text, on_click=fn() {
        @yue.Clipboard::get().set_text(lines.join("\n"))
        match code_toast.val {
          Some(push) => push("代码已复制 ✓", @yue.Success)
          None => ()
        }
      }),
    ],
    style=[("marginTop", 12.0), ("marginBottom", 4.0)],
    style_str=[("alignItems", "center")],
  )
}
