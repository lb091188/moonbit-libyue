///|
/// 全库检查按需请求页面，进度事件允许宿主让出执行权和取消。
/// 全库供页协议：按需请求完整页、发送可让出执行权的进度事件，最后交付包含部分结果的详细报告。
pub(all) enum InspectionEvent {
  NeedInspectionPage(Int)
  InspectionProgress(ScanProgress)
  InspectionFinished(DatabaseInspectionDetails)
} derive(Debug)

///|
pub extend InspectionEvent with @debug.Debug::{to_repr}

///|
/// 无 I/O 全库检查游标；包含 schema、对象树、freelist 和 Ptrmap。宿主可供页、拒绝当前读请求或停止，并保留此前观察到的归属与诊断。
pub struct InspectionCursor {
  priv db : Database
  priv state : OwnershipState
  priv max_payload : UInt64
  priv entries : Array[SchemaEntry]
  priv mut entry_index : Int
  priv mut phase : Int
  priv mut root : Int
  priv mut name : String
  priv mut index_root : Bool
  priv mut scan : BTreeCursor?
  priv mut free : FreelistCursor?
  priv mut ptrmap : PtrmapCursor?
  priv mut ptrmap_checked : Bool
  priv mut all_claimed : Bool
  priv mut pending : Int?
  priv mut supplied : Bytes?
  priv mut read_error : SqliteError?
  priv mut request_kind : Int
  priv mut finished : DatabaseInspectionDetails?
}

///|
/// 创建包含 schema、对象树、freelist、Ptrmap 的全库游标；默认累计 payload 64 MiB、诊断 100 条。配置错误返回失败报告，宿主按事件供页或拒绝读请求。
pub fn Database::inspection_cursor(
  self : Database,
  max_total_payload_bytes? : UInt64 = 67108864UL,
  max_issues? : Int = 100,
) -> InspectionCursor {
  self.inspection_cursor_traced([], max_total_payload_bytes~, max_issues~)
}

///|
fn Database::inspection_cursor_traced(
  self : Database,
  located_issues : Array[LocatedDatabaseIssue],
  max_total_payload_bytes~ : UInt64,
  max_issues~ : Int,
) -> InspectionCursor {
  let state : OwnershipState = {
    owners: Map([]),
    issues: [],
    located_issues,
    trace: InspectionTrace::new(),
    max_pages: Int::min(self.limits.max_pages, self.report_max_pages),
    max_issues: if max_issues > 0 {
      max_issues
    } else {
      1
    },
    coverage: true,
    failed: false,
    truncated: false,
    roots: 0,
    records: 0,
    payload: 0UL,
  }
  let vacuum = self.header.largest_root_page != 0U
  let cursor : InspectionCursor = {
    db: self,
    state,
    max_payload: max_total_payload_bytes,
    entries: [],
    entry_index: 0,
    phase: 0,
    root: 1,
    name: "sqlite_schema",
    index_root: false,
    scan: None,
    free: None,
    ptrmap: None,
    ptrmap_checked: !vacuum,
    all_claimed: true,
    pending: None,
    supplied: None,
    read_error: None,
    request_kind: 0,
    finished: None,
  }
  if max_issues < 1 {
    state.error(None, Invalid("诊断条数上限必须为正数"))
    cursor.finished = Some({
      inspection: state.finish(0, !vacuum),
      issues: located_issues,
    })
    return cursor
  }
  if self.page_count > state.max_pages {
    state.error(
      None,
      LimitExceeded("数据库逻辑页数超过全局检查预算"),
    )
    cursor.ptrmap_checked = false
    cursor.phase = 4
    return cursor
  }
  if self.header.largest_root_page.to_uint64() > self.page_count.to_uint64() ||
    (!vacuum && self.header.incremental_vacuum) {
    state.trace.at(Configuration, Some(1), byte_offset=Some(52))
    state.error(None, Invalid("auto-vacuum 文件头字段不一致"))
    cursor.ptrmap_checked = false
    cursor.phase = 4
    return cursor
  }
  let lock_page = 1073741824 / self.header.page_size + 1
  if lock_page <= self.page_count {
    state.claim({
      page_number: lock_page,
      kind: LockByte,
      root_page: None,
      object_name: None,
      parent_page: None,
    }) catch {
      error => state.error(None, error)
    }
  }
  if vacuum {
    let step = self.header.usable_size / 5 + 1
    let mut number = 2
    while number <= self.page_count {
      let actual = if number == lock_page { number + 1 } else { number }
      if actual <= self.page_count {
        state.claim({
          page_number: actual,
          kind: PointerMap,
          root_page: None,
          object_name: None,
          parent_page: None,
        }) catch {
          error => state.error(None, error)
        }
      }
      if self.page_count - number < step {
        break
      }
      number = number + step
    }
  }
  state.roots = 1
  cursor
}

///|
/// 返回全库已成功解码记录、已认领页面和已请求 payload；schema 记录也计数。
pub fn InspectionCursor::progress(self : InspectionCursor) -> ScanProgress {
  {
    records_read: self.state.records,
    pages_read: self.state.owners.length(),
    payload_bytes: self.state.payload,
  }
}

