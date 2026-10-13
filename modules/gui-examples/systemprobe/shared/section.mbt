// 共享层：页面「段」装配。`page` 用 segmented 列出各段短名（如
// 主题|按钮|文字|…）；每段正文自带滚动区（切段各自保留滚动位置，
// 页级不再整体滚动），选中段填满剩余高度。切段只切容器可见性，
// 不重建视图树。代码区顶行常驻「复制」，点击写入剪贴板并经全局
// toast 回显（钩子由 main 注入）。
//
// 新栈口径（G7 记档，与 master 线的三处机械差）：
// ① 组件返回 `@core.Node` 且不接 `style=[...]`，间距/内边距一律走容器参数
//    （`padding`/`row_gap`）——旧链路那套 CSS 字符串在本栈不存在；
// ② 显隐从 `View::set_visible` 换成 `Widget::set_visible`，惰性挂载从
//    `Node::mount_into(View)` 换成 `Node::mount_into(Widget)`，机制不变；
// ③ 「段滚动区撑满剩余高度」在旧链路写 `style=[("flexgrow",1.0)]`，本栈在
//    `handle` 里对滚动视口直接置 `flex_grow`（滚动容器本身不接 grow 参数）。

///|
/// 全局 toast 推送钩子：main 创建 `toast_layer` 后注入，代码区「复制」回显用。
pub let code_toast : Ref[((String, @ui.SemanticType) -> Unit)?] = Ref(None)

///|
/// 一段演示：`name` 进页面顶部 segmented 标签列表（短名，页内唯一）；
/// title/desc/content/code 为该段正文四件套。
pub struct Section {
  name : String
  title : String
  desc : String
  content : Array[@core.Node]
  code : Array[String]
}

///|
/// 声明一段演示：`name` 是段列表短名（页内唯一），`title`/`desc`/`content`/`code`
/// 为该段正文四件套；实际节点由 `page` 统一装配。
pub fn section(
  name : String,
  title : String,
  desc : String,
  content : Array[@core.Node],
  code? : Array[String] = [],
) -> Section {
  { name, title, desc, content, code }
}

///|
/// 一页 = 顶部 segmented 段列表（超宽自动换行）+ 段正文栈；选中段填满剩余
/// 高度并自带滚动，其余段隐藏（不重建，滚动位置各自保留）。
pub fn page(secs : Array[Section]) -> @core.Node {
  let selected : @core.Store[String] = @core.Store::new(secs[0].name)
  let names : Array[String] = []
  for s in secs {
    names.push(s.name)
  }
  let strip = @ui.row([@ui.segmented(names, selected)], padding=10.0)
  let bodies : Array[@core.Node] = []
  for s in secs {
    bodies.push(section_body(s, selected))
  }
  @ui.col([strip, @ui.col(bodies, grow=1.0)], grow=1.0)
}

///|
/// 主区导航页：挂载后订阅导航状态做 `set_visible` 切换（侧栏菜单 /
/// segmented / 面包屑共享同一导航 Store）。页面内容**惰性挂载**：未选中过的
/// 页只留空壳，首次选中才把 content 挂进占位——15 页全量挂载（浏览器页含
/// WebKit 重控件）的启动开销不可行。
pub fn nav_page(
  name : String,
  selected : @core.Store[String],
  content : @core.Node,
) -> @core.Node {
  let mounted : Ref[Bool] = Ref(false)
  @ui.col([], grow=1.0, handle=fn(c) {
    fn ensure(s : String) -> Unit {
      if !mounted.val && s == name {
        mounted.val = true
        let _ = content.mount_into(c)
      }
      c.set_visible(s == name)
    }

    ensure(selected.get())
    selected.subscribe(ensure)
  })
}

///|
/// 选中段的正文：标题 + 演示 + 说明 + 代码（带复制行），内容超高段内滚动；
/// 容器随页面 `selected` 切换显隐。演示内容**惰性挂载**：未选中过的段只有
/// 标题/说明/代码骨架，首次选中才把 content 挂进占位容器——全量挂载意味着
/// 启动即建 111 段全部控件（图标墙页 803 个图标控件），debug 构建秒级；
/// 挂过之后保形，显隐/滚动位置语义不变。
fn section_body(s : Section, selected : @core.Store[String]) -> @core.Node {
  let mounted : Ref[Bool] = Ref(false)
  let holder = @ui.col([], row_gap=8.0, handle=fn(h) {
    fn ensure(name : String) -> Unit {
      if !mounted.val && name == s.name {
        mounted.val = true
        for c in s.content {
          let _ = c.mount_into(h)
        }
      }
    }

    ensure(selected.get())
    selected.subscribe(ensure)
  })
  let inner : Array[@core.Node] = [
    @ui.text(s.title, role=@ui.Section),
  ]
  if s.desc.length() > 0 {
    inner.push(@ui.text(s.desc, role=@ui.Secondary, max_width=900.0))
  }
  inner.push(holder)
  if s.code.length() > 0 {
    inner.push(code_copy_row(s.code))
    inner.push(@ui.code_view(s.code, lang="moonbit", line_numbers=true))
  }
  // 本容器是显隐切换对象；滚动视口在 handle 里撑满剩余高度
  @ui.col(
    [
      @ui.scroll_v(
        [@ui.col(inner, row_gap=6.0, padding=14.0)],
        @ui.ScrollState::new(),
        handle=fn(v) { v.node.set_flex_grow(1.0) },
      ),
    ],
    grow=1.0,
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
/// 代码区顶行：左「代码」小标，右「复制」按钮（toast 回显）。
fn code_copy_row(lines : Array[String]) -> @core.Node {
  @ui.row(
    [
      @ui.text("代码", role=@ui.Secondary),
      @ui.text("", role=@ui.Secondary, handle=fn(w) {
        w.node.set_flex_grow(1.0)
      }),
      @ui.button_t("复制", variant=@ui.Text, on_click=fn() {
        let _ = @sys.clipboard_set_text(lines.join("\n"))
        match code_toast.val {
          Some(push) => push("代码已复制 ✓", @ui.Success)
          None => ()
        }
      }),
    ],
    column_gap=8.0,
  )
}
