// 浮层的原生档（批 E 余项）：所在窗里有已挂载的原生子件（网页区）时，浮层必须
// 换成**真窗口**——自绘像素永远画在原生子件之下，图层再高也盖不住网页（§4.5）。
//
// 三条机制：
// ① **档位判定**只看一件事：本窗有没有挂着的子件（`Window::has_child_surfaces()`）。
//    没有网页就不必多开一扇窗，继续走 `overlay.mbt` 的图层；
// ② **先开框、量完再收**：弹层大小要的是内容的实际尺寸，而尺寸要挂载并布局一次
//    才知道，所以开一个临时框、挂内容、首帧后按实测矩形 `set_size_pixels` 收到
//    贴合大小（最多三次，避免布局回环）；
// ③ **点外收起靠失焦**：点在网页区时按钮事件被 webview 子窗吃掉，只有焦点转移
//    会告诉我们「用户点了别处」，所以弹层窗收到 `LostFocus` 就收起自己。

///|
/// 已开的原生档浮层：句柄 → 弹层宿主窗。表在进程级，不进 `OverlayHost`
/// （宿主归 App，宿主再持 App 就是引用环）。
let g_native : Ref[Map[Int, App]] = Ref(Map([]))
let g_native_passes : Ref[Map[Int, Int]] = Ref(Map([]))

///|
/// 该不该走原生档：当前窗有已挂载的原生子件就走。无宿主/无窗一律走图层。
pub fn overlay_native_tier() -> Bool {
  match host_active() {
    Some(a) => a.window().has_child_surfaces()
    None => false
  }
}

///|
/// 开一扇弹层窗装 `content`。返回 false = 开不出来（调用方退回图层档）。
fn overlay_native_open(
  cid : Int,
  content : Node,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Bool {
  match host_active() {
    None => false
    Some(a) =>
      match a.open_popup(
        x.round().to_int(),
        y.round().to_int(),
        if w < 80.0 { 320 } else { w.round().to_int() },
        if h < 40.0 { 200 } else { h.round().to_int() },
      ) {
        None => false
        Some(pop) => {
          pop.mount([content])
          g_native.val.set(cid, pop)
          g_native_passes.val.set(cid, 0)
          true
        }
      }
  }
}

///|
/// 收起一个原生档浮层（窗已自己关过时只清表）。返回是否命中原生档。
fn overlay_native_close(cid : Int) -> Bool {
  match g_native.val.get(cid) {
    None => false
    Some(pop) => {
      let _ = g_native.val.remove(cid)
      let _ = g_native_passes.val.remove(cid)
      if !pop.closed {
        pop.close_window()
      }
      true
    }
  }
}

///|
/// 原生档在开数（诊断与 `overlay_count` 用）。
pub fn overlay_native_count() -> Int {
  g_native.val.length()
}

///|
/// 量内容实际尺寸：弹层根控件的可见子项矩形并集（隐藏项矩形已被清零，天然排除）。
fn overlay_content_size(app : App) -> (Int, Int) {
  let mut w = 0.0
  let mut h = 0.0
  for k in app.root.children() {
    if k.visible && k.rect.w > w {
      w = k.rect.w
    }
    if k.visible && k.rect.y + k.rect.h > h {
      h = k.rect.y + k.rect.h
    }
  }
  (w.ceil().to_int(), h.ceil().to_int())
}

///|
/// 首帧后收框：宿主每拍调一次，同一浮层最多试三帧（布局可能因宽度变化再长高）。
/// 三帧用尽后仍放行**放大**——内容后来长宽了（例如顶部轻提示又推来一条更宽的），
/// 框子不跟着长就会把多出来的内容切掉；收缩仍受三帧限制，避免宽度回环里来回改尺寸。
pub fn overlay_fit_pass(app : App) -> Unit {
  let hits : Array[Int] = []
  for cid, pop in g_native.val {
    if pop.session.wid == app.session.wid {
      hits.push(cid)
    }
  }
  for cid in hits {
    let passes = match g_native_passes.val.get(cid) {
      Some(n) => n
      None => 0
    }
    match g_native.val.get(cid) {
      None => ()
      Some(pop) => {
        let (w, h) = overlay_content_size(pop)
        let (cw, ch) = pop.session.window.size()
        if passes >= 3 {
          if w > cw || h > ch {
            pop.session.window.set_size_pixels(w.max(cw), h.max(ch))
          }
          continue
        }
        g_native_passes.val.set(cid, passes + 1)
        if w > 1 && h > 1 && (w != cw || h != ch) {
          pop.session.window.set_size_pixels(w, h)
        }
      }
    }
  }
}

///|
/// 「失焦即收起」的开关，**默认关**。真窗口实测：弹层开出来约两秒就自己没了，
/// 而内容里的「收起」从没被点过（`hides=0`）——映射期的焦点来回会立刻送一次
/// focus-out。在没有「拿到过焦点才算」的判据之前，宁可让浮层常驻、由内容自己收，
/// 也不要「开一下就自己消失」这种更坏的现象。
let g_dismiss_on_blur : Ref[Bool] = Ref(false)

///|
pub fn overlay_set_dismiss_on_blur(on : Bool) -> Unit {
  g_dismiss_on_blur.val = on
}

///|
pub fn overlay_dismiss_on_blur() -> Bool {
  g_dismiss_on_blur.val
}

///|
/// 弹层窗失去键盘焦点 = 用户点了别处 → 收起最上面那层（图层档的「点外收起」
/// 靠命中，原生档只能靠这条）。开关见上。
pub fn overlay_on_lost_focus(app : App) -> Unit {
  if !g_dismiss_on_blur.val {
    return
  }
  let mut top = 0
  for cid, pop in g_native.val {
    if pop.session.wid == app.session.wid {
      top = if cid > top { cid } else { top }
    }
  }
  if top != 0 {
    let _ = overlay_native_close(top)
    invalidate()
  }
}

///|
/// 拆掉所有原生档浮层（宿主退出时调，避免主窗退了而弹层还留在屏上）。
pub fn overlay_close_all_native() -> Unit {
  let ids : Array[Int] = []
  for cid, _ in g_native.val {
    ids.push(cid)
  }
  for cid in ids {
    let _ = overlay_native_close(cid)
  }
}
