// 共享层:页面「段」装配。page 用 segmented 列出各段短名(如
// 主题|按钮|文字|…);每段正文自带滚动区(切段各自保留滚动位置,
// 页级不再整体滚动),选中段填满剩余高度。切段只切容器可见性,
// 不重建视图树。代码区顶行常驻「复制」,点击写入剪贴板并经全局
// toast 回显(钩子由 main 注入)。

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
/// 一页 = 顶部 segmented 段列表(超宽自动换行)+ 段正文栈;选中段
/// 填满剩余高度并自带滚动,其余段隐藏(不重建,滚动位置各自保留)。
pub fn page(secs : Array[Section]) -> @yue.Node {
  let selected : @yue.Store[String] = @yue.Store::new(secs[0].name)
  let names : Array[String] = []
  for s in secs {
    names.push(s.name)
  }
  let strip = @yue.hbox(
    [@yue.segmented(names, selected)],
    style=[("paddingLeft", 14.0), ("paddingRight", 14.0), ("paddingTop", 10.0), ("flexWrap", "wrap"), ("alignItems", "center")],
  )
  let bodies : Array[@yue.Node] = []
  for s in secs {
    bodies.push(section_body(s, selected))
  }
  @yue.vbox(
    [
      strip,
      // 段是显隐切换对象:按两栖容器规则用 grow/shrink 单写,不写
      // flex 简写(简写派生 basis 0 的坑见 docs/zh/adaptation.md)
      @yue.vbox(
        bodies,
        style=[("flexgrow", 1.0), ("flexshrink", 1.0), ("flexDirection", "column")],
      ),
    ],
    style=[("flex", 1.0)],
  )
}

///|
/// 主区导航页:挂载后订阅导航状态做 set_visible 切换(侧栏菜单/
/// segmented/面包屑共享同一导航 Store)。页面内容惰性挂载:未选中过
/// 的页只留空壳,首次选中才把 content 挂进占位——与段级惰性同机理,
/// 15 页全量挂载(浏览器页含 WebKit 重控件)的启动开销不可行。
pub fn nav_page(
  name : String,
  selected : @yue.Store[String],
  content : @yue.Node,
) -> @yue.Node {
  let mounted : Ref[Bool] = Ref(false)
  @yue.vbox([], style=[("flex", 1.0)], handle=fn(c) {
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

///|
/// 选中段的正文:标题 + 演示 + 说明 + 代码(带复制行),内容超高分段内
/// 滚动;容器随页面 selected 切换显隐。演示内容惰性挂载:未选中过的
/// 段只有标题/说明/代码骨架,首次选中才把 content 挂进占位容器——
/// 全量挂载意味着启动即建 111 段全部控件(图标墙页 803 个图标控件),
/// debug 构建秒级;挂过之后保形,显隐/滚动位置语义不变。
fn section_body(s : Section, selected : @yue.Store[String]) -> @yue.Node {
  let mounted : Ref[Bool] = Ref(false)
  // 惰性挂载完成后按当前内容重算滚动范围(Linux GTK 的滚动范围取
  // set_content 时刻快照,不刷新会停在骨架高度滚不动)
  let scroll_ref : Ref[@yue.Scroll?] = Ref(None)
  let holder = @yue.vbox([], handle=fn(h) {
    fn ensure(name : String) -> Unit {
      if !mounted.val && name == s.name {
        mounted.val = true
        for c in s.content {
          let _ = c.mount_into(h.view)
        }
        match scroll_ref.val {
          Some(sc) => sc.refresh_content_size()
          None => ()
        }
      }
    }
    ensure(selected.get())
    selected.subscribe(ensure)
  })
  let inner : Array[@yue.Node] = [
    @yue.label_t(s.title, role=@yue.Section, style=[("marginBottom", 10.0)]),
  ]
  if s.desc != "" {
    inner.push(
      @yue.label_t(s.desc, role=@yue.Secondary, style=[("marginTop", 10.0),("marginBottom", 10.0)]),
    )
  }
  inner.push(holder)
  if s.code.length() > 0 {
    inner.push(code_copy_row(s.code))
    inner.push(
      @yue.code_view(s.code, lang="moonbit", line_numbers=true, style=[("width", 1000.0)]),
    )
  }
  // 本容器是显隐切换对象:grow/shrink 单写(不写 flex 简写)
  @yue.vbox(
    [
      @yue.scroll(
        @yue.vbox(inner, style=[("padding", 14.0)]),
        style=[("flexgrow", 1.0), ("flexshrink", 1.0)],
        handle=fn(sc) { scroll_ref.val = Some(sc) },
      ),
    ],
    style=[("flexgrow", 1.0), ("flexshrink", 1.0)],
    handle=fn(c) {
      fn apply(name : String) -> Unit {
        c.set_visible(name == s.name)
      }

      apply(selected.get())
      selected.subscribe(apply)
    },
  )
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
    style=[("marginTop", 10.0), ("marginBottom", 4.0), ("alignItems", "center")],
  )
}
