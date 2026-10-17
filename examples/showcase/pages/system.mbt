// 系统集成页：文件对话框 / 消息框 / 通知 / 剪贴板 / 定时器 / 托盘 / 自启 /
// 外部打开 / 系统信息 / 音量。
//
// G7 迁移记档（与 master 旧页的差）：
// ① 旧页 13 段里 6 段本栈未接、整段不迁（按钮不放，口径写进本草头与人工清单）：
//    关闭拦截（无 should_close 钩子）、单实例（TODO §6 接线项）、无边框透明窗
//    （stub 无分层窗口透明度）、屏幕常亮（无 keep_awake）、休眠锁屏事件、
//    电量与网络（无电源事件通道）——后四样随平台批；
// ② 「电量网络」的位置换成本栈已有的「系统信息」（si_os/si_machine/si_memory/
//    si_uptime + desktop_name），另补「音量」段（vol_* 三平台门面已在）；
// ③ 通知从 `@yue.NotificationCenter` 切 `@shell.notify_send`（W 族门面：探测 +
//    结构化错误 + 后端名回显）；托盘从 `@yue.Tray` 切 `@shell.Tray`（dispatch 由
//    200ms 轮询表驱动——本栈宿主循环没有每帧钩子，native-app 同表）；
// ④ 文件对话框 parent 传宿主窗口 id（`App::wid().to_int64()`），旧链路传 View。

///|
/// 自启动用的应用 id（reverse-DNS 形态：autostart_valid_app_id 要求至少一个点、
/// 元素不以数字或 '-' 开头）。
const AUTOSTART_APP_ID : String = "libyue.showcase"

///|
/// 宿主窗口 id → 对话框 parent（0 = 无父窗口；这里恒有父）。
fn dialog_parent(a : @widget.App) -> Int64 {
  a.wid().to_int64()
}

///|
/// 托盘图标像素：32×32 BGRA（预乘 alpha，不透明圆）。与 native-app 的
/// `demo_icon_pixels` 同制法，这里只留一个琥珀圆。
fn tray_icon_pixels(n : Int) -> FixedArray[Byte] {
  let px : FixedArray[Byte] = FixedArray::make(n * n * 4, b'\x00')
  let c = n / 2
  for y = 0; y < n; y = y + 1 {
    for x = 0; x < n; x = x + 1 {
      let off = (y * n + x) * 4
      let dx = x - c
      let dy = y - c
      let inside = dx * dx + dy * dy < c * c
      px[off] = (if inside {
        40
      } else {
        0
      }).to_byte()
      px[off + 1] = (if inside {
        100
      } else {
        0
      }).to_byte()
      px[off + 2] = (if inside {
        230
      } else {
        0
      }).to_byte()
      px[off + 3] = (if inside {
        255
      } else {
        0
      }).to_byte()
    }
  }
  px
}

///|
/// 托盘派发表：挂上就跑，200ms 一拍自重排（宿主退出后 timer 自然不再响）。
/// 命中左键/菜单项都在 dispatch 里派发，回调即页内计数。
fn tray_poll_loop() -> Unit {
  let tick : Ref[() -> Unit] = Ref(fn() { () })
  tick.val = fn() -> Unit {
    let _ = @shell.dispatch_tray_event()
    match @widget.host_active() {
      Some(a) => ignore(a.timer(200, tick.val))
      None => ()
    }
  }
  (tick.val)()
}

///|
/// 「用指定程序打开」的演示对象：Windows 记事本、Linux gedit、macOS 给
/// TextEdit 的可执行路径（这一档按 argv 直传，`open -a 应用名` 那种形态随
/// mac 平台批再接）。挑不到的平台给空串，按钮直接演示 SpawnFailed。
fn open_probe_app() -> String {
  match @sys.sys_platform() {
    "windows" => "notepad.exe"
    "linux" => "gedit"
    "macos" => "/System/Applications/TextEdit.app/Contents/MacOS/TextEdit"
    _ => ""
  }
}

