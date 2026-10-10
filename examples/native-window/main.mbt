// MoonBit 原生 GUI 栈 G2-G4 的最小驱动：自建窗口 + 自有像素缓冲 + 循环归
// MoonBit + 两个自绘输入框（焦点栈、Tab 环绕、点击定位光标、caret 闪烁）。
// 每个矩形都由 yue/render 算出并经 yue/win 上屏，与离屏快照同一份字节。
//
// 跑法：moon run examples/native-window（需 X11/显示服务；无显示时打印 SKIP）
// 5 秒后自动退出并打印状态，便于本机冒烟。

///|
priv struct Box {
  ed : @input.Editor
  x : Double
  y : Double
  w : Double
  h : Double
  id : Int
}

// 前缀量宽：caret 的屏幕位置 = 已选字节的文本宽度（与内核同用的字节下标口径）
fn prefix_width(ed : @input.Editor, upto : Int, size : Double) -> Double {
  let w = match @text.measure(ed.get_text_in_range(0, upto), size) {
    Some(m) => m.width
    None => 0
  }
  w.to_double()
}

fn draw_boxes(
  p : @render.Painter,
  boxes : Array[Box],
  focused : Int?,
  blink : Bool,
  size : Double,
) -> Unit {
  let lh = match @text.line_height(size) {
    Some(h) => h.to_double()
    None => size * 1.5
  }
  for b in boxes {
    let is_focus = match focused {
      Some(f) => f == b.id
      None => false
    }
    p.set_fill_color(if is_focus { "#303446" } else { "#26283b" })
    p.fill_rect(b.x, b.y, b.w, b.h)
    p.set_stroke_color(if is_focus { "#89b4fa" } else { "#45475a" })
    p.set_line_width(1.0)
    p.stroke_rect(b.x, b.y, b.w, b.h)
    let _ = @text.draw_to(
      p.bitmap, b.x + 4.0, b.y + (b.h - lh) / 2.0, b.ed.get_text(), size,
      "#cdd6f4",
    )
    if is_focus && blink {
      let cx = b.x + 4.0 + prefix_width(b.ed, b.ed.caret_pos(), size)
      p.set_fill_color("#f5e0dc")
      p.fill_rect(cx, b.y + 4.0, 1.0, b.h - 8.0)
    }
  }
}

fn draw(win : @win.Window, boxes : Array[Box], focused : Int?, blink : Bool, tick : Int) -> Unit {
  let (w, h) = win.size()
  let bm = @render.Bitmap::new(w, h)
  let p = @render.Painter::new(bm)
  let fw = w.to_double()
  let fh = h.to_double()
  p.set_fill_color("#1e1e2e")
  p.fill_rect(0.0, 0.0, fw, fh)
  // 四等分色块：验相邻矩形共用边不留缝
  let bw = fw / 4.0
  let colors = ["#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa"]
  for i = 0; i < 4; i = i + 1 {
    p.set_fill_color(colors[i])
    p.fill_rect(bw * i.to_double(), 0.0, bw, 10.0)
  }
  draw_boxes(p, boxes, focused, blink, 14.0)
  let focus_text = match focused {
    Some(f) => f.to_string()
    None => "-"
  }
  let note = "帧 \{tick} · 焦点 \{focus_text} · Tab 切换、点击可定位光标"
  let _ = @text.draw_to(bm, 24.0, 30.0, note, 12.0, "#a6adc8")
  // Cairo 路径层：验抗锯齿曲线整条链路
  match @render.Cairo::over(bm) {
    Some(c) => {
      c.set_fill_color("#cba6f7")
      c.begin_path()
      c.arc(fw - 70.0, 90.0, 26.0, 0.0, 6.283185307179586)
      c.fill()
      c.end()
    }
    None => ()
  }
  win.present(bm.data, bm.width, bm.height)
}

// 点击定位 caret：逐码点量前缀宽，取「不超过点击点」的最右边界
fn place_caret(b : Box, local_x : Double, size : Double) -> Unit {
  let n = b.ed.byte_len()
  let mut best = 0
  let mut k = 0
  while k < n {
    let next = b.ed.boundary_after(k + 1)
    let wid = prefix_width(b.ed, next, size)
    if wid + 4.0 <= local_x {
      best = next
    }
    if next <= k {
      k = n
    } else {
      k = next
    }
  }
  b.ed.select_range(best, best)
}

