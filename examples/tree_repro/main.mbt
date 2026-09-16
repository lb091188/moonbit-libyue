fn main {
  if !@yue.initialize() {
    return
  }
  let title = @yue.label(
    "Tree 树形控件",
    style_str=[("color", "#356AA0")],
    style=[("marginBottom", 4.0)],
  )
  let desc = @yue.label(
    "缩进层级 + 点击展开/折叠(▸/▾)。",
    style_str=[("color", "#8A9199")],
    style=[("marginBottom", 10.0)],
  )
  let tree = @yue.tree([
    {
      label: "src",
      children: [
        { label: "components.mbt", children: [], },
        { label: "examples", children: [{ label: "components", children: [], }], },
      ],
    },
    { label: "docs", children: [{ label: "components-ui.md", children: [], }], },
  ])
  // 与真实 app 一致:tree 上一段是「position:relative + 内嵌 Scroll」的 Backtop 段
  let tall : Array[@yue.Node] = []
  for i in 0..<20 {
    tall.push(@yue.label_t("\{i + 1}. 向下滚动的内容行", role=@yue.Body))
  }
  let sc_handle : Ref[@yue.Scroll?] = Ref(None)
  let backtop_sec = @yue.vbox(
    [
      @yue.label_t("Backtop 返回顶部", role=@yue.Section),
      @yue.label("滚动下方区域", style=[("marginBottom", 10.0)]),
      @yue.vbox(
        [
          @yue.scroll(
            @yue.vbox(tall, style=[("padding", 8.0)]),
            style=[("flex", 1.0)],
            handle=fn(s) { sc_handle.val = Some(s) },
          ),
          @yue.hbox(
            [@yue.label("        "), @yue.backtop_t(fn() {
              match sc_handle.val {
                Some(s) => s.set_scroll_position(0.0, 0.0)
                None => ()
              }
            })],
            style=[("padding", 4.0)],
            style_str=[("alignItems", "center")],
          ),
        ],
        style=[("height", 150.0)],
        style_str=[("position", "relative"), ("flexDirection", "column")],
      ),
      @yue.separator(style=[("marginTop", 4.0), ("marginBottom", 20.0)]),
    ],
    style=[("marginBottom", 6.0)],
  )
  let sec = @yue.vbox([backtop_sec, title, desc, tree], style=[("marginBottom", 6.0)])
  let page = @yue.vbox([sec], style=[("padding", 14.0)], handle=fn(c) {
    // 模拟真实 app:页面初始隐藏,1 秒后切为可见(侧栏点击)
    c.set_visible(false)
    @yue.set_timer(1000, fn() {
      c.set_visible(true)
      false
    })
  })
  let root = @yue.mount([@yue.scroll(page, style=[("flex", 1.0)])])
  let win = @yue.Window::new()
  win.set_title("tree repro")
  win.set_content_size(300.0, 300.0)
  win.set_content(root)
  win.on_close(fn(_w) { @yue.quit() })
  win.activate()
  @yue.run()
}
