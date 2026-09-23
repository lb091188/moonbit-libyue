// L2 组件:hover 组——组内任意位置(含全部子控件)悬停即整组进入
// hover 态,子控件触发的事件同样改变组的样式。
//
// 机制:指针位置轮询(位置即真理),不依赖 enter/leave 的可达性——
// GTK 的事件按最深命中的 GdkWindow 发,子容器/子控件(NUContainer、
// 原生 Entry 等)的事件窗口会独占指针事件,祖先容器收不到 enter
// (sysmonitor 卡片能收 enter 是因为子件是无窗口的 label;一旦子件
// 是容器/原生控件就断流)。轮询 100ms 一拍,读全局指针坐标与组屏幕
// 矩形比对(cursor_screen_x/y 与 get_bounds_in_screen 同坐标系,多屏
// 拼接含负值一致);enter 事件仅作空白区命中时的即时加速,离场判定
// 完全由轮询承担。Windows 下同一机制照常工作(跨平台一致,不依赖
// 平台 hover 语义)。
//
// 背景高亮内置为 on_draw 自绘:GTK 下容器的可见背景必须自绘
// (set_background_color 与 backgroundColor 样式对无 draw 的容器不
// 可靠,主题 CSS 与子控件窗口都会压掉),悬停/常态底色在组件内直
// 接绘制,透明子区域自然透出。

///|
/// 点是否在矩形内(含边界)。
pub fn rect_contains(
  b : RectF,
  px : Double,
  py : Double,
) -> Bool {
  px >= b.x && px <= b.x + b.width && py >= b.y && py <= b.y + b.height
}

///|
/// hover 组容器:child 为组内容(声明式节点)。
/// - hover_bg / base_bg:悬停 / 常态底色(默认取主题 fill_hover /
///   透明不画);圆角 radius 可选。
/// - on_change:组 hover 态翻转时回调(仅变化时),携带组容器——
///   光标、边框等额外反馈在回调里对它应用;底色已内置无需处理。
pub fn hover_group(
  child : Node,
  hover_bg? : String = "",
  base_bg? : String = "",
  radius? : Double = 0.0,
  on_change? : (Bool, Container) -> Unit = fn(_b, _c) {  },
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let host = themed_container(style~, style_str~)
      attach(parent, ViewLike::view(host))
      ignore((child.mount)(ViewLike::view(host)))
      let hover = Ref(false)
      fn set(h : Bool) -> Unit {
        if h != hover.val {
          hover.val = h
          ViewLike::schedule_paint(host)
          on_change(h, host)
        }
      }
      host.on_draw(fn(p) {
        let bg = if hover.val {
          if hover_bg != "" { hover_bg } else { theme_fill_hover() }
        } else {
          base_bg
        }
        if bg != "" {
          let b = ViewLike::get_bounds(host)
          p.set_fill_color(bg)
          if radius > 0.0 {
            fill_round_rect(p, 0.0, 0.0, b.width, b.height, radius)
          } else {
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
        }
      })
      fn pointer_in_group() -> Bool {
        rect_contains(
          ViewLike::get_bounds_in_screen(host),
          cursor_screen_x(),
          cursor_screen_y(),
        )
      }
      // 常驻低频轮询:两次轻量 FFI 查询(指针坐标 + 屏幕矩形),
      // 微秒级;每拍仅翻转时回调,静止无额外开销
      set_timer(100, fn() {
        set(pointer_in_group())
        true
      })
      // enter 仅加速:host 自身空白区命中时立即置真(下一拍轮询确认)
      ViewLike::on_mouse_enter(host, fn(_e) {
        set(true)
      })
      ViewLike::view(host)
    },
  }
}
