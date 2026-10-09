// 视频帧播放视图：帧源回调按帧号产出 RGBA 字节，经 pngr_encode_rgba
// 中转为 PNG，Image::new_from_png 解码后由 Painter::draw_image 铺满
// 绘制（libyue 的 Image 没有裸像素构造入口，PNG 内存编码是纯 MoonBit
// 的中转通道）。画面推进由 set_timer 驱动；解码器（moonav1 等）作为
// 帧源接入，与本组件解耦。详见 system-capabilities.md「视频播放」。

///|
/// 帧源：帧号（0-based）→ 该帧 RGBA 字节（长度应为 width*height*4）。
pub type VideoFrameSource = (Int) -> Bytes?

///|
/// 帧间隔毫秒（1000/fps，fps<=0 按 1 帧/秒兜底）。
pub fn vid_frame_delay(fps : Int) -> Int {
  if fps < 1 {
    1000
  } else if fps > 1000 {
    1
  } else {
    (1000 + fps - 1) / fps
  }
}

///|
/// 下一帧号：idx+1 < count 给 Some(idx+1)；越界时循环给 Some(0)，非
/// 循环给 None（播放结束）。
pub fn vid_next_frame(idx : Int, count : Int, looping : Bool) -> Int? {
  if count <= 1 {
    None
  } else if idx + 1 < count {
    Some(idx + 1)
  } else if looping {
    Some(0)
  } else {
    None
  }
}

///|
/// 帧字节预期长度（RGBA = 4 字节/像素）。
pub fn vid_rgba_len(width : Int, height : Int) -> Int {
  width * height * 4
}

///|
/// 帧字节 → Image（长度不符 / 编码失败 / 解码失败给 None；调用方画
/// 占位背景）。headless 无 GUI 上下文时 Image 解码恒空图，此时 Image
/// 句柄仍非空——调用方按 is_empty 判定是否可用。
pub fn vid_frame_image(source : VideoFrameSource, idx : Int, width : Int, height : Int) -> Image? {
  match source(idx) {
    Some(bytes) =>
      if bytes.length() == vid_rgba_len(width, height) {
        match pngr_encode_rgba(bytes, width, height) {
          Ok(png) => {
            let img = Image::new_from_png(png)
            if img.is_empty() {
              None
            } else {
              Some(img)
            }
          }
          Err(_) => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
/// 播放句柄：持定时器开关与暂停标记（stop 后定时器下一帧注销）。
pub(all) struct VidHandle {
  running : Ref[Bool]
  paused : Ref[Bool]
}

///|
/// 建播放句柄（默认运行中）。
pub fn VidHandle::make() -> VidHandle {
  { running: Ref(true), paused: Ref(false), }
}

///|
/// 句柄是否运行（定时器存活）。
pub fn VidHandle::is_running(self : VidHandle) -> Bool {
  self.running.val
}

///|
/// 句柄是否处于暂停（定时器存活但不推进帧）。
pub fn VidHandle::is_paused(self : VidHandle) -> Bool {
  self.paused.val
}

///|
/// 暂停/恢复帧推进（句柄仍运行，只停推进）。
pub fn vid_pause(handle : VidHandle) -> Unit {
  handle.paused.val = true
}

///|
pub fn vid_resume(handle : VidHandle) -> Unit {
  handle.paused.val = false
}

///|
/// 停止并注销定时器（不可恢复）。**移除 video_view_t 视图前必须
/// 调用**：定时器无取消 id，只有回调返回 false 才停，漏 stop 会让
/// 帧推进对已销毁的视图空转到播完。
pub fn vid_stop(handle : VidHandle) -> Unit {
  handle.running.val = false
}

///|
/// 视频帧视图：width/height 为帧像素尺寸（视图按 style 拉伸），
/// frame_count/fps 定播放长度与帧率，source 为帧源；loop 默认播到
/// 末帧停止。暂停经句柄 vid_pause/vid_resume；停止后组件应卸载。
/// 帧缺失/解码失败画主题底色占位，不中断播放。
/// ⚠ 生命周期契约：**卸载前必须 vid_stop(handle)**。帧推进定时器
/// 由 libyue SetTimer 驱动（无取消 id，见 app.mbt set_timer），
/// 只有回调返回 false 才停——不先 stop 就移除视图，定时器仍会
/// 对已销毁的视图空转到播完为止。
pub fn video_view_t(
  width : Int,
  height : Int,
  frame_count : Int,
  source : VideoFrameSource,
  fps? : Int = 30,
  looping? : Bool = false,
  handle? : VidHandle = VidHandle::make(),
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  on_ready? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  {
    mount: fn(parent) {
      let idx = Store::new(0)
      let size_style : Array[(String, &StyVal)] = if fill {
        [("height", 320.0)]
      } else {
        [("width", 560.0), ("height", 320.0)]
      }
      for kv in style {
        size_style.push(kv)
      }
      let cv = themed_container(style=size_style)
      on_ready(cv)
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        match vid_frame_image(source, idx.get(), width, height) {
          Some(img) => p.draw_image(img, 0.0, 0.0, b.width, b.height)
          None => {
            p.set_fill_color(theme_bg_panel())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
        }
      })
      idx.subscribe(fn(_i) { ViewLike::schedule_paint(cv) })
      set_timer(vid_frame_delay(fps), fn() {
        if !handle.running.val {
          false
        } else {
          if !handle.paused.val {
            match vid_next_frame(idx.get(), frame_count, looping) {
              Some(next) => idx.set(next)
              None => handle.running.val = false
            }
          }
          true
        }
      })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
