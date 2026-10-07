///|
/// 异常尾部策略：默认 RejectInvalidTail；显式 UseValidPrefix 使用此前完整提交。帧预算不足或宿主读取失败不能降级为旧快照。
pub(all) enum WalTailPolicy {
  RejectInvalidTail
  UseValidPrefix
} derive(Debug, Eq)

///|
pub extend WalTailPolicy with @debug.Debug::{to_repr}

///|
pub extend WalTailPolicy with Eq::{equal, not_equal}

///|
/// 持有完整 WAL 字节的旧 PageSource 覆盖视图；读取最新完整提交，隔离未提交更新及缩小/增长后的旧页，受 Int 地址空间限制。
pub struct WalSource {
  base : &PageSource
  wal : Bytes
  page_size : Int
  page_count : Int
  base_pages : Int
  overlay : Map[Int, Int]
  inspection : WalInspection
}

///|
pub extend WalSource with PageSource::{byte_length, read_range}

///|
/// 只读最新已提交快照；调用者负责提供同一数据库、同一时刻的不可变副本。
/// 使用完整 WAL 字节构造旧 Int 地址空间覆盖视图；默认拒绝异常尾部，显式有效前缀策略也不能绕过帧预算。配对源必须静态一致。
pub fn WalSource::new(
  base : &PageSource,
  wal : Bytes,
  tail_policy? : WalTailPolicy = RejectInvalidTail,
  max_frames? : Int = 100000,
) -> WalSource raise SqliteError {
  let inspection = inspect_wal(wal, max_frames~)
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
  let size = base.byte_length()
  if size < 0 {
    raise Invalid("主文件长度不能为负数")
  }
  let base_header = if size == 0 {
    None
  } else {
    Some(parse_header(source_read(base, 0, 100)))
  }
  let page_size = match inspection.header {
    Some(header) => header.page_size
    None =>
      base_header.unwrap_or_else(() => {
        raise Invalid("没有 WAL 或可用主文件")
      }).page_size
  }
  if size % page_size != 0 {
    raise Invalid("WAL 主文件不包含完整页面")
  }
  if base_header is Some(header) && header.page_size != page_size {
    raise Invalid("WAL 与主文件 page_size 不一致")
  }
  let physical_pages = size / page_size
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
  if page_count < 1 || page_count > 2147483647 / page_size {
    raise LimitExceeded("WAL 快照大小超出 Int 数据源范围")
  }
  let overlay : Map[Int, Int] = Map([])
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
        overlay[number] = frame.byte_offset + 24
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
/// 返回构造覆盖视图时的 WAL 验证报告，不重新扫描源；调用者不应修改报告数组。
pub fn WalSource::inspection(self : WalSource) -> WalInspection {
  self.inspection
}

///|
/// 返回最新完整提交的逻辑页数；没有提交时使用主文件逻辑页数。
pub fn WalSource::page_count(self : WalSource) -> Int {
  self.page_count
}

///|
/// 返回静态源字节长度，不执行格式检查。
pub impl PageSource for WalSource with fn byte_length(self) {
  self.page_count * self.page_size
}

///|
/// 按源契约返回准确范围字节；范围和长度错误按实现所属的源错误类型返回。
pub impl PageSource for WalSource with fn read_range(self, offset, count) {
  let size = self.byte_length()
  if offset < 0 || count < 0 || offset > size || count > size - offset {
    raise Invalid("WAL 快照读取越界")
  }
  let output : FixedArray[Byte] = FixedArray::make(count, 0)
  let mut copied = 0
  while copied < count {
    let position = offset + copied
    let number = position / self.page_size + 1
    let in_page = position % self.page_size
    let length = Int::min(count - copied, self.page_size - in_page)
    let input = match self.overlay.get(number) {
      Some(wal_offset) =>
        self.wal[wal_offset + in_page:wal_offset + in_page + length].to_owned()
      None => {
        if number > self.base_pages {
          raise Invalid("WAL 快照页面缺失")
        }
        source_read(self.base, position, length)
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
/// 从已构造的 WAL 覆盖源打开只读 Database；使用提交逻辑页数，包括缩小和增长，不把旧主文件页数当快照页数。
pub fn open_wal_source(
  source : WalSource,
  limits? : Limits = Limits::default(),
) -> Database raise SqliteError {
  open_sized_source(source, limits, Some(source.page_count))
}

///|
/// 便捷打开完整静态 db/WAL 字节；不是在线锁、checkpoint 或恢复协议。默认严格尾部策略，空 WAL 使用主文件。
pub fn open_wal_database(
  base : Bytes,
  wal : Bytes,
  limits? : Limits = Limits::default(),
  tail_policy? : WalTailPolicy = RejectInvalidTail,
  max_frames? : Int = 100000,
) -> Database raise SqliteError {
  open_wal_source(
    WalSource::new(BytesSource::new(base), wal, tail_policy~, max_frames~),
    limits~,
  )
}
