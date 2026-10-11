// L3 响应式层：Signal（自动依赖收集的信号）与 Store（可订阅的值）。
// 自 master 线 `yue/signals.mbt` / `yue/store.mbt` 平移**内核**（零平台依赖、
// 原样保留），挂视图那两层换成新栈形态：`bind_node`/`swap_node` 见
// `yue/core/node.mbt`（挂载目标是自绘 `Widget`，不是 libyue 的 `View`）。
// 与 Store 的分工：
//   Store  = 可写源 + 组件 API 的既有参数类型，手动 get/set/subscribe；
//   Signal = 源 + computed（求值期自动收集读到的信号为依赖，依赖变化自动
//            失效、读取时重算），派生关系免手动接线。
// 两者共享同一内核，可零成本互转（Signal::store / Store::signal）。
// 批处理：同一事件回调里多次 set，用 batch(fn(){...}) 包裹，订阅者只在
// 出 batch 时收到一次通知。

///|
/// 信号内核(非泛型):脏标记 + 订阅/依赖关系。泛型壳(Signal[T])
/// 持有值与计算函数;id 用于关系数组里的身份比较。
/// subs 为 (订阅 id, 回调) 对:subscribe 返回的 id 即退订句柄
/// (见 Signal::remove),recompute 期间登记的依赖不受影响。
struct SigNode {
  id : Int
  mut dirty : Bool
  mut queued : Bool
  mut subs : Array[(Int, () -> Unit)]
  mut deps : Array[SigNode]
  mut observers : Array[SigNode]
}

///|
let sig_next_id : Ref[Int] = Ref(0)

///|
/// 订阅 id 计数器:subscribe 的返回值即本计数器的当期值,
/// remove 按 id 精确摘除,互不影响同一信号上的其他订阅。
let sig_sub_next_id : Ref[Int] = Ref(0)

///|
let sig_batch_depth : Ref[Int] = Ref(0)

///|
let sig_pending : Ref[Array[SigNode]] = Ref([])

///|
/// 依赖收集上下文:Some((正在重算的 computed 节点, 收集缓冲))。
let sig_collector : Ref[(SigNode, Array[SigNode])?] = Ref(None)

///|
/// 订阅回收袋栈:重建式组件(bind_node 重挂 / 表格重建 / 穿梭框移动)
/// 在重建前开袋,重建期间注册的全部订阅(Store 与主题)把退订闭包
/// 压进袋中;旧代订阅在下次重建前整袋退订——随旧视图一起死掉的
/// 订阅不再随重建次数无界累积。袋可嵌套(子树内再开袋),与
/// sig_collector 同款「收集期全局上下文」模式。
let sub_bags : Ref[Array[Array[() -> Unit]]] = Ref([])

///|
fn sig_fresh_id() -> Int {
  sig_next_id.val += 1
  sig_next_id.val
}

///|
fn sig_fresh_sub_id() -> Int {
  sig_sub_next_id.val += 1
  sig_sub_next_id.val
}

///|
/// 把一条订阅的退订闭包压入当前回收袋(无袋时忽略:常规挂载订阅
/// 随应用存活,不进袋)。
/// 公开给跨包的组件用:任何「随这一代子树一起生、一起死」的资源(主题订阅、
/// 自定义清理)都走这里,不必等 bind_node 重建才回收。
pub fn sub_bag_register(off : () -> Unit) -> Unit {
  match sub_bags.val.last() {
    Some(bag) => bag.push(off)
    None => ()
  }
}

///|
/// 开订阅回收袋(与 [sub_bag_end] 成对;嵌套安全)。
pub fn sub_bag_begin() -> Unit {
  sub_bags.val.push([])
}

///|
/// 收袋:返回本代注册的退订闭包表(调用方留存,下次重建前经
/// [sub_bag_discard] 整体退订)。
pub fn sub_bag_end() -> Array[() -> Unit] {
  let n = sub_bags.val.length()
  if n == 0 {
    []
  } else {
    let top = sub_bags.val[n - 1]
    sub_bags.val.truncate(n - 1)
    top
  }
}

///|
/// 整体退订一袋订阅(闭包来自 [sub_bag_end])。
pub fn sub_bag_discard(offs : Array[() -> Unit]) -> Unit {
  for off in offs {
    off()
  }
}

///|
fn sig_has(xs : Array[SigNode], x : SigNode) -> Bool {
  for y in xs {
    if y.id == x.id {
      return true
    }
  }
  false
}

///|
/// 通知传播:调本节点订阅者 + 下游 computed 标脏(级联)。batch 期间
/// 只入队去重,出 batch 统一冲刷。订阅者回调里读 get() 拿到的是最新值;
/// 钻石依赖下同一订阅者可能被多路径调用,重复调用读到的值一致。
fn sig_deliver(node : SigNode) -> Unit {
  if sig_batch_depth.val > 0 {
    if !node.queued {
      node.queued = true
      sig_pending.val.push(node)
    }
    return
  }
  let snapshot = node.subs.copy()
  for entry in snapshot {
    (entry.1)()
  }
  for o in node.observers.copy() {
    o.dirty = true
    sig_deliver(o)
  }
}

///|
/// 可订阅的信号:源信号(Signal::new)或派生信号(Signal::computed)。
/// 订阅闭包由 Signal 持有(纯 MoonBit 侧引用,无需 FFI 保活),默认
/// 存活整个应用期。
pub struct Signal[T] {
  priv node : SigNode
  priv mut value : T
  priv comp : (() -> T)?
}

