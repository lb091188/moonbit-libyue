// `next_tick`：事件回调里「等这一批数据落定再做事」的排队通道（design.md §3
// 第 3 项的 nextTick 对应物）。
//
// 帧末合并口径（同条第 3 项）：**同一事件回调内合并、回调尾同步 flush**——
// 跨拍队列会让反馈晚一帧。宿主 `App::step` 在「事件排空之后、绘制之前」冲刷
// 一次；应用里读到的画面与数据永远同拍。布局与重绘本来就按帧合并
// （`invalidate` 只置脏，`paint_frame` 一帧一次 relayout），多次 `set` 不会
// 重复布局/绘制——本模块补的是「把做事推迟到批尾」的显式入口。

///|
let tick_queue : Ref[Array[() -> Unit]] = Ref([])

///|
/// 排队一个回调到本批末尾（宿主在事件排空后、绘制前统一冲刷）。
/// 冲刷途中新 `next_tick` 的项进下一批，不会在本批里饿死或递归爆开。
pub fn next_tick(f : () -> Unit) -> Unit {
  let _ = tick_queue.val.push(f)
}

///|
/// 当前排队条数（测试与宿主观测用）。
pub fn tick_pending() -> Int {
  tick_queue.val.length()
}

///|
/// 冲刷一批：先取快照再跑，跑途中新排队的留给下一批。
pub fn tick_flush() -> Unit {
  let batch = tick_queue.val.copy()
  tick_queue.val = []
  for f in batch {
    f()
  }
}

///|
/// 丢掉全部排队回调（拆宿主/退出清理用，防跨应用实例残留）。
pub fn tick_clear() -> Unit {
  tick_queue.val = []
}
