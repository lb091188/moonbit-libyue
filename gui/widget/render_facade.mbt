// W35 绘图门面：在 widget 包对外 re-export @render 的公共绘制类型，
// 让 `on_draw` 回调的 Painter / Color / Gradient 等不需要单独 import render。
// 方法调用走实例（`p.fill_rect(...)`）不依赖包名；静态构造走 @render 路径
// 或 `@widget.Painter`（别名解析到同一定义）。

///|
pub type Painter = @render.Painter
pub type Color = @render.Color
pub type Bitmap = @render.Bitmap
pub type Gradient = @render.Gradient
pub type Canvas = @render.Canvas
pub type Image = @render.Image
pub type ImageSlot = @render.ImageSlot
pub type Animation = @render.Animation
