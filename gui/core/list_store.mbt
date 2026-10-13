// L3 响应式层的通用列表容器（design.md §3 第 1 项）：在 `Store[Array[T]]` 之上
// 补 keyed 差分——「改一条只重挂一条」的地基，`for_list`（§3 第 4 项）直接吃它。
//
// 三条口径：
// - 数据面就是普通 `Store[Array[T]]`（§3「没有字符串路径」），增删改只写 Store，
//   差分、显隐、合并重绘全是上层入口的事；
// - `key` 提取器给不出（同 key 重复）按新番输旧番——与 Vue 的 duplicate key 同义，
//   不报错、不吞项；不给 `key` 时按下标对齐（等价无 `:key`），只报「长度收缩」；
// - 通知随订阅回收袋退订（`sub_bag_*`），换一代列表不留死订阅。

///|
/// 通用列表容器：内部就是一个 `Store[Array[T]]`（`signal()` 可拿去 `computed` 派生）。
pub struct ListStore[T] {
  store : Store[Array[T]]
}

///|
pub fn[T] ListStore::new(init~ : Array[T] = []) -> ListStore[T] {
  { store: Store::new(init) }
}

///|
/// 列表元素示例类型（测试与最小示例用；真实项目自带记录类型即可）。
pub(all) struct Item {
  id : Int
  name : String
}


///|
/// 读当前列表（快照副本，外部改不回填）。
pub fn[T] ListStore::get(self : ListStore[T]) -> Array[T] {
  self.store.get()
}

///|
pub fn[T] ListStore::length(self : ListStore[T]) -> Int {
  self.store.get().length()
}

///|
/// 追加一条。
pub fn[T] ListStore::push(self : ListStore[T], item : T) -> Unit {
  self.store.update_always(fn(ts) { [..ts, item] })
}

///|
/// 按谓词删（第一条命中即删，删的是「谁满足谓词」而不是「第几个」）。
pub fn[T] ListStore::remove(self : ListStore[T], pred : (T) -> Bool) -> Bool {
  let mut hit = false
  self.store.update_always(fn(ts) {
    let out : Array[T] = []
    let mut skipped = false
    for t in ts {
      if !skipped && pred(t) {
        skipped = true
        hit = true
      } else {
        out.push(t)
      }
    }
    out
  })
  hit
}

///|
/// 按谓词定位并改写（回调拿到旧值，返回新值；没命中什么都不发生）。
pub fn[T] ListStore::update(self : ListStore[T], pred : (T) -> Bool, f : (T) -> T) -> Bool {
  let mut hit = false
  self.store.update_always(fn(ts) {
    let out : Array[T] = []
    for t in ts {
      if !hit && pred(t) {
        hit = true
        out.push(f(t))
      } else {
        out.push(t)
      }
    }
    out
  })
  hit
}

///|
/// 区间替换：从 `at` 起删 `del` 条、插入 `items`（`at` 越界钳到端点；`del` 按剩余量截断）。
pub fn[T] ListStore::splice(self : ListStore[T], at : Int, del : Int, items : Array[T]) -> Unit {
  self.store.update_always(fn(ts) {
    let n = ts.length()
    let mut start = at
    if start < 0 {
      start = 0
    }
    if start > n {
      start = n
    }
    let mut d = del
    if d < 0 {
      d = 0
    }
    if d > n - start {
      d = n - start
    }
    let out : Array[T] = []
    for i in 0..<start {
      out.push(ts[i])
    }
    for x in items {
      out.push(x)
    }
    for i in (start + d)..<n {
      out.push(ts[i])
    }
    out
  })
}

///|
/// 以 Store/Signal 形态共用同一份列表（computed 派生、batch 合并都照旧）。
pub fn[T] ListStore::signal(self : ListStore[T]) -> Signal[Array[T]] {
  self.store.signal()
}

