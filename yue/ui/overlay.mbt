// 浮层组件首批：气泡弹层 / 下拉菜单 / 悬浮提示。
//
// 三件都开在 `yue/core/overlay.mbt` 的图层上：整窗覆盖、空则不可见（不打扰内容
// 事件）、点浮层外收起最上面那层。浮层内容一律**临开临建、关掉即摘**（不进内容树、
// 不占位、也不需要隐藏态），这与「预建 + 显隐」的切换式组件是两条路：浮层是瞬时
// 的，重建成本换掉了一整族隐藏态与状态同步。
//
// 与 master 的一条差（记档）：`tooltip_t` 在旧链路走 GTK 原生 tooltip
// （`ffi_view_set_tooltip`），本栈全自绘、没有原生 tooltip 通道，所以改成
// 「悬停延时后开一层自绘气泡」——观感可控（吃主题），代价是要自己管延时与收起。

///|
/// 浮层面板：面板底 + 描边 + 可选固定尺寸（0 = 按内容）。
fn overlay_pane(
  children : Array[@core.Node],
  width : Double,
  height : Double,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(@yoga.Column)
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    }
    if height > 0.0 {
      w.node.set_height(@yoga.fixed(height))
    }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
    })
    @core.mount_children(w, children)
    w
  })
}

///|
/// 浮层是否还开着（句柄有效即开着：点外部会被图层收起，句柄随之失效——
/// 组件因此不必自己跟踪「外面关掉了」这件事）。
fn overlay_alive(id : Int) -> Bool {
  match @core.overlay_rect_of(id) {
    Some(_) => true
    None => false
  }
}

///|
/// 气泡弹层（EP Popover）：点 trigger 在它下方弹出任意内容，再点一次收起；
/// 点浮层外由图层收起。width/height 传 0 表示按内容定尺寸。
pub fn popover_t(
  trigger : @core.Node,
  content : @core.Node,
  width? : Double = 0.0,
  height? : Double = 0.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let open_id : Ref[Int] = Ref(0)
    // trigger 自己仍在最前：它内部控件的事件先跑，抬起冒泡到这里才切换开合
    let _ = trigger.mount_into(w)
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Up => {
          // 开着时再点触发件通常到不了这里：那一击被图层消费掉（点浮层外收起）；
          // 这个分支兜底（程序化投递、或图层被撤掉的形态），免得句柄失效后打不开
          if overlay_alive(open_id.val) {
            @core.overlay_hide(open_id.val)
            open_id.val = 0
          } else {
            open_id.val = @core.overlay_show_at(
              overlay_pane([content], width, height),
              self.rect.x,
              self.rect.y + self.rect.h + 2.0,
            )
          }
          false
        }
        _ => false
      }
    })
    handle(w)
    w
  })
}

///|
/// 下拉菜单一行（28 高，悬停高亮；`"-"` 画成分隔线）。
fn menu_row(text : String, on_pick : () -> Unit) -> @core.Node {
  if text == "-" {
    return separator()
  }
  let font = @text.Font::new("", 13.0)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.percent(100.0))
    w.node.set_height(@yoga.fixed(28.0))
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      if self.hovered {
        p.set_fill_color(@theme.theme_fill_hover())
        p.fill_rect(0.0, 0.0, r.w, r.h)
      }
      let _ = @text.draw_box_at(
        p,
        10.0,
        0.0,
        (r.w - 10.0).max(1.0),
        r.h,
        text,
        font,
        @theme.theme_text_regular(),
        align=@text.Start,
        valign=@text.Center,
      )
    })
    w.on_pointer = Some(fn(
      _self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => true
        @core.Up => {
          on_pick()
          false
        }
        _ => false
      }
    })
    w
  })
}

