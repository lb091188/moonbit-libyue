// 展示组件:tag / badge / card / avatar / alert / timeline / descriptions / result / empty / statistic / progress_line / divider / carousel。

///|
/// 标签(对应 EP Tag 的浅色变体):类型浅底 + 同族深字,直角,
/// 宽度按文本自适应,文字垂直居中。
pub fn tag_of_type(
  text : String,
  t : SemanticType,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let font = @yue.Font::new("Sans", 12.0)
      let probe = @yue.AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", text_w + 16.0),
        ("height", 24.0),
        ("marginRight", 8.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let c = @yue.themed_container(style=base)
      handle(c)
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        p.set_fill_color(type_light_color(t))
        p.fill_rect(0.0, 0.0, b.width, b.height)
        // 水平手动居中(GTK 端 DrawAttributedText 不实现水平 align)
        p.draw_text(
          text,
          (b.width - text_w) / 2.0,
          0.0,
          b.width,
          b.height,
          valign=@yue.Center,
          color=type_color(t),
        )
      })
      @yue.attach(parent, @yue.ViewLike::view(c))
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 兼容旧用法的彩色实底标签(自定颜色)。
pub fn tag(
  text : String,
  color : String,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let font = @yue.Font::new("Sans", 12.0)
      let probe = @yue.AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", text_w + 16.0),
        ("height", 24.0),
        ("marginRight", 8.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let c = @yue.themed_container(style=base)
      handle(c)
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        p.set_fill_color(color)
        p.fill_rect(0.0, 0.0, b.width, b.height)
        p.draw_text(
          text,
          (b.width - text_w) / 2.0,
          0.0,
          b.width,
          b.height,
          valign=@yue.Center,
          color="#FFFFFF",
        )
      })
      @yue.attach(parent, @yue.ViewLike::view(c))
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 数字角标(对应 EP Badge 的数字形态):红底白字小块,宽度自适应。
/// 语义红 draw 现取跟随主题(不复用 tag——其 color 参数为固定色语义)。
pub fn badge_count(
  count : Int,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  let text = count.to_string()
  {
    mount: fn(parent) {
      let font = @yue.Font::new("Sans", 12.0)
      let probe = @yue.AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", text_w + 14.0),
        ("height", 18.0),
        ("marginRight", 8.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let c = @yue.themed_container(style=base)
      handle(c)
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        p.set_fill_color(@yue.theme_danger())
        p.fill_rect(0.0, 0.0, b.width, b.height)
        p.draw_text(
          text,
          (b.width - text_w) / 2.0,
          0.0,
          b.width,
          b.height,
          valign=@yue.Center,
          color="#FFFFFF",
        )
      })
      @yue.attach(parent, @yue.ViewLike::view(c))
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 提示横幅(对应 EP Alert):类型浅底 + 左侧 4px 色条 + 同族深字,
/// 全宽,文字垂直居中。
pub fn alert(
  text : String,
  t : SemanticType,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("height", 40.0),
        ("marginBottom", 10.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = @yue.themed_container(style=base)
      handle(v)
      v.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(v)
        let w = b.width
        let h = b.height
        p.set_fill_color(type_light_color(t))
        p.fill_rect(0.0, 0.0, w, h)
        p.set_fill_color(type_color(t))
        p.fill_rect(0.0, 0.0, 4.0, h)
        p.draw_text(
          text,
          16.0,
          0.0,
          w,
          h,
          align=@yue.Start,
          valign=@yue.Center,
          color=type_color(t),
        )
      })
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}

///|
/// 卡片(对应 EP Card):白底 + 边框,标题栏(加粗、底部分隔线),
/// 内容区从标题栏下方开始。children 经内层容器挂载,自动留出标题高度。
pub fn card(
  title : String,
  children : Array[@yue.Node],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let head_h = 40.0
      let base : Array[(String, &@yue.StyVal)] = [("height", 160.0)]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      outer.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(outer)
        let w = b.width
        let h = b.height
        // 边框
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(0.0, 0.0, w, h)
        // 标题栏底部分隔线
        p.set_fill_color(@yue.theme_border())
        p.fill_rect(0.0, head_h, w, 1.0)
      })
      // 标题(加粗,垂直居中,左内边距 16;文字为自绘,padding 样式
      // 只影响子项排列,起点须在 draw 坐标里给)
      let title_at = @yue.AttributedText::new(
        title,
        valign=@yue.Center,
        wrap=false,
      )
      title_at.set_font(@yue.Font::new("Sans", 14.0, weight=@yue.Bold))
      title_at.set_color(@yue.theme_text_primary())
      let title = @yue.themed_container(style=[("height", head_h)])
      fn apply_title_color() -> Unit {
        title_at.set_color(@yue.theme_text_primary())
        title_at.set_text(title_at.get_text())
        @yue.ViewLike::schedule_paint(title)
      }

      apply_title_color()
      ignore(@yue.on_theme_change(apply_title_color))
      title.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(title)
        p.draw_attributed_text(title_at, 16.0, 0.0, b.width - 16.0, head_h)
      })
      outer.add_child(title)
      // 内容区
      let body = @yue.themed_container(style=[
        ("padding", 14.0),
        ("flexDirection", "column"),
      ])
      for ch in children {
        ignore((ch.mount)(@yue.ViewLike::view(body)))
      }
      outer.add_child(body)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 头像:方形实底 + 白字居中(EP Avatar 的 square 形态)。
