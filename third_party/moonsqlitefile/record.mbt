///|
/// SQLite 记录中的原始值，保留整数、浮点数与二进制数据的区别。
/// SQLite record 的磁盘值类型；Integer 保留 Int64，Text 按数据库编码解码，Blob 保留字节。不是 SQL 引擎计算后的逻辑值。
pub(all) enum Value {
  Null
  Integer(Int64)
  Real(Double)
  Text(String)
  Blob(Bytes)
} derive(Debug, Eq)

///|
pub extend Value with @debug.Debug::{to_repr}

///|
pub extend Value with Eq::{equal, not_equal}

///|
fn record_serial_length(serial : UInt64) -> Int raise SqliteError {
  match serial {
    0UL | 8UL | 9UL => 0
    1UL => 1
    2UL => 2
    3UL => 3
    4UL => 4
    5UL => 6
    6UL | 7UL => 8
    10UL | 11UL => raise Invalid("记录包含保留 serial type：\{serial}")
    _ => {
      let length = (serial - 12UL) / 2UL
      if length > 2147483647UL {
        raise Invalid("记录字段长度超出可读取范围")
      }
      length.to_int()
    }
  }
}

///|
fn record_integer(payload : Bytes, offset : Int, count : Int) -> Int64 {
  let mut bits = 0UL
  for i = 0; i < count; i = i + 1 {
    bits = (bits << 8) | payload[offset + i].to_uint64()
  }
  if count < 8 && payload[offset].to_int() >= 128 {
    // SQLite 使用大端二进制补码，短整数必须进行符号扩展。
    bits.reinterpret_as_int64() - (1L << (count * 8))
  } else {
    bits.reinterpret_as_int64()
  }
}

///|
fn record_text(data : BytesView, encoding : Int) -> String raise SqliteError {
  try {
    match encoding {
      1 => @utf8.decode(data, ignore_bom=false)
      2 => @utf16.decode(data, ignore_bom=false, endianness=@utf16.Little)
      3 => @utf16.decode(data, ignore_bom=false, endianness=@utf16.Big)
      _ => raise Invalid("无效文本编码：\{encoding}")
    }
  } catch {
    _ => raise Invalid("记录文本不符合指定的 Unicode 编码")
  }
}

///|
/// 解码完整的 SQLite record payload；编码编号与数据库文件头保持一致。
/// 完整解码 record 的 serial types 与 payload；encoding 为 1/2/3，保留磁盘值顺序，不执行 SQL 转换。截断、非法编码或不支持类型通过 SqliteError 返回。
pub fn decode_record(
  payload : Bytes,
  encoding : Int,
) -> Array[Value] raise SqliteError {
  if encoding < 1 || encoding > 3 {
    raise Invalid("无效文本编码：\{encoding}")
  }
  let (header_size, header_varint_size) = decode_varint(payload, 0)
  if header_size < header_varint_size.to_uint64() ||
    header_size > payload.length().to_uint64() {
    raise Invalid("记录头长度超出 payload 边界")
  }
  let header_end = header_size.to_int()
  let serials : Array[UInt64] = []
  let mut header_cursor = header_varint_size
  while header_cursor < header_end {
    let (serial, size) = decode_varint(payload, header_cursor)
    if size > header_end - header_cursor {
      raise Invalid("serial type varint 跨越记录头边界")
    }
    serials.push(serial)
    header_cursor = header_cursor + size
  }
  let values : Array[Value] = []
  let mut body_cursor = header_end
  for serial in serials {
    let count = record_serial_length(serial)
    require_range(payload, body_cursor, count)
    let value = match serial {
      0UL => Null
      1UL | 2UL | 3UL | 4UL | 5UL | 6UL =>
        Integer(record_integer(payload, body_cursor, count))
      7UL =>
        Real(record_integer(payload, body_cursor, 8).reinterpret_as_double())
      8UL => Integer(0L)
      9UL => Integer(1L)
      _ => {
        let data = payload[body_cursor : body_cursor + count]
        if serial % 2UL == 0UL {
          Blob(data.to_owned())
        } else {
          Text(record_text(data, encoding))
        }
      }
    }
    values.push(value)
    body_cursor = body_cursor + count
  }
  if body_cursor != payload.length() {
    raise Invalid("记录体含有未被 serial type 描述的剩余字节")
  }
  values
}