///|
/// keyed 差分的账表：四张表都按新表下标定位（`kept`/`added` 带落位下标）。
pub(all) struct KeyDiff[T] {
  /// 上一代有、这一代没有——要卸载
  removed : Array[T]
  /// 两代都有但内容变了——要就地刷新
  changed : Array[(T, T)]
  /// 这一代新增（带落位下标）——要挂载
  added : Array[(Int, T)]
  /// 两代都有（带新落位下标）——绘制层序按它摆
  kept : Array[(Int, T)]
}

///|
/// 纯函数差分：旧表按 key 建索引，新表逐条判「有没有/变没变」；
/// `changed` 与 `kept` 同条（变了的两份都给出）。同 key 重复按新番输旧番。
pub fn[T, K : Eq] keyed_diff(
  old : Array[T],
  new : Array[T],
  key : (T) -> K,
  eq : (T, T) -> Bool,
) -> KeyDiff[T] {
  let removed : Array[T] = []
  // 旧表索引（键值对数组，线性找）：key 只要求 Eq，不把 Hash 绑进公共签名
  let old_index : Array[(K, T)] = []
  for t in old {
    // 重复 key：后写的旧番覆盖先写（语义同 Vue：duplicate key 以新为准）
    let k = key(t)
    let mut placed = false
    for j in 0..<old_index.length() {
      if old_index[j].0 == k {
        old_index[j] = (k, t)
        placed = true
      }
    }
    if !placed {
      let _ = old_index.push((k, t))
    }
  }
  let changed : Array[(T, T)] = []
  let added : Array[(Int, T)] = []
  let kept : Array[(Int, T)] = []
  let seen : Array[K] = []
  for i in 0..<new.length() {
    let t = new[i]
    let k = key(t)
    if seen.contains(k) {
      // 同 key 第二条：直接当新增（按下标落位），不去搅第一条的账
      let _ = added.push((i, t))
      continue
    }
    let _ = seen.push(k)
    let mut found : T? = None
    for pair in old_index {
      if pair.0 == k {
        found = Some(pair.1)
      }
    }
    match found {
      None => {
        let _ = added.push((i, t))
      }
      Some(prev) => {
        let _ = kept.push((i, t))
        if !eq(prev, t) {
          let _ = changed.push((prev, t))
        }
      }
    }
  }
  for t in old {
    if !seen.contains(key(t)) {
      let _ = removed.push(t)
    }
  }
  { removed, changed, added, kept }
}

///|
/// 按下标对齐的差分（不给 key 的场合，等价 Vue 无 `:key`）：只报「长度收缩」的
/// removed 与「内容替换」的 changed/added，顺序敏感。
pub fn[T] index_diff(old : Array[T], new : Array[T], eq : (T, T) -> Bool) -> KeyDiff[T] {
  let removed : Array[T] = []
  let changed : Array[(T, T)] = []
  let added : Array[(Int, T)] = []
  let kept : Array[(Int, T)] = []
  let n = old.length().min(new.length())
  for i in 0..<n {
    let _ = kept.push((i, new[i]))
    if !eq(old[i], new[i]) {
      let _ = changed.push((old[i], new[i]))
    }
  }
  for i in n..<new.length() {
    let _ = added.push((i, new[i]))
  }
  for i in n..<old.length() {
    let _ = removed.push(old[i])
  }
  { removed, changed, added, kept }
}

///|
/// 订阅列表变化并拿 keyed 差分：每次通知给一份 `(旧表, 新表, 差分)`，
/// 订阅闭包经 `sub_bag_register` 进当前回收袋（换代整袋退订，不留死订阅）。
/// 退订句柄同时返回，便于不用回收袋的场合手动 `Store::remove`。
pub fn[T, K : Eq] ListStore::subscribe_diff(
  self : ListStore[T],
  key : (T) -> K,
  eq : (T, T) -> Bool,
  on_diff : (Array[T], Array[T], KeyDiff[T]) -> Unit,
) -> Int {
  let mut prev = self.store.get()
  let id = self.store.subscribe_id(fn(next : Array[T]) -> Unit {
    let d = keyed_diff(prev, next, key, eq)
    prev = next
    on_diff(prev, next, d)
  })
  sub_bag_register(fn() -> Unit { self.store.remove(id) })
  id
}
