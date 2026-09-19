// 应用内对话框:dialog_t(EP Dialog 对位,同窗遮罩形态)。遮罩层
// position=absolute 全覆盖 + 半透明黑(固定色,不随主题),面板经
// justifyContent/alignItems center 居中——不新开窗口,跨平台零平台代码;
// 视觉模态(遮罩挡鼠标,面板消费点击防冒泡误关),非键盘强模态。
// 显示经 Store[Bool] 驱动:set_visible 即弹/收,同一份 Node 常驻页面树。

///|
/// 对话框:visible 驱动弹/收;标题栏(title + ✕)+ 内容区(children)
/// + 底部按钮区(取消 Soft / 确定 Solid,文案传空串隐藏该按钮,两个都
/// 空则整行不显示)。确定/取消/✕ 触发回调后自动收起;close_on_mask=true
/// 时点遮罩空白处也收起。width 为面板宽(默认 420)。
pub fn dialog_t(
  visible : Store[Bool],
  title : String,
  children : Array[Node],
  width? : Double = 420.0,
  confirm_text? : String = "确定",
  cancel_text? : String = "取消",
  on_confirm? : () -> Unit = fn() {  },
  on_cancel? : () -> Unit = fn() {  },
  close_on_mask? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let close = fn() -> Unit {
        visible.set(false)
      }
      // 遮罩:absolute 全覆盖 + 居中排布;固定半透明黑(EP 遮罩语义)
      let overlay = themed_container(
        style_str=[
          ("position", "absolute"),
          ("top", "0"),
          ("bottom", "0"),
          ("left", "0"),
          ("right", "0"),
          ("justifyContent", "center"),
          ("alignItems", "center"),
        ],
      )
      ViewLike::set_background_color(overlay, "#00000059")
      // 面板:主题面板底 + 1px 边框(on_draw 描)
      let panel = themed_container(
        style=[("width", width)],
        style_str=[("flexDirection", "column"), ("maxHeight", "80%")],
      )
      set_panel_bg(panel)
      panel.on_draw(fn(p) {
        let b = ViewLike::get_bounds(panel)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
      })
      // 面板消费鼠标,避免点击内容冒泡到遮罩触发 close_on_mask
      ViewLike::on_mouse_down(panel, fn(_e) { true })
      // 标题栏:标题 + 弹性空档 + ✕
      let head = themed_container(
        style=[("height", 44.0), ("paddingLeft", 16.0), ("paddingRight", 10.0), ("marginTop", 4.0)],
        style_str=[("flexDirection", "row"), ("alignItems", "center")],
      )
      attach(ViewLike::view(head), label_t(title, role=Section).mount_into(ViewLike::view(head)))
      let spacer = themed_container(style=[("flex", 1.0)])
      head.add_child(spacer)
      let close_btn = icon_button_t(Close, on_click=fn() {
        on_cancel()
        close()
      }, tip="关闭")
      attach(ViewLike::view(head), close_btn.mount_into(ViewLike::view(head)))
      panel.add_child(head)
      // 内容区:统一 16px 内边距
      let body = themed_container(
        style=[("padding", 16.0)],
        style_str=[("flexDirection", "column")],
      )
      for ch in children {
        ignore((ch.mount)(ViewLike::view(body)))
      }
      panel.add_child(body)
      // 底部按钮区:右对齐;两个文案都空则不显示
      if confirm_text != "" || cancel_text != "" {
        let foot = themed_container(
          style=[("paddingRight", 16.0), ("paddingBottom", 14.0)],
          style_str=[("flexDirection", "row"), ("justifyContent", "flex-end")],
        )
        if cancel_text != "" {
          attach(
            ViewLike::view(foot),
            button_t(cancel_text, on_click=fn() {
              on_cancel()
              close()
            }).mount_into(ViewLike::view(foot)),
          )
        }
        if confirm_text != "" {
          attach(
            ViewLike::view(foot),
            button_t(confirm_text, variant=Solid, on_click=fn() {
              on_confirm()
              close()
            }).mount_into(ViewLike::view(foot)),
          )
        }
        panel.add_child(foot)
      }
      // 遮罩点击(面板外空白):可选收起
      ViewLike::on_mouse_down(overlay, fn(_e) {
        if close_on_mask {
          close()
          true
        } else {
          true
        }
      })
      overlay.add_child(panel)
      // 显示态:Store 驱动
      ViewLike::set_visible(overlay, visible.get())
      visible.subscribe(fn(v) { ViewLike::set_visible(overlay, v) })
      attach(parent, ViewLike::view(overlay))
      ViewLike::view(overlay)
    },
  }
}

