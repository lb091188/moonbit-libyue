// Store 对照页:手动响应式模式演示。与主题五页的 Signal 自动依赖收集
// 对照——派生关系要手动接线(动作里 set / subscribe 回调里 set),
// 忘接线界面就静默不刷新;信号版见「基础组件」等页。

///|
fn page_store_demo(_app : App) -> @yue.Node {
  let counter : @yue.Store[Int] = @yue.Store::new(0)
  // 手动派生一:动作回调里顺手 set(改 A 必须记得改 B)
  let doubled : @yue.Store[Int] = @yue.Store::new(0)
  counter.subscribe(fn(n) { doubled.set(n * 2) })
  // 手动派生二:Store::map(源 set 时自动跟随,一对一映射)
  let text = counter.map(fn(n) { "当前计数 \{n}" })
  // 手动派生三:跨 Store 手动同步
  let merged : @yue.Store[String] = @yue.Store::new("")
  counter.subscribe(fn(n) { merged.set("计数 \{n},双倍 \{n * 2}") })
  scroll_page([
    section(
      "手动计数器",
      "Store::update 改源,bind_label 回显——「改值」与「刷新界面」已自动,但派生值全要手动接。",
      [
        @yue.hbox(
          [
            @yue.button_t("计数 +1", variant=@yue.Solid, on_click=fn() {
              counter.update(fn(n) { n + 1 })
              // ↑ 动作本体;若 doubled 不靠 subscribe,这里就得再写
              //   doubled.set(counter.get() * 2)——信号版无此负担
            }),
            @yue.bind_label(counter, fn(n) { "计数:\{n}" }, style=[
              ("marginLeft", 10.0),
            ]),
          ],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "手动派生:subscribe 回调里 set",
      "counter.subscribe(fn(n) { doubled.set(n * 2) })——派生关系散落在动作代码各处,链一长就是胶水瀑布。",
      [
        @yue.bind_label(doubled, fn(n) { "双倍(手动接线):\{n}" }),
      ],
    ),
    section(
      "手动派生:Store::map",
      "一对一映射有现成糖(map 派生只读 Store),但两个以上源合成仍要 subscribe 手动同步。",
      [
        @yue.bind_label(text, fn(s) { s }),
        @yue.bind_label(merged, fn(s) { s }, style=[("marginTop", 6.0)]),
      ],
    ),
    section(
      "与信号版对照",
      "信号写法:computed(fn() { counter.get() * 2 })——关系声明在定义处,多源合成/条件派生同一写法。",
      [
        @yue.descriptions([
          ("手动(本页)", "动作里 set / subscribe 里 set / map 一对一"),
          ("信号(主题页)", "computed 声明派生,batch 合并同回调多次 set"),
          ("取舍", "两者共享同一内核,Store::signal / Signal::store 互转"),
        ]),
      ],
    ),
  ])
}
