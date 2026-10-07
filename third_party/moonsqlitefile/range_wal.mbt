///|
/// 范围 WAL 中的一帧；byte_offset 使用 Int64，指向帧头，其他字段保持原帧语义。
pub(all) struct RangeWalFrame {
  index : Int
  byte_offset : Int64
  page_number : UInt
  database_pages : UInt
  checksum1 : UInt
  checksum2 : UInt
} derive(Debug, Eq)

///|
pub extend RangeWalFrame with @debug.Debug::{to_repr}

///|
pub extend RangeWalFrame with Eq::{equal, not_equal}

///|
/// 范围 WAL 的有效提交边界；帧号仍为 Int，逻辑页数来自提交帧。
pub(all) struct RangeWalCommit {
  frame_index : Int
  database_pages : UInt
} derive(Debug, Eq)

///|
pub extend RangeWalCommit with @debug.Debug::{to_repr}

///|
pub extend RangeWalCommit with Eq::{equal, not_equal}

///|
/// 范围 WAL 报告；stop_offset 与 trailing_bytes 为 Int64，未完成校验的帧不能用于最新快照。
pub(all) struct RangeWalInspection {
  header : WalHeader?
  frames : Array[RangeWalFrame]
  commits : Array[RangeWalCommit]
  committed_frames : Int
  database_pages : UInt?
  stop_reason : WalStopReason
  stop_offset : Int64
  trailing_bytes : Int64
} derive(Debug)

///|
pub extend RangeWalInspection with @debug.Debug::{to_repr}

///|
/// 只接受连续有效帧；遇到首个无效帧后不搜索更后面的提交标记。
/// 逐帧验证 64 位静态 WAL 源，不持有完整 WAL；默认帧预算 100000。实际宿主失败抛 source/ 错误，不作为有效前缀成功。
pub fn inspect_wal_source(
  source : &RangeSource,
  max_frames? : Int = 100000,
) -> RangeWalInspection raise SqliteError {
  let cursor = WalCursor::new(source.byte_length64(), max_frames~)
  while true {
    match cursor.next() {
      NeedWalRange(offset, count) =>
        cursor.provide(offset, range_sqlite_read(source, offset, count))
      WalReady(report) => return report
    }
  } nobreak {
    abort("WAL 游标未结束")
  }
}
