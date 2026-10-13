// Store 对照页：手动响应式模式演示。与主题五页的 Signal 自动依赖收集
// 对照——派生关系要手动接线（动作里 set / subscribe 回调里 set），
// 忘接线界面就静默不刷新；信号版见「基础组件」等页。
pub fn page_store_demo(_app : @shared.App) -> @core.Node {
  let counter : @core.Store[Int] = @core.Store::new(0)
  // 手动派生一：动作回调里顺手 set（改 A 必须记得改 B）
  let doubled : @core.Store[Int] = @core.Store::new(0)
  counter.subscribe(fn(n) { doubled.set(n * 2) })
  // 手动派生二：Store::map（源 set 时自动跟随，一对一映射）
  let text = counter.map(fn(n) { "当前计数 \{n}" })
  // 手动派生三：跨 Store 手动同步
  let merged : @core.Store[String] = @core.Store::new("")
  counter.subscribe(fn(n) { merged.set("计数 \{n},双倍 \{n * 2}") })
  @shared.page([
    @shared.section(
      "计数器",
      "手动计数器",
      "Store::update 改源，bind_label 回显——「改值」与「刷新界面」已自动，但派生值全要手动接。",
      [
        @ui.row(
          [
            @ui.button("计数 +1", variant=@ui.Solid, on_click=fn() {
              counter.update(fn(n) { n + 1 })
              // ↑ 动作本体；若 doubled 不靠 subscribe，这里就得再写
              //   doubled.set(counter.get() * 2)——信号版无此负担
            }),
            @ui.bind_label(counter, fn(n) { "计数：\{n}" }),
          ],
          column_gap=12.0,
        ),
      ],
      code=[
        "let counter = @core.Store::new(0)",
        "@ui.button(\"计数 +1\", variant=@ui.Solid, on_click=fn() {",
        "  counter.update(fn(n) { n + 1 })",
        "})",
        "@ui.bind_label(counter, fn(n) { \"计数：\\{n}\" })",
      ],
    ),
    @shared.section(
      "手动接线",
      "手动派生：subscribe",
      "counter.subscribe(fn(n) { doubled.set(n * 2) })——派生关系散落在动作代码各处，链一长就是胶水瀑布。",
      [@ui.bind_label(doubled, fn(n) { "双倍（手动接线）：\{n}" })],
      code=[
        "let counter = @core.Store::new(0)",
        "let doubled = @core.Store::new(0)",
        "counter.subscribe(fn(n) { doubled.set(n * 2) })",
        "@ui.bind_label(doubled, fn(n) { \"双倍：\\{n}\" })",
      ],
    ),
    @shared.section(
      "map派生",
      "手动派生：Store::map",
      "一对一映射有现成糖（map 派生只读 Store），但两个以上源合成仍要 subscribe 手动同步。",
      [
        @ui.col(
          [
            @ui.bind_label(text, fn(s) { s }),
            @ui.bind_label(merged, fn(s) { s }),
          ],
          row_gap=6.0,
        ),
      ],
      code=[
        "let text = counter.map(fn(n) { \"当前计数 \\{n}\" })",
        "@ui.bind_label(text, fn(s) { s })",
        "let merged = @core.Store::new(\"\")",
        "counter.subscribe(fn(n) { merged.set(\"计数 \\{n}\") })",
      ],
    ),
    @shared.section(
      "信号对照",
      "与信号版对照",
      "信号写法：computed(fn() { counter.get() * 2 })——关系声明在定义处，多源合成/条件派生同一写法。",
      [
        @ui.descriptions([
          ("手动（本页）", "动作里 set / subscribe 里 set / map 一对一"),
          ("信号（主题页）", "computed 声明派生，batch 合并同回调多次 set"),
          ("取舍", "两者共享同一内核，Store::signal / Signal::store 互转"),
        ]),
      ],
      code=[
        "let a = @core.Signal::new(2)",
        "let b = @core.Signal::new(3)",
        "let sum = @core.Signal::computed(fn() { a.get() + b.get() })",
        "let doubled = a.map(fn(n) { n * 2 })",
        "@ui.bind(sum, fn(v) { \"和：\\{v}\" })",
      ],
    ),
  ])
}
