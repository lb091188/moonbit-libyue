///|
/// CRC32 / Adler32 已知答案（zlib 标准："123456789"）。
test "checksum 已知答案：CRC32/Adler32 of 123456789" {
  let v = @utf8.encode("123456789")
  // 0xCBF43926 的 32 位有符号视角
  inspect(pngr_crc32(v), content="-873187034")
  // 0x91E01DE
  inspect(pngr_adler32(v), content="152961502")
}

///|
/// 1x1 像素 PNG 的字节级自校验（headless 测试环境无 GUI 上下文，
/// Image::new_from_png 恒空，故按容器结构逐段断言；真机解码验证走
/// systemprobe 示例）。
test "png_encode_rgba：1x1 容器结构自校验" {
  let px = FixedArray::make(4, b'\x00')
  px[0] = b'\xF0'
  px[1] = b'\xF0'
  px[2] = b'\xF0'
  px[3] = b'\xFF'
  let png = match png_encode_rgba(Bytes::from_array(px), 1, 1) {
    Ok(b) => b
    Err(e) => fail("编码失败：\{e}")
  }
  // 签名
  inspect(png[0].to_int() == 0x89 && png[1].to_int() == 0x50, content="true")
  inspect(png[2].to_int() == 0x4E && png[3].to_int() == 0x47, content="true")
  // IHDR：length=13、type、width=1 BE、height=1 BE、bitdepth 8、colortype 6
  inspect(
    png[8].to_int() == 0 &&
    png[9].to_int() == 0 &&
    png[10].to_int() == 0 &&
    png[11].to_int() == 13,
    content="true",
  )
  inspect(png[12] == b"I"[0] && png[13] == b"H"[0], content="true")
  inspect(
    png[16].to_int() == 0 &&
    png[17].to_int() == 0 &&
    png[18].to_int() == 0 &&
    png[19].to_int() == 1,
    content="true",
  )
  inspect(
    png[20].to_int() == 0 &&
    png[21].to_int() == 0 &&
    png[22].to_int() == 0 &&
    png[23].to_int() == 1,
    content="true",
  )
  inspect(png[24].to_int() == 8, content="true")
  inspect(png[25].to_int() == 6, content="true")
  // IDAT：zlib 头 0x78 0x01（stored 压缩），3 字节 BFINAL+LEN+NLEN 头
  // 总长度自洽：8 + 25(IHDR) + 12+len(IDAT) + 12(IEND)
  let raw_len = 5 // 1 行= filter 1 + RGBA 4
  let idat_len = 2 + 5 + raw_len + 4 // zlib 头 + 存块头 + raw + adler
  inspect(png.length(), content="\{8 + 25 + 12 + idat_len + 12}")
  let iend_off = 8 + 25 + 12 + idat_len
  inspect(
    png[iend_off + 4] == b"I"[0] && png[iend_off + 5] == b"E"[0],
    content="true",
  )
  // IDAT 尾部 = adler32(scanlines) BE；scanlines = 00 FF FF FF FF
  let sl = FixedArray::make(5, b'\x00')
  sl[1] = b'\xF0'
  sl[2] = b'\xF0'
  sl[3] = b'\xF0'
  sl[4] = b'\xFF'
  let adler = pngr_adler32(Bytes::from_array(sl))
  let idat_tail = 8 + 25 + 8 + idat_len - 4 // IDAT data 尾部 - 4
  inspect(
    ((adler >> 24) & 255).to_byte() == png[idat_tail] &&
    ((adler >> 16) & 255).to_byte() == png[idat_tail + 1],
    content="true",
  )
}

///|
/// 4x4 棋盘：容器长度与 IDAT stored 块数自洽（raw=4*(1+16)=68 单块）。
test "png_encode_rgba：4x4 长度自洽" {
  let px = FixedArray::make(4 * 4 * 4, b'\x7F')
  let png = match png_encode_rgba(Bytes::from_array(px), 4, 4) {
    Ok(b) => b
    Err(e) => fail("编码失败：\{e}")
  }
  let raw_len = 4 * (1 + 4 * 4)
  let idat_len = 2 + 5 + raw_len + 4
  inspect(png.length(), content="\{8 + 25 + 12 + idat_len + 12}")
}

///|
/// 多 stored 块大图（扫描流 80200 字节 > 65535 → 2 块）。
test "png_encode_rgba：多 stored 块长度自洽" {
  let px = FixedArray::make(200 * 100 * 4, b'\x80')
  let png = match png_encode_rgba(Bytes::from_array(px), 200, 100) {
    Ok(b) => b
    Err(e) => fail("编码失败：\{e}")
  }
  let raw_len = 100 * (1 + 200 * 4)
  let blocks = (raw_len + 65534) / 65535
  inspect(blocks, content="2")
  let idat_len = 2 + blocks * 5 + raw_len + 4
  inspect(png.length(), content="\{8 + 25 + 12 + idat_len + 12}")
}

///|
/// 半透明渐变帧（16x16）长度自洽。
test "png_encode_rgba：渐变帧长度自洽" {
  let w = 16
  let h = 16
  let px = FixedArray::make(w * h * 4, b'\x33')
  let png = match png_encode_rgba(Bytes::from_array(px), w, h) {
    Ok(b) => b
    Err(e) => fail("编码失败：\{e}")
  }
  let raw_len = h * (1 + w * 4)
  let idat_len = 2 + 5 + raw_len + 4
  inspect(png.length(), content="\{8 + 25 + 12 + idat_len + 12}")
}

///|
/// 非法参数给 Err（尺寸零 / 数据长度不符）。
test "png_encode_rgba：非法参数给 Err" {
  match png_encode_rgba(@utf8.encode("x"), 2, 2) {
    Ok(_) => fail("长度不符应给 Err")
    Err(_) => ()
  }
  match png_encode_rgba(@utf8.encode("x"), 0, 1) {
    Ok(_) => fail("零尺寸应给 Err")
    Err(_) => ()
  }
}
