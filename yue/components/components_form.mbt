// 表单组件:button / entry / checkbox / radio / switch / input / form / link / textarea / slider / select / rate / color_picker。

///|
/// 按钮变体:Solid 主题色实底白字 / Soft 浅底主题色字 /
/// Text 透明底主题色字 / Danger 红色实底白字。
pub(all) enum ButtonVariant {
  Solid
  Soft
  Text
  Danger
}

///|
/// 按钮配色求解:color / background_color 传非空为显式覆盖(所有状态
/// 一致,hover 不再变色);未传按 variant + hover 走预设
/// (background_color 为 "" 即无底,Text 常态)。
fn button_colors(
  variant : ButtonVariant,
  hover : Bool,
  color : String,
  background_color : String,
) -> (String, String) {
  let fg_eff = if color != "" {
    color
  } else {
    match variant {
      Solid => "#FFFFFF"
      Soft => if hover { "#FFFFFF" } else { @yue.theme_primary() }
      Text => @yue.theme_primary()
      Danger => "#FFFFFF"
    }
  }
  let bg_eff = if background_color != "" {
    background_color
  } else {
    match variant {
      Solid =>
        if hover {
          @yue.theme_primary_hover()
        } else {
          @yue.theme_primary()
        }
      Soft =>
        if hover {
          @yue.theme_primary()
        } else {
          @yue.theme_primary_light()
        }
      Text => if hover { @yue.theme_fill_hover() } else { "" }
      Danger =>
        if hover {
          @yue.theme_danger_hover()
        } else {
          @yue.theme_danger()
        }
    }
  }
  (fg_eff, bg_eff)
}

///|
/// 主题化按钮(自绘,hover 全程收敛在主题内,不交给原生样式):
/// Solid hover 加深 / Soft hover 变实底白字 / Text hover 浅灰底 /
/// Danger hover 加深。color / background_color 传非空即覆盖文字色 /
/// 底色(所有状态生效,hover 不再变色);不传则按 variant 预设。
pub fn button_t(
  text : String,
  on_click? : () -> Unit = fn() {  },
  variant? : ButtonVariant = Soft,
  color? : String = "",
  background_color? : String = "",
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let focused = Ref(false)
      let font = @yue.Font::new("Sans", 13.0)
      let probe = @yue.AttributedText::new(text, wrap=false)
      probe.set_font(font)
      let text_w = probe.get_bounds_for(10000.0, 100.0).width
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", text_w + 32.0),
        ("height", @yue.control_height),
        ("marginRight", 8.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = @yue.themed_container(style=base)
      handle(v)
      v.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(v)
        let (fg_c, bg_c) = button_colors(
          variant,
          hover.val,
          color,
          background_color,
        )
        if bg_c != "" {
          p.set_fill_color(bg_c)
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        // GTK 端 DrawAttributedText 只实现 valign,水平 align 无效——
        // 用 mount 时测的文本宽手动水平居中。
        let at = @yue.AttributedText::new(text, valign=@yue.Center, wrap=false)
        at.set_font(font)
        at.set_color(fg_c)
        p.draw_attributed_text(
          at,
          (b.width - text_w) / 2.0,
          0.0,
          b.width,
          b.height,
        )
        // 实底变体上主题色环不可见,焦点环用白色
        if focused.val {
          @yue.draw_focus_ring(
            p,
            b.width,
            b.height,
            color=match variant {
              Solid => "#FFFFFF"
              Danger => "#FFFFFF"
              _ => @yue.theme_primary()
            },
          )
        }
      })
      @yue.View::set_cursor(v, @yue.hand())
      @yue.ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(v)
          on_click()
          true
        } else {
          false
        }
      })
      @yue.bind_focus(
        v,
        fn() { @yue.ViewLike::schedule_paint(v) },
        focused,
        on_click,
      )
      @yue.ViewLike::on_mouse_enter(v, fn(_e) {
        hover.val = true
        @yue.ViewLike::schedule_paint(v)
      })
      @yue.ViewLike::on_mouse_leave(v, fn(_e) {
        hover.val = false
        @yue.ViewLike::schedule_paint(v)
      })
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}

///|
/// Windows 原生单行输入文字贴顶(Win32 EDIT 自客户区顶部绘制,无垂直
/// 居中样式):控件高度收窄到「行高(带原生边框时 +1px×2)」,文字即
/// 在控件内天然居中;外层容器用 justifyContent=center 让控件垂直居中
/// (布局语义,适配任意高度值)。返回收窄后的控件高度。

///|
/// 输入框文字色跟随主题:Linux 由全局接管 CSS 负责,不逐控件设;其余
/// 平台显式设当前主题前景/背景并订阅主题切换重设(Windows 原生
/// RichEdit 恒黑字不随主题,是此函数存在的原因)。

///|
/// 主题化单行输入:统一字体与行高;文字色经主题通道跟随色板。
/// 样式作用于 Entry 本体;Windows 文字贴顶,改为外包居中容器
/// (Entry 收窄到行高,容器 justifyContent=center),样式落容器。
pub fn entry_t(
  text? : String = "",
  password? : Bool = false,
  on_input? : (String) -> Unit = fn(_s) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Entry) -> Unit = fn(_e) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let e = match password {
        true => @yue.Entry::make(text~, entry_type=@yue.Password)
        false => @yue.Entry::make(text~, entry_type=@yue.Normal)
      }
      @yue.ViewLike::set_font(e, @yue.Font::new("Sans", 13.0))
      let base : Array[(String, &@yue.StyVal)] = [
        ("height", @yue.control_height),
      ]
      for kv in style {
        base.push(kv)
      }
      let target : @yue.View = if @yue.platform() == "windows" {
        // Linux 端 Entry 尺寸已归一化(min-height:0),补显式高度维持观感;
        // Windows 收窄控件到行高 + 外包居中容器(布局语义,适配任意高度)
        @yue.ViewLike::set_style(e, "height", @yue.entry_ctrl_height(true))
        let shell_style = base.copy()
        shell_style.push(("justifyContent", "center"))
        let shell = @yue.themed_container(style=shell_style)
        @yue.attach(@yue.ViewLike::view(shell), @yue.ViewLike::view(e))
        @yue.ViewLike::view(shell)
      } else {
        @yue.apply_style(e, style=base)
        @yue.ViewLike::view(e)
      }
      @yue.bind_entry_theme(e)
      e.on_text_change(fn() { on_input(e.get_text()) })
      handle(e)
      @yue.attach(parent, target)
      target
    },
  }
}

