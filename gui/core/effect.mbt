// `effect` / `watch` 一等入口（design.md §3 第 2 项）： computed 已经能在求值期
// 自动收集依赖，这里把「跟着数据跑」的两类需求收成正式 API——
// - `effect`：闭包读了哪些信号就订阅哪些，依赖一变整个闭包重跑（副作用自己留在闭包里）；
// - `watch`：只盯一个源信号，值变了拿 (新值, 旧值) 做一次动作，不重跑收集。
// 两者的退订都进订阅回收袋（`sub_bag_*`）：随这一代子树一起退，重挂不留死订阅。

///|
/// 副作用：立即跑一遍 `body`（跑的过程中自动收集读到的信号作依赖），此后任一
/// 依赖变化就重跑。返回退订闭包（幂等）；不用它也会随当前回收袋退订。
/// 嵌套安全：重跑时的收集会先断开旧依赖，不会越跑越多。
pub fn effect(body : () -> Unit) -> () -> Unit {
  // computed 的「重算 = 重跑闭包 + 依赖重收集」正是 effect 的语义；套一个
  // 空订阅让它接到通知（Signal::subscribe 的唤醒形态就是 self.get()）。
  // 依赖一变:observer 标脏 → sig_deliver 走订阅 → rerun_effect 恰好跑 body 一遍。
  let s = Signal::effect(fn() -> Unit {
    body()
  })
  let sid = s.subscribe_raw(fn() -> Unit { s.rerun_effect() })
  s.rerun_effect() // 建立即跑第一遍(同时完成依赖收集)
  fn() -> Unit { s.remove(sid) }
}

///|
/// 观察一个信号：初值不发（要跟初值做事请先 `get()`），此后每次变化给
/// (新值, 旧值)。`immediate=true` 时建订阅先补发一次 (初值, 初值)。
/// 退订同样进回收袋；返回退订闭包。
pub fn[T] watch(
  src : Signal[T],
  on_change : (T, T) -> Unit,
  immediate? : Bool = false,
) -> () -> Unit {
  let last : Ref[T] = Ref(src.get())
  let sid = src.subscribe(fn(v : T) -> Unit {
    let old = last.val
    last.val = v
    on_change(v, old)
  })
  if immediate {
    let v = src.get()
    on_change(v, v)
  }
  fn() -> Unit { src.remove(sid) }
}

///|
/// Store 形态的观察（输入类组件绑 Store 的常用面）：语义同 [watch]，源取
/// `Store::signal()`，与 `Store::subscribe_id` 共用同一注册表。
pub fn[T] watch_store(src : Store[T], on_change : (T, T) -> Unit) -> () -> Unit {
  watch(src.signal(), on_change)
}
