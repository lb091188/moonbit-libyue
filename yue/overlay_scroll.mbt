// L2 组件:悬浮滚动条(overlay scrollbar)。
//
// 背景:libyue 在 Windows 的滚动条是自绘经典样式(箭头按钮 + 常驻占
// 布局),SetOverlayScrollbar 对 Windows 是空操作;Linux 的 GTK overlay
// 则原生悬浮。本模块把滚动条策略置 Never 隐藏平台条,自绘悬浮 thumb
// 叠在内容右缘:滚动浮现、停顿约 1s 后两级渐隐、hover/拖拽期间保持、
// 支持沿轨道拖拽(thumb 可见段)与点击轨道锚定,thumb 上滚轮转发给
// Scroll。三平台走同一实现,滚动条外观与主题色一致。
//
// 实现约束:thumb 视图经 yoga absolute 定位占满右缘全高(top/bottom
// 静态样式,滚动期间零 yoga 重排),可见 thumb 段在 on_draw 里按状态
// 绘制;几何(位置/长度)由 on_scroll 与 on_size_changed 驱动重算。
// 声明式 scroll() 的默认形态(overlay=true 且未显式 policy)同样走
// attach_overlay_thumb 收口。

///|
/// 给已挂进 host 的 Scroll 挂悬浮 thumb:隐藏平台滚动条(policy 置
/// Never),thumb 以 yoga absolute 定位于 host 右缘(host 须为同时容纳
/// Scroll 的容器,几何即滚动视口)。
pub fn attach_overlay_thumb(host : View, s : Scroll) -> Unit {
  s.set_scrollbar_policy(Never, Never) // 隐藏平台滚动条,thumb 全权替代
  // ---- 悬浮 thumb:右缘窄条,占满轨道高度,可见段由绘制决定 ----
  let thumb = themed_container(style=[("width", 6.0)], style_str=[
    ("position", "absolute"),
    ("right", "0px"),
    ("top", "0px"),
    ("bottom", "0px"),
  ])
  attach(host, ViewLike::view(thumb))
  // 状态(gy/thumb_len 绘制用;alpha 两级 d9≈85% 常态 / 73≈45% 渐隐中)
  let vis = Ref(false)
  let alpha = Ref("d9") // #RRGGBBAA 的 AA 段(十六进制)
  let hover = Ref(false)
  let drag = Ref(false)
  let gy = Ref(0.0) // 可见 thumb 段顶点(轨道坐标)
  let thumb_len = Ref(0.0)
  let track_len = Ref(1.0)
  let hide_timer = Ref(0)
  let drag_y0 = Ref(0.0)
  let drag_pos0 = Ref(0.0)
  let maxy = Ref(0.0)

  fn arm_hide() {
    if hide_timer.val != 0 {
      clear_timeout(hide_timer.val)
      hide_timer.val = 0
    }
    if drag.val || hover.val {
      return
    }
    hide_timer.val = set_timeout(1000, fn() {
      if drag.val || hover.val {
        return
      }
      alpha.val = "73"
      ViewLike::schedule_paint(thumb)
      hide_timer.val = set_timeout(350, fn() {
        if drag.val || hover.val {
          return
        }
        vis.val = false
        ViewLike::set_visible(thumb, false)
        hide_timer.val = 0
      })
    })
  }

  fn sync() {
    let m = s.get_max_scroll_position_y()
    let track = s.get_bounds().height
    maxy.val = m
    track_len.val = track
    if m <= 0.5 || track < 40.0 {
      if vis.val {
        vis.val = false
        ViewLike::set_visible(thumb, false)
      }
      return
    }
    let full = track * track / (track + m)
    let len = if full < 40.0 { 40.0 } else { full }
    let pos = s.get_scroll_position_y()
    let y = if track - len > 0.0 {
      pos / m * (track - len)
    } else {
      0.0
    }
    thumb_len.val = len
    gy.val = y
    if !vis.val {
      alpha.val = "d9"
      vis.val = true
      ViewLike::set_visible(thumb, true)
    }
    ViewLike::schedule_paint(thumb)
    arm_hide()
  }

  s.on_scroll(fn() {
    sync()
    false
  })
  ViewLike::on_size_changed(s, fn() { sync() })
  thumb.on_draw(fn(p) {
    if !vis.val || thumb_len.val <= 0.0 {
      return
    }
    p.set_fill_color(with_alpha(theme_border(), alpha.val))
    fill_round_rect(p, 0.0, gy.val, 6.0, thumb_len.val, 3.0)
  })
  ViewLike::on_mouse_enter(thumb, fn(_e) {
    hover.val = true
    if vis.val {
      alpha.val = "d9"
      ViewLike::schedule_paint(thumb)
    }
  })
  ViewLike::on_mouse_leave(thumb, fn(_e) {
    hover.val = false
    arm_hide()
  })
  // 按住后平台有隐式鼠标捕获,拖出 thumb 仍收 move
  ViewLike::on_mouse_down(thumb, fn(e) {
    if e.button == 1 && vis.val {
      drag.val = true
      drag_y0.val = e.view_y
      drag_pos0.val = s.get_scroll_position_y()
      alpha.val = "ff"
      ViewLike::schedule_paint(thumb)
      true
    } else {
      false
    }
  })
  ViewLike::on_mouse_move(thumb, fn(e) {
    if drag.val && maxy.val > 0.5 && track_len.val - thumb_len.val > 0.0 {
      let dy = e.view_y - drag_y0.val
      let pos = drag_pos0.val + dy * maxy.val / (track_len.val - thumb_len.val)
      s.set_scroll_position(s.get_scroll_position_x(), pos)
    }
  })
  ViewLike::on_mouse_up(thumb, fn(e) {
    if e.button == 1 && drag.val {
      drag.val = false
      alpha.val = "d9"
      ViewLike::schedule_paint(thumb)
      arm_hide()
      true
    } else {
      false
    }
  })
  // thumb 窄条上的滚轮不冒泡到 Scroll,手动转发
  ViewLike::on_wheel(thumb, fn(delta) {
    s.set_scroll_position(
      s.get_scroll_position_x(),
      s.get_scroll_position_y() + delta * 48.0,
    )
  })
}

///|
/// 悬浮滚动条容器:content 为滚动内容(声明式节点),挂载后自带悬浮
/// thumb。style 应用于外层容器(须给定尺寸或由外层布局决定);handle
/// 可拿到内部 Scroll 做程序化滚动。
pub fn overlay_scroll(
  content : Node,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
  handle? : (Scroll) -> Unit = fn(_s) {  },
) -> Node {
  {
    mount: fn(parent) {
      let host = themed_container(style~, style_str~)
      attach(parent, ViewLike::view(host))
      let s = Scroll::new()
      handle(s)
      attach(ViewLike::view(host), ViewLike::view(s))
      let holder = Container::new()
      ignore((content.mount)(ViewLike::view(holder)))
      s.set_content(holder)
      attach_overlay_thumb(ViewLike::view(host), s)
      // declarative scroll() 同款:Windows 上原生子控件 HWND 不随滚动平移,
      // 0ms 定时器延到滚动布局完成后强制重摆 content 子树(勿追加整区失
      // 效重绘,实测会加剧闪烁与卡顿)
      if platform() == "windows" {
        s.on_scroll(fn() {
          let _ = set_timeout(0, fn() { holder.update_child_bounds() })
          false
        })
      }
      ViewLike::view(host)
    },
  }
}