///|
/// 主题化复选框(自绘,替代原生控件:GTK 原生 Checkbox 的 hover 高亮圈
/// 与直角主题冲突):14x14 直角方框,选中实心主题色 + 白勾,
/// hover 边框变主题色,含禁用态。
pub fn checkbox_t(
  title : String,
  checked? : Bool = false,
  disabled? : Bool = false,
  color? : String = "",
  on_change? : (Bool) -> Unit = fn(_v) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let state = Ref(checked)
      let hover = Ref(false)
      let focused = Ref(false)
      let font = @yue.Font::new("Sans", 13.0)
      let probe = @yue.AttributedText::new(title, wrap=false)
      probe.set_font(font)
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", probe.get_bounds_for(10000.0, 100.0).width + 30.0),
        ("height", 24.0),
        ("marginBottom", 6.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = @yue.themed_container(style=base)
      handle(v)
      let activate = fn() -> Unit {
        state.val = !state.val
        on_change(state.val)
        @yue.ViewLike::schedule_paint(v)
      }

      v.on_draw(fn(p) {
        let by = 5.0
        p.set_stroke_color(
          if disabled {
            @yue.theme_border()
          } else if state.val || hover.val {
            @yue.theme_primary()
          } else {
            @yue.theme_border()
          },
        )
        p.stroke_rect(3.5, by + 0.5, 13.0, 13.0)
        if state.val {
          p.set_fill_color(
            if disabled {
              @yue.theme_border()
            } else {
              @yue.theme_primary()
            },
          )
          p.fill_rect(5.0, by + 2.0, 10.0, 10.0)
          // 白勾:折线两段,描两遍(错位 0.5px)近似 2px 线宽,不依赖字体
          p.set_stroke_color("#FFFFFF")
          for off in [0.0, 0.5] {
            p.begin_path()
            p.move_to(6.9 + off, by + 7.4)
            p.line_to(9.0 + off, by + 9.5)
            p.line_to(13.8 + off, by + 4.4)
            p.stroke()
          }
        }
        let b = @yue.ViewLike::get_bounds(v)
        let at = @yue.AttributedText::new(title, valign=@yue.Center, wrap=false)
        at.set_font(font)
        at.set_color(
          if disabled {
            @yue.theme_border()
          } else if color != "" {
            color
          } else {
            @yue.theme_text_regular()
          },
        )
        p.draw_attributed_text(at, 25.0, 0.0, b.width, b.height)
        if focused.val {
          @yue.draw_focus_ring(p, b.width, b.height)
        }
      })
      let repaint = fn() -> Unit {
        if !disabled {
          @yue.ViewLike::schedule_paint(v)
        }
      }
      @yue.View::set_cursor(v, @yue.hand())
      @yue.ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 && !disabled {
          @yue.ViewLike::focus(v)
          activate()
          true
        } else {
          false
        }
      })
      @yue.ViewLike::on_mouse_enter(v, fn(_e) {
        hover.val = true
        repaint()
      })
      @yue.ViewLike::on_mouse_leave(v, fn(_e) {
        hover.val = false
        repaint()
      })
      if !disabled {
        @yue.bind_focus(v, repaint, focused, activate)
      }
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}

