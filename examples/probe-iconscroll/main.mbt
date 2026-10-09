// 图标库页滚动探针(端到端):完整复刻 showcase 层级——根 hbox(flex1)
// → 页列 vbox(flex1) → nav_page 显隐互切(flex 简写) → page(flex 简写 +
// 段容器 grow/shrink) → 段外壳 set_visible + 惰性挂载 + scroll
// (grow/shrink) → 内容 vbox(padding14) → 图标墙。
// 病理(前序探针定案):Linux GTK 的 Scroll 滚动范围取 set_content 时刻
// 的内容自然高快照,惰性后挂内容不更新 → max_y=0 滚不动;修复 =
// 惰性挂载完成后调 Scroll::refresh_content_size 重写。本探针验证修复版
// 装配下切段、二轮显隐、切页回来后 max_y 恒为内容高−视口。

///|
/// 复刻 section_body 段装配(含修复:挂载后 refresh)
fn mk_sec(
  name : String,
  content : @yue.Node,
  sec_sel : @yue.Store[String],
  grab_scroll? : Bool = false,
  grab_holder? : Bool = false,
  grab_shell? : Bool = false,
  scroll_r? : Ref[@yue.Scroll?] = Ref(None),
  holder_r? : Ref[@yue.Container?] = Ref(None),
  shell_r? : Ref[@yue.Container?] = Ref(None),
) -> @yue.Node {
  let mounted = Ref(false)
  let scroll_ref : Ref[@yue.Scroll?] = Ref(None)
  let holder = @yue.vbox([], handle=fn(h) {
    fn ensure(n : String) -> Unit {
      if !mounted.val && n == name {
        mounted.val = true
        let _ = content.mount_into(h.view)
        match scroll_ref.val {
          Some(sc) => sc.refresh_content_size()
          None => ()
        }
      }
    }
    ensure(sec_sel.get())
    sec_sel.subscribe(ensure)
    if grab_holder {
      holder_r.val = Some(h)
    }
  })
  let inner : Array[@yue.Node] = [
    @components.label_t("段:\{name}", role=@components.Section, style=[("marginBottom", 8.0)]),
    holder,
    @components.label_t("说明文字占位", role=@components.Secondary, style=[
      ("marginTop", 10.0),
    ]),
  ]
  @yue.vbox(
    [
      @yue.scroll(
        @yue.vbox(inner, style=[("padding", 14.0)]),
        style=[("flexgrow", 1.0), ("flexshrink", 1.0)],
        handle=fn(s) {
          scroll_ref.val = Some(s)
          if grab_scroll {
            scroll_r.val = Some(s)
          }
        },
      ),
    ],
    style=[("flexgrow", 1.0), ("flexshrink", 1.0)],
    handle=fn(c) {
      fn apply(n : String) -> Unit {
        c.set_visible(n == name)
      }
      apply(sec_sel.get())
      sec_sel.subscribe(apply)
      if grab_shell {
        shell_r.val = Some(c)
      }
    },
  )
}

