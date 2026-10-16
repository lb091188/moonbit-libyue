// G9 Batch 2 过渡兼容层：base（响应式内核/焦点栈/记账基元）已出成独立子包，
// 本文件把原先住在 core 的公开名转发一层，让 `@core.*` 调用点在迁移期不改写。
// 全量替换 `@core.Signal` → `@base.Signal` 等完成后整文件删除（TODO §1 G9）。

///|
pub type Signal[T] = @base.Signal[T]

///|
pub type Store[T] = @base.Store[T]

///|
pub type ListStore[T] = @base.ListStore[T]

///|
pub type Item = @base.Item

///|
pub type KeyDiff[T] = @base.KeyDiff[T]

///|
pub type FocusStack = @base.FocusStack
pub type Rect = @base.Rect

///|
pub fn batch(f : () -> Unit) -> Unit {
  @base.batch(f)
}

///|
pub fn[T] watch(
  src : Signal[T],
  on_change : (T, T) -> Unit,
  immediate? : Bool = false,
) -> () -> Unit {
  @base.watch(src, on_change, immediate=immediate)
}

///|
pub fn[T] watch_store(
  src : Store[T],
  on_change : (T, T) -> Unit,
) -> () -> Unit {
  @base.watch_store(src, on_change)
}

///|
pub fn[T] index_diff(
  old : Array[T],
  new : Array[T],
  eq : (T, T) -> Bool,
) -> KeyDiff[T] {
  @base.index_diff(old, new, eq)
}

///|
pub fn[T] index_same(a : T, b : T) -> Bool {
  @base.index_same(a, b)
}

///|
pub fn[T, K : Eq] keyed_diff(
  old : Array[T],
  new : Array[T],
  key : (T) -> K,
  eq : (T, T) -> Bool,
) -> KeyDiff[T] {
  @base.keyed_diff(old, new, key, eq)
}

///|
pub fn[T, K : Eq] keyed_align(
  old_items : Array[T],
  new_items : Array[T],
  key : (T) -> K,
  eq : (T, T) -> Bool,
) -> KeyDiff[T] {
  @base.keyed_align(old_items, new_items, key, eq)
}

///|
pub fn next_tick(f : () -> Unit) -> Unit {
  @base.next_tick(f)
}

///|
pub fn tick_pending() -> Int {
  @base.tick_pending()
}

///|
pub fn tick_flush() -> Unit {
  @base.tick_flush()
}

///|
pub fn tick_clear() -> Unit {
  @base.tick_clear()
}

///|
pub fn prof_record(
  layout_ms : Int64,
  paint_ms : Int64,
  present_ms : Int64,
  total_ms : Int64,
) -> Unit {
  @base.prof_record(layout_ms, paint_ms, present_ms, total_ms)
}

///|
pub fn paint_profile_reset() -> Unit {
  @base.paint_profile_reset()
}

///|
pub fn paint_profile_summary() -> String {
  @base.paint_profile_summary()
}

///|
pub fn keysym_is_printable(ks : Int) -> Bool {
  @base.keysym_is_printable(ks)
}

///|
pub fn sub_bag_register(off : () -> Unit) -> Unit {
  @base.sub_bag_register(off)
}

///|
pub fn sub_bag_begin() -> Unit {
  @base.sub_bag_begin()
}

///|
pub fn sub_bag_end() -> Array[() -> Unit] {
  @base.sub_bag_end()
}

///|
pub fn sub_bag_discard(offs : Array[() -> Unit]) -> Unit {
  @base.sub_bag_discard(offs)
}

///|
pub const MOD_SHIFT : Int = @base.MOD_SHIFT
pub const MOD_CTRL : Int = @base.MOD_CTRL
pub const MOD_ALT : Int = @base.MOD_ALT
pub const MOD_META : Int = @base.MOD_META

///|
pub const KS_BACKSPACE : Int = @base.KS_BACKSPACE
pub const KS_TAB : Int = @base.KS_TAB
pub const KS_SPACE : Int = @base.KS_SPACE
pub const KS_RETURN : Int = @base.KS_RETURN
pub const KS_ESCAPE : Int = @base.KS_ESCAPE
pub const KS_LEFT : Int = @base.KS_LEFT
pub const KS_UP : Int = @base.KS_UP
pub const KS_RIGHT : Int = @base.KS_RIGHT
pub const KS_DOWN : Int = @base.KS_DOWN
pub const KS_HOME : Int = @base.KS_HOME
pub const KS_END : Int = @base.KS_END
pub const KS_DELETE : Int = @base.KS_DELETE
pub const KS_ISO_LEFT_TAB : Int = @base.KS_ISO_LEFT_TAB
