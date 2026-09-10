// 程序生成的托盘图标：不依赖任何图片资源与解码器。
// 月牙造型（本仓库是 MoonBit 封装），2x2 超采样抗锯齿，
// 输出 SNI 规范要求的 ARGB 大端序位图。

///|
/// 默认托盘图标：32×32 月牙，返回 (宽, 高, ARGB 字节)。
pub fn default_icon_pixmap() -> (Int, Int, Bytes) {
  let w = 32
  let h = 32
  let px : FixedArray[Byte] = FixedArray::make(w * h * 4, b'\x00')
  // 外圆与偏移的挖空圆构成月牙
  let cx = 16.0
  let cy = 16.0
  let r_out = 13.0
  let ix = 22.0
  let iy = 12.0
  let r_in = 12.0
  for y in 0..<h {
    for x in 0..<w {
      let mut hit = 0.0
      for sy in 0..<2 {
        for sx in 0..<2 {
          let px = x.to_double() + 0.25 + sx.to_double() * 0.5
          let py = y.to_double() + 0.25 + sy.to_double() * 0.5
          let d_out = (px - cx) * (px - cx) + (py - cy) * (py - cy)
          let d_in = (px - ix) * (px - ix) + (py - iy) * (py - iy)
          if d_out <= r_out * r_out && d_in > r_in * r_in {
            hit += 1.0
          }
        }
      }
      if hit > 0.0 {
        let a = (hit / 4.0 * 255.0).to_int()
        let off = (y * w + x) * 4
        // 大端序 AARRGGBB
        px[off] = a.to_byte()
        px[off + 1] = (0xE8).to_byte() // R
        px[off + 2] = (0xB3).to_byte() // G
        px[off + 3] = (0x4B).to_byte() // B
      }
    }
  }
  (w, h, Bytes::makei(w * h * 4, fn(i) { px[i] }))
}
