// 地图与飞线白盒测试：GeoJSON 解析（FeatureCollection/Feature/Polygon/
// MultiPolygon 与错误分支）、等距圆柱投影、包围盒/质心/布局适配、飞线
// 控制点与二次贝塞尔采样。样例为手写 GeoJSON 片段（含整数坐标与 \uXXXX
// 转义的区域名）；绘制函数保证可编译（真实绘制走 on_draw，由用户真机
// 验证）。

///|
/// FeatureCollection 实测形态样例：Polygon（整数坐标）/ MultiPolygon /
/// 无 name 的 Polygon / null geometry 的 Feature（应跳过）。
fn geo_sample_fc() -> String {
  "{\"type\":\"FeatureCollection\",\"features\":[" +
  "{\"type\":\"Feature\",\"properties\":{\"name\":\"\\u5317\\u4eac\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[116,39],[117,40],[115,40],[116,39]]]}}," +
  "{\"type\":\"Feature\",\"properties\":{\"name\":\"sh\"},\"geometry\":{\"type\":\"MultiPolygon\",\"coordinates\":[[[[121,31],[122,31],[121,32],[121,31]]],[[[117,23],[118,23],[117,24],[117,23]]]]}}," +
  "{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[0,1],[0,0]]]}}," +
  "{\"type\":\"Feature\",\"properties\":{\"name\":\"gz\"},\"geometry\":null}" +
  "]}"
}

