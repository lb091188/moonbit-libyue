// 锁屏状态机测试(whitebox:直接操纵包内全局,先记旧值后还原)。

///|
test "lock_transition:同态重复不重发,翻转才派发" {
  let n = Ref(0)
  let last = Ref("")
  let old_cbs = g_lock_cbs
  let old_state = g_lock_state.val
  g_lock_cbs.clear()
  g_lock_cbs.push(fn(e) {
    n.val = n.val + 1
    last.val = e.to_string()
  })
  g_lock_state.val = None
  lock_transition(true)
  lock_transition(true) // 同态:不派发
  lock_transition(false)
  lock_transition(false) // 同态:不派发
  inspect(n.val.to_string(), content="2")
  inspect(last.val, content="SessionLockEvent::Unlocked")
  g_lock_cbs.clear()
  for cb in old_cbs {
    g_lock_cbs.push(cb)
  }
  g_lock_state.val = old_state
}