///|
/// 轻提示层:返回 (层节点, 推送函数)。层节点挂在窗口根(absolute 顶部
/// 横条区域,不占布局),推送函数 push(text, t) 弹一条语义提示,默认
/// duration_ms 毫秒后自动移除;多条自上而下堆叠。推送须在层 mount 之后
/// 调用(典型:按钮回调里推)。
pub fn toast_layer(
  duration_ms? : Int = 2600,
) -> (Node, (String, SemanticType) -> Unit) {
  let host : Ref[Container?] = Ref(None)
  let layer = {
    mount: fn(parent) {
      let c = themed_container(
        style=[("paddingTop", 8.0)],
        style_str=[
          ("position", "absolute"),
          ("top", "0"),
          ("left", "0"),
          ("right", "0"),
          ("flexDirection", "column"),
          ("alignItems", "center"),
        ],
      )
      host.val = Some(c)
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
    },
  }
  fn push(text : String, t : SemanticType) -> Unit {
    match host.val {
      None => ()
      Some(c) => {
        let fnt = Font::new("Sans", 13.0)
        let probe = AttributedText::new(text, wrap=false)
        probe.set_font(fnt)
        let text_w = probe.get_bounds_for(10000.0, 100.0).width
        let w = text_w + 62.0
        let bar = themed_container(
          style=[
            ("width", w),
            ("height", 34.0),
            ("marginBottom", 8.0),
          ],
        )
        set_panel_bg(bar)
        bar.on_draw(fn(p) {
          let b = ViewLike::get_bounds(bar)
          p.set_stroke_color(theme_border())
          p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
          let kind : IconKind = match t {
            Info => IconKind::Info
            Success => IconKind::Success
            Warning => IconKind::Warning
            Danger => IconKind::Error
            Primary => IconKind::Info
          }
          draw_icon(p, kind, 18.0, b.height / 2.0, 7.0, type_color(t))
          let at = AttributedText::new(text, valign=Center, wrap=false)
          at.set_font(fnt)
          at.set_color(theme_text_regular())
          // GTK 端水平 align 无效,按测宽手动居中(图标 24 + 右侧留白)
          let x = 30.0 + (b.width - 30.0 - 16.0 - text_w) / 2.0
          p.draw_attributed_text(at, x, 0.0, b.width, b.height)
        })
        c.add_child(bar)
        ignore(
          set_timeout(duration_ms, fn() {
            ignore(Container::remove_child_view(c, ViewLike::view(bar)))
          }),
        )
      }
    }
  }
  (layer, push)
}

///|
/// 右键上下文菜单:给任意节点包右键弹原生菜单。items 为 (文案, 回调)
/// 序列,文案 "-" 画分隔线;弹出位置经 get_bounds_in_screen + 事件相对
/// 坐标换算屏幕坐标(Menu::popup_at 收屏幕坐标)。菜单每次右键现建,
/// 避免原生菜单复用的状态残留。
pub fn context_menu_for(
  content : Node,
  items : Array[(String, () -> Unit)],
) -> Node {
  {
    mount: fn(parent) {
      let wrap = themed_container(style_str=[("flexDirection", "column")])
      ignore((content.mount)(ViewLike::view(wrap)))
      ViewLike::on_mouse_down(wrap, fn(e) {
        if e.button == 2 {
          let menu = Menu::new()
          for it in items {
            if it.0 == "-" {
              ignore(menu.add_separator())
            } else {
              let (label, cb) = it
              let mi = menu.add_label_item(label)
              mi.on_click(cb)
            }
          }
          let sb = ViewLike::get_bounds_in_screen(wrap)
          menu.popup_at(sb.x + e.view_x, sb.y + e.view_y)
          true
        } else {
          false
        }
      })
      attach(parent, ViewLike::view(wrap))
      ViewLike::view(wrap)
    },
  }
}
