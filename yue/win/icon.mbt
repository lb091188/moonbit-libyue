// 图标加载（W20f）：把「磁盘图标文件」或「已解码像素」转成平台图标句柄。
// 三个消费者——窗口图标（`Window::set_icon`，W20e）、托盘（W20c）、菜单——共用
// 这一层，避免各自重复解码。
//
// 分工：本层只做「来源判定 + 句柄生命周期 + 语义化失败」，字节的解读全在平台桩
// （`yue/win/stub.c` 的图标段）：`.ico`/`.bmp` 走 Win32 原生 `LoadImageW`，
// PNG/JPEG/GIF 走 WIC 内存解码，已解码像素走 32bpp DIB + `CreateIconIndirect`。
// 非 Windows 后端是失败桩（HICON 是 Win32 概念；Linux 托盘走 SNI 的图标名/
// 像素通道），故 `Icon` 在这些平台上恒不可用——调用方按 `Icon::is_valid` 降级。

///|
/// 图标来源格式（按路径扩展名判定）。纯函数，调用方据此选加载路径、测试直接钉。
pub(all) enum IconFormat {
  Ico
  Bmp
  Png
  Jpeg
  Gif
  Other
}

///|
/// 取小写扩展名（不含点）；无扩展名或尾点是点给空串。
fn icon_ext_of(path : String) -> String {
  let bs = @utf8.encode(path)
  let mut dot = -1
  for i = bs.length() - 1; i >= 0; i = i - 1 {
    let c = bs[i].to_int()
    if c == 46 {
      // '.'
      dot = i
      break
    }
    if c == 47 || c == 92 {
      // '/' 或 '\'：路径分隔符先出现，说明尾段没有扩展名
      break
    }
  }
  if dot < 0 || dot == bs.length() - 1 {
    return ""
  }
  @utf8.decode_lossy(bs[dot + 1 :]).to_lower()
}

///|
/// 按扩展名判定图标格式（大小写不敏感）。
pub fn icon_format_of(path : String) -> IconFormat {
  match icon_ext_of(path) {
    "ico" => Ico
    "bmp" => Bmp
    "png" => Png
    "jpg" | "jpeg" => Jpeg
    "gif" => Gif
    _ => Other
  }
}

///|
/// 平台图标句柄（后端表下标；`handle == 0` 表示无效/平台不支持）。
/// 用后调 `Icon::free` 释放；未释放的随进程退出由系统回收。
pub(all) struct Icon {
  mut handle : Int
}

///|
/// 句柄是否有效（0 恒无效——平台不支持或加载失败都落这里）。
pub fn Icon::is_valid(self : Icon) -> Bool {
  self.handle > 0
}

///|
/// 从磁盘文件载入图标。`.ico`/`.bmp` 走平台原生加载，PNG/JPEG/GIF 走平台解码
/// 后端；文件不存在、解码失败或平台不支持时给 None（调用方走降级，不静默）。
/// `size` 给期望边长（像素，0 = 平台默认）。
pub fn load_icon_file(path : String, size? : Int = 0) -> Icon? {
  let h = wm_icon_load_file(@utf8.encode(path), size)
  if h > 0 {
    Some({ handle: h })
  } else {
    None
  }
}

///|
/// 从 PNG/JPEG/GIF/BMP 的内存字节载入（走平台解码后端）。
pub fn load_icon_bytes(data : Bytes) -> Icon? {
  let h = wm_icon_from_png(data, data.length())
  if h > 0 {
    Some({ handle: h })
  } else {
    None
  }
}

///|
/// 从已解码像素建图标。像素口径与 `yue/render` 的 Bitmap 一致：BGRA 小端序、
/// **预乘 alpha**（`CreateIconIndirect` 认预乘，两者逐字节直拷）；`px` 长度需
/// `width*height*4`，尺寸非正或平台不支持给 None。
pub fn icon_from_bgra(px : FixedArray[Byte], width : Int, height : Int) -> Icon? {
  if width <= 0 || height <= 0 || px.length() < width * height * 4 {
    return None
  }
  let h = wm_icon_from_bgra(px, width, height)
  if h > 0 {
    Some({ handle: h })
  } else {
    None
  }
}

///|
/// 释放图标句柄（幂等；释放后 `is_valid` 变 false）。
pub fn Icon::free(self : Icon) -> Unit {
  if self.handle > 0 {
    wm_icon_free(self.handle)
    self.handle = 0
  }
}

///|
/// 当前存活图标数（探针/回归用：句柄表容量与释放对称性）。
pub fn icon_alive_count() -> Int {
  wm_icon_alive()
}
