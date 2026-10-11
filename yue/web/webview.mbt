///|
/// webview 引擎在位探测：Linux 需要发行版提供 webkit2gtk-4.1（动态链），缺包或
/// 非 Linux 平台返回 false。调用方据此换一份自绘的降级内容，而不是等加载失败——
/// 「探测 + 语义化降级」是本栈每条能力都走的形态（沿用 `yue/sys` 的范式）。
pub fn webview_supported() -> Bool {
  wb_available() == 1
}

///|
/// 一扇窗里的一个 webview 区（pane）。owner = 原生子件：它占一块由 yoga 算出的
/// 矩形，矩形内是 WebKit 自己画的，我们的 Painter 不参与，也不被 `clip_rect` 裁。
pub(all) struct Webview {
  app : @core.App
  mut surface : @win.ChildSurface?
  mut handle : Int64
  mut url : String
  /// 上一次同步给子件的矩形（相同就不重复走一遍 FFI）
  mut last_rect : (Double, Double, Double, Double)
}

///|
/// 建一个 webview pane 并给出起始 URL。引擎不可用返回 None（调用方降级）。
/// 此刻还没有矩形（要等布局），页面在第一次绘制时随子件槽一起挂上。
pub fn webview_new(app : @core.App, url : String) -> Webview? {
  if !webview_supported() {
    return None
  }
  Some({
    app,
    surface: None,
    handle: 0L,
    url,
    last_rect: (0.0, 0.0, 0.0, 0.0),
  })
}

///|
fn wb_str(f : (Int64, Bytes, Int) -> Int, id : Int64) -> String {
  let cap = 256
  let buf = Bytes::new(cap)
  let n = f(id, buf, cap)
  if n <= 0 {
    ""
  } else {
    let keep = if n > cap - 1 { cap - 1 } else { n }
    @utf8.decode_lossy(buf[0:keep])
  }
}

///|
/// 矩形同步的纯规则：布局给的是 Double，子件槽要的是整数像素，**四舍五入**
/// （截断会让 0.6px 的漂移每帧都算「变了」，每帧多走一遍 FFI 与一次重排）。
pub fn webview_rect_key(
  rect : (Double, Double, Double, Double),
) -> (Int, Int, Int, Int) {
  (
    rect.0.round().to_int(),
    rect.1.round().to_int(),
    rect.2.round().to_int(),
    rect.3.round().to_int(),
  )
}

///|
/// 把布局算出的矩形同步给子件（窗口内容坐标）。每帧调用，位置没动不重复走 FFI。
fn Webview::sync_rect(self : Webview, rect : (Double, Double, Double, Double)) -> Unit {
  let same = {
    let a = webview_rect_key(self.last_rect)
    let b = webview_rect_key(rect)
    a == b
  }
  if same {
    return
  }
  self.last_rect = rect
  match self.surface {
    None => ()
    Some(s) => {
      s.set_rect(rect)
      let k = webview_rect_key(rect)
      wb_set_size(self.handle, k.2, k.3)
    }
  }
}

///|
/// 挂进布局的节点：`grow` 为真时吃掉父容器的剩余空间（Tauri-like 的整页形态），
/// 否则按 `width`/`height` 定尺寸（左右分栏里页面区通常也是 grow 的那一侧）。
pub fn Webview::node(
  self : Webview,
  width? : Double = 0.0,
  height? : Double = 0.0,
  grow? : Double = 0.0,
) -> @core.Node {
  @core.node_of_new(fn(parent : @core.Widget) -> @core.Widget {
    let w = @core.Widget::new()
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    }
    if height > 0.0 {
      w.node.set_height(@yoga.fixed(height))
    }
    if grow > 0.0 {
      w.node.set_flex_grow(grow)
    }
    w.on_draw = Some(fn(self_w : @core.Widget, _p : @render.Painter, _r : @core.Rect) -> Unit {
      let r = (self_w.rect.x, self_w.rect.y, self_w.rect.w, self_w.rect.h)
      if self.surface is None && r.2 > 1.0 && r.3 > 1.0 {
        self.mount_at(r)
      } else {
        self.sync_rect(r)
      }
    })
    parent.append_child(w)
    w
  })
}

///|
/// 第一次拿到真实矩形时挂子件槽并把页面装进去。
fn Webview::mount_at(self : Webview, rect : (Double, Double, Double, Double)) -> Unit {
  let k = webview_rect_key(rect)
  match self.app.window.mount_child_surface(@win.Webview, rect) {
    None => ()
    Some(s) => {
      self.surface = Some(s)
      self.handle = wb_create(s.handle(), k.2, k.3, @utf8.encode(self.url))
      self.last_rect = rect
    }
  }
}

///|
/// 导航到新地址（未挂载时先记下，挂载即加载）。
pub fn Webview::load_url(self : Webview, url : String) -> Unit {
  self.url = url
  match self.surface {
    None => ()
    Some(_) => wb_load_uri(self.handle, @utf8.encode(url))
  }
}

///|
pub fn Webview::reload(self : Webview) -> Unit {
  if self.handle != 0L {
    wb_reload(self.handle)
  }
}

///|
pub fn Webview::stop(self : Webview) -> Unit {
  if self.handle != 0L {
    wb_stop(self.handle)
  }
}

///|
/// 当前地址与标题（未挂载/还没解析出来时给空串）。
pub fn Webview::current_url(self : Webview) -> String {
  if self.handle == 0L {
    ""
  } else {
    wb_str(wb_uri, self.handle)
  }
}

///|
pub fn Webview::get_title(self : Webview) -> String {
  if self.handle == 0L {
    ""
  } else {
    wb_str(wb_title, self.handle)
  }
}

///|
pub fn Webview::is_loading(self : Webview) -> Bool {
  self.handle != 0L && wb_is_loading(self.handle) == 1
}

///|
/// 拆掉页面与子件槽（幂等）。窗口拆除时子件槽由窗口层一并回收，这里只保证
/// 自己先摘，不留悬垂句柄。
pub fn Webview::close(self : Webview) -> Unit {
  if self.handle != 0L {
    wb_destroy(self.handle)
    self.handle = 0L
  }
  match self.surface {
    Some(s) => s.unmount()
    None => ()
  }
  self.surface = None
}
