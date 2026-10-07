///|
/// 失败发生的检查阶段；读取失败不能仅凭 SqliteError 判断为格式损坏。
/// 失败时实际执行的检查阶段；不从错误文本猜测阶段或位置。
pub(all) enum DiagnosticPhase {
  Configuration
  ReadPage
  PageLayout
  TreeTraversal
  CellPayload
  OverflowChain
  RecordDecode
  SchemaDecode
  FreelistCheck
  PtrmapCheck
  PageOwnershipCheck
} derive(Debug, Eq)

///|
pub extend DiagnosticPhase with @debug.Debug::{to_repr}

///|
pub extend DiagnosticPhase with Eq::{equal, not_equal}

///|
/// 偏移从页面起点计数，下标从零计数；不能确定位置时保留 None。
/// 可用的失败位置。页号从 1 开始，byte_offset 相对页面，cell_index 从 0 开始；未知字段为 None，初始化失败不产生该报告。
pub(all) struct DiagnosticLocation {
  phase : DiagnosticPhase
  page_number : Int?
  byte_offset : Int?
  cell_index : Int?
  page_diagnostic : PageDiagnostic?
} derive(Debug)

///|
pub extend DiagnosticLocation with @debug.Debug::{to_repr}

///|
/// 单树检查与可用的失败位置；inspection 的状态语义与原同步报告一致。
pub(all) struct BTreeInspectionDetails {
  inspection : BTreeInspection
  location : DiagnosticLocation?
} derive(Debug)

///|
pub extend BTreeInspectionDetails with @debug.Debug::{to_repr}

///|
/// 全库问题及观察到的位置；缺失位置不代表页 0，不从根页或字符串推断。
pub(all) struct LocatedDatabaseIssue {
  issue : DatabaseIssue
  location : DiagnosticLocation?
} derive(Debug)

///|
pub extend LocatedDatabaseIssue with @debug.Debug::{to_repr}

///|
/// issues 与 inspection.issues 同序同长度，位置来自同一次检查，不重新读取源。
/// 全库报告与按问题顺序对应的位置；不会额外重读数据库。
pub(all) struct DatabaseInspectionDetails {
  inspection : DatabaseInspection
  issues : Array[LocatedDatabaseIssue]
} derive(Debug)

///|
pub extend DatabaseInspectionDetails with @debug.Debug::{to_repr}

///|
priv struct InspectionTrace {
  mut phase : DiagnosticPhase
  mut page_number : Int?
  mut byte_offset : Int?
  mut cell_index : Int?
  mut page_diagnostic : PageDiagnostic?
}

///|
fn InspectionTrace::new() -> InspectionTrace {
  {
    phase: Configuration,
    page_number: None,
    byte_offset: None,
    cell_index: None,
    page_diagnostic: None,
  }
}

///|
fn InspectionTrace::at(
  self : InspectionTrace,
  phase : DiagnosticPhase,
  page_number : Int?,
  byte_offset? : Int? = None,
  cell_index? : Int? = None,
) -> Unit {
  self.phase = phase
  self.page_number = page_number
  self.byte_offset = byte_offset
  self.cell_index = cell_index
  self.page_diagnostic = None
}

///|
fn InspectionTrace::snapshot(self : InspectionTrace) -> DiagnosticLocation {
  {
    phase: self.phase,
    page_number: self.page_number,
    byte_offset: self.byte_offset,
    cell_index: self.cell_index,
    page_diagnostic: self.page_diagnostic,
  }
}

///|
/// 与 inspect_btree 使用相同扫描和状态语义，额外保留失败上下文。
/// 返回单树报告及实际失败位置，不进行第二次扫描；位置未知为 None。
pub fn Database::inspect_btree_details(
  self : Database,
  root : Int,
  limit? : Int = self.limits.max_rows,
  max_total_payload_bytes? : UInt64 = 67108864UL,
) -> BTreeInspectionDetails {
  let trace = InspectionTrace::new()
  let observer : ScanObserver = {
    claim: (_, _, _) => (),
    charge_payload: _ => (),
    trace,
  }
  let mut records_decoded = 0
  try
    self.scan_btree_observed(
      root,
      _ => {
        records_decoded = records_decoded + 1
        true
      },
      observer,
      limit~,
      max_total_payload_bytes~,
    )
  catch {
    error =>
      {
        inspection: inspection_failure(root, records_decoded, error),
        location: Some(trace.snapshot()),
      }
  } noraise {
    summary =>
      {
        inspection: {
          root_page: root,
          status: if summary.completion == Complete {
            InspectionStatus::Complete
          } else {
            Incomplete
          },
          records_decoded,
          summary: Some(summary),
          error: None,
        },
        location: None,
      }
  }
}

///|
/// 一次全库检查同时保留每个问题的可用位置，不从错误字符串猜测；语义与 inspect_database 相同。
pub fn Database::inspect_database_details(
  self : Database,
  max_total_payload_bytes? : UInt64 = 67108864UL,
  max_issues? : Int = 100,
) -> DatabaseInspectionDetails {
  let issues : Array[LocatedDatabaseIssue] = []
  let inspection = self.inspect_database_traced(
    issues,
    max_total_payload_bytes~,
    max_issues~,
  )
  { inspection, issues, }
}
