///|
/// 页面由调用者提供；游标不执行 I/O，记录之间可暂停以实现异步背压。
/// B-tree 供页协议。NeedPage 请求一个完整页面；RecordReady 交付一条记录；ScanFinished 包含终止原因。等待供页时重复 next 保持相同请求。
pub(all) enum ScanEvent {
  NeedPage(Int)
  RecordReady(BTreeRecord)
  ScanFinished(ScanSummary)
} derive(Debug)

///|
pub extend ScanEvent with @debug.Debug::{to_repr}

///|
/// 已完成的记录和已认领页面进度，不表示整个扫描已完成。
/// 尚未完成扫描的已交付记录、已认领页面及已请求 payload 进度；不能据此声称完整。
pub(all) struct ScanProgress {
  records_read : Int
  pages_read : Int
  payload_bytes : UInt64
} derive(Debug, Eq)

///|
pub extend ScanProgress with @debug.Debug::{to_repr}

///|
pub extend ScanProgress with Eq::{equal, not_equal}

///|
priv struct CursorFrameRequest {
  number : Int
  depth : Int
  lower : Int64?
  upper : Int64?
  parent : Int?
}

///|
priv struct CursorPayload {
  reader : PayloadReader
  size : Int
  rowid : Int64?
  page_number : Int
  cell_offset : Int
  cell_index : Int
}

///|
/// 无 I/O 的可暂停 B-tree 状态机。调用 next 后按请求 supply 页面；消费者等待期间不预读。失败后查看 progress/location，并 stop 释放状态。
pub struct BTreeCursor {
  priv db : Database
  priv observer : ScanObserver
  priv limit : Int
  priv max_payload : UInt64
  priv table_only : Bool
  priv occupied : Map[Int, PageUse]
  priv stack : Array[WalkFrame]
  priv mut table : Bool?
  priv mut pending_frame : CursorFrameRequest?
  priv mut pending_page : Int?
  priv mut supplied : Bytes?
  priv mut payload : CursorPayload?
  priv mut records_read : Int
  priv mut payload_bytes : UInt64
  priv mut last_rowid : Int64?
  priv mut leaf_depth : Int?
  priv mut finished : ScanSummary?
  priv mut failed : Bool
}

///|
/// 创建可恢复的扫描，不读取根页；next 返回需要的页面或一条记录。
/// 创建无 I/O 扫描游标，next 按需请求完整页。limit 不能超过 Limits.max_rows，累计 payload 默认 64 MiB；table_only 额外要求 table B-tree。
pub fn Database::scan_cursor(
  self : Database,
  root : Int,
  limit? : Int = self.limits.max_rows,
  max_total_payload_bytes? : UInt64 = 67108864UL,
  table_only? : Bool = false,
) -> BTreeCursor raise SqliteError {
  self.scan_cursor_observed(
    root,
    quiet_observer(),
    limit~,
    max_total_payload_bytes~,
    table_only~,
  )
}

///|
fn Database::scan_cursor_observed(
  self : Database,
  root : Int,
  observer : ScanObserver,
  limit~ : Int,
  max_total_payload_bytes~ : UInt64,
  table_only? : Bool = false,
) -> BTreeCursor raise SqliteError {
  observer.trace.at(Configuration, None)
  if limit < 0 || limit > self.limits.max_rows {
    raise LimitExceeded("记录数请求超出资源限制")
  }
  {
    db: self,
    observer,
    limit,
    max_payload: max_total_payload_bytes,
    table_only,
    occupied: Map([]),
    stack: [],
    table: None,
    pending_frame: Some({
      number: root,
      depth: 1,
      lower: None,
      upper: None,
      parent: None,
    }),
    pending_page: None,
    supplied: None,
    payload: None,
    records_read: 0,
    payload_bytes: 0UL,
    last_rowid: None,
    leaf_depth: None,
    finished: None,
    failed: false,
  }
}

///|
/// 返回已交付记录、已认领 B-tree/overflow 页与已请求 payload 进度；失败记录的 payload 可能已计费。
pub fn BTreeCursor::progress(self : BTreeCursor) -> ScanProgress {
  if self.finished is Some(summary) {
    return {
      records_read: summary.records_read,
      pages_read: summary.pages_read,
      payload_bytes: summary.payload_bytes,
    }
  }
  {
    records_read: self.records_read,
    pages_read: self.occupied.length(),
    payload_bytes: self.payload_bytes,
  }
}

///|
/// 返回实际阶段和可用位置；失败后仍可读取，不从错误字符串推断。
pub fn BTreeCursor::location(self : BTreeCursor) -> DiagnosticLocation {
  self.observer.trace.snapshot()
}

