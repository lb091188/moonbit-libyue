// L3 响应式层第二形态:Signal(自动依赖收集的信号)。
// 与 Store 的分工:
//   Store  = 可写源 + 组件 API 的既有参数类型(select_t/slider_t 等),
//            手动 get/set/subscribe;
//   Signal = 源 + computed(求值期自动收集读到的信号为依赖,依赖变化
//            自动失效、读取时重算),派生关系免手动接线。
// 两者共享同一信号内核,可零成本互转(Signal::store / Store::signal)。
// 批处理:同一事件回调里多次 set,用 batch(fn(){...}) 包裹,订阅者只在
// 出 batch 时收到一次通知。

///|
/// 信号内核(非泛型):脏标记 + 订阅/依赖关系。泛型壳(Signal[T])
/// 持有值与计算函数;id 用于关系数组里的身份比较。
struct SigNode {
  id : Int
  mut dirty : Bool
  mut queued : Bool
  subs : Array[() -> Unit]
  mut deps : Array[SigNode]
  mut observers : Array[SigNode]
}

///|
let sig_next_id : Ref[Int] = Ref(0)

///|
let sig_batch_depth : Ref[Int] = Ref(0)

///|
let sig_pending : Ref[Array[SigNode]] = Ref([])

///|
/// 依赖收集上下文:Some((正在重算的 computed 节点, 收集缓冲))。
let sig_collector : Ref[(SigNode, Array[SigNode])?] = Ref(None)

///|
fn sig_fresh_id() -> Int {
  sig_next_id.val += 1
  sig_next_id.val
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
  for f in snapshot {
    f()
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
/// 订阅变化,回调收到最新值。注册时不回调(初值请直接 get);暂无退订,
/// 订阅默认存活整个应用期。
pub fn[T] Signal::subscribe(self : Signal[T], f : (T) -> Unit) -> Unit {
  self.node.subs.push(fn() { f(self.get()) })
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
  { sig: self }
}

///|
/// 声明式文本绑定(信号版):节点挂载时创建 Label(初值 f(get))并
/// 订阅,之后信号变化自动更新文本。与 bind_label(Store) 同一实现内核,
/// 接受源信号或 computed 派生信号。
pub fn[A] bind(
  sig : Signal[A],
  f : (A) -> String,
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  bind_label({ sig }, f, style~, style_str~)
}
