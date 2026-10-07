///|
/// 全库归属报告的八类页用途；一页只统计首次归属，冲突另外报告。
pub(all) enum PageKind {
  BtreeRoot
  BtreeChild
  OverflowFirst
  OverflowContinuation
  FreelistTrunk
  FreelistLeaf
  PointerMap
  LockByte
} derive(Debug, Eq)

///|
pub extend PageKind with @debug.Debug::{to_repr}

///|
pub extend PageKind with Eq::{equal, not_equal}

///|
/// 首次认领页面的用途、根页、对象和父页；不属于对象或没有父页时相应字段为 None。
pub(all) struct PageOwnership {
  page_number : Int
  kind : PageKind
  root_page : Int?
  object_name : String?
  parent_page : Int?
} derive(Debug, Eq)

///|
pub extend PageOwnership with @debug.Debug::{to_repr}

///|
pub extend PageOwnership with Eq::{equal, not_equal}

///|
/// 全库结构问题：扫描错误、跨用途页冲突、完整覆盖后的未认领页、不支持特性及 Ptrmap 归属不一致。
pub(all) enum DatabaseIssue {
  ScanError(Int?, SqliteError)
  PageConflict(PageOwnership, PageOwnership)
  UnclaimedPage(Int)
  UnsupportedFeature(String)
  PtrmapMismatch(PtrmapEntry, PageOwnership)
} derive(Debug)

///|
pub extend DatabaseIssue with @debug.Debug::{to_repr}

///|
/// 只检查逻辑数据库页；完整页归属不等价于 SQL 完整性检查。
/// 全库已观察报告。ownership_complete 与 ptrmap_checked 分别标记覆盖；diagnostics_truncated 表示诊断截断。schema 记录计入 records_decoded，失败 payload 请求也计费。
pub(all) struct DatabaseInspection {
  status : InspectionStatus
  ownership_complete : Bool
  ptrmap_checked : Bool
  diagnostics_truncated : Bool
  roots_inspected : Int
  records_decoded : Int
  payload_bytes : UInt64
  pages : Array[PageOwnership]
  unclaimed_pages : Array[Int]
  issues : Array[DatabaseIssue]
} derive(Debug)

///|
pub extend DatabaseInspection with @debug.Debug::{to_repr}

///|
priv struct OwnershipState {
  owners : Map[Int, PageOwnership]
  issues : Array[DatabaseIssue]
  located_issues : Array[LocatedDatabaseIssue]
  trace : InspectionTrace
  max_pages : Int
  max_issues : Int
  mut coverage : Bool
  mut failed : Bool
  mut truncated : Bool
  mut roots : Int
  mut records : Int
  mut payload : UInt64
}

///|
fn OwnershipState::issue(self : OwnershipState, issue : DatabaseIssue) -> Unit {
  if self.issues.length() < self.max_issues {
    let location : DiagnosticLocation? = match issue {
      PageConflict(_, owner) =>
        Some({
          phase: PageOwnershipCheck,
          page_number: Some(owner.page_number),
          byte_offset: None,
          cell_index: None,
          page_diagnostic: None,
        })
      UnclaimedPage(number) =>
        Some({
          phase: PageOwnershipCheck,
          page_number: Some(number),
          byte_offset: None,
          cell_index: None,
          page_diagnostic: None,
        })
      UnsupportedFeature(_) => None
      _ => Some(self.trace.snapshot())
    }
    self.issues.push(issue)
    self.located_issues.push({ issue, location, })
  } else {
    self.truncated = true
  }
}

///|
fn OwnershipState::error(
  self : OwnershipState,
  root : Int?,
  error : SqliteError,
) -> Unit {
  self.coverage = false
  if error is Invalid(_) {
    self.failed = true
  }
  self.issue(ScanError(root, error))
}

///|
fn OwnershipState::claim(
  self : OwnershipState,
  owner : PageOwnership,
) -> Unit raise SqliteError {
  if self.owners.get(owner.page_number) is Some(previous) {
    self.failed = true
    self.issue(PageConflict(previous, owner))
    raise Invalid("页 \{owner.page_number} 被多个用途或对象占用")
  }
  if self.owners.length() >= self.max_pages {
    raise LimitExceeded("数据库级页数预算已耗尽")
  }
  self.owners[owner.page_number] = owner
}

///|
fn OwnershipState::observer(
  self : OwnershipState,
  root : Int,
  name : String,
) -> ScanObserver {
  {
    claim: (number, kind, parent) => {
      self.claim({
        page_number: number,
        kind,
        root_page: Some(root),
        object_name: Some(name),
        parent_page: parent,
      })
    },
    charge_payload: size => self.payload = self.payload + size,
    trace: self.trace,
  }
}

///|
fn OwnershipState::finish(
  self : OwnershipState,
  page_count : Int,
  ptrmap_checked : Bool,
) -> DatabaseInspection {
  let pages : Array[PageOwnership] = []
  let unclaimed : Array[Int] = []
  // 预检拒绝超预算的数据库，避免枚举或分配无界的页列表。
  if page_count <= self.max_pages {
    for index = 0; index < page_count; index = index + 1 {
      let number = index + 1
      if self.owners.get(number) is Some(owner) {
        pages.push(owner)
      } else {
        unclaimed.push(number)
        if self.coverage {
          self.failed = true
          self.issue(UnclaimedPage(number))
        }
      }
    }
  }
  let status = if self.failed {
    Failed
  } else if !self.coverage || !ptrmap_checked || self.truncated {
    Incomplete
  } else {
    Complete
  }
  {
    status,
    ownership_complete: self.coverage,
    ptrmap_checked,
    diagnostics_truncated: self.truncated,
    roots_inspected: self.roots,
    records_decoded: self.records,
    payload_bytes: self.payload,
    pages,
    unclaimed_pages: unclaimed,
    issues: self.issues,
  }
}

///|
/// 扫描 schema、独立 B-tree 和 freelist，使用整个检查过程共享的预算。
/// 检查 schema、对象树、freelist 和 Ptrmap 的全局归属；保存部分结果。默认累计 payload 64 MiB、最多 100 条诊断，不检查 SQL 排序或表/索引内容一致性。
pub fn Database::inspect_database(
  self : Database,
  max_total_payload_bytes? : UInt64 = 67108864UL,
  max_issues? : Int = 100,
) -> DatabaseInspection {
  self.inspect_database_traced([], max_total_payload_bytes~, max_issues~)
}

///|
fn Database::inspect_database_traced(
  self : Database,
  located_issues : Array[LocatedDatabaseIssue],
  max_total_payload_bytes~ : UInt64,
  max_issues~ : Int,
) -> DatabaseInspection {
  let cursor = self.inspection_cursor_traced(
    located_issues,
    max_total_payload_bytes~,
    max_issues~,
  )
  while true {
    match cursor.next() {
      NeedInspectionPage(number) =>
        cursor.provide_page(number, self.read_page(number)) catch {
          error =>
            cursor.reject_page(error) catch {
              _ => abort("全库游标请求状态不一致")
            }
        }
      InspectionProgress(_) => ()
      InspectionFinished(details) => return details.inspection
    }
  } nobreak {
    abort("全库检查循环意外结束")
  }
}
