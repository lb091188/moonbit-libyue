///|
/// sqlite_schema 的一条已校验记录。root_page 为 0 表示无独立根页；sql 可为空，不解析 CREATE 语句，也不恢复列名或 SQL 语义。
pub(all) struct SchemaEntry {
  object_type : String
  name : String
  table_name : String
  root_page : Int
  sql : String?
} derive(Debug)

///|
pub extend SchemaEntry with @debug.Debug::{to_repr}

///|
/// 异步适配层校验已解码的 sqlite_schema 记录，语义与同步 schema 一致。
/// 校验一条已解码 sqlite_schema record 和根页范围；不解析 sql 字符串，page_count 必须是视图的逻辑页数。
pub fn decode_schema_entry(
  values : Array[Value],
  page_count : Int,
) -> SchemaEntry raise SqliteError {
  schema_entry(values, page_count)
}

///|
/// 完整读取并校验 sqlite_schema；受 Limits.max_rows 预算限制，超出时抛 LimitExceeded，不把 schema 前缀冒充完整对象集合。
pub fn Database::schema(
  self : Database,
) -> Array[SchemaEntry] raise SqliteError {
  let entries : Array[SchemaEntry] = []
  for row in self.read_table(1) {
    entries.push(schema_entry(row.values, self.page_count))
  }
  entries
}

///|
fn schema_entry(
  values : Array[Value],
  page_count : Int,
) -> SchemaEntry raise SqliteError {
  match values {
    [Text(object_type), Text(name), Text(table_name), root_value, sql_value] => {
      let root = match root_value {
        Integer(value) => value
        Null => 0L
        _ => raise Invalid("schema rootpage 字段类型无效")
      }
      if root < 0L || root > page_count.to_int64() {
        raise Invalid("schema root page 越界")
      }
      if object_type != "table" &&
        object_type != "index" &&
        object_type != "view" &&
        object_type != "trigger" {
        raise Invalid("schema 包含未知对象类型")
      }
      let sql = match sql_value {
        Text(value) => Some(value)
        Null => None
        _ => raise Invalid("schema SQL 字段类型无效")
      }
      { object_type, name, table_name, root_page: root.to_int(), sql, }
    }
    _ => raise Invalid("sqlite_schema 记录不包含标准五列")
  }
}

///|
/// 按 schema 名称读取普通 rowid 表；不执行 SELECT，也不恢复 INTEGER PRIMARY KEY 磁盘 Null 字段，WITHOUT ROWID 请用 table_records。
pub fn Database::table_rows(
  self : Database,
  name : String,
  limit? : Int = self.limits.max_rows,
) -> Array[Row] raise SqliteError {
  if name == "sqlite_schema" || name == "sqlite_master" {
    return self.read_table(1, limit~)
  }
  for entry in self.schema() {
    if entry.object_type == "table" && entry.name == name {
      if entry.root_page == 0 {
        raise Unsupported("虚拟表没有独立数据 B-tree")
      }
      return self.read_table(entry.root_page, limit~)
    }
  }
  raise Invalid("未找到表：\{name}")
}

///|
/// 返回普通表或 WITHOUT ROWID 表的原始存储记录，不推断 SQL 列顺序。
/// 按表名读取原始记录，包含 WITHOUT ROWID；values 保留存储顺序，显式 limit 可返回前缀。
pub fn Database::table_records(
  self : Database,
  name : String,
  limit? : Int = self.limits.max_rows,
) -> Array[BTreeRecord] raise SqliteError {
  if name == "sqlite_schema" || name == "sqlite_master" {
    return self.read_btree(1, limit~)
  }
  for entry in self.schema() {
    if entry.object_type == "table" && entry.name == name {
      if entry.root_page == 0 {
        raise Unsupported("虚拟表没有独立数据 B-tree")
      }
      return self.read_btree(entry.root_page, limit~)
    }
  }
  raise Invalid("未找到表：\{name}")
}

///|
/// 按索引名读取包含内部 cell 的原始记录；不验证排序、collation 或表/索引内容一致性。
pub fn Database::index_records(
  self : Database,
  name : String,
  limit? : Int = self.limits.max_rows,
) -> Array[BTreeRecord] raise SqliteError {
  for entry in self.schema() {
    if entry.object_type == "index" && entry.name == name {
      if entry.root_page == 0 {
        raise Invalid("索引没有有效根页")
      }
      return self.read_index(entry.root_page, limit~)
    }
  }
  raise Invalid("未找到索引：\{name}")
}
