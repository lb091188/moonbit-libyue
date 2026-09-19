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
