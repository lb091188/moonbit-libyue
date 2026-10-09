// Windows「点击劫持」诊断探针 v3:自动记录事件到状态栏,真机跑一轮
// 把状态栏文本抄回来即可定位失效层级。
//
// 操作(★每测一行前关掉重开;关不掉按 Esc 退出★):
//   1. 开探针,点行1 若干次;
//   2. 重开,点行2,再点行1 一次,再点窗口空白处一次;
//   3. 重开,点行3,再点行1 一次,再点空白处一次;
//   4. 重开,点行5-A(变隐藏、B 出现),再点 B,再点行1——验证显隐切换
//      (不 remove/add)是否安全,这是 showcase 明暗按钮的规避方案;
// 每次点击后看「事件流」最后几行:
//   - 出现 [根 (x,y)] = 窗口层活着,只是子控件路由断;
//   - 什么都没有 = 整个窗口鼠标消息死了;
//   - 点行1 却出现 [行2] = 点击被劫持给了行2 的回调。

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let n : @yue.Signal[Int] = @yue.Signal::new(0)
  let dark : @yue.Store[Bool] = @yue.Store::new(false)
  // 事件流:最近 4 条,新事件顶在最前
  let log : @yue.Store[String] = @yue.Store::new("(等待点击)")

  fn say(tag : String, detail : String) -> Unit {
    log.update(fn(old) {
      let parts : Array[String] = []
      parts.push("[\{tag} \{detail}]")
      let mut cnt = 0
      for line in old.split("|") {
        let line = line.to_owned()
        if line != "(等待点击)" && cnt < 3 {
          parts.push(line)
          cnt = cnt + 1
        }
      }
      parts.join("|")
    })
  }

  let toggle : @yue.Store[Bool] = @yue.Store::new(true)
  let body : Array[@yue.Node] = [
    @components.label_t("点击劫持诊断探针 v3(Esc 退出)", role=@components.Title),
    @components.label_t(
      "每测一行前重开探针;点击后看下方事件流",
      role=@components.Secondary,
    ),
    @components.button_t(
      "行1 对照 \{n.get()}",
      on_click=fn() {
        n.update(fn(v) { v + 1 })
        say("行1", "自增")
      },
      variant=@components.Solid,
    ),
    @yue.bind_node(n, fn(v) {
      @components.button_t("行2 bind_node 重挂 \{v}", on_click=fn() {
        n.update(fn(x) { x + 1 })
        say("行2", "重挂触发")
      })
    }),
    @components.button_t(
      "行3 切主题",
      on_click=fn() {
        dark.update(fn(v) { !v })
        @yue.theme_apply(
          if dark.get() {
            @yue.dark_theme()
          } else {
            @yue.default_theme()
          },
        )
        say("行3", "主题切换")
      },
      variant=@components.Danger,
    ),
    @yue.hbox(
      [
        @components.label_t("行4:"),
        @yue.bind_node(dark.signal(), fn(d) {
          @icons.icon_button_t(
            if d {
              @icons.Sunny
            } else {
              @icons.Moon
            },
            on_click=fn() {
              dark.update(fn(v) { !v })
              @yue.theme_apply(
                if !d {
                  @yue.dark_theme()
                } else {
                  @yue.default_theme()
                },
              )
              say("行4", "图标按钮触发")
            },
            tip="showcase 同款",
          )
        }),
      ],
      style=[("alignItems", "center")],
    ),
    // 行5:规避方案验证——双预建按钮显隐切换(不 remove/add)
    @yue.hbox(
      [
        @components.label_t("行5 显隐切换:"),
        @components.button_t(
          "行5-A(显示时)",
          on_click=fn() {
            toggle.update(fn(v) { !v })
            say("行5A", "显隐触发")
          },
          handle=fn(c) { toggle.subscribe(fn(v) { c.set_visible(v) }) },
        ),
        @components.button_t(
          "行5-B(隐藏时)",
          on_click=fn() {
            toggle.update(fn(v) { !v })
            say("行5B", "显隐触发")
          },
          handle=fn(c) {
            toggle.subscribe(fn(v) { c.set_visible(!v) })
            c.set_visible(false)
          },
        ),
      ],
      style=[("alignItems", "center")],
      handle=fn(row) {
        // 用 toggle 信号演示:点 A 隐 A 显 B,点 B 隐 B 显 A
        ignore(row)
      },
    ),
    @yue.separator(),
    @components.label_t("事件流(新在前):", role=@components.Secondary),
    @yue.bind_label(log, fn(s) { s }),
  ]
  ignore(
    @yue.mount_window(
      [
        // 根容器:记录窗口层收到的每次点击坐标(判断整窗是否还活着)
        @yue.vbox(body, style=[("padding", 16.0), ("flexgrow", 1.0)], handle=fn(
          root,
        ) {
          root.on_mouse_down(fn(e) {
            say("根", "(\{e.view_x}, \{e.view_y})")
            false
          })
        }),
      ],
      title="点击劫持诊断 v3",
      size=Some((600.0, 560.0)),
      center=true,
      handle=fn(w) {
        // Esc 退出:鼠标死后键盘焦点仍可用,保底关闭通道
        w.on_key_down(fn(e) {
          if e.code == @yue.VKEY_ESCAPE {
            @yue.quit()
            true
          } else {
            false
          }
        })
      },
    ),
  )
  @yue.run()
}
