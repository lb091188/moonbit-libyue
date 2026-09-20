// 事件系统纯 MoonBit 部分测试（不依赖原生库）。

///|
fn down(x : Double, ts : Int, btn : Int) -> @yue.MouseEvent {
  {
    kind: MouseDown,
    button: btn,
    view_x: x,
    view_y: 10.0,
    window_x: 0.0,
    window_y: 0.0,
    screen_x: 0.0,
    screen_y: 0.0,
    modifiers: 0,
    timestamp: ts,
  }
}

///|
test "ClickTracker 连击计数：时间窗/距离窗/换键重置" {
  let t = @yue.ClickTracker::new()
  // 单击
  inspect(t.feed(down(10.0, 1000, 1)), content="1")
  // 200ms 后 1px 内再点 → 双击
  inspect(t.feed(down(11.0, 1200, 1)), content="2")
  // 300ms 5px 内再点 → 三击
  inspect(t.feed(down(13.0, 1500, 1)), content="3")
  // 距离超窗（>5px）→ 重新计 1
  inspect(t.feed(down(40.0, 1600, 1)), content="1")
  // 时间超窗（>400ms）→ 重新计 1
  inspect(t.feed(down(40.0, 2100, 1)), content="1")
  // 换键 → 重新计 1
  inspect(t.feed(down(40.0, 2200, 3)), content="1")
  // 自定义窗口：放宽距离
  let wide = @yue.ClickTracker::new_with(1000, 50.0)
  inspect(wide.feed(down(0.0, 100, 2)), content="1")
  inspect(wide.feed(down(45.0, 800, 2)), content="2")
}

///|
test "事件结构字段与修饰位" {
  let me : @yue.MouseEvent = {
    kind: MouseUp,
    button: 3,
    view_x: 1.5,
    view_y: 2.5,
    window_x: 11.0,
    window_y: 22.0,
    screen_x: 33.0,
    screen_y: 44.0,
    modifiers: @yue.KEY_MOD_SHIFT,
    timestamp: 42,
  }
  inspect(me.kind is MouseUp, content="true")
  inspect(me.button, content="3")
  inspect(me.view_x, content="1.5")
  inspect(me.window_y, content="22")
  inspect(me.screen_x, content="33")
  inspect(me.timestamp, content="42")
  inspect(me.has_mod(@yue.KEY_MOD_SHIFT), content="true")
  inspect(me.has_mod(@yue.KEY_MOD_CTRL), content="false")
  let ke : @yue.KeyEvent = {
    kind: KeyDown,
    code: @yue.VKEY_ESCAPE,
    modifiers: @yue.KEY_MOD_CTRL.lor(@yue.KEY_MOD_ALT),
    timestamp: 7,
  }
  inspect(ke.kind is KeyDown, content="true")
  inspect(ke.code, content="65307")
  inspect(ke.has_mod(@yue.KEY_MOD_CTRL), content="true")
  inspect(ke.has_mod(@yue.KEY_MOD_ALT), content="true")
  inspect(ke.has_mod(@yue.KEY_MOD_META), content="false")
}
