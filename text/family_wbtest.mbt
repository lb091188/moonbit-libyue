// 字体族枚举/回退与混排行高的回归。
// 枚举表内容随机器字体走，所以只断**性质**（非空、有序、去重、可反查），
// 不锁具体族名；度量同理：只断聚合规则与相对高低，不锁像素值。

///|
fn flip_ascii(s : String) -> String {
  let mut out = ""
  for c in s.to_array() {
    let i = c.to_int()
    let v =
      if i >= 97 && i <= 122 {
        i - 32
      } else if i >= 65 && i <= 90 {
        i + 32
      } else {
        i
      }
    out = out + v.unsafe_to_char().to_string()
  }
  out
}

///|
test "字体族枚举：非空、有序、去重、不含分隔符" {
  match families() {
    None => ()
    Some(list) => {
      assert_true(list.length() > 0)
      for name in list {
        assert_true(name.length() > 0)
        assert_false(name.contains("\n"))
      }
      // 注意：MoonBit 的 String 序是 **shortlex**（先比长度再比码元），
      // `<` / `compare` 都不是字典序；C 侧排的是字典序，所以这里显式用
      // `lexical_compare` 判。
      let mut i = 1
      while i < list.length() {
        assert_true(list[i - 1].lexical_compare(list[i]) < 0)
        i = i + 1
      }
    }
  }
}

///|
test "族名可用性：空名与通用族一律可用，不存在的族不可用" {
  assert_true(family_available(""))
  assert_true(family_available("serif"))
  assert_true(family_available("sans-serif"))
  assert_true(family_available("monospace"))
  assert_false(family_available("绝不可能存在的族 Qzzx"))
  match families() {
    None => ()
    Some(list) => {
      let real = list[0]
      assert_true(family_available(real))
      // 大小写换一遍照样可用（与 fontconfig/Pango 同口径）
      assert_true(family_available(flip_ascii(real)))
    }
  }
}

///|
test "resolve_family：取第一个可用者，跳过空串，全不可用退系统默认" {
  assert_eq(resolve_family([]), "")
  assert_eq(resolve_family(["不存在 Aaa", ""]), "")
  assert_eq(resolve_family(["不存在 Aaa", "不存在 Bbb"]), "")
  assert_eq(resolve_family(["不存在 Aaa", "serif", "monospace"]), "serif")
  match families() {
    None => ()
    Some(list) => {
      let real = list[list.length() - 1]
      assert_eq(resolve_family(["不存在 Aaa", real, "serif"]), real)
    }
  }
}

///|
test "Font::resolve：不可用的族名退空族名，字号字重样式不动" {
  let bogus = Font::new("绝不可能存在的族 Qzzx", 21.0, weight=Bold, style=Italic)
  let r = bogus.resolve()
  assert_eq((r.name, r.size), ("", 21.0))
  assert_eq(weight_value(r.weight), 700)
  assert_eq(style_id(r.style), 1)

  // 通用族与空名原样保留（保留请求名才量得到那一族的度量）
  let mono = Font::new("monospace", 12.0)
  assert_eq(mono.resolve().name, "monospace")
  let dflt = Font::new("", 13.0)
  assert_eq(dflt.resolve().name, "")

  match families() {
    None => ()
    Some(list) => {
      let real = list[0]
      assert_eq(Font::new(real, 15.0).resolve().name, real)
    }
  }

  // 逐个解析：不可用的那条退空，可用的那条留着
  let rs = resolve_fonts([bogus, mono])
  assert_eq((rs.length(), rs[0].name, rs[1].name), (2, "", "monospace"))
}

