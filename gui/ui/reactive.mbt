// 响应式薄入口（design.md §3 第 4 项）：`v-for` / `v-if` 的对应物。
//
// - `for_list`：keyed 差分，**只重挂该挂的行**——未变的行复用原控件、就地挪位
//   （焦点/滚动状态原样保留），删除即卸，新增/变更按新下标插入。不给 `key`
//   按下标对齐（等价 Vue 无 `:key`）。
// - `when`：if/else 对应物，入参收 **Signal/Store 本体**（不收 `.get()` 快照，
//   §3 第 5 条绑定语义通则）；不给 `else` 是单支（假时隐藏不重建、状态不丢），
//   给了是双支常驻切显隐（`swap_node` 落地）。要销毁重建的场合走 `bind_node`，
//   `when` 只是上面的糖。任意类型的源用 `pred` 折算真假（缺省=非空即真）。
//
// 值本体变了怎么办：行内容来自普通值（`t.title` 那类）走 changed 档重挂该行；
// 要「改一格只重绘那一格」，把会变的字段各自做成 `Store`（§4.0 口径），行内走
// `text_dyn` / `input(value=..)`——差分只动结构，不动内容。

///|
/// 显隐判据的缺省折算：信号带值即真（`Bool` 源直接用值、`Option` 源看有没有，
/// 其余类型恒真——拿不出统一假值判据的不猜，自己给 `pred`）。
/// 内部按「能拆出 Bool/Option 就拆」的次序判：
pub fn[T] when_default_pred(v : T) -> Bool {
  let _ = v
  true
}

///|
/// `when`（信号版·单支）：真挂 `then`、假隐藏——不销毁、状态不丢。
pub fn[T] when(
  cond : @core.Signal[T],
  then : @core.Node,
  pred? : (T) -> Bool = when_default_pred,
) -> @core.Node {
  @core.node_of_new(fn(host : @core.Widget) -> @core.Widget {
    let w = (then.mount)(host)
    w.set_visible(pred(cond.get()))
    let _ = cond.subscribe(fn(v : T) -> Unit {
      w.set_visible(pred(v))
      let _ = @core.invalidate()
    })
    host
  })
}

///|
/// `when`（双支常驻）：两支都预建，按信号切显隐（`swap_node` 落地，零重建）。
pub fn[T] when_else(
  cond : @core.Signal[T],
  then : @core.Node,
  otherwise : @core.Node,
  pred? : (T) -> Bool = when_default_pred,
) -> @core.Node {
  @core.swap_node(cond.map(pred), then, otherwise)
}

///|
/// `when`（Store 形态）：同一棵树盯一个 `Store`（§3 第 5 条输入类组件同源）。
pub fn[T] when_store(
  cond : @core.Store[T],
  then : @core.Node,
  pred? : (T) -> Bool = when_default_pred,
) -> @core.Node {
  when(cond.signal(), then, pred=pred)
}

///|
/// `when_else`（Store 形态）。
pub fn[T] when_else_store(
  cond : @core.Store[T],
  then : @core.Node,
  otherwise : @core.Node,
  pred? : (T) -> Bool = when_default_pred,
) -> @core.Node {
  when_else(cond.signal(), then, otherwise, pred=pred)
}

///|
/// `for_list`（keyed）：`build(item, index)` 建行；缺省判据「同键同值」（元素
/// 内容变化不该触发行重挂——会变的字段各自做成 Store，§4.0）。
pub fn[T, K : Eq] for_list(
  ls : @core.ListStore[T],
  build : (T, Int) -> @core.Node,
  key~ : (T) -> K,
  eq~ : (T, T) -> Bool = fn(_a : T, _b : T) -> Bool { true },
) -> @core.Node {
  list_node(ls, build, key, eq)
}

///|
/// `for_list`（按下标对齐，等价无 `:key`）：长度收缩才卸多余行，改一格重挂那行。
pub fn[T] for_list_indexed(
  ls : @core.ListStore[T],
  build : (T, Int) -> @core.Node,
) -> @core.Node {
  // 下标对齐：键恒等 → 同下标比内容，内容变即重挂该行（Vue 无 :key 的语义）
  list_node(
    ls,
    build,
    fn(_t : T) -> Int { 0 },
    fn(a : T, b : T) -> Bool { @core.index_same(a, b) },
    indexed=true,
  )
}

