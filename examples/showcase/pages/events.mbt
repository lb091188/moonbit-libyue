// 事件与布局页：指针 / 悬停 / 捕获 / 光标 / 键盘 × yoga 布局模型。
//
// G7 迁移记档（与 master 旧页的五条机制差，全部落在「宿主接管」上）：
// ① 五个鼠标回调（on_mouse_enter/leave/move/down/up）合成**一个** `on_pointer`：
//    `PointerEvent.kind` 区分 Down/Up/Move/Leave，坐标交给处理器前已换算成本地
//    坐标（`Leave` 保持窗口坐标），enter/leave 不再手写——悬停态由宿主维护；
// ② 显式捕获三件套（set_capture / has_capture / release_capture +
//    on_capture_lost）没有了：宿主规则是「**命中即捕获**」——任何一次按下到松手
//    之间，Move/Up 全投给被按下的控件（`route_pointer`），指针移出它的矩形也不丢
//    抬起（本地坐标可为负）；再按另一处即夺走捕获。演示从「开关」改成「规则」；
// ③ 「全局鼠标 + 修饰键 200ms 轮询」整段删除：本栈没有窗口外指针通道，修饰键随
//    每个指针/按键事件下发（`ev.mods` 位掩码，MOD_SHIFT/MOD_CTRL/MOD_ALT/MOD_META）。
//    原位置换成两段本栈原生能力：`on_hover_change` 起停定时器（悬停秒表）与
//    `@core.set_timeout` 进程级延时通道（周期任务靠自重排，句柄可取消）；
// ④ 光标从 `View::set_cursor(view, Cursor)` 换成控件字段 `w.cursor`（编号 0..4），
//    宿主按悬停路径取「最深的非零请求」下发；旧链路的 Crosshair/NotAllowed 本栈
//    没有——平台没有的形状不强推（见前端化设计文档的口径）；
// ⑤ 键盘从「窗口级 on_key_down」换成「焦点控件 on_key」：键只投给当前焦点，
//    点击即聚焦（focusable_at → focus）；宿主只投**按下**（抬起不投，防编辑内核
//    把松手当字符），Tab/Shift+Tab 被宿主吃去驱动焦点栈。焦点 id 要在宿主就绪后
//    注册（页内容惰性挂载，挂载时 `host_active()` 才拿得到）。

///|
/// 修饰键位掩码 → 可读串（指针与按键事件同一口径）。
fn mods_label(m : Int) -> String {
  let mut s = ""
  if (m & @core.MOD_SHIFT) != 0 {
    s = s + "Shift "
  }
  if (m & @core.MOD_CTRL) != 0 {
    s = s + "Ctrl "
  }
  if (m & @core.MOD_ALT) != 0 {
    s = s + "Alt "
  }
  if (m & @core.MOD_META) != 0 {
    s = s + "Meta "
  }
  if s.length() == 0 {
    "(无)"
  } else {
    s
  }
}

///|
/// 虚拟键码 → 可读名：可打印区间直接给字符，命名键给名字，其余给编号。
/// （宿主只投按下，`press` 恒真；这里仍显示它，字段就在事件上。）
fn key_name(ks : Int) -> String {
  if ks == @core.KS_BACKSPACE {
    "Backspace"
  } else if ks == @core.KS_TAB {
    "Tab"
  } else if ks == @core.KS_RETURN {
    "Enter"
  } else if ks == @core.KS_ESCAPE {
    "Esc"
  } else if ks == @core.KS_LEFT {
    "Left"
  } else if ks == @core.KS_UP {
    "Up"
  } else if ks == @core.KS_RIGHT {
    "Right"
  } else if ks == @core.KS_DOWN {
    "Down"
  } else if ks == @core.KS_HOME {
    "Home"
  } else if ks == @core.KS_END {
    "End"
  } else if ks == @core.KS_DELETE {
    "Delete"
  } else if ks >= 32 && ks <= 126 {
    match ks.to_char() {
      Some(c) => "\{c}"
      None => "键 \{ks}"
    }
  } else {
    "键 \{ks}"
  }
}

