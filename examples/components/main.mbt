// 探索:用组件库(yue/components.mbt 的 side_menu/segmented/tag/code_view)
// 拼装 deepin / 360 / 火绒风格的现代桌面应用外壳:
//   浅色侧边导航 + 顶栏分段导航 + 主区页面联动(Store + set_visible)。
// 本文件里的 badge/card/counter_widget 是「自定义组件」三种封装路径的演示。

///|
/// 自绘组件:圆形徽标(纯 Painter,零图片资源)。
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
/// 有状态组件:计数器。私有 Store,每个实例独立计数。
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
/// 主区页面:挂载后订阅 selected 做 set_visible 联动。
fn page(
  name : String,
  selected : @yue.Store[String],
  children : Array[@yue.Node],
) -> @yue.Node {
  @yue.vbox(children, style=[("flex", 1.0), ("padding", 14.0)], handle=fn(c) {
    fn apply(s : String) -> Unit {
      c.set_visible(s == name)
    }

    apply(selected.get())
    selected.subscribe(apply)
  })
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  // 全局导航状态:侧边菜单与顶栏分段导航共享,谁点都联动。
  let selected : @yue.Store[String] = @yue.Store::new("总览")
  let counter_a = counter_widget(0)
  let window = @yue.mount_window(
    [
      @yue.hbox(style=[("flex", 1.0)], style_str=[("alignItems", "stretch")], [
        // 侧边导航(deepin / 火绒桌面软件风格)
        @yue.side_menu(["总览", "组件", "代码"], selected),
        // 主区:顶栏 + 页面
        @yue.vbox(
          [
            // 顶栏:分段导航 + 彩色标签
            @yue.hbox(
              [
                @yue.segmented(["总览", "组件", "代码"], selected),
                @yue.tag("MoonShell", "#409EFF"),
                @yue.tag("v0.1", "#67C23A"),
              ],
              style=[("padding", 10.0)],
              style_str=[("alignItems", "center")],
              handle=fn(c) { c.set_background_color("#FFFFFF") },
            ),
            // 页面:总览
            page("总览", selected, [
              card("组合式组件", "#4C8BF5", [
                @yue.label(
                  "普通函数返回 Node 即组件,可接收任意参数。",
                ),
                counter_a,
              ]),
            ]),
            // 页面:组件
            page("组件", selected, [
              card("自绘徽标与标签", "#34A853", [
                @yue.hbox(
                  [
                    badge("A", "#4C8BF5"),
                    @yue.label(" "),
                    badge("B", "#EA4335"),
                    @yue.label("   "),
                    @yue.tag("纯 MoonBit", "#E6A23C"),
                  ],
                  style_str=[("alignItems", "center")],
                ),
              ]),
            ]),
            // 页面:代码(逐 token 自绘高亮,全平台一致)
            page("代码", selected, [
              @yue.code_view([
                "// 代码高亮:逐 token 自绘,Windows 也能逐字着色", "fn add(a : Double, b : Double) -> Double {",
                "  // 关键字 字符串 数字", "  let tag = \"结果: \"", "  return a + b * 2",
                "}",
              ]),
            ]),
          ],
          style=[("flex", 1.0)],
          handle=fn(c) { c.set_background_color("#F2F3F5") },
        ),
      ]),
    ],
    title="自定义组件与现代化布局",
    size=Some((820.0, 560.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  window.activate()
  @yue.run()
}
