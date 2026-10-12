// 拖放组件（W21c）：把 `yue/core/drag.mbt` 的会话包成两个声明式钩子——
// 拖源 `drag_source(content, payload)`、投放目标 `drop_target(content, on_drop)`。
//
// 与旧栈的一条差（记档）：旧链路的拖源/投放是**平台回调**（GTK `gtk_drag_*` /
// Win32 `IDropTarget`），且要分别注册 enter/update/leave 三件；本栈全自绘，
// **应用内拖放**不需要任何平台接口，三个回调也收成一个 `on_drop`——拖入高亮由
// 绘制方读 `@core.drag_hover()` 自判（见 `drop_target`）。**跨应用**的系统级拖放
// 仍随平台批（接口形状已定，后端接上后本文件不用改）。
//
// 一个使用约束（不是 bug）：拖源内容里的**交互控件会先吃掉按下**（指针事件最深的
// 先跑），那样就拖不动它——拖源里放展示件（文本/图标/缩略图），别放按钮。

///|
/// 拖源：包住 `content`，在其上按下并拖出 `threshold` 像素后调 `payload()` 取数据
/// 开拖；`payload()` 返回 None（或不给）表示这一拖不成立（当作普通点击）。
/// 拖拽期间只做「更新落点」，松手时投给落点（见 `@core.drag_drop`）。
pub fn drag_source(
  content : @core.Node,
  payload? : () -> @core.DragData? = fn() -> @core.DragData? { None },
  threshold? : Double = 4.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let _ = content.mount_into(w)
    // 三态：armed = 按下且在等阈值；dragging = 已经开拖（会话在跑）
    let armed : Ref[Bool] = Ref(false)
    let dragging : Ref[Bool] = Ref(false)
    let ox : Ref[Double] = Ref(0.0)
    let oy : Ref[Double] = Ref(0.0)
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      // 投给控件的是本地坐标，换回窗口坐标再交给会话（会话一律用窗口坐标）
      let wx = self.rect.x + ev.x
      let wy = self.rect.y + ev.y
      match ev.kind {
        @core.Down => {
          if ev.button != 1 {
            false
          } else {
            armed.val = true
            dragging.val = false
            ox.val = wx
            oy.val = wy
            true
          }
        }
        @core.Move => {
          if dragging.val {
            let _ = @core.drag_move(wx, wy)
            true
          } else if armed.val {
            let dx = wx - ox.val
            let dy = wy - oy.val
            if dx * dx + dy * dy >= threshold * threshold {
              // 过阈值才算拖：没过阈值时按普通点击放行（内容里的选择/点击不受影响）
              match payload() {
                Some(data) =>
                  if @core.drag_begin(data, self.id, wx, wy) {
                    dragging.val = true
                    armed.val = false
                    true
                  } else {
                    // 已有别的拖拽在跑：这一拖不成立，退回普通按下
                    armed.val = false
                    false
                  }
                None => {
                  armed.val = false
                  false
                }
              }
            } else {
              false
            }
          } else {
            false
          }
        }
        @core.Up => {
          let was = dragging.val
          armed.val = false
          dragging.val = false
          if was {
            // 松手：投给落点（没有落点或被拒绝都会结束会话）
            let _ = @core.drag_drop(wx, wy)
            true
          } else {
            false
          }
        }
        @core.Leave => {
          // 指针离开本控件：还在等阈值就撤销；已经开拖时不动（拖拽是跨控件的，
          // 会话自己按窗口坐标算落点）
          if !dragging.val {
            armed.val = false
          }
          false
        }
      }
    })
    handle(w)
    w
  })
}

///|
/// 投放目标：包住 `content`，被拖拽悬停时描一圈主题主色高亮，松手时若有数据则
/// 调 `accept` 判收不收、收则调 `on_drop`。`accept` 默认全收。
pub fn drop_target(
  content : @core.Node,
  on_drop? : (@core.DragData, Double, Double) -> Unit = fn(
    _d : @core.DragData,
    _x : Double,
    _y : Double,
  ) -> Unit {
    ()
  },
  accept? : (@core.DragData) -> Bool = fn(_d : @core.DragData) -> Bool { true },
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let _ = content.mount_into(w)
    w.set_on_drop(fn(data : @core.DragData, x : Double, y : Double) -> Bool {
      if accept(data) {
        on_drop(data, x, y)
        true
      } else {
        false
      }
    })
    // 悬停高亮：会话把「当前最深命中的投放目标 id」记在 core 里，这里读它自判——
    // 于是不需要 enter/update/leave 三个回调，也就不会有「离开回调漏发」的态
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      if @core.drag_active() && @core.drag_hover() == self.id {
        p.set_stroke_color(@theme.theme_primary())
        p.set_line_width(2.0)
        p.stroke_rect(1.0, 1.0, (r.w - 2.0).max(1.0), (r.h - 2.0).max(1.0))
      }
    })
    handle(w)
    w
  })
}
