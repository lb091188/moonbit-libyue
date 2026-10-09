// 导航组件:side_menu / segmented / breadcrumb / pagination / steps / collapse / tabs / tree / transfer。

///|
fn side_menu_bg(act : Bool, hov : Bool) -> String {
  if act {
    @yue.theme_primary_light()
  } else if hov {
    @yue.theme_fill_hover()
  } else {
    ""
  }
}

///|
fn side_menu_fg(act : Bool, _hov : Bool) -> String {
  if act {
    @yue.theme_primary()
  } else {
    @yue.theme_text_primary()
  }
}

///|
/// 侧边导航菜单(对应 EP Menu):hover 浅灰、选中主题浅蓝底 + 主题色
/// 文字 + 左侧 3px 强调条,4px 圆角,文字垂直居中。icons 给「项文本 →
/// 图标」(缺省不画);selected 为共享状态,主区页面可订阅同一 Store
/// 做 set_visible 联动。
pub fn side_menu(
  items : Array[String],
  selected : @yue.Store[String],
  icons? : Array[(String, @icons.IconKind)] = [],
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  let width = 180.0
  let base : Array[(String, &@yue.StyVal)] = [
    ("width", width),
    ("padding", 6.0),
  ]
  for kv in style {
    base.push(kv)
  }
  // 用户覆盖 width 时项宽随 180 基准失准,故默认样式照旧、覆盖由
  // style 直接改外层;项宽跟随需要调用方自行对齐(内部项 168 固定)
  let nodes : Array[@yue.Node] = []
  for it in items {
    let mut kind : @icons.IconKind? = None
    for kv in icons {
      if kv.0 == it {
        kind = Some(kv.1)
      }
    }
    nodes.push(
      stateful_item(
        it,
        // 外层 vbox 有 padding 6,项宽 = 总宽 − 两侧 padding,防向右溢出
        [("width", width - 12.0), ("height", 40.0)],
        selected,
        side_menu_bg,
        side_menu_fg,
        pad_x=20.0,
        align_start=true,
        icon=kind,
        accent=true,
        rounded=true,
      ),
    )
  }
  @declarative.vbox(nodes, style=base, handle=fn(c) { @yue.set_panel_bg(c) })
}

///|
fn segmented_bg(act : Bool, hov : Bool) -> String {
  if act {
    @yue.theme_bg_panel()
  } else if hov {
    @yue.theme_border()
  } else {
    ""
  }
}

///|
fn segmented_fg(act : Bool, _hov : Bool) -> String {
  if act {
    @yue.theme_primary()
  } else {
    @yue.theme_text_regular()
  }
}

///|
/// 分段控制器 / 顶栏导航(对应 EP Segmented):选中白底 + 主题色文字,
/// hover 灰底,直角,文字垂直居中。
pub fn segmented(
  options : Array[String],
  selected : @yue.Store[String],
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  let items : Array[@yue.Node] = []
  for opt in options {
    items.push(
      stateful_item(
        opt,
        [("height", 30.0)],
        selected,
        segmented_bg,
        segmented_fg,
        pad_x=16.0,
      ),
    )
  }
  // 超宽自动换行(段多时一行放不下,如图标库 19 段)。要点:Yoga 的
  // flexShrink 默认 0(区别于 CSS 的 1),不显式收缩则内部 hbox 拿到
  // 内容全宽、wrap 永不触发;shrink 1 把宽度约束压进来才断行。
  // rowGap 是换行行距。段少的页面不触发换行,外观不变。
  let base : Array[(String, &@yue.StyVal)] = [
    ("padding", 2.0),
    ("rowGap", 4.0),
    ("flexShrink", 1.0),
    ("alignItems", "center"),
    ("flexWrap", "wrap"),
  ]
  for kv in style {
    base.push(kv)
  }
  @declarative.hbox(items, style=base, handle=fn(c) {
    @yue.bind_bg(c, fn() { @yue.theme_border() })
  })
}

///|
fn crumb_bg(_act : Bool, _hov : Bool) -> String {
  ""
}