///|
fn main {
  if !@win.init_backend() {
    println("NATIVE-WINDOW-SKIP: 本平台无窗口后端或没有显示服务")
    return
  }
  let win = match @win.Window::new(480, 320, "MoonBit 原生窗口 (G4)") {
    Some(w) => w
    None => {
      println("NATIVE-WINDOW-FAIL: 建窗失败")
      return
    }
  }
  win.show()
  win.request_focus()

  let a = @input.Editor::new()
  let _ = a.insert_text("hello")
  let b = @input.Editor::new()
  let _ = b.insert_text("第二个框")
  let boxes : Array[Box] = [
    { ed: a, x: 24.0, y: 60.0, w: 200.0, h: 26.0, id: 1 },
    { ed: b, x: 24.0, y: 96.0, w: 200.0, h: 26.0, id: 2 },
  ]
  let fs = @core.FocusStack::new()
  let _ = fs.register(1)
  let _ = fs.register(2)

  let l = @core.Loop::new()
  l.start(@win.now_ms())
  let frames = Ref(0)
  let blink = Ref(true)
  let dirty = Ref(true)
  let seen = Ref(0)
  let queue_left = Ref(0)

  let ticker : Ref[() -> Unit] = Ref(fn() { () })
  ticker.val = fn() {
    if l.is_running() {
      frames.val = frames.val + 1
      dirty.val = true
      let _ = l.timer(100, ticker.val)
    }
  }
  let blinker : Ref[() -> Unit] = Ref(fn() { () })
  blinker.val = fn() {
    if l.is_running() {
      blink.val = !blink.val
      dirty.val = true
      let _ = l.timer(500, blinker.val)
    }
  }
  let _ = l.timer(100, ticker.val)
  let _ = l.timer(500, blinker.val)
  let _ = l.timer(5000, fn() { l.quit() })

  while l.is_running() {
    let budget = l.wait_budget(@win.now_ms())
    match budget {
      Some(ms) => {
        let _ = @win.wait(ms)
      }
      None => {
        let _ = @win.wait(-1)
      }
    }
    let _ = l.advance(@win.now_ms())
    // 事件全排空
    let mut keep = true
    while keep {
      match win.poll_event() {
        @win.Event::Closing => {
          l.quit()
          keep = false
        }
        @win.Event::NeedsDraw => dirty.val = true
        @win.Event::Resized => dirty.val = true
        @win.Event::Input => {
          seen.val = seen.val + 1
          match win.take_input() {
            Some(ev) => {
              if ev.code == 0 {
                // 键按下
                if ev.keysym == @core.KS_TAB {
                  let _ = fs.move_focus(false)
                  win.request_focus()
                  dirty.val = true
                } else if ev.keysym == @core.KS_ISO_LEFT_TAB {
                  let _ = fs.move_focus(true)
                  win.request_focus()
                  dirty.val = true
                } else {
                  match fs.current() {
                    Some(f) => {
                      let target = boxes[f - 1]
                      if target.ed.handle_key(ev.keysym, ev.mods) {
                        dirty.val = true
                      }
                    }
                    None => ()
                  }
                }
              } else if ev.code == 2 {
                // 按钮按下：命中哪个框就聚焦哪个并定位光标
                let mx = ev.x.to_double()
                let my = ev.y.to_double()
                for bx in boxes {
                  if mx >= bx.x && mx < bx.x + bx.w && my >= bx.y &&
                      my < bx.y + bx.h {
                    let _ = fs.focus(bx.id)
                    win.request_focus()
                    place_caret(bx, mx - bx.x, 14.0)
                    dirty.val = true
                  }
                }
              }
            }
            None => ()
          }
        }
        @win.Event::NoEvent => keep = false
      }
    }
    queue_left.val = win.pending_input()
    if dirty.val {
      dirty.val = false
      draw(win, boxes, fs.current(), blink.val, frames.val)
    }
  }
  win.close()
  println(
    "NATIVE-WINDOW-OK frames=\{frames.val} seen=\{seen.val} queue=\{queue_left.val} a='\{a.get_text()}' b='\{b.get_text()}'",
  )
}