pub fn avatar(
  letter : String,
  color : String,
  size? : Double = 36.0,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", size),
        ("height", size),
        ("marginRight", 8.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let c = @yue.themed_container(style=base)
      handle(c)
      @yue.ViewLike::set_background_color(c, color)
      // 字母水平居中:GTK 端 align 无效,mount 时测宽手动摆位
      let letter_probe = @yue.AttributedText::new(letter, wrap=false)
      letter_probe.set_font(@yue.Font::new("Sans", size / 2.2))
      let letter_w = letter_probe.get_bounds_for(10000.0, 1000.0).width
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        p.draw_text(
          letter,
          (b.width - letter_w) / 2.0,
          0.0,
          b.width,
          b.height,
          valign=@yue.Center,
          color="#FFFFFF",
        )
      })
      @yue.attach(parent, @yue.ViewLike::view(c))
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 圆点徽标(EP Badge 的 dot 形态):8×8 色点。
pub fn badge_dot(
  color? : String = "",
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  let base : Array[(String, &@yue.StyVal)] = [
    ("width", 8.0),
    ("height", 8.0),
    ("marginRight", 6.0),
  ]
  for kv in style {
    base.push(kv)
  }
  @declarative.container(
    on_draw=fn(p) {
      // 空串=默认语义红,draw 现取跟随主题;显式传色则恒定
      p.set_fill_color(if color == "" { @yue.theme_danger() } else { color })
      p.fill_rect(0.0, 0.0, 10000.0, 10000.0)
    },
    style=base,
  )
}

///|
/// 可关闭横幅:alert + 右侧关闭钮(点击整条隐藏)。
pub fn alert_closeable(
  text : String,
  t : SemanticType,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("height", 40.0),
        ("marginBottom", 10.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = @yue.themed_container(style=base)
      handle(v)
      @yue.bind_bg(v, fn() { type_light_color(t) })
      let label = @yue.Label::new("  " + text)
      @yue.bind_fg(label, fn() { type_color(t) })
      v.add_child(label)
      // 弹性空白把关闭钮推到右端
      let spacer = @yue.themed_container(style=[("flex", 1.0), ("height", 1.0)])
      v.add_child(spacer)
      let close = @yue.themed_container(style=[
        ("width", 32.0),
        ("height", 40.0),
      ])
      let hover = Ref(false)
      let close_focused = Ref(false)
      let close_it = fn() -> Unit { @yue.ViewLike::set_visible(v, false) }

      close.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(close)
        let c = if hover.val {
          type_color(t)
        } else {
          @yue.theme_text_secondary()
        }
        draw_clear_x(p, b.width / 2.0, b.height / 2.0, color=c)
        if close_focused.val {
          @yue.draw_focus_ring(p, b.width, b.height)
        }
      })
      @yue.View::set_cursor(close, @yue.hand())
      @yue.ViewLike::on_mouse_down(close, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(close)
          close_it()
          true
        } else {
          false
        }
      })
      @yue.bind_focus(
        close,
        fn() { @yue.ViewLike::schedule_paint(close) },
        close_focused,
        close_it,
      )
      @yue.ViewLike::on_mouse_enter(close, fn(_e) {
        hover.val = true
        @yue.ViewLike::schedule_paint(close)
      })
      @yue.ViewLike::on_mouse_leave(close, fn(_e) {
        hover.val = false
        @yue.ViewLike::schedule_paint(close)
      })
      v.add_child(close)
      // 让关闭钮靠右:中间垫一个弹性空白
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}

