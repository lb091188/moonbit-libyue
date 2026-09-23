// L2 组件:hover 组——组内任意位置(含全部子控件)悬停即整组进入
// hover 态,子控件触发的事件同样改变组的样式。
//
// 机制:指针位置轮询(位置即真理),不依赖 enter/leave 的可达性——
// GTK 的指针事件不冒泡,发给最深命中的 GdkWindow 就终结,子容器/
// 原生控件(NUContainer、Entry 等)的事件窗口会独占指针事件,祖先
// 容器收不到 enter(sysmonitor 卡片能收 enter 是因为子件是无窗口的
// label;子件一旦是容器/原生控件就断流)。Windows 下同一机制工作
// (跨平台一致,不依赖平台 hover 语义)。
//
// 开销:全部组共享一个全局定时器(100ms 一拍,无组时完全停止),
// 每 tick 一次指针查询 + 每组一次屏幕矩形比对,均为微秒级 FFI;
// 组静止(态不翻转)时不触发任何回调与重绘。enter 事件仅作组自身
// 空白区命中时的即时加速。
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
/// 全局 hover 中心的注册项。
priv struct HoverEntry {
  host : Container
  apply : (Bool) -> Unit
}

///|
let g_hover_entries : Array[HoverEntry] = []

///|
/// 全局定时器句柄(set_timeout 链;无组时归零停转)。
let g_hover_timer : Ref[Int] = Ref(0)

///|
fn hover_tick() -> Unit {
  if g_hover_entries.is_empty() {
    g_hover_timer.val = 0
    return
  }
  // 每 tick 一次指针查询,各组只做矩形比对
  let px = cursor_screen_x()
  let py = cursor_screen_y()
  for e in g_hover_entries {
    (e.apply)(
      rect_contains(ViewLike::get_bounds_in_screen(e.host), px, py),
    )
  }
  g_hover_timer.val = set_timeout(100, fn() { hover_tick() })
}

///|
fn hover_register(entry : HoverEntry) -> Unit {
  g_hover_entries.push(entry)
  if g_hover_timer.val == 0 {
    hover_tick()
  }
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
      hover_register({ host, apply: set })
      // enter 仅加速:host 自身空白区命中时立即置真(下一拍全局确认)
      ViewLike::on_mouse_enter(host, fn(_e) {
        set(true)
      })
      ViewLike::view(host)
    },
  }
}
