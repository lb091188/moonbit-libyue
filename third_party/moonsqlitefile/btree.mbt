///|
/// 原始存储记录；index B-tree 没有独立 rowid，字段按磁盘顺序保留。
/// B-tree 原始存储记录。values 按磁盘顺序保留；索引和 WITHOUT ROWID 的 rowid 为 None。page_number 从 1 开始，cell_offset 为页内字节偏移。
pub(all) struct BTreeRecord {
  rowid : Int64?
  values : Array[Value]
  page_number : Int
  cell_offset : Int
} derive(Debug)

///|
pub extend BTreeRecord with @debug.Debug::{to_repr}

///|
/// 扫描终止原因：Complete 为实际遍历结束，RecordLimit 为尚有数据时到达记录前缀上限，VisitorStopped 为消费者停止；不代表 integrity_check。
pub(all) enum ScanCompletion {
  Complete
  RecordLimit
  VisitorStopped
} derive(Debug, Eq)

///|
pub extend ScanCompletion with @debug.Debug::{to_repr}

///|
pub extend ScanCompletion with Eq::{equal, not_equal}

///|
/// 扫描结果及终止原因。pages_read 包含已认领 B-tree/overflow 页，payload_bytes 是已请求 payload 字节数；不是成功记录字节数或精确内存消耗。
pub(all) struct ScanSummary {
  records_read : Int
  pages_read : Int
  payload_bytes : UInt64
  completion : ScanCompletion
} derive(Debug)

///|
pub extend ScanSummary with @debug.Debug::{to_repr}

///|
priv enum PageUse {
  Btree
  Overflow
}

///|
priv struct ScanObserver {
  claim : (Int, PageKind, Int?) -> Unit raise SqliteError
  charge_payload : (UInt64) -> Unit
  trace : InspectionTrace
}

///|
fn quiet_observer() -> ScanObserver {
  {
    claim: (_, _, _) => (),
    charge_payload: _ => (),
    trace: InspectionTrace::new(),
  }
}

///|
fn page_use_name(page_use : PageUse) -> String {
  match page_use {
    Btree => "B-tree"
    Overflow => "overflow"
  }
}

///|
priv struct WalkFrame {
  page : Page
  bytes : Bytes
  depth : Int
  lower : Int64?
  upper : Int64?
  mut cursor : Int
  mut previous_key : Int64?
  mut emit_pending : Bool
  mut right_visited : Bool
}

///|
fn Database::walk_frame_loaded(
  self : Database,
  number : Int,
  depth : Int,
  lower : Int64?,
  upper : Int64?,
  table : Bool,
  occupied : Map[Int, PageUse],
  parent : Int?,
  observer : ScanObserver,
  bytes : Bytes,
) -> WalkFrame raise SqliteError {
  observer.trace.at(TreeTraversal, Some(number))
  if depth > self.limits.max_depth {
    raise LimitExceeded("B-tree 深度超过限制")
  }
  if occupied.get(number) is Some(page_use) {
    raise Invalid(
      "页 \{number} 已用于 \{page_use_name(page_use)}，不能重复用于 B-tree",
    )
  }
  if occupied.length() >= self.limits.max_pages {
    raise LimitExceeded("扫描总页数超过限制")
  }
  observer.trace.at(ReadPage, Some(number))
  observer.trace.at(PageOwnershipCheck, Some(number))
  (observer.claim)(
    number,
    if parent is None {
      BtreeRoot
    } else {
      BtreeChild
    },
    parent,
  )
  occupied[number] = Btree
  let page = self.page_from_bytes(number, bytes, trace=Some(observer.trace))
  observer.trace.at(TreeTraversal, Some(number))
  let page_is_table = page.kind == TableLeaf || page.kind == TableInterior
  if page_is_table != table {
    raise Invalid("B-tree 中混入不同类型的页面")
  }
  // 非根空页会丢失记录；仅页 1 允许零 cell 的内部虚拟根。
  if page.cell_count == 0 &&
    (
      parent is Some(_) ||
      (
        (page.kind == TableInterior || page.kind == IndexInterior) &&
        number != 1
      )
    ) {
    raise Invalid("B-tree 非根页面或非页 1 内部根页不能为空")
  }
  {
    page,
    bytes,
    depth,
    lower,
    upper,
    cursor: 0,
    previous_key: lower,
    emit_pending: false,
    right_visited: false,
  }
}

///|
/// 按 B-tree 顺序逐条回调，返回 false 可停止；无需在库中保存所有结果。
/// 逐条调用 visit，返回 false 停止；不收集结果数组。默认累计 payload 64 MiB，失败请求也计费；报告区分遍历结束、记录前缀上限和消费者停止。
pub fn Database::scan_btree(
  self : Database,
  root : Int,
  visit : (BTreeRecord) -> Bool raise SqliteError,
  limit? : Int = self.limits.max_rows,
  max_total_payload_bytes? : UInt64 = 67108864UL,
) -> ScanSummary raise SqliteError {
  self.scan_btree_observed(
    root,
    visit,
    quiet_observer(),
    limit~,
    max_total_payload_bytes~,
  )
}

///|
fn Database::scan_btree_observed(
  self : Database,
  root : Int,
  visit : (BTreeRecord) -> Bool raise SqliteError,
  observer : ScanObserver,
  limit~ : Int,
  max_total_payload_bytes~ : UInt64,
) -> ScanSummary raise SqliteError {
  let cursor = self.scan_cursor_observed(
    root,
    observer,
    limit~,
    max_total_payload_bytes~,
  )
  while true {
    match cursor.next() {
      NeedPage(number) => cursor.provide_page(number, self.read_page(number))
      RecordReady(record) => if !visit(record) { return cursor.stop() }
      ScanFinished(summary) => return summary
    }
  } nobreak {
    abort("同步扫描游标未结束")
  }
}

///|
/// 收集任意 B-tree 的原始记录，索引内部 cell 也交付；显式 limit 可返回前缀。单条仍完整解码，集合本身可能占用大量内存。
pub fn Database::read_btree(
  self : Database,
  root : Int,
  limit? : Int = self.limits.max_rows,
  max_total_payload_bytes? : UInt64 = 67108864UL,
) -> Array[BTreeRecord] raise SqliteError {
  let records : Array[BTreeRecord] = []
  let summary = self.scan_btree(
    root,
    record => {
      records.push(record)
      true
    },
    limit~,
    max_total_payload_bytes~,
  )
  if limit == self.limits.max_rows && summary.completion != Complete {
    raise LimitExceeded(
      "记录数超过资源限制；请指定更小的 limit 读取前缀",
    )
  }
  records
}

///|
/// 收集 index B-tree/WITHOUT ROWID 的原始记录；普通 rowid 表类型不符合时抛 Invalid，不检查索引排序或 collation。
pub fn Database::read_index(
  self : Database,
  root : Int,
  limit? : Int = self.limits.max_rows,
) -> Array[BTreeRecord] raise SqliteError {
  let page = self.page(root)
  if page.kind != IndexLeaf && page.kind != IndexInterior {
    raise Invalid("根页不是 index B-tree")
  }
  self.read_btree(root, limit~)
}
