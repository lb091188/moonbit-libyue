// W38 渲染上下文：CPU 路径的现在形态 + GPU 路径的扩展口子。
// on_draw 保持 Painter 签名向后兼容；要接 3D/GPU 的控件走 on_render(ctx)。
// 将来 WebGPU 后端落地时只扩 enum，不改 Widget 协议。

///|
/// 绘制上下文（渲染路径的分派点）：
/// - `Cpu(painter)`：软件光栅 / Cairo 光栅，控件走 Painter API；
/// - `Gpu(gpu)`（预留）：GPU 合成 / 3D 场景，控件拿 GPU context 提交纹理与绘制指令。
pub(all) enum RenderCtx {
  Cpu(Painter)
  // Gpu(GpuContext)  // WebGPU 后端落地后打开
}

///|
/// 取上下文里的 CPU Painter（GPU 档返回 None）。
pub fn RenderCtx::as_painter(self : RenderCtx) -> Painter? {
  match self {
    Cpu(p) => Some(p)
  }
}

///|
/// 是否走 GPU 路径（当前恒 false，为上层控件预留判定分支）。
pub fn RenderCtx::is_gpu(self : RenderCtx) -> Bool {
  match self {
    Cpu(_) => false
  }
}

///|
/// 当前窗是否可用 GPU 后端（探测函数，WebGPU 模块落地前恒 false）。
pub fn gpu_backend_available() -> Bool {
  false
}
