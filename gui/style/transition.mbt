// `transition`：状态桶切换时的属性过渡（design.md §5 P5）。
//
// 插值集合只收「每帧从样式槽读出来」的绘制期字段：三条颜色 + 边框宽 + 圆角。
// `opacity` / `box_shadow` 的生效点是 `apply` → `Widget` 字段（绘制遍历不逐帧读槽），
// 布局字段参与插值等于每帧重排——两者都不在集合里。
//
// 帧驱动复用进程级 `@core.set_timeout`：每拍只给活动中的控件局部置脏
// （`@core.invalidate_id`），全部收敛就停表，不空转。

///|
/// 一条控件的过渡账。`shown` 是最近一次交出去的值——目标中途再变就从它续起，
/// 所以悬停到一半移开不会跳变（反向打断从当前像素出发，不从端点出发）。
priv struct Anim {
  mut from : Style
  mut target : Style
  mut start : Int64
  mut dur : Int
  mut shown : Style
  mut finished : Bool
}

///|
let anims : Map[Int, Anim] = Map([])

///|
let ticking : Ref[Bool] = Ref(false)

///|
/// 每拍的间隔（毫秒）：60fps 的一格。插值按**真实经过时间**算，不看拍数，
/// 所以这一格不准（掉帧、宿主忙）只会让过渡少几帧，不会变快变慢。
let tick_ms : Int = 16

///|
/// 控件被摘掉时连带清掉它的过渡账（与样式侧表同一条丢弃钩子）。
pub fn forget_anim(id : Int) -> Unit {
  let _ = anims.remove(id)
}

///|
/// 当前挂着账的控件数（诊断用：残账判据）。
pub fn anim_count() -> Int {
  anims.length()
}

///|
/// 过渡时长（毫秒）：基块上的 `transition_ms`，没写或 ≤0 都不动画。
fn duration_of(target : Style) -> Int {
  match target.transition_ms {
    Some(v) => if v > 0.5 { v.round().to_int() } else { 0 }
    None => 0
  }
}

///|
/// 缓动曲线（smoothstep，近似 CSS 的 ease-in-out）：两端速度归零，中段最快。
fn ease(t : Double) -> Double {
  t * t * (3.0 - 2.0 * t)
}

///|
fn lerp_number(a : Double?, b : Double?, t : Double) -> Double? {
  match (a, b) {
    (Some(x), Some(y)) => Some(x + (y - x) * t)
    _ => b
  }
}

///|
/// 颜色插值：两端都**现取**成 hex 再混色（`Var` token 走当前主题）。任一端没写、
/// 或写法不是 hex（命名色那类）时由 `mix_hex` 退成端点值——中间帧停在起点，
/// 终点那一帧仍然是目标值，不会画错颜色。
fn lerp_color(a : Color?, b : Color?, t : Double) -> Color? {
  match (a, b) {
    (Some(x), Some(y)) =>
      Some(Hex(@theme.mix_hex(resolve_color(x), resolve_color(y), 1.0 - t)))
    _ => b
  }
}

///|
/// 逐字段插值：`t=0` 给 `from`、`t=1` 给 `to`；不在插值集合里的字段一律取目标值。
pub fn lerp_style(from : Style, to : Style, t : Double) -> Style {
  let tt = if t <= 0.0 { 0.0 } else if t >= 1.0 { 1.0 } else { t }
  // 复制目标块（merge 造新值、不改入参），再覆盖插值字段
  let out = merge(to, empty_style())
  out.color = lerp_color(from.color, to.color, tt)
  out.background_color = lerp_color(
    from.background_color,
    to.background_color,
    tt,
  )
  out.border_color = lerp_color(from.border_color, to.border_color, tt)
  out.border_width = lerp_number(from.border_width, to.border_width, tt)
  out.border_radius = lerp_number(from.border_radius, to.border_radius, tt)
  out
}

