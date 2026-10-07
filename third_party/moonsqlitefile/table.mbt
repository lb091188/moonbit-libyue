///|
/// 普通 rowid 表的原始记录。INTEGER PRIMARY KEY 的磁盘字段可能为 Null，主键位于 rowid；不执行 SQL 列映射或类型亲和性转换。
pub(all) struct Row {
  rowid : Int64
  values : Array[Value]
  page_number : Int
} derive(Debug)

///|
pub extend Row with @debug.Debug::{to_repr}

///|
fn page_varint(
  bytes : Bytes,
  offset : Int,
  usable : Int,
) -> (UInt64, Int) raise SqliteError {
  if offset < 0 || offset >= usable {
    raise Invalid("cell varint 起点越界")
  }
  let result = decode_varint(bytes, offset)
  if result.1 > usable - offset {
    raise Invalid("cell varint 跨越页面保留空间")
  }
  result
}

///|
/// 以 rowid 顺序读取普通表；保留首版接口与原始存储值语义。
/// 收集普通 rowid 表的原始记录；显式 limit 可返回前缀，默认预算造成未完成时抛 LimitExceeded。不支持 index/WITHOUT ROWID，改用 read_btree。
pub fn Database::read_table(
  self : Database,
  root : Int,
  limit? : Int = self.limits.max_rows,
) -> Array[Row] raise SqliteError {
  let page = self.page(root)
  if page.kind == IndexLeaf || page.kind == IndexInterior {
    raise Unsupported(
      "该表使用 index B-tree；请使用 table_records 读取原始记录",
    )
  }
  self
  .read_btree(root, limit~)
  .map(record => {
    rowid: record.rowid.unwrap(),
    values: record.values,
    page_number: record.page_number,
  })
}
