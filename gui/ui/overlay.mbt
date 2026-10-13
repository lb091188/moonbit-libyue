// 浮层组件首批：气泡弹层 / 下拉菜单 / 悬浮提示。
//
// 三件都开在 `core/overlay.mbt` 的图层上：整窗覆盖、空则不可见（不打扰内容
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
    w.cursor = @core.CURSOR_HAND
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
    w.cursor = @core.CURSOR_HAND
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

///|
/// 对话框（EP Dialog）：`visible` 驱动弹/收；标题栏（标题 + `✕`）+ 内容区 +
/// 底部按钮区（取消 / 确定，文案传空串隐藏该按钮）。三个出口都会先收起再回调。
/// 遮罩铺满窗口并吃掉点击（视觉模态；`close_on_mask=true` 时点遮罩空白处收起）。
///
/// 与 master 的一条差（记档）：旧链路把遮罩做成**页面内的绝对定位层**（同一份
/// `Node` 常驻页面树、靠 `set_visible` 弹收）；本栈改开在浮层图层上——对话框
/// 天然要压过所有内容与其它浮层，图层正是这个语义，而且不需要常驻一棵隐藏树。
pub fn dialog_t(
  visible : @core.Store[Bool],
  title : String,
  children : Array[@core.Node],
  confirm_text? : String = "确定",
  cancel_text? : String = "取消",
  on_confirm? : () -> Unit = fn() -> Unit { () },
  on_cancel? : () -> Unit = fn() -> Unit { () },
  close_on_mask? : Bool = false,
  width? : Double = 420.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  // 用显式 mount 而不是 `node_of_new`：后者的 finish 在**构造期**就跑
  // （`node_of_new` = `node_of(finish(Widget::new()))`），而「按 Store 立刻开层」
  // 需要浮层宿主已经就位——宿主是 App 建窗时装的，挂载期调用才稳。
  {
    mount: fn(parent : @core.Widget) -> @core.Widget {
    let anchor = @core.Widget::new()
    watch_theme()
    // 锚点自己是个 0 尺寸占位：对话框的可见性只由 Store 驱动
    anchor.node.set_height(@yoga.fixed(0.0))
    let open_id : Ref[Int] = Ref(0)
    let title_font = @text.Font::new("", 14.0, weight=@text.SemiBold)
    let close = fn(v : Bool) -> Unit { visible.set(v) }
    let open = fn() -> Unit {
      if open_id.val != 0 {
        return
      }
      let panel_w = width
      // 面板：主题面板底 + 描边 + 标题栏/内容/按钮三区
      let panel : @core.Widget = @core.Widget::new()
      let panel_node = @core.node_of(panel)
      let scrim = @core.node_of_new(fn(s : @core.Widget) -> @core.Widget {
        watch_theme()
        // 铺满「铺满窗口的包裹层」：宽度靠内部对齐撑不可靠（内容可能更宽），
        // 显式 100% 才保证遮罩确实盖住整窗
        s.node.set_width(@yoga.percent(100.0))
        s.node.set_height(@yoga.percent(100.0))
        s.node.set_justify_content(@yoga.JustifyContent::Center)
        s.node.set_align_items(@yoga.AlignItems::Center)
        // 遮罩自己吃下按下：视觉模态（点击不穿透到内容）
        s.on_pointer = Some(fn(
          self : @core.Widget,
          ev : @core.PointerEvent,
        ) -> Bool {
          match ev.kind {
            @core.Down => true
            @core.Up => {
              let ax = ev.x + self.rect.x
              let ay = ev.y + self.rect.y
              if !panel.rect.contains(ax, ay) && close_on_mask {
                close(false)
              }
              false
            }
            _ => false
          }
        })
        let _ = panel_node.mount_into(s)
        s
      })
      // 面板内容
      let title_bar = @core.Widget::new()
      title_bar.node.set_flex_direction(@yoga.Row)
      title_bar.node.set_height(@yoga.fixed(40.0))
      title_bar.node.set_align_items(@yoga.AlignItems::Center)
      title_bar.set_padding(left=12.0)
      title_bar.on_draw = Some(fn(
        _s : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        let _ = @text.draw_box_at(
          p,
          12.0,
          0.0,
          (r.w - 44.0).max(1.0),
          r.h,
          title,
          title_font,
          @theme.theme_text_primary(),
          align=@text.Start,
          valign=@text.Center,
        )
      })
      let close_btn = @core.Widget::new()
      close_btn.node.set_position(@yoga.Absolute)
      close_btn.node.set_top(@yoga.fixed(8.0))
      close_btn.node.set_right(@yoga.fixed(8.0))
      close_btn.node.set_width(@yoga.fixed(24.0))
      close_btn.node.set_height(@yoga.fixed(24.0))
      close_btn.cursor = @core.CURSOR_HAND
      close_btn.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        if self.hovered {
          p.set_fill_color(@theme.theme_fill_hover())
          fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
        }
        p.set_stroke_color(@theme.theme_text_secondary())
        p.set_line_width(1.4)
        p.begin_path()
        p.move_to(8.0, 8.0)
        p.line_to(r.w - 8.0, r.h - 8.0)
        p.move_to(r.w - 8.0, 8.0)
        p.line_to(8.0, r.h - 8.0)
        p.stroke()
      })
      close_btn.on_pointer = Some(fn(
        _s : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Down => true
          @core.Up => {
            close(false)
            false
          }
          _ => false
        }
      })
      let body = @core.Widget::new()
      body.node.set_flex_direction(@yoga.Column)
      body.node.set_width(@yoga.percent(100.0))
      body.set_padding(left=14.0)
      @core.mount_children(body, children)
      let footer = @core.Widget::new()
      footer.node.set_flex_direction(@yoga.Row)
      footer.node.set_height(@yoga.fixed(44.0))
      footer.node.set_justify_content(@yoga.JustifyContent::FlexEnd)
      footer.node.set_align_items(@yoga.AlignItems::Center)
      footer.node.set_gap(0.0, 8.0)
      footer.set_padding(left=12.0)
      fn footer_btn(text : String, primary : Bool, act : () -> Unit) -> Unit {
        if text.length() == 0 {
          return
        }
        let b = @core.Widget::new()
        b.node.set_width(@yoga.fixed(text_width(text, title_font) + 28.0))
        b.node.set_height(@yoga.fixed(28.0))
        b.cursor = @core.CURSOR_HAND
        b.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(
            if primary {
              if self.hovered {
                @theme.theme_primary_hover()
              } else {
                @theme.theme_primary()
              }
            } else if self.hovered {
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
            0.0,
            0.0,
            r.w,
            r.h,
            text,
            title_font,
            if primary { "#ffffff" } else { @theme.theme_text_regular() },
            align=@text.Center,
            valign=@text.Center,
          )
        })
        b.on_pointer = Some(fn(
          _s : @core.Widget,
          ev : @core.PointerEvent,
        ) -> Bool {
          match ev.kind {
            @core.Down => true
            @core.Up => {
              close(false)
              act()
              false
            }
            _ => false
          }
        })
        footer.append_child(b)
      }

      footer_btn(cancel_text, false, on_cancel)
      footer_btn(confirm_text, true, on_confirm)
      panel.node.set_flex_direction(@yoga.Column)
      panel.node.set_width(@yoga.fixed(panel_w))
      panel.set_padding_all(0.0)
      panel.on_draw = Some(fn(
        _s : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        p.set_fill_color(@theme.theme_bg_panel())
        fill_round_rect(p, 0.0, 0.0, r.w, r.h, 6.0)
        p.set_stroke_color(@theme.theme_border())
        p.set_line_width(1.0)
        p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      })
      panel.append_child(title_bar)
      panel.append_child(close_btn)
      panel.append_child(body)
      panel.append_child(footer)
      open_id.val = @core.overlay_show_full(scrim)
      handle(anchor)
    }

    // Store 驱动：为真开一层、为假收掉（开着时被图层收起也要同步回 Store）
    let sig = visible.signal()
    let sid = sig.subscribe(fn(v : Bool) -> Unit {
      if v {
        open()
      } else {
        if open_id.val != 0 {
          @core.overlay_hide(open_id.val)
          open_id.val = 0
        }
      }
    })
    @core.sub_bag_register(fn() { sig.remove(sid) })
    if visible.get() {
      open()
    }
    parent.append_child(anchor)
    anchor
    },
  }
}

