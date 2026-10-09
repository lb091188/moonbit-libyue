// L3 响应式层:Store(可订阅的值)+ bind_label。
// Store 是信号内核的 Store 形态视图:可写源 + 组件 API 的既有参数类型;
// 派生/自动依赖收集用 Signal(signals.mbt),两者经 Signal::store /
// Store::signal 零成本互转。订阅闭包由信号内核持有(纯 MoonBit 侧引用,
// 无需 FFI 保活);常规订阅随应用存活,组件随子视图销毁时经
// Store::remove / 订阅回收袋(sub_bag_*)退订,不留下死订阅。

///|
/// 可订阅的值。set 时通知全部订阅者(快照遍历,订阅者里再 set 安全,
/// 但注意别写成无限递归)。
pub struct Store[T] {
  sig : Signal[T]
}

///|
pub fn[T] Store::new(value : T) -> Store[T] {
  { sig: Signal::new(value), }
}

///|
/// 读当前值。
pub fn[T] Store::get(self : Store[T]) -> T {
  self.sig.get()
}

///|
/// 写新值并通知订阅者(不去重:相同值也会通知)。
pub fn[T] Store::set(self : Store[T], value : T) -> Unit {
  self.sig.set(value)
}

///|
/// 用函数更新:set(f(get()))。
pub fn[T] Store::update(self : Store[T], f : (T) -> T) -> Unit {
  self.sig.update(f)
}

///|
/// 订阅变化。注册时不回调(初始值请直接 get)。常规订阅随应用存活;
/// 组件随子视图一起销毁时(重建式组件换行、bind_node 重挂)应改经
/// [Store::subscribe_id] 取句柄后退订,或把挂载包进订阅回收袋
/// ([sub_bag_begin]/[sub_bag_end])整代一次性退订。
pub fn[T] Store::subscribe(self : Store[T], f : (T) -> Unit) -> Unit {
  ignore(self.sig.subscribe(f))
}

///|
/// 订阅变化并返回退订句柄(订阅注册表 id):经 [Store::remove] 按
/// 句柄摘除。与 [Store::subscribe] 同一注册表,区别只在句柄可退订。
pub fn[T] Store::subscribe_id(self : Store[T], f : (T) -> Unit) -> Int {
  self.sig.subscribe(f)
}

///|
/// 退订:摘除 [Store::subscribe_id](或 store.signal().subscribe)返回的
/// 句柄对应的订阅(幂等,未知句柄空操作)。已随视图销毁的订阅应及时
/// 退订,否则变更通知仍会对死视图空跑、无界累积。
pub fn[T] Store::remove(self : Store[T], handle : Int) -> Unit {
  self.sig.remove(handle)
}

///|
/// 派生只读 Store:源 set 时自动跟随。适合"状态 → 显示文本"这类映射。
pub fn[A, B] Store::map(self : Store[A], f : (A) -> B) -> Store[B] {
  self.sig.map(f).store()
}

///|
/// 以 Signal 形态使用同一状态(共享值与订阅):可用 computed 派生、
/// batch 批处理等信号能力。
pub fn[T] Store::signal(self : Store[T]) -> Signal[T] {
  self.sig
}

///|
/// 声明式文本绑定:节点挂载时创建 Label(初值 f(get))并订阅,
/// 之后每次 set 自动更新文本。Store[A] 通常来自 map 派生。
/// 文本恒单行:默认富文本自动换行,在 hbox 里剩余宽度不足时回显会被
/// 压成两行;这里替换为 wrap=false 的富文本(之后的 set_text 仍在
/// 同一富文本上改写,单行测宽持续生效),并显式钉主题常规文字色
/// (富文本路径不走系统文字色)。
/// 标签宽度跟随文本:set_text 后强制重排一次,变长/变短即时生效
/// (不补则停在挂载时的宽度,长文本截断,详见 adaptation.md)。
pub fn[A] bind_label(
  store : Store[A],
  f : (A) -> String,
  style? : Array[(String, &StyVal)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let init = f(store.get())
      let l = Label::make(init, style~)
      let at = AttributedText::new(init, valign=Center, wrap=false)
      at.set_font(Font::new("Sans", 13.0))
      fn apply_color() -> Unit {
        at.set_color(theme_text_regular())
        at.set_text(at.get_text())
        ViewLike::schedule_paint(l)
      }

      apply_color()
      ignore(on_theme_change(apply_color))
      l.set_attributed_text(at)
      // set_text 只标脏 yoga + 按旧尺寸重绘,不触发布局下发(标签宽度
      // 不会跟随文本变化,变长即截断),须补一次强制重排
      store.subscribe(fn(v) {
        l.set_text(f(v))
        ViewLike::update_layout(l)
      })
      attach(parent, ViewLike::view(l))
      ViewLike::view(l)
    },
  }
}
