// 混合模式：枚举与旧契约 `yue/painter.mbt` 的 BlendMode 同序同义（前 16 个
// 是 W3C 混合，后 9 个是 Porter-Duff 合成），实现由 Cairo 算子承担；本机实测
// 25 个算子全部生效（pigment 系与 HSL 系含），无需自实现混合算法。

///|
pub(all) enum BlendMode {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  SoftLight
  HardLight
  Difference
  Exclusion
  Hue
  Saturation
  Color
  Luminosity
  Clear
  Copy
  SourceIn
  SourceOut
  SourceAtop
  DestinationOver
  DestinationIn
  DestinationAtop
  Xor
}

///|
/// 传给 C 的枚举序（与 nu::BlendMode 数值直传的口径一致）。
fn blend_mode_id(mode : BlendMode) -> Int {
  match mode {
    Normal => 0
    Multiply => 1
    Screen => 2
    Overlay => 3
    Darken => 4
    Lighten => 5
    ColorDodge => 6
    ColorBurn => 7
    SoftLight => 8
    HardLight => 9
    Difference => 10
    Exclusion => 11
    Hue => 12
    Saturation => 13
    Color => 14
    Luminosity => 15
    Clear => 16
    Copy => 17
    SourceIn => 18
    SourceOut => 19
    SourceAtop => 20
    DestinationOver => 21
    DestinationIn => 22
    DestinationAtop => 23
    Xor => 24
  }
}