///|
/// 轻提示：返回推送函数 `push(text, t)`，每条 `duration_ms` 后自动移除，多条自上而下
/// 堆叠（整条带子居中显示在窗口顶部）。
///
/// 与 master 的一条差（记档）：旧链路返回「层节点 + 推送函数」、由调用方把层挂进
/// 页面树；本栈把这条带子开在**浮层图层**上（第一条推送时才开、最后一条撤下就收），
/// 于是提示永远压在对话框与其它浮层之上，也不必在页面里常驻一棵空树。入口因此
/// 只剩一个函数。没有浮层宿主时是空操作。
pub fn toast_layer(
  duration_ms? : Int = 2600,
) -> (String, SemanticType) -> Unit {
  let strip : Ref[@core.Widget?] = Ref(None)
  let open_id : Ref[Int] = Ref(0)
  let alive : Ref[Int] = Ref(0)
  let font = @text.Font::new("", 13.0)
  let strip_w = @core.Widget::new()
  strip_w.node.set_position(@yoga.Absolute)
  strip_w.node.set_top(@yoga.fixed(0.0))
  strip_w.node.set_left(@yoga.fixed(0.0))
  strip_w.node.set_right(@yoga.fixed(0.0))
  strip_w.node.set_flex_direction(@yoga.Column)
  strip_w.node.set_align_items(@yoga.AlignItems::Center)
  strip_w.set_padding(top=8.0)
  strip.val = Some(strip_w)
  let push : (String, SemanticType) -> Unit = fn(text : String, t : SemanticType) -> Unit {
    match strip.val {
      None => ()
      Some(c) => {
        if open_id.val == 0 {
          open_id.val = @core.overlay_show_full(@core.node_of(c))
        }
        let bar = @core.Widget::new()
        bar.node.set_width(@yoga.fixed(text_width(text, font) + 46.0))
        bar.node.set_height(@yoga.fixed(34.0))
        bar.set_margin(bottom=8.0)
        bar.on_draw = Some(fn(
          _s : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(@theme.theme_bg_panel())
          fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
          p.set_stroke_color(@theme.theme_border())
          p.set_line_width(1.0)
          p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
          let kind : @icons.IconKind = match t {
            Primary | Info => @icons.IconKind::InfoCircleFill
            Success => @icons.IconKind::CheckCircleFill
            Warning => @icons.IconKind::WarningCircleFill
            Danger => @icons.IconKind::CloseCircleFill
          }
          @icons.draw_icon(p, kind, 18.0, r.h / 2.0, 7.0, type_color(t))
          let _ = @text.draw_box_at(
            p,
            30.0,
            0.0,
            (r.w - 42.0).max(1.0),
            r.h,
            text,
            font,
            @theme.theme_text_regular(),
            align=@text.Start,
            valign=@text.Center,
          )
        })
        c.append_child(bar)
        alive.val = alive.val + 1
        @core.invalidate()
        let _ = @core.set_timeout(duration_ms, fn() {
          let _ = c.remove_child(bar)
          alive.val = alive.val - 1
          if alive.val <= 0 && open_id.val != 0 {
            @core.overlay_hide(open_id.val)
            open_id.val = 0
          }
          @core.invalidate()
        })
      }
    }
  }
  push
}