///|
/// 单选组:选中项实心方块 + 主题色文字,未选中空心方块,点击互斥。
/// 整行自绘(文字不挂子件,hover 全行生效);GTK 端原生 Radio 不共享组
/// 无法互斥,故自绘指示器。
pub fn radio_group(
  options : Array[String],
  selected : @yue.Store[String],
  disabled? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("marginBottom", 10.0),
        ("flexDirection", "column"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let font = @yue.Font::new("Sans", 13.0)
      let rows : Array[@yue.Container] = []
      let mut idx = 0
      for opt in options {
        let i = idx
        let probe = @yue.AttributedText::new(opt, wrap=false)
        probe.set_font(font)
        let w = probe.get_bounds_for(10000.0, 100.0).width + 30.0
        let hover = Ref(false)
        let focused = Ref(false)
        let row = @yue.themed_container(style=[("width", w), ("height", 28.0)])
        let activate = fn() -> Unit { selected.set(opt) }

        row.on_draw(fn(p) {
          let act = selected.get() == opt
          p.set_stroke_color(
            if disabled {
              @yue.theme_border()
            } else if act || hover.val {
              @yue.theme_primary()
            } else {
              @yue.theme_border()
            },
          )
          p.stroke_rect(3.5, 7.5, 13.0, 13.0)
          if act {
            p.set_fill_color(
              if disabled {
                @yue.theme_border()
              } else {
                @yue.theme_primary()
              },
            )
            p.fill_rect(7.0, 11.0, 6.0, 6.0)
          }
          let at = @yue.AttributedText::new(opt, valign=@yue.Center, wrap=false)
          at.set_font(font)
          at.set_color(
            if disabled {
              @yue.theme_border()
            } else if act {
              @yue.theme_text_primary()
            } else if hover.val {
              @yue.theme_primary()
            } else {
              @yue.theme_text_regular()
            },
          )
          p.draw_attributed_text(at, 25.0, 0.0, w, 28.0)
          if focused.val {
            @yue.draw_focus_ring(p, w, 28.0)
          }
        })
        let repaint = fn() -> Unit {
          if !disabled {
            @yue.ViewLike::schedule_paint(row)
          }
        }
        @yue.View::set_cursor(row, @yue.hand())
        @yue.ViewLike::on_mouse_down(row, fn(e) {
          if e.button == 1 && !disabled {
            @yue.ViewLike::focus(row)
            activate()
            true
          } else {
            false
          }
        })
        @yue.ViewLike::on_mouse_enter(row, fn(_e) {
          hover.val = true
          repaint()
        })
        @yue.ViewLike::on_mouse_leave(row, fn(_e) {
          hover.val = false
          repaint()
        })
        if !disabled {
          @yue.ViewLike::set_focusable(row, true)
          @yue.ViewLike::on_focus_in(row, fn() {
            focused.val = true
            repaint()
            false
          })
          @yue.ViewLike::on_focus_out(row, fn() {
            focused.val = false
            repaint()
            false
          })
          // Enter/Space 选中;方向键在组内移动选中并跟随焦点
          @yue.ViewLike::on_key_down(row, fn(e) {
            if e.code == @yue.VKEY_RETURN || e.code == @yue.VKEY_SPACE {
              activate()
              true
            } else if e.code == @yue.VKEY_DOWN || e.code == @yue.VKEY_RIGHT {
              if i + 1 < options.length() {
                selected.set(options[i + 1])
                @yue.ViewLike::focus(rows[i + 1])
                true
              } else {
                false
              }
            } else if e.code == @yue.VKEY_UP || e.code == @yue.VKEY_LEFT {
              if i > 0 {
                selected.set(options[i - 1])
                @yue.ViewLike::focus(rows[i - 1])
                true
              } else {
                false
              }
            } else {
              false
            }
          })
        }
        selected.subscribe(fn(_s) { repaint() })
        rows.push(row)
        outer.add_child(row)
        idx = idx + 1
      }
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 开关(EP Switch 的直角形态):轨道 + 滑块,开=主题蓝轨道滑块靠右,
/// 关=浅灰轨道滑块靠左;点击切换,状态存于 Store[Bool]。
pub fn switch_t(
  checked : @yue.Store[Bool],
  disabled? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", 40.0),
        ("height", 18.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = @yue.themed_container(style=base)
      handle(v)
      let focused = Ref(false)
      let activate = fn() -> Unit { checked.set(!checked.get()) }

      let slider_w = 14.0
      v.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(v)
        let on = checked.get()
        p.set_fill_color(
          if on {
            @yue.theme_primary()
          } else {
            @yue.theme_border()
          },
        )
        p.fill_rect(0.0, 0.0, b.width, b.height)
        let sx = if on { b.width - slider_w - 2.0 } else { 2.0 }
        p.set_fill_color(
          if disabled {
            @yue.theme_info_light()
          } else {
            @yue.theme_bg_panel()
          },
        )
        p.fill_rect(sx, 2.0, slider_w, b.height - 4.0)
        if focused.val {
          @yue.draw_focus_ring(p, b.width, b.height)
        }
      })
      @yue.View::set_cursor(v, @yue.hand())
      @yue.ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 && !disabled {
          @yue.ViewLike::focus(v)
          activate()
          true
        } else {
          false
        }
      })
      checked.subscribe(fn(_v) { @yue.ViewLike::schedule_paint(v) })
      if !disabled {
        @yue.bind_focus(
          v,
          fn() { @yue.ViewLike::schedule_paint(v) },
          focused,
          activate,
        )
      }
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}

///|
/// 边框输入框:外层自绘 1px 边框(聚焦变主题色)+ 白底,
/// 内部 Entry 去 native 边框只负责文字;margin 控制外边距,直角。
/// clearable=true 时字段悬停且非空,右侧显示 ✕,点击清空文本
/// (Entry 右侧恒定留出清空带——原生子窗口盖在自绘之上,带内不重叠)。
pub fn input_t(
  text? : String = "",
  password? : Bool = false,
  clearable? : Bool = false,
  on_input? : (String) -> Unit = fn(_s) {  },
  invalid? : @yue.Store[Bool] = @yue.Store::new(false),
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      let hover = Ref(false)
      let has_text = Ref(text != "")
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", 280.0),
        ("height", @yue.control_height),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      @yue.set_panel_bg(outer)
      outer.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(outer)
        p.set_stroke_color(
          if invalid.get() {
            @yue.theme_danger()
          } else if focused.val {
            @yue.theme_focus_accent()
          } else {
            @yue.theme_border()
          },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        if clearable && hover.val && has_text.val {
          draw_clear_x(p, b.width - 12.0, b.height / 2.0)
        }
      })
      invalid.subscribe(fn(_v) { @yue.ViewLike::schedule_paint(outer) })
      let entry = match password {
        true => @yue.Entry::make(text~, entry_type=@yue.Password)
        false => @yue.Entry::make(text~, entry_type=@yue.Normal)
      }
      @yue.ViewLike::set_borderless(entry, true)
      @yue.set_panel_bg(entry)
      @yue.ViewLike::set_style(entry, "marginLeft", 10.0)
      @yue.ViewLike::set_style(
        entry,
        "marginRight",
        if clearable {
          26.0
        } else {
          10.0
        },
      )
      if @yue.platform() == "windows" {
        // 文字贴顶:控件收窄到行高,外层 justifyContent=center 垂直居中
        @yue.ViewLike::set_style(entry, "height", @yue.entry_ctrl_height(false))
        @yue.ViewLike::set_style_str(outer, "justifyContent", "center")
      } else {
        // 高度撑满 + 原生子窗口绘制在自绘之上:上下留 2 让出边框线
        @yue.ViewLike::set_style(entry, "flex", 1.0)
        @yue.ViewLike::set_style(entry, "marginTop", 2.0)
        @yue.ViewLike::set_style(entry, "marginBottom", 2.0)
      }
      @yue.bind_entry_theme(entry)
      @yue.ViewLike::on_focus_in(entry, fn() {
        focused.val = true
        @yue.ViewLike::schedule_paint(outer)
        false
      })
      @yue.ViewLike::on_focus_out(entry, fn() {
        focused.val = false
        @yue.ViewLike::schedule_paint(outer)
        // 光标归 0:文本滚回首端,溢出裁切固定发生在右缘,左侧不再出现
        // 随光标位置变化的余量
        entry.set_position(0)
        false
      })
      entry.on_text_change(fn() {
        let cur = entry.get_text()
        has_text.val = cur != ""
        on_input(cur)
        @yue.ViewLike::schedule_paint(outer)
      })
      if clearable {
        @yue.ViewLike::on_mouse_enter(outer, fn(_e) {
          hover.val = true
          @yue.ViewLike::schedule_paint(outer)
        })
        @yue.ViewLike::on_mouse_leave(outer, fn(_e) {
          hover.val = false
          @yue.ViewLike::schedule_paint(outer)
        })
        // 清空带不与 Entry 重叠(其事件窗口只覆盖原生子窗口之外的区域),
        // 点击落在带上即清空
        @yue.ViewLike::on_mouse_up(outer, fn(e) {
          let b = @yue.ViewLike::get_bounds(outer)
          if e.button == 1 && has_text.val && e.view_x >= b.width - 24.0 {
            entry.set_text("")
            has_text.val = false
            // SetText 不触发 on_text_change(fork 的 is-editing 守卫吞掉
            // changed 信号,防编程式设置回环):清空后必须显式补一次回调,
            // 否则使用方的过滤条件不更新(文本没了列表不变)
            on_input("")
            @yue.ViewLike::schedule_paint(outer)
            true
          } else {
            false
          }
        })
      }
      outer.add_child(entry)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 数字输入器(EP InputNumber):-/+ 按钮步进,范围钳制,状态存 Store[Double]。