///|
/// 主题化面板皮：底色随悬停切换（悬停 = fill_hover，常态 = bg_panel），描边走
/// 主题边框色。在 `on_draw` 里**现取**主题值——换主题不用重建控件（容器的
/// `watch_theme` 已由构造器装好，只管重绘）。覆盖容器默认绘制，故不传 bg/border。
fn skin_panel(w : @core.Widget) -> Unit {
  w.on_draw = Some(fn(
    self : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    p.set_fill_color(if self.hovered {
      @theme.theme_fill_hover()
    } else {
      @theme.theme_bg_panel()
    })
    p.fill_rect(0.0, 0.0, r.w, r.h)
    p.set_stroke_color(@theme.theme_border())
    p.set_line_width(1.0)
    p.stroke_rect(0.0, 0.0, r.w, r.h)
  })
}

///|
/// 键盘焦点区：点击聚焦（宿主 Down → 焦点栈对齐控件树 → focusable_at → focus），
/// `on_key` 回显。只需要声明 `focus_id`——宿主每回合把「在树里且未隐藏」的焦点号
/// 对齐进栈（页内容是惰性挂载的，切走即隐藏、自动退出 Tab 次序），调用方不必注册。
fn key_focus_area(echo : @core.Store[String]) -> @core.Node {
  // 诊断（真机一轮定位，拿到读数后删）：n 只走 stdout，与重绘链无关——
  // stdout 里 n 在涨而屏幕上不更新 = 重绘链断；stdout 一条不涨 = 事件链断。
  let n : Ref[Int] = Ref(0)
  {
    mount: fn(parent : @core.Widget) -> @core.Widget {
      let w = @core.Widget::new()
      w.node.set_width(@yoga.percent(100.0))
      w.node.set_height(@yoga.fixed(96.0))
      w.focus_id = KEY_AREA_FOCUS_ID
      w.cursor = @core.CURSOR_TEXT
      let font = @text.Font::new("", 13.0)
      w.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        p.set_fill_color(@theme.theme_bg_panel())
        p.fill_rect(0.0, 0.0, r.w, r.h)
        // 焦点环：聚焦主题色、未聚焦边框色（focused 由宿主按焦点栈维护）
        p.set_stroke_color(if self.focused {
          @theme.theme_primary()
        } else {
          @theme.theme_border()
        })
        p.set_line_width(1.0)
        p.stroke_rect(0.0, 0.0, r.w, r.h)
        // 文本走 text 自己的 Cairo 会话，与 Painter 会话交替前刷一次
        p.flush()
        let _ = @text.draw_box_at(
          p,
          10.0,
          0.0,
          (r.w - 20.0).max(1.0),
          r.h,
          "键盘焦点区（点击聚焦，然后按任意键）",
          font,
          @theme.theme_text_regular(),
          align=@text.Center,
          valign=@text.Center,
          wrap=false,
        )
      })
      w.on_pointer = Some(fn(_self : @core.Widget, ev : @core.PointerEvent) -> Bool {
        match ev.kind {
          @widget.PointerKind::Down => true
          _ => false
        }
      })
      w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
        n.val = n.val + 1
        println(
          "KEY-DIAG n=" + n.val.to_string() + " keysym=" + ev.keysym.to_string() +
          " press=" + ev.press.to_string() + " mods=" + ev.mods.to_string()
        )
        echo.set(
          "\{key_name(ev.keysym)}（keysym \{ev.keysym}）mods=\{mods_label(ev.mods)} press=\{ev.press} 第 \{n.val.to_string()} 键",
        )
        true
      })
      parent.append_child(w)
      w
    },
  }
}

///|
/// 键盘焦点区的焦点 id（页内唯一；>0 才可聚焦）。本页之外无人占用 9xx 段。
const KEY_AREA_FOCUS_ID : Int = 910

