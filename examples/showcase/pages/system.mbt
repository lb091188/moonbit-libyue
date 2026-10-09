// 系统集成页:文件对话框/消息框/通知/剪贴板/定时器/托盘/透明窗/
// 关闭拦截。跨页状态(窗口与托盘句柄、关闭拦截)在 App。

///|
fn draw_heart(painter : @yue.Painter) -> Unit {
  painter.begin_path()
  painter.move_to(75.0, 40.0)
  painter.bezier_curve_to(75.0, 37.0, 70.0, 25.0, 50.0, 25.0)
  painter.bezier_curve_to(20.0, 25.0, 20.0, 62.5, 20.0, 62.5)
  painter.bezier_curve_to(20.0, 80.0, 40.0, 102.0, 75.0, 120.0)
  painter.bezier_curve_to(110.0, 102.0, 130.0, 80.0, 130.0, 62.5)
  painter.bezier_curve_to(130.0, 62.5, 130.0, 25.0, 100.0, 25.0)
  painter.bezier_curve_to(85.0, 25.0, 75.0, 37.0, 75.0, 40.0)
  painter.fill()
}

///|
/// 无边框透明置顶的心形小窗,整窗可拖动(悬浮件/桌面宠物的形态基础)。
fn open_floating_heart() -> Unit {
  let win = @yue.Window::new_with_options(frame=false, transparent=true)
  win.set_always_on_top(true)
  win.set_content_size(150.0, 130.0)
  let content = @yue.Container::new()
  content.set_mouse_down_can_move_window(true)
  win.set_content(content)
  content.on_draw(fn(painter) {
    painter.set_fill_color("#3000")
    draw_heart(painter)
    painter.translate(-5.0, -5.0)
    painter.set_fill_color("#D46A6A")
    draw_heart(painter)
  })
  win.center()
  win.activate()
}