pub fn input_number(
  value : @yue.Store[Double],
  min? : Double = 0.0,
  max? : Double = 100.0,
  step? : Double = 1.0,
  num_width? : Double = 64.0,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [
        ("height", @yue.control_height),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ]
      for kv in style {
        base.push(kv)
      }
      let row = @yue.themed_container(style=base)
      handle(row)
      let font = @yue.Font::new("Sans", 13.0)
      fn step_btn(dir : Double) -> Unit {
        let b = @yue.themed_container(style=[
          ("width", 28.0),
          ("height", @yue.control_height),
          ("alignItems", "center"),
        ])
        @yue.bind_bg(b, fn() { @yue.theme_info_light() })
        let hover = Ref(false)
        b.on_draw(fn(p) {
          let bd = @yue.ViewLike::get_bounds(b)
          p.set_fill_color(
            if hover.val {
              @yue.theme_primary_light()
            } else {
              @yue.theme_info_light()
            },
          )
          p.fill_rect(0.0, 0.0, bd.width, bd.height)
          // +/− 矢量自绘(字形图标跨平台发虚,GTK align 亦无效)
          if dir > 0.0 {
            draw_glyph_plus(
              p,
              bd.width / 2.0,
              bd.height / 2.0,
              4.0,
              @yue.theme_text_regular(),
            )
          } else {
            draw_glyph_minus(
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
            value.update(fn(n) {
              let m = n + dir * step
              if m < min {
                min
              } else if m > max {
                max
              } else {
                m
              }
            })
            true
          } else {
            false
          }
        })
        @yue.ViewLike::on_mouse_enter(b, fn(_e) {
          hover.val = true
          @yue.ViewLike::schedule_paint(b)
        })
        @yue.ViewLike::on_mouse_leave(b, fn(_e) {
          hover.val = false
          @yue.ViewLike::schedule_paint(b)
        })
        row.add_child(b)
      }

      step_btn(-1.0)
      // marginRight 0:EP InputNumber 的按钮与输入区紧贴
      let num = @yue.themed_container(style=[
        ("width", num_width),
        ("height", @yue.control_height),
        ("marginRight", 0.0),
        ("alignItems", "center"),
      ])
      @yue.set_panel_bg(num)
      let t = @yue.AttributedText::new(
        value.get().to_string(),
        valign=@yue.Center,
        wrap=false,
      )
      t.set_font(font)
      t.set_color(@yue.theme_text_primary())
      num.on_draw(fn(p) {
        // GTK 端 DrawAttributedText 不实现水平 align,手动测宽居中
        let b = @yue.ViewLike::get_bounds(num)
        let tw = t.get_bounds_for(10000.0, 100.0).width
        p.draw_attributed_text(t, (b.width - tw) / 2.0, 0.0, b.width, b.height)
      })
      value.subscribe(fn(v) {
        t.set_text(v.to_string())
        @yue.ViewLike::schedule_paint(num)
      })
      row.add_child(num)
      step_btn(1.0)
      @yue.attach(parent, @yue.ViewLike::view(row))
      @yue.ViewLike::view(row)
    },
  }
}