///|
/// 面包屑(对应 EP Breadcrumb):层级随选中态联动——当前项深色不可点,
/// 其余灰色可点、hover 变主题色。
pub fn breadcrumb(
  items : Array[String],
  selected : @yue.Store[String],
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  let nodes : Array[@yue.Node] = []
  let mut i = 0
  for it in items {
    if i > 0 {
      nodes.push(
        stateful_item(
          "/",
          [("height", 24.0), ("marginRight", 4.0)],
          @yue.Store::new(""),
          crumb_bg,
          crumb_fg_static,
          font_size=13.0,
        ),
      )
    }
    nodes.push(
      stateful_item(
        it,
        [("height", 24.0), ("marginRight", 4.0)],
        selected,
        crumb_bg,
        crumb_fg,
        pad_x=4.0,
        font_size=13.0,
      ),
    )
    i = i + 1
  }
  let base : Array[(String, &@yue.StyVal)] = [("alignItems", "center")]
  for kv in style {
    base.push(kv)
  }
  @declarative.hbox(nodes, style=base)
}

///|
fn crumb_fg(_act : Bool, hov : Bool) -> String {
  if hov {
    @yue.theme_primary()
  } else {
    @yue.theme_text_secondary()
  }
}

///|
fn crumb_fg_static(_act : Bool, _hov : Bool) -> String {
  @yue.theme_text_secondary()
}

///|
/// 分页(EP Pagination):‹ 页码 ›,当前页主题色实底白字,
/// 悬停浅蓝,28×28 直角,文字垂直居中。current 为共享状态(从 1 开始),
/// 点击直接写源 Store,全部按钮同步高亮。
pub fn pagination(
  current : @yue.Store[Int],
  pages : Int,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("height", 30.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ]
      for kv in style {
        base.push(kv)
      }
      let row = @yue.themed_container(style=base)
      handle(row)
      fn add_btn(label : String, target : Int, is_page : Bool) -> Unit {
        let hover = Ref(false)
        let focused = Ref(false)
        let probe = @yue.AttributedText::new(label, wrap=false)
        let label_w = probe.get_bounds_for(10000.0, 100.0).width
        let b = @yue.themed_container(style=[
          ("width", 28.0),
          ("height", 28.0),
          ("marginRight", 4.0),
        ])
        let activate = fn() -> Unit {
          if is_page {
            current.set(target)
          } else {
            current.update(fn(n) {
              let m = n + target
              if m < 1 {
                1
              } else if m > pages {
                pages
              } else {
                m
              }
            })
          }
        }

        b.on_draw(fn(p) {
          let bd = @yue.ViewLike::get_bounds(b)
          let cur = current.get()
          let act = is_page && cur == target
          if act {
            p.set_fill_color(@yue.theme_primary())
            p.fill_rect(0.0, 0.0, bd.width, bd.height)
          } else if hover.val {
            p.set_fill_color(@yue.theme_primary_light())
            p.fill_rect(0.0, 0.0, bd.width, bd.height)
          }
          p.draw_text(
            label,
            (bd.width - label_w) / 2.0,
            0.0,
            bd.width,
            bd.height,
            valign=@yue.Center,
            color=if act { "#FFFFFF" } else { @yue.theme_text_regular() },
          )
          if focused.val {
            @yue.draw_focus_ring(p, bd.width, bd.height, color="#FFFFFF")
          }
        })
        @yue.View::set_cursor(b, @yue.hand())
        @yue.ViewLike::on_mouse_down(b, fn(e) {
          if e.button == 1 {
            @yue.ViewLike::focus(b)
            activate()
            true
          } else {
            false
          }
        })
        @yue.bind_focus(
          b,
          fn() { @yue.ViewLike::schedule_paint(b) },
          focused,
          activate,
        )
        @yue.ViewLike::on_mouse_enter(b, fn(_e) {
          hover.val = true
          @yue.ViewLike::schedule_paint(b)
        })
        @yue.ViewLike::on_mouse_leave(b, fn(_e) {
          hover.val = false
          @yue.ViewLike::schedule_paint(b)
        })
        current.subscribe(fn(_v) { @yue.ViewLike::schedule_paint(b) })
        row.add_child(b)
      }

      add_btn("‹", -1, false)
      let mut i = 1
      while i <= pages {
        add_btn(i.to_string(), i, true)
        i = i + 1
      }
      add_btn("›", 1, false)
      @yue.attach(parent, @yue.ViewLike::view(row))
      @yue.ViewLike::view(row)
    },
  }
}

