// 自绘消息框（W21b）：`@ui` 层的模态对话框组件，**不依赖原生 `MessageBoxW`**，
// 三平台同构。与 W20d 的原生档（`@win.show_message_box`）并存，调用方按需选：
//  - 原生档：系统外观、系统模态、阻塞返回编号，但**只有 Win32 有**（macOS 留桩）；
//  - 本档：自绘外观（吃主题）、**非阻塞**（点按钮回调编号）、三平台同一份代码。
//
// 与 `dialog`（EP Dialog）的关系：两者都开在 `core/overlay.mbt` 的浮层图层
// 上，共享同一套遮罩/居中/点外收起机制；差在**语义面**——
//  - `dialog` 是「内容对话框」：调用方给任意内容树 + 确定/取消两个出口；
//  - `message_box` 是「消息框」：图标（按消息种类）+ 正文 + informative 副行 +
//    任意多个按钮（每个带自己的响应编号），对应旧链路 `MessageBox` 的
//    `set_title`/`set_text`/`set_informative_text`/`add_button(title, response)`/
//    `on_response` 语义面。
//
// 三条设计口径（写清以免后续被当 bug 改）：
// ① **响应编号由调用方给**（`add_button(title, response)` 同义），组件只把它原样
//    回传；这是「同义面」，不借用原生档 `MessageBoxResult` 的 1..7 编号——那套编号
//    是 Win32 的返回值口径，自绘档不该被它绑住。
// ② **✕ / Esc / 点遮罩 = 收起但不给响应编号**，走 `on_dismiss`。原生 `MessageBoxW`
//    的 ✕ 归 `IDCANCEL`，本档不这么借（见①）；要「取消也算一个结果」，调用方自己
//    放一个取消按钮即可。
// ③ **Enter = 第一个按钮**（与原生档 `default_index=0` 同义，也是双按钮时最左那个
//    的常见约定）；无按钮时等同 ✕。

///|
/// 消息框语义类型（与 W20d 原生档的 `@win.MessageBoxKind` 同义，但住组件层——
/// 本层不依赖平台包，三平台同构）。
pub(all) enum MsgBoxKind {
  Default
  Information
  Warning
  Question
  Error
}

///|
/// 消息种类 → 图标（`Default` 也画信息图标：不画会留下空白列，观感上像缺了东西）。
pub fn msgbox_icon_of(kind : MsgBoxKind) -> @icons.IconKind {
  match kind {
    Default => @icons.IconKind::InfoCircleFill
    Information => @icons.IconKind::InfoCircleFill
    Warning => @icons.IconKind::WarningCircleFill
    Question => @icons.IconKind::QuestionCircleFill
    Error => @icons.IconKind::CloseCircleFill
  }
}

///|
/// 消息种类 → 图标取色（Default/Information/Question 用主色，Warning 用警示色、
/// Error 用危险色——与 toast 的 `type_color` 同一套语义色）。
pub fn msgbox_icon_color_of(kind : MsgBoxKind) -> String {
  match kind {
    Default => @theme.theme_primary()
    Information => @theme.theme_primary()
    Warning => @theme.theme_warning()
    Question => @theme.theme_primary()
    Error => @theme.theme_danger()
  }
}

///|
/// 默认钮的响应编号（第一个按钮；空表给 0，调用方据此判「没有默认钮」）。
/// Enter 键与「默认聚焦哪个钮」都用它。
pub fn msgbox_default_code(buttons : Array[(String, Int)]) -> Int {
  if buttons.length() > 0 {
    buttons[0].1
  } else {
    0
  }
}

///|
/// 消息框的焦点 id 取号：从 700000 起（避开调用方常用的低号段，如示例里的
/// 1..25）。每次开层取一个、关层注销。
let msgbox_next_focus_id : Ref[Int] = Ref(700000)

fn msgbox_alloc_focus_id() -> Int {
  msgbox_next_focus_id.val = msgbox_next_focus_id.val + 1
  msgbox_next_focus_id.val
}

