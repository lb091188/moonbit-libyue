///|
/// 仅描述指定根页的扫描结果，不代表整个数据库的完整性结论。
/// 结构检查状态。Complete 仅表示声明范围完成；Incomplete 包含预算、宿主失败及不支持；Failed 表示已观察到格式错误或历史旧源 Invalid。
pub(all) enum InspectionStatus {
  Complete
  Incomplete
  Failed
} derive(Debug, Eq)

///|
pub extend InspectionStatus with @debug.Debug::{to_repr}

///|
pub extend InspectionStatus with Eq::{equal, not_equal}

///|
/// 不保存记录数组；发生错误时仍保留此前成功解码的记录数。
/// 单树检查报告。root_page 是入口根页，records_decoded 只含成功交付记录；失败时可能没有 summary，error 保存原始 SqliteError。
pub(all) struct BTreeInspection {
  root_page : Int
  status : InspectionStatus
  records_decoded : Int
  summary : ScanSummary?
  error : SqliteError?
} derive(Debug)

///|
pub extend BTreeInspection with @debug.Debug::{to_repr}

///|
fn inspection_failure(
  root : Int,
  records_decoded : Int,
  error : SqliteError,
) -> BTreeInspection {
  let status = match error {
    Invalid(_) => Failed
    Unsupported(_) | LimitExceeded(_) => Incomplete
  }
  {
    root_page: root,
    status,
    records_decoded,
    summary: None,
    error: Some(error),
  }
}

///|
/// 检查单棵 B-tree，保留完成状态或原始错误；资源不足不判为格式损坏。
/// 检查一棵树并保留成功记录数；不收集记录。新范围源宿主失败为 Incomplete，旧源 Invalid 保留 Failed 历史行为，不能仅据状态判定损坏。
pub fn Database::inspect_btree(
  self : Database,
  root : Int,
  limit? : Int = self.limits.max_rows,
  max_total_payload_bytes? : UInt64 = 67108864UL,
) -> BTreeInspection {
  let mut records_decoded = 0
  try
    self.scan_btree(
      root,
      _ => {
        records_decoded = records_decoded + 1
        true
      },
      limit~,
      max_total_payload_bytes~,
    )
  catch {
    Invalid(message) =>
      inspection_failure(root, records_decoded, Invalid(message))
    Unsupported(message) =>
      inspection_failure(root, records_decoded, Unsupported(message))
    LimitExceeded(message) =>
      inspection_failure(root, records_decoded, LimitExceeded(message))
  } noraise {
    summary => {
      let status = if summary.completion == Complete {
        InspectionStatus::Complete
      } else {
        InspectionStatus::Incomplete
      }
      {
        root_page: root,
        status,
        records_decoded,
        summary: Some(summary),
        error: None,
      }
    }
  }
}