///|
test "font_metrics：ascent/descent 与既有行高、基线两个口径同源" {
  let f = Font::new("", 14.0)
  match font_metrics(f) {
    None => ()
    Some(m) => {
      assert_true(m.ascent > 0)
      assert_true(m.descent >= 0)
      // 行高套 K 地板（max(自然, ceil(size×K))，见 text.mbt 的 LINE_HEIGHT_K）；
      // 度量本身（ascent/descent）仍是引擎原值，地板只作用于行高投影
      let natural = m.ascent + m.descent
      let floor = (f.size * 1.36).ceil().to_int()
      assert_eq(
        line_height_font(f),
        Some(if natural > floor { natural } else { floor }),
      )
      assert_eq(line_ascent_font(f), Some(m.ascent))
      // 字号抬高度量：同一族 28px 的升距一定大于 13px
      let small = Font::new("", 13.0)
      let big = Font::new("", 28.0)
      match (font_metrics(small), font_metrics(big)) {
        (Some(s), Some(b)) => assert_true(b.ascent > s.ascent)
        _ => ()
      }
    }
  }
}

///|
test "line_height_multi：混排行盒 = 升距最大 + 降距最大" {
  assert_eq(line_height_multi([]), None)
  let base = Font::new("", 13.0)
  let big = Font::new("", 28.0)
  // 单元素退化成那一份自己的行高
  assert_eq(line_height_multi([base]), line_height_font(base))
  match (font_metrics(base), font_metrics(big)) {
    (Some(m1), Some(m2)) => {
      // 混排行盒 = 自然（升距最大+降距最大）再套 K 地板（用行内最大字号，
      // 与 line_height_multi 同口径）
      let natural = m1.ascent.max(m2.ascent) + m1.descent.max(m2.descent)
      let floor = (big.size * 1.36).ceil().to_int()
      let want = if natural > floor { natural } else { floor }
      let got = line_height_multi([base, big])
      assert_eq(got, Some(want))
      // 混排行盒 ≥ 任何单份的行高（这是「盒会不会裁字」的判据）
      match got {
        Some(h) => {
          assert_true(h >= m1.ascent + m1.descent)
          assert_true(h >= m2.ascent + m2.descent)
        }
        None => fail("应当有值")
      }
      // 顺序无关
      assert_eq(line_height_multi([big, base]), got)
      // 同字号同族的两条并进去不改变结果（幂等）
      assert_eq(line_height_multi([base, base, big]), got)
    }
    _ => ()
  }
  // 不可用的族名照样量得出数（Pango 退到默认族），不会把整行拖成 None
  let bogus = line_height_multi([base, Font::new("不存在的族 Qzzx", 13.0)])
  match bogus {
    None => ()
    Some(h) => assert_true(h >= 13)
  }
}

///|
test "AttributedText 混排行高：区间字号参与，纯颜色区间不参与" {
  let t = AttributedText::new("基准文字与大字")
  let only = t.line_height()
  assert_eq(only, line_height_multi([t.effective_font()]))

  // 颜色区间不引入新字体 → 行高不变
  t.set_color_for("#ff0000", 0, 6)
  assert_eq(t.line_height(), only)

  t.set_font_for(Font::new("", 28.0), 6, 12)
  let mixed = t.line_height()
  assert_eq(mixed, line_height_multi([t.effective_font(), Font::new("", 28.0)]))
  match (only, mixed) {
    (_, Some(b)) => assert_true(b >= 13)
    _ => ()
  }
  // 空文本不影响行高口径
  let e = AttributedText::new("")
  assert_eq(e.line_height(), line_height_multi([e.effective_font()]))
}

///|
test "混排行高覆盖实际绘制高度（基准字体的行高装不下大字号）" {
  let t = AttributedText::new("基准 Base 28")
  t.set_font_for(Font::new("", 28.0), 10, 12)
  match (t.line_height(), t.get_bounds_for(240.0, 0.0).height) {
    (Some(lh), bh) => {
      // 行高必须**盖得住**渲染出来的那一行
      assert_true(bh <= lh.to_double() + 1.0)
      let base_only = line_height_multi([t.effective_font()])
      match base_only {
        Some(b) => {
          // 基准字体（13px）的行高装不下 28px 的内容——这正是「盒矮了会裁字」
          assert_true(lh > b)
          assert_true(bh > b.to_double())
        }
        None => ()
      }
    }
    _ => fail("有后端时应当给得出行高")
  }
}
