// 滚动视图与滚动条策略。

///|
/// 创建滚动视图。
pub fn Scroll::new() -> Scroll {
  { view: ffi_scroll_new(), }
}

///|
/// 设置滚动内容视图。
pub fn[T : ViewLike] Scroll::set_content(self : Scroll, content : T) -> Unit {
  ffi_scroll_set_content(ViewLike::view(self), content.view())
}

///|
/// 设置内容逻辑尺寸（超出可视区产生滚动）。
pub fn Scroll::set_content_size(
  self : Scroll,
  width : Double,
  height : Double,
) -> Unit {
  ffi_scroll_set_content_size(ViewLike::view(self), width, height)
}

///|
/// 设置滚动位置。
pub fn Scroll::set_scroll_position(
  self : Scroll,
  horizon : Double,
  vertical : Double,
) -> Unit {
  ffi_scroll_set_scroll_position(ViewLike::view(self), horizon, vertical)
}

///|
/// 回到顶部:设置位置后短延时复设一次——快速滚到底后 GTK smooth 滚动
/// 仍有在途滚动事件,首次设置会被拉回旧值(真机实测「点两次才回顶」),
/// 复设压过在途事件,一次点击即生效。
pub fn Scroll::scroll_to_top(self : Scroll) -> Unit {
  self.set_scroll_position(0.0, 0.0)
  ignore(set_timeout(80, fn() { self.set_scroll_position(0.0, 0.0) }))
}

///|
/// 是否使用覆盖式滚动条。

///|
/// 滚动条策略（对照 Scroll::Policy）。
pub(all) enum ScrollPolicy {
  Always
  Never
  Automatic
}

///|
fn scroll_policy_id(p : ScrollPolicy) -> Int {
  match p {
    Always => 0
    Never => 1
    Automatic => 2
  }
}

///|
fn scroll_policy_of(id : Int) -> ScrollPolicy {
  match id {
    0 => Always
    1 => Never
    _ => Automatic
  }
}

///|
/// 设置横/纵滚动条策略。
pub fn Scroll::set_scrollbar_policy(
  self : Scroll,
  h : ScrollPolicy,
  v : ScrollPolicy,
) -> Unit {
  ffi_scroll_set_scrollbar_policy(
    self.view,
    scroll_policy_id(h),
    scroll_policy_id(v),
  )
}

///|
pub fn Scroll::get_scrollbar_policy(
  self : Scroll,
) -> (ScrollPolicy, ScrollPolicy) {
  (
    scroll_policy_of(ffi_scroll_get_scrollbar_policy_x(self.view)),
    scroll_policy_of(ffi_scroll_get_scrollbar_policy_y(self.view)),
  )
}

///|
pub fn Scroll::set_overlay_scrollbar(self : Scroll, yes : Bool) -> Unit {
  ffi_scroll_set_overlay_scrollbar(
    ViewLike::view(self),
    if yes {
      1
    } else {
      0
    },
  )
}
