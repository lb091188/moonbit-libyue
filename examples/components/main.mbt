// 探索:自定义组件封装 + mount 原生布局现代化。
// 组件封装路径(探索结论,全部零平台代码):
//   1. 组合式组件 —— 普通函数返回 Node(推荐,零新概念):card/nav_item;
//   2. 自绘组件   —— container(on_draw=...) + Painter,零图片资源:badge;
//   3. 有状态组件 —— 组件私有 Store + bind_label,状态随实例走:counter;
//      跨组件协调 —— 共享 Store + map 派生(侧边栏高亮)。
// 布局:全部用原生 vbox/hbox/scroll 弹性盒排出的
// 「深色侧边栏 + 顶栏 + 滚动卡片内容」应用外壳。
// 注:vbox/hbox 现支持 handle(本次探索补齐),布局容器可直接设背景色。

///|
/// 组合式组件:卡片 = 强调条 + 标题 + 内容列。
fn card(
  title : String,
  accent : String,
  children : Array[@yue.Node],
) -> @yue.Node {
  @yue.vbox(
    [
      @yue.hbox(
        [
          @yue.container(style=[("width", 4.0), ("height", 18.0)], handle=fn(
            c,
          ) {
            c.set_background_color(accent)
          }),
          @yue.label(title, style=[("marginLeft", 8.0)]),
        ],
        style_str=[("alignItems", "center")],
      ),
      @yue.vbox(children, style=[("marginTop", 10.0), ("marginLeft", 12.0)]),
    ],
    style=[("padding", 14.0), ("marginBottom", 12.0)],
    handle=fn(c) { c.set_background_color("#FFFFFF") },
  )
}

///|
/// 自绘组件:圆形徽标(纯 Painter,无任何图片资源)。
fn badge(letter : String, color : String) -> @yue.Node {
  @yue.container(
    on_draw=fn(p) {
      p.set_fill_color(color)
      p.begin_path()
      p.arc(20.0, 20.0, 18.0, 0.0, 6.2832)
      p.fill()
      p.set_fill_color("#FFFFFF")
      p.draw_text(letter, 0.0, 0.0, 40.0, 40.0, align=Center, valign=Center)
    },
    style=[("width", 40.0), ("height", 40.0)],
  )
}

///|
/// 有状态组件:计数器。状态(Store)封装在组件内部,
/// 每个实例独立计数——组件即「函数 + 闭包状态」。
fn counter_widget(start : Int) -> @yue.Node {
  let count : @yue.Store[Int] = @yue.Store::new(start)
  @yue.hbox(
    [
      @yue.button("-", on_click=fn() { count.update(fn(n) { n - 1 }) }),
      @yue.bind_label(count, fn(n) { " \{n} " }, style=[
        ("marginLeft", 12.0),
        ("marginRight", 12.0),
      ]),
      @yue.button("+", on_click=fn() { count.update(fn(n) { n + 1 }) }),
    ],
    style=[("marginTop", 8.0)],
    style_str=[("alignItems", "center")],
  )
}

///|
/// 组合式组件:侧边栏导航项。高亮演示跨组件状态协调——
/// 所有导航项订阅同一个「选中项」Store,经 map 派生各自的是否激活。
fn nav_item(text : String, selected : @yue.Store[String]) -> @yue.Node {
  let is_active : @yue.Store[Bool] = selected.map(fn(s) { s == text })
  @yue.bind_label(
    is_active,
    fn(active) { if active { "▸ \{text}" } else { "  \{text}" } },
    style=[("padding", 6.0)],
  )
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  // 跨组件共享状态:当前选中的导航项。
  let selected : @yue.Store[String] = @yue.Store::new("总览")
  // 有状态组件实例:两个计数器各自独立计数。
  let counter_a = counter_widget(0)
  let counter_b = counter_widget(100)
  let window = @yue.mount_window(
    [
      // 应用外壳:侧边栏 + 主区(flexDirection=row)
      @yue.hbox(
        style=[("flex", 1.0)],
        style_str=[("alignItems", "stretch")],
        [
        // 侧边栏:深色底 + 导航项
        @yue.vbox(
          [
            @yue.label("  MoonShell", style=[("marginBottom", 12.0)]),
            nav_item("总览", selected),
            nav_item("组件", selected),
            nav_item("设置", selected),
          ],
          style=[("width", 140.0), ("padding", 10.0)],
          handle=fn(c) { c.set_background_color("#2B2F3A") },
        ),
        // 主区:顶栏 + 可滚动内容
        @yue.vbox(
          [
            @yue.hbox(
              [
                @yue.bind_label(selected, fn(s) { "\{s}" }),
                @yue.label("                          "),
                badge("M", "#4C8BF5"),
              ],
              style=[("padding", 10.0)],
              style_str=[("alignItems", "center")],
              handle=fn(c) { c.set_background_color("#F2F3F5") },
            ),
            @yue.scroll(
              @yue.vbox(
                [
                  card("组合式组件", "#4C8BF5", [
                    @yue.label(
                      "普通函数返回 Node 即组件,可接收任意参数。",
                    ),
                    counter_a,
                  ]),
                  @yue.hbox([
                    card("自绘徽标", "#34A853", [
                      @yue.hbox(
                        [
                          badge("A", "#4C8BF5"),
                          @yue.label(" "),
                          badge("B", "#EA4335"),
                        ],
                        style_str=[("alignItems", "center")],
                      ),
                    ]),
                    card("独立状态", "#FBBC05", [counter_b]),
                  ]),
                ],
                style=[("padding", 14.0)],
              ),
              style=[("flex", 1.0)],
            ),
          ],
          style=[("flex", 1.0)],
        ),
      ]),
    ],
    title="自定义组件与现代化布局",
    size=Some((760.0, 520.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  window.activate()
  @yue.run()
}
