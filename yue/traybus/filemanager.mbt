// org.freedesktop.FileManager1:跨桌面统一的「打开文件管理器并选中」接口
// (Nautilus / Dolphin / 部分构建的 Thunar 提供)。不在线时由调用方回退
// spawn xdg-open 打开父目录(选中态丢失,差异记 adaptation)。

///|
/// FileManager1 是否在线(NameHasOwner 探测,照 sni.mbt 的 watcher 探测)。
pub fn filemanager_available() -> Bool {
  match bus_conn() {
    Err(_) => false
    Ok(c) =>
      match
        c.call_sync(
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus",
          "org.freedesktop.DBus",
          "NameHasOwner",
          "s",
          [VString("org.freedesktop.FileManager1")],
        ) {
        Ok(m) =>
          match m.body.get(0) {
            Some(VBool(true)) => true
            _ => false
          }
        Err(_) => false
      }
  }
}

///|
/// ShowItems:打开文件管理器并选中给定 URI(需 file:// 百分号编码,
/// 见 file_uri)。
pub fn show_items(
  uris : Array[String],
  startup_id : String,
) -> Result[Unit, String] {
  match bus_conn() {
    Err(e) => Err(e)
    Ok(c) => {
      let vals : Array[DVal] = []
      for u in uris {
        vals.push(VString(u))
      }
      match
        c.call_sync(
          "org.freedesktop.FileManager1",
          "/org/freedesktop/FileManager1",
          "org.freedesktop.FileManager1",
          "ShowItems",
          "ass",
          [VArray("s", vals), VString(startup_id)],
        ) {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
    }
  }
}

///|
/// 绝对路径 → file:// URI:UTF-8 字节逐个百分号编码,保留 RFC 3986
/// unreserved(A-Za-z0-9-._~)与 '/',其余(空格/中文/&?=% 等)按字节 %XX。
///|
/// URI 百分号 hex 用大写(RFC 3986 大小写均可,大写是通行惯例)。
fn uri_hex(v : Int) -> Char {
  if v < 10 {
    (48 + v).unsafe_to_char() // '0'
  } else {
    (55 + v).unsafe_to_char() // 'A'
  }
}

///|
pub fn file_uri(path : String) -> String {
  let bytes = utf8(path)
  let sb = StringBuilder()
  sb.write_string("file://")
  for i in 0..<bytes.length() {
    let b = bytes[i].to_int()
    let keep = (b >= 97 && b <= 122) || // a-z
      (b >= 65 && b <= 90) || // A-Z
      (b >= 48 && b <= 57) || // 0-9
      b == 45 ||
      b == 46 ||
      b == 95 ||
      b == 126 || // - . _ ~
      b == 47 // /
    if keep {
      sb.write_char(b.unsafe_to_char())
    } else {
      sb.write_char('%')
      sb.write_char(uri_hex(b >> 4))
      sb.write_char(uri_hex(b & 15))
    }
  }
  sb.to_string()
}