///|
/// 右键上下文菜单：给任意节点包一层，右键（`button == 3`）在指针处开自绘菜单，
/// `items` 是 (文案, 回调)，文案 `"-"` 画分隔线。
///
/// 右键走「祖先优先」派发（见 `core/widget.mbt` 的 `dispatch_on_path`）：
/// 上下文菜单是容器级能力，包在内层控件外面要能先拿到它——否则包住按钮时按钮
/// 先把按下吃掉，菜单永远弹不出来。
///
/// 与 master 的一条差（记档）：旧链路弹的是 GTK 原生菜单（`Menu::popup_at`）；
/// 自绘栈没有原生菜单，改成开在浮层图层上的自绘面板，位置按事件里的窗口坐标
/// （本栈指针事件本来就带窗口坐标，不必绕屏幕坐标）。
pub fn context_menu_for(
  content : @core.Node,
  items : Array[(String, () -> Unit)],
  width? : Double = 150.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let _ = content.mount_into(w)
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => {
          if ev.button != 3 {
            false
          } else {
            let rows : Array[@core.Node] = []
            for i = 0; i < items.length(); i = i + 1 {
              let entry = items[i]
              rows.push(
                menu_row(entry.0, fn() -> Unit {
                  @core.overlay_hide_top()
                  (entry.1)()
                }),
              )
            }
            let _ = @core.overlay_show_at(
              overlay_pane(rows, width, 0.0),
              self.rect.x + ev.x,
              self.rect.y + ev.y,
            )
            true
          }
        }
        @core.Up => ev.button == 3
        _ => false
      }
    })
    handle(w)
    w
  })
}