///|
pub fn page_system(app : @ui.App) -> @yue.Node {
  // 月相循环表:set_icon 只吃 PNG 文件路径,点一次切一个相
  let moon_idx = Ref(0)
  let moon_phases = [
    ("新月", "examples/showcase/assets/tray_moon_new.png"),
    ("娥眉月", "examples/showcase/assets/tray_moon_crescent.png"),
    ("上弦月", "examples/showcase/assets/tray_moon_quarter.png"),
    ("盈凸月", "examples/showcase/assets/tray_moon_gibbous.png"),
    ("满月", "examples/showcase/assets/tray_moon_full.png"),
  ]
  let secs : Array[@ui.Section] = [
    @ui.section(
      "文件",
      "文件对话框",
      "FileDialog 模态打开/保存,回显所选路径;API: read/write_text_file",
      [
        @yue.hbox([
          @yue.button_t("打开文件…", on_click=fn() {
            match app.win_ref.val {
              Some(w) => {
                let dlg = @yue.FileDialog::new_open()
                dlg.set_filters("文本文件:txt,md|所有文件:*")
                if dlg.run_for_window(w) {
                  app.toast_push("已选 \{dlg.get_result()}", @yue.Success)
                } else {
                  app.toast_push("已取消", @yue.Info)
                }
              }
              None => ()
            }
          }),
          @yue.button_t("保存文件…", on_click=fn() {
            match app.win_ref.val {
              Some(w) => {
                let dlg = @yue.FileDialog::new_save()
                dlg.set_filename("components.txt")
                if dlg.run_for_window(w) {
                  let ok = @yue.write_text_file(
                    dlg.get_result(),
                    "由 components 写入\n",
                  )
                  app.toast_push(
                    if ok {
                      "已保存 \{dlg.get_result()}"
                    } else {
                      "保存失败"
                    },
                    if ok {
                      @yue.Success
                    } else {
                      @yue.Danger
                    },
                  )
                } else {
                  app.toast_push("已取消", @yue.Info)
                }
              }
              None => ()
            }
          }),
        ]),
      ],
      code=[
        "let dlg = @yue.FileDialog::new_open()", "dlg.set_filters(\"文本文件:txt,md|所有文件:*\")",
        "if dlg.run_for_window(w) {", "  println(\"已选 \\{dlg.get_result()}\")",
        "} else {", "  println(\"已取消\")", "}", "let save = @yue.FileDialog::new_save()",
        "save.set_filename(\"components.txt\")", "if save.run_for_window(w) {", "  ignore(@yue.write_text_file(save.get_result(), \"内容\\n\"))",
        "}",
      ],
    ),
    @ui.section(
      "消息框",
      "消息框",
      "原生 MessageBox:标题/正文/按钮,响应 id 回传。",
      [
        @yue.hbox([
          @yue.button_t("询问框", on_click=fn() {
            match app.win_ref.val {
              Some(w) => {
                let box = @yue.MessageBox::new(@yue.Information)
                box.set_title("确认操作")
                box.set_text("要执行该操作吗?")
                box.add_button("确定", 1)
                box.add_button("取消", 2)
                box.on_response(fn(code) {
                  app.toast_push("消息框响应 id=\{code}", @yue.Info)
                })
                box.show_for_window(w)
              }
              None => ()
            }
          }),
          @yue.button_t("警告框", on_click=fn() {
            match app.win_ref.val {
              Some(w) => {
                let box = @yue.MessageBox::new(@yue.Warning)
                box.set_title("警告")
                box.set_text("此操作不可撤销!")
                box.on_response(fn(code) {
                  app.toast_push("消息框响应 id=\{code}", @yue.Info)
                })
                box.show_for_window(w)
              }
              None => ()
            }
          }),
        ]),
      ],
      code=[
        "let mb = @yue.MessageBox::new(@yue.Information)", "mb.set_title(\"确认操作\")",
        "mb.set_text(\"要执行该操作吗?\")", "mb.add_button(\"确定\", 1)",
        "mb.add_button(\"取消\", 2)", "mb.on_response(fn(code) { println(\"响应 id=\\{code}\") })",
        "mb.show_for_window(w)",
      ],
    ),
    @ui.section(
      "通知",
      "系统通知",
      "提交系统通知中心:普通通知、带操作按钮、静默入中心三种形态。",
      [
        @yue.hbox([
          @yue.button_t("普通通知", on_click=fn() {
            let n = @yue.Notification::new()
            n.set_title("components 演示")
            n.set_body(
              "这是一条系统通知,点击后已提交通知中心。",
            )
            n.show()
            app.toast_push("通知已提交", @yue.Success)
          }),
          @yue.button_t("带按钮", on_click=fn() {
            let n = @yue.Notification::new()
            n.set_title("带操作按钮的通知")
            n.set_body("点通知上的按钮试试(查看 / 忽略)")
            n.set_actions([("查看", "view"), ("忽略", "ignore")])
            n.show()
          }),
          @yue.button_t("静默通知", variant=@yue.Soft, on_click=fn() {
            let n = @yue.Notification::new()
            n.set_title("静默通知")
            n.set_body("set_silent(true):不发声不打扰")
            n.set_silent(true)
            @yue.NotificationCenter::add(n)
          }),
        ]),
      ],
      code=[
        "let n = @yue.Notification::new()", "n.set_title(\"components 演示\")",
        "n.set_body(\"这是一条系统通知。\")", "n.show()", "n.set_actions([(\"查看\", \"view\"), (\"忽略\", \"ignore\")])",
        "n.set_silent(true)", "@yue.NotificationCenter::add(n)",
      ],
    ),
    @ui.section(
      "剪贴板",
      "剪贴板",
      "Clipboard 读写系统剪贴板文本;set_data 写富文本(Html)。",
      [
        @yue.hbox([
          @yue.button_t("写入文本", on_click=fn() {
            @yue.Clipboard::get().set_text(
              "来自 components 的剪贴板内容",
            )
            app.toast_push("已写入剪贴板", @yue.Success)
          }),
          @yue.button_t("读回显示", variant=@yue.Solid, on_click=fn() {
            let t = @yue.Clipboard::get().get_text()
            app.toast_push(
              if t == "" {
                "剪贴板为空"
              } else {
                "读到: \{t}"
              },
              if t == "" {
                @yue.Warning
              } else {
                @yue.Info
              },
            )
          }),
          @yue.button_t("写 HTML 富文本", on_click=fn() {
            @yue.Clipboard::get().set_data(
              @yue.Html,
              "<b>components 富文本剪贴板</b>",
            )
            app.toast_push("已写入 Html 富文本", @yue.Success)
          }),
        ]),
      ],
      code=[
        "@yue.Clipboard::get().set_text(\"剪贴板内容\")", "let t = @yue.Clipboard::get().get_text()",
        "@yue.Clipboard::get().set_data(@yue.Html, \"<b>富文本</b>\")",
      ],
    ),
    @ui.section(
      "定时器",
      "定时器与延迟任务",
      "set_timeout 单次 / set_timer 周期(返回 false 停)。",
      [
        @yue.hbox([
          @yue.button_t("1.5 秒后提示", on_click=fn() {
            ignore(
              @yue.set_timeout(1500, fn() {
                app.toast_push("延时任务触发", @yue.Success)
              }),
            )
          }),
          @yue.button_t("周期计数到 3", variant=@yue.Solid, on_click=fn() {
            let n = Ref(0)
            @yue.set_timer(700, fn() {
              n.val = n.val + 1
              app.toast_push("第 \{n.val} 次周期回调", @yue.Info)
              n.val < 3
            })
          }),
        ]),
      ],
      code=[
        "ignore(@yue.set_timeout(1500, fn() { println(\"延时任务\") }))", "let n = Ref(0)",
        "@yue.set_timer(700, fn() {", "  n.val = n.val + 1", "  n.val < 3", "})",
      ],
    ),
    @ui.section(
      "托盘",
      "托盘状态",
      "托盘图标左键点击计数(见上方回显),右键弹菜单;set_icon 更换图标须传 PNG 文件路径,点击在五个月相图标间循环,主题图标名仅 Linux。",
      [
        @yue.bind_label(app.tray_clicks, fn(n) {
          "托盘图标已被点击 \{n} 次"
        }),
        @yue.hbox(
          [
            @yue.button_t("切主题图标(Linux)", on_click=fn() {
              match app.tray_ref.val {
                Some(t) => {
                  t.set_icon_name("utilities-terminal")
                  app.toast_push(
                    "托盘图标已切为系统主题图标",
                    @yue.Success,
                  )
                }
                None => app.toast_push("托盘不可用", @yue.Warning)
              }
            }),
            @yue.button_t("切换月相图标", on_click=fn() {
              match app.tray_ref.val {
                Some(t) => {
                  let (phase_name, phase_path) = moon_phases[moon_idx.val]
                  t.set_icon(phase_path)
                  app.toast_push(
                    "托盘图标已切换:\{phase_name}(PNG)",
                    @yue.Info,
                  )
                  moon_idx.val = (moon_idx.val + 1) % moon_phases.length()
                }
                None => app.toast_push("托盘不可用", @yue.Warning)
              }
            }),
          ],
          style=[("marginTop", 8.0)],
        ),
      ],
      code=[
        "match @yue.Tray::new(\"examples/showcase/assets/icon.png\") {", "  Ok(tray) => {",
        "    tray.set_tooltip(\"演示托盘\", \"左键计数,右键菜单\")",
        "    // set_icon 只吃 PNG 文件路径;月相五连循环",
        "    tray.set_icon(\"examples/showcase/assets/tray_moon_full.png\")",
        "    // set_icon_name 仅 Linux SNI 后端支持",
        "    tray.set_icon_name(\"utilities-terminal\")", "  }", "  Err(_e) => ()",
        "}",
      ],
    ),
    @ui.section(
      "透明窗",
      "无边框透明窗口",
      "无边框透明置顶,整窗可拖动;无编程关闭 API,随应用退出。",
      [
        @yue.button_t("打开悬浮心形窗口", variant=@yue.Solid, on_click=fn() {
          open_floating_heart()
        }),
      ],
      code=[
        "let win = @yue.Window::new_with_options(frame=false, transparent=true)",
        "win.set_always_on_top(true)", "win.set_content_size(150.0, 130.0)", "let content = @yue.Container::new()",
        "content.set_mouse_down_can_move_window(true)", "win.set_content(content)",
        "content.on_draw(fn(p) {", "  p.set_fill_color(\"#D46A6A\")", "  // …画任意形状",
        "})", "win.center()", "win.activate()",
      ],
    ),
    @ui.section(
      "拦截",
      "关闭拦截",
      "勾选后点窗口关闭被 set_should_close 拦下",
      [
        @yue.checkbox_t("开启关闭拦截", checked=false, on_change=fn(v) {
          app.close_veto.val = v
          if !v {
            app.veto_info.set("(未开启拦截)")
          }
        }),
        @yue.bind_label(app.veto_info, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
      code=["w.set_should_close(fn() {", "  false", "})"],
    ),
  ]
  // 单实例:角色与唤起参数在 main 启动时采集,这里只展示
  secs.push(
    @ui.section(
      "单实例",
      "单实例与二次唤起",
      "再启动一个本程序,新实例会唤醒本窗口后退出。",
      [
        @yue.bind_label(app.si_role, fn(s) { s }, style=[("marginBottom", 4.0)]),
        @yue.bind_label(app.si_wake, fn(s) { s }),
      ],
      code=[
        "match @yue.SingleInstance::acquire(\"org.app.Id\") {", "  Ok(Some(si)) => si.on_activate(fn(args) {",
        "    println(\"收到唤起:\\{args.length()} 个参数\")", "  })", "  Ok(None) => println(\"已有实例,本实例退出\")",
        "  Err(e) => println(\"不可用:\\{e}(降级继续运行)\")", "}",
      ],
    ),
  )
  // 开机自启动:开关直连真实状态(Linux 写 XDG 自启动目录,Windows 写
  // HKCU Run 键);冒烟验证后关掉即复位
  let auto : @yue.Autostart = match
    @yue.Autostart::new("org.moonbitlibyue.Showcase") {
    Ok(a) => a
    Err(_) => abort("unreachable") // 固定 app_id 恒合法
  }
  let auto_on : @yue.Store[Bool] = @yue.Store::new(
    match auto.is_enabled() {
      Ok(v) => v
      Err(_) => false
    },
  )
  let auto_out : @yue.Store[String] = @yue.Store::new(
    "(开关即真实生效,重新登录后拉起)",
  )
  auto_on.subscribe(fn(on) {
    let r = if on { auto.enable() } else { auto.disable() }
    auto_out.set(
      match r {
        Ok(_) =>
          if on {
            "已启用:重启 / 重新登录后自动拉起"
          } else {
            "已关闭:自启动已移除"
          }
        Err(e) => "操作失败:\{e}"
      },
    )
  })
  secs.push(
    @ui.section(
      "自启",
      "开机自启动",
      "开关直连真实自启动状态,重新登录后生效。",
      [
        @yue.hbox([
          @yue.switch_t(auto_on),
          @yue.label_t("org.moonbitlibyue.Showcase", role=@yue.Secondary),
        ]),
        @yue.bind_label(auto_out, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
      code=[
        "match @yue.Autostart::new(\"org.app.Id\") {", "  Ok(auto) => {", "    ignore(auto.enable())",
        "    println(auto.is_enabled())", "    ignore(auto.disable())", "  }", "  Err(e) => println(e)",
        "}",
      ],
    ),
  )
  // 打开外部:URL 交默认浏览器,文件管理器选中(README.md 相对工作目录解析)
  secs.push(
    @ui.section(
      "外部",
      "打开外部",
      "Ok 只表示已交给系统。",
      [
        @yue.hbox([
          @yue.button_t("打开 libyue.com", on_click=fn() {
            match @yue.open_url("https://libyue.com") {
              Ok(_) => app.toast_push("已交给系统打开", @yue.Success)
              Err(e) => app.toast_push("失败:\{e}", @yue.Danger)
            }
          }),
          @yue.button_t("在文件管理器中显示 README.md", on_click=fn() {
            match @yue.reveal_in_file_manager("README.md") {
              Ok(_) => app.toast_push("已交给文件管理器", @yue.Success)
              Err(e) => app.toast_push("失败:\{e}", @yue.Danger)
            }
          }),
        ]),
      ],
      code=[
        "match @yue.open_url(\"https://libyue.com\") {", "  Ok(_) => println(\"已交给默认浏览器\")",
        "  Err(e) => println(\"失败:\\{e}\")", "}", "match @yue.reveal_in_file_manager(\"README.md\") {",
        "  Ok(_) => println(\"已交给文件管理器\")", "  Err(e) => println(\"失败:\\{e}\")",
        "}",
      ],
    ),
  )
  // 屏幕常亮与用户空闲:开关直连真实抑制(句柄记下供 release);空闲
  // 秒数定时刷新——点击本身是输入会重置空闲,即读即显恒为 0,改为
  // 开关开启后每秒读一次(开关关闭,定时器下一拍自行停止)
  let idle_out : @yue.Store[String] = @yue.Store::new(
    if @yue.idle_supported() {
      "(打开开关开始每秒刷新;不动输入看数值增长,动一下看归零)"
    } else {
      "当前平台不支持空闲查询"
    },
  )
  let idle_running : @yue.Store[Bool] = @yue.Store::new(false)
  idle_running.subscribe(fn(on) {
    if on {
      @yue.set_timer(1000, fn() {
        if !idle_running.get() {
          return false // 开关已关:停止刷新
        }
        match @yue.idle_seconds() {
          Ok(s) => idle_out.set("当前空闲:\{s} 秒")
          Err(e) => idle_out.set("不可用:\{e}")
        }
        true
      })
      ()
    } else {
      idle_out.set("(已停止刷新)")
    }
  })
  let ka : Ref[@yue.KeepAwake?] = Ref(None)
  let ka_on : @yue.Store[Bool] = @yue.Store::new(@yue.keep_awake_active())
  let ka_out : @yue.Store[String] = @yue.Store::new(
    if @yue.KeepAwake::is_supported() {
      "(未开启)"
    } else {
      "当前环境无抑制服务在线"
    },
  )
  ka_on.subscribe(fn(on) {
    if on {
      match @yue.KeepAwake::enable("org.moonbitlibyue.Showcase") {
        Ok(k) => {
          ka.val = Some(k)
          ka_out.set("已申请常亮:系统屏保 / 自动息屏被抑制")
        }
        Err(e) => {
          ka_on.set(false)
          ka_out.set("申请失败:\{e}")
        }
      }
    } else {
      match ka.val {
        Some(k) =>
          match k.release() {
            Ok(_) => {
              ka.val = None
              ka_out.set("已解除常亮")
            }
            Err(e) => ka_out.set("解除失败:\{e}")
          }
        None => ka_out.set("(未开启)")
      }
    }
  })
  secs.push(
    @ui.section(
      "常亮空闲",
      "屏幕常亮与用户空闲",
      "KeepAwake 抑制系统屏保 / 自动息屏",
      [
        @yue.hbox([
          @yue.switch_t(ka_on),
          @yue.label_t("保持屏幕常亮", role=@yue.Secondary),
        ]),
        @yue.bind_label(ka_out, fn(s) { s }, style=[("marginTop", 8.0)]),
        @yue.hbox(
          [
            @yue.switch_t(idle_running),
            @yue.label_t("每秒刷新空闲秒数", role=@yue.Secondary),
          ],
          style=[("marginTop", 8.0)],
        ),
        @yue.bind_label(idle_out, fn(s) { s }, style=[("marginTop", 8.0)]),
      ],
      code=[
        "match @yue.KeepAwake::enable(\"org.app.Id\") {", "  Ok(k) => ignore(k.release())",
        "  Err(e) => println(e)", "}", "match @yue.idle_seconds() {", "  Ok(s) => println(\"空闲 \\{s} 秒\")",
        "  Err(e) => println(e)", "}",
      ],
    ),
  )
  // 休眠唤醒与锁屏解锁:计数演示(真机休眠一次 / Win+L 锁屏一次即见)
  let suspend_n = Ref(0)
  let resume_n = Ref(0)
  let lock_n = Ref(0)
  let unlock_n = Ref(0)
  let sleep_out : @yue.Store[String] = @yue.Store::new(
    if @yue.suspend_resume_supported() {
      "休眠 0 次 / 唤醒 0 次"
    } else {
      "当前环境无 logind,休眠事件不可用"
    },
  )
  let lock_out : @yue.Store[String] = @yue.Store::new(
    if @yue.session_lock_supported() {
      "锁屏 0 次 / 解锁 0 次"
    } else {
      "当前环境锁屏事件不可用"
    },
  )
  @yue.on_suspend_resume(fn(e) {
    match e {
      @yue.Suspending => suspend_n.val = suspend_n.val + 1
      @yue.Resuming => resume_n.val = resume_n.val + 1
    }
    sleep_out.set("休眠 \{suspend_n.val} 次 / 唤醒 \{resume_n.val} 次")
  })
  match
    @yue.session_lock_watch(fn(e) {
      match e {
        @yue.Locked => lock_n.val = lock_n.val + 1
        @yue.Unlocked => unlock_n.val = unlock_n.val + 1
      }
      lock_out.set("锁屏 \{lock_n.val} 次 / 解锁 \{unlock_n.val} 次")
    }) {
    Ok(_) => ()
    Err(e) => lock_out.set("锁屏订阅失败:\{e}")
  }
  secs.push(
    @ui.section(
      "休眠锁屏",
      "休眠唤醒与锁屏解锁",
      "事件计数演示:真机休眠一次 / Win+L 锁屏一次即见变化。",
      [
        @yue.bind_label(sleep_out, fn(s) { s }, style=[("marginBottom", 4.0)]),
        @yue.bind_label(lock_out, fn(s) { s }),
      ],
      code=[
        "@yue.on_suspend_resume(fn(e) {", "  match e {", "    @yue.Suspending => println(\"休眠\")",
        "    @yue.Resuming => println(\"唤醒\")", "  }", "})", "match @yue.session_lock_watch(fn(e) {",
        "  match e {", "    @yue.Locked => println(\"锁屏\")", "    @yue.Unlocked => println(\"解锁\")",
        "  }", "}) {", "  Ok(_) => ()", "  Err(e) => println(e)", "}",
      ],
    ),
  )
  // 电量与网络:定时轮询刷新(默认 30s,电量缓慢变化也可见)+ 变化事件计数
  // (真机拔插电源 / 断联网即见)
  let power_out : @yue.Store[String] = @yue.Store::new("")
  let refresh_power : () -> Unit = fn() {
    if !@yue.battery_supported() {
      power_out.set("当前环境无 UPower,电量不可用")
      return
    }
    match @yue.battery_query() {
      Ok(Some(b)) => {
        let full = match b.charging_seconds {
          Some(s) => "距充满 \{s} 秒"
          None => "剩余时间未知"
        }
        power_out.set("电量 \{b.percent}%,充电中:\{b.charging}(\{full})")
      }
      Ok(None) =>
        // 台式机常态:无电池但电源来源可查(交流在线)
        power_out.set(
          match @yue.power_source() {
            Ok(src) =>
              if src is @yue.Ac {
                "无电池,电源:交流在线"
              } else {
                "无电池,电源:电池供电(异常:请反馈)"
              }
            Err(_) => "无电池(电源状态未知)"
          },
        )
      Err(e) => power_out.set("查询失败:\{e}")
    }
  }
  refresh_power()
  // 周期轮询:电量百分比/充电态随放充电缓慢变化,仅靠启动查询与电源
  // 切换事件看不到(任务返回 true 持续轮询)
  ignore(
    @yue.set_timer(30000, fn() {
      refresh_power()
      true
    }),
  )
  let net_out : @yue.Store[String] = @yue.Store::new(
    // Windows 查询走后台轮询缓存,启动后首个状态值由变化事件派发刷新
    if @yue.network_supported() {
      "当前网络:(探测中)"
    } else {
      "当前环境无 NetworkManager,网络状态不可用"
    },
  )
  let net_n = Ref(0)
  // 电源切换事件即时刷新电量读数(替代原来只写"电源切换"的文案,
  // 与 30s 轮询走同一查询口径)
  @yue.on_power_source_change(fn(_src) { refresh_power() })
  @yue.on_network_status_change(fn(s) {
    net_n.val = net_n.val + 1
    net_out.set("当前网络:\{s.label()}(第 \{net_n.val} 次变化)")
  })
  secs.push(
    @ui.section(
      "电量网络",
      "电量与网络",
      "电量 30 秒轮询 + 电源切换即时刷新;网络状态变化事件计数(真机拔插电源 / 断联网即见)。",
      [
        @yue.bind_label(power_out, fn(s) { s }, style=[("marginBottom", 4.0)]),
        @yue.bind_label(net_out, fn(s) { s }),
      ],
      code=[
        "match @yue.battery_query() {", "  Ok(Some(b)) => println(\"电量 \\{b.percent}% 充电中:\\{b.charging}\")",
        "  Ok(None) => println(@yue.power_source())", "  Err(e) => println(e)", "}",
        "@yue.on_power_source_change(fn(_src) { println(\"电源切换\") })", "@yue.on_network_status_change(fn(s) {",
        "  println(\"网络:\\{s.label()}\")", "})",
      ],
    ),
  )
  @ui.page(secs)
}
