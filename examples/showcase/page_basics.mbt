// 基础控件页：标签 / 按钮 / 输入 / 滑块进度 / 复选单选。

///|
fn page_basics() -> @yue.Node {
  let clicks : @yue.Store[Int] = @yue.Store::new(0)
  let echo : @yue.Store[String] = @yue.Store::new("")
  let slider_val : @yue.Store[Double] = @yue.Store::new(0.0)
  let pick : @yue.Store[String] = @yue.Store::new("乙")
  let indeterminate = Ref(false)
  let bar : Ref[@yue.ProgressBar?] = Ref(None)
  scroll_page([
    section("标签 / 按钮", "Button 点击计数；文本由 Store 驱动自动更新（L3 响应式 bind_label）。", [
      @yue.button("点我", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
      @yue.bind_label(clicks, fn(n) { "已点 \{n} 次" }, style=[("marginTop", 8.0)]),
    ]),
    section("单行输入 Entry", "on_input 实时回显；回车触发 on_enter；password=true 为密码框。", [
      @yue.entry(
        text="在这里输入…",
        on_input=fn(s) { echo.set(s) },
        on_enter=fn(s) { echo.set("\{s}（回车）") },
      ),
      @yue.bind_label(echo, fn(s) { "回显：\{s}" }, style=[("marginTop", 8.0)]),
      @yue.entry(text="口令", password=true, style=[("marginTop", 8.0)]),
    ]),
    section("滑块联动进度条", "Slider on_change 更新 Store 与进度条（ProgressBar 经 handle 命令式 set_value）；按钮切换不确定态。", [
      @yue.slider(
        range=Some((0.0, 100.0)),
        step=Some(1.0),
        on_change=fn(v) {
          slider_val.set(v)
          when_some(bar, fn(p) { p.set_value(v / 100.0) })
        },
      ),
      @yue.progress(handle=fn(p) { bar.val = Some(p) }, style=[("marginTop", 8.0)]),
      @yue.bind_label(slider_val, fn(v) { "滑块值：\{v.round()}" }, style=[("marginTop", 8.0)]),
      @yue.button(
        "切换不确定态",
        on_click=fn() {
          indeterminate.val = !indeterminate.val
          when_some(bar, fn(p) { p.set_indeterminate(indeterminate.val) })
        },
        style=[("marginTop", 8.0)],
      ),
    ]),
    section("复选框 / 单选组", "checkbox 独立勾选；同组 radio 自动互斥（libyue 行为），切换时被取消的旧项也会收到一次 on_change(false)。", [
      @yue.checkbox("启用扩展", on_change=fn(v) { if v { pick.set("扩展已启用") } }),
      @yue.hbox(
        [
          @yue.radio("甲", on_change=fn(v) { if v { pick.set("甲") } }),
          @yue.radio("乙", checked=true, on_change=fn(v) { if v { pick.set("乙") } }),
          @yue.radio("丙", on_change=fn(v) { if v { pick.set("丙") } }),
        ],
        style=[("marginTop", 8.0)],
      ),
      @yue.bind_label(pick, fn(s) { "当前：\{s}" }, style=[("marginTop", 8.0)]),
    ]),
  ])
}
