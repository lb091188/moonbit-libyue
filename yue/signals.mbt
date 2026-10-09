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
fn sub_bag_register(off : () -> Unit) -> Unit {
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

///|
/// 声明式文本绑定(信号版):节点挂载时创建 Label(初值 f(get))并
/// 订阅,之后信号变化自动更新文本。与 bind_label(Store) 同一实现内核,
/// 接受源信号或 computed 派生信号。
pub fn[A] bind(
  sig : Signal[A],
  f : (A) -> String,
  style? : Array[(String, &StyVal)] = [],
) -> Node {
  bind_label({ sig, }, f, style~)
}

///|
/// 声明式节点绑定:信号变化时把容器内容重挂为 f(新值) 的节点。
/// 每次变化重建整棵子树,适合低频切换(如随状态换图标/换整块视图);
/// 高频更新请改用 bind 文本绑定或经 handle 命令式改属性。Store 传
/// store.signal() 接入。
/// ⚠ Windows:重挂的 remove+add 真机实证会令后续鼠标 hit-test 异常
/// (全窗点击被路由给重挂过的控件,推迟重挂也躲不开,见
/// adaptation.md),点击链路会重挂自身的场景请改「预建 + set_visible
/// 显隐切换」规避;libyue 层根修前此限制不解除。
pub fn[T] bind_node(sig : Signal[T], f : (T) -> Node) -> Node {
  {
    mount: fn(parent) {
      let c = Container::new()
      let current : Ref[View?] = Ref(None)
      // 本代子树的订阅退订闭包(重建前整袋退订:旧子树连同它订阅的
      // Store/主题回调一起退场,不随重建次数累积死订阅)
      let gen : Ref[Array[() -> Unit]] = Ref([])
      fn rebuild(v : T) -> Unit {
        sub_bag_discard(gen.val)
        match current.val {
          Some(old) => ignore(Container::remove_child_view(c, old))
          None => ()
        }
        sub_bag_begin()
        let node = f(v)
        current.val = Some((node.mount)(ViewLike::view(c)))
        gen.val = sub_bag_end()
        // Windows:运行期 remove+add 后 yoga 根不重算(native 只修被清零
        // 节点自身,见 view.mbt 的 refresh_layout 注释),新挂子树 bounds
        // 停在脏值,鼠标 hit-test 恒命中它——点击窗口任意处都误触重挂
        // 前的控件(真机实测:深浅切换按钮重挂后,全窗点击都变成切换
        // 明暗,键盘焦点路径不受影响)。重挂后整窗布局重算+重绘兜底,
        // 与 tabs 切页同款;Linux 的 GTK 布局自动覆盖新子树,无需此步
        if platform() == "windows" {
          refresh_layout(c)
        }
      }

      rebuild(sig.get())
      // Windows:信号更新触发的重挂整体推迟一拍——在点击回调栈内
      // remove+add 正被事件分发的控件(被点按钮自身在 bind_node 子树内
      // 的场景),Windows 的事件分发状态会永久错乱,真机探针实测点一次
      // 后全窗点击失效且不可逆;脱离触发上下文后重挂无害(点击子树外
      // 按钮触发别的 bind_node 重挂,同栈内执行也正常,同为探针实证)。
      // Linux 的 GTK 布局同步安全,保持即时重挂
      if platform() == "windows" {
        ignore(sig.subscribe(fn(v) { post_task(fn() { rebuild(v) }) }))
      } else {
        ignore(sig.subscribe(fn(v) { rebuild(v) }))
      }
      attach(parent, ViewLike::view(c))
      ViewLike::view(c)
    },
  }
}

///|
/// 两态切换:预建 a/b 两棵节点,信号值选显隐(不销毁不重建 view)。
/// bind_node 的 Windows 安全替代——重挂的 remove+add 在 Windows 上
/// 会令鼠标命中测试错乱(见 bind_node 警示),显隐走 display:none
/// (fork 补丁维护路径)无此患;代价是两棵子树常驻(低频切换场景可
/// 忽略)。典型如随深浅换太阳/月亮图标按钮:
///
/// ```moonbit nocheck
/// @yue.swap_node(dark.signal(),
///   @icons.icon_button_t(@icons.Moon, on_click=..., tip="切换到深色"),
///   @icons.icon_button_t(@icons.Sunny, on_click=..., tip="切换到浅色"))
/// ```
pub fn swap_node(sig : Signal[Bool], a : Node, b : Node) -> Node {
  {
    mount: fn(parent) {
      let va = (a.mount)(parent)
      let vb = (b.mount)(parent)
      fn apply(v : Bool) -> Unit {
        set_visible_view(va, !v)
        set_visible_view(vb, v)
      }

      apply(sig.get())
      ignore(sig.subscribe(apply))
      ignore(parent)
      va
    },
  }
}