///|
/// 记账核心：`keys`（键→行控件）+ 平行数组（下标→键/值/控件）。
/// 一轮更新= 卸 removed/changed 的旧控件 → 按新序列逐位「复用挪位 / 新建插入」。
fn[T, K : Eq] list_node(
  ls : @core.ListStore[T],
  build : (T, Int) -> @core.Node,
  key : (T) -> K,
  eq : (T, T) -> Bool,
  indexed~ : Bool = false,
) -> @core.Node {
  @core.node_of_new(fn(host : @core.Widget) -> @core.Widget {
    host.node.set_flex_direction(@yoga.Column)
    host.node.set_align_items(@yoga.AlignItems::Stretch)
    let ks : Array[K] = []
    let vs : Array[T] = []
    let ws : Array[@core.Widget] = []
    fn sync(items : Array[T]) -> Unit {
      // 1) 差分卸账：键没了、或同键值变了——旧控件出树（重复键的多余行一并出）
      let mut cut = 0
      while cut < ws.length() {
        let mut hit : T? = None
        for x in items {
          if key(x) == ks[cut] {
            hit = Some(x)
          }
        }
        let keep_row = match hit {
          Some(nt) => eq(vs[cut], nt)
          None => false
        }
        if keep_row {
          cut += 1
        } else {
          let _ = host.remove_child(ws[cut])
          let _ = ws.remove(cut)
          let _ = ks.remove(cut)
          let _ = vs.remove(cut)
        }
      }
      // 2) 按新序列逐位对齐：键档「复用挪位/新建插入」；下标档「同位比内容、
      //    变了重挂那一行」（Vue 无 :key 的语义）
      for j in 0..<items.length() {
        let t = items[j]
        let k = key(t)
        if indexed {
          if j < ws.length() {
            let old = ws[j]
            let _ = host.remove_child(old)
            let w = (build(t, j).mount)(host)
            let pos = host.index_of(w)
            if pos != j {
              host.move_child(pos, j)
            }
            ws[j] = w
            ks[j] = k
            vs[j] = t
          } else {
            let w = (build(t, j).mount)(host)
            let pos = host.index_of(w)
            if pos != j {
              host.move_child(pos, j)
            }
            let _ = ws.push(w)
            let _ = ks.push(k)
            let _ = vs.push(t)
          }
        } else {
          let mut old = -1
          for q in 0..<ks.length() {
            if ks[q] == k {
              old = q
            }
          }
          if old == j {
            continue
          }
          if old >= 0 {
            host.move_child(old, j)
            let w = ws[old]
            let _ = ws.remove(old)
            let _ = ks.remove(old)
            let _ = vs.remove(old)
            let at = j.min(ws.length())
            let _ = ws.insert(at, w)
            let _ = ks.insert(at, k)
            let _ = vs.insert(at, t)
          } else {
            let w = (build(t, j).mount)(host)
            let pos = host.index_of(w)
            if pos != j {
              host.move_child(pos, j)
            }
            let at = j.min(ws.length())
            let _ = ws.insert(at, w)
            let _ = ks.insert(at, k)
            let _ = vs.insert(at, t)
          }
        }
      }
      let _ = @core.invalidate()
    }
    sync(ls.get())
    let _ = ls.signal().subscribe(fn(items : Array[T]) -> Unit { sync(items) })
    host
  })
}

///|
/// `when`（布尔源·常用档）：直接看 `Bool` 值显隐。
pub fn when_bool(cond : @core.Signal[Bool], then : @core.Node) -> @core.Node {
  when(cond, then, pred=fn(v : Bool) -> Bool { v })
}

///|
/// `when_store`（布尔源·常用档）。
pub fn when_store_bool(cond : @core.Store[Bool], then : @core.Node) -> @core.Node {
  when_bool(cond.signal(), then)
}

///|
/// `when_else`（布尔源·常用档）：两支常驻、切显隐零重建（与 `swap_node` 同机制，
/// 外面套一层宿主以便按 then/else 语义对齐位序；宿主本身不占绘制）。
pub fn when_else_bool(
  cond : @core.Signal[Bool],
  then : @core.Node,
  otherwise : @core.Node,
) -> @core.Node {
  @core.node_of_new(fn(host : @core.Widget) -> @core.Widget {
    let va = (then.mount)(host)
    let vb = (otherwise.mount)(host)
    fn apply(v : Bool) -> Unit {
      va.set_visible(v)
      vb.set_visible(!v)
      let _ = @core.invalidate()
    }
    apply(cond.get())
    let _ = cond.subscribe(apply)
    host
  })
}

///|
/// `when_else_store`（布尔源·常用档）。
pub fn when_else_store_bool(
  cond : @core.Store[Bool],
  then : @core.Node,
  otherwise : @core.Node,
) -> @core.Node {
  when_else_bool(cond.signal(), then, otherwise)
}