///|
/// 步骤条(EP Steps):数字方块(完成浅蓝/当前实底/待办灰)+ 文字 + 连线。
pub fn steps(
  items : Array[String],
  current : @yue.Store[Int],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("height", 40.0),
        ("marginBottom", 12.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ]
      for kv in style {
        base.push(kv)
      }
      let row = @yue.themed_container(style=base)
      handle(row)
      let font = @yue.Font::new("Sans", 13.0)
      let n = items.length()
      // 单循环交错排布「连线 | 数字方块 | 文字」,文字紧随各自数字;
      // 数字居中走 draw_text 的 align 参数(测宽手动摆位在 Windows 偏左)
      for i in 0..<n {
        if i > 0 {
          let line = @yue.themed_container(style=[
            ("flex", 1.0),
            ("height", 2.0),
            ("marginRight", 6.0),
          ])
          let idx = i
          line.on_draw(fn(p) {
            let b = @yue.ViewLike::get_bounds(line)
            p.set_fill_color(
              if current.get() >= idx {
                @yue.theme_primary()
              } else {
                @yue.theme_border()
              },
            )
            p.fill_rect(0.0, 0.0, b.width, b.height)
          })
          row.add_child(line)
        }
        let num_txt = (i + 1).to_string()
        let bx = @yue.themed_container(style=[
          ("width", 24.0),
          ("height", 24.0),
          ("marginRight", 6.0),
        ])
        bx.on_draw(fn(p) {
          let b = @yue.ViewLike::get_bounds(bx)
          let cur = current.get()
          let st = if i < cur {
            0 // done
          } else if i == cur {
            1 // active
          } else {
            2 // todo
          }
          p.set_fill_color(
            match st {
              0 => @yue.theme_primary_light()
              1 => @yue.theme_primary()
              _ => @yue.theme_info_light()
            },
          )
          p.fill_rect(0.0, 0.0, b.width, b.height)
          p.draw_text(
            num_txt,
            0.0,
            0.0,
            b.width,
            b.height,
            align=@yue.Center,
            valign=@yue.Center,
            color=match st {
              0 => @yue.theme_primary()
              1 => "#FFFFFF"
              _ => @yue.theme_text_secondary()
            },
          )
        })
        current.subscribe(fn(_v) { @yue.ViewLike::schedule_paint(bx) })
        row.add_child(bx)
        // 文字色随「当前步」与主题双状态变化;set_color 后须同文 set_text
        // 触发重排(否则重绘仍用旧色,见 adaptation.md)
        let l = @yue.Label::new(items[i])
        @yue.ViewLike::set_font(l, font)
        fn apply_step_label() -> Unit {
          @yue.ViewLike::set_color(
            l,
            if i <= current.get() {
              @yue.theme_text_primary()
            } else {
              @yue.theme_text_secondary()
            },
          )
          l.set_text(l.get_text())
          @yue.ViewLike::schedule_paint(l)
        }

        apply_step_label()
        ignore(@yue.on_theme_change(apply_step_label))
        current.subscribe(fn(_v) { apply_step_label() })
        row.add_child(l)
      }
      @yue.attach(parent, @yue.ViewLike::view(row))
      @yue.ViewLike::view(row)
    },
  }
}

