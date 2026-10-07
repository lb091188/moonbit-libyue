///|
/// 按顺序供给完整 WAL header 或帧；不执行宿主 I/O。
/// WAL 供给协议：NeedWalRange 指定准确 64 位偏移及完整 header/帧长度；WalReady 返回验证报告。
pub(all) enum WalReadEvent {
  NeedWalRange(Int64, Int)
  WalReady(RangeWalInspection)
} derive(Debug)

///|
pub extend WalReadEvent with @debug.Debug::{to_repr}

///|
/// 不执行 I/O 的顺序 WAL 校验游标；供给范围必须符合当前请求。取消或失败的游标不能用于构造覆盖快照。
pub struct WalCursor {
  priv size : Int64
  priv max_frames : Int
  priv mut header : WalHeader?
  priv frames : Array[RangeWalFrame]
  priv commits : Array[RangeWalCommit]
  priv mut offset : Int64
  priv mut checksum : (UInt, UInt)
  priv mut committed_frames : Int
  priv mut database_pages : UInt?
  priv mut requested : (Int64, Int)?
  priv mut supplied : Bytes?
  priv mut finished : RangeWalInspection?
  priv mut closed : Bool
}

///|
/// 创建顺序 WAL 校验游标，不读取数据；size 为非负 Int64，max_frames 默认为 100000 且必须为正，非空短 header 立即拒绝。
pub fn WalCursor::new(
  size : Int64,
  max_frames? : Int = 100000,
) -> WalCursor raise SqliteError {
  if max_frames < 1 {
    raise Invalid("WAL 帧上限必须为正数")
  }
  if size < 0L {
    raise Invalid("WAL 数据源长度不能为负数")
  }
  if size > 0L && size < 32L {
    raise Invalid("WAL header 不完整")
  }
  {
    size,
    max_frames,
    header: None,
    frames: [],
    commits: [],
    offset: 0L,
    checksum: (0U, 0U),
    committed_frames: 0,
    database_pages: None,
    requested: None,
    supplied: None,
    finished: None,
    closed: false,
  }
}

///|
/// 只接受当前请求，调用者须先分类宿主短读、越界与读取失败。
/// 只接受当前 NeedWalRange 的准确偏移和长度；错位、短读、重复供给或已关闭抛 Invalid。先由宿主分类读取错误。
pub fn WalCursor::provide(
  self : WalCursor,
  offset : Int64,
  bytes : Bytes,
) -> Unit raise SqliteError {
  if self.closed || self.finished is Some(_) || self.supplied is Some(_) {
    raise Invalid("WAL 游标已关闭、完成或已经供给数据")
  }
  match self.requested {
    Some((expected, count)) =>
      if offset != expected || bytes.length() != count {
        raise Invalid("WAL 供给范围不符合当前请求")
      }
    None => raise Invalid("WAL 游标尚未请求数据")
  }
  self.supplied = Some(bytes)
}

///|
/// 取消后释放缓冲和索引；不能把此前的提交当成最新快照返回。
/// 取消并释放供给缓冲、帧和提交数组；取消后的游标不能构造覆盖快照。
pub fn WalCursor::close(self : WalCursor) -> Unit {
  self.closed = true
  self.supplied = None
  self.requested = None
  self.frames.clear()
  self.commits.clear()
  self.finished = None
}

///|
/// 返回已校验有效帧数；未完成时不能当作最新完整 WAL 的边界，close 后计数归零。
pub fn WalCursor::frames_read(self : WalCursor) -> Int {
  self.frames.length()
}

///|
fn copy_wal_inspection(report : RangeWalInspection) -> RangeWalInspection {
  { ..report, frames: report.frames.copy(), commits: report.commits.copy(), }
}

///|
fn WalCursor::finish(self : WalCursor, reason : WalStopReason) -> WalReadEvent {
  let report : RangeWalInspection = {
    header: self.header,
    frames: self.frames,
    commits: self.commits,
    committed_frames: self.committed_frames,
    database_pages: self.database_pages,
    stop_reason: reason,
    stop_offset: self.offset,
    trailing_bytes: self.size - self.offset,
  }
  self.finished = Some(report)
  WalReady(copy_wal_inspection(report))
}

///|
/// 未供给数据时重复同一请求，成功接受一帧后才推进 offset 和 checksum。
/// 顺序推进至完整 header/帧请求或验证报告；等待供给时重复请求不变，失败后关闭游标。异常尾部记录在停止原因。
pub fn WalCursor::next(self : WalCursor) -> WalReadEvent raise SqliteError {
  if self.closed {
    raise Invalid("WAL 游标已经关闭")
  }
  errdefer self.close()
  if self.finished is Some(report) {
    return WalReady(copy_wal_inspection(report))
  }
  if self.requested is Some((offset, count)) && self.supplied is None {
    return NeedWalRange(offset, count)
  }
  if self.size == 0L {
    return self.finish(WalEndOfFile)
  }
  if self.header is None {
    if self.supplied is None {
      self.requested = Some((0L, 32))
      return NeedWalRange(0L, 32)
    }
    let header = parse_wal_header(self.supplied.unwrap())
    self.header = Some(header)
    self.checksum = (header.checksum1, header.checksum2)
    self.offset = 32L
    self.supplied = None
    self.requested = None
  } else if self.supplied is Some(data) {
    let header = self.header.unwrap()
    self.supplied = None
    self.requested = None
    if read_u32(data, 8) != header.salt1 || read_u32(data, 12) != header.salt2 {
      return self.finish(WalSaltMismatch)
    }
    let number = read_u32(data, 0)
    let pages = read_u32(data, 4)
    if number == 0U || number == 0xffffffffU || pages == 0xffffffffU {
      return self.finish(WalInvalidFrame)
    }
    let next = wal_checksum(data, 0, 8, header.checksum_order, self.checksum)
    let next = wal_checksum(
      data,
      24,
      header.page_size,
      header.checksum_order,
      next,
    )
    if next != (read_u32(data, 16), read_u32(data, 20)) {
      return self.finish(WalChecksumMismatch)
    }
    let index = self.frames.length() + 1
    self.frames.push({
      index,
      byte_offset: self.offset,
      page_number: number,
      database_pages: pages,
      checksum1: next.0,
      checksum2: next.1,
    })
    if pages != 0U {
      self.commits.push({ frame_index: index, database_pages: pages, })
      self.committed_frames = index
      self.database_pages = Some(pages)
    }
    self.checksum = next
    self.offset = self.offset + 24L + header.page_size.to_int64()
  }
  if self.offset == self.size {
    return self.finish(WalEndOfFile)
  }
  if self.frames.length() == self.max_frames {
    return self.finish(WalFrameLimit)
  }
  let count = 24 + self.header.unwrap().page_size
  if self.size - self.offset < count.to_int64() {
    return self.finish(WalTruncatedFrame)
  }
  self.requested = Some((self.offset, count))
  NeedWalRange(self.offset, count)
}
