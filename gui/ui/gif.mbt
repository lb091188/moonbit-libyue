// 动图（GIF）组件：解码留首帧，按每帧时长自转；解不出动图就退回静帧首帧。
//
// 延时走本栈的进程级定时器通道（`@core.set_timeout`，与轮播自转同一条），
// 无宿主时空操作，所以无头测试能自己装通道手动派拍。动图句柄的槽位随
// 声明式回收袋释放（重挂/替换旧代时 `close`），不靠 GC。

///|
/// 动图运行态：外部可读「已换过几帧 / 是否在播」，可暂停与继续。
pub(all) struct GifHandle {
  mut running : Bool
  mut frames : Int
  mut tick : () -> Unit
}

///|
pub fn GifHandle::make(running? : Bool = true) -> GifHandle {
  { running, frames: 0, tick: fn() { () } }
}

///|
/// 已换过的帧数（每成功换一帧加一）。
pub fn GifHandle::frame_count(self : GifHandle) -> Int {
  self.frames
}

///|
pub fn GifHandle::is_running(self : GifHandle) -> Bool {
  self.running
}

///|
/// 暂停：停在当前帧（待触发的那一拍跑完发现没在播就自续断链）。
pub fn GifHandle::pause(self : GifHandle) -> Unit {
  self.running = false
}

///|
/// 继续：从当前帧接着走。
pub fn GifHandle::play(self : GifHandle) -> Unit {
  if !self.running {
    self.running = true
    (self.tick)()
  }
}

///|
/// 动图组件。`width`/`height` 给 0 用动图自身尺寸；`looping=false` 时播完一轮
/// （帧号回到 0）就停。非 GIF 文件也能用：解出来是静图就只画一帧、不排自转。
pub fn gif(
  path : String,
  width? : Double = 0.0,
  height? : Double = 0.0,
  looping? : Bool = true,
  running? : Bool = true,
  state? : GifHandle,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let anim : @render.Animation? = @render.Animation::new_from_file(path)
  let h = match state {
    Some(s) => {
      s.running = running
      s
    }
    None => GifHandle::make(running=running)
  }
  // 首帧在建树时就取好：静图（或解出动图失败）也走这条路，组件永远有一张可画的图
  let keep : Ref[@render.Image] = Ref(match anim {
    Some(a) => a.current()
    None => @render.Image::new_from_file(path)
  })
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let timer : Ref[Int] = Ref(0)
    let looping_ = looping
    // 局部函数不能自引用，走 Ref 间接（与示例里的 ticker 同形）
    let step : Ref[() -> Unit] = Ref(fn() { () })
    step.val = fn() -> Unit {
      timer.val = 0
      match anim {
        None => ()
        Some(a) => {
          if !h.running {
            return
          }
          // 所在页被隐藏（这一帧没被画到）：不推进帧、不置脏，只留着排下一拍
          if !w.is_painted() {
            timer.val = @core.set_timeout(a.delay_ms(), fn() { (step.val)() })
            return
          }
          if a.advance() {
            h.frames = h.frames + 1
            keep.val = a.current()
            @core.invalidate()
          }
          if !looping_ && a.frame() == 0 {
            h.running = false
            return
          }
          timer.val = @core.set_timeout(a.delay_ms(), fn() { (step.val)() })
        }
      }
    }

    h.tick = fn() -> Unit { (step.val)() }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let img = keep.val
      if !img.is_empty() {
        p.flush()
        p.draw_image(img, 0.0, 0.0, r.w, r.h)
      }
    })
    match anim {
      Some(a) => {
        let dw = if width > 0.0 { width } else { a.width.to_double() }
        let dh = if height > 0.0 { height } else { a.height.to_double() }
        w.node.set_width(@yoga.fixed(dw))
        w.node.set_height(@yoga.fixed(dh))
        if !a.is_static && h.running {
          // 排第一拍（静图不排：它没有下一帧）
          timer.val = @core.set_timeout(a.delay_ms(), fn() { (step.val)() })
        }
        // 槽位随本代回收袋释放（重挂/替换时不留悬着的动图句柄）
        @core.sub_bag_register(fn() { a.close() })
      }
      None => {
        if width > 0.0 {
          w.node.set_width(@yoga.fixed(width))
        }
        if height > 0.0 {
          w.node.set_height(@yoga.fixed(height))
        }
      }
    }
    handle(w)
    w
  })
}