///|
/// 复刻 nav_page(flex 简写 + 显隐切换 + 首选挂载)
fn mk_nav(
  name : String,
  page_sel : @yue.Store[String],
  content : @yue.Node,
) -> @yue.Node {
  let mounted = Ref(false)
  @yue.vbox([], style=[("flex", 1.0)], handle=fn(c) {
    fn ensure(s : String) -> Unit {
      if !mounted.val && s == name {
        mounted.val = true
        let _ = content.mount_into(c.view)
      }
      c.set_visible(s == name)
    }
    ensure(page_sel.get())
    page_sel.subscribe(ensure)
  })
}

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let page_sel = @yue.Store::new("基础")
  let sec_sel = @yue.Store::new("短")
  let page_box_r : Ref[@yue.Container?] = Ref(None)
  let secs_box_r : Ref[@yue.Container?] = Ref(None)
  let sec_long_shell_r : Ref[@yue.Container?] = Ref(None)
  let scroll_r : Ref[@yue.Scroll?] = Ref(None)
  let holder_r : Ref[@yue.Container?] = Ref(None)
  let base_scroll_r : Ref[@yue.Scroll?] = Ref(None)

  // 长段内容:21 行 × 5 列 50px 图标(高约 1260,必超 720 视口)
  let wall_rows : Array[@yue.Node] = []
  for _r in 0..<21 {
    let items : Array[@yue.Node] = []
    for _c in 0..<5 {
      items.push(@icons.icon(@icons.Star, size=50.0))
    }
    wall_rows.push(@yue.hbox(items, style=[("gap", 10.0)]))
  }
  let long_wall = @yue.vbox(wall_rows, style=[("gap", 8.0)])
  // 基础页内容:40 行文本(超屏可滚对照组)
  let base_lines : Array[@yue.Node] = []
  for i in 0..<40 {
    base_lines.push(
      @components.label_t("基础页文本行 \{i}", role=@components.Secondary, style=[
        ("height", 28.0),
      ]),
    )
  }

  let icon_page = @yue.vbox(
    [
      @yue.hbox([@components.label_t("图标库")], style=[
        ("paddingLeft", 14.0),
        ("paddingTop", 10.0),
      ]),
      @yue.vbox(
        [
          mk_sec("短", @icons.icon(@icons.Star, size=50.0), sec_sel),
          mk_sec(
            "长",
            long_wall,
            sec_sel,
            grab_scroll=true,
            grab_holder=true,
            grab_shell=true,
            scroll_r~,
            holder_r~,
            shell_r=sec_long_shell_r,
          ),
        ],
        style=[
          ("flexgrow", 1.0),
          ("flexshrink", 1.0),
          ("flexDirection", "column"),
        ],
        handle=fn(c) { secs_box_r.val = Some(c) },
      ),
    ],
    style=[("flex", 1.0)],
    handle=fn(c) { page_box_r.val = Some(c) },
  )
  let base_page = @yue.vbox(
    [
      @yue.scroll(
        @yue.vbox(base_lines, style=[("padding", 14.0)]),
        style=[("flexgrow", 1.0), ("flexshrink", 1.0)],
        handle=fn(s) { base_scroll_r.val = Some(s) },
      ),
    ],
    style=[("flexgrow", 1.0), ("flexshrink", 1.0)],
  )

  let root = @yue.hbox(
    [
      @yue.vbox([], style=[("width", 180.0)]),
      @yue.vbox(
        [
          mk_nav("基础", page_sel, base_page),
          mk_nav("图标", page_sel, icon_page),
        ],
        style=[("flex", 1.0)],
      ),
    ],
    style=[("flex", 1.0), ("alignItems", "stretch")],
  )

  fn h(r : Ref[@yue.Container?]) -> Double {
    match r.val {
      Some(c) => c.get_bounds().height
      None => -1.0
    }
  }
  fn dump(tag : String) -> Unit {
    let sv = match scroll_r.val {
      Some(s) => s.get_bounds().height
      None => -1.0
    }
    let maxy = match scroll_r.val {
      Some(s) => s.get_max_scroll_position_y()
      None => -1.0
    }
    let base_maxy = match base_scroll_r.val {
      Some(s) => s.get_max_scroll_position_y()
      None => -1.0
    }
    println(
      "[\{tag}] page=\{h(page_box_r)} 段容器=\{h(secs_box_r)} 长段外壳=\{h(sec_long_shell_r)} 长段scroll视口=\{sv} 长段holder=\{h(holder_r)} 长段max_y=\{maxy} | 基础页max_y=\{base_maxy}",
    )
  }

  let window = @yue.mount_window(
    [root],
    title="图标库滚动探针(端到端)",
    size=Some((1280.0, 720.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  window.activate()
  @yue.set_timer(600, fn() {
    page_sel.set("图标")
    @yue.set_timer(700, fn() {
      dump("切到图标页·短段")
      sec_sel.set("长")
      @yue.set_timer(700, fn() {
        dump("切到长段(首次挂载)")
        sec_sel.set("短")
        @yue.set_timer(600, fn() {
          sec_sel.set("长")
          @yue.set_timer(700, fn() {
            dump("长段二轮显隐后")
            page_sel.set("基础")
            @yue.set_timer(600, fn() {
              dump("切回基础页")
              @yue.set_timer(400, fn() {
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
      false
    })
    false
  })
  @yue.run()
}
