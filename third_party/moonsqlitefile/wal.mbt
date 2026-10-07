///|
/// WAL 累计 checksum 的字节序，由 header magic 决定；其他 WAL 数值仍按大端存储。
pub(all) enum WalChecksumOrder {
  LittleEndianChecksum
  BigEndianChecksum
} derive(Debug, Eq)

///|
pub extend WalChecksumOrder with @debug.Debug::{to_repr}

///|
pub extend WalChecksumOrder with Eq::{equal, not_equal}

///|
/// 已校验的 32 字节 WAL 头；page_size 是实际页长，salt 与 checksum 用于逐帧验证，不提供在线锁或恢复协议。
pub(all) struct WalHeader {
  checksum_order : WalChecksumOrder
  version : UInt
  page_size : Int
  checkpoint_sequence : UInt
  salt1 : UInt
  salt2 : UInt
  checksum1 : UInt
  checksum2 : UInt
} derive(Debug, Eq)

///|
pub extend WalHeader with @debug.Debug::{to_repr}

///|
pub extend WalHeader with Eq::{equal, not_equal}

///|
/// 内存 WAL 中的一帧；index 从 1 开始，byte_offset 指向帧头，database_pages 非零表示提交边界。
pub(all) struct WalFrame {
  index : Int
  byte_offset : Int
  page_number : UInt
  database_pages : UInt
  checksum1 : UInt
  checksum2 : UInt
} derive(Debug, Eq)

///|
pub extend WalFrame with @debug.Debug::{to_repr}

///|
pub extend WalFrame with Eq::{equal, not_equal}

///|
/// 完整有效提交边界；frame_index 从 1 开始，database_pages 是该提交的逻辑页数。
pub(all) struct WalCommit {
  frame_index : Int
  database_pages : UInt
} derive(Debug, Eq)

///|
pub extend WalCommit with @debug.Debug::{to_repr}

///|
pub extend WalCommit with Eq::{equal, not_equal}

///|
/// WAL 扫描停止原因；异常尾部与完整提交分开记录。WalFrameLimit 不能被有效前缀策略当作最新快照成功。
pub(all) enum WalStopReason {
  WalEndOfFile
  WalTruncatedFrame
  WalSaltMismatch
  WalChecksumMismatch
  WalInvalidFrame
  WalFrameLimit
} derive(Debug, Eq)

///|
pub extend WalStopReason with @debug.Debug::{to_repr}

///|
pub extend WalStopReason with Eq::{equal, not_equal}

///|
/// 内存 WAL 连续有效帧和提交报告；异常尾部可返回报告而非抛错，构造快照时再应用尾部策略。空 WAL 没有 header。
pub(all) struct WalInspection {
  header : WalHeader?
  frames : Array[WalFrame]
  commits : Array[WalCommit]
  committed_frames : Int
  database_pages : UInt?
  stop_reason : WalStopReason
  stop_offset : Int
  trailing_bytes : Int
} derive(Debug)

///|
pub extend WalInspection with @debug.Debug::{to_repr}

///|
fn wal_word(data : Bytes, offset : Int, order : WalChecksumOrder) -> UInt {
  let mut value = 0U
  for i = 0; i < 4; i = i + 1 {
    let index = match order {
      BigEndianChecksum => offset + i
      LittleEndianChecksum => offset + 3 - i
    }
    value = (value << 8) | data[index].to_uint()
  }
  value
}

///|
// 累计 checksum 使用模 2^32 无符号加法，存储字段始终为大端。
fn wal_checksum(
  data : Bytes,
  offset : Int,
  count : Int,
  order : WalChecksumOrder,
  initial : (UInt, UInt),
) -> (UInt, UInt) {
  let mut s0 = initial.0
  let mut s1 = initial.1
  for i = offset; i < offset + count; i = i + 8 {
    s0 = s0 + wal_word(data, i, order) + s1
    s1 = s1 + wal_word(data, i + 4, order) + s0
  }
  (s0, s1)
}

///|
/// 验证 WAL header；头部不完整、格式或 checksum 错误直接抛出错误。
/// 验证 32 字节 WAL header、magic、版本、页长及 checksum；不扫描帧。
pub fn parse_wal_header(data : Bytes) -> WalHeader raise SqliteError {
  require_range(data, 0, 32)
  let checksum_order = match read_u32(data, 0) {
    0x377f0682U => LittleEndianChecksum
    0x377f0683U => BigEndianChecksum
    _ => raise Invalid("WAL magic 不匹配")
  }
  let version = read_u32(data, 4)
  if version != 3007000U {
    raise Unsupported("未知 WAL 格式版本：\{version}")
  }
  let page_size = bounded_int(read_u32(data, 8).to_uint64(), "WAL page_size")
  if page_size < 512 || page_size > 65536 || (page_size & (page_size - 1)) != 0 {
    raise Invalid("无效 WAL page_size")
  }
  let checksum1 = read_u32(data, 24)
  let checksum2 = read_u32(data, 28)
  if wal_checksum(data, 0, 24, checksum_order, (0U, 0U)) !=
    (checksum1, checksum2) {
    raise Invalid("WAL header checksum 不匹配")
  }
  {
    checksum_order,
    version,
    page_size,
    checkpoint_sequence: read_u32(data, 12),
    salt1: read_u32(data, 16),
    salt2: read_u32(data, 20),
    checksum1,
    checksum2,
  }
}

///|
/// 只接受连续有效帧；遇到首个无效帧后不搜索更后面的提交标记。
/// 顺序验证完整内存 WAL，返回连续有效帧、提交边界和停止原因。默认最多 100000 帧；异常尾部与帧预算在报告中区分。
pub fn inspect_wal(
  data : Bytes,
  max_frames? : Int = 100000,
) -> WalInspection raise SqliteError {
  // 字节入口复用范围校验，旧报告的 Int 字段保留原有契约。
  let report = inspect_wal_source(BytesSource::new(data), max_frames~)
  {
    header: report.header,
    frames: report.frames.map(frame => {
      index: frame.index,
      byte_offset: frame.byte_offset.to_int(),
      page_number: frame.page_number,
      database_pages: frame.database_pages,
      checksum1: frame.checksum1,
      checksum2: frame.checksum2,
    }),
    commits: report.commits.map(commit => {
      frame_index: commit.frame_index,
      database_pages: commit.database_pages,
    }),
    committed_frames: report.committed_frames,
    database_pages: report.database_pages,
    stop_reason: report.stop_reason,
    stop_offset: report.stop_offset.to_int(),
    trailing_bytes: report.trailing_bytes.to_int(),
  }
}
