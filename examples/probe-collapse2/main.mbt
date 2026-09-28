// tabs_t 切页塌陷回归探针(showcase 主结构全复刻):
// hbox[sidebar, 多个兄弟 page(vbox flex:1, Store 驱动全量 set_visible 切换,
//   与 showcase page 函数同款 apply)]
// page1 = scroll(flex:1) → vbox(padding) → section vbox → 标题/描述
//   + tabs_a(页=裸 label,showcase 真实形态)
//   + tabs_b(页=vbox+flex:1「液位计」:flex:1 子的高=父分配高,
//     如实反映 tabs 页容器是否被压扁)
// 判定:五次采样 a0/a1/b0/b1 恒 18;b 组出现 1 即回归(tabs 页容器塌)。
// 覆盖导航(外层)与 tabs 切页(内层)双重显隐路径。侧栏仅布局摆设,
// 不复刻 button_t:窗口销毁期 GTK focus-out 回调会踩已析构资源,
// 与塌陷课题无关。
///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let nav = @yue.Store::new("p1")
  let sel_a = @yue.Store::new(0)
  let sel_b = @yue.Store::new(0)
  let labels : Array[@yue.Label] = []
  let boxes : Array[@yue.Container] = []
  let mk_label_page = fn(name : String) -> @yue.Node {
    @yue.label_t("裸\{name}页", role=@yue.Body, handle=fn(l) {
      labels.push(l)
    })
  }
  let mk_box_page = fn(name : String) -> @yue.Node {
    @yue.vbox(
      [@yue.label_t("盒\{name}页", role=@yue.Body)],
      style=[("flex", 1.0)],
      handle=fn(c) { boxes.push(c) },
    )
  }
  let tabs_a = @yue.tabs_t(
    [("A0", mk_label_page("A0")), ("A1", mk_label_page("A1"))],
    selected=sel_a,
  )
  let tabs_b = @yue.tabs_t(
    [("B0", mk_box_page("B0")), ("B1", mk_box_page("B1"))],
    selected=sel_b,
  )
  let section = @yue.vbox(
    [
      @yue.label_t("段落标题", role=@yue.Section),
      @yue.label_t("段落描述文字。", role=@yue.Body),
      tabs_a,
      tabs_b,
    ],
    style=[("marginBottom", 6.0)],
  )
  let content = @yue.vbox([section], style=[("padding", 14.0)])
  let scroll = @yue.scroll(content, style=[("flex", 1.0)])
  // showcase page 同款:flex:1 + selected Store 全量 set_visible
  let mk_page = fn(name : String, inner : @yue.Node) -> @yue.Node {
    @yue.vbox([inner], style=[("flex", 1.0)], handle=fn(c) {
      fn apply(s : String) -> Unit {
        c.set_visible(s == name)
      }
      apply(nav.get())
      nav.subscribe(apply)
    })
  }
  let page1 = mk_page("p1", scroll)
  let page2 = mk_page(
    "p2",
    @yue.vbox([@yue.label_t("另一页", role=@yue.Body)], style=[
      ("padding", 14.0),
    ]),
  )
  // 侧栏仅作布局摆设(不复刻 button_t:focus-out 在窗口销毁期的回调
  // 会踩已析构资源,与塌陷课题无关);导航切换走 nav Store 直设
  let sidebar = @yue.vbox(
    [
      @yue.label_t("菜单项一", role=@yue.Body),
      @yue.label_t("菜单项二", role=@yue.Body),
    ],
    style=[("width", 120.0), ("padding", 8.0)],
  )
  let _ = @yue.mount_window(
    [
      @yue.hbox([sidebar, page1, page2], style=[("flex", 1.0)], style_str=[
        ("alignItems", "stretch"),
      ]),
    ],
    center=true,
    on_close=fn(_w) { @yue.quit() },
    handle=fn(w) { w.set_content_size(640.0, 400.0) },
  )
  fn dump(tag : String) -> Unit {
    let h = fn(i : Int) -> Double {
      if i < labels.length() {
        labels[i].get_bounds().height
      } else {
        -1.0
      }
    }
    let hb = fn(i : Int) -> Double {
      if i < boxes.length() {
        boxes[i].get_bounds().height
      } else {
        -1.0
      }
    }
    println(
      "[\{tag}] a0=\{h(0)} a1=\{h(1)} | 液位计 b0=\{hb(0)} b1=\{hb(1)}",
    )
  }
  fn after(ms : Int, f : () -> Unit) -> Unit {
    let _ = @yue.set_timer(ms, fn() {
      f()
      false
    })
    ()
  }
  after(1200, fn() {
    dump("初始(p1)")
    nav.set("p2")
    after(900, fn() {
      dump("导航切到p2")
      nav.set("p1")
      after(900, fn() {
        dump("导航切回p1")
        sel_a.set(1)
        sel_b.set(1)
        after(900, fn() {
          dump("tabs切到页1")
          sel_a.set(0)
          sel_b.set(0)
          after(900, fn() {
            dump("tabs切回页0")
            after(600, fn() { @yue.quit() })
          })
        })
      })
    })
  })
  @yue.run()
}