///|
/// 颜色的可比投影（`Color` 没有 `Eq`，本仓库约定按写法前缀区分，不 derive）。
fn color_key(c : Color?) -> String {
  match c {
    None => ""
    Some(Hex(s)) => "#" + s
    Some(Named(s)) => "n" + s
    Some(Var(s)) => "@" + s
  }
}

///|
/// 插值字段的投影：两个目标的投影相等就认为「状态没变」，动画按原进度继续走。
fn animatable_key(s : Style) -> (String, String, String, Double?, Double?) {
  (
    color_key(s.color),
    color_key(s.background_color),
    color_key(s.border_color),
    s.border_width,
    s.border_radius,
  )
}

///|
/// 推进一条账：到点就交终点值并结清，没到点就交插值值。
fn progress(a : Anim, now : Int64) -> Style {
  let t = (now - a.start).to_double() / a.dur.to_double()
  if t >= 1.0 {
    a.shown = a.target
    a.finished = true
    a.shown
  } else {
    let v = lerp_style(a.from, a.target, ease(if t <= 0.0 { 0.0 } else { t }))
    a.shown = v
    ensure_ticking()
    v
  }
}

///|
/// 落定：账停在目标值上（`shown` 同步成目标，下一次过渡从它续起）。
fn settle(a : Anim, target : Style, now : Int64) -> Unit {
  a.from = target
  a.target = target
  a.shown = target
  a.start = now
  a.finished = true
}

///|
/// 按给定时刻推进一条控件的过渡（绘制期入口，`now` 由调用方给，测试可喂假时钟）。
/// 口径四条：
/// ① 第一次见到这条控件只记目标、不动画（建树与重挂不该整片淡入）；
/// ② 当前显示值已经等于目标（或差异不在插值集合里）就落定；
/// ③ 目标换了就从当前显示值续接（反向打断不跳变），同一目标则按原时钟继续走；
/// ④ `transition_ms` 没写或为 0 立刻落定。
pub fn step(id : Int, target : Style, now : Int64) -> Style {
  let dur = duration_of(target)
  match anims.get(id) {
    None => {
      anims.set(id, {
        from: target,
        target,
        start: now,
        dur,
        shown: target,
        finished: true,
      })
      target
    }
    Some(a) => {
      let at_shown = animatable_key(a.shown) == animatable_key(target)
      let same_as_running = animatable_key(a.target) == animatable_key(target)
      if dur <= 0 || at_shown {
        settle(a, target, now)
        target
      } else if a.finished || !same_as_running {
        // 目标换了：从当前显示值续接,不跳变
        a.from = a.shown
        a.target = target
        a.start = now
        a.dur = dur
        a.finished = false
        progress(a, now)
      } else {
        // 同一目标、过渡未完：非插值字段跟着新目标走，时钟不动
        a.target = target
        progress(a, now)
      }
    }
  }
}

///|
/// 一拍：把还没落定的过渡各自标脏（只标自己那一块）。全部落定就停表。
fn tick() -> Unit {
  let now = @core.now_ms()
  let mut live = 0
  for id, a in anims {
    if !a.finished {
      // 时间已过但一直没被画到（整块被藏起来）：补交终点值并标这一格，不留长尾
      if (now - a.start).to_int() >= a.dur {
        a.shown = a.target
        a.finished = true
        @core.invalidate_id(id)
      } else {
        @core.invalidate_id(id)
        live += 1
      }
    }
  }
  if live > 0 {
    let _ = @core.set_timeout(tick_ms, tick)
  } else {
    ticking.val = false
  }
}

///|
/// 起表（幂等）：过渡进行中只维持一条定时器,收敛后停,不空转。
fn ensure_ticking() -> Unit {
  if !ticking.val {
    ticking.val = true
    let _ = @core.set_timeout(tick_ms, tick)
  }
}

///|
/// 过渡是否还在跑（诊断与测试用）。
pub fn anim_running(id : Int) -> Bool {
  match anims.get(id) {
    Some(a) => !a.finished
    None => false
  }
}
