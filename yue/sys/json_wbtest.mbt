// JSON 解析器的回归（资产自 master 平移；测试为本包自建——旧链路的覆盖散在
// vscode_history / browser_bookmarks 的测试里，随系统能力批次再平移过来）。
// `VscJson` 是带载荷枚举、`==` 派生不出来，因此断言一律走取值助手、
// `kind_of` 字符串化与码点读数，不比整个值对象。

///|
fn kind_of(v : VscJson?) -> String {
  match v {
    None => "none"
    Some(VscJNull) => "null"
    Some(VscJBool) => "bool"
    Some(VscJInt(_)) => "int"
    Some(VscJFloat(_)) => "float"
    Some(VscJStr(_)) => "str"
    Some(VscJArr(_)) => "arr"
    Some(VscJObj(_)) => "obj"
  }
}

///|
fn[T] is_none(o : T?) -> Bool {
  match o {
    None => true
    Some(_) => false
  }
}

///|
fn str_of(text : String) -> String {
  match vsc_json_parse(text) {
    Some(VscJStr(s)) => s
    _ => "<非字符串>"
  }
}

///|
test "标量：null / bool / int / float" {
  assert_eq(kind_of(vsc_json_parse("null")), "null")
  // VscJBool 无载荷：true/false 只表「存在布尔值」，调用方不分支取值
  assert_eq(kind_of(vsc_json_parse("true")), "bool")
  assert_eq(kind_of(vsc_json_parse("false")), "bool")
  assert_eq(kind_of(vsc_json_parse("42")), "int")
  assert_eq(kind_of(vsc_json_parse(" -7 ")), "int")
  assert_eq(kind_of(vsc_json_parse("1.5")), "float")
  assert_eq(vsc_json_int64(vsc_json_parse("42")), Some(42L))
  assert_eq(vsc_json_int64(vsc_json_parse("-7")), Some(-7L))
  // 整值浮点兜底转 Int64；带小数部分不给
  assert_eq(vsc_json_int64(vsc_json_parse("123.0")), Some(123L))
  assert_eq(vsc_json_int64(vsc_json_parse("123.5")), None)
  // 非整数类型取值助手一律拒绝
  assert_eq(is_none(vsc_json_str(vsc_json_parse("7"))), true)
  assert_eq(is_none(vsc_json_int64(vsc_json_parse("\"7\""))), true)
}

///|
test "Int64 精度：毫秒时间戳不被截成 Int32 语义" {
  let v = vsc_json_parse("{\"ts\":1632000000123}")
  let ts = match v {
    Some(o) => vsc_json_int64(vsc_json_get(o, "ts"))
    None => None
  }
  assert_eq(ts, Some(1632000000123L))
  // 超出 2^53 精确范围的浮点拒绝；恰好 2^53 放行（字面量本身已在二进制里取整）
  assert_eq(vsc_json_int64(vsc_json_parse("1e20")), None)
  assert_eq(vsc_json_int64(vsc_json_parse("9007199254740992.0")), Some(9007199254740992L))
}

///|
test "嵌套结构与链式取值" {
  let v = vsc_json_parse(
    "{\"a\":{\"b\":[10,20,{\"c\":\"x\"}]},\"empty\":{},\"arr\":[]}",
  )
  assert_eq(kind_of(v), "obj")
  let a = match v {
    Some(o) => vsc_json_get(o, "a")
    None => None
  }
  let b = match a {
    Some(o) => vsc_json_get(o, "b")
    None => None
  }
  assert_eq(kind_of(b), "arr")
  let third = match b {
    Some(VscJArr(items)) => items[2]
    _ => VscJNull
  }
  assert_eq(vsc_json_str(vsc_json_get(third, "c")), Some("x"))
  let empty_obj = match v {
    Some(o) => vsc_json_get(o, "empty")
    None => None
  }
  assert_eq(kind_of(empty_obj), "obj")
  // 缺失键与非对象接收者都给 None
  assert_eq(
    is_none(match v {
      Some(o) => vsc_json_get(o, "nope")
      None => None
    }),
    true,
  )
  assert_eq(is_none(vsc_json_get(VscJNull, "k")), true)
}

