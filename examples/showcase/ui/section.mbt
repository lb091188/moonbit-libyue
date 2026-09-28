// 共享层:页面「段」装配。scroll_page 用 segmented 列出各段短名
// (如 主题|按钮|文字|…),正文区显示选中段的 标题/演示/说明/代码 四件
// 同屏;切段只切容器可见性,不重建视图树。代码区顶行常驻「复制」,
// 点击写入剪贴板并经全局 toast 回显(钩子由 main 注入)。

///|
/// 全局 toast 推送钩子:main 创建 toast_layer 后注入,复制回显用。
pub let code_toast : Ref[((String, @yue.SemanticType) -> Unit)?] = Ref(
  None,
)

///|
/// 一段演示:name 进页面顶部 segmented 标签列表(短名,页内唯一);
/// title/desc/content/code 为该段正文四件套。
pub struct Section {
  name : String
  title : String
  desc : String
  content : Array[@yue.Node]
  code : Array[String]
}

///|
/// 声明一段演示:name 是段列表短名(页内唯一),title/desc/content/code
/// 为该段正文四件套;实际节点由 scroll_page 统一装配。
pub fn section(
  name : String,
  title : String,
  desc : String,
  content : Array[@yue.Node],
  code? : Array[String] = [],
) -> Section {
  { name, title, desc, content, code, }
}

///|
/// 一页 = 顶部 segmented 段列表(超宽自动换行)+ 滚动正文;选中某段
/// 显示该段 标题/演示/说明/代码,其余段隐藏(不重建)。
pub fn scroll_page(secs : Array[Section]) -> @yue.Node {
  let selected : @yue.Store[String] = @yue.Store::new(secs[0].name)
  let names : Array[String] = []
  for s in secs {
    names.push(s.name)
  }
  let strip = @yue.hbox(
    [@yue.segmented(names, selected)],
    style=[("paddingLeft", 14.0), ("paddingRight", 14.0), ("paddingTop", 10.0)],
    style_str=[("flexWrap", "wrap"), ("alignItems", "center")],
  )
  let bodies : Array[@yue.Node] = []
  for s in secs {
    bodies.push(section_body(s, selected))
  }
  @yue.vbox(
    [
      strip,
      @yue.scroll(@yue.vbox(bodies, style=[("padding", 14.0)]), style=[
        ("flex", 1.0),
      ]),
    ],
    style=[("flex", 1.0)],
  )
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
      @yue.button_t(
        "复制",
        variant=@yue.Text,
        on_click=fn() {
          @yue.Clipboard::get().set_text(lines.join("\n"))
          match code_toast.val {
            Some(push) => push("代码已复制 ✓", @yue.Success)
            None => ()
          }
        },
      ),
    ],
    style=[("marginTop", 12.0), ("marginBottom", 4.0)],
    style_str=[("alignItems", "center")],
  )
}
