// Windows「点击劫持」二分探针:定位深浅切换后全窗点击失效的根因要素。
//
// 操作步骤(★每测一行前必须关掉探针重开★——失效一旦发生不可逆,
//   不重启会让后续所有行的数据都被污染):
//   1. 开探针,点行 1(对照)若干次——数字应正常自增;
//   2. 重开探针,点行 2 → 回点行 1,还自增吗?
//   3. 重开探针,点行 2b → 回点行 1?
//   4. 重开探针,点行 3 → 回点行 1?
//   5. 重开探针,点行 4 → 回点行 1?
// 行 2 现已与行 2b 同语义(库内修复:Windows 上 bind_node 重挂推迟一拍),
// 两者都应不再失效;若仍失效把现象与行号发回。

fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let n : @yue.Signal[Int] = @yue.Signal::new(0)
  let n2 : @yue.Signal[Int] = @yue.Signal::new(0)
  let dark : @yue.Store[Bool] = @yue.Store::new(false)

  let probe : @yue.Store[String] = @yue.Store::new("(未操作)")

  fn say(s : String) -> Unit {
    probe.set(s)
  }

  ignore(
    @yue.mount_window(
    [
      @yue.label_t("点击劫持二分探针", role=@yue.Title),
      @yue.label_t("每点一行后,回到「行1 对照」多点几下,看数字是否还在自增", role=@yue.Secondary),
      @yue.bind_label(probe, fn(s) { "状态: \{s}" }),
      @yue.separator(),
      // 行 1 对照:普通自绘按钮,无重挂无主题
      @yue.button_t(
        "行1 对照:自增 \{n.get()}",
        on_click=fn() {
          n.update(fn(v) { v + 1 })
          say("行1 正常自增")
        },
        variant=@yue.Solid,
      ),
      // 行 2:bind_node 运行期重挂(点击回调内 remove+add),不切主题
      @yue.bind_node(n, fn(v) {
        @yue.button_t(
          "行2 bind_node 重挂 \{v}(点我,再试行1)",
          on_click=fn() {
            n.update(fn(x) { x + 1 })
            say("行2 重挂已触发")
          },
        )
      }),
      // 行 2b:bind_node 重挂但信号更新推迟一拍(重挂脱离点击回调栈)
      @yue.bind_node(n2, fn(v) {
        @yue.button_t(
          "行2b 延迟重挂 \{v}(点我,再试行1)",
          on_click=fn() {
            @yue.post_task(fn() { n2.update(fn(x) { x + 1 }) })
            say("行2b 延迟重挂已排队")
          },
        )
      }),
      // 行 3:切主题(不用 bind_node),普通按钮
      @yue.button_t(
        "行3 切主题(点我,再试行1)",
        on_click=fn() {
          dark.update(fn(v) { !v })
          @yue.theme_apply(if dark.get() { @yue.dark_theme() } else { @yue.default_theme() })
          say("行3 主题已切换")
        },
        variant=@yue.Danger,
      ),
      // 行 4:icon_button_t + tip + bind_node 重挂 + 切主题(showcase 同款)
      @yue.hbox(
        [
          @yue.label_t("行4:"),
          @yue.bind_node(dark.signal(), fn(d) {
            @yue.icon_button_t(
              if d { @yue.YhSunny } else { @yue.YhMoon },
              on_click=fn() {
                dark.update(fn(v) { !v })
                @yue.theme_apply(if !d { @yue.dark_theme() } else { @yue.default_theme() })
                say("行4 图标按钮已触发")
              },
              tip="showcase 同款",
            )
          }),
        ],
        style=[("alignItems", "center")],
      ),
    ],
      title="点击劫持二分探针",
      size=Some((560.0, 420.0)),
      center=true,
    ),
  )
  @yue.run()
}