///|
/// 表单项:左侧标签(灰,定宽)+ 右侧控件区,垂直居中。error 为校验
/// 错误文案 Store:非空时控件行下方显示 danger 红字;行高固定预留,
/// 错误出现/消失不引起布局跳动。
pub fn form_item(
  label : String,
  control : @yue.Node,
  label_width? : Double = 90.0,
  error? : @yue.Store[String] = @yue.Store::new(""),
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &@yue.StyVal)] = [("flexDirection", "column")]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      let row = @yue.themed_container(style=[
        ("marginBottom", 2.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ])
      let k = @yue.Label::new(label)
      @yue.ViewLike::set_font(k, @yue.Font::new("Sans", 13.0))
      @yue.bind_fg(k, fn() { @yue.theme_text_secondary() })
      k.set_align(@yue.End)
      let kwrap = @yue.themed_container(style=[
        ("width", label_width),
        ("marginRight", 12.0),
      ])
      kwrap.add_child(k)
      row.add_child(kwrap)
      ignore((control.mount)(@yue.ViewLike::view(row)))
      outer.add_child(row)
      let err = @yue.Label::new(error.get())
      @yue.ViewLike::set_font(err, @yue.Font::new("Sans", 12.0))
      @yue.bind_fg(err, fn() { @yue.theme_danger() })
      @yue.ViewLike::set_style(err, "height", 18.0)
      @yue.ViewLike::set_style(err, "marginLeft", label_width + 12.0)
      outer.add_child(err)
      error.subscribe(fn(msg) {
        // 红字色固定由 bind_fg 管,set_color 反而错(参数是颜色不是
        // 文本);set_text 只标脏不重排,须补强制重排否则变长截断
        err.set_text(msg)
        @yue.ViewLike::update_layout(err)
      })
      let spacer = @yue.themed_container(style=[("height", 8.0)])
      outer.add_child(spacer)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 表单:分组标题 + 一组表单项。
pub fn form(
  title : String,
  items : Array[@yue.Node],
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  let nodes : Array[@yue.Node] = [
    label_t(title, role=Section, style=[("marginBottom", 10.0)]),
  ]
  for it in items {
    nodes.push(it)
  }
  let base : Array[(String, &@yue.StyVal)] = [("marginBottom", 10.0)]
  for kv in style {
    base.push(kv)
  }
  @declarative.vbox(nodes, style=base)
}

///|
/// 链接文字:主题色,悬停加深并显示下划线色条,点击回调。
pub fn link(
  text : String,
  on_click : () -> Unit,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let base : Array[(String, &@yue.StyVal)] = [
        ("paddingRight", 6.0),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ]
      for kv in style {
        base.push(kv)
      }
      let row = @yue.themed_container(style=base)
      handle(row)
      let l = @yue.Label::new(text)
      @yue.ViewLike::set_font(l, @yue.Font::new("Sans", 13.0))
      fn apply_color() -> Unit {
        @yue.ViewLike::set_color(l, @yue.theme_primary())
        l.set_text(l.get_text())
      }

      apply_color()
      ignore(@yue.on_theme_change(apply_color))
      row.add_child(l)
      let underline = @yue.themed_container(style=[("height", 1.0)])
      @yue.bind_bg(underline, fn() { @yue.theme_primary() })
      row.add_child(underline)
      fn apply() -> Unit {
        @yue.ViewLike::set_visible(underline, hover.val)
      }

      apply()
      @yue.ViewLike::on_mouse_enter(row, fn(_e) {
        hover.val = true
        apply()
      })
      @yue.ViewLike::on_mouse_leave(row, fn(_e) {
        hover.val = false
        apply()
      })
      @yue.View::set_cursor(row, @yue.hand())
      @yue.ViewLike::on_mouse_down(row, fn(e) {
        if e.button == 1 {
          on_click()
          true
        } else {
          false
        }
      })
      @yue.attach(parent, @yue.ViewLike::view(row))
      @yue.ViewLike::view(row)
    },
  }
}