///|
/// 返回检查实际阶段及可用位置；None 字段表示未掌握位置。
pub fn InspectionCursor::location(
  self : InspectionCursor,
) -> DiagnosticLocation {
  self.state.trace.snapshot()
}

///|
/// 供给当前请求的完整页；错页、重复或长度不符抛 Invalid，不允许把宿主短读送入格式解析。
pub fn InspectionCursor::provide_page(
  self : InspectionCursor,
  number : Int,
  bytes : Bytes,
) -> Unit raise SqliteError {
  if self.finished is Some(_) ||
    self.pending != Some(number) ||
    self.supplied is Some(_) {
    raise Invalid("全库游标未请求此页，或页面已经提供")
  }
  if bytes.length() != self.db.header.page_size {
    raise Invalid("全库游标供页长度必须等于 page_size")
  }
  self.supplied = Some(bytes)
}

///|
/// 宿主失败或取消保留观察结果，并明确标记检查未完成。
/// 停止全库检查并释放游标，保留已观察页面、记录、诊断和位置；未完成时状态为 Incomplete，可提供停止原因。
pub fn InspectionCursor::stop(
  self : InspectionCursor,
  reason? : SqliteError = Unsupported("检查由宿主提前终止"),
) -> DatabaseInspectionDetails {
  if self.finished is Some(details) {
    return details
  }
  self.state.error(if self.phase < 2 { Some(self.root) } else { None }, reason)
  self.ptrmap_checked = false
  self.finish()
}

///|
fn InspectionCursor::finish(
  self : InspectionCursor,
) -> DatabaseInspectionDetails {
  if self.finished is Some(details) {
    return details
  }
  if self.scan is Some(scan) {
    ignore(scan.stop())
  }
  self.scan = None
  self.free = None
  self.ptrmap = None
  self.pending = None
  self.supplied = None
  self.entries.clear()
  let details : DatabaseInspectionDetails = {
    inspection: self.state.finish(self.db.page_count, self.ptrmap_checked),
    issues: self.state.located_issues,
  }
  self.finished = Some(details)
  details
}

///|
fn InspectionCursor::request(
  self : InspectionCursor,
  number : Int,
  kind : Int,
) -> InspectionEvent raise SqliteError {
  self.state.trace.at(ReadPage, Some(number))
  if number < 1 || number > self.db.page_count {
    raise Invalid("页号越界：\{number}")
  }
  self.pending = Some(number)
  self.request_kind = kind
  NeedInspectionPage(number)
}

///|
/// 推进一个供页/进度事件或返回详细报告；已完成或停止后重复调用保持最终结果，不执行宿主 I/O。
pub fn InspectionCursor::next(self : InspectionCursor) -> InspectionEvent {
  if self.finished is Some(details) {
    return InspectionFinished(details)
  }
  self.advance() catch {
    error => {
      if self.phase == 3 {
        if error is Invalid(_) {
          self.state.failed = true
        }
        self.state.issue(ScanError(None, error))
      } else {
        self.state.error(
          if self.phase < 2 {
            Some(self.root)
          } else {
            None
          },
          error,
        )
      }
      if self.scan is Some(scan) {
        ignore(scan.stop())
      }
      self.scan = None
      self.pending = None
      self.supplied = None
      if self.phase == 0 {
        self.phase = 4
      } else if self.phase == 1 {
        self.root = 0
      } else if self.phase == 2 {
        self.phase = 3
      } else {
        self.phase = 4
        self.ptrmap_checked = false
      }
      InspectionProgress(self.progress())
    }
  }
}

