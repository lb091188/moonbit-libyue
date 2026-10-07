///|
/// 解析、参数或资源错误。Invalid 可来自旧 PageSource 的宿主抛错，不能单凭该枚举判定损坏；新 RangeSource 的宿主失败以 source/ 前缀映射为 Unsupported，检查状态为 Incomplete。
pub(all) suberror SqliteError {
  Invalid(String)
  Unsupported(String)
  LimitExceeded(String)
} derive(Debug)

///|
pub extend SqliteError with @debug.Debug::{to_repr}