///|
/// 自绘消息框（模态，开在浮层图层上）。
///
/// - `visible`：`Store[Bool]` 驱动弹收（与 `dialog` 同制；开着时被图层收起也会
///   同步回 Store）。
/// - `kind`：决定左侧图标与取色。
/// - `text` 是正文；`informative` 是副行（次要色，可空）——对应旧链路的
///   `set_text` / `set_informative_text`。
/// - `buttons`：`(文案, 响应编号)` 列表，按给定顺序**从左到右**排（第一个是默认钮，
///   高亮成主色按钮）。文案传空串即跳过该钮。
/// - `on_response`：点按钮时回调其响应编号（先收起再回调）。
/// - `on_dismiss`：✕ / Esc / 点遮罩（`close_on_mask=true` 时）收起，不给编号。
/// - `close_on_mask`：点遮罩空白处是否收起（默认否——消息框通常要求显式作答）。
/// - `width`：面板固定宽（正文按它折行）。
pub fn message_box(
  visible : @core.Store[Bool],
  title : String,
  content : String,
  kind? : MsgBoxKind = Information,
  informative? : String = "",
  buttons? : Array[(String, Int)] = [("确定", 1)],
  on_response? : (Int) -> Unit = fn(_r : Int) -> Unit { () },
  on_dismiss? : () -> Unit = fn() -> Unit { () },
  close_on_mask? : Bool = false,
  width? : Double = 420.0,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  // 用显式 mount 而不是 `node_of_new`：后者的 finish 在构造期就跑，而「按 Store
  // 立刻开层」要求浮层宿主已经就位（宿主是 App 建窗时装的）。同 `dialog`。
  {
    mount: fn(parent : @core.Widget) -> @core.Widget {
      let anchor = @core.Widget::new()
      watch_theme()
      // 锚点是个 0 尺寸占位：可见性只由 Store 驱动，不在页面里占位
      anchor.node.set_height(@yoga.fixed(0.0))
      let open_id : Ref[Int] = Ref(0)
      let focus_id : Ref[Int] = Ref(0)
      let prev_focus : Ref[Int] = Ref(0)
      let icon_kind = msgbox_icon_of(kind)
      let icon_color = msgbox_icon_color_of(kind)
      let title_font = @text.Font::new("", 14.0, weight=@text.SemiBold)
      let btn_font = @text.Font::new("", 13.0)
      // 正文可用宽：面板宽 - 左内边距 16 - 图标 24 - 图标右边距 2 - 列间距 12
      // - 右内边距 16（面板宽度固定，正文靠这个值折行）
      let inner_w = (width - 70.0).max(80.0)
      // 收层：关浮层 + 还焦点。**幂等**（Store 订阅与按钮回调都会调它）
      let teardown_open = fn() -> Unit {
        if open_id.val != 0 {
          @core.overlay_hide(open_id.val)
          open_id.val = 0
        }
        if focus_id.val != 0 {
          match @core.host_active() {
            Some(a) => {
              a.focus.unregister(focus_id.val)
              // 还回开框前那个焦点（>0 才可能还在栈里；不在栈里时 focus 给 false，
              // 什么也不做，不会把焦点抢走）
              if prev_focus.val > 0 {
                let _ = a.focus.focus(prev_focus.val)
              }
            }
            None => ()
          }
          focus_id.val = 0
        }
      }
      let respond = fn(code : Int) -> Unit {
        // 先直接收层（不依赖 Store 真值到假值的跳变），再同步 Store（订阅里再收一次
        // 是幂等的），最后回调——口径与 `dialog` 的「三个出口都先收起再回调」一致
        teardown_open()
        visible.set(false)
        on_response(code)
      }
      let dismiss = fn() -> Unit {
        teardown_open()
        visible.set(false)
        on_dismiss()
      }
      let open = fn() -> Unit {
        if open_id.val != 0 {
          return
        }
        let panel = @core.Widget::new()
        let panel_node = @core.node_of(panel)
        // 遮罩：铺满窗口 + 吃下按下（视觉模态，点击不穿透到内容）
        let scrim = @core.node_of_new(fn(s : @core.Widget) -> @core.Widget {
          watch_theme()
          s.node.set_width(@yoga.percent(100.0))
          s.node.set_height(@yoga.percent(100.0))
          s.node.set_justify_content(@yoga.JustifyContent::Center)
          s.node.set_align_items(@yoga.AlignItems::Center)
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
                  dismiss()
                }
                false
              }
              _ => false
            }
          })
          let _ = panel_node.mount_into(s)
          s
        })
        // 标题栏：标题文字 + 右上角 ✕
        let title_bar = @core.Widget::new()
        title_bar.node.set_flex_direction(@yoga.Row)
        title_bar.node.set_height(@yoga.fixed(40.0))
        title_bar.node.set_align_items(@yoga.AlignItems::Center)
        title_bar.set_padding(left=16.0)
        @style.apply(
          title_bar,
          @style.merge_all([@style.style(color="text_primary"), paint_subset(class)]),
        )
        title_bar.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          let st = @style.style_for(self)
          let _ = @text.draw_box_at(
            p,
            16.0,
            0.0,
            (r.w - 48.0).max(1.0),
            r.h,
            title,
            title_font,
            @style.color_of(st.color, @theme.theme_text_primary()),
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
        @style.apply(
          close_btn,
          @style.merge_all([
            @style.style(color="text_secondary", border_radius=4.0).hover(background_color="fill_hover"),
            paint_subset(class),
          ]),
        )
        close_btn.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          let st = @style.style_for(self)
          let bg = @style.color_of(st.background_color, "")
          if bg.length() > 0 {
            p.set_fill_color(bg)
            fill_round_rect(p, 0.0, 0.0, r.w, r.h, @style.number_of(st.border_radius, 4.0))
          }
          p.set_stroke_color(@style.color_of(st.color, @theme.theme_text_secondary()))
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
              dismiss()
              false
            }
            _ => false
          }
        })
        // 正文区：图标 + (正文 / 副行)
        let body = @core.Widget::new()
        body.node.set_flex_direction(@yoga.Row)
        body.node.set_width(@yoga.percent(100.0))
        body.set_padding(top=14.0, left=16.0)
        body.node.set_gap(0.0, 12.0)
        body.node.set_align_items(@yoga.AlignItems::FlexStart)
        let icon_w = @core.Widget::new()
        icon_w.node.set_width(@yoga.fixed(24.0))
        icon_w.node.set_height(@yoga.fixed(24.0))
        icon_w.node.set_flex_shrink(0.0)
        icon_w.set_margin(right=2.0)
        // 语义图标色按 kind 定（数据态），折成 color 供绘制期读；class 给了 color 就盖过
        @style.apply(
          icon_w,
          @style.merge_all([
            match fg_block(icon_color) {
              Some(b) => b
              None => @style.empty_style()
            },
            paint_subset(class),
          ]),
        )
        icon_w.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          let st = @style.style_for(self)
          @icons.draw_icon(p, icon_kind, r.w / 2.0, r.h / 2.0, 11.0, @style.color_of(st.color, icon_color))
        })
        let col = @core.Widget::new()
        col.node.set_flex_direction(@yoga.Column)
        col.node.set_width(@yoga.fixed(inner_w))
        col.node.set_gap(6.0, 0.0)
        let _ = text(
          content,
          font_size=13.0,
          color="text_regular",
          wrap=true,
          max_width=inner_w,
        ).mount_into(col)
        if informative != "" {
          let _ = text(
            informative,
            font_size=12.0,
            color="text_secondary",
            wrap=true,
            max_width=inner_w,
          ).mount_into(col)
        }
        body.append_child(icon_w)
        body.append_child(col)
        // 按钮区：按给定顺序从左到右，第一个是默认钮（主色）
        let footer = @core.Widget::new()
        footer.node.set_flex_direction(@yoga.Row)
        footer.node.set_height(@yoga.fixed(52.0))
        footer.node.set_justify_content(@yoga.JustifyContent::FlexEnd)
        footer.node.set_align_items(@yoga.AlignItems::Center)
        footer.node.set_gap(0.0, 8.0)
        footer.set_padding(left=16.0)
        for i = 0; i < buttons.length(); i = i + 1 {
          let input = buttons[i]
          let code = input.1
          if input.0 == "" {
            continue
          }
          let primary = i == 0
          let b = @core.Widget::new()
          b.node.set_width(@yoga.fixed(text_width(input.0, btn_font) + 30.0))
          b.node.set_height(@yoga.fixed(30.0))
          b.node.set_flex_shrink(0.0)
          b.cursor = @core.CURSOR_HAND
          // 主/次两档皮肤折进槽：基块=常态、hover 桶=点亮态（与对话框底钮同形）
          let skin = if primary {
            @style.style(
              color="#ffffff",
              background_color="primary",
              border_color="border",
              border_width=1.0,
              border_radius=4.0,
            ).hover(background_color="primary_hover")
          } else {
            @style.style(
              color="text_regular",
              background_color="bg_panel",
              border_color="border",
              border_width=1.0,
              border_radius=4.0,
            ).hover(background_color="fill_hover")
          }
          @style.apply(b, @style.merge_all([skin, paint_subset(class)]))
          b.on_draw = Some(fn(
            self : @core.Widget,
            p : @render.Painter,
            r : @core.Rect,
          ) -> Unit {
            let st = @style.style_for(self)
            p.set_fill_color(
              @style.color_of(
                st.background_color,
                if primary { @theme.theme_primary() } else { @theme.theme_bg_panel() },
              ),
            )
            fill_round_rect(p, 0.0, 0.0, r.w, r.h, @style.number_of(st.border_radius, 4.0))
            p.set_stroke_color(@style.color_of(st.border_color, @theme.theme_border()))
            p.set_line_width(@style.number_of(st.border_width, 1.0))
            p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
            let _ = @text.draw_box_at(
              p,
              0.0,
              0.0,
              r.w,
              r.h,
              input.0,
              btn_font,
              @style.color_of(
                st.color,
                if primary { "#ffffff" } else { @theme.theme_text_regular() },
              ),
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
                respond(code)
                false
              }
              _ => false
            }
          })
          footer.append_child(b)
        }
        // 面板：主题面板底 + 描边 + 圆角，固定宽、按内容高
        panel.node.set_flex_direction(@yoga.Column)
        panel.node.set_width(@yoga.fixed(width))
        @style.apply(
          panel,
          @style.merge_all([
            @style.style(
              background_color="bg_panel",
              border_color="border",
              border_width=1.0,
              border_radius=6.0,
            ),
            paint_subset(class),
          ]),
        )
        panel.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          let st = @style.style_for(self)
          p.set_fill_color(@style.color_of(st.background_color, @theme.theme_bg_panel()))
          fill_round_rect(p, 0.0, 0.0, r.w, r.h, @style.number_of(st.border_radius, 6.0))
          p.set_stroke_color(@style.color_of(st.border_color, @theme.theme_border()))
          p.set_line_width(@style.number_of(st.border_width, 1.0))
          p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
        })
        // Esc 收起、Enter 触发默认钮：键盘事件按焦点投递，面板自己就是焦点控件
        // （层级上它比遮罩深，键先到它这里）
        panel.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
          if !ev.press {
            return false
          }
          if ev.keysym == @core.KS_ESCAPE {
            dismiss()
            true
          } else if ev.keysym == @core.KS_RETURN {
            // Enter = 第一个按钮（默认钮）；没有按钮时等同 ✕
            if buttons.length() > 0 {
              respond(msgbox_default_code(buttons))
            } else {
              dismiss()
            }
            true
          } else {
            false
          }
        })
        panel.append_child(title_bar)
        panel.append_child(close_btn)
        panel.append_child(body)
        panel.append_child(footer)
        // 接管焦点：Esc/Enter 要有落点。记住原焦点，收层时还回去。
        match @core.host_active() {
          Some(a) => {
            let fid = msgbox_alloc_focus_id()
            focus_id.val = fid
            panel.focus_id = fid
            match a.focus.current() {
              Some(p) => prev_focus.val = p
              None => prev_focus.val = 0
            }
            let _ = a.focus.register(fid)
            let _ = a.focus.focus(fid)
          }
          None => ()
        }
        open_id.val = @core.overlay_show_full(scrim)
        handle(anchor)
      }

      // Store 驱动：为真开层、为假收层（开着时被图层收起也要同步回 Store）
      let sig = visible.signal()
      let sid = sig.subscribe(fn(v : Bool) -> Unit {
        if v {
          open()
        } else {
          teardown_open()
        }
      })
      @core.sub_bag_register(fn() { sig.remove(sid) })
      if visible.get() {
        open()
      }
      parent.append_child(anchor)
      fold_style(anchor, @style.empty_style(), class)
      anchor
    },
  }
}