///|
pub fn page_events(app : @shared.App) -> @core.Node {
  // ---- 段一：鼠标（五类指针事件 + 双击判定） ----
  let evt_mouse : @core.Store[String] = @core.Store::new("(移入色块区操作)")
  let evt_dbl : @core.Store[String] = @core.Store::new("(在操作区快速连点两次)")
  let dbl_n : Ref[Int] = Ref(0)
  // 双击判定与 input 的「双击选词」同一口径：400ms + 4px（monotonic 时钟）
  let last_down : Ref[(Int64, Double, Double)] = Ref((0L, 0.0, 0.0))
  // ---- 段二：悬停秒表（on_hover_change 起停 200ms 自重排定时器） ----
  // 自停上限 100 拍（20s）：切页后悬停态可能滞留（隐藏控件不参与命中，但宿主
  // 只在指针移动时重算悬停），自停兜底，不会永远转下去
  let watch_n : Ref[Int] = Ref(0)
  let watch_timer : Ref[Int] = Ref(0)
  let watch_secs : @core.Store[Int] = @core.Store::new(0)
  let watch_tick : Ref[() -> Unit] = Ref(fn() { () })

  watch_tick.val = fn() -> Unit {
    watch_n.val = watch_n.val + 1
    watch_secs.set(watch_n.val / 5)
    if watch_n.val < 100 {
      watch_timer.val = @core.set_timeout(200, watch_tick.val)
    } else {
      watch_timer.val = 0
    }
  }

  fn watch_stop() -> Unit {
    if watch_timer.val != 0 {
      @core.clear_timeout(watch_timer.val)
      watch_timer.val = 0
    }
  }

  // ---- 段三：捕获（命中即捕获，拖动演示） ----
  let cap_log : @core.Store[String] = @core.Store::new("(在 A 区按下，拖到 B 区上再松手)")

  fn cap_area(tag : String) -> @core.Node {
    @ui.col(
      [@ui.text("\{tag} 区", role=@ui.Body)],
      width=150.0,
      height=80.0,
      handle=fn(w : @core.Widget) -> Unit {
        skin_panel(w)
        w.on_pointer = Some(fn(_self : @core.Widget, ev : @core.PointerEvent) -> Bool {
          match ev.kind {
            @widget.PointerKind::Down => {
              cap_log.set("\{tag} 按下 → 捕获者换成 \{tag}（pressed 已由宿主置上）")
              true
            }
            @widget.PointerKind::Move => {
              cap_log.set("\{tag} 收到 move (\{ev.x.round()}, \{ev.y.round()})——负值 = 指针已移出本区，仍投给捕获者")
              false
            }
            @widget.PointerKind::Up => {
              cap_log.set("\{tag} 抬起 → 捕获释放，悬停按抬起位置重判")
              true
            }
            @widget.PointerKind::Leave => false
          }
        })
      },
    )
  }

  // ---- 段四：光标（w.cursor 字段 + 悬停路径最深请求） ----
  let cur_area : Ref[@core.Widget?] = Ref(None)
  let cur_now : @core.Store[String] = @core.Store::new("Default")

  fn apply_cursor(kind : Int, name : String) -> Unit {
    match cur_area.val {
      Some(w) => {
        w.cursor = kind
        cur_now.set(name)
      }
      None => ()
    }
  }

  // ---- 段五：键盘 ----
  let key_echo : @core.Store[String] = @core.Store::new("(点击下面区域获得焦点，再按任意键)")
  @shared.page([
    @shared.section(
      "鼠标",
      "指针事件 PointerEvent",
      "五类指针事件（Down/Up/Move/Leave）走控件同一个 `on_pointer` 回调；坐标在交给处理器前已换算成**本地坐标**（Leave 保持窗口坐标），button 与修饰键位掩码随事件下发——修饰键不再需要轮询。双击判定 400ms + 4px，与输入框的「双击选词」同一口径。",
      [
        @ui.col(
          [@ui.text("鼠标操作区", role=@ui.Body)],
          height=96.0,
          handle=fn(w : @core.Widget) -> Unit {
            skin_panel(w)
            w.on_pointer = Some(fn(_self : @core.Widget, ev : @core.PointerEvent) -> Bool {
              match ev.kind {
                @widget.PointerKind::Down => {
                  let now = @core.now_ms()
                  let (t0, x0, y0) = last_down.val
                  if now - t0 < 400L && (ev.x - x0).abs() < 4.0 && (ev.y - y0).abs() < 4.0 {
                    dbl_n.val = dbl_n.val + 1
                    evt_dbl.set("双击！连击 \{dbl_n.val} 次 btn=\{ev.button}")
                  }
                  last_down.val = (now, ev.x, ev.y)
                  evt_mouse.set("down btn=\{ev.button} mods=\{mods_label(ev.mods)}")
                  true
                }
                @widget.PointerKind::Up => {
                  evt_mouse.set("up btn=\{ev.button}")
                  true
                }
                @widget.PointerKind::Move => {
                  evt_mouse.set("move (\{ev.x.round()}, \{ev.y.round()}) btn=\{ev.button} mods=\{mods_label(ev.mods)}")
                  false
                }
                @widget.PointerKind::Leave => {
                  evt_mouse.set("leave（窗口坐标 (\{ev.x.round()}, \{ev.y.round()})）")
                  false
                }
              }
            })
          },
        ),
        @ui.bind_label(evt_mouse, fn(s) { s }),
        @ui.bind_label(evt_dbl, fn(s) { s }),
      ],
      code=[
        "let evt : @core.Store[String] = @core.Store::new(\"(移入操作区操作)\")",
        "@ui.col([@ui.text(\"鼠标操作区\", role=@ui.Body)], height=96.0, handle=fn(w) {",
        "  w.on_pointer = Some(fn(_self, ev : @core.PointerEvent) -> Bool {",
        "    match ev.kind {",
        "      @widget.PointerKind::Down => { evt.set(\"down btn=\\{ev.button}\"); true }",
        "      @widget.PointerKind::Up => { evt.set(\"up btn=\\{ev.button}\"); true }",
        "      @widget.PointerKind::Move => { evt.set(\"move (\\{ev.x}, \\{ev.y})\"); false }",
        "      @widget.PointerKind::Leave => { evt.set(\"leave\"); false }",
        "    }",
        "  })",
        "})",
        "@ui.bind_label(evt, fn(s) { s })",
      ],
    ),
    @shared.section(
      "悬停",
      "悬停态与 on_hover_change",
      "悬停由宿主维护（命中测试 + set_hover），控件读 `hovered` 字段即可，不写 enter/leave。悬停带**父链语义**（CSS :hover 同义）：组内任意子件悬停，组也算悬停——所以包住按钮的面板能收到 `on_hover_change`，用它按悬停起停定时器（本页即一座悬停秒表）。",
      [
        @ui.col(
          [
            @ui.text("悬停秒表：把鼠标放进这块面板（或点上面那颗按钮都算）", role=@ui.Body),
            @ui.row(
              [
                @ui.button("组内按钮", variant=@ui.Solid, on_click=fn() {
                  app.toast_push("悬停组里的按钮被点了", @ui.Success)
                }),
                @ui.bind_label(watch_secs, fn(n) {
                  if n == 0 {
                    "悬停计时：(未悬停)"
                  } else {
                    "悬停计时：\{n} s"
                  }
                }),
              ],
              column_gap=12.0,
            ),
          ],
          padding=12.0,
          row_gap=8.0,
          handle=fn(w : @core.Widget) -> Unit {
            skin_panel(w)
            w.on_hover_change = Some(fn(_w : @core.Widget, on : Bool) -> Unit {
              if on {
                watch_n.val = 0
                watch_secs.set(0)
                (watch_tick.val)()
              } else {
                watch_stop()
              }
            })
          },
        ),
      ],
      code=[
        "let secs : @core.Store[Int] = @core.Store::new(0)",
        "@ui.col([...], handle=fn(w) {",
        "  w.on_hover_change = Some(fn(_w, on : Bool) -> Unit {",
        "    if on { (tick.val)() } else { stop() }  // 悬停起停定时器",
        "  })",
        "})",
        "// 进程级延时通道：回调里自重排即周期定时器，句柄可取消",
        "let id = @core.set_timeout(200, tick.val)",
        "@core.clear_timeout(id)",
      ],
    ),
    @shared.section(
      "捕获",
      "按下捕获（宿主内置规则）",
      "旧链路的 set_capture / has_capture / release_capture / on_capture_lost 四件套在本栈没有了：**任何一次按下（命中控件即成为捕获者）到松手之间**，Move/Up 全投给被按下的控件——指针移出它的矩形也不丢抬起（本地坐标为负），再按另一处即夺走捕获。拖选、拖动插入点都靠这条规则。",
      [
        @ui.row([cap_area("A"), cap_area("B")], column_gap=12.0),
        @ui.bind_label(cap_log, fn(s) { s }),
      ],
      code=[
        "// 宿主规则：命中即捕获，没有显式开关",
        "w.on_pointer = Some(fn(_self, ev) -> Bool {",
        "  match ev.kind {",
        "    @widget.PointerKind::Down => true   // 按下起，Move/Up 全归本控件",
        "    @widget.PointerKind::Move => { log.set(\"(\\{ev.x}, \\{ev.y})\"); false }",
        "    @widget.PointerKind::Up => true     // 松手释放；指针在区外也收得到",
        "    @widget.PointerKind::Leave => false",
        "  }",
        "})",
      ],
    ),
    @shared.section(
      "光标",
      "光标形状 Cursor",
      "`w.cursor` 是控件上的形状请求（0 默认 / 1 手型 / 2 文本 / 3 横向调整 / 4 纵向调整）；宿主每次移动按悬停路径取「**最深的非零请求**」下发——包住一整组的 `cursor_group` 会自然回退，组内子件自己提了形状以它为准（旧链路要把光标递归设进每个子孙）。Crosshair/NotAllowed 平台没有，本栈不强推。",
      [
        @ui.col(
          [@ui.text("光标预览区（把鼠标放上来，再点下面按钮换形状）", role=@ui.Body)],
          height=56.0,
          handle=fn(w : @core.Widget) -> Unit {
            skin_panel(w)
            cur_area.val = Some(w)
          },
        ),
        @ui.row(
          [
            @ui.button("手型", on_click=fn() {
              apply_cursor(@core.CURSOR_HAND, "Hand")
            }),
            @ui.button("文本", on_click=fn() {
              apply_cursor(@core.CURSOR_TEXT, "Text")
            }),
            @ui.button("横向调整", on_click=fn() {
              apply_cursor(@core.CURSOR_RESIZE_H, "ResizeH")
            }),
            @ui.button("纵向调整", on_click=fn() {
              apply_cursor(@core.CURSOR_RESIZE_V, "ResizeV")
            }),
            @ui.button("默认", on_click=fn() {
              apply_cursor(@core.CURSOR_DEFAULT, "Default")
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(cur_now, fn(s) { "预览区当前光标：\{s}" }),
        @ui.text(
          "组回退：下面一组的 cursor = ResizeH；组内文本没提请求 → 用组的形状，按钮自己请求了手型 → 以它为准。",
          role=@ui.Secondary,
          max_width=640.0,
        ),
        @ui.cursor_group(
          [
            @ui.text("组内文本（回退到组的横向调整）", role=@ui.Body),
            @ui.button("组内按钮（自己的手型）", variant=@ui.Soft, on_click=fn() { () }),
          ],
          direction=@yoga.Row,
          column_gap=12.0,
          cursor=@core.CURSOR_RESIZE_H,
          padding=10.0,
        ),
      ],
      code=[
        "w.cursor = @core.CURSOR_HAND  // 0 默认 / 1 手型 / 2 文本 / 3 横调 / 4 纵调",
        "// 宿主按悬停路径取「最深的非零请求」下发：",
        "@ui.cursor_group([...], cursor=@core.CURSOR_RESIZE_H)",
        "// 组内没提请求的位置回退到组；子件提了以子件为准",
      ],
    ),
    @shared.section(
      "键盘",
      "键盘事件 KeyEvent",
      "键只投给**当前焦点控件**：点击下方区域即聚焦（宿主 Down → 焦点栈对齐树 → focusable_at → focus）。宿主只投**按下**（抬起不投——防编辑内核把松手当字符）；Tab/Shift+Tab 被宿主消费去驱动焦点栈，到不了 on_key。`ev.mods` 是修饰键位掩码。",
      [
        key_focus_area(key_echo),
        @ui.bind_label(key_echo, fn(s) { s }),
      ],
      code=[
        "w.focus_id = 910   // >0 即可聚焦、即可 Tab 到（宿主按树序对齐焦点栈）",
        "w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {",
        "  echo.set(\"\\{ev.keysym} mods=\\{ev.mods}\")",
        "  true",
        "})",
      ],
    ),
    @shared.section(
      "布局",
      "嵌套布局与三种宽度",
      "固定 / 百分比 / flex 三种宽度模型；8px 把手可拖动调整占比（split，首栏最小 120、次栏最小 80，拖动期靠宿主的按下捕获不丢事件）。全集见 docs/zh/layout.md。",
      [
        @ui.col(
          [
            @ui.split(
              @ui.tree([
                {
                  label: "组件",
                  children: [
                    {
                      label: "基础",
                      children: [
                        { label: "图标", children: [] },
                        { label: "分隔", children: [] },
                      ],
                    },
                    {
                      label: "导航",
                      children: [{ label: "分栏", children: [] }],
                    },
                  ],
                },
              ]),
              @ui.col(
                [@ui.text("右侧详情区：拖动中间把手调整占比", role=@ui.Body)],
                padding=12.0,
              ),
              min_first=120.0,
            ),
          ],
          height=200.0,
          width=520.0,
        ),
        @ui.row(
          [
            @ui.view(
              [@ui.text("固定 80", color="#ffffff")],
              direction=@yoga.Row,
              width=80.0,
              height=40.0,
              background_color="#3A5F8A",
              align_items=@yoga.AlignItems::Center,
              justify_content=@yoga.JustifyContent::Center,
            ),
            @ui.view(
              [@ui.text("50%", color="#ffffff")],
              direction=@yoga.Row,
              height=40.0,
              background_color="#8A3A5F",
              align_items=@yoga.AlignItems::Center,
              justify_content=@yoga.JustifyContent::Center,
              handle=fn(w : @core.Widget) -> Unit {
                w.node.set_width(@yoga.percent(50.0))
              },
            ),
            @ui.view(
              [@ui.text("flex 1", color="#ffffff")],
              direction=@yoga.Row,
              height=40.0,
              grow=1.0,
              background_color="#5F8A3A",
              align_items=@yoga.AlignItems::Center,
              justify_content=@yoga.JustifyContent::Center,
            ),
          ],
          column_gap=8.0,
        ),
      ],
      code=[
        "@ui.split(@ui.tree(root), detail, min_first=120.0)  // 拖动 8px 把手改占比",
        "@ui.view([...], width=80.0, height=40.0)        // 固定",
        "// 百分比：容器没接这个参数，handle 里对布局节点写",
        "handle=fn(w) { w.node.set_width(@yoga.percent(50.0)) }",
        "@ui.view([...], grow=1.0)                       // flex",
      ],
    ),
  ])
}
