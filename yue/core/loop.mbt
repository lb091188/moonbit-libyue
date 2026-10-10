// 循环与任务调度：循环归 MoonBit（不用 gtk_main），本包只回答「什么时候该干
// 什么」——平台泵（G2 的 yue/win）负责等事件、把单调时钟读数交给 `advance`，
// 并把 `wait_budget` 的返回值作为最长等待毫秒（None 表示可无限等，此时必须
// 靠跨线程唤醒位回来，漏唤醒即死锁，见 experiment/async-pump-research.md）。
//
// 三条纪律来自 libyue 实测坑：回调里不做重活（`post_task` 推迟一拍）、
// 定时器必须可取消（`cancel`，对象销毁后仍在飞的定时器会直接崩）、
// 退出走「先停派发、再拆对象」（`quit` 之后 `advance` 不再执行任何回调）。

///|
pub struct Job {
  id : Int
  due_ms : Int64
  seq : Int
  run : () -> Unit
}

///|
pub struct Loop {
  mut next_id : Int
  mut next_seq : Int
  mut last_now : Int64
  mut running : Bool
  jobs : Array[Job]
}

///|
pub fn Loop::new() -> Loop {
  // -1 = 时基未建立。平台时钟是 CLOCK_MONOTONIC（开机起算），若从 0 起算
  // 相对延时，首次 advance 前排的定时器会全部立刻到期（实测骨架动画只跑
  // 一拍就是这么来的），故必须由宿主先 start 一次。
  { next_id: 1, next_seq: 0, last_now: -1L, running: true, jobs: [] }
}

///|
/// 建立时基：传入平台单调时钟读数，必须在排任何定时器之前调用一次。
pub fn Loop::start(self : Loop, now_ms : Int64) -> Unit {
  if self.last_now < 0L {
    self.last_now = now_ms
  }
}

///|
/// 时基是否已建立。
pub fn Loop::started(self : Loop) -> Bool {
  self.last_now >= 0L
}

// 立即项恒早于任何定时器：due 取 -1，单调时钟读数总 >= 0。

///|
const IMMEDIATE : Int64 = -1L

///|
fn insert(jobs : Array[Job], job : Job) -> Unit {
  // 先到先跑，同刻按提交次序
  let mut at = jobs.length()
  let mut i = 0
  while i < jobs.length() {
    let other = jobs[i]
    let later = other.due_ms > job.due_ms ||
      (other.due_ms == job.due_ms && other.seq > job.seq)
    if later {
      at = i
      break
    }
    i = i + 1
  }
  jobs.insert(at, job)
}

///|
/// 推迟一拍执行。回调里的重活应先算完再排回来，别在派发栈上直接做。
pub fn Loop::post_task(self : Loop, work : () -> Unit) -> Unit {
  let js = self.jobs
  insert(js, { id: 0, due_ms: IMMEDIATE, seq: self.next_seq, run: work, })
  self.next_seq = self.next_seq + 1
}

///|
/// 延时任务（毫秒）。返回的 id 可用于 `cancel`，延时 0 与 `post_task` 同拍。
pub fn Loop::timer(self : Loop, delay_ms : Int, work : () -> Unit) -> Int {
  let delay = if delay_ms < 0 { 0 } else { delay_ms }
  let id = self.next_id
  self.next_id = self.next_id + 1
  let js = self.jobs
  // 未 start 时基准取 0（-1 只是「未建立」的哨兵，不参与运算）
  let base = if self.last_now < 0L { 0L } else { self.last_now }
  insert(js, {
    id,
    due_ms: base + delay.to_int64(),
    seq: self.next_seq,
    run: work,
  })
  self.next_seq = self.next_seq + 1
  id
}

///|
/// 取消尚未执行的定时器；已执行或不存在返回 false。
pub fn Loop::cancel(self : Loop, id : Int) -> Bool {
  let js = self.jobs
  let mut found = -1
  for i = 0; i < js.length(); i = i + 1 {
    if js[i].id == id {
      found = i
      break
    }
  }
  if found < 0 {
    false
  } else {
    let _ = js.remove(found)
    true
  }
}

///|
/// 待跑项还有多少（测试与诊断用）。
pub fn Loop::pending(self : Loop) -> Int {
  self.jobs.length()
}

///|
/// 跑完所有到期项，返回执行个数。`quit` 之后不做任何回调。
pub fn Loop::advance(self : Loop, now_ms : Int64) -> Int {
  self.last_now = now_ms
  if !self.running {
    return 0
  }
  let mut ran = 0
  let mut go = true
  // 只处理本轮进入时已排队的项：回调里 post_task/timer 排到下一拍
  let limit = self.next_seq
  while go {
    let js = self.jobs
    if js.length() == 0 {
      go = false
    } else {
      let head = js[0]
      if head.due_ms > now_ms || head.seq >= limit || !self.running {
        go = false
      } else {
        let _ = js.remove(0)
        (head.run)()
        ran = ran + 1
      }
    }
  }
  ran
}

///|
/// 平台泵本次最长可等多久：有立即项或已到期项返回 `Some(0)`，
/// 只有未来定时器返回距最近的毫秒数，无待办返回 `None`（可无限等，
/// 但必须有跨线程唤醒位把 `wait` 叫回来）。
pub fn Loop::wait_budget(self : Loop, now_ms : Int64) -> Int? {
  let js = self.jobs
  if js.length() == 0 {
    None
  } else {
    let head = js[0]
    if head.due_ms <= now_ms {
      Some(0)
    } else {
      let delta = head.due_ms - now_ms
      Some(if delta > 1000000L { 1000000 } else { delta.to_int() })
    }
  }
}

///|
/// 停止派发。拆除对象前必须先调它（先停派发、再拆对象）。
pub fn Loop::quit(self : Loop) -> Unit {
  self.running = false
}

///|
pub fn Loop::is_running(self : Loop) -> Bool {
  self.running
}
