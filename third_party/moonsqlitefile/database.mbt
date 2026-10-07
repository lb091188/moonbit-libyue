///|
/// 单次操作的资源上限；不是堆内存上限。max_rows 默认 100000，单条 payload 默认 16 MiB，max_pages 默认 100000，max_depth 默认 64；累计 payload 由扫描参数独立控制。
pub(all) struct Limits {
  max_rows : Int
  max_payload_bytes : Int
  max_pages : Int
  max_depth : Int
} derive(Debug)

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
/// 返回默认单次预算：100000 条记录、16 MiB 单条 payload、100000 页、深度 64；累计 payload 默认值由扫描接口另行提供。
pub fn Limits::default() -> Limits {
  {
    max_rows: 100000,
    max_payload_bytes: 16777216,
    max_pages: 100000,
    max_depth: 64,
  }
}

///|
/// 已打开的只读静态数据库视图。页号从 1 开始；page_count 是逻辑页数，WAL 视图以最新提交为准。旧 source 字段保留 Int 寻址兼容性，完整源应通过 source64 访问。
pub struct Database {
  source : &PageSource
  priv data_source : DataSource
  header : Header
  page_count : Int
  limits : Limits
  priv report_max_pages : Int
}

///|
/// 从完整静态 Bytes 打开只读库；只验证初始化与文件头。后续格式错误在实际访问时返回；不获取并发快照或执行完整性检查。
pub fn open_database(
  data : Bytes,
  limits? : Limits = Limits::default(),
) -> Database raise SqliteError {
  open_source(BytesSource::new(data), limits~)
}

///|
/// 返回打开时已校验的文件头，不重读源；WAL 视图的逻辑页数应读取 page_count。
pub fn Database::header(self : Database) -> Header {
  self.header
}

///|
/// 返回当前视图的逻辑页数；WAL 视图采用最新完整提交页数，不直接采用旧主文件声明。
pub fn Database::page_count(self : Database) -> Int {
  self.page_count
}

///|
/// 读取完整的逻辑页，number 从 1 开始；页号越界为 Invalid，范围宿主失败保留 source/ 分类。此入口不解析页布局。
pub fn Database::read_page(
  self : Database,
  number : Int,
) -> Bytes raise SqliteError {
  if number < 1 || number > self.page_count {
    raise Invalid("页号越界：\{number}")
  }
  let offset = (number - 1).to_int64() * self.header.page_size.to_int64()
  data_read(self.data_source, offset, self.header.page_size)
}

///|
fn page_number(value : UInt) -> Int raise SqliteError {
  if value > 2147483647U {
    raise LimitExceeded("页号超出当前 Int 页号接口范围")
  }
  value.reinterpret_as_int()
}
