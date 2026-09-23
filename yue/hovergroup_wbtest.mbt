// hover 组的矩形判定纯函数测试。

///|
test "rect_contains:含边界" {
  let r : RectF = { x: 100.0, y: 200.0, width: 300.0, height: 80.0 }
  inspect(rect_contains(r, 100.0, 200.0), content="true") // 左上角
  inspect(rect_contains(r, 400.0, 280.0), content="true") // 右下角
  inspect(rect_contains(r, 250.0, 240.0), content="true") // 内部
  inspect(rect_contains(r, 99.9, 240.0), content="false") // 左外
  inspect(rect_contains(r, 400.1, 240.0), content="false") // 右外
  inspect(rect_contains(r, 250.0, 199.9), content="false") // 上外
  inspect(rect_contains(r, 250.0, 280.1), content="false") // 下外
}

///|
test "rect_contains:多屏负坐标矩形" {
  let r : RectF = { x: -2560.0, y: 490.0, width: 500.0, height: 400.0 }
  inspect(rect_contains(r, -2560.0, 490.0), content="true")
  inspect(rect_contains(r, -2100.0, 700.0), content="true")
  inspect(rect_contains(r, -2059.9, 700.0), content="false")
  inspect(rect_contains(r, 0.0, 0.0), content="false")
}