///|
/// 时间线(EP Timeline):左列色点+竖线,右列标题+描述。item 高固定 56。
pub fn timeline(
  items : Array[(String, String, SemanticType)],
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
      let n = items.length()
      let mut i = 0
      for entry in items {
        let is_last = i == n - 1
        let row = @yue.themed_container(style=[
          ("height", 56.0),
          ("flexDirection", "row"),
        ])
        let node_col = @yue.themed_container(style=[
          ("width", 20.0),
          ("height", 56.0),
        ])
        let is_first = i == 0
        node_col.on_draw(fn(p) {
          // 竖线:首行从点心起、末行到点心止,中间整行贯通(节点色块居中)
          let b = @yue.ViewLike::get_bounds(node_col)
          let cy = b.height / 2.0
          let top = if is_first { cy } else { 0.0 }
          let bottom = if is_last { cy } else { b.height }
          if bottom > top {
            p.set_fill_color(@yue.theme_border())
            p.fill_rect(9.0, top, 2.0, bottom - top)
          }
          p.set_fill_color(type_color(entry.2))
          p.fill_rect(5.0, b.height / 2.0 - 5.0, 10.0, 10.0)
        })
        let text_col = @yue.themed_container(style=[
          ("paddingLeft", 8.0),
          ("flex", 1.0),
          ("flexDirection", "column"),
        ])
        let title = @yue.Label::new(entry.0)
        fn apply_title_color() -> Unit {
          @yue.ViewLike::set_color(title, @yue.theme_text_primary())
          title.set_text(title.get_text())
        }

        apply_title_color()
        ignore(@yue.on_theme_change(apply_title_color))
        title.set_align(@yue.Start)
        let desc = @yue.Label::new(entry.1)
        @yue.bind_fg(desc, fn() { @yue.theme_text_secondary() })
        desc.set_align(@yue.Start)
        text_col.add_child(title)
        text_col.add_child(desc)
        row.add_child(node_col)
        row.add_child(text_col)
        outer.add_child(row)
        i = i + 1
      }
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 描述列表(EP Descriptions):键灰值深的两列网格。
pub fn descriptions(
  pairs : Array[(String, String)],
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
      for kv in pairs {
        let row = @yue.themed_container(style=[
          ("height", 26.0),
          ("flexDirection", "row"),
          ("alignItems", "center"),
        ])
        let k = @yue.Label::new(kv.0)
        @yue.bind_fg(k, fn() { @yue.theme_text_secondary() })
        k.set_align(@yue.Start)
        let v = @yue.Label::new(kv.1)
        @yue.bind_fg(v, fn() { @yue.theme_text_primary() })
        v.set_align(@yue.Start)
        let key_wrap = @yue.themed_container(style=[("width", 110.0)])
        key_wrap.add_child(k)
        row.add_child(key_wrap)
        row.add_child(v)
        outer.add_child(row)
      }
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 结果页(EP Result):大色块符号 + 标题 + 描述 + 自定义按钮区。
pub fn result(
  t : SemanticType,
  title : String,
  desc : String,
  children : Array[@yue.Node],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      // 图标(76+16) + 标题 30 + 描述 24 + 按钮区(8+按钮高约 32)+ 底部留白
      let base : Array[(String, &@yue.StyVal)] = [
        ("height", 208.0),
        ("marginBottom", 12.0),
        ("flexDirection", "column"),
        ("alignItems", "center"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let icon = @yue.themed_container(style=[
        ("width", 76.0),
        ("height", 76.0),
        ("marginTop", 16.0),
      ])

      @yue.bind_bg(icon, fn() { type_light_color(t) })
      // 符号用 Painter 矢量路径自绘(✓/✕/!):不测宽、不摆位,三平台
      // 一致(Windows 的 AttributedText 测宽含内边距,手动居中必偏左,
      // 见 adaptation.md);主题切换重取色显式重绘
      icon.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(icon)
        let cx = b.width / 2.0
        let cy = b.height / 2.0
        let s = 20.0
        p.set_stroke_color(type_color(t))
        p.begin_path()
        match t {
          Success => {
            p.move_to(cx - s, cy + s * 0.1)
            p.line_to(cx - s * 0.2, cy + s * 0.7)
            p.line_to(cx + s, cy - s * 0.6)
            p.stroke()
          }
          Danger => {
            p.move_to(cx - s * 0.7, cy - s * 0.7)
            p.line_to(cx + s * 0.7, cy + s * 0.7)
            p.move_to(cx + s * 0.7, cy - s * 0.7)
            p.line_to(cx - s * 0.7, cy + s * 0.7)
            p.stroke()
          }
          _ => {
            p.set_fill_color(type_color(t))
            p.fill_rect(cx - s * 0.14, cy - s, s * 0.28, s * 1.25)
            p.fill_rect(cx - s * 0.14, cy + s * 0.5, s * 0.28, s * 0.28)
          }
        }
      })
      ignore(@yue.on_theme_change(fn() { @yue.ViewLike::schedule_paint(icon) }))
      let big = @yue.themed_container(style=[
        ("height", 30.0),
        ("alignItems", "center"),
      ])
      let t1 = @yue.Label::new(title)
      @yue.ViewLike::set_font(
        t1,
        @yue.Font::new("Sans", 18.0, weight=@yue.SemiBold),
      )
      @yue.bind_fg(t1, fn() { @yue.theme_text_primary() })
      big.add_child(t1)
      let sub = @yue.themed_container(style=[
        ("height", 24.0),
        ("alignItems", "center"),
      ])
      let t2 = @yue.Label::new(desc)
      @yue.bind_fg(t2, fn() { @yue.theme_text_secondary() })
      sub.add_child(t2)
      let btns = @yue.themed_container(style=[
        ("marginTop", 8.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ])
      for ch in children {
        ignore((ch.mount)(@yue.ViewLike::view(btns)))
      }
      outer.add_child(icon)
      outer.add_child(big)
      outer.add_child(sub)
      outer.add_child(btns)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 空状态(EP Empty):灰块占位 + 居中说明。
pub fn empty(
  desc : String,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("height", 140.0),
        ("marginBottom", 12.0),
        ("flexDirection", "column"),
        ("alignItems", "center"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let box = @yue.themed_container(style=[
        ("width", 96.0),
        ("height", 88.0),
        ("marginTop", 12.0),
      ])
      // 自绘简约空箱:盖 + 盒体,不依赖字体符号
      box.on_draw(fn(p) {
        // 不读运行时 bounds:容器宽固定 96,首绘若布局未就绪 cx=0,
        // 图案画到负坐标被裁且无重绘时机("偶尔不显示"根因)
        let cx = 48.0
        // 盒体
        p.set_fill_color(@yue.theme_fill_hover())
        p.fill_rect(cx - 26.0, 36.0, 52.0, 34.0)
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(cx - 26.0, 36.0, 52.0, 34.0)
        // 盖(比体宽,略上叠)
        p.set_fill_color(@yue.theme_info_light())
        p.fill_rect(cx - 34.0, 22.0, 68.0, 14.0)
        p.stroke_rect(cx - 34.0, 22.0, 68.0, 14.0)
      })
      let cap = @yue.themed_container(style=[
        ("height", 26.0),
        ("marginTop", 6.0),
        ("alignItems", "center"),
      ])
      let l = @yue.Label::new(desc)
      @yue.bind_fg(l, fn() { @yue.theme_text_secondary() })
      cap.add_child(l)
      outer.add_child(box)
      outer.add_child(cap)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 数值统计(EP Statistic):大号数值(响应式)+ 灰色标题。
pub fn statistic(
  title : String,
  value : @yue.Store[String],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("marginRight", 24.0),
        ("flexDirection", "column"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let num = @yue.Label::new(value.get())
      @yue.ViewLike::set_font(
        num,
        @yue.Font::new("Sans", 24.0, weight=@yue.SemiBold),
      )
      @yue.bind_fg(num, fn() { @yue.theme_text_primary() })
      let cap = @yue.Label::new(title)
      @yue.bind_fg(cap, fn() { @yue.theme_text_secondary() })
      // set_text 只标脏不重排,变长截断,须补强制重排
      value.subscribe(fn(v) {
        num.set_text(v)
        @yue.ViewLike::update_layout(num)
      })
      outer.add_child(num)
      outer.add_child(cap)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 线性进度条(EP Progress):背景浅灰轨道 + 主题色填充,
/// value 为 Store(0..1),变化自动重绘。
pub fn progress_line(
  value : @yue.Store[Double],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      // grow/shrink 单写不写 flex 简写:column 父(auto 高链)下简写
      // 派生 basis 0 首轮解析成 0 即塌(height 被盖),惰性挂载时序必现
      let base : Array[(String, &@yue.StyVal)] = [
        ("flexgrow", 1.0),
        ("flexshrink", 1.0),
        ("height", 8.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = @yue.themed_container(style=base)
      handle(v)
      @yue.bind_bg(v, fn() { @yue.theme_info_light() })
      v.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(v)
        let frac = value.get()
        if frac > 0.0 {
          p.set_fill_color(@yue.theme_primary())
          p.fill_rect(0.0, 0.0, b.width * frac, b.height)
        }
      })
      value.subscribe(fn(_x) { @yue.ViewLike::schedule_paint(v) })
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}

///|
/// 分隔线(EP Divider):水平(默认,height 1px,宽 flex)或竖直(宽 1px,
/// 高随父容器);spacing 为两侧留白。底色挂载时读主题(重建界面生效)。
pub fn divider(
  vertical? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = if vertical {
        [("width", 1.0), ("marginLeft", 10.0), ("marginRight", 10.0)]
      } else {
        [("height", 1.0), ("marginTop", 10.0), ("marginBottom", 10.0)]
      }
      if !vertical {
        // 水平分隔线在 column 父(auto 高链)下:grow/shrink 单写,
        // flex 简写派生 basis 0 会盖掉 height 1 塌成 0 高
        base.push(("flexgrow", 1.0))
        base.push(("flexshrink", 1.0))
      }
      for kv in style {
        base.push(kv)
      }
      let c = @yue.themed_container(style=base)
      handle(c)
      @yue.bind_bg(c, fn() { @yue.theme_border() })
      @yue.attach(parent, @yue.ViewLike::view(c))
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 轮播句柄：持自动轮播开关与已排下的超时 id（stop 取消待触发那次，
/// 自排链随之终止）。与 video_view 的 VidHandle 同款「挂载定时器的
/// 回收通道」。
pub(all) struct CarouselHandle {
  running : Ref[Bool]
  timer : Ref[Int]
}

///|
/// 建轮播句柄（默认自动轮播中）。
pub fn CarouselHandle::make() -> CarouselHandle {
  { running: Ref(true), timer: Ref(0), }
}

///|
/// 轮播是否还在自动切换（手动箭头/指示点不受影响）。
pub fn CarouselHandle::is_running(self : CarouselHandle) -> Bool {
  self.running.val
}

///|
/// 停止自动轮播（不可恢复；手动切换仍可用）。卸载轮播前必须调用：
/// 自排的超时链不认视图已移除，不退就会继续对已销毁的子树空转。
pub fn carousel_stop(handle : CarouselHandle) -> Unit {
  handle.running.val = false
  let id = handle.timer.val
  if id != 0 {
    @yue.clear_timeout(id)
    handle.timer.val = 0
  }
}

///|
/// 轮播(EP Carousel):面板序列 + 左右箭头 + 底部指示点,自动轮播
/// (interval_ms > 0 时,interval 毫秒一切,悬停暂停),点击箭头/指示点
/// 手动切换。面板为任意 Node,统一按给定宽高展示。
/// 自动轮播是自排的超时链,回收经 [carousel_stop](rotation):卸载
/// 轮播前必须先 stop,否则链继续对已移除的视图空转。
pub fn carousel_t(
  pages : Array[@yue.Node],
  width? : Double = 360.0,
  height? : Double = 180.0,
  interval_ms? : Int = 3000,
  rotation? : CarouselHandle = CarouselHandle::make(),
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let n = pages.length()
      let cur = Ref(0)
      let paused = Ref(false)
      let dots : Array[@yue.Container] = []
      let panels : Array[@yue.Container] = []
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", width),
        ("height", height + 24.0),
        ("marginBottom", 10.0),
        ("flexDirection", "column"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let stage = @yue.themed_container(style=[
        ("width", width),
        ("height", height),
        ("flexDirection", "column"),
      ])
      // 切页:越界回绕
      fn do_switch(i : Int) -> Unit {
        let idx = if i < 0 { n - 1 } else if i >= n { 0 } else { i }
        let prev = cur.val
        cur.val = idx
        if prev != idx {
          @yue.ViewLike::set_visible(panels[prev], false)
          @yue.ViewLike::schedule_paint(dots[prev])
          @yue.ViewLike::set_visible(panels[idx], true)
          @yue.ViewLike::schedule_paint(dots[idx])
        }
      }

      // 面板与指示点先建好,切换只动 set_visible
      for i in 0..<n {
        // 面板填满舞台(grow 拉高 + stretch 拉宽):固定宽会横向溢出
        // 舞台(两侧箭头各占 24px),盖住右侧切换箭头的事件窗口。
        // grow/shrink 单写:column 舞台 auto 高链下简写派生 basis 0 塌陷
        let pc = @yue.themed_container(style=[
          ("flexgrow", 1.0),
          ("flexshrink", 1.0),
          ("flexDirection", "column"),
          ("alignSelf", "stretch"),
        ])
        @yue.ViewLike::set_visible(pc, i == 0)
        ignore((pages[i].mount)(@yue.ViewLike::view(pc)))
        stage.add_child(pc)
        panels.push(pc)
        let dot = @yue.themed_container(style=[
          ("width", 8.0),
          ("height", 8.0),
          ("marginLeft", 4.0),
          ("marginRight", 4.0),
          ("marginTop", 8.0),
        ])
        let di = i
        dot.on_draw(fn(p) {
          p.set_fill_color(
            if cur.val == di {
              @yue.theme_primary()
            } else {
              @yue.theme_border()
            },
          )
          p.fill_rect(0.0, 0.0, 8.0, 8.0)
        })
        @yue.View::set_cursor(dot, @yue.hand())
        @yue.ViewLike::on_mouse_down(dot, fn(e) {
          if e.button == 1 {
            do_switch(di)
            true
          } else {
            false
          }
        })
        dots.push(dot)
      }
      // 左右箭头(矢量三角,悬浮在舞台两侧的窄热区)
      fn arrow(right : Bool) -> @yue.Container {
        let a = @yue.themed_container(style=[
          ("width", 24.0),
          ("height", height),
        ])
        let hover = Ref(false)
        a.on_draw(fn(p) {
          if hover.val {
            let b = @yue.ViewLike::get_bounds(a)
            p.set_fill_color(@yue.theme_fill_hover())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
          let cx = 12.0
          let cy = height / 2.0
          p.set_fill_color(@yue.theme_text_regular())
          p.begin_path()
          if right {
            p.move_to(cx - 4.0, cy - 5.0)
            p.line_to(cx + 4.0, cy)
            p.line_to(cx - 4.0, cy + 5.0)
          } else {
            p.move_to(cx + 4.0, cy - 5.0)
            p.line_to(cx - 4.0, cy)
            p.line_to(cx + 4.0, cy + 5.0)
          }
          p.close_path()
          p.fill()
        })
        @yue.ViewLike::on_mouse_enter(a, fn(_e) {
          hover.val = true
          @yue.ViewLike::schedule_paint(a)
        })
        @yue.ViewLike::on_mouse_leave(a, fn(_e) {
          hover.val = false
          @yue.ViewLike::schedule_paint(a)
        })
        @yue.View::set_cursor(a, @yue.hand())
        @yue.ViewLike::on_mouse_down(a, fn(e) {
          if e.button == 1 {
            do_switch(if right { cur.val + 1 } else { cur.val - 1 })
            true
          } else {
            false
          }
        })
        a
      }

      // 布局:舞台行 = 左箭头 + 舞台 + 右箭头;下行为指示点
      let stage_row = @yue.themed_container(style=[("flexDirection", "row")])
      stage_row.add_child(arrow(false))
      @yue.ViewLike::set_style(stage, "flex", 1.0)
      stage_row.add_child(stage)
      stage_row.add_child(arrow(true))
      let dots_row = @yue.themed_container(style=[("flexDirection", "row")])
      for d in dots {
        dots_row.add_child(d)
      }
      outer.add_child(stage_row)
      outer.add_child(dots_row)
      // 悬停暂停自动轮播;set_timeout 一次性,回调里自排下一个
      @yue.ViewLike::on_mouse_enter(outer, fn(_e) { paused.val = true })
      @yue.ViewLike::on_mouse_leave(outer, fn(_e) { paused.val = false })
      if interval_ms > 0 && n > 1 {
        let tick : Ref[() -> Unit] = Ref(fn() {  })
        tick.val = fn() {
          // 超时 id 记进句柄:carousel_stop 取消待触发那次,running
          // 兜底终止自排链(回调已进队时不至于再多转一圈)
          rotation.timer.val = @yue.set_timeout(interval_ms, fn() {
            if rotation.running.val {
              if !paused.val {
                do_switch(cur.val + 1)
              }
              (tick.val)()
            }
          })
        }
        (tick.val)()
      }
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}
