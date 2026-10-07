// Linux 切页塌陷复现探针(a900a4d 定位的最小结构,不经 tabs_t):
// scroll(flex1,确定高) → content(auto 列) → outer(auto 高, marginBottom 10)
//   → head(36) + page0/page1(flex1, 内部撑 20 高,显隐切页)
// 健康表现:outer 高恒为 head+页+margin(≈66);塌陷时 outer 掉到≈10
// (只剩 margin,分配值塌、内容测量不塌)。
// 定时采样 get_bounds:挂载 1.2s 测初始 → 先显新页后隐旧页(与 tabs_t
// 同序)→ 再 1.2s 复测 → 反向切回 → 复测 → 退出。

///|
fn mk_page(name : String, explicit_basis : Bool) -> @yue.Container {
  let page = @yue.Container::new()
  page.set_style("flex", 1.0)
  if explicit_basis {
    page.set_style("flexbasis", 0.0) // tabs_t page_c 同款:显式 basis 0
  }
  page.set_style_str("flexDirection", "column")
  let body = @yue.Container::new()
  body.set_style("height", 20.0)
  body.set_style("marginBottom", 2.0)
  let tag = @yue.Label::new(name)
  body.add_child(tag)
  page.add_child(body)
  page
}

///|
fn dump3(
  tag : String,
  outer : @yue.Container,
  head : @yue.Container,
  content : @yue.Container,
  p0 : @yue.Container,
  p1 : @yue.Container,
  p2 : @yue.Container,
) -> Unit {
  let o = outer.get_bounds()
  let h = head.get_bounds()
  let c = content.get_bounds()
  let b0 = p0.get_bounds()
  let b1 = p1.get_bounds()
  let b2 = p2.get_bounds()
  println(
    "[\{tag}] outer=\{o.height} head=\{h.height} content=\{c.height} p0=\{b0.height} p1=\{b1.height} p2=\{b2.height}",
  )
}

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_content_size(400.0, 300.0)
  let page_box = @yue.Container::new()
  page_box.set_style_str("flexDirection", "column")
  let scroll = @yue.Scroll::new()
  scroll.set_style("flex", 1.0)
  let content = @yue.Container::new()
  content.set_style_str("flexDirection", "column")
  let outer = @yue.Container::new()
  outer.set_style_str("flexDirection", "column")
  outer.set_style("marginBottom", 10.0)
  let head = @yue.Container::new()
  head.set_style("height", 36.0)
  let p0 = mk_page("page0", false)
  let p1 = mk_page("page1", false)
  p1.set_visible(false)
  let p2 = mk_page("page2", true)
  p2.set_visible(false)
  outer.add_child(head)
  outer.add_child(p0)
  outer.add_child(p1)
  outer.add_child(p2)
  content.add_child(outer)
  scroll.set_content(content)
  page_box.add_child(scroll)
  window.set_content(page_box)
  window.center()
  window.on_close(fn(_w) { @yue.quit() })
  window.activate()
  @yue.set_timer(1200, fn() {
    dump3("初始", outer, head, content, p0, p1, p2)
    p1.set_visible(true)
    p0.set_visible(false)
    @yue.set_timer(1200, fn() {
      dump3("切到p1", outer, head, content, p0, p1, p2)
      p2.set_visible(true)
      p1.set_visible(false)
      @yue.set_timer(1200, fn() {
        dump3("切到p2", outer, head, content, p0, p1, p2)
        p0.set_visible(true)
        p2.set_visible(false)
        @yue.set_timer(1200, fn() {
          dump3("切回p0", outer, head, content, p0, p1, p2)
          p0.set_visible(true)
          @yue.set_timer(600, fn() {
            @yue.quit()
            false
          })
          false
        })
        false
      })
      false
    })
    false
  })
  @yue.run()
}
