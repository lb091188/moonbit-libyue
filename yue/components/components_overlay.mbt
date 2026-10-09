// 浮层组件:tooltip / popover / dropdown_menu。

///|
/// 悬浮提示:给任意节点包原生 tooltip(系统样式,零成本;主题化气泡
/// 请用 popover_t)。
pub fn tooltip_t(
  content : @yue.Node,
  tip : String,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.View) -> Unit = fn(_v) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let v = (content.mount)(parent)
      @yue.apply_style_view(v, style)
      handle(v)
      @yue.ffi_view_set_tooltip(v, @yue.utf8_bytes(tip))
      v
    },
  }
}

///|
/// 气泡弹层(EP Popover):trigger 点击后在自身下方弹出任意内容
/// (Node,Popover 承载,内容先挂进临时容器),再次点击切换收起。
pub fn popover_t(
  trigger : @yue.Node,
  content : @yue.Node,
  width : Double,
  height : Double,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let tv = (trigger.mount)(parent)
      let pop : Ref[@yue.Popover?] = Ref(None)
      let open = Ref(false)
      let wrapped : (
        Int,
        Double,
        Double,
        Double,
        Double,
        Double,
        Double,
        Int,
        Int,
      ) -> Int = fn(button, _vx, _vy, _wx, _wy, _sx, _sy, _m, _t) {
        if button != 1 {
          return 0
        }
        match pop.val {
          None => {
            let p = @yue.Popover::new()
            @yue.bind_popover_bg(p)
            let holder_style : Array[(String, &@yue.StyVal)] = [
              ("width", width),
              ("height", height),
            ]
            for kv in style {
              holder_style.push(kv)
            }
            let holder = @yue.themed_container(style=holder_style)
            handle(holder)
            ignore((content.mount)(@yue.ViewLike::view(holder)))
            p.set_content(holder)
            p.set_content_size(width, height)
            // 点外关闭(Linux 系统行为)/显式关闭都同步状态,
            // 否则下次点击误走 close 分支,弹层再也打不开
            p.on_close(fn() { open.val = false })
            pop.val = Some(p)
            @yue.ffi_popover_show_relative_to(p, tv)
            open.val = true
          }
          Some(p) =>
            if open.val {
              p.close()
            } else {
              @yue.ffi_popover_show_relative_to(p, tv)
              open.val = true
            }
        }
        1
      }
      @yue.ffi_view_set_cursor(tv, @yue.hand())
      @yue.keep_alive(fn() { ignore(wrapped) })
      @yue.ffi_view_on_mouse_up(
        tv,
        fn(f, b, vx, vy, wx, wy, sx, sy, m, t) {
          f(b, vx, vy, wx, wy, sx, sy, m, t)
        },
        wrapped,
      )
      tv
    },
  }
}

///|
/// 下拉菜单(EP Dropdown):触发文字 + 下拉箭头,点击弹菜单项列表
/// (Popover 承载):悬停高亮,点击回调序号并收起;"-" 项画分隔线。
pub fn dropdown_menu(
  trigger : String,
  items : Array[String],
  on_select : (Int) -> Unit,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let fnt = @yue.Font::new("Sans", 13.0)
      let focused = Ref(false)
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", 160.0),
        ("height", @yue.control_height),
        ("marginBottom", 10.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let field = @yue.themed_container(style=base)
      @yue.set_panel_bg(field)
      @yue.View::set_cursor(field, @yue.hand())
      field.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(field)
        if focused.val {
          p.set_fill_color(@yue.theme_fill_hover())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        p.set_stroke_color(
          if focused.val {
            @yue.theme_focus_accent()
          } else {
            @yue.theme_border()
          },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        p.draw_text(
          trigger,
          10.0,
          0.0,
          b.width - 30.0,
          b.height,
          valign=@yue.Center,
          color=@yue.theme_text_primary(),
        )
        p.set_fill_color(@yue.theme_text_secondary())
        p.begin_path()
        p.move_to(b.width - 20.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 12.0, b.height / 2.0 - 2.0)
        p.line_to(b.width - 16.0, b.height / 2.0 + 3.0)
        p.close_path()
        p.fill()
      })
      let pop : Ref[@yue.Popover?] = Ref(None)
      @yue.ViewLike::set_focusable(field, true)
      @yue.ViewLike::on_focus_in(field, fn() {
        focused.val = true
        @yue.ViewLike::schedule_paint(field)
        false
      })
      @yue.ViewLike::on_focus_out(field, fn() {
        focused.val = false
        @yue.ViewLike::schedule_paint(field)
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
        false
      })
      @yue.ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(field)
          match pop.val {
            Some(_) => ()
            None => {
              let p = @yue.Popover::new()
              @yue.bind_popover_bg(p)
              // 根容器宽高创建期给定(事后 set_style 会被弹层时序吞掉),
              // 高度 = 项数 x 28 + padding 8,与 content_size 一致
              let pop_w = @yue.ViewLike::get_bounds(field).width
              let list = @yue.themed_container(style=[
                ("width", pop_w),
                ("height", items.length().to_double() * 28.0 + 8.0),
                ("padding", 4.0),
                ("flexDirection", "column"),
              ])
              @yue.set_panel_bg(list)
              for i in 0..<items.length() {
                let it = items[i]
                let idx = i
                if it == "-" {
                  let sep = @yue.themed_container(style=[("height", 9.0)])
                  sep.on_draw(fn(p2) {
                    let b = @yue.ViewLike::get_bounds(sep)
                    p2.set_stroke_color(@yue.theme_border())
                    p2.begin_path()
                    p2.move_to(8.0, 4.5)
                    p2.line_to(b.width - 8.0, 4.5)
                    p2.stroke()
                  })
                  list.add_child(sep)
                  continue
                }
                let hover = Ref(false)
                let row = @yue.themed_container(style=[
                  ("height", 28.0),
                  ("paddingLeft", 8.0),
                  ("flexDirection", "row"),
                  ("alignItems", "center"),
                ])
                row.on_draw(fn(p2) {
                  let b = @yue.ViewLike::get_bounds(row)
                  if hover.val {
                    p2.set_fill_color(@yue.theme_fill_hover())
                    p2.fill_rect(0.0, 0.0, b.width, b.height)
                  }
                  let at = @yue.AttributedText::new(
                    it,
                    valign=@yue.Center,
                    wrap=false,
                  )
                  at.set_font(fnt)
                  at.set_color(@yue.theme_text_regular())
                  p2.draw_attributed_text(at, 8.0, 0.0, b.width - 16.0, 28.0)
                })
                @yue.ViewLike::on_mouse_enter(row, fn(_e) {
                  hover.val = true
                  @yue.ViewLike::schedule_paint(row)
                })
                @yue.ViewLike::on_mouse_leave(row, fn(_e) {
                  hover.val = false
                  @yue.ViewLike::schedule_paint(row)
                })
                @yue.View::set_cursor(row, @yue.hand())
                // release 才选中+关层:防 press 关层后悬着的 release
                // 穿透到弹层下方控件(弹层点项一律 release,见
                // adaptation.md)
                @yue.ViewLike::on_mouse_up(row, fn(e2) {
                  if e2.button == 1 {
                    on_select(idx)
                    match pop.val {
                      Some(p3) => p3.close()
                      None => ()
                    }
                    true
                  } else {
                    false
                  }
                })
                list.add_child(row)
              }
              p.set_content(list)
              p.set_content_size(pop_w, items.length().to_double() * 28.0 + 8.0)
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      @yue.attach(parent, @yue.ViewLike::view(field))
      @yue.ViewLike::view(field)
    },
  }
}
