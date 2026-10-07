///|
fn require_range(
  data : Bytes,
  offset : Int,
  count : Int,
) -> Unit raise SqliteError {
  if offset < 0 ||
    count < 0 ||
    offset > data.length() ||
    count > data.length() - offset {
    raise Invalid(
      "读取越界：offset=\{offset}, length=\{count}, size=\{data.length()}",
    )
  }
}

///|
fn read_u16(data : Bytes, offset : Int) -> Int raise SqliteError {
  require_range(data, offset, 2)
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
fn read_u32(data : Bytes, offset : Int) -> UInt raise SqliteError {
  require_range(data, offset, 4)
  let mut value = 0U
  for i = 0; i < 4; i = i + 1 {
    value = (value << 8) | data[offset + i].to_uint()
  }
  value
}

///|
fn bounded_int(value : UInt64, name : String) -> Int raise SqliteError {
  if value > 2147483647UL {
    raise LimitExceeded("\{name} 超出当前内存读取器范围")
  }
  value.to_int()
}

///|
/// 从 offset 解码 1–9 字节 SQLite varint，返回无符号值与消耗字节数；截断或越界抛 Invalid，不进行有符号 rowid 转换。
pub fn decode_varint(
  data : Bytes,
  offset : Int,
) -> (UInt64, Int) raise SqliteError {
  let mut value = 0UL
  for i = 0; i < 9; i = i + 1 {
    require_range(data, offset + i, 1)
    let byte = data[offset + i].to_uint64()
    // 第九字节使用全部八位，其余字节只使用低七位。
    if i == 8 {
      return ((value << 8) | byte, 9)
    }
    value = (value << 7) | (byte & 127UL)
    if (byte & 128UL) == 0UL {
      return (value, i + 1)
    }
  }
  raise Invalid("无效 varint")
}
