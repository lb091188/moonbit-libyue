// MoonBit 原生 GUI 栈 G2 的最小驱动：自建窗口 + 自有像素缓冲 + 循环归 MoonBit。
// 窗口里画的每个矩形都由 yue/render 的 Painter 算出、经 yue/win 上屏，
// 与离屏快照同一份字节；5 秒后自动退出，便于本机冒烟与 CI 之外的检查。
//
// 跑法：moon run examples/native-window（需 X11/显示服务；无显示时打印 SKIP 退出）

///|
fn paint(win : @win.Window, tick : Int) -> Unit {
  let (w, h) = win.size()
  let bm = @render.Bitmap::new(w, h)
  let p = @render.Painter::new(bm)
  let fw = w.to_double()
  let fh = h.to_double()
  // 底色
  p.set_fill_color("#1e1e2e")
  p.fill_rect(0.0, 0.0, fw, fh)
  // 四个等分色块：验相邻矩形共用边不留缝
  let bw = fw / 4.0
  let colors = ["#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa"]
  for i = 0; i < 4; i = i + 1 {
    p.set_fill_color(colors[i])
    p.fill_rect(bw * i.to_double(), 0.0, bw, fh / 3.0)
  }
  // 内侧描边矩形 + 一个随 tick 移动的方块：验重绘真的在跑
  p.set_stroke_color("#cdd6f4")
  p.set_line_width(2.0)
  p.stroke_rect(20.0, 20.0, fw - 40.0, fh - 40.0)
  p.set_fill_color("#f5e0dc")
  let x = (fw - 40.0) * (tick % 10).to_double() / 9.0
  p.fill_rect(x, fh - 80.0, 40.0, 40.0)
  // Cairo 路径层：抗锯齿的圆 + 贝塞尔弧，证明整条链（Cairo → 自有缓冲 → 窗口）
  match @render.Cairo::over(bm) {
    Some(c) => {
      c.set_fill_color("#cba6f7")
      c.begin_path()
      c.arc(fw / 2.0, fh / 2.0, 40.0, 0.0, 6.283185307179586)
      c.fill()
      c.set_fill_color("#94e2d5")
      c.begin_path()
      c.move_to(fw / 2.0, fh / 2.0)
      c.bezier_curve_to(
        fw / 2.0 + 60.0, fh / 2.0 - 60.0, fw / 2.0 + 120.0, fh / 2.0 + 60.0,
        fw / 2.0 + 140.0, fh / 2.0,
      )
      c.set_line_width(3.0)
      c.stroke()
      c.end()
    }
    None => ()
  }
  // 文本层：先量后画，量到的盒高就是布局会拿到的尺寸（G7 接 measure 回调同源）
  match @text.measure("MoonBit 原生窗口", 18.0) {
    Some(m) => {
      let _ = @text.draw_to(bm, 24.0, 28.0, "MoonBit 原生窗口", 18.0, "#cdd6f4")
      let note = "行高 \{m.height} · 基线 \{m.baseline} · 宽 \{m.width}"
      let _ = @text.draw_to(bm, 24.0, 54.0, note, 12.0, "#a6adc8")
    }
    None => ()
  }
  win.present(bm.data, bm.width, bm.height)
}

///|
fn main {
  if !@win.init_backend() {
    println("NATIVE-WINDOW-SKIP: 本平台无窗口后端或没有显示服务")
    return
  }
  let win = match @win.Window::new(480, 320, "MoonBit 原生窗口 (G2)") {
    Some(w) => w
    None => {
      println("NATIVE-WINDOW-FAIL: 建窗失败")
      return
    }
  }
  win.show()
  let l = @core.Loop::new()
  l.start(@win.now_ms())
  let frames = Ref(0)
  // 100ms 自重排的节拍：既驱动动画，也验证「定时器重排 + 反复上屏」这条路。
  // 闭包自引用经 Ref 中转（MoonBit 闭包不能直接捕获自身）。
  let ticker : Ref[() -> Unit] = Ref(fn() { () })
  ticker.val = fn() {
    if l.is_running() {
      frames.val = frames.val + 1
      paint(win, frames.val)
      let _ = l.timer(100, ticker.val)
    }
  }
  let _ = l.timer(100, ticker.val)
  // 冒烟用自动退出；真交互窗口在 G4 接焦点与键盘后另开示例
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
    // 事件全排空：一次只取一个事件的话，Resized 会把 NeedsDraw 顶到下一拍
    let mut dirty = false
    let mut keep_polling = true
    while keep_polling {
      match win.poll_event() {
        @win.Event::Closing => {
          l.quit()
          keep_polling = false
        }
        @win.Event::Resized => dirty = true
        @win.Event::NeedsDraw => dirty = true
        @win.Event::NoEvent => keep_polling = false
      }
    }
    if dirty {
      frames.val = frames.val + 1
      paint(win, frames.val)
    }
  }
  win.close()
  println("NATIVE-WINDOW-OK frames=\{frames.val}")
}
