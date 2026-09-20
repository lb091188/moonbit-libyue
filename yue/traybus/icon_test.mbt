// 托盘图标纯 MoonBit 部分测试。

///|
test "default_icon_pixmap 尺寸与非空" {
  let (w, h, px) = @traybus.default_icon_pixmap()
  inspect(w, content="32")
  inspect(h, content="32")
  inspect(px.length(), content="4096")
  // 至少有一些非透明像素（金色月牙）
  let mut nontransparent = 0
  for i in 0..<(w * h) {
    if px[i * 4] != 0 {
      nontransparent += 1
    }
  }
  inspect(nontransparent > 100, content="true")
}

///|
test "downscale_pixmap 32 到 16" {
  let (w, h, px) = @traybus.default_icon_pixmap()
  let (nw, nh, npx) = @traybus.downscale_pixmap(w, h, px, 16, 16)
  inspect(nw, content="16")
  inspect(nh, content="16")
  inspect(npx.length(), content="1024")
  // 左上角外圈透明
  inspect(npx[0] == 0, content="true")
  // 中心附近应有内容(月牙本体在偏左上,中心点 8,8 对应原图 16,16 处于月牙环上)
  let mut nontransparent = 0
  for i in 0..<256 {
    if npx[i * 4] != 0 {
      nontransparent += 1
    }
  }
  inspect(nontransparent > 10, content="true")
}
