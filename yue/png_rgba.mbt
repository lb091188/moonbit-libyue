// RGBA 位图编码为 PNG（8 bit、color type 6、无隔行）。用于把逐帧
// 像素数据喂给 Image::new_from_png——libyue 的 Image 没有裸像素构造
// 入口，PNG 内存编码是纯 MoonBit 的中转通道；压缩用 zlib stored
// 块（不压缩但合法），小图够用，详见 system-capabilities.md「视频播放」。

///|
/// PNG 文件签名（8 字节魔数）。
fn pngr_sig() -> FixedArray[Byte] {
  let f = FixedArray::make(8, b'\x00')
  f[0] = b'\x89'
  f[1] = b'\x50'
  f[2] = b'\x4E'
  f[3] = b'\x47'
  f[4] = b'\x0D'
  f[5] = b'\x0A'
  f[6] = b'\x1A'
  f[7] = b'\x0A'
  f
}

///|
/// CRC32（IEEE，多项式 0xEDB88320 反射表）。表生成与累计全程在
/// Int64 上做：Int64 对非负值的 >> 即 32 位逻辑右移，结果截回 Int。
fn pngr_crc_table() -> Array[Int64] {
  let poly : Int64 = 3988292384L
  let table : Array[Int64] = []
  for i = 0; i < 256; i = i + 1 {
    let mut c : Int64 = i.to_int64()
    for _k = 0; _k < 8; _k = _k + 1 {
      c = if (c & 1L) == 1L {
        poly ^ (c >> 1)
      } else {
        c >> 1
      }
    }
    table.push(c)
  }
  table
}

///|
/// CRC32 累计值（初值 0xFFFFFFFF，结束取反）。
fn pngr_crc32(data : Bytes) -> Int {
  let table = pngr_crc_table()
  let mut c : Int64 = 4294967295L
  for i = 0; i < data.length(); i = i + 1 {
    c = table[((c.to_int()) ^ data[i].to_int()) & 0xFF] ^ (c >> 8)
  }
  (c ^ 4294967295L).to_int()
}

///|
/// Adler-32（zlib 校验和：s1=1+Σ字节, s2=ΣΣ字节，模 65521）。
fn pngr_adler32(data : Bytes) -> Int {
  let mut s1 = 1
  let mut s2 = 0
  for i = 0; i < data.length(); i = i + 1 {
    s1 = (s1 + data[i].to_int()) % 65521
    s2 = (s2 + s1) % 65521
  }
  (s2 << 16) | s1
}

///|
/// RGBA 原始扫描流：每行 = 过滤字节 0 + 该行 RGBA。
fn pngr_scanlines(data : Bytes, width : Int, height : Int) -> Bytes {
  let out = FixedArray::make(height * (1 + width * 4), b'\x00')
  let mut off = 0
  for row = 0; row < height; row = row + 1 {
    let base = row * width * 4
    for col = 0; col < width * 4; col = col + 1 {
      out[off + 1 + col] = data[base + col]
    }
    off += 1 + width * 4
  }
  Bytes::from_array(out)
}

///|
/// zlib 流：CMF/FLG 头 + stored deflate 块（每块 ≤ 65535）+ adler32。
fn pngr_zlib_stored(raw : Bytes) -> Bytes {
  let blocks = if raw.length() == 0 {
    1
  } else {
    (raw.length() + 65534) / 65535
  }
  let out = FixedArray::make(2 + blocks * 5 + raw.length() + 4, b'\x00')
  let mut off = 2
  out[0] = b'\x78'
  out[1] = b'\x01'
  for b = 0; b < blocks; b = b + 1 {
    let start = b * 65535
    let len = if raw.length() - start > 65535 {
      65535
    } else {
      raw.length() - start
    }
    let nlen = 65535 - len
    // BFINAL(1bit)+BTYPE(00 存块) 低位对齐后即一个头字节；LEN/NLEN 小端
    out[off] = if b == blocks - 1 { b'\x01' } else { b'\x00' }
    out[off + 1] = (len & 255).to_byte()
    out[off + 2] = ((len >> 8) & 255).to_byte()
    out[off + 3] = (nlen & 255).to_byte()
    out[off + 4] = ((nlen >> 8) & 255).to_byte()
    off += 5
    for i = 0; i < len; i = i + 1 {
      out[off + i] = raw[start + i]
    }
    off += len
  }
  let adler = pngr_adler32(raw)
  for i = 0; i < 4; i = i + 1 {
    out[off + i] = ((adler >> (24 - 8 * i)) & 255).to_byte()
  }
  Bytes::from_array(out)
}

///|
/// 把一个 chunk（length + type + data + crc）追加到 out，返回写游标。
fn pngr_push_chunk(out : FixedArray[Byte], off : Int, ctype : String, data : Bytes) -> Int {
  let type_bytes = utf8_bytes(ctype)
  let mut o = off
  for i = 0; i < 4; i = i + 1 {
    out[o + i] = ((data.length() >> (24 - 8 * i)) & 255).to_byte()
  }
  o += 4
  for i = 0; i < type_bytes.length(); i = i + 1 {
    out[o + i] = type_bytes[i]
  }
  o += type_bytes.length()
  for i = 0; i < data.length(); i = i + 1 {
    out[o + i] = data[i]
  }
  o += data.length()
  let crc_in = FixedArray::make(type_bytes.length() + data.length(), b'\x00')
  for i = 0; i < type_bytes.length(); i = i + 1 {
    crc_in[i] = type_bytes[i]
  }
  for i = 0; i < data.length(); i = i + 1 {
    crc_in[type_bytes.length() + i] = data[i]
  }
  let crc = pngr_crc32(Bytes::from_array(crc_in))
  for i = 0; i < 4; i = i + 1 {
    out[o + i] = ((crc >> (24 - 8 * i)) & 255).to_byte()
  }
  o + 4
}

///|
/// 把 RGBA 位图编码为 PNG 字节流（8 bit、color type 6、无隔行、stored
/// 压缩）。data 为 width*height*4 字节的行主序 RGBA；尺寸或数据长度
/// 不符给 Err。
pub fn pngr_encode_rgba(data : Bytes, width : Int, height : Int) -> Result[Bytes, String] {
  if width <= 0 || height <= 0 {
    return Err("width/height 必须为正")
  }
  if data.length() != width * height * 4 {
    return Err("data 长度与 width*height*4 不符")
  }
  let raw = pngr_scanlines(data, width, height)
  let idat = pngr_zlib_stored(raw)
  let ihdr = FixedArray::make(13, b'\x00')
  for i = 0; i < 4; i = i + 1 {
    ihdr[i] = ((width >> (24 - 8 * i)) & 255).to_byte()
    ihdr[4 + i] = ((height >> (24 - 8 * i)) & 255).to_byte()
  }
  ihdr[8] = b'\x08'
  ihdr[9] = b'\x06'
  ihdr[10] = b'\x00'
  ihdr[11] = b'\x00'
  ihdr[12] = b'\x00'
  let total = 8 + (4 + 4 + 13 + 4) + (4 + 4 + idat.length() + 4) + (4 + 4 + 4)
  let out = FixedArray::make(total, b'\x00')
  let sig = pngr_sig()
  for i = 0; i < 8; i = i + 1 {
    out[i] = sig[i]
  }
  let mut off = pngr_push_chunk(out, 8, "IHDR", Bytes::from_array(ihdr))
  off = pngr_push_chunk(out, off, "IDAT", idat)
  let _ = pngr_push_chunk(out, off, "IEND", Bytes::new(0))
  Ok(Bytes::from_array(out))
}
