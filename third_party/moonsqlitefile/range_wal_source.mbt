///|
/// 64 位主文件/WAL 静态覆盖源；只保存有界覆盖索引，按范围读取实际来源，逻辑页数以最新完整提交为准。宿主必须提供一致且不可变的配对副本。
pub struct RangeWalSource {
  priv base : &RangeSource
  priv wal : &RangeSource
  priv page_size : Int
  priv page_count : Int
  priv base_pages : Int
  priv overlay : Map[Int, Int64]
  priv inspection : RangeWalInspection
}

///|
pub extend RangeWalSource with RangeSource::{byte_length64, read_range64}

///|
/// 只读最新已提交快照；调用者负责提供同一数据库、同一时刻的不可变副本。
/// 逐帧校验配对静态范围源并构建有界最新提交覆盖索引；max_frames/max_overlay_pages 默认各 100000。宿主失败或预算不足不能回退为旧成功快照。
pub fn RangeWalSource::new(
  base : &RangeSource,
  wal : &RangeSource,
  tail_policy? : WalTailPolicy = RejectInvalidTail,
  max_frames? : Int = 100000,
  max_overlay_pages? : Int = 100000,
) -> RangeWalSource raise SqliteError {
  build_range_wal_source(
    base,
    wal,
    inspect_wal_source(wal, max_frames~),
    tail_policy,
    max_overlay_pages,
  )
}

///|
/// 使用已经完成的供帧游标创建索引；游标输入必须来自相同的不可变 WAL。
/// 从完成的 WalCursor 构造覆盖索引，不重新验证 WAL；传入源必须与供给校验时相同且不可变。未完成/取消游标拒绝构造。
pub fn RangeWalSource::from_cursor(
  base : &RangeSource,
  wal : &RangeSource,
  cursor : WalCursor,
  tail_policy? : WalTailPolicy = RejectInvalidTail,
  max_overlay_pages? : Int = 100000,
) -> RangeWalSource raise SqliteError {
  if cursor.closed {
    raise Invalid("WAL 游标已经关闭")
  }
  let report = cursor.finished.unwrap_or_else(() => {
    raise Invalid("WAL 游标尚未完成")
  })
  build_range_wal_source(
    base,
    wal,
    copy_wal_inspection(report),
    tail_policy,
    max_overlay_pages,
  )
}

///|
fn build_range_wal_source(
  base : &RangeSource,
  wal : &RangeSource,
  inspection : RangeWalInspection,
  tail_policy : WalTailPolicy,
  max_overlay_pages : Int,
) -> RangeWalSource raise SqliteError {
  if max_overlay_pages < 1 {
    raise Invalid("WAL 覆盖页预算必须为正数")
  }
  if inspection.stop_reason == WalFrameLimit {
    raise LimitExceeded(
      "WAL 帧上限不足，不能确定最新已提交快照",
    )
  }
  if tail_policy == RejectInvalidTail && inspection.stop_reason != WalEndOfFile {
    raise Invalid(
      "WAL 存在无效或截断尾部；请检查报告并显式选择 UseValidPrefix",
    )
  }
  let size = base.byte_length64()
  if size < 0L {
    raise Invalid("主文件长度不能为负数")
  }
  let base_header = if size == 0L {
    None
  } else {
    Some(parse_header(range_sqlite_read(base, 0L, 100)))
  }
  let page_size = match inspection.header {
    Some(header) => header.page_size
    None =>
      base_header.unwrap_or_else(() => {
        raise Invalid("没有 WAL 或可用主文件")
      }).page_size
  }
  if size % page_size.to_int64() != 0L {
    raise Invalid("WAL 主文件不包含完整页面")
  }
  if base_header is Some(header) && header.page_size != page_size {
    raise Invalid("WAL 与主文件 page_size 不一致")
  }
  let physical_pages = bounded_int(
    (size / page_size.to_int64()).reinterpret_as_uint64(),
    "database pages",
  )
  let mut base_pages = physical_pages
  let page_count = match inspection.database_pages {
    Some(pages) => bounded_int(pages.to_uint64(), "WAL database pages")
    None => {
      let header = base_header.unwrap_or_else(() => {
        raise Invalid("没有已提交 WAL 或可用主文件")
      })
      if header.declared_pages != 0U &&
        header.change_counter == header.version_valid_for {
        let count = bounded_int(
          header.declared_pages.to_uint64(),
          "database pages",
        )
        if count > physical_pages {
          raise Invalid("主文件声明页数超过文件长度")
        }
        count
      } else {
        physical_pages
      }
    }
  }
  if page_count < 1 {
    raise Invalid("WAL 快照页数必须为正数")
  }
  let overlay : Map[Int, Int64] = Map([])
  // 逆序保留最新版本；后续提交的缩小边界使更早的高页号版本失效。
  // 只扫描一次，避免每个提交反复遍历整张覆盖表。
  let mut retained_pages = page_count
  for i = inspection.committed_frames - 1; i >= 0; i = i - 1 {
    let frame = inspection.frames[i]
    if frame.database_pages != 0U &&
      frame.database_pages.to_uint64() < retained_pages.to_uint64() {
      retained_pages = frame.database_pages.reinterpret_as_int()
    }
    if frame.page_number.to_uint64() <= retained_pages.to_uint64() {
      let number = frame.page_number.reinterpret_as_int()
      if !overlay.contains(number) {
        if overlay.length() >= max_overlay_pages {
          raise LimitExceeded("WAL 覆盖页索引超过独立预算")
        }
        overlay[number] = frame.byte_offset + 24L
      }
    }
  }
  base_pages = Int::min(base_pages, retained_pages)
  // 文件增长的所有新页必须由 WAL 提供；避免从旧的截断残留页读取数据。
  let mut new_pages = 0
  for number, _ in overlay {
    if number > base_pages {
      new_pages = new_pages + 1
    }
  }
  if page_count > base_pages && new_pages != page_count - base_pages {
    raise Invalid("WAL 快照缺少增长后的页面")
  }
  { base, wal, page_size, page_count, base_pages, overlay, inspection, }
}