///|
/// 多行输入(EP Input textarea 形态,input_t 同套路):外层自绘 1px 边框
/// (聚焦变主题色)+ 内边距,内部 TextEdit 去 native 边框只负责文字,
/// 内容超出按平台自身滚动(GTK TextView/RichEdit 滚轮)。文本变化经
/// on_input 回调。clearable=true 时字段悬停且非空,右侧显示 ✕,
/// 点击清空文本(on_input 收到空串)。
pub fn textarea_t(
  text? : String = "",
  on_input? : (String) -> Unit = fn(_s) {  },
  clearable? : Bool = false,
  invalid? : @yue.Store[Bool] = @yue.Store::new(false),
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      let hover = Ref(false)
      let has_text = Ref(text != "")
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", 280.0),
        ("height", 110.0),
        ("padding", 10.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      @yue.set_panel_bg(outer)
      outer.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(outer)
        p.set_stroke_color(
          if invalid.get() {
            @yue.theme_danger()
          } else if focused.val {
            @yue.theme_focus_accent()
          } else {
            @yue.theme_border()
          },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        if clearable && hover.val && has_text.val {
          draw_clear_x(p, b.width - 20.0, b.height / 2.0)
        }
      })
      invalid.subscribe(fn(_v) { @yue.ViewLike::schedule_paint(outer) })
      let edit = @yue.TextEdit::new()
      edit.set_text(text)
      @yue.ViewLike::set_font(edit, @yue.Font::new("Sans", 13.0))
      @yue.ViewLike::set_borderless(edit, true)
      @yue.set_panel_bg(edit)
      @yue.ViewLike::set_style(edit, "flex", 1.0)
      if clearable {
        @yue.ViewLike::set_style(edit, "marginRight", 24.0)
      }
      edit.on_text_change(fn() {
        if clearable {
          has_text.val = edit.get_text() != ""
          @yue.ViewLike::schedule_paint(outer)
        }
        on_input(edit.get_text())
      })
      @yue.ViewLike::on_focus_in(edit, fn() {
        focused.val = true
        @yue.ViewLike::schedule_paint(outer)
        false
      })
      @yue.ViewLike::on_focus_out(edit, fn() {
        focused.val = false
        @yue.ViewLike::schedule_paint(outer)
        false
      })
      if clearable {
        @yue.ViewLike::on_mouse_enter(outer, fn(_e) {
          hover.val = true
          @yue.ViewLike::schedule_paint(outer)
        })
        @yue.ViewLike::on_mouse_leave(outer, fn(_e) {
          hover.val = false
          @yue.ViewLike::schedule_paint(outer)
        })
        @yue.ViewLike::on_mouse_up(outer, fn(e) {
          let b = @yue.ViewLike::get_bounds(outer)
          if e.button == 1 && has_text.val && e.view_x >= b.width - 32.0 {
            edit.set_text("")
            true
          } else {
            false
          }
        })
      }
      outer.add_child(edit)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 滑杆(EP Slider,自绘):浅灰轨道 + 主题色填充段 + 方形 thumb,支持
/// 点击轨道/拖拽 thumb 调值,值按 step 量化后写入 value(Store[Double]),
/// 外部 set 同样生效。on_change 在值变化时回调(含拖拽过程)。
/// bar_color/track_color 自定义填充/轨道色(空=主题色,深色遮盖层上的
/// 白色滑杆用)。
pub fn slider_t(
  value : @yue.Store[Double],
  min? : Double = 0.0,
  max? : Double = 100.0,
  step? : Double = 1.0,
  on_change? : (Double) -> Unit = fn(_v) {  },
  bar_color? : String = "",
  track_color? : String = "",
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let h = 24.0
      let track_h = 4.0
      let thumb = 12.0
      let dragging = Ref(false)
      let hover = Ref(false)
      // 默认横向自适应父容器宽:grow/shrink 单写(column 父 auto 高链下
      // 简写派生 basis 0 会盖掉 height 塌成 0 高);定宽由调用方
      // style=[("flexgrow", 0.0), ("width", w)] 覆盖
      let base : Array[(String, &@yue.StyVal)] = [
        ("flexgrow", 1.0),
        ("flexshrink", 1.0),
        ("height", h),
        ("marginBottom", 10.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = @yue.themed_container(style=base)
      handle(v)
      fn clamp01(x : Double) -> Double {
        if x < 0.0 {
          0.0
        } else if x > 1.0 {
          1.0
        } else {
          x
        }
      }

      fn ratio_of(val : Double) -> Double {
        if max <= min {
          return 0.0
        }
        clamp01((val - min) / (max - min))
      }

      // 值按 step 量化(对齐到网格,再回钳范围)
      fn quantize(val : Double) -> Double {
        if step <= 0.0 {
          return val
        }
        let k = ((val - min) / step).round()
        let q = min + k * step
        if q < min {
          min
        } else if q > max {
          max
        } else {
          q
        }
      }

      fn set_from_x(x : Double) -> Unit {
        let w = @yue.ViewLike::get_bounds(v).width
        let r = clamp01((x - thumb / 2.0) / (w - thumb))
        value.set(quantize(min + r * (max - min)))
      }

      v.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(v)
        let w = b.width
        let ratio = ratio_of(value.get())
        let ty = (h - track_h) / 2.0
        // 轨道底用 border 灰:白底上的浅斑马纹几乎不可见,
        // 轨道必须整条可见才能读出滑杆长度
        p.set_fill_color(
          if track_color == "" {
            @yue.theme_border()
          } else {
            track_color
          },
        )
        p.fill_rect(0.0, ty, w, track_h)
        p.set_fill_color(
          if bar_color == "" {
            @yue.theme_primary()
          } else {
            bar_color
          },
        )
        p.fill_rect(0.0, ty, ratio * (w - thumb) + thumb / 2.0, track_h)
        // thumb:主题色实心方块,hover/拖拽加深
        let tx = ratio * (w - thumb)
        if bar_color == "" {
          p.set_fill_color(
            if hover.val || dragging.val {
              @yue.theme_primary_hover()
            } else {
              @yue.theme_primary()
            },
          )
        } else {
          p.set_fill_color(bar_color)
        }
        p.fill_rect(tx, (h - thumb) / 2.0, thumb, thumb)
      })
      @yue.View::set_cursor(v, @yue.hand())
      @yue.ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 {
          dragging.val = true
          @yue.ViewLike::set_capture(v)
          set_from_x(e.view_x)
          true
        } else {
          false
        }
      })
      @yue.ViewLike::on_mouse_move(v, fn(e) {
        if dragging.val {
          set_from_x(e.view_x)
        }
      })
      @yue.ViewLike::on_mouse_up(v, fn(_e) {
        if dragging.val {
          dragging.val = false
          @yue.ViewLike::release_capture(v)
          true
        } else {
          false
        }
      })
      @yue.ViewLike::on_mouse_enter(v, fn(_e) {
        hover.val = true
        @yue.ViewLike::schedule_paint(v)
      })
      @yue.ViewLike::on_mouse_leave(v, fn(_e) {
        hover.val = false
        @yue.ViewLike::schedule_paint(v)
      })
      @yue.ViewLike::on_focus_out(v, fn() {
        if dragging.val {
          dragging.val = false
          @yue.ViewLike::release_capture(v)
        }
        false
      })
      value.subscribe(fn(new_v) {
        on_change(new_v)
        @yue.ViewLike::schedule_paint(v)
      })
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}

