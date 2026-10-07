///|
/// 源必须在 Database 的使用期间保持同一份静态快照；不提供并发锁或事务语义。
/// 旧同步静态源；长度与偏移为 Int，必须精确返回请求字节。不得修改快照；宿主 SqliteError 保留历史映射。大文件和细分类别应使用 RangeSource。
pub(open) trait PageSource {
  fn byte_length(Self) -> Int
  fn read_range(Self, Int, Int) -> Bytes raise SqliteError
}

///|
/// 不可变内存字节源；同时实现旧 PageSource 与 64 位 RangeSource，实际容量仍受 Bytes 和宿主内存限制。
pub struct BytesSource {
  data : Bytes
}

///|
/// 包装不可变 Bytes，不复制整个输入；源容量受 Bytes/Int 限制。
pub fn BytesSource::new(data : Bytes) -> BytesSource {
  { data, }
}

///|
pub extend BytesSource with PageSource::{byte_length, read_range}

///|
/// 返回静态源字节长度，不执行格式检查。
pub impl PageSource for BytesSource with fn byte_length(self) {
  self.data.length()
}

///|
/// 按源契约返回准确范围字节；范围和长度错误按实现所属的源错误类型返回。
pub impl PageSource for BytesSource with fn read_range(self, offset, count) {
  require_range(self.data, offset, count)
  self.data[offset:offset + count].to_owned()
}

///|
fn source_read(
  source : &PageSource,
  offset : Int,
  count : Int,
) -> Bytes raise SqliteError {
  let size = source.byte_length()
  if offset < 0 || count < 0 || offset > size || count > size - offset {
    raise Invalid("数据源读取范围越界")
  }
  let bytes = source.read_range(offset, count)
  if bytes.length() != count {
    raise Invalid("数据源未返回请求的完整字节范围")
  }
  bytes
}

///|
/// 打开旧同步 PageSource；初始化只请求 100 字节头。长度/偏移受 Int 限制，宿主 SqliteError 保留历史分类；调用者管理源生命周期。
pub fn open_source(
  source : &PageSource,
  limits? : Limits = Limits::default(),
) -> Database raise SqliteError {
  open_sized_source(source, limits, None)
}

///|
fn open_sized_source(
  source : &PageSource,
  limits : Limits,
  committed_pages : Int?,
) -> Database raise SqliteError {
  open_data_source(LegacySource(source), limits, committed_pages)
}

///|
fn open_data_source(
  source : DataSource,
  limits : Limits,
  committed_pages : Int?,
  max_report_pages? : Int = limits.max_pages,
) -> Database raise SqliteError {
  if max_report_pages < 1 {
    raise Invalid("报告页数预算必须为正数")
  }
  if limits.max_rows < 1 ||
    limits.max_payload_bytes < 1 ||
    limits.max_pages < 1 ||
    limits.max_depth < 1 {
    raise Invalid("所有资源限制必须为正数")
  }
  let size = data_length(source)
  let header = parse_header(data_read(source, 0L, 100))
  if size % header.page_size.to_int64() != 0L ||
    size < header.page_size.to_int64() {
    raise Invalid("数据库文件不包含完整页面")
  }
  if size / header.page_size.to_int64() > 2147483647L {
    raise LimitExceeded("数据库页数超出当前 Int 页号接口范围")
  }
  let physical_pages = bounded_int(
    (size / header.page_size.to_int64()).reinterpret_as_uint64(),
    "database pages",
  )
  let page_count = if committed_pages is Some(pages) {
    if pages != physical_pages {
      raise Invalid("WAL 逻辑页数与快照长度不一致")
    }
    pages
  } else if header.declared_pages != 0U &&
    header.change_counter == header.version_valid_for {
    let declared = bounded_int(
      header.declared_pages.to_uint64(),
      "database pages",
    )
    if declared > physical_pages {
      raise Invalid(
        "数据库声明页数超过文件长度；请使用 checkpoint 后的副本",
      )
    }
    declared
  } else {
    physical_pages
  }
  if header.freelist_pages.to_uint64() > page_count.to_uint64() {
    raise Invalid("freelist 页数超过数据库页数")
  }
  let legacy : &PageSource = match source {
    LegacySource(source) => source
    WideSource(source) => LegacyRangeView::{ source, }
  }
  {
    source: legacy,
    data_source: source,
    header,
    page_count,
    limits,
    report_max_pages: max_report_pages,
  }
}