///|
/// 仅允许供应当前请求的完整页面；宿主须在调用前自行分类短读和读取失败。
/// 仅接受当前 NeedPage 请求对应的完整页面；错页、短页、重复供给或未请求供给抛 Invalid。宿主应在供给前区分读取失败与格式失败。
pub fn BTreeCursor::provide_page(
  self : BTreeCursor,
  number : Int,
  bytes : Bytes,
) -> Unit raise SqliteError {
  if self.failed ||
    self.finished is Some(_) ||
    self.pending_page != Some(number) ||
    self.supplied is Some(_) {
    raise Invalid("游标未请求此页，或当前页面已经提供")
  }
  if bytes.length() != self.db.header.page_size {
    raise Invalid("游标供页长度必须等于 page_size")
  }
  self.supplied = Some(bytes)
}

///|
/// 提前终止并释放当前路径和未完成的 payload；不再请求页面。
/// 停止并释放路径、页缓冲和 payload；保留已观察计数。未自然结束时返回 VisitorStopped，不把取消当完整。
pub fn BTreeCursor::stop(self : BTreeCursor) -> ScanSummary {
  self.finish(VisitorStopped)
}

///|
fn BTreeCursor::finish(
  self : BTreeCursor,
  completion : ScanCompletion,
) -> ScanSummary {
  if self.finished is Some(summary) {
    return summary
  }
  let summary : ScanSummary = {
    records_read: self.records_read,
    pages_read: self.occupied.length(),
    payload_bytes: self.payload_bytes,
    completion,
  }
  self.stack.clear()
  self.occupied.clear()
  self.pending_frame = None
  self.pending_page = None
  self.supplied = None
  self.payload = None
  self.finished = Some(summary)
  summary
}

///|
fn BTreeCursor::request_page(
  self : BTreeCursor,
  number : Int,
) -> ScanEvent raise SqliteError {
  self.observer.trace.at(ReadPage, Some(number))
  if number < 1 || number > self.db.page_count {
    raise Invalid("页号越界：\{number}")
  }
  self.pending_page = Some(number)
  NeedPage(number)
}

///|
fn BTreeCursor::take_page(self : BTreeCursor) -> Bytes {
  let bytes = self.supplied.unwrap()
  self.supplied = None
  self.pending_page = None
  bytes
}

///|
/// 连续 next 在尚未供页时重复同一请求；错误后游标不可继续使用。
/// 推进至一条记录、一个供页请求或结束；等待供页时重复调用不改变请求。解析/预算失败抛 SqliteError，进度和位置仍可读取。
pub fn BTreeCursor::next(self : BTreeCursor) -> ScanEvent raise SqliteError {
  if self.failed {
    raise Invalid("扫描游标已经失败")
  }
  errdefer {
    self.failed = true
    self.stack.clear()
    self.supplied = None
    self.payload = None
  }
  self.advance()
}

///|
fn BTreeCursor::emit(
  self : BTreeCursor,
  payload : CursorPayload,
) -> ScanEvent raise SqliteError {
  self.observer.trace.at(
    RecordDecode,
    Some(payload.page_number),
    byte_offset=Some(payload.cell_offset),
    cell_index=Some(payload.cell_index),
  )
  let record : BTreeRecord = {
    rowid: payload.rowid,
    values: decode_record(payload.reader.bytes(), self.db.header.text_encoding),
    page_number: payload.page_number,
    cell_offset: payload.cell_offset,
  }
  self.payload_bytes = self.payload_bytes + payload.size.to_uint64()
  self.records_read = self.records_read + 1
  let frame = self.stack[self.stack.length() - 1]
  frame.cursor = frame.cursor + 1
  frame.emit_pending = false
  self.payload = None
  RecordReady(record)
}