///|
/// 折叠面板(EP Collapse):点击标题行切换内容显隐,各面板独立开合,
/// 初始仅第一面板展开。
pub fn collapse(
  panels : Array[(String, Array[@yue.Node])],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("marginBottom", 12.0),
        ("flexDirection", "column"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let mut first = true
      for entry in panels {
        let open = Ref(first)
        first = false
        let head = @yue.themed_container(style=[
          ("height", 34.0),
          ("paddingLeft", 12.0),
          ("flexDirection", "row"),
          ("alignItems", "center"),
        ])
        @yue.bind_bg(head, fn() { @yue.theme_info_light() })
        let head_focused = Ref(false)
        head.on_draw(fn(p) {
          if head_focused.val {
            let b = @yue.ViewLike::get_bounds(head)
            @yue.draw_focus_ring(p, b.width, b.height)
          }
        })
        // 自绘折叠指示(V 形折线,不依赖字体字形)
        let arrow = @yue.themed_container(style=[
          ("width", 12.0),
          ("height", 12.0),
          ("marginRight", 5.0),
        ])
        arrow.on_draw(fn(p) {
          p.set_stroke_color(@yue.theme_primary())
          for off in [0.0, 0.6] {
            p.begin_path()
            if open.val {
              p.move_to(1.5 + off, 4.0)
              p.line_to(6.0 + off, 8.0)
              p.line_to(10.5 + off, 4.0)
            } else {
              p.move_to(4.0, 1.5 + off)
              p.line_to(8.0, 6.0 + off)
              p.line_to(4.0, 10.5 + off)
            }
            p.stroke()
          }
        })
        let title = @yue.Label::new(entry.0)
        fn apply_title_color() -> Unit {
          @yue.ViewLike::set_color(title, @yue.theme_text_primary())
          title.set_text(title.get_text())
        }

        apply_title_color()
        ignore(@yue.on_theme_change(apply_title_color))
        head.add_child(arrow)
        head.add_child(title)
        let body = @yue.themed_container(style=[
          ("padding", 10.0),
          ("flexDirection", "column"),
        ])
        @yue.set_panel_bg(body)
        for ch in entry.1 {
          ignore((ch.mount)(@yue.ViewLike::view(body)))
        }
        let apply = fn() -> Unit {
          @yue.ViewLike::set_visible(body, open.val)
          @yue.ViewLike::schedule_paint(arrow)
        }
        let toggle = fn() -> Unit {
          open.val = !open.val
          apply()
        }

        apply()
        @yue.View::set_cursor(head, @yue.hand())
        @yue.ViewLike::on_mouse_down(head, fn(e) {
          if e.button == 1 {
            @yue.ViewLike::focus(head)
            toggle()
            true
          } else {
            false
          }
        })
        @yue.bind_focus(
          head,
          fn() { @yue.ViewLike::schedule_paint(head) },
          head_focused,
          toggle,
        )
        let panel = @yue.themed_container(style=[
          ("marginBottom", 6.0),
          ("flexDirection", "column"),
        ])
        panel.add_child(head)
        panel.add_child(body)
        outer.add_child(panel)
      }
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 树节点数据。
pub(all) struct TreeNode {
  label : String
  children : Array[TreeNode]
}

///|
/// 树形控件(EP Tree):缩进层级 + 点击展开/折叠(有子节点时箭头指示)。
pub fn tree(
  root : Array[TreeNode],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("marginBottom", 10.0),
        ("paddingTop", 2.0),
        ("flexDirection", "column"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let font = @yue.Font::new("Sans", 13.0)
      // 实心小三角箭头(矢量自绘,不依赖字体字形,避免 Windows 端字符发虚)
      fn draw_caret(p : @yue.Painter, open : Bool) -> Unit {
        p.set_fill_color(@yue.theme_text_secondary())
        p.begin_path()
        if open {
          p.move_to(2.0, 3.5)
          p.line_to(8.0, 3.5)
          p.line_to(5.0, 7.5)
        } else {
          p.move_to(3.5, 2.0)
          p.line_to(7.5, 5.0)
          p.line_to(3.5, 8.0)
        }
        p.close_path()
        p.fill()
      }

      fn build(
        nodes : Array[TreeNode],
        level : Int,
        into : @yue.Container,
      ) -> Unit {
        for nd in nodes {
          let has_children = nd.children.length() > 0
          let open = Ref(false)
          let indent = level.to_double() * 18.0
          let row = @yue.themed_container(style=[
            ("height", 32.0),
            ("marginLeft", indent),
            ("flexDirection", "row"),
            ("alignItems", "center"),
          ])
          let arrow = @yue.themed_container(style=[
            ("width", 10.0),
            ("height", 10.0),
            ("marginRight", 3.0),
          ])
          arrow.on_draw(fn(p) { if has_children { draw_caret(p, open.val) } })
          let label = @yue.Label::new(" " + nd.label)
          @yue.ViewLike::set_font(label, font)
          @yue.bind_fg(label, fn() { @yue.theme_text_primary() })
          row.add_child(arrow)
          row.add_child(label)
          let kids = @yue.themed_container(style=[("flexDirection", "column")])
          @yue.ViewLike::set_visible(kids, false)
          if has_children {
            build(nd.children, level + 1, kids)
          }
          @yue.View::set_cursor(row, @yue.hand())
          @yue.ViewLike::on_mouse_down(row, fn(e) {
            if e.button == 1 && has_children {
              open.val = !open.val
              @yue.ViewLike::schedule_paint(arrow)
              @yue.ViewLike::set_visible(kids, open.val)
              true
            } else {
              false
            }
          })
          into.add_child(row)
          into.add_child(kids)
        }
      }

      build(root, 0, outer)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 穿梭框(EP Transfer):左右两列,点击行选中(实心方块标记),
/// 中间 ›/‹ 按钮把选中项在两列间移动。数据经双 Store 驱动。
pub fn transfer(
  left_items : @yue.Store[Array[String]],
  right_items : @yue.Store[Array[String]],
  width? : Double = 160.0,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("marginBottom", 10.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ]
      for kv in style {
        base.push(kv)
      }
      let row = @yue.themed_container(style=base)
      handle(row)
      let font = @yue.Font::new("Sans", 13.0)
      // 选中集合(按值),用 Ref 可变数组
      let left_sel : Ref[Array[String]] = Ref([])
      let right_sel : Ref[Array[String]] = Ref([])
      let left_box = @yue.themed_container(style=[
        ("width", width),
        ("flexDirection", "column"),
      ])
      let right_box = @yue.themed_container(style=[
        ("width", width),
        ("flexDirection", "column"),
      ])
      fn contains(arr : Array[String], s : String) -> Bool {
        for x in arr {
          if x == s {
            return true
          }
        }
        false
      }

      fn remove_one(arr : Array[String], s : String) -> Array[String] {
        let out : Array[String] = []
        let mut removed = false
        for x in arr {
          if !removed && x == s {
            removed = true
          } else {
            out.push(x)
          }
        }
        out
      }

      let left_rows : Ref[Array[@yue.View]] = Ref([])
      let right_rows : Ref[Array[@yue.View]] = Ref([])
      // 行级订阅的本代退订闭包:每次重建(移动项/改数据)前整袋退订,
      // 旧行随 remove_child_view 一起退场,死订阅不随移动次数累积
      let gen : Ref[Array[() -> Unit]] = Ref([])
      fn clear_list(
        box : @yue.Container,
        rows : Ref[Array[@yue.View]],
      ) -> Unit {
        for v in rows.val {
          ignore(box.remove_child_view(v))
        }
        rows.val = []
      }

      fn build_list(
        box : @yue.Container,
        items : @yue.Store[Array[String]],
        sel : Ref[Array[String]],
        rows : Ref[Array[@yue.View]],
      ) -> Unit {
        for it in items.get() {
          let it_ref = it
          let row = @yue.themed_container(style=[
            ("height", 26.0),
            ("paddingLeft", 8.0),
            ("flexDirection", "row"),
            ("alignItems", "center"),
          ])
          let mark = @yue.themed_container(style=[
            ("width", 10.0),
            ("height", 10.0),
            ("marginRight", 6.0),
          ])
          mark.on_draw(fn(p) {
            let is_sel = contains(sel.val, it_ref)
            p.set_stroke_color(
              if is_sel {
                @yue.theme_primary()
              } else {
                @yue.theme_border()
              },
            )
            p.stroke_rect(0.5, 0.5, 9.0, 9.0)
            if is_sel {
              p.set_fill_color(@yue.theme_primary())
              p.fill_rect(3.0, 3.0, 4.0, 4.0)
            }
          })
          let l = @yue.Label::new(it_ref)
          @yue.ViewLike::set_font(l, font)
          @yue.bind_fg(l, fn() { @yue.theme_text_regular() })
          row.add_child(mark)
          row.add_child(l)
          let mark_ref = mark
          @yue.View::set_cursor(row, @yue.hand())
          @yue.ViewLike::on_mouse_down(row, fn(e) {
            if e.button == 1 {
              if contains(sel.val, it_ref) {
                sel.val = remove_one(sel.val, it_ref)
              } else {
                let grown = sel.val.copy()
                grown.push(it_ref)
                sel.val = grown
              }
              @yue.ViewLike::schedule_paint(mark_ref)
              true
            } else {
              false
            }
          })
          box.add_child(row)
          rows.val.push(@yue.ViewLike::view(row))
        }
      }

      fn move_items(
        from : @yue.Store[Array[String]],
        to : @yue.Store[Array[String]],
        sel : Ref[Array[String]],
      ) -> Unit {
        let moving = sel.val
        let remain : Array[String] = []
        for x in from.get() {
          if !contains(moving, x) {
            remain.push(x)
          }
        }
        let merged = to.get().copy()
        for x in moving {
          merged.push(x)
        }
        from.set(remain)
        to.set(merged)
        sel.val = []
      }

      fn render_all() -> Unit {
        @yue.sub_bag_discard(gen.val)
        clear_list(left_box, left_rows)
        clear_list(right_box, right_rows)
        @yue.sub_bag_begin()
        build_list(left_box, left_items, left_sel, left_rows)
        build_list(right_box, right_items, right_sel, right_rows)
        gen.val = @yue.sub_bag_end()
      }

      left_items.subscribe(fn(_v) { render_all() })
      right_items.subscribe(fn(_v) { render_all() })
      fn mid_btn(to_right : Bool) -> Unit {
        let b = @yue.themed_container(style=[
          ("width", 32.0),
          ("height", 28.0),
          ("marginRight", 8.0),
          ("alignItems", "center"),
        ])
        @yue.bind_bg(b, fn() { @yue.theme_info_light() })
        b.on_draw(fn(p) {
          let bd = @yue.ViewLike::get_bounds(b)
          // ‹/› 矢量三角(字形图标跨平台发虚,GTK align 亦无效)
          if to_right {
            draw_glyph_right(
              p,
              bd.width / 2.0,
              bd.height / 2.0,
              4.0,
              @yue.theme_text_regular(),
            )
          } else {
            draw_glyph_left(
              p,
              bd.width / 2.0,
              bd.height / 2.0,
              4.0,
              @yue.theme_text_regular(),
            )
          }
        })
        @yue.View::set_cursor(b, @yue.hand())
        @yue.ViewLike::on_mouse_down(b, fn(e) {
          if e.button == 1 {
            if to_right {
              move_items(left_items, right_items, left_sel)
            } else {
              move_items(right_items, left_items, right_sel)
            }
            true
          } else {
            false
          }
        })
        row.add_child(b)
      }

      row.add_child(left_box)
      mid_btn(true)
      mid_btn(false)
      row.add_child(right_box)
      render_all()
      @yue.attach(parent, @yue.ViewLike::view(row))
      @yue.ViewLike::view(row)
    },
  }
}

///|
/// 页签(EP Tabs,顶部形态):页签头行(选中主题色文字 + 底部 2px 指示条,
/// 悬停变深)+ 内容区经 set_visible 切换。selected 为页序号 Store,默认
/// 内部建 0。
pub fn tabs_t(
  pages : Array[(String, @yue.Node)],
  selected? : @yue.Store[Int],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let sel = match selected {
        Some(s) => s
        None => @yue.Store::new(0)
      }
      let fnt = @yue.Font::new("Sans", 13.0)
      // 宽度随父容器拉伸(列容器默认 stretch),不写死:概览页要放
      // 全宽图表;grow+shrink 让页区在父容器有确定高度时填充/压缩
      // (Scroll 等无 measure 的叶节点靠这个拿到确定高度,否则塌缩归零)。
      // 不写 flex 简写:简写派生 basis 0,在 auto 高父链的内容测量轮里
      // 会被当成 0 高内容贡献,兄弟页显隐 dirty 祖先后整棵塌(native
      // v0.15.6-mbt.19 只修被清零节点自身);grow/shrink 不参与内容
      // 测量,basis 走 auto 语义,auto 父下按内容高
      let base : Array[(String, &@yue.StyVal)] = [
        ("flexgrow", 1.0),
        ("flexshrink", 1.0),
        ("marginBottom", 10.0),
        ("flexDirection", "column"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let head = @yue.themed_container(style=[
        ("height", 36.0),
        ("flexDirection", "row"),
      ])
      outer.add_child(head)
      let contents : Array[@yue.Container] = []
      let page_views : Array[@yue.View] = []
      let cur = Ref(sel.get())
      for i in 0..<pages.length() {
        let (title, node) = pages[i]
        let idx = i
        // 页签头:宽度自适应(测字宽 + 两侧 14px)
        let probe = @yue.AttributedText::new(title, wrap=false)
        probe.set_font(fnt)
        let tw = probe.get_bounds_for(10000.0, 100.0).width
        let tab = @yue.themed_container(style=[
          ("width", tw + 28.0),
          ("height", 36.0),
          ("marginRight", 8.0),
        ])
        let hover = Ref(false)
        tab.on_draw(fn(p) {
          let b = @yue.ViewLike::get_bounds(tab)
          let act = cur.val == idx
          let at = @yue.AttributedText::new(
            title,
            valign=@yue.Center,
            wrap=false,
          )
          at.set_font(fnt)
          at.set_color(
            if act {
              @yue.theme_primary()
            } else if hover.val {
              @yue.theme_text_regular()
            } else {
              @yue.theme_text_secondary()
            },
          )
          p.draw_attributed_text(at, 14.0, 0.0, b.width - 14.0, 36.0)
          if act {
            p.set_fill_color(@yue.theme_primary())
            p.fill_rect(0.0, 34.0, b.width, 2.0)
          }
        })
        @yue.View::set_cursor(tab, @yue.hand())
        @yue.ViewLike::on_mouse_down(tab, fn(e) {
          if e.button == 1 {
            sel.set(idx)
            true
          } else {
            false
          }
        })
        @yue.ViewLike::on_mouse_enter(tab, fn(_e) {
          hover.val = true
          @yue.ViewLike::schedule_paint(tab)
        })
        @yue.ViewLike::on_mouse_leave(tab, fn(_e) {
          hover.val = false
          @yue.ViewLike::schedule_paint(tab)
        })
        head.add_child(tab)
        // 内容页:flex 让页区填充 outer 的确定高度(Scroll / Table 等
        // 无 measure 叶节点依赖父级确定高度)。Windows 用显式 basis 0
        // (CSS 的 flex:1 1 0 语义)让高度只由 flex 分配决定,治其显隐
        // 切换的中间态压缩;其余平台用 grow/shrink 单写(basis 走 auto
        // 内容测量):纯简写在「父链已布局稳定后才挂载」的时序下(段/
        // 页惰性挂载),派生 basis 0 首轮即解析成 0 并进缓存,且初始
        // 可见页从未隐藏、不落 mbt.19 重显保护——初始页 0 高,切换一
        // 轮才恢复(实测);单写与 outer 同款两栖语义
        let page_c = @yue.themed_container(
          style=if @yue.platform() == "windows" {
            [("flex", 1.0), ("flexbasis", 0.0), ("flexDirection", "column")]
          } else {
            [
              ("flexgrow", 1.0),
              ("flexshrink", 1.0),
              ("flexDirection", "column"),
            ]
          },
        )
        @yue.ViewLike::set_visible(page_c, cur.val == idx)
        let page_v = (node.mount)(@yue.ViewLike::view(page_c))
        outer.add_child(page_c)
        contents.push(page_c)
        page_views.push(page_v)
      }
      sel.subscribe(fn(i) {
        cur.val = i
        // 先显示新页再隐藏旧页:反序会让 yoga 在「新页未显示、旧页已
        // 隐藏」的中间态把外层 flex 容器按 0 内容分配
        @yue.ViewLike::set_visible(contents[i], true)
        for j in 0..<contents.length() {
          if j != i {
            @yue.ViewLike::set_visible(contents[j], false)
          }
        }
        @yue.ViewLike::schedule_paint(head)
        @yue.refresh_layout(outer)
        // 页内容视图(on_draw 宿主)显式重绘一次,确保切换后当帧画出
        @yue.schedule_paint_view(page_views[i])
      })
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 分组侧边菜单(side_menu 的分组形态):组标题行自绘(次要色小字 +
/// 右侧折叠箭头),foldable 时可点收起/展开组内项(默认全展开,键盘
/// Enter/Space 同效);组内菜单项画法与 side_menu 一致(图标/强调条/
/// 圆角,选中/悬停联动 selected)。icons 给「项文本 → 图标」。
pub fn side_menu_sections(
  sections : Array[(String, Array[String])],
  selected : @yue.Store[String],
  icons? : Array[(String, @icons.IconKind)] = [],
  foldable? : Bool = true,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  let width = 180.0
  let base : Array[(String, &@yue.StyVal)] = [
    ("width", width),
    ("padding", 6.0),
    ("flexDirection", "column"),
  ]
  for kv in style {
    base.push(kv)
  }
  {
    mount: fn(parent) {
      let outer = @yue.themed_container(style=base)
      handle(outer)
      @yue.set_panel_bg(outer)
      let gfont = @yue.Font::new("Sans", 12.0)
      for (group, items) in sections {
        let open = Ref(true)
        // 组标题行:自绘(组名 + 右侧折叠箭头),不挂子件保证 hover 全区域
        let head = @yue.themed_container(style=[
          ("height", 30.0),
          ("width", width - 12.0),
        ])
        let head_hover = Ref(false)
        let head_focused = Ref(false)
        head.on_draw(fn(p) {
          let b = @yue.ViewLike::get_bounds(head)
          if foldable && head_hover.val {
            p.set_fill_color(@yue.theme_fill_hover())
            @yue.fill_round_rect(p, 0.0, 0.0, b.width, b.height, 4.0)
          }
          let at = @yue.AttributedText::new(
            group,
            valign=@yue.Center,
            wrap=false,
          )
          at.set_font(gfont)
          at.set_color(@yue.theme_text_secondary())
          p.draw_attributed_text(at, 14.0, 0.0, b.width, b.height)
          if foldable {
            @icons.draw_icon(
              p,
              if open.val {
                CaretDownSmall
              } else {
                CaretRightSmall
              },
              b.width - 14.0,
              b.height / 2.0,
              5.0,
              @yue.theme_text_secondary(),
            )
          }
          if head_focused.val {
            @yue.draw_focus_ring(p, b.width, b.height)
          }
        })
        // 组内项容器 + 项(收起即整容器隐藏,不占布局)
        let body = @yue.themed_container(style=[("flexDirection", "column")])
        for it in items {
          let mut kind : @icons.IconKind? = None
          for kv in icons {
            if kv.0 == it {
              kind = Some(kv.1)
            }
          }
          let item = stateful_item(
            it,
            // 项宽 = 总宽 − 两侧 padding,与标题行同宽防溢出
            [("width", width - 12.0), ("height", 36.0)],
            selected,
            side_menu_bg,
            side_menu_fg,
            pad_x=14.0,
            align_start=true,
            icon=kind,
            accent=true,
            rounded=true,
          )
          ignore((item.mount)(@yue.ViewLike::view(body)))
        }
        fn apply_fold() -> Unit {
          @yue.ViewLike::set_visible(body, open.val)
          @yue.ViewLike::schedule_paint(head)
        }

        if foldable {
          let toggle = fn() -> Unit {
            open.val = !open.val
            apply_fold()
          }

          apply_fold()
          @yue.View::set_cursor(head, @yue.hand())
          @yue.ViewLike::on_mouse_enter(head, fn(_e) {
            head_hover.val = true
            @yue.ViewLike::schedule_paint(head)
          })
          @yue.ViewLike::on_mouse_leave(head, fn(_e) {
            head_hover.val = false
            @yue.ViewLike::schedule_paint(head)
          })
          @yue.ViewLike::on_mouse_down(head, fn(e) {
            if e.button == 1 {
              @yue.ViewLike::focus(head)
              toggle()
              true
            } else {
              false
            }
          })
          @yue.bind_focus(
            head,
            fn() { @yue.ViewLike::schedule_paint(head) },
            head_focused,
            toggle,
          )
        }
        outer.add_child(head)
        outer.add_child(body)
      }
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}
