///|
/// 已校验的 100 字节 SQLite 头。page_size 为实际字节数，usable_size 扣除保留空间；declared_pages 是头部声明值，不一定等于打开视图的逻辑页数。text_encoding 为 1/2/3，未初始化空库也允许 0。
pub(all) struct Header {
  page_size : Int
  usable_size : Int
  write_version : Int
  read_version : Int
  change_counter : UInt
  declared_pages : UInt
  freelist_trunk : UInt
  freelist_pages : UInt
  schema_cookie : UInt
  schema_format : Int
  largest_root_page : UInt
  incremental_vacuum : Bool
  text_encoding : Int
  user_version : UInt
  application_id : UInt
  version_valid_for : UInt
  sqlite_version : UInt
} derive(Debug, Eq)

///|
pub extend Header with @debug.Debug::{to_repr}

///|
pub extend Header with Eq::{equal, not_equal}

///|
/// 验证至少 100 字节的 SQLite 文件头，不读取页面；页长编码 1 还原为 65536。输入无效或格式不支持时抛 SqliteError。
pub fn parse_header(data : Bytes) -> Header raise SqliteError {
  require_range(data, 0, 100)
  if data[0:16].to_owned() != b"SQLite format 3\x00" {
    raise Invalid("不是 SQLite 3 数据库：magic 不匹配")
  }
  let raw_size = read_u16(data, 16)
  let page_size = if raw_size == 1 { 65536 } else { raw_size }
  if page_size < 512 || page_size > 65536 || (page_size & (page_size - 1)) != 0 {
    raise Invalid("无效 page_size：\{page_size}")
  }
  let usable_size = page_size - data[20].to_int()
  if usable_size < 480 {
    raise Invalid("页面可用空间不足 480 字节")
  }
  let write_version = data[18].to_int()
  let read_version = data[19].to_int()
  if read_version != 1 && read_version != 2 {
    raise Unsupported("未知文件读取版本")
  }
  if write_version < 1 {
    raise Invalid("无效文件写入版本")
  }
  if data[21] != 64 || data[22] != 32 || data[23] != 32 {
    raise Invalid("无效 payload fractions")
  }
  let schema_format = bounded_int(
    read_u32(data, 44).to_uint64(),
    "schema_format",
  )
  if schema_format > 4 {
    raise Unsupported("未知 schema format")
  }
  let text_encoding = bounded_int(read_u32(data, 56).to_uint64(), "encoding")
  if text_encoding < 0 || text_encoding > 3 {
    raise Unsupported("未知文本编码")
  }
  for i = 72; i < 92; i = i + 1 {
    if data[i] != 0 {
      raise Invalid("数据库头保留字段必须为零")
    }
  }
  {
    page_size,
    usable_size,
    write_version,
    read_version,
    change_counter: read_u32(data, 24),
    declared_pages: read_u32(data, 28),
    freelist_trunk: read_u32(data, 32),
    freelist_pages: read_u32(data, 36),
    schema_cookie: read_u32(data, 40),
    schema_format,
    largest_root_page: read_u32(data, 52),
    incremental_vacuum: read_u32(data, 64) != 0U,
    text_encoding,
    user_version: read_u32(data, 60),
    application_id: read_u32(data, 68),
    version_valid_for: read_u32(data, 92),
    sqlite_version: read_u32(data, 96),
  }
}