///|
/// 下拉候选行(EP 样式,select_t 各平台共用):当前选中浅蓝底 + 主题色字 +
/// 右侧 ✓,hover/键盘高亮灰底。mark 为键盘高亮标记(非鼠标路径)。
fn select_row(
  opt : String,
  value : @yue.Store[String],
  on_pick : () -> Unit,
) -> @yue.Container {
  let row = @yue.themed_container(style=[
    ("height", 28.0),
    ("paddingLeft", 8.0),
    ("flexDirection", "row"),
    ("alignItems", "center"),
  ])
  let hover = Ref(false)
  row.on_draw(fn(p) {
    let b = @yue.ViewLike::get_bounds(row)
    let act = value.get() == opt
    if act {
      p.set_fill_color(@yue.theme_primary_light())
      p.fill_rect(0.0, 0.0, b.width, b.height)
    } else if hover.val {
      p.set_fill_color(@yue.theme_fill_hover())
      p.fill_rect(0.0, 0.0, b.width, b.height)
    }
    p.draw_text(
      opt,
      8.0,
      0.0,
      b.width - 26.0,
      b.height,
      valign=@yue.Center,
      color=if act { @yue.theme_primary() } else { @yue.theme_text_regular() },
    )
    if act {
      // 选中项右侧 ✓(矢量小勾,不依赖字体)
      p.set_stroke_color(@yue.theme_primary())
      p.begin_path()
      p.move_to(b.width - 18.0, b.height / 2.0)
      p.line_to(b.width - 14.0, b.height / 2.0 + 4.0)
      p.line_to(b.width - 8.0, b.height / 2.0 - 4.0)
      p.stroke()
    }
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
  // release 才选中:press 时刻 pick+关层会解除弹层指针抓取,悬着的
  // release 穿透到弹层下方控件;release 由弹层抓取派发给行,无待决事件
  @yue.ViewLike::on_mouse_up(row, fn(e) {
    if e.button == 1 {
      on_pick()
      true
    } else {
      false
    }
  })
  row
}

///|
/// 下拉选择(EP Select,全自绘):点击弹候选列表(Popover 承载):悬停
/// 高亮、当前选中主题色 ✓,点选回填并收起,失焦收起;选中经
/// value(Store[String])同步。三平台同形态。clearable=true 时字段悬停
/// 且有值,箭头左侧显示 ✕,点击清空选择(value 置空串、on_change("")。
/// 选项本身为空串时 ✕ 判定与「无值」同义)。
/// (曾有 Linux 可过滤形态——字段可输入实时筛选 + ↑↓/回车键盘导航,
/// 真机两轮验证均折在 X11 弹层焦点语义上,已移除,见 adaptation.md。)
pub fn select_t(
  options : Array[String],
  value : @yue.Store[String],
  on_change? : (String) -> Unit = fn(_s) {  },
  clearable? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      let hover = Ref(false)
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", 200.0),
        ("height", @yue.control_height),
        ("marginBottom", 10.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let field = @yue.themed_container(style=base)
      @yue.set_panel_bg(field)
      @yue.View::set_cursor(field, @yue.hand())
      fn apply(text : String) -> Unit {
        ignore(text)
        @yue.ViewLike::schedule_paint(field)
      }

      field.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(field)
        p.set_stroke_color(
          if focused.val {
            @yue.theme_focus_accent()
          } else {
            @yue.theme_border()
          },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        p.draw_text(
          value.get(),
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
        if clearable && hover.val && value.get() != "" {
          draw_clear_x(p, b.width - 30.0, b.height / 2.0)
        }
      })
      let pop : Ref[@yue.Popover?] = Ref(None)
      fn pick(opt : String) -> Unit {
        value.set(opt)
        on_change(opt)
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
      }

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
      @yue.ViewLike::on_mouse_enter(field, fn(_e) {
        hover.val = true
        @yue.ViewLike::schedule_paint(field)
      })
      @yue.ViewLike::on_mouse_leave(field, fn(_e) {
        hover.val = false
        @yue.ViewLike::schedule_paint(field)
      })
      @yue.ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(field)
          // 清空带(箭头左侧)优先:清空选择,不弹列表
          let b = @yue.ViewLike::get_bounds(field)
          if clearable &&
            value.get() != "" &&
            e.view_x >= b.width - 40.0 &&
            e.view_x <= b.width - 20.0 {
            value.set("")
            on_change("")
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = @yue.Popover::new()
              @yue.bind_popover_bg(p)
              // 高度 = 项数 x 28 + padding 8,上限 300;根容器宽高必须
              // 创建期给定(事后 set_style 会被弹层分配时序吞掉),
              // 公式与 content_size 一致
              let mut rows_h = options.length().to_double() * 28.0 + 8.0
              if rows_h > 300.0 {
                rows_h = 300.0
              }
              // 弹层宽随字段实际宽(用户 style 覆盖宽度后自动跟随)
              let pop_w = @yue.ViewLike::get_bounds(field).width
              let list = @yue.themed_container(style=[
                ("width", pop_w),
                ("height", rows_h),
                ("padding", 4.0),
                ("flexDirection", "column"),
              ])
              @yue.set_panel_bg(list)
              for opt in options {
                let o = opt
                list.add_child(select_row(o, value, fn() { pick(o) }))
              }
              p.set_content(list)
              p.set_content_size(pop_w, rows_h)
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
      value.subscribe(fn(v) { apply(v) })
      @yue.attach(parent, @yue.ViewLike::view(field))
      @yue.ViewLike::view(field)
    },
  }
}

///|
/// 五角星路径(矢量自绘,不依赖字体字形):cx/cy 星心,R 外半径,
/// 内半径取 0.382R(正五角星比例)。
fn star_path(
  p : @yue.Painter,
  cx : Double,
  cy : Double,
  r_out : Double,
) -> Unit {
  let r_in = r_out * 0.382
  p.begin_path()
  for k in 0..<10 {
    let rad = if k % 2 == 0 { r_out } else { r_in }
    // 起点朝上(-90°),每步 36°
    let ang = (-90.0 + k.to_double() * 36.0) * 3.141592653589793 / 180.0
    let x = cx + rad * @math.cos(ang)
    let y = cy + rad * @math.sin(ang)
    if k == 0 {
      p.move_to(x, y)
    } else {
      p.line_to(x, y)
    }
  }
  p.close_path()
}

///|
/// 评分(EP Rate,自绘):五角星序列,选中实心主题色、未选中描边灰,
/// 悬停预亮(实心),点击写入 value(Store[Int],0..max)。
pub fn rate_t(
  value : @yue.Store[Int],
  max? : Int = 5,
  on_change? : (Int) -> Unit = fn(_v) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let size = 22.0
      let gap = 4.0
      let hover = Ref(0) // 0 = 无预览,否则预亮到第 N 颗
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", size * max.to_double() + gap * (max - 1).to_double()),
        ("height", size),
        ("marginBottom", 10.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = @yue.themed_container(style=base)
      handle(v)
      fn star_at(x : Double) -> Int {
        let idx = ((x + gap / 2.0) / (size + gap)).to_int() + 1
        if idx < 1 {
          1
        } else if idx > max {
          max
        } else {
          idx
        }
      }

      v.on_draw(fn(p) {
        for i in 1..<=max {
          let cx = (i - 1).to_double() * (size + gap) + size / 2.0
          let cy = size / 2.0
          let lit = if hover.val > 0 {
            i <= hover.val
          } else {
            i <= value.get()
          }
          if lit {
            p.set_fill_color(@yue.theme_primary())
            star_path(p, cx, cy, size / 2.0 - 1.0)
            p.fill()
          } else {
            p.set_stroke_color(@yue.theme_border())
            star_path(p, cx, cy, size / 2.0 - 1.0)
            p.stroke()
          }
        }
      })
      @yue.ViewLike::on_mouse_move(v, fn(e) {
        let h = star_at(e.view_x)
        if h != hover.val {
          hover.val = h
          @yue.ViewLike::schedule_paint(v)
        }
      })
      @yue.ViewLike::on_mouse_leave(v, fn(_e) {
        if hover.val != 0 {
          hover.val = 0
          @yue.ViewLike::schedule_paint(v)
        }
      })
      @yue.View::set_cursor(v, @yue.hand())
      @yue.ViewLike::on_mouse_down(v, fn(e) {
        if e.button == 1 {
          value.set(star_at(e.view_x))
          true
        } else {
          false
        }
      })
      value.subscribe(fn(new_v) {
        on_change(new_v)
        @yue.ViewLike::schedule_paint(v)
      })
      @yue.attach(parent, @yue.ViewLike::view(v))
      @yue.ViewLike::view(v)
    },
  }
}

///|
/// 取色器(EP ColorPicker,下拉形态):触发字段(当前色块 + hex + 箭头)
/// 点击弹出预设色板(Popover 承载):点击色块写入 value("#RRGGBB")并
/// 收起;选中色块主题色描边 + 白勾。失焦收起。
pub fn color_picker_t(
  value : @yue.Store[String],
  colors? : Array[String] = [
    "#2D68C4", "#2E9E5B", "#D9822B", "#D64550", "#6B7480", "#1E4FA3", "#3F6E9E",
    "#7A9E4E", "#B86E2B", "#9AA0A6", "#E8EAED", "#BDC1C6", "#4E5560", "#2A2F36",
    "#F5F7FA",
  ],
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let focused = Ref(false)
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", 200.0),
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
        p.set_stroke_color(
          if focused.val {
            @yue.theme_focus_accent()
          } else {
            @yue.theme_border()
          },
        )
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        // 当前色块
        p.set_fill_color(value.get())
        p.fill_rect(10.0, 8.0, 14.0, 14.0)
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(10.5, 8.5, 13.0, 13.0)
        p.draw_text(
          value.get(),
          32.0,
          0.0,
          b.width - 52.0,
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
      fn pick(c : String) -> Unit {
        value.set(c)
        match pop.val {
          Some(p) => p.close()
          None => ()
        }
      }

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
              // 色板网格:5 列布局,选中描边 + 白勾
              let swatch = 26.0
              let gap = 6.0
              let per_row = 5
              // 弹层根容器宽高必须创建期给定(公式与 content_size 一致):
              // 事后 set_style 会被弹层分配时序吞掉——实测色板整体不绘制
              // 但事件窗口仍在(能点击看不到)
              let rows_n0 = (colors.length() + per_row - 1) / per_row
              let grid_w0 = per_row.to_double() * (swatch + gap) + 16.0
              let grid_h0 = 16.0 + rows_n0.to_double() * (swatch + gap)
              let grid = @yue.themed_container(style=[
                ("width", grid_w0),
                ("height", grid_h0),
                ("padding", 8.0),
                ("flexDirection", "column"),
              ])
              @yue.set_panel_bg(grid)
              let rows : Array[(@yue.Container, Array[@yue.Container])] = []
              for i in 0..<colors.length() {
                if i % per_row == 0 {
                  rows.push(
                    (
                      @yue.themed_container(style=[
                        ("height", swatch + gap),
                        ("flexDirection", "row"),
                      ]),
                      [],
                    ),
                  )
                }
                let (row, cells) = rows[rows.length() - 1]
                let c = colors[i]
                let cell = @yue.themed_container(style=[
                  ("width", swatch),
                  ("height", swatch),
                  ("marginRight", gap),
                ])
                @yue.View::set_cursor(cell, @yue.hand())
                cell.on_draw(fn(p2) {
                  p2.set_fill_color(c)
                  p2.fill_rect(0.0, 0.0, swatch, swatch)
                  p2.set_stroke_color(@yue.theme_border())
                  p2.stroke_rect(0.5, 0.5, swatch - 1.0, swatch - 1.0)
                  if value.get() == c {
                    p2.set_stroke_color(@yue.theme_primary())
                    p2.stroke_rect(1.5, 1.5, swatch - 3.0, swatch - 3.0)
                    p2.set_stroke_color("#FFFFFF")
                    p2.begin_path()
                    p2.move_to(swatch / 2.0 - 5.0, swatch / 2.0)
                    p2.line_to(swatch / 2.0 - 1.0, swatch / 2.0 + 4.0)
                    p2.line_to(swatch / 2.0 + 6.0, swatch / 2.0 - 5.0)
                    p2.stroke()
                  }
                })
                // release 才选中:弹层点项一律 release,防穿透
                @yue.ViewLike::on_mouse_up(cell, fn(e2) {
                  if e2.button == 1 {
                    pick(c)
                    true
                  } else {
                    false
                  }
                })
                row.add_child(cell)
                cells.push(cell)
              }
              for (row, _cells) in rows {
                grid.add_child(row)
              }
              value.subscribe(fn(_v) {
                for (_r, cells) in rows {
                  for cell in cells {
                    @yue.ViewLike::schedule_paint(cell)
                  }
                }
                @yue.ViewLike::schedule_paint(field)
              })
              // 高度 = padding 16 + 行数 x 32(色块 26 + 间距 6);
              // content_size 与创建期根容器尺寸公式一致
              p.set_content(grid)
              p.set_content_size(grid_w0, grid_h0)
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