///|
/// 下拉菜单（EP Dropdown）：触发文字 + 下拉箭头，点开菜单项列表，悬停高亮，
/// 选中回调序号并收起。
pub fn dropdown_menu(
  trigger : String,
  items : Array[String],
  on_select? : (Int) -> Unit = fn(_i : Int) -> Unit { () },
  width? : Double = 150.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let font = @text.Font::new("", 13.0)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let tw = text_width(trigger, font)
    w.node.set_width(@yoga.fixed(tw + 40.0))
    w.node.set_height(@yoga.fixed(30.0))
    let open_id : Ref[Int] = Ref(0)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(
        if self.hovered {
          @theme.theme_fill_hover()
        } else {
          @theme.theme_bg_panel()
        },
      )
      fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      let _ = @text.draw_box_at(
        p,
        10.0,
        0.0,
        (r.w - 30.0).max(1.0),
        r.h,
        trigger,
        font,
        @theme.theme_text_regular(),
        align=@text.Start,
        valign=@text.Center,
      )
      // 下拉箭头：展开朝上、收起朝下
      fold_arrow(
        p,
        r.w - 14.0,
        r.h / 2.0,
        4.0,
        overlay_alive(open_id.val),
        @theme.theme_text_secondary(),
      )
    })
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => true
        @core.Up => {
          if overlay_alive(open_id.val) {
            @core.overlay_hide(open_id.val)
            open_id.val = 0
          } else {
            let rows : Array[@core.Node] = []
            for i = 0; i < items.length(); i = i + 1 {
              let idx = i
              rows.push(
                menu_row(items[i], fn() -> Unit {
                  @core.overlay_hide(open_id.val)
                  open_id.val = 0
                  on_select(idx)
                }),
              )
            }
            open_id.val = @core.overlay_show_at(
              overlay_pane(rows, width, 0.0),
              self.rect.x,
              self.rect.y + self.rect.h + 2.0,
            )
          }
          false
        }
        _ => false
      }
    })
    handle(w)
    w
  })
}

///|
/// 提示气泡（实底白字的圆角小条）。
fn tooltip_pane(tip : String, font : @text.Font) -> @core.Node {
  let text_w = text_width(tip, font)
  @core.node_of_new(fn(pane_w : @core.Widget) -> @core.Widget {
    watch_theme()
    pane_w.node.set_height(@yoga.fixed(24.0))
    pane_w.node.set_width(@yoga.fixed(text_w + 16.0))
    pane_w.on_draw = Some(fn(
      _s : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_text_primary())
      fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
      let _ = @text.draw_box_at(
        p,
        0.0,
        0.0,
        r.w,
        r.h,
        tip,
        font,
        "#ffffff",
        align=@text.Center,
        valign=@text.Center,
      )
    })
    pane_w
  })
}

///|
/// 悬浮提示（EP Tooltip）：指针停在内容上 `delay_ms` 毫秒后在它下方开一层气泡，
/// 指针离开即收（延时未到就离开则不出现）。
///
/// 悬停走宿主的 `on_hover_change` 而不是「等子控件的移动事件冒泡上来」：子控件
/// 可能自己消费移动（按钮就是这样，`Move => !is_off()`），包在外面的组件就再也
/// 收不到通知；宿主维护的悬停态带父链语义（与 CSS `:hover` 同义），包住谁都成立。
pub fn tooltip_t(
  content : @core.Node,
  tip : String,
  delay_ms? : Int = 500,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let font = @text.Font::new("", 12.0)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let tip_id : Ref[Int] = Ref(0)
    let timer : Ref[Int] = Ref(0)
    let _ = content.mount_into(w)
    w.on_hover_change = Some(fn(
      self : @core.Widget,
      on : Bool,
    ) -> Unit {
      if on {
        if timer.val == 0 && tip_id.val == 0 {
          // 锚点先算好再排延时：定时回调不捕获本控件（自捕获是引用环）
          let ax = self.rect.x
          let ay = self.rect.y + self.rect.h + 4.0
          timer.val = @core.set_timeout(delay_ms, fn() {
            timer.val = 0
            tip_id.val = @core.overlay_show_at(tooltip_pane(tip, font), ax, ay)
          })
        }
      } else {
        if timer.val != 0 {
          @core.clear_timeout(timer.val)
          timer.val = 0
        }
        if tip_id.val != 0 {
          @core.overlay_hide(tip_id.val)
          tip_id.val = 0
        }
      }
    })
    handle(w)
    w
  })
}
