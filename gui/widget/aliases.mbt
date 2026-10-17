// 包内别名与裸名转发（G9 Batch 2）：base/shell 提层后，widget 各文件的书写
// 形态保持原样。只在本包可见。

///|
pub type Rect = @base.Rect
pub type FocusStack = @base.FocusStack
pub type Signal[T] = @base.Signal[T]
pub type Store[T] = @base.Store[T]
pub type ListStore[T] = @base.ListStore[T]
pub type KeyDiff[T] = @base.KeyDiff[T]
pub type Item = @base.Item
pub type Loop = @shell.Loop
pub type Session = @shell.Session

///|
const MOD_SHIFT : Int = @base.MOD_SHIFT
const MOD_CTRL : Int = @base.MOD_CTRL
const MOD_ALT : Int = @base.MOD_ALT
const MOD_META : Int = @base.MOD_META
const KS_BACKSPACE : Int = @base.KS_BACKSPACE
const KS_TAB : Int = @base.KS_TAB
const KS_RETURN : Int = @base.KS_RETURN
const KS_ESCAPE : Int = @base.KS_ESCAPE
const KS_LEFT : Int = @base.KS_LEFT
const KS_UP : Int = @base.KS_UP
const KS_RIGHT : Int = @base.KS_RIGHT
const KS_DOWN : Int = @base.KS_DOWN
const KS_HOME : Int = @base.KS_HOME
const KS_END : Int = @base.KS_END
const KS_DELETE : Int = @base.KS_DELETE
const KS_ISO_LEFT_TAB : Int = @base.KS_ISO_LEFT_TAB

///|
fn host_loop() -> Loop { @shell.host_loop() }
fn host_mark_active(s : Session) -> Unit { @shell.host_mark_active(s) }
fn host_deregister(s : Session) -> Unit { @shell.host_deregister(s) }
fn host_window_count() -> Int { @shell.host_window_count() }
fn host_close_action(primary : Bool, remaining : Int) -> Bool {
  @shell.host_close_action(primary, remaining)
}
fn keysym_is_printable(ks : Int) -> Bool { @base.keysym_is_printable(ks) }
fn prof_record(a : Int64, b : Int64, c : Int64, d : Int64) -> Unit {
  @base.prof_record(a, b, c, d)
}
fn set_timer_hooks(sched : (Int, () -> Unit) -> Int, cancel : (Int) -> Unit) -> Unit {
  @shell.set_timer_hooks(sched, cancel)
}
fn sub_bag_begin() -> Unit { @base.sub_bag_begin() }
fn sub_bag_end() -> Array[() -> Unit] { @base.sub_bag_end() }
fn sub_bag_discard(offs : Array[() -> Unit]) -> Unit { @base.sub_bag_discard(offs) }
fn tick_flush() -> Unit { @base.tick_flush() }