///|
fn[T] sig_make(value : T, comp : (() -> T)?) -> Signal[T] {
  {
    node: {
      id: sig_fresh_id(),
      dirty: match comp {
        Some(_) => true
        None => false
      },
      queued: false,
      subs: [],
      deps: [],
      observers: [],
    },
    value,
    comp,
  }
}

///|
/// 创建源信号。
pub fn[T] Signal::new(value : T) -> Signal[T] {
  sig_make(value, None)
}

///|
/// 派生信号:闭包内读到的每个信号自动成为依赖;任一依赖变化后本信号
/// 失效,下一次 get() 重算。闭包不应读写自身(会无限递归);依赖分
/// 支(条件读)自动跟随最新一次求值实际读到的信号。
pub fn[T] Signal::computed(f : () -> T) -> Signal[T] {
  let s = sig_make(f(), Some(f))
  s.node.dirty = true
  s.recompute()
  s
}

///|
/// 批处理:fn 内的多次 set 合并为出 fn 时的一次通知(订阅者只跑一轮)。
/// 可嵌套,最外层结束时冲刷。
pub fn batch(f : () -> Unit) -> Unit {
  sig_batch_depth.val += 1
  f()
  sig_batch_depth.val -= 1
  if sig_batch_depth.val == 0 {
    let snapshot = sig_pending.val.copy()
    sig_pending.val = []
    for n in snapshot {
      n.queued = false
    }
    for n in snapshot {
      sig_deliver(n)
    }
  }
}

///|
/// 重算 computed:断开旧依赖 → 收集期执行闭包 → 登记新依赖 → 落值清脏。
fn[T] Signal::recompute(self : Signal[T]) -> Unit {
  match self.comp {
    Some(f) => {
      for d in self.node.deps {
        d.observers = d.observers.filter(fn(x) { x.id != self.node.id })
      }
      self.node.deps = []
      let saved = sig_collector.val
      let buf : Array[SigNode] = []
      sig_collector.val = Some((self.node, buf))
      let v = f()
      sig_collector.val = saved
      for d in buf {
        if d.id != self.node.id && !sig_has(self.node.deps, d) {
          d.observers.push(self.node)
          self.node.deps.push(d)
        }
      }
      self.value = v
      self.node.dirty = false
    }
    None => ()
  }
}

///|
/// 读值。computed 依赖失效时惰性重算;在 computed 闭包内读信号即登记
/// 依赖(读取即订阅)。
pub fn[T] Signal::get(self : Signal[T]) -> T {
  match sig_collector.val {
    Some((owner, buf)) =>
      if self.node.id != owner.id && !sig_has(buf, self.node) {
        buf.push(self.node)
      }
    None => ()
  }
  if self.node.dirty {
    self.recompute()
  }
  self.value
}

///|
/// 写新值并通知订阅者(不去重:相同值也会通知)。computed 上调用 set
/// 会覆盖缓存值,下次依赖变化仍会按闭包重算——正常用法只对源信号 set。
pub fn[T] Signal::set(self : Signal[T], value : T) -> Unit {
  self.value = value
  self.node.dirty = false
  sig_deliver(self.node)
}

///|
/// 用函数更新:set(f(get()))。
pub fn[T] Signal::update(self : Signal[T], f : (T) -> T) -> Unit {
  self.set(f(self.get()))
}

///|
/// 订阅变化,回调收到最新值。注册时不回调(初值请直接 get)。
/// 返回订阅 id(退订句柄):经 [Signal::remove] 按 id 摘除;重建式
/// 组件更省事的做法是把挂载包进 [sub_bag_begin]/[sub_bag_end],
/// 旧代订阅整袋退订(见 bind_node)。
pub fn[T] Signal::subscribe(self : Signal[T], f : (T) -> Unit) -> Int {
  let sid = sig_fresh_sub_id()
  self.node.subs.push((sid, fn() { f(self.get()) }))
  sub_bag_register(fn() { self.remove(sid) })
  sid
}

///|
/// 当前订阅条数。组件层的「不随重挂堆积死订阅」这类回归要有可观测的量,
/// 否则只能靠人肉数回调次数。
pub fn[T] Signal::sub_count(self : Signal[T]) -> Int {
  self.node.subs.length()
}

///|
/// 退订:摘除 subscribe 返回的 id 对应的回调(幂等,其余订阅不受
/// 影响;已随视图销毁的订阅应及时退订,否则主题/Signal 变更时仍
/// 会对死视图空跑)。
pub fn[T] Signal::remove(self : Signal[T], sid : Int) -> Unit {
  self.node.subs = self.node.subs.filter(fn(e) { e.0 != sid })
}

///|
/// 派生只读信号(等价 computed 闭包里只读一个源):源变化自动跟随。
pub fn[A, B] Signal::map(self : Signal[A], f : (A) -> B) -> Signal[B] {
  Signal::computed(fn() { f(self.get()) })
}

///|
/// 视图转换:以 Store 形态使用同一信号(共享值与订阅)。组件 API 的
/// Store 参数传 computed 信号时为只读语义,组件不应回写。
pub fn[T] Signal::store(self : Signal[T]) -> Store[T] {
  { sig: self, }
}

