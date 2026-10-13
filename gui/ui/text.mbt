// 文本族首批：文字角色（字号 + 颜色随角色统一）、主题化标签、按宽量高。
//
// §2 合并后 `label_t` 消失：角色排版入口就是 `ui/basic.mbt` 的 `text`
// （`role?` 给了就按 `role_font`/字重折算），`TextRole` 与角色助手住在 `base.mbt`。

///|
/// 量一段文本在指定宽度下的自然渲染高（`width` 传 0 按不换行量）。
/// 运行期长高的标签用显式高度绕开「测量口径不一致」的老坑：容器问到的
/// 自然高与绘制时按盒宽折行算出的高可能不是一回事，显式设高最稳。
pub fn measure_text_height(
  text : String,
  role? : TextRole = Body,
  width? : Double = 0.0,
) -> Double {
  let f = role_font(role)
  let box_w = if width > 0.0 { width.floor().to_int() } else { 0 }
  match @text.measure_font(text, f, max_width=box_w, wrap=box_w > 0) {
    Some(m) => m.height.to_double()
    None => 0.0
  }
}