///|
fn InspectionCursor::advance(
  self : InspectionCursor,
) -> InspectionEvent raise SqliteError {
  if self.pending is Some(number) {
    if self.read_error is Some(error) {
      self.read_error = None
      raise error
    }
    if self.supplied is None {
      return NeedInspectionPage(number)
    }
    let bytes = self.supplied.unwrap()
    self.pending = None
    self.supplied = None
    match self.request_kind {
      1 => {
        let page = self.db.page_from_bytes(
          number,
          bytes,
          trace=Some(self.state.trace),
        )
        self.state.trace.at(
          SchemaDecode,
          Some(number),
          byte_offset=if self.phase == 0 { Some(100) } else { None },
        )
        if self.phase == 0 &&
          page.kind != TableLeaf &&
          page.kind != TableInterior {
          raise Invalid("sqlite_schema 根页必须是 table B-tree")
        }
        if self.index_root &&
          page.kind != IndexLeaf &&
          page.kind != IndexInterior {
          raise Invalid("schema 索引根页不是 index B-tree")
        }
        let scan = self.db.scan_cursor_observed(
          self.root,
          self.state.observer(self.root, self.name),
          limit=self.db.limits.max_rows - self.state.records,
          max_total_payload_bytes=self.max_payload - self.state.payload,
        )
        ignore(scan.next())
        scan.provide_page(number, bytes)
        self.scan = Some(scan)
      }
      2 => self.scan.unwrap().provide_page(number, bytes)
      3 => self.free.unwrap().supplied = Some(bytes)
      _ => {
        let ptrmap = self.ptrmap.unwrap()
        ptrmap.cached = bytes
        ptrmap.cached_number = number
      }
    }
  }
  while true {
    if self.phase < 2 {
      if self.scan is Some(scan) {
        match scan.next() {
          NeedPage(number) => return self.request(number, 2)
          RecordReady(record) => {
            self.state.records = self.state.records + 1
            if self.phase == 0 {
              self.state.trace.at(
                SchemaDecode,
                Some(record.page_number),
                byte_offset=Some(record.cell_offset),
                cell_index=self.state.trace.cell_index,
              )
              self.entries.push(schema_entry(record.values, self.db.page_count))
            }
            return InspectionProgress(self.progress())
          }
          ScanFinished(summary) => {
            self.scan = None
            if summary.completion != Complete {
              self.state.trace.at(
                if self.phase == 0 {
                  SchemaDecode
                } else {
                  Configuration
                },
                if self.phase == 0 {
                  None
                } else {
                  Some(self.root)
                },
              )
              self.state.error(
                Some(self.root),
                LimitExceeded(
                  if self.phase == 0 {
                    "schema 未完整读取，无法发现全部根页"
                  } else {
                    "全局记录数预算已耗尽"
                  },
                ),
              )
              if self.phase == 0 {
                self.phase = 4
                continue
              }
            }
            self.phase = 1
            self.root = 0
          }
        }
      }
      if self.root != 0 {
        return self.request(self.root, 1)
      }
      self.state.trace.at(SchemaDecode, None)
      if self.state.issues.length() >= self.state.max_issues {
        self.state.coverage = false
        self.state.truncated = true
        self.phase = 3
        continue
      }
      if self.entry_index == self.entries.length() {
        self.phase = 2
        continue
      }
      let entry = self.entries[self.entry_index]
      self.entry_index = self.entry_index + 1
      if entry.object_type == "view" || entry.object_type == "trigger" {
        if entry.root_page != 0 {
          self.state.error(
            Some(entry.root_page),
            Invalid("view 或 trigger 不能拥有根页"),
          )
        }
        continue
      }
      if entry.root_page == 0 {
        if entry.object_type == "index" {
          self.state.error(Some(0), Invalid("索引没有根页"))
        }
        continue
      }
      self.root = entry.root_page
      self.name = entry.name
      self.index_root = entry.object_type == "index"
      self.state.roots = self.state.roots + 1
      if !self.index_root {
        self.scan = Some(
          self.db.scan_cursor_observed(
            self.root,
            self.state.observer(self.root, self.name),
            limit=self.db.limits.max_rows - self.state.records,
            max_total_payload_bytes=self.max_payload - self.state.payload,
          ),
        )
      }
      continue
    }
    if self.phase == 2 {
      if self.free is None {
        self.free = Some(
          self.db.freelist_cursor(
            (number, kind, parent) => {
              self.state.claim({
                page_number: number,
                kind,
                root_page: None,
                object_name: None,
                parent_page: parent,
              })
            },
            self.state.trace,
          ),
        )
      }
      match self.free.unwrap().next() {
        Some(number) => return self.request(number, 3)
        None => {
          self.free = None
          self.phase = 3
        }
      }
      return InspectionProgress(self.progress())
    }
    if self.phase == 3 {
      if self.db.header.largest_root_page == 0U {
        self.phase = 4
        continue
      }
      if !self.state.coverage {
        self.ptrmap_checked = false
        self.phase = 4
        continue
      }
      if self.ptrmap is None {
        self.state.check_root_positions(self.db)
        self.ptrmap = Some(self.db.ptrmap_cursor(self.state.trace))
      }
      match self.ptrmap.unwrap().next() {
        MapPage(number) => return self.request(number, 4)
        MapEntry(entry) => {
          if self.state.issues.length() >= self.state.max_issues {
            self.state.truncated = true
            self.ptrmap_checked = false
            self.phase = 4
            continue
          }
          if !self.state.check_ptrmap_entry(entry) {
            self.all_claimed = false
          }
          return InspectionProgress(self.progress())
        }
        MapFinished => {
          self.ptrmap_checked = self.all_claimed
          self.phase = 4
        }
      }
      continue
    }
    return InspectionFinished(self.finish())
  } nobreak {
    abort("全库检查循环意外结束")
  }
}

///|
/// 将本次页读取失败送回状态机，其他可独立检查的对象仍可继续。
/// 将当前页面读取错误交给核心，保留部分报告并继续可独立检查的对象；schema 读取失败不能继续发现全部根页。范围宿主错误应先使用 source/ 映射。
pub fn InspectionCursor::reject_page(
  self : InspectionCursor,
  reason : SqliteError,
) -> Unit raise SqliteError {
  if self.finished is Some(_) ||
    self.pending is None ||
    self.supplied is Some(_) ||
    self.read_error is Some(_) {
    raise Invalid("全库游标没有待失败的页请求")
  }
  self.read_error = Some(reason)
}
