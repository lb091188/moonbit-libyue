// 几何族纯 MoonBit 部分测试。

///|
test "RectF contains/center/enlarge/shrink" {
  let r : RectF = { x: 10.0, y: 20.0, width: 100.0, height: 50.0, }
  inspect(r.contains({ x: 10.0, y: 20.0, }), content="true")
  inspect(r.contains({ x: 109.9, y: 69.9, }), content="true")
  inspect(r.contains({ x: 110.0, y: 40.0, }), content="false")
  let c = r.center()
  inspect(c.x, content="60")
  inspect(c.y, content="45")
  let big = r.enlarge({ left: 5.0, top: 6.0, right: 7.0, bottom: 8.0, })
  inspect(big.x, content="5")
  inspect(big.y, content="14")
  inspect(big.width, content="112")
  inspect(big.height, content="64")
  let small = big.shrink({ left: 5.0, top: 6.0, right: 7.0, bottom: 8.0, })
  inspect(small.width, content="100")
  inspect(small.height, content="50")
  // 过缩时钳到 0
  let tiny = r.shrink({ left: 60.0, top: 0.0, right: 60.0, bottom: 0.0, })
  inspect(tiny.width, content="0")
}

///|
test "RectF union 与 SizeF add" {
  let a : RectF = { x: 0.0, y: 0.0, width: 10.0, height: 10.0, }
  let b : RectF = { x: 20.0, y: 5.0, width: 10.0, height: 10.0, }
  let u = a.union(b)
  inspect(u.x, content="0")
  inspect(u.y, content="0")
  inspect(u.width, content="30")
  inspect(u.height, content="15")
  let sz0 : SizeF = { width: 3.0, height: 4.0, }
  let sz = sz0.add({ width: 1.0, height: 2.0, })
  inspect(sz.width, content="4")
  inspect(sz.height, content="6")
}