///|
fn BTreeCursor::advance(self : BTreeCursor) -> ScanEvent raise SqliteError {
  if self.finished is Some(summary) {
    return ScanFinished(summary)
  }
  if self.pending_page is Some(number) && self.supplied is None {
    return NeedPage(number)
  }
  while true {
    if self.pending_frame is Some(request) {
      if request.depth > self.db.limits.max_depth {
        raise LimitExceeded("B-tree 深度超过限制")
      }
      if self.occupied.get(request.number) is Some(page_use) {
        raise Invalid(
          "页 \{request.number} 已用于 \{page_use_name(page_use)}，不能重复用于 B-tree",
        )
      }
      if self.occupied.length() >= self.db.limits.max_pages {
        raise LimitExceeded("扫描总页数超过限制")
      }
      if self.supplied is None {
        return self.request_page(request.number)
      }
      let bytes = self.take_page()
      if self.table is None {
        let page = self.db.page_from_bytes(
          request.number,
          bytes,
          trace=Some(self.observer.trace),
        )
        self.table = Some(page.kind == TableLeaf || page.kind == TableInterior)
        if self.table_only && !self.table.unwrap() {
          raise Invalid("请求的根页不是 table B-tree")
        }
      }
      self.stack.push(
        self.db.walk_frame_loaded(
          request.number,
          request.depth,
          request.lower,
          request.upper,
          self.table.unwrap(),
          self.occupied,
          request.parent,
          self.observer,
          bytes,
        ),
      )
      self.pending_frame = None
    }
    if self.payload is Some(payload) {
      match payload.reader.next_page() {
        None => return self.emit(payload)
        Some(number) => {
          if self.supplied is None {
            return self.request_page(number)
          }
          payload.reader.provide(self.take_page())
        }
      }
      continue
    }
    if self.stack.is_empty() {
      return ScanFinished(self.finish(Complete))
    }
    let frame = self.stack[self.stack.length() - 1]
    let page = frame.page
    let bytes = frame.bytes
    let usable = self.db.header.usable_size
    let table = self.table.unwrap()
    let interior = page.kind == TableInterior || page.kind == IndexInterior
    self.observer.trace.at(TreeTraversal, Some(page.number))
    if !interior {
      if self.leaf_depth is Some(expected) && expected != frame.depth {
        raise Invalid("B-tree 叶页深度不一致")
      }
      self.leaf_depth = Some(frame.depth)
    }
    if frame.cursor == page.cell_count {
      if interior && !frame.right_visited {
        frame.right_visited = true
        self.pending_frame = Some({
          number: page.right_child.unwrap(),
          depth: frame.depth + 1,
          lower: frame.previous_key,
          upper: frame.upper,
          parent: Some(page.number),
        })
      } else {
        ignore(self.stack.pop())
      }
      continue
    }
    let offset = page.cell_offsets[frame.cursor]
    self.observer.trace.at(
      TreeTraversal,
      Some(page.number),
      byte_offset=Some(offset),
      cell_index=Some(frame.cursor),
    )
    if interior && !frame.emit_pending {
      if offset > usable - 4 {
        raise Invalid("interior cell 子页指针越界")
      }
      let child = page_number(read_u32(bytes, offset))
      let mut upper = frame.upper
      if table {
        let (bits, _) = page_varint(bytes, offset + 4, usable)
        let key = bits.reinterpret_as_int64()
        if frame.previous_key is Some(previous) && key <= previous {
          raise Invalid("interior rowid 未严格递增")
        }
        if frame.upper is Some(bound) && key > bound {
          raise Invalid("interior rowid 越过父页键范围")
        }
        upper = Some(key)
      }
      let lower = frame.previous_key
      if table {
        frame.previous_key = upper
        frame.cursor = frame.cursor + 1
      } else {
        frame.emit_pending = true
      }
      self.pending_frame = Some({
        number: child,
        depth: frame.depth + 1,
        lower,
        upper,
        parent: Some(page.number),
      })
      continue
    }
    if self.records_read == self.limit {
      return ScanFinished(self.finish(RecordLimit))
    }
    let payload_offset = if page.kind == IndexInterior {
      offset + 4
    } else {
      offset
    }
    self.observer.trace.at(
      CellPayload,
      Some(page.number),
      byte_offset=Some(offset),
      cell_index=Some(frame.cursor),
    )
    let (size_bits, size_bytes) = page_varint(bytes, payload_offset, usable)
    let size = bounded_int(size_bits, "payload size")
    if size.to_uint64() > self.max_payload - self.payload_bytes {
      raise LimitExceeded("扫描累计 payload 超过字节预算")
    }
    (self.observer.charge_payload)(size.to_uint64())
    let (rowid, rowid_bytes) = if table {
      self.observer.trace.at(
        TreeTraversal,
        Some(page.number),
        byte_offset=Some(offset),
        cell_index=Some(frame.cursor),
      )
      let (bits, length) = page_varint(
        bytes,
        payload_offset + size_bytes,
        usable,
      )
      let rowid = bits.reinterpret_as_int64()
      if frame.lower is Some(bound) && rowid <= bound {
        raise Invalid("叶页 rowid 低于父页键范围")
      }
      if frame.upper is Some(bound) && rowid > bound {
        raise Invalid("叶页 rowid 高于父页键范围")
      }
      if self.last_rowid is Some(previous) && rowid <= previous {
        raise Invalid("叶页 rowid 未严格递增")
      }
      self.last_rowid = Some(rowid)
      (Some(rowid), length)
    } else {
      (None, 0)
    }
    self.observer.trace.at(
      CellPayload,
      Some(page.number),
      byte_offset=Some(offset),
      cell_index=Some(frame.cursor),
    )
    let reader = self.db.payload_reader(
      bytes,
      payload_offset + size_bytes + rowid_bytes,
      size,
      table,
      self.occupied,
      page.number,
      self.observer,
    )
    self.payload = Some({
      reader,
      size,
      rowid,
      page_number: page.number,
      cell_offset: offset,
      cell_index: frame.cursor,
    })
  } nobreak {
    abort("游标循环意外结束")
  }
}