///|
test "字符串转义：常规、\\u、代理对与孤立代理" {
  assert_eq(str_of("\"a\\nb\""), "a\nb")
  assert_eq(str_of("\"\\\"\\\\\\/\""), "\"\\/")
  assert_eq(str_of("\"\\t\\r\\b\\f\""), "\t\r\b\f")
  assert_eq(str_of("\"\\u0041\""), "A")
  assert_eq(str_of("\"\\u00e9\""), "é")
  // 代理对转义合并成一个码点
  assert_eq(str_of("\"\\uD83D\\uDE00\""), "😀")
  // 孤立高代理替换为 U+FFFD
  let lone = str_of("\"\\uD800\"")
  assert_eq(lone.length(), 1)
  assert_eq(lone.unsafe_get(0).to_int(), 0xFFFD)
  // 未闭合字符串 → None
  assert_eq(is_none(vsc_json_parse("\"oops")), true)
  // 坏 \u 序列 → None
  assert_eq(is_none(vsc_json_parse("\"\\u00\"")), true)
}

///|
test "语法错误与尾随内容一律拒绝" {
  let bad : Array[String] = [
    "{\"a\":1,}",
    "{\"a\" 1}",
    "{'a':1}",
    "[1,2",
    "tru",
    "{\"a\":1} extra",
    "",
    "[,]",
    "\"\\q\"",
  ]
  let mut accepted = 0
  for t in bad {
    match vsc_json_parse(t) {
      Some(_) => accepted = accepted + 1
      None => ()
    }
  }
  assert_eq(accepted, 0)
  // 对照：合法的空白松散形态要过
  assert_eq(kind_of(vsc_json_parse(" { \"a\" : [ 1 , 2 ] } ")), "obj")
  assert_eq(kind_of(vsc_json_parse("[]")), "arr")
}

///|
test "GeoJSON 形态（图表包共用这条路径）" {
  let v = vsc_json_parse(
    "{\"type\":\"Feature\",\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[0.0,0.0],[1.0,0.0]]]}}",
  )
  let g = match v {
    Some(o) => vsc_json_get(o, "geometry")
    None => None
  }
  assert_eq(kind_of(g), "obj")
  let pt = match g {
    Some(o) =>
      match vsc_json_get(o, "coordinates") {
        Some(VscJArr(rings)) =>
          match rings[0] {
            VscJArr(pts) => Some(pts[1])
            _ => None
          }
        _ => None
      }
    None => None
  }
  // [1.0, 0.0] 是整值浮点，按 Int64 取要能取到 1
  let x = match pt {
    Some(VscJArr(xs)) => vsc_json_int64(Some(xs[0]))
    _ => None
  }
  assert_eq(x, Some(1L))
}

///|
test "十六进制码元与码点取值助手" {
  assert_eq(vsc_hex_val('0'.to_int()), Some(0))
  assert_eq(vsc_hex_val('9'.to_int()), Some(9))
  assert_eq(vsc_hex_val('a'.to_int()), Some(10))
  assert_eq(vsc_hex_val('F'.to_int()), Some(15))
  assert_eq(is_none(vsc_hex_val('g'.to_int())), true)
  // 实测：本工具链的 String 按 **UTF-16 码元** 索引（unsafe_get 给码元不是码点），
  // 故 emoji 的两个代理码元被合并成一个码点、消耗 2
  let (cp, step) = vsc_codepoint_at("😀A", 0)
  assert_eq(cp, 0x1F600)
  assert_eq(step, 2)
  let (cp2, step2) = vsc_codepoint_at("A", 0)
  assert_eq(cp2, 65)
  assert_eq(step2, 1)
}
