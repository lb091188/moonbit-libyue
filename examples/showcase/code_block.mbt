// 折叠代码块:章节演示代码的收纳形态。初始收起,点标题行展开/再点收起;
// 展开后右上角「复制」把整段代码写入剪贴板并短促回显「已复制」。
// 状态全命令式(Ref + set_visible),不接 Store/Signal——展开是纯本地
// 瞬态,无跨节点派生关系。

///|
fn code_block(lines : Array[String]) -> @yue.Node {
  let text = lines.join("\n")
  let open = Ref(false)
  let body_ref : Ref[@yue.Container?] = Ref(None)
  // 两个箭头图标常驻、切换可见性(收起 › / 展开 ▾)
  let arrow_closed : Ref[@yue.Container?] = Ref(None)
  let arrow_open : Ref[@yue.Container?] = Ref(None)
  fn apply_open() -> Unit {
    match body_ref.val {
      Some(c) => c.set_visible(open.val)
      None => ()
    }
    match arrow_closed.val {
      Some(c) => c.set_visible(!open.val)
      None => ()
    }
    match arrow_open.val {
      Some(c) => c.set_visible(open.val)
      None => ()
    }
  }

  let copied : @yue.Store[String] = @yue.Store::new("")
  let header = @yue.hbox(
    [
      @yue.hbox(
        [@yue.icon(@yue.ChevronRight, size=12.0)],
        style=[("width", 14.0), ("height", 14.0)],
        handle=fn(c) { arrow_closed.val = Some(c) },
      ),
      @yue.hbox(
        [@yue.icon(@yue.ChevronDown, size=12.0)],
        style=[("width", 14.0), ("height", 14.0)],
        handle=fn(c) {
          arrow_open.val = Some(c)
          c.set_visible(false)
        },
      ),
      @yue.label_t("演示代码", role=@yue.Secondary),
    ],
    style=[("height", 24.0), ("paddingLeft", 4.0), ("marginTop", 6.0)],
    style_str=[("alignItems", "center")],
    handle=fn(c) {
      @yue.View::set_cursor(c, @yue.Cursor::new(@yue.Hand))
      c.on_mouse_enter(fn(_e) {
        c.set_background_color(@yue.theme_current().fill_hover)
      })
      c.on_mouse_leave(fn(_e) { c.set_background_color("#00000000") })
      c.on_mouse_down(fn(e) {
        if e.button == 1 {
          open.val = !open.val
          apply_open()
          true
        } else {
          false
        }
      })
    },
  )
  let body = @yue.vbox(
    [
      @yue.hbox(
        [
          @yue.button_t(
            "复制",
            variant=@yue.Text,
            on_click=fn() {
              @yue.Clipboard::get().set_text(text)
              copied.set("已复制 ✓")
              ignore(@yue.set_timeout(1500, fn() { copied.set("") }))
            },
          ),
          @yue.bind(copied.signal(), fn(s) { s }),
        ],
        style_str=[("justifyContent", "flex-end"), ("alignItems", "center")],
      ),
      @yue.code_view(lines, lang="moonbit", line_numbers=true, width=640.0),
    ],
    style=[("marginTop", 4.0)],
    handle=fn(c) {
      body_ref.val = Some(c)
      c.set_visible(false)
    },
  )
  @yue.vbox([header, body])
}
