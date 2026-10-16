// 窗口页：窗口 API × 全局快捷键 × 拖放（应用内 + 系统级拖入 / 拖出）。
//
// G7 迁移记档（与 master 旧页的三条差）：
// ① 窗口段少了「最大化/还原」「置顶切换」两个按钮——本栈 Win32 段没写
//    SC_MAXIMIZE / TOPMOST，按钮就不放（平台没有的能力不强推，见前端化设计
//    文档的口径）；旧链路的 `set_content_size` 对应本栈 `set_size_pixels`；
//    取窗口经宿主 `App::window()`（控件层本来就拿不到窗口，`set_fullscreen`
//    因此收在宿主上；标题/尺寸/无边框这类窗口级动作由上层直调 `@win.Window`）；
// ② 快捷键从 `@yue.register_global_shortcut` 切到 `@shell.hotkey_*` 门面（W22）：
//    注册收 `Result`，命中经 `hotkey_poll` 抽（id→加速串回查表在门面里，页内
//    不自己持表——只记注册时返回的句柄用于注销）；轮询表挂宿主 200ms 一拍；
// ③ 拖放：旧链路的「跨应用系统级」（register_dragged_types + enter/update/drop
//    三回调）在本栈拆成两段——应用内那条三平台同构，系统级两档 Windows/Linux 已接：
//    拖入走 `core/drag.mbt` 的 `drag_external_*`（旧三回调收成 `on_drop` 一个 +
//    悬停期一次 `accept` 查询），拖出走 `drag_external_send`（`drag_source`
//    的 `external=true`，本机没后端时自动回落应用内）。Linux/mac 的系统级两档
//    仍随平台批。
//    本页三段都演示：`drag_source`/`drop_target` 两个声明式钩子 + 从资源管理器
//    拖文件进「只收文件」那块 + 两块往外拖（文本、文件）。

///|
/// 热键错误 → 可读串（门面的两档：没后端 / 有backend但这次没成）。
fn hotkey_err_text(e : @shell.HotkeyError) -> String {
  match e {
    @shell.HotkeyError::Unsupported => "本平台没有全局快捷键后端（当前仅 Windows）"
    @shell.HotkeyError::Failed(why) => "注册失败：\{why}"
  }
}

///|
/// 拖出回报 → 可读串：成交档给效果，没走成时给原因（后端未接会自动回落应用内）。
fn drag_send_text(r : Result[@core.DragEffect, @core.DragError]) -> String {
  match r {
    Ok(e) => match e {
      @core.DragEffect::Copy => "已复制出去"
      @core.DragEffect::Move => "已移动出去"
      @core.DragEffect::Link => "已建立链接"
      @core.DragEffect::Rejected => "取消或落点不收"
    }
    Err(@core.DragError::Unsupported) => "本机没有系统级拖出后端（已回落应用内拖放）"
    Err(@core.DragError::Failed(why)) => "这趟没走成：\{why}（已回落应用内拖放）"
  }
}

///|
/// 快捷键轮询表：挂上就跑，200ms 一拍自重排（宿主停/退出后 timer 自然不再响）。
/// 命中即累计 + toast——加速串由门面回查表给，调用方不持第二张表。
/// 页内容惰性挂载，故本表由段内一个零尺寸挂载钩子启动（页函数体跑完时宿主
/// 还没就绪，`app.host` 那时还是 None）。
fn hotkey_poll_loop(app : @shared.App, hits : @core.Store[Int]) -> Unit {
  let tick : Ref[() -> Unit] = Ref(fn() { () })
  tick.val = fn() -> Unit {
    match @shell.hotkey_poll() {
      Some(hk) => {
        hits.update(fn(n) { n + 1 })
        app.toast_push("快捷键触发：\{hk.spec}", @ui.Success)
      }
      None => ()
    }
    match app.host.val {
      Some(a) => ignore(a.timer(200, tick.val))
      None => ()
    }
  }
  (tick.val)()
}

