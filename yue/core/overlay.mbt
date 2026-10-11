// 浮层宿主：整窗覆盖的图层 + 已开浮层栈。
//
// 两条设计取舍（都为了不打扰内容的事件流）：
// ① **空图层不可见**——`display:none` 的控件不在任何命中路径上，所以没有浮层时
//    点击原样落到内容控件；一旦开了第一层就把图层置可见并**立刻重排一次**（图层
//    此前不可见、矩形还是清零的，不重排就换算不出它自己的原点），这样浮层按窗口
//    坐标摆位时能把图层原点扣掉。
// ② **点浮层外收起最上面那层**——图层是浮层的父控件，浮层内部被点时最深的命中者
//    是浮层里的控件（事件往上冒时图层会看到坐标落在子浮层内，于是不关）；点在所有
//    子浮层之外时最深命中者就是图层本身，此时收起最上面一层并消费掉这次按下。
//
// 图层坐标口径：图层是根控件的绝对定位子控件（insets 全 0 → 铺满根的 padding 盒），
// 所以「窗口坐标 → 图层坐标」只差一个图层原点。

///|
/// 浮层宿主：持有根控件（开层时要立刻重排）与图层、已开浮层栈。
pub(all) struct OverlayHost {
  root : Widget
  layer : Widget
  mut next_id : Int
  mut items : Array[(Int, Widget)]
}

///|
/// 建宿主并把图层挂到根控件最后（后画在上），图层默认不可见。
pub fn make_overlay_host(root : Widget) -> OverlayHost {
  let layer = Widget::new()
  layer.node.set_position(@yoga.Absolute)
  layer.node.set_top(@yoga.fixed(0.0))
  layer.node.set_left(@yoga.fixed(0.0))
  layer.node.set_right(@yoga.fixed(0.0))
  layer.node.set_bottom(@yoga.fixed(0.0))
  layer.set_visible(false)
  root.append_child(layer)
  let host : OverlayHost = { root, layer, next_id: 0, items: [] }
  layer.on_pointer = Some(fn(
    self : Widget,
    ev : PointerEvent,
  ) -> Bool {
    let inside = {
      let ax = ev.x + self.rect.x
      let ay = ev.y + self.rect.y
      let mut hit = false
      for k in self.kids {
        if k.visible && k.rect.contains(ax, ay) {
          hit = true
        }
      }
      hit
    }
    match ev.kind {
      // 按下与抬起都消费（不让这一击漏到内容里），**收起放在抬起**：
      // 若放在按下，同一击的抬起会重新命中触发件、把刚关掉的浮层又打开
      Down => true
      Up => {
        if !inside {
          overlay_hide_top()
        }
        true
      }
      _ => false
    }
  })
  host
}

///|
/// 进程级单槽（与 `set_repaint_hook` 同款：当前形态一进程一宿主）。
let overlay_slot : Ref[OverlayHost?] = Ref(None)

///|
/// 安装浮层宿主（`App::new` 调用；无宿主时所有浮层 API 都是空操作）。
pub fn set_overlay_host(h : OverlayHost) -> Unit {
  overlay_slot.val = Some(h)
}

///|
/// 已开浮层数（诊断与测试用）。
pub fn overlay_count() -> Int {
  match overlay_slot.val {
    Some(h) => h.items.length()
    None => 0
  }
}

///|
/// 图层当前是否可见（有浮层就该可见）。
pub fn overlay_visible() -> Bool {
  match overlay_slot.val {
    Some(h) => h.layer.visible
    None => false
  }
}

///|
/// 在窗口坐标 `(x, y)` 处开一层浮层，内容挂在图层里的一个绝对定位包裹控件上。
/// 返回句柄；没有宿主时返回 0（浮层不出现）。
pub fn overlay_show_at(content : Node, x : Double, y : Double) -> Int {
  match overlay_slot.val {
    None => 0
    Some(h) => {
      if h.items.length() == 0 {
        h.layer.set_visible(true)
      }
      // 图层此前可能是不可见的（矩形清零），摆位前先让它按当前布局就位
      h.root.relayout(h.root.rect.w, h.root.rect.h)
      let wrap = Widget::new()
      wrap.node.set_position(@yoga.Absolute)
      wrap.node.set_left(@yoga.fixed(x - h.layer.rect.x))
      wrap.node.set_top(@yoga.fixed(y - h.layer.rect.y))
      let _ = content.mount_into(wrap)
      h.layer.append_child(wrap)
      h.next_id = h.next_id + 1
      h.items.push((h.next_id, wrap))
      invalidate()
      h.next_id
    }
  }
}

///|
/// 关掉指定浮层（句柄 0 或不存在时空操作）；关完最后一层就收起图层。
pub fn overlay_hide(id : Int) -> Unit {
  match overlay_slot.val {
    None => ()
    Some(h) => {
      let kept : Array[(Int, Widget)] = []
      for it in h.items {
        if it.0 == id {
          let _ = h.layer.remove_child(it.1)
        } else {
          kept.push(it)
        }
      }
      h.items = kept
      if h.items.length() == 0 {
        h.layer.set_visible(false)
      }
      invalidate()
    }
  }
}

///|
/// 关掉最上面一层（点浮层外收起用）。
pub fn overlay_hide_top() -> Unit {
  match overlay_slot.val {
    Some(h) =>
      if h.items.length() > 0 {
        overlay_hide(h.items[h.items.length() - 1].0)
      }
    None => ()
  }
}

///|
/// 关掉全部浮层。
pub fn overlay_clear() -> Unit {
  match overlay_slot.val {
    Some(h) => {
      for it in h.items {
        let _ = h.layer.remove_child(it.1)
      }
      h.items = []
      h.layer.set_visible(false)
      invalidate()
    }
    None => ()
  }
}

///|
/// 把图层挪回最后一个子控件（内容挂载后调用）：后画的覆盖在前、命中也最先，
/// 浮层必须始终压在内容之上。
pub fn overlay_raise() -> Unit {
  match overlay_slot.val {
    Some(h) => {
      let idx = h.root.index_of(h.layer)
      let n = h.root.children().length()
      if idx >= 0 && idx < n - 1 {
        h.root.move_child(idx, n - 1)
      }
    }
    None => ()
  }
}

///|
/// 指定浮层的包裹控件（诊断与测试用：浮层内容挂在它的子控件里）。
pub fn overlay_root_of(id : Int) -> Widget? {
  match overlay_slot.val {
    Some(h) => {
      for it in h.items {
        if it.0 == id {
          return Some(it.1)
        }
      }
      None
    }
    None => None
  }
}

///|
/// 指定浮层在窗口坐标里的矩形（诊断与测试用）。
pub fn overlay_rect_of(id : Int) -> Rect? {
  match overlay_slot.val {
    Some(h) => {
      for it in h.items {
        if it.0 == id {
          let r = it.1.rect
          return Some({
            x: r.x + h.layer.rect.x,
            y: r.y + h.layer.rect.y,
            w: r.w,
            h: r.h,
          })
        }
      }
      None
    }
    None => None
  }
}