///|
test "geojson_parse：FeatureCollection 的区域/名称/环序" {
  match geojson_parse(geo_sample_fc()) {
    Ok(regions) => {
      // null geometry 的 Feature 跳过 → 3 个区域
      assert_eq(regions.length(), 3)
      assert_eq(regions[0].name, Some("北京"))
      // \uXXXX 转义的中文区域名由底层解析器还原
      assert_eq(regions[0].rings.length(), 1)
      assert_eq(regions[0].rings[0].length(), 4)
      // 整数坐标（116/39）也按数值入环
      assert_true((regions[0].rings[0][0].0 - 116.0).abs() < 1.0e-9)
      assert_true((regions[0].rings[0][0].1 - 39.0).abs() < 1.0e-9)
      assert_eq(regions[1].name, Some("sh"))
      // MultiPolygon 两个多边形的环按顺序拼接
      assert_eq(regions[1].rings.length(), 2)
      assert_eq(regions[1].rings[0][0], (121.0, 31.0))
      assert_eq(regions[1].rings[1][0], (117.0, 23.0))
      // properties 无 name → 名称 None（不是空串）
      match regions[2].name {
        Some(_) => assert_true(false)
        None => assert_true(true)
      }
      assert_eq(regions[2].rings.length(), 1)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "geojson_parse：Feature 根 / 裸 Polygon / 裸 MultiPolygon" {
  match
    geojson_parse(
      "{\"type\":\"Feature\",\"properties\":{\"name\":\"gz\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[113,23],[114,23],[113,24],[113,23]]]}}",
    ) {
    Ok(regions) => {
      assert_eq(regions.length(), 1)
      assert_eq(regions[0].name, Some("gz"))
      assert_eq(regions[0].rings.length(), 1)
    }
    Err(_) => assert_true(false)
  }
  // 裸几何无名称；MultiPolygon 两环
  match
    geojson_parse(
      "{\"type\":\"MultiPolygon\",\"coordinates\":[[[[0,0],[1,0],[0,1],[0,0]]],[[[5,5],[6,5],[5,6],[5,5]]]]}",
    ) {
    Ok(regions) => {
      assert_eq(regions.length(), 1)
      match regions[0].name {
        Some(_) => assert_true(false)
        None => assert_true(true)
      }
      assert_eq(regions[0].rings.length(), 2)
    }
    Err(_) => assert_true(false)
  }
  // 单个 Feature 且 geometry 为 null → 空表（合法 GeoJSON）
  match
    geojson_parse("{\"type\":\"Feature\",\"properties\":{},\"geometry\":null}") {
    Ok(regions) => assert_eq(regions.length(), 0)
    Err(_) => assert_true(false)
  }
}

///|
test "geojson_parse：错误分支（InvalidJson / UnknownRoot / BadGeometry）" {
  // 语法错误与尾随内容
  match geojson_parse("{\"type\":") {
    Err(InvalidJson) => assert_true(true)
    _ => assert_true(false)
  }
  match geojson_parse("{\"type\":\"Polygon\"}{}") {
    Err(InvalidJson) => assert_true(true)
    _ => assert_true(false)
  }
  // 不可识别的根类型（含无 type）
  match geojson_parse("{\"type\":\"Point\",\"coordinates\":[1,2]}") {
    Err(UnknownRoot) => assert_true(true)
    _ => assert_true(false)
  }
  match geojson_parse("{\"foo\":1}") {
    Err(UnknownRoot) => assert_true(true)
    _ => assert_true(false)
  }
  // FeatureCollection 缺 features 数组
  match geojson_parse("{\"type\":\"FeatureCollection\"}") {
    Err(BadGeometry) => assert_true(true)
    _ => assert_true(false)
  }
  // 环点数 < 3
  match
    geojson_parse(
      "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"x\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[1,2],[3,4]]]}}]}",
    ) {
    Err(BadGeometry) => assert_true(true)
    _ => assert_true(false)
  }
  // 坐标含非数值
  match
    geojson_parse(
      "{\"type\":\"Polygon\",\"coordinates\":[[[\"a\",2],[3,4],[5,6],[1,2]]]}",
    ) {
    Err(BadGeometry) => assert_true(true)
    _ => assert_true(false)
  }
  // 非多边形几何（LineString）→ BadGeometry
  match
    geojson_parse(
      "{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1]]}}",
    ) {
    Err(BadGeometry) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "geojson_parse：空 features / 空白与换行容忍" {
  match geojson_parse("{\"type\":\"FeatureCollection\",\"features\":[]}") {
    Ok(regions) => assert_eq(regions.length(), 0)
    Err(_) => assert_true(false)
  }
  let spaced = "{\n  \"type\" : \"FeatureCollection\",\n  \"features\" : [ {\n    \"type\" : \"Feature\",\n    \"properties\" : { \"name\" : \"nl\" },\n    \"geometry\" : { \"type\" : \"Polygon\", \"coordinates\" : [ [ [ 1.0e1, 2.5e0 ], [ 1.2e1, 3 ], [ 11, 3 ], [ 10, 2.5 ] ] ] }\n  } ]\n}"
  match geojson_parse(spaced) {
    Ok(regions) => {
      assert_eq(regions.length(), 1)
      assert_eq(regions[0].name, Some("nl"))
      // 指数记数法坐标（1.0e1 = 10、2.5e0 = 2.5）
      assert_true((regions[0].rings[0][0].0 - 10.0).abs() < 1.0e-9)
      assert_true((regions[0].rings[0][0].1 - 2.5).abs() < 1.0e-9)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "geo_project：等距圆柱线性映射与越界钳制" {
  let rect : @yue.RectF = { x: 10.0, y: 20.0, width: 360.0, height: 180.0, }
  // 经纬度原点 → 绘制区中心
  let (cx, cy) = geo_project(0.0, 0.0, rect)
  assert_true((cx - 190.0).abs() < 1.0e-9)
  assert_true((cy - 110.0).abs() < 1.0e-9)
  // 四角：左上 = (-180, 90)，右下 = (180, -90)
  let (lx, ty) = geo_project(-180.0, 90.0, rect)
  assert_true((lx - 10.0).abs() < 1.0e-9)
  assert_true((ty - 20.0).abs() < 1.0e-9)
  let (rx, by) = geo_project(180.0, -90.0, rect)
  assert_true((rx - 370.0).abs() < 1.0e-9)
  assert_true((by - 200.0).abs() < 1.0e-9)
  // 一般点：lon -90 → 左+1/4，lat 45 → 上+1/4
  let (qx, qy) = geo_project(-90.0, 45.0, rect)
  assert_true((qx - 100.0).abs() < 1.0e-9)
  assert_true((qy - 65.0).abs() < 1.0e-9)
  // 越界钳制到绘制区内（不逃出 rect）
  let (ox, oy) = geo_project(200.0, -100.0, rect)
  assert_true((ox - 370.0).abs() < 1.0e-9)
  assert_true((oy - 200.0).abs() < 1.0e-9)
}

///|
test "geo_bbox / geo_fit_rect：包围盒与等比适配" {
  assert_true(geo_bbox([]) is None)
  assert_true(geo_bbox_points([]) is None)
  let regions = geojson_parse(geo_sample_fc()).unwrap()
  match geo_bbox(regions) {
    Some((x0, y0, x1, y1)) => {
      // 覆盖全部样例点：经度 0..122、纬度 0..40
      assert_true((x0 - 0.0).abs() < 1.0e-9)
      assert_true((y0 - 0.0).abs() < 1.0e-9)
      assert_true((x1 - 122.0).abs() < 1.0e-9)
      assert_true((y1 - 40.0).abs() < 1.0e-9)
    }
    None => assert_true(false)
  }
  // 等比适配：w 为短边（宽向占满），纵向往中心留白
  let fit = geo_fit_rect((0.0, 0.0, 360.0, 180.0), 536.0, 336.0)
  assert_true((fit.x - 0.0).abs() < 1.0e-9)
  assert_true((fit.width - 536.0).abs() < 1.0e-9)
  assert_true((fit.height - 268.0).abs() < 1.0e-9)
  assert_true((fit.y - 34.0).abs() < 1.0e-9)
  // h 为短边：纵向往中心收
  let fit2 = geo_fit_rect((0.0, 0.0, 360.0, 180.0), 720.0, 180.0)
  assert_true((fit2.height - 180.0).abs() < 1.0e-9)
  assert_true((fit2.width - 360.0).abs() < 1.0e-9)
  assert_true((fit2.x - 180.0).abs() < 1.0e-9)
  // 退化轴给 1 度最小跨度：bw=bh=1（1:1），短边 h=50 定缩放 → 50×50 横向居中
  let fit3 = geo_fit_rect((5.0, 5.0, 5.0, 5.0), 100.0, 50.0)
  assert_true((fit3.width - 50.0).abs() < 1.0e-9)
  assert_true((fit3.height - 50.0).abs() < 1.0e-9)
  assert_true((fit3.x - 25.0).abs() < 1.0e-9)
  assert_true((fit3.y - 0.0).abs() < 1.0e-9)
}

///|
test "geo_map_layout / geo_label_fits：边距、收敛与标签落位" {
  let lay = geo_map_layout(560.0, 360.0)
  assert_true((lay.x - 12.0).abs() < 1.0e-9)
  assert_true((lay.y - 12.0).abs() < 1.0e-9)
  assert_true((lay.width - 536.0).abs() < 1.0e-9)
  assert_true((lay.height - 336.0).abs() < 1.0e-9)
  // 画布过窄：边距收敛到半宽，绘制区最小 1px
  let narrow = geo_map_layout(10.0, 360.0)
  assert_true((narrow.x - 5.0).abs() < 1.0e-9)
  assert_true((narrow.width - 1.0).abs() < 1.0e-9)
  // 标签盒完整落在 rect 内才 true（贴边/越界 false）
  let rect : @yue.RectF = { x: 0.0, y: 0.0, width: 100.0, height: 50.0, }
  assert_true(geo_label_fits(50.0, 25.0, 40.0, 16.0, rect))
  assert_true(geo_label_fits(30.0, 25.0, 40.0, 16.0, rect))
  assert_true(!geo_label_fits(10.0, 25.0, 40.0, 16.0, rect))
  assert_true(!geo_label_fits(90.0, 25.0, 40.0, 16.0, rect))
  assert_true(!geo_label_fits(50.0, 4.0, 40.0, 16.0, rect))
  assert_true(!geo_label_fits(50.0, 46.0, 40.0, 16.0, rect))
}

///|
test "geo_shoelace / geo_ring_centroid / geo_region_centroid" {
  let ccw = [(0.0, 0.0), (2.0, 0.0), (2.0, 2.0), (0.0, 2.0)]
  let cw = [(0.0, 0.0), (0.0, 2.0), (2.0, 2.0), (2.0, 0.0)]
  assert_true((geo_shoelace(ccw) - 4.0).abs() < 1.0e-9)
  assert_true((geo_shoelace(cw) + 4.0).abs() < 1.0e-9)
  assert_true(geo_shoelace([(0.0, 0.0), (1.0, 1.0)]).abs() < 1.0e-9)
  // 面积质心 = 正方形中心（绕向无关）
  let (cx, cy) = geo_ring_centroid(ccw)
  assert_true((cx - 1.0).abs() < 1.0e-9)
  assert_true((cy - 1.0).abs() < 1.0e-9)
  // 共线退化：退化为顶点均值
  let (dx, dy) = geo_ring_centroid([(0.0, 0.0), (1.0, 1.0), (2.0, 2.0)])
  assert_true((dx - 1.0).abs() < 1.0e-9)
  assert_true((dy - 1.0).abs() < 1.0e-9)
  // 区域取 |面积| 最大环（主轴环）的质心，小内环不拉偏
  let small = [(0.0, 0.0), (0.1, 0.0), (0.0, 0.1), (0.0, 0.0)]
  let region = GeoRegion::make(Some("r"), [small, ccw])
  match geo_region_centroid(region) {
    Some((rx, ry)) => {
      assert_true((rx - 1.0).abs() < 1.0e-9)
      assert_true((ry - 1.0).abs() < 1.0e-9)
    }
    None => assert_true(false)
  }
  assert_true(geo_region_centroid(GeoRegion::make(None, [])) is None)
}

///|
test "geo_flight_ctrl：中点法向偏移 / 退化" {
  // 水平向右：法向 (dy, -dx) → 画布 y 向下，弧凸向上
  let (cx, cy) = geo_flight_ctrl((0.0, 0.0), (100.0, 0.0), bend=0.5)
  assert_true((cx - 50.0).abs() < 1.0e-9)
  assert_true((cy + 50.0).abs() < 1.0e-9)
  // 默认 bend 0.2：距 100 → 偏移 20
  let (dx, dy) = geo_flight_ctrl((0.0, 0.0), (100.0, 0.0))
  assert_true((dx - 50.0).abs() < 1.0e-9)
  assert_true((dy + 20.0).abs() < 1.0e-9)
  // 竖直向下：法向指向画布右侧
  let (vx, vy) = geo_flight_ctrl((0.0, 0.0), (0.0, 100.0), bend=0.5)
  assert_true((vx - 50.0).abs() < 1.0e-9)
  assert_true((vy - 50.0).abs() < 1.0e-9)
  // 起终重合：控制点即中点（无长度可偏移）
  let (sx, sy) = geo_flight_ctrl((3.0, 4.0), (3.0, 4.0))
  assert_true((sx - 3.0).abs() < 1.0e-9)
  assert_true((sy - 4.0).abs() < 1.0e-9)
}

///|
test "geo_quad_bezier：端点与中点" {
  let p0 = (0.0, 0.0)
  let c = (50.0, -50.0)
  let p1 = (100.0, 0.0)
  let (a0x, a0y) = geo_quad_bezier(p0, c, p1, 0.0)
  assert_true((a0x - 0.0).abs() < 1.0e-9)
  assert_true((a0y - 0.0).abs() < 1.0e-9)
  let (a1x, a1y) = geo_quad_bezier(p0, c, p1, 1.0)
  assert_true((a1x - 100.0).abs() < 1.0e-9)
  assert_true((a1y - 0.0).abs() < 1.0e-9)
  // t=0.5：0.25·p0 + 0.5·c + 0.25·p1 = 中点与控制点的中点
  let (mx, my) = geo_quad_bezier(p0, c, p1, 0.5)
  assert_true((mx - 50.0).abs() < 1.0e-9)
  assert_true((my + 25.0).abs() < 1.0e-9)
}

///|
test "geo_flight_points：弧线采样（端点/段数/弧凸）" {
  let pts = geo_flight_points((0.0, 0.0), (100.0, 0.0), bend=0.5, steps=4)
  assert_eq(pts.length(), 5)
  assert_eq(pts[0], (0.0, 0.0))
  assert_eq(pts[4], (100.0, 0.0))
  // 水平弧的整体弧顶在 t=0.5（y 最小，凸向上），中间点全部在弦上方
  assert_true((pts[2].1 + 25.0).abs() < 1.0e-9)
  for i in 1..<4 {
    assert_true(pts[i].1 < 0.0)
  }
  // 默认 steps=48 → 49 点；steps<1 按 1 段（2 点）
  assert_eq(geo_flight_points((0.0, 0.0), (1.0, 1.0)).length(), 49)
  let one = geo_flight_points((0.0, 0.0), (1.0, 1.0), steps=0)
  assert_eq(one.length(), 2)
  assert_eq(one[0], (0.0, 0.0))
  assert_eq(one[1], (1.0, 1.0))
}

///|
test "geo_name_hash / geo_region_color / geo_flight_seg_color" {
  // 空串取 FNV-1a 偏移基值（2166136261 mod 2147483647）
  assert_eq(geo_name_hash(""), 18652614)
  // 确定性：同名同值
  assert_eq(geo_name_hash("北京"), geo_name_hash("北京"))
  assert_true(geo_name_hash("北京") != geo_name_hash("上海"))
  // 无名区域不微调（即主题主色本身）
  let base = @yue.theme_primary()
  match @yue.parse_hex(geo_region_color(None)) {
    Some(_) => assert_true(true)
    None => assert_true(false)
  }
  assert_eq(geo_region_color(None), base)
  // 同名稳定、异名可见差异（明度微调后仍是合法 6 位 hex）
  assert_eq(geo_region_color(Some("北京")), geo_region_color(Some("北京")))
  match @yue.parse_hex(geo_region_color(Some("sh"))) {
    Some(_) => assert_true(true)
    None => assert_true(false)
  }
  // 渐变端点：t=0 主色（起点）、t=1 info 色（终点）
  assert_eq(geo_flight_seg_color(0.0), @yue.theme_primary())
  assert_eq(geo_flight_seg_color(1.0), @yue.theme_info())
}

///|
test "GeoFlight / GeoRegion 构造与 geo_map_t 组件可编译（不 mount，真机验证绘制）" {
  let flight = GeoFlight::make((116.4, 39.9), (121.47, 31.23))
  assert_eq(flight.from, (116.4, 39.9))
  assert_eq(flight.to, (121.47, 31.23))
  let regions = GeoRegion::make(Some("demo"), [
    [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (0.0, 0.0)],
  ])
  assert_eq(regions.rings.length(), 1)
  assert_eq(regions.rings[0].length(), 4)
  // 组件构造只建未挂载片段（无平台副作用）；绘制路径走 on_draw，
  // 由用户真机验证
  let store : @yue.Store[Array[GeoRegion]] = @yue.Store::new([regions])
  let node = geo_map_t(store, flights=[flight])
  ignore(node.mount)
  // 解析 → Store → 组件 全链路（不 mount）
  let parsed = geojson_parse(geo_sample_fc())
  match parsed {
    Ok(rs) => {
      let s2 : @yue.Store[Array[GeoRegion]] = @yue.Store::new(rs)
      let n2 = geo_map_t(s2, show_labels=false)
      ignore(n2.mount)
    }
    Err(_) => assert_true(false)
  }
}
