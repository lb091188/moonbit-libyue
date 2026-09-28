// Store 对照页:手动响应式模式演示。与主题五页的 Signal 自动依赖收集
// 对照——派生关系要手动接线(动作里 set / subscribe 回调里 set),
// 忘接线界面就静默不刷新;信号版见「基础组件」等页。

///|
pub fn page_store_demo(_app : @ui.App) -> @yue.Node {
  let counter : @yue.Store[Int] = @yue.Store::new(0)
  // 手动派生一:动作回调里顺手 set(改 A 必须记得改 B)
  let doubled : @yue.Store[Int] = @yue.Store::new(0)
  counter.subscribe(fn(n) { doubled.set(n * 2) })
  // 手动派生二:Store::map(源 set 时自动跟随,一对一映射)
  let text = counter.map(fn(n) { "当前计数 \{n}" })
  // 手动派生三:跨 Store 手动同步
  let merged : @yue.Store[String] = @yue.Store::new("")
  counter.subscribe(fn(n) { merged.set("计数 \{n},双倍 \{n * 2}") })
  @ui.page([
    @ui.section(
      "计数器",
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
      code=[
        "// Store::update 改源,bind_label 回显",
        "// Store::new(初始值):建可订阅源;之后每次 set 都通知订阅者",
        "// (不去重,相同值也通知)",
        "let counter = @yue.Store::new(0)",
        "// button_t(text, ...):主题化按钮;on_click 点击回调(默认无操作),",
        "// variant 默认 Soft(浅底主题色字),Solid=主题色实底白字",
        "@yue.button_t(\"计数 +1\", variant=@yue.Solid, on_click=fn() {",
        "  // update(f) 即 set(f(get())):改值并自动通知订阅者,n 为旧值",
        "  counter.update(fn(n) { n + 1 })",
        "})",
        "// bind_label(store, f):挂载时建 Label 显示 f(初值),此后每次 set",
        "// 自动刷新文本;style/style_str 可选布局样式,默认空",
        "@yue.bind_label(counter, fn(n) { \"计数:\\{n}\" })",
      ],
    ),
    @ui.section(
      "手动接线",
      "手动派生:subscribe 回调里 set",
      "counter.subscribe(fn(n) { doubled.set(n * 2) })——派生关系散落在动作代码各处,链一长就是胶水瀑布。",
      [@yue.bind_label(doubled, fn(n) { "双倍(手动接线):\{n}" })],
      code=[
        "// 派生关系散落在 subscribe 回调各处,链一长就是胶水瀑布",
        "// Store::new(初始值):建可订阅源;这里 counter 作手动接线中的源",
        "let counter = @yue.Store::new(0)",
        "// 同一 API 再建 doubled,作手动派生的写入目标",
        "let doubled = @yue.Store::new(0)",
        "// subscribe(f):源每次 set 后以最新值调 f;注册时不回调(初值自己",
        "// get),暂无退订,订阅存活整个应用期——派生要自己在回调里 set",
        "counter.subscribe(fn(n) { doubled.set(n * 2) })",
        "// bind_label:挂载显示 f(初值),doubled 每次 set 自动刷新文本",
        "@yue.bind_label(doubled, fn(n) { \"双倍:\\{n}\" })",
      ],
    ),
    @ui.section(
      "map派生",
      "手动派生:Store::map",
      "一对一映射有现成糖(map 派生只读 Store),但两个以上源合成仍要 subscribe 手动同步。",
      [
        @yue.bind_label(text, fn(s) { s }),
        @yue.bind_label(merged, fn(s) { s }, style=[("marginTop", 6.0)]),
      ],
      code=[
        "// Store::map(f):一对一映射的现成糖,源 set 时自动跟随,返回派生",
        "// 只读 Store,适合「状态 → 显示文本」这类映射",
        "let text = counter.map(fn(n) { \"当前计数 \\{n}\" })",
        "// bind_label:text 已是字符串,恒等函数 fn(s) { s } 直接回显",
        "@yue.bind_label(text, fn(s) { s })",
        "// 两个以上源合成仍要 subscribe 手动同步",
        "// Store::new(\"\"):再建一个源,作跨源手动合成的写入目标",
        "let merged = @yue.Store::new(\"\")",
        "// subscribe(f):f 收到源的最新值,回调里手动写 merged 完成同步",
        "counter.subscribe(fn(n) { merged.set(\"计数 \\{n}\") })",
      ],
    ),
    @ui.section(
      "信号对照",
      "与信号版对照",
      "信号写法:computed(fn() { counter.get() * 2 })——关系声明在定义处,多源合成/条件派生同一写法。",
      [
        @yue.descriptions([
          (
            "手动(本页)", "动作里 set / subscribe 里 set / map 一对一",
          ),
          (
            "信号(主题页)", "computed 声明派生,batch 合并同回调多次 set",
          ),
          (
            "取舍", "两者共享同一内核,Store::signal / Signal::store 互转",
          ),
        ]),
      ],
      code=[
        "// 信号版:关系声明在定义处,多源合成/条件派生同一写法",
        "// Signal::new(初始值):建源信号,get() 读、set() 写",
        "let a = @yue.Signal::new(2)",
        "// 同一 API 再建 b,供 computed 闭包多源合成",
        "let b = @yue.Signal::new(3)",
        "// computed(f):闭包里 get 到的信号自动登记为依赖,任一变化即失效、",
        "// 下次 get() 重算——多源合成免手动接线",
        "let sum = @yue.Signal::computed(fn() { a.get() + b.get() })",
        "// Signal::map(f):派生只读信号,等价 computed 闭包里只读一个源",
        "let doubled = a.map(fn(n) { n * 2 })",
        "// 互转:Store::signal() / Signal::store()",
        "// bind(信号, f):信号版文本绑定,与 bind_label 同一实现内核,",
        "// 挂载显示 f(初值),信号变化自动刷新;style/style_str 默认空",
        "@yue.bind(sum, fn(v) { \"和:\\{v}\" })",
      ],
    ),
  ])
}
