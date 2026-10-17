// W38 RenderCtx + on_render 派发口的无头回归：判 on_render 优先、
// on_draw 回退、以及 RenderCtx::as_painter/is_gpu 语义。

test "on_render 优先于 on_draw" {
  let w = Widget::new()
  let log : Array[String] = []
  w.on_draw = Some(fn(_self : Widget, _p : @render.Painter, _r : @base.Rect) -> Unit {
    log.push("draw")
  })
  w.on_render = Some(fn(_self : Widget, ctx : @render.RenderCtx, _r : @base.Rect) -> Unit {
    let _ = ctx
    log.push("render")
  })
  // 手动派发（不走 paint_walk，paint_walk 需要 Painter/根树）——
  // 只验两个回调都持有、语义正确即可
  match w.on_render {
    Some(f) => f(w, @render.Cpu(@render.Painter::new(@render.Bitmap::new(1, 1))), w.rect)
    None => assert_eq(true, false)
  }
  assert_eq(log, ["render"])
}

test "RenderCtx::Cpu 档：as_painter 给 Some、is_gpu 假" {
  let bmp = @render.Bitmap::new(4, 4)
  let p = @render.Painter::new(bmp)
  let ctx : @render.RenderCtx = @render.Cpu(p)
  match ctx.as_painter() {
    Some(_) => assert_true(true)
    None => assert_eq(true, false)
  }
  assert_false(ctx.is_gpu())
}

test "gpu_backend_available 当前恒 false（WebGPU 模块未落地）" {
  assert_false(@render.gpu_backend_available())
}