///|
/// 窗口动作按钮：点下去经宿主取窗口门面执行 `act`，按钮名写回显行。
/// 宿主未就绪时（理论上是点不到的）静默跳过。
fn win_button(
  app : @shared.App,
  last_op : @core.Store[String],
  text : String,
  act : (@win.Window) -> Unit,
  variant? : @ui.ButtonVariant = @ui.Soft,
) -> @core.Node {
  @ui.button(text, variant=variant, on_click=fn() {
    match app.host.val {
      Some(a) => {
        act(a.window())
        last_op.set(text)
      }
      None => ()
    }
  })
}

///|
/// 窗口页。页内私有状态（回显/热键句柄/两个切换态）不进共享 App。
pub fn page_window(app : @shared.App) -> @core.Node {
  let taskbar_out : @core.Store[String] = @core.Store::new("（还没写过任务栏进度）")
  fn taskbar_pct(v : Int64, t : Int64, tag : String) -> Unit {
    match app.host.val {
      Some(a) =>
        taskbar_out.set(
          if a.window.set_taskbar_progress(v, t) { "已写进度 \{tag}" } else { "写失败（\{tag}，后端不在位？）" },
        )
      None => ()
    }
  }
  fn taskbar_state(st : @win.TaskbarState, tag : String) -> Unit {
    match app.host.val {
      Some(a) =>
        taskbar_out.set(
          if a.window.set_taskbar_state(st) { "已写状态 \{tag}" } else { "写失败（\{tag}，后端不在位？）" },
        )
      None => ()
    }
  }
  let last_op : @core.Store[String] = @core.Store::new("（尚无操作）")
  // 两个切换态由按钮自己翻（窗口层没有 is_fullscreen/is_borderless 之外的
  // 读回通道，态以按钮点击为准）
  let fs : Ref[Bool] = Ref(false)
  let bl : Ref[Bool] = Ref(false)
  let sz : Ref[Int] = Ref(1280)
  // 快捷键：门面回查表在 core 里，页内只记自己注册过的句柄（注销用）
  let hotkeys : Ref[Array[@shell.Hotkey]] = Ref([])
  let hk_status : @core.Store[String] = @core.Store::new("（未注册）")
  let hk_hits : @core.Store[Int] = @core.Store::new(0)
  // 拖放回显
  let dnd : @core.Store[String] = @core.Store::new("（还没投过）")
  let ext : @core.Store[String] = @core.Store::new("（外部还没投过）")
  let out : @core.Store[String] = @core.Store::new("（还没往外拖过）")
  @shared.page([
    @shared.section(
      "窗口",
      "窗口 API",
      "运行期操作窗口：改标题 / 全屏 / 尺寸切换（1280×720 ↔ 960×540）/ 无边框。「最大化/还原」「置顶」本栈未接（Win32 段没写 SC_MAXIMIZE / TOPMOST），按钮就不放——平台没有的能力不强推。",
      [
        @ui.row(
          [
            win_button(app, last_op, "改标题", fn(w : @win.Window) -> Unit {
              w.set_title("组件库演示板 · 标题已改")
            }),
            win_button(app, last_op, "全屏切换", fn(w : @win.Window) -> Unit {
              fs.val = !fs.val
              w.set_fullscreen(fs.val)
            }),
            win_button(app, last_op, "尺寸切换", fn(w : @win.Window) -> Unit {
              // 定死一个目标值会看着「没用」——启动尺寸就是它；两档来回切才看得见
              sz.val = if sz.val == 1280 { 960 } else { 1280 }
              let h = (sz.val.to_double() * 9.0 / 16.0).round().to_int()
              w.set_size_pixels(sz.val, h)
            }),
            win_button(app, last_op, "无边框切换", fn(w : @win.Window) -> Unit {
              bl.val = !bl.val
              w.set_borderless(bl.val)
            }),
          ],
          column_gap=8.0,
        ),
        @ui.row(
          [
            @ui.text("最近操作：", role=@ui.Secondary),
            @ui.bind_label(last_op, fn(s) { s }),
          ],
          column_gap=6.0,
        ),
      ],
      code=[
        "// 宿主句柄挂载时由 main 的 handle 回调填入；窗口门面经它取",
        "match app.host.val {",
        "  Some(a) => {",
        "    let w = a.window()",
        "    w.set_title(\"组件库演示板 · 标题已改\")",
        "    w.set_fullscreen(true)",
        "    w.set_size_pixels(1280, 720)",
        "    w.set_borderless(true)",
        "  }",
        "  None => ()",
        "}",
      ],
    ),
    @shared.section(
      "快捷键",
      "全局快捷键",
      "应用外生效的系统快捷键（Ctrl+Alt+C，仅 Windows；别的平台注册即返回 Unsupported）。门面持有 id→加速串回查表，轮询命中直接给 Hotkey。",
      [
        // 零尺寸挂载钩子：段首次选中时启动轮询表（见 hotkey_poll_loop）。
        // 首拍必须挂真·挂载时机（Node::on_mount）——node_of_new 的 finish 是
        // 构造期执行、那时宿主还没建好，timer 是空通道，表会当场死掉不再重排
        // （与图表页推点同一条坑，见 charts.mbt 头注释）。
        @core.node_of_new(fn(w : @core.Widget) -> @core.Widget { w }).on_mount(
          fn() -> Unit { hotkey_poll_loop(app, hk_hits) },
        ),
        @ui.row(
          [
            @ui.button("注册 Ctrl+Alt+C", on_click=fn() {
              match @shell.hotkey_register("Ctrl+Alt+C") {
                Ok(hk) => {
                  hotkeys.val.push(hk)
                  hk_status.set("已注册（切到别的窗口按一下）")
                }
                Err(e) => hk_status.set(hotkey_err_text(e))
              }
            }),
            @ui.button("注销全部", variant=@ui.Soft, on_click=fn() {
              for hk in hotkeys.val {
                ignore(@shell.hotkey_unregister(hk))
              }
              hotkeys.val = []
              hk_status.set("已全部注销")
            }),
          ],
          column_gap=8.0,
        ),
        @ui.row(
          [
            @ui.text("状态：", role=@ui.Secondary),
            @ui.bind_label(hk_status, fn(s) { s }),
            @ui.bind_label(hk_hits, fn(n) { "命中 \{n} 次" }),
          ],
          column_gap=6.0,
        ),
      ],
      code=[
        "match @shell.hotkey_register(\"Ctrl+Alt+C\") {",
        "  Ok(hk) => // hk.id / hk.spec（回查表门面自持）",
        "  Err(Unsupported) => // 非 Windows",
        "  Err(Failed(why)) => // 组合被占用 / 表满",
        "}",
        "// 宿主每拍抽一次（本页 200ms 表；native-app 每帧）",
        "match @shell.hotkey_poll() {",
        "  Some(hk) => println(\"触发：\\{hk.spec}\")",
        "  None => ()",
        "}",
        "@shell.hotkey_unregister(hk)",
      ],
    ),
    @shared.section(
      "拖放",
      "应用内拖放 + 系统级拖入 / 拖出",
      "按住左边色块拖出 4px 即开拖，拖到右边面板上会描主色边，松手成交——这条三平台同构，同一棵树上能连着拖多少次都行。系统级**拖入**（从文件管理器拖文件、从编辑器拖文本进窗口）Windows/Linux 已接：外部事件每拍喂进同一条会话，落点命中、悬停描边、`accept` 判据全部复用，不收的落点系统光标直接显示禁止。系统级**拖出**（Windows/Linux）也走通：`drag_source(external=true)` 在过阈值那一刻把这趟交给系统，对方程序拿到标准的复制/移动/链接语义（Ctrl/Shift/Alt 定夺），本机没这条后端时自动回落到上面那条应用内会话。macOS 的系统级两档随平台批。",
      [
        @ui.row(
          [
            @ui.drag_source(
              @ui.view(
                [@ui.text("拖我", role=@ui.Body)],
                background_color="primary_light",
                border_color="primary",
                width=120.0,
                height=64.0,
                padding=8.0,
              ),
              payload=fn() { Some(@core.DragData::Text("窗口页的拖放演示")) },
            ),
            @ui.text("拖到右边 →", role=@ui.Secondary),
            @ui.drop_target(
              @ui.view(
                [@ui.text("投放区（松手成交）", role=@ui.Secondary)],
                background_color="bg_panel",
                border_color="border",
                width=220.0,
                height=64.0,
                padding=8.0,
              ),
              on_drop=fn(d : @core.DragData, _x : Double, _y : Double) -> Unit {
                match d {
                  @core.DragData::Text(t) => dnd.set("收到文本：\{t}")
                  @core.DragData::Paths(ps) => {
                    let joined = ps.join(" ; ")
                    dnd.set("应用内投进 \{ps.length()} 个路径：\{joined}")
                  }
                  _ => dnd.set("收到了别的载荷")
                }
              },
            ),
          ],
          column_gap=12.0,
          align_items=@yoga.AlignItems::Center,
        ),
        @ui.row(
          [
            @ui.drop_target(
              @ui.view(
                [@ui.text("只收文件（从资源管理器拖进来）", role=@ui.Secondary)],
                background_color="bg_panel",
                border_color="border",
                width=220.0,
                height=64.0,
                padding=8.0,
              ),
              accept=fn(d : @core.DragData) -> Bool {
                d.kind() == @core.FilePaths
              },
              on_drop=fn(d : @core.DragData, _x : Double, _y : Double) -> Unit {
                match d {
                  @core.DragData::Paths(ps) => {
                    let joined = ps.join(" ; ")
                    ext.set("外部投进 \{ps.length()} 个：\{joined}")
                  }
                  _ => ext.set("不该投到这里")
                }
              },
            ),
            @ui.text(
              if @core.drag_external_supported() {
                "系统级拖入：本机可用（试试从资源管理器拖文件）"
              } else {
                "系统级拖入：本机后端未接（拖放仍限应用内）"
              },
              role=@ui.Secondary,
            ),
          ],
          column_gap=12.0,
          align_items=@yoga.AlignItems::Center,
        ),
        @ui.row(
          [
            @ui.drag_source(
              @ui.view(
                [@ui.text("拖我出去\n（记事本/浏览器）", role=@ui.Body)],
                background_color="primary_light",
                border_color="primary",
                width=120.0,
                height=64.0,
                padding=8.0,
              ),
              payload=fn() { Some(@core.DragData::Text("窗口页的拖放演示")) },
              external=true,
              on_external=fn(r) { out.set("文本拖出：\{drag_send_text(r)}") },
            ),
            @ui.drag_source(
              @ui.view(
                [@ui.text("拖文件出去\n（桌面/资源管理器）", role=@ui.Body)],
                background_color="bg_panel",
                border_color="primary",
                width=150.0,
                height=64.0,
                padding=8.0,
              ),
              // 相对路径由后端绝对化（对方程序拿到的是完整位置）
              payload=fn() {
                Some(@core.DragData::Paths([ "README.md", "docs/zh/adaptation.md" ]))
              },
              external=true,
              on_external=fn(r) { out.set("文件拖出：\{drag_send_text(r)}") },
            ),
            @ui.text(
              if @core.drag_external_send_supported() {
                "系统级拖出：本机可用（Ctrl 复制 / Shift 移动 / Alt 链接）"
              } else {
                "系统级拖出：本机后端未接（自动回落应用内拖放）"
              },
              role=@ui.Secondary,
            ),
          ],
          column_gap=12.0,
          align_items=@yoga.AlignItems::Center,
        ),
        @ui.row(
          [
            @ui.text("投放回显：", role=@ui.Secondary),
            @ui.bind_label(dnd, fn(s) { s }),
            @ui.text("外部回显：", role=@ui.Secondary),
            @ui.bind_label(ext, fn(s) { s }),
          ],
          column_gap=6.0,
        ),
        @ui.row(
          [@ui.text("拖出回显：", role=@ui.Secondary), @ui.bind_label(out, fn(s) {
            s
          })],
          column_gap=6.0,
        ),
      ],
      code=[
        "// 拖源：过 4px 阈值才开拖，payload 取数（None 当普通点击）",
        "@ui.drag_source(",
        "  tile,",
        "  payload=fn() { Some(@core.DragData::Text(\"窗口页的拖放演示\")) },",
        ")",
        "// 投放目标：悬停描主色边（读 drag_hover 自判，无 enter/leave 三回调）",
        "@ui.drop_target(",
        "  panel,",
        "  accept=fn(d) { d.kind() == @core.FilePaths }, // 不收时系统光标显示禁止",
        "  on_drop=fn(d, _x, _y) {",
        "    match d {",
        "      @core.DragData::Paths(ps) => ...",
        "      _ => ...",
        "    }",
        "  },",
        ")",
        "// 系统级拖入（Windows/Linux）：建窗自动挂投放目标，宿主每拍抽事件喂进同一条",
        "// 会话；运行时探测决定这台机器能不能用（非 Windows 给 false）",
        "if @core.drag_external_supported() { ... }",
        "// 系统级拖出（Windows/Linux）：过阈值那一刻把这趟交给系统，阻塞到松手/取消；",
        "// 本机后端没接或这趟起不来时自动回落到应用内会话",
        "@ui.drag_source(",
        "  tile,",
        "  payload=fn() { Some(@core.DragData::Paths([ \"README.md\" ])) }, // 相对路径会被绝对化",
        "  external=true,",
        "  on_external=fn(r) { ... }, // Ok(效果)=成交/取消，Err=没走成（已回落）",
        ")",
      ],
    ),

    @shared.section(
      "任务栏",
      "任务栏进度",
      "写任务栏按钮的进度条与状态（Windows 的 ITaskbarList3，只写不读；Linux/mac 后端未接时按钮如实回报写失败，不静默）。",
      [
        @ui.row(
          [
            @ui.button("10%", on_click=fn() { taskbar_pct(1, 10, "10%") }),
            @ui.button("50%", on_click=fn() { taskbar_pct(5, 10, "50%") }),
            @ui.button("100%", on_click=fn() { taskbar_pct(10, 10, "100%") }),
            @ui.button("错误", variant=@ui.Danger, on_click=fn() {
              taskbar_state(@win.TaskbarState::Error, "错误")
            }),
            @ui.button("暂停", variant=@ui.Soft, on_click=fn() {
              taskbar_state(@win.TaskbarState::Paused, "暂停")
            }),
            @ui.button("不确定", variant=@ui.Soft, on_click=fn() {
              taskbar_state(@win.TaskbarState::Indeterminate, "不确定")
            }),
            @ui.button("清除", variant=@ui.Text, on_click=fn() {
              taskbar_state(@win.TaskbarState::NoProgress, "清除")
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(taskbar_out, fn(s) { s }),
      ],
      code=[
        "// 宿主窗口门面上只有写入口（后端没有 getter，进度值由调用方自持）",
        "match app.host.val {",
        "  Some(a) => {",
        "    let ok = a.window().set_taskbar_progress(5, 10) // 50%",
        "    let ok2 = a.window().set_taskbar_state(TaskbarState::Error)",
        "  }",
        "  None => ()",
        "}",
      ],
    ),
  ])
}