///|
/// 托盘错误 → 可读串（TrayError 三档：没后端 / 图标没建成 / 后端具体失败）。
fn tray_err_text(e : @shell.TrayError) -> String {
  match e {
    @shell.TrayError::Unsupported => "本平台没有托盘后端"
    @shell.TrayError::IconLoadFailed => "图标加载失败"
    @shell.TrayError::Backend(msg) => "托盘后端失败：\{msg}"
  }
}

///|
/// 消息框返回值 → 可读串（编号归一的语义枚举，不记数字）。
fn msgbox_result_label(r : @win.MessageBoxResult) -> String {
  match r {
    @win.Ok => "确定"
    @win.Cancel => "取消"
    @win.Abort => "中止"
    @win.Retry => "重试"
    @win.Ignore => "忽略"
    @win.Yes => "是"
    @win.No => "否"
    @win.Failed => "弹框失败"
  }
}

///|
/// 系统集成页。页内私有状态（回显/托盘句柄/周期表句柄）不进共享 App。
pub fn page_system(app : @shared.App) -> @widget.Node {
  let file_out : @base.Store[String] = @base.Store::new("（还没选过文件）")
  let mb_out : @base.Store[String] = @base.Store::new("（还没弹过框）")
  let nt_out : @base.Store[String] = @base.Store::new("（还没发过通知）")
  let cb_out : @base.Store[String] = @base.Store::new("（还没动过剪贴板）")
  let timer_out : @base.Store[String] = @base.Store::new("（表未起）")
  let ticks : @base.Store[Int] = @base.Store::new(0)
  let tray_note : @base.Store[String] = @base.Store::new("（还没建托盘）")
  let tray_clicks : @base.Store[Int] = @base.Store::new(0)
  // 托盘句柄（挂载闭包里建托盘时填入）：挂菜单 / 改提示要拿它
  let tray_holder : Ref[@shell.Tray?] = Ref(None)
  let auto_state : @base.Store[String] = @base.Store::new("（未读）")
  let ext_out : @base.Store[String] = @base.Store::new("（还没打开过外部）")
  let si_out : @base.Store[String] = @base.Store::new("（点「刷新」读一次）")
  let vol_out : @base.Store[String] = @base.Store::new("（还没读过音量）")
  // 周期表句柄（0 = 没起）；停表用
  let tick_id : Ref[Int] = Ref(0)
  // 自启动开关：Store 是唯一态，subscribe 落进真实系统状态。
  // priming 标志：初值读取不算「用户改动」，不能反向写一遍系统
  let auto_on : @base.Store[Bool] = @base.Store::new(false)
  let auto_primed : Ref[Bool] = Ref(false)
  auto_on.subscribe(fn(v : Bool) -> Unit {
    if !auto_primed.val {
      return
    }
    if !@sys.autostart_supported() {
      auto_state.set("本平台不支持开机自启")
      return
    }
    let r = if v {
      @sys.autostart_enable(AUTOSTART_APP_ID)
    } else {
      @sys.autostart_disable(AUTOSTART_APP_ID)
    }
    match r {
      Ok(_) => auto_state.set(if v { "已开启（重新登录后生效）" } else { "已关闭" })
      Err(e) => auto_state.set("写入失败：\{e}")
    }
  })
  match @sys.autostart_is_enabled(AUTOSTART_APP_ID) {
    Ok(v) => {
      auto_on.set(v)
      auto_state.set(if v { "已开启（重新登录后生效）" } else { "已关闭" })
    }
    Err(_) => auto_state.set("读不到当前自启状态")
  }
  auto_primed.val = true
  @shared.page([
    @shared.section(
      "文件",
      "文件对话框",
      "原生模态文件对话框：打开回显所选路径；保存把一行文本写进你选的文件。对话框挂在本窗口上（parent = 宿主窗口 id）。",
      [
        @ui.row(
          [
            @ui.button("打开文件…", on_click=fn() {
              match app.host.val {
                Some(a) => {
                  let dlg = @sys.FileDialog::new_open()
                  dlg.set_filters("文本文件:txt,md|所有文件:*")
                  if dlg.run_for_window(dialog_parent(a)) {
                    let p = dlg.get_result()
                    file_out.set("已选：\{p}")
                    match @sys.sys_read_text_file(p) {
                      Some(t) => file_out.set("已选：\{p}（读回 \{t.length()} 字符）")
                      None => file_out.set("已选：\{p}（读不出内容或不是文本）")
                    }
                  } else {
                    file_out.set("已取消")
                  }
                  dlg.destroy()
                }
                None => ()
              }
            }),
            @ui.button("保存文件…", variant=@ui.Soft, on_click=fn() {
              match app.host.val {
                Some(a) => {
                  let dlg = @sys.FileDialog::new_save()
                  dlg.set_filters("文本文件:txt|所有文件:*")
                  dlg.set_filename("showcase.txt")
                  if dlg.run_for_window(dialog_parent(a)) {
                    let p = dlg.get_result()
                    file_out.set(
                      if @sys.sys_write_text_file(p, "libyue 演示板写入\n") {
                        "已写入：\{p}"
                      } else {
                        "写入失败：\{p}"
                      },
                    )
                  } else {
                    file_out.set("已取消")
                  }
                  dlg.destroy()
                }
                None => ()
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(file_out, fn(s) { s }),
      ],
      code=[
        "let dlg = @sys.FileDialog::new_open()",
        "dlg.set_filters(\"文本文件:txt,md|所有文件:*\")",
        "let parent = a.wid().to_int64() // 宿主窗口 id",
        "if dlg.run_for_window(parent) {",
        "  let p = dlg.get_result()",
        "  ignore(@sys.sys_read_text_file(p))",
        "}",
        "dlg.destroy()",
      ],
    ),
    @shared.section(
      "消息框",
      "原生消息框",
      "模态消息框（Win32 MessageBoxW / GTK 对话框）：信息档 × 是/否，错误档 × 是/否/取消。返回值归一成语义枚举，不记编号。",
      [
        @ui.row(
          [
            @ui.button("信息 是/否", on_click=fn() {
              let r = @win.show_message_box(
                "libyue 演示板",
                "原生消息框：点「是」或「否」看回显。",
                @win.Information,
                @win.YesNo,
              )
              mb_out.set("信息档 → \{msgbox_result_label(r)}")
            }),
            @ui.button("错误 是/否/取消", variant=@ui.Danger, on_click=fn() {
              let r = @win.show_message_box(
                "libyue 演示板",
                "错误档：三个按钮都能收回语义。",
                @win.Error,
                @win.YesNoCancel,
              )
              mb_out.set("错误档 → \{msgbox_result_label(r)}")
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(mb_out, fn(s) { s }),
      ],
      code=[
        "let r = @win.show_message_box(",
        "  \"libyue 演示板\",",
        "  \"原生消息框：点「是」或「否」看回显。\",",
        "  Information,",
        "  YesNo,",
        ")",
        "match r { Yes => ... No => ... _ => ... }",
      ],
    ),
    @shared.section(
      "通知",
      "系统通知",
      "系统通知中心：普通通知与带进度条通知。后端不可用（无 dbus 会话等）时明说失败，不假装成功。",
      [
        @ui.row(
          [
            @ui.button("普通通知", on_click=fn() {
              match @shell.notify_send("libyue 演示板", "构建完成", "3 个目标已产出") {
                Ok(id) => nt_out.set("已发送 #\{id}")
                Err(e) => nt_out.set("发送失败：\{e}")
              }
            }),
            @ui.button("带进度 60%", variant=@ui.Soft, on_click=fn() {
              match
                @shell.notify_send(
                  "libyue 演示板",
                  "同步中",
                  "已完成 60%",
                  kind=1,
                  progress=60,
                ) {
                Ok(id) => nt_out.set("已发送 #\{id}（带进度）")
                Err(e) => nt_out.set("发送失败：\{e}")
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(nt_out, fn(s) { s }),
        @ui.text(
          if @shell.notify_supported() {
            "通知后端可用"
          } else {
            "通知后端不可用（按钮会报失败）"
          },
          role=@ui.Secondary,
        ),
      ],
      code=[
        "match @shell.notify_send(",
        "  \"libyue 演示板\", \"构建完成\", \"3 个目标已产出\") {",
        "  Ok(id) => println(\"已发送 #\\{id}\")",
        "  Err(e) => println(\"失败: \\{e}\")",
        "}",
        "// 带进度：progress=60, kind=1",
      ],
    ),
    @shared.section(
      "剪贴板",
      "剪贴板",
      "读写系统剪贴板文本。写入后点「读取」验证（也可以直接粘到别的程序里）。",
      [
        @ui.row(
          [
            @ui.button("写入文本", on_click=fn() {
              cb_out.set(
                if @sys.clipboard_set_text("libyue 演示板 · 剪贴板写入") {
                  "已写入（去别处粘贴试试）"
                } else {
                  "写入失败（剪贴板不可用）"
                },
              )
            }),
            @ui.button("读取剪贴板", variant=@ui.Soft, on_click=fn() {
              match @sys.clipboard_get_text() {
                Some(t) => cb_out.set("读到：\{t}")
                None => cb_out.set("读不到（空或不可用）")
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(cb_out, fn(s) { s }),
      ],
      code=[
        "@sys.clipboard_set_text(\"libyue 演示板 · 剪贴板写入\")",
        "match @sys.clipboard_get_text() {",
        "  Some(t) => println(\"读到: \\{t}\")",
        "  None => println(\"空或不可用\")",
        "}",
      ],
    ),
    @shared.section(
      "定时器",
      "定时器与延时任务",
      "宿主 `timer` 周期表（句柄可停）+ `set_timeout` 进程级单次延时。两族都自重排，不需要外部循环配合。",
      [
        @ui.row(
          [
            @ui.button("1.5 秒后提示", on_click=fn() {
              ignore(
                @shell.set_timeout(1500, fn() {
                  app.toast_push("延时任务触发", @ui.Success)
                }),
              )
              timer_out.set("已排 1.5s 单次")
            }),
            @ui.button("起周期表(1s)", variant=@ui.Soft, on_click=fn() {
              if tick_id.val != 0 {
                timer_out.set("表已经在跑")
              } else {
                match app.host.val {
                  Some(a) => {
                    let tick : Ref[() -> Unit] = Ref(fn() { () })
                    tick.val = fn() -> Unit {
                      ticks.update(fn(n) { n + 1 })
                      // 自重排的周期表：每次重排都要把**新句柄**记回 tick_id，
                      // 否则「停表」取消的是已经跑掉的那一号，表照旧在响
                      tick_id.val = a.timer(1000, tick.val)
                    }
                    tick_id.val = a.timer(1000, tick.val)
                    timer_out.set("表已起（1s 一拍）")
                  }
                  None => ()
                }
              }
            }),
            @ui.button("停表", variant=@ui.Text, on_click=fn() {
              match app.host.val {
                Some(a) =>
                  if tick_id.val != 0 {
                    ignore(a.cancel_timer(tick_id.val))
                    tick_id.val = 0
                    timer_out.set("表已停")
                  } else {
                    timer_out.set("表没在跑")
                  }
                None => ()
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(timer_out, fn(s) { s }),
        @ui.bind_label(ticks, fn(n) { "周期表已响 \{n} 次" }),
      ],
      code=[
        "// 单次延时（进程级）",
        "ignore(@shell.set_timeout(1500, fn() {",
        "  app.toast_push(\"延时任务触发\", Success)",
        "}))",
        "// 周期表：回调里自重排，且每次都要记回新句柄才可停",
        "let id = a.timer(1000, tick)",
        "ignore(a.cancel_timer(id))",
      ],
    ),
    @shared.section(
      "托盘",
      "系统托盘",
      "托盘图标左键计数、右键弹菜单（「挂菜单」后）；dispatch 走 200ms 轮询表（宿主循环没有每帧钩子）。图标是运行期生成的 32px BGRA 位图，菜单复用 W20a 菜单模型。",
      [
        // 零尺寸挂载钩子：建托盘（启动即出图标）在构造期，派发表起表必须挂
        // 真·挂载时机（Node::on_mount）——node_of_new 的 finish 是构造期执行，
        // 那时宿主还没建好，tray_poll_loop 首拍读到 @widget.host_active() 为 None
        // 就永久不再重排，之后左右键事件全压在队列里没人抽，右键「自动弹出已挂
        // 的菜单」也走不到；真机表现正是「图标在、点了没反应、菜单弹不出」。
        // （与快捷键页轮询表、图表页推点同一条坑的第 3 处。）
        @widget.node_of_new(fn(w : @widget.Widget) -> @widget.Widget {
          // 图标句柄只是 Win32 那一档要的东西（HICON），Linux 的 SNI 不读它、
          // 面板用库内置位图显示——所以拿到什么照传、拿不到也照建。
          // （旧写法把整段挂在 icon 成功之后，而 wm_icon_from_bgra 在 GTK 分支
          //  是失败桩恒给句柄 0，于是 Linux 上托盘根本没起过。）
          let ic = @win.icon_from_bgra(tray_icon_pixels(32), 32, 32)
          match @shell.Tray::new("libyue-showcase-tray", icon=ic) {
            Ok(t) => {
              t.set_tooltip("libyue 演示板", "左键计数 · W 族门面")
              t.on_click(fn() {
                tray_clicks.update(fn(n) { n + 1 })
                app.toast_push("托盘左键被点了", @ui.Info)
              })
              tray_holder.val = Some(t)
              tray_note.set("已建（\{t.backend_name()}）")
            }
            Err(e) => {
              tray_note.set(tray_err_text(e))
              match ic {
                Some(x) => x.free()
                None => ()
              }
            }
          }
          w
        }).on_mount(fn() -> Unit {
          tray_poll_loop()
        }),
        @ui.row(
          [
            @ui.button("改提示", variant=@ui.Soft, on_click=fn() {
              match tray_holder.val {
                Some(t) => {
                  t.set_tooltip("libyue 演示板", "提示已改 · \{tray_clicks.get()} 次左键")
                  tray_note.set("提示已改（悬停托盘图标可见）")
                }
                None => tray_note.set("托盘未建，改不了提示")
              }
            }),
            // 右键菜单：复用 W20a 菜单模型（Tray::set_menu）；菜单项点击
            // 经同一条 dispatch_menu_command 派发链回到回调（main 挂了表）
            @ui.button("挂菜单", variant=@ui.Soft, on_click=fn() {
              match tray_holder.val {
                Some(t) => {
                  let menu = @shell.Menu::new(title="托盘")
                  let _ = menu.add_item("冒个提示").set_on_click(fn() {
                    app.toast_push("来自托盘菜单", @ui.Info)
                  })
                  let _ = menu.add_item("回首页").set_on_click(fn() {
                    app.selected.set("基础组件")
                  })
                  let _ = menu.add_separator()
                  let _ = menu.add_item("退出").set_on_click(fn() {
                    match app.host.val {
                      Some(a) => a.quit()
                      None => ()
                    }
                  })
                  t.set_menu(menu)
                  tray_note.set("菜单已挂（右键托盘图标）")
                }
                None => tray_note.set("托盘未建，挂不了菜单")
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(tray_note, fn(s) { s }),
        @ui.bind_label(tray_clicks, fn(n) { "左键 \{n} 次" }),
      ],
      code=[
        "let ic = @win.icon_from_bgra(tray_icon_pixels(32), 32, 32)",
        "match @shell.Tray::new(\"libyue-showcase-tray\", icon=Some(ic)) {",
        "  Ok(t) => {",
        "    t.set_tooltip(\"libyue 演示板\", \"左键计数\")",
        "    t.on_click(fn() { clicks.val = clicks.val + 1 })",
        "    // 右键菜单：菜单模型翻译成弹出菜单挂上，",
        "    // 选中项经 dispatch_menu_command 回到 on_click",
        "    t.set_menu(menu)",
        "  }",
        "  Err(e) => ...",
        "}",
        "// 派发表：宿主循环没有每帧钩子，示例自挂 200ms 表",
        "let _ = @shell.dispatch_tray_event()",
      ],
    ),
    @shared.section(
      "自启",
      "开机自启动",
      "开关直连真实自启动状态（Linux 写 ~/.config/autostart，Windows 写 Run 键）。重新登录后生效；关闭即撤销。",
      [
        @ui.row(
          [
            @ui.switch(auto_on, on_text="开启自启", off_text="关闭自启"),
            @ui.bind_label(auto_state, fn(s) { s }),
          ],
          column_gap=10.0,
          align_items=@yoga.AlignItems::Center,
        ),
      ],
      code=[
        "// 读当前真实状态",
        "match @sys.autostart_is_enabled(\"libyue.showcase\") {",
        "  Ok(v) => on.set(v)",
        "  Err(_) => ...",
        "}",
        "// 开关即写系统",
        "@sys.autostart_enable(\"libyue.showcase\")",
        "@sys.autostart_disable(\"libyue.showcase\")",
      ],
    ),
    @shared.section(
      "外部",
      "打开外部",
      "把 URL 交给默认浏览器、把文件交给默认程序或指定程序、把路径交给文件管理器。文件走 `@sys.open_file` / `@sys.open_file_with`（相对路径按工作目录归一，路径不存在先给 `NotFound`，不把「打不开」说成「已交给系统」）；定位走 `@shell.reveal_in_file_manager`：Linux 先试会话总线的 `FileManager1.ShowItems`（打开并**选中**），不在线才退回 `xdg-open` 打开父目录（选中态丢失），Windows 直调 `explorer /select`（分隔符统一成反斜杠才会选中）。Ok 只表示已交给系统，之后归操作系统。",
      [
        @ui.row(
          [
            @ui.button("打开 libyue.com", on_click=fn() {
              match @sys.open_url("https://libyue.com") {
                Ok(_) => ext_out.set("已交给默认浏览器")
                Err(e) => ext_out.set("打开失败：\{e}")
              }
            }),
            @ui.button("在文件管理器显示 TODO.md", variant=@ui.Soft, on_click=fn() {
              match @shell.reveal_in_file_manager("TODO.md") {
                Ok(_) => ext_out.set("已交给文件管理器")
                Err(e) => ext_out.set("显示失败：\{e}")
              }
            }),
            @ui.button("用默认程序打开 TODO.md", variant=@ui.Soft, on_click=fn() {
              match @sys.open_file("TODO.md") {
                Ok(_) => ext_out.set("已交给默认程序")
                Err(e) => ext_out.set("默认程序打开失败：\{e}")
              }
            }),
            @ui.button("用指定程序打开 TODO.md", variant=@ui.Soft, on_click=fn() {
              let app = open_probe_app()
              match @sys.open_file_with(app, "TODO.md") {
                Ok(_) => ext_out.set("已交给 \{app}")
                Err(e) => ext_out.set("指定程序（\{app}）打开失败：\{e}")
              }
            }),
            @ui.button("用指定程序打开不存在的路径", variant=@ui.Soft, on_click=fn() {
              match @sys.open_file_with(open_probe_app(), "no-such-file-zzz.md") {
                Ok(_) => ext_out.set("已交给指定程序")
                Err(e) => ext_out.set("按预期被拦下：\{e}")
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(ext_out, fn(s) { s }),
      ],
      code=[
        "match @sys.open_url(\"https://libyue.com\") {",
        "  Ok(_) => println(\"已交给默认浏览器\")",
        "  Err(e) => println(\"失败: \\{e}\")",
        "}",
        "// 打开并选中：Linux 走 FileManager1.ShowItems，退回 xdg-open 父目录\n",
        "match @shell.reveal_in_file_manager(\"TODO.md\") { ... }",
        "// 用默认程序打开（相对路径按工作目录归一，路径不存在先给 NotFound）",
        "match @sys.open_file(\"TODO.md\") { ... }",
        "// 用指定程序打开：app 可以是 PATH 里的命令名或完整可执行路径",
        "match @sys.open_file_with(\"notepad.exe\", \"TODO.md\") { ... }",
      ],
    ),
    @shared.section(
      "信息音量",
      "系统信息与音量",
      "信息：发行版 / 机器 / 内存 / 开机时长 + 桌面环境（替代旧页「电量网络」——电源与网络事件本栈未接，随平台批）。音量：读当前音量/静音、设百分比、切静音（Linux pactl / Windows CoreAudio），后端不可用时按钮明说。",
      [
        @ui.row(
          [
            @ui.button("刷新系统信息", on_click=fn() {
              si_out.set(read_sysinfo())
            }),
            @ui.button("读音量", on_click=fn() {
              match @sys.vol_get() {
                Ok(v) => vol_out.set("音量 \{v.volume}% 静音=\{v.muted}（\{v.sink}）")
                Err(e) => vol_out.set("读取失败：\{e}")
              }
            }),
            @ui.button("设为 50%", variant=@ui.Soft, on_click=fn() {
              match @sys.vol_set(50) {
                Ok(_) => vol_out.set("已设为 50%")
                Err(e) => vol_out.set("设置失败：\{e}")
              }
            }),
            @ui.button("静音切换", variant=@ui.Text, on_click=fn() {
              match @sys.vol_get() {
                Ok(v) =>
                  match @sys.vol_set_mute(!v.muted) {
                    Ok(_) => vol_out.set(if v.muted { "已取消静音" } else { "已静音" })
                    Err(e) => vol_out.set("设置失败：\{e}")
                  }
                Err(e) => vol_out.set("读取失败：\{e}")
              }
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(si_out, fn(s) { s }),
        @ui.bind_label(vol_out, fn(s) { s }),
      ],
      code=[
        "match @sys.si_os() {",
        "  Ok(o) => println(\"\\{o.pretty_name} \\{o.version_id}\")",
        "  Err(_) => ...",
        "}",
        "// 同族：si_machine / si_memory / si_uptime / desktop_name",
        "match @sys.vol_get() {",
        "  Ok(v) => println(\"\\{v.volume}% muted=\\{v.muted}\")",
        "  Err(e) => ...",
        "}",
        "@sys.vol_set(50)",
        "@sys.vol_set_mute(true)",
      ],
    ),
  ])
}

///|
/// 系统信息一次读完拼成一屏（读不到的项标注原因，不静默丢）。
fn read_sysinfo() -> String {
  let sb = StringBuilder()
  match @sys.si_os() {
    Ok(o) => {
      sb.write_string("系统：\{o.pretty_name}")
      if o.version_id.length() > 0 {
        sb.write_string("（\{o.version_id}）")
      }
      sb.write_string("\n")
    }
    Err(_) => sb.write_string("系统：本平台读不到发行版\n")
  }
  match @sys.si_machine() {
    Ok(m) => sb.write_string("机器：\{m.vendor} \{m.product}\n")
    Err(_) => sb.write_string("机器：本平台读不到\n")
  }
  match @sys.si_memory() {
    Ok(mm) =>
      sb.write_string(
        "内存：可用 \{mm.available_kb / 1024} MB / 共 \{mm.total_kb / 1024} MB\n",
      )
    Err(_) => sb.write_string("内存：本平台读不到\n")
  }
  match @sys.si_uptime() {
    Ok(u) => sb.write_string("开机：\{u.to_int()} 秒\n")
    Err(_) => sb.write_string("开机时长：本平台读不到\n")
  }
  sb.write_string("桌面：\{@sys.desktop_name()}")
  sb.to_string()
}