///|
/// 返回覆盖视图的 64 位 WAL 验证报告，不重新读取源；调用者不应修改报告数组。
pub fn RangeWalSource::inspection(self : RangeWalSource) -> RangeWalInspection {
  self.inspection
}

///|
/// 返回最新完整提交的逻辑页数，隔离未提交尾部和缩小后旧页。
pub fn RangeWalSource::page_count(self : RangeWalSource) -> Int {
  self.page_count
}

///|
/// 返回静态源字节长度，不执行格式检查。
pub impl RangeSource for RangeWalSource with fn byte_length64(self) {
  self.page_count.to_int64() * self.page_size.to_int64()
}

///|
/// 按源契约返回准确范围字节；范围和长度错误按实现所属的源错误类型返回。
pub impl RangeSource for RangeWalSource with fn read_range64(
  self,
  offset,
  count,
) {
  let size = self.byte_length64()
  check_source_range(size, offset, count)
  let output : FixedArray[Byte] = FixedArray::make(count, 0)
  let mut copied = 0
  while copied < count {
    let position = offset + copied.to_int64()
    let number = (position / self.page_size.to_int64()).to_int() + 1
    let in_page = (position % self.page_size.to_int64()).to_int()
    let length = Int::min(count - copied, self.page_size - in_page)
    let input = match self.overlay.get(number) {
      Some(wal_offset) =>
        range_read(self.wal, wal_offset + in_page.to_int64(), length)
      None => {
        if number > self.base_pages {
          raise HostFailure("WAL 快照页面缺失")
        }
        range_read(self.base, position, length)
      }
    }
    for i = 0; i < length; i = i + 1 {
      output[copied + i] = input[i]
    }
    copied = copied + length
  }
  Bytes::from_array(output)
}

///|
/// 从已校验的 64 位覆盖源打开 Database，使用提交逻辑页数；初始化失败没有部分检查报告，调用者仍管理源生命周期。
pub fn open_range_wal_source(
  source : RangeWalSource,
  limits? : Limits = Limits::default(),
  max_report_pages? : Int = 100000,
) -> Database raise SqliteError {
  open_data_source(
    WideSource(source),
    limits,
    Some(source.page_count),
    max_report_pages~,
  )
}

///|
/// 异步适配器使用同一个核心覆盖索引确定页来源，不重复实现提交或缩小语义。
/// 覆盖视图中页面的真实来源；MainPage/WalPage 携带页面内容起始的 Int64 字节偏移，WalPage 跳过 24 字节帧头。
pub(all) enum SnapshotPageRange {
  MainPage(Int64)
  WalPage(Int64)
} derive(Debug, Eq)

///|
pub extend SnapshotPageRange with @debug.Debug::{to_repr}

///|
pub extend SnapshotPageRange with Eq::{equal, not_equal}

///|
/// 查询逻辑页实际读取来源；返回页面内容起始的 Int64 偏移，WAL 偏移不包含 24 字节帧头。页号越界抛 Invalid。
pub fn RangeWalSource::page_range(
  self : RangeWalSource,
  number : Int,
) -> SnapshotPageRange raise SqliteError {
  if number < 1 || number > self.page_count {
    raise Invalid("页号越界：\{number}")
  }
  match self.overlay.get(number) {
    Some(offset) => WalPage(offset)
    None => MainPage((number - 1).to_int64() * self.page_size.to_int64())
  }
}
