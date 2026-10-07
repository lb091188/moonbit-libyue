// 旭日图组件（EP Chart 对标，纯 MoonBit 全自绘，Painter 承载）：
//   sun_chart_t 旭日图（ECharts Sunburst 对标）：树形数据逐级同心环，
//                父段角度区间由子项按聚合值占比瓜分（同层闭合、起始角
//                对齐父段），同支系顶层段取主题语义色循环、逐层色深
//                渐变，段间按角度内缩留缝，段内标签放不下不画，中心
//                显示聚合总文字（可选）。
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （主题切换重绘跟随）；数据（树根 SunItem）经 Store 驱动，set 后只
// schedule_paint 画布，不重建视图树。纯函数（值聚合 / 树深 / 环形
// 分段布局 / 留缝几何 / 标签适配 / 色深渐变 / 反色文字）集中在文件
// 头部，charts_sunburst_wbtest.mbt 白盒覆盖。

// ---------------------------------------------------------------------------
// 纯函数层：聚合 / 树深 / 环形分段 / 留缝 / 标签适配 / 色深
// （白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 旭日图树节点：名称 + 显式值 value + 子项 children。显式值 <= 0（含
/// 缺省）时该节点取子项聚合值之和（口径见 [sun_total]）；make 不传
/// value 即按同一规则填好默认值。叶子节点只用 name + value。
pub(all) struct SunItem {
  name : String
  value : Double
  children : Array[SunItem]
}

///|
/// 建旭日图树节点：value 缺省时取 children 的聚合值之和（聚合口径见
/// [sun_total]，与独立聚合函数同一规则，不传即自动填默认）。
pub fn SunItem::make(
  name : String,
  value? : Double? = None,
  children? : Array[SunItem] = [],
) -> SunItem {
  let v = match value {
    Some(x) => x
    None => {
      let mut t = 0.0
      for c in children {
        t = t + sun_total(c)
      }
      t
    }
  }
  { name, value: v, children, }
}

///|
/// 聚合值：显式值 > 0 时取显式值（显式优先），否则为全部子项聚合值之
/// 和（逐层递归）；显式 0/负值与缺失同口径，负值子项不计入，无子项
/// 为 0。角度份额、中心总文字均以本函数为唯一量纲。
pub fn sun_total(item : SunItem) -> Double {
  if item.value > 0.0 {
    item.value
  } else {
    let mut t = 0.0
    for c in item.children {
      t = t + sun_total(c)
    }
    t
  }
}

///|
/// 树最大深度：根的直系子项深度为 1，逐层向下取最大；无子项为 0。
/// 即环形分段的最深层级（环数）。
pub fn sun_max_depth(item : SunItem) -> Int {
  let mut d = 0
  for c in item.children {
    let cd = sun_max_depth(c) + 1
    if cd > d {
      d = cd
    }
  }
  d
}

///|
/// 旭日图环形分段（画布坐标）：depth 为层级（根的直系子项为 1），
/// value 为该节点聚合值（角度份额的量纲），(a0, a1) 为起止角（弧度，
/// 画布语义 0 指向右、顺时针为正，根段区间自 12 点方向起），(cx, cy)
/// 为圆心，(r_in, r_out) 为内/外半径；parent 为父段在分段表中的下标
/// （顶层段为 -1），top 为该段所属顶层段下标（自身即顶层时为自身
/// 下标，绘制取其主题语义色再按 depth 渐变）。分段按深度优先序排列：
/// 父段下标恒小于其子段下标。
pub(all) struct SunSegment {
  name : String
  depth : Int
  value : Double
  a0 : Double
  a1 : Double
  cx : Double
  cy : Double
  r_in : Double
  r_out : Double
  parent : Int
  top : Int
}

///|
/// 环形布局的固定几何参数（圆心、半径区间、环数；sun_layout 内派生）。
priv struct SunRingGeom {
  cx : Double
  cy : Double
  ri0 : Double
  span : Double
  rings : Int
}

///|
/// 递归发射分段：item 的 [a0, a1] 角度区间由其子项按聚合值占比瓜分
/// （同层闭合：首子段起始角对齐 a0、末子段终止角精确对齐 a1，浮点
/// 累计残差由末段收回），子段自 12 点方向父段起始角起顺时针排布；
/// 聚合值 <= 0 的子项不产出分段也不占角度。第 1 级段的 top 取自身
/// 下标（顶层段基色来源），更深层继承父段 top。深度优先写入 out，
/// 父段下标恒小于子段。
fn sun_emit(
  item : SunItem,
  depth : Int,
  a0 : Double,
  a1 : Double,
  parent : Int,
  top : Int,
  geom : SunRingGeom,
  out : Array[SunSegment],
) -> Unit {
  let totals : Array[Double] = []
  for c in item.children {
    totals.push(sun_total(c))
  }
  let mut subtot = 0.0
  for t in totals {
    if t > 0.0 {
      subtot = subtot + t
    }
  }
  if !(subtot > 0.0) {
    return
  }
  let mut used = 0.0
  let mut last_idx = -1
  for i, c in item.children {
    let t = totals[i]
    if !(t > 0.0) {
      continue
    }
    let sa0 = a0 + (a1 - a0) * used / subtot
    used = used + t
    let sa1 = a0 + (a1 - a0) * used / subtot
    let d = depth + 1
    let idx = out.length()
    let this_top = if depth == 0 { idx } else { top }
    out.push({
      name: c.name,
      depth: d,
      value: t,
      a0: sa0,
      a1: sa1,
      cx: geom.cx,
      cy: geom.cy,
      r_in: geom.ri0 + geom.span * (d - 1).to_double() / geom.rings.to_double(),
      r_out: geom.ri0 + geom.span * d.to_double() / geom.rings.to_double(),
      parent,
      top: this_top,
    })
    last_idx = idx
    sun_emit(c, d, sa0, sa1, idx, this_top, geom, out)
  }
  // 末子段终止角精确对齐父段终止角（消浮点累计残差，闭合无残隙）
  if last_idx >= 0 {
    out[last_idx] = { ..out[last_idx], a1, }
  }
}

///|
/// 旭日图布局：把 root 展开为逐级同心环分段——第 d 级环占 [r0, r1]
/// 径向区间的第 d 段（环数 = 树最大深度，根的直系子项为第 1 级）；
/// 每个父段的角度区间由其子项按聚合值占比瓜分，同层闭合无残隙，子段
/// 起始角对齐父段起始角。根段角度区间自 12 点方向（-π/2）起、扫满
/// 整圈。父段显式值与子项和不一致的残差归父段自身（父段不产出分段），
/// 不摊薄子段。聚合值 <= 0 的节点不产出分段；根无子项或总值 <= 0
/// 时返回空表。r0 负值钳 0；r1 < r0 时各环径向宽度为 0（角度分配不受
/// 影响，仍按闭合规则产出）。
pub fn sun_layout(
  root : SunItem,
  center : (Double, Double),
  r0 : Double,
  r1 : Double,
) -> Array[SunSegment] {
  let out : Array[SunSegment] = []
  if !(sun_total(root) > 0.0) {
    return out
  }
  let rings = sun_max_depth(root)
  if rings <= 0 {
    return out
  }
  let ri0 = if r0 > 0.0 { r0 } else { 0.0 }
  let ro1 = if r1 > ri0 { r1 } else { ri0 }
  let geom = { cx: center.0, cy: center.1, ri0, span: ro1 - ri0, rings, }
  sun_emit(root, 0, -pi / 2.0, -pi / 2.0 + tau, -1, -1, geom, out)
  out
}

///|
/// 段间留缝（角度内缩）：把 [a0, a1] 两端各内缩半个缝宽（弧长 gap/2，
/// 折算为角 = (gap/2) / rm），返回留缝后的起止角；留缝后无剩余
/// （sweep <= 2×半缝角）时 None（该段不画）。rm 钳到 >= 1，防圆心
/// 附近角度爆炸。相邻段各让半个缝宽，段间即留下一条 gap 宽的视觉缝
/// （不依赖描边线宽，三平台一致）。
pub fn sun_seam(
  a0 : Double,
  a1 : Double,
  rm : Double,
  gap? : Double = 1.6,
) -> (Double, Double)? {
  let half = gap / 2.0 / (if rm > 1.0 { rm } else { 1.0 })
  if a1 - a0 <= 2.0 * half {
    None
  } else {
    Some((a0 + half, a1 - half))
  }
}

///|
/// 环间留缝（半径内缩）：内外半径各内缩半个缝宽，返回 (r_in, r_out)；
/// 环厚不足整个缝宽时 None（该环不画，避免内缩后半径交叉）。判定带
/// 1e-9 容差，口径为「环厚在容差内等于 gap 即不足」。
pub fn sun_radial_gap(
  r_in : Double,
  r_out : Double,
  gap? : Double = 0.8,
) -> (Double, Double)? {
  let half = gap / 2.0
  if r_out - r_in <= gap + 1.0e-9 {
    None
  } else {
    Some((r_in + half, r_out - half))
  }
}

///|
/// 文本宽度估算字宽数：CJK 及全角字符（码位 >= 0x2E80）按 2 个字宽、
/// 其余按 1（每字宽约 7px，Sans 12px，与 truncate_to 同一口径），供
/// 段内标签是否放得下与落盒宽度共用一套估算。
pub fn sun_text_units(text : String) -> Int {
  let mut units = 0
  for ch in text {
    units = units + (if ch.to_int() >= 0x2E80 { 2 } else { 1 })
  }
  units
}

///|
/// 段内标签是否放得下：弧长（sweep × rm）需容纳估算文本宽 + 10px
/// 余量，且环厚 >= 15px（11px 字号 + 上下留白）；任一条不满足即放不下
/// （调用方不画该标签——不截断、不放溢到段外）。rm 钳到 >= 1。
pub fn sun_label_fits(
  name : String,
  sweep : Double,
  rm : Double,
  ring_w : Double,
) -> Bool {
  let arc = sweep * (if rm > 1.0 { rm } else { 1.0 })
  let need = sun_text_units(name).to_double() * 7.0 + 10.0
  arc >= need && ring_w >= 15.0
}

///|
/// 色深渐变：同支系（同一顶层段）逐层提亮——第 1 级取基色原样，之后
/// 每深一级提亮 7%（HSL 的 L），最多提亮 35%（深层环不至洗白）。
/// base 通常为顶层段的主题语义色（绘制时经 sun_base_color 现取）。
pub fn sun_shade(base : String, depth : Int) -> String {
  let d = if depth < 1 { 1 } else { depth }
  lighten_hex(base, (0.07 * (d - 1).to_double()).min(0.35))
}

///|
/// 段内文字反色：按分段填充色亮度挑深字/白字（亮度 > 150 取深字，
/// 否则取白字），保证标签压在彩段上可读；色值无法解析时兜底白字。
pub fn sun_text_on(hex : String) -> String {
  match parse_hex(hex) {
    Some((r, g, b)) =>
      if 0.299 * r.to_double() + 0.587 * g.to_double() + 0.114 * b.to_double() >
        150.0 {
        "#1D2129"
      } else {
        "#FFFFFF"
      }
    None => "#FFFFFF"
  }
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 顶层段基色（5 语义色循环，相邻顶层段不同色；每次绘制现取主题色，
/// 主题切换自动跟随）。
fn sun_base_color(top : Int) -> String {
  match top % 5 {
    0 => theme_primary()
    1 => theme_success()
    2 => theme_warning()
    3 => theme_danger()
    _ => theme_info()
  }
}

///|
/// 环形段描边（面板底色，与 [sun_seam] / [sun_radial_gap] 的几何留缝
/// 叠加出描边分隔观感）：外弧走真 arc、内弧折线回程后闭合描边——
/// 内弧回程一律折线，与 charts.mbt 的 fill_ring 同一口径。
fn sun_stroke_ring(
  p : Painter,
  cx : Double,
  cy : Double,
  r_out : Double,
  r_in : Double,
  a0 : Double,
  a1 : Double,
) -> Unit {
  p.begin_path()
  p.arc(cx, cy, r_out, a0, a1)
  let steps = ((a1 - a0).abs() / (pi / 16.0)).ceil().to_int().max(4)
  let last = steps + 1
  for k in 0..<last {
    let a = a1 - (a1 - a0) * k.to_double() / steps.to_double()
    p.line_to(cx + r_in * @math.cos(a), cy + r_in * @math.sin(a))
  }
  p.close_path()
  p.stroke()
}

///|
/// 旭日图绘制（画布坐标，root 已由调用方取出）：外半径 r1 = 短边一半
/// - 8px（最小 12）；内半径 r0 = inner（<= 0 时取 r1 的 22%，中心留
/// 孔放总文字）。先按 [sun_seam] / [sun_radial_gap] 算可画段（缝后
/// 几何：相邻段、相邻环都不贴边），统一填充同心环并以面板底色描边
/// （几何留缝 + 描边双保险的段分隔观感）；段内标签放得下才画（居中
/// 于段弧中点，颜色按分段填充色反色）；中心按 center_text 显示——
/// None 为聚合总值 + 「总计」caption，Some("") 隐藏，Some(t) 显示 t。
/// 无分段（空树/总值 <= 0）画「暂无数据」占位。
fn sun_draw(
  p : Painter,
  w : Double,
  h : Double,
  root : SunItem,
  inner : Double,
  center_text : String?,
  show_labels : Bool,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let total = sun_total(root)
  let cx = w / 2.0
  let cy = h / 2.0
  let r1 = (w.min(h) / 2.0 - 8.0).max(12.0)
  let r0 = if inner > 0.0 { inner.min(r1) } else { r1 * 0.22 }
  let segs = sun_layout(root, (cx, cy), r0, r1)
  if segs.length() == 0 {
    let at = AttributedText::new(
      "暂无数据",
      align=Center,
      valign=Center,
      wrap=false,
    )
    at.set_font(Font::new("Sans", 13.0))
    at.set_color(theme_text_secondary())
    let tw = at.get_bounds_for(400.0, 40.0).width
    p.draw_attributed_text(at, cx - tw / 2.0, cy - 10.0, tw + 4.0, 20.0)
    return
  }
  // 可画段（缝后几何）先统一算好，填充与标签共用同一套
  let drawn : Array[(SunSegment, Double, Double, Double, Double)] = []
  for seg in segs {
    let rm = (seg.r_in + seg.r_out) / 2.0
    match sun_seam(seg.a0, seg.a1, rm) {
      None => ()
      Some((sa0, sa1)) =>
        match sun_radial_gap(seg.r_in, seg.r_out) {
          None => ()
          Some((ri, ro)) => drawn.push((seg, sa0, sa1, ri, ro))
        }
    }
  }
  // 环形段填充（同支系逐层色深渐变）+ 面板底色描边（段分隔观感）
  for dr in drawn {
    let (seg, sa0, sa1, ri, ro) = dr
    p.set_fill_color(sun_shade(sun_base_color(seg.top), seg.depth))
    fill_ring(p, seg.cx, seg.cy, ro, ri, sa0, sa1)
    p.set_stroke_color(theme_bg_panel())
    sun_stroke_ring(p, seg.cx, seg.cy, ro, ri, sa0, sa1)
  }
  // 段内标签：放不下就不画（不截断、不放溢）
  if show_labels {
    for dr in drawn {
      let (seg, sa0, sa1, ri, ro) = dr
      let rm = (ri + ro) / 2.0
      if sun_label_fits(seg.name, sa1 - sa0, rm, ro - ri) {
        let mid = (sa0 + sa1) / 2.0
        let tw = sun_text_units(seg.name).to_double() * 7.0 + 10.0
        let th = (ro - ri).min(16.0)
        p.draw_text(
          seg.name,
          seg.cx + rm * @math.cos(mid) - tw / 2.0,
          seg.cy + rm * @math.sin(mid) - th / 2.0,
          tw,
          th,
          align=Center,
          valign=Center,
          color=sun_text_on(sun_shade(sun_base_color(seg.top), seg.depth)),
          wrap=false,
        )
      }
    }
  }
  // 中心总文字（可选）
  let center_txt = match center_text {
    Some(t) => t
    None => fmt_axis(total)
  }
  if center_txt != "" {
    let at = AttributedText::new(
      center_txt,
      align=Center,
      valign=Center,
      wrap=false,
    )
    at.set_font(Font::new("Sans", 20.0, weight=SemiBold))
    at.set_color(theme_text_primary())
    let tw = at.get_bounds_for(400.0, 60.0).width
    p.draw_attributed_text(at, cx - tw / 2.0, cy - 16.0, tw + 4.0, 28.0)
    match center_text {
      None => {
        let cap = AttributedText::new(
          "总计",
          align=Center,
          valign=Center,
          wrap=false,
        )
        cap.set_font(Font::new("Sans", 11.0))
        cap.set_color(theme_text_secondary())
        let cw = cap.get_bounds_for(200.0, 20.0).width
        p.draw_attributed_text(cap, cx - cw / 2.0, cy + 10.0, cw + 4.0, 16.0)
      }
      Some(_) => ()
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 旭日图（EP 无对应，ECharts Sunburst 对标）：树形数据逐级同心环——
/// 每级一环，父段角度区间由其子项按聚合值占比瓜分（起始角对齐父段，
/// 同层闭合无残隙），顶层段取主题 5 语义色循环、同支系逐层提亮；
/// 段间/环间按留缝几何内缩（不依赖描边线宽）；段内标签按可容纳空间
/// 判定，放不下不画；中心显示聚合总文字——center_text 缺省为总值 +
/// 「总计」caption，Some("") 隐藏，Some(t) 自定义文案；show_labels=false
/// 关段内标签。inner <= 0 时中心孔取外半径 22%，可传绝对值自定义。
/// 数据（树根）经 Store 驱动，set 后只重绘画布不重建视图树；主题切换
/// 现取色自动跟随。fill=true 不设固定宽度，横向铺满父容器（跟随窗口
/// 伸缩）。
pub fn sun_chart_t(
  data : Store[SunItem],
  inner? : Double = 0.0,
  show_labels? : Bool = true,
  center_text? : String? = None,
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  {
    mount: fn(parent) {
      let size_style : Array[(String, &StyVal)] = if fill {
        [("height", 380.0)]
      } else {
        [("width", 440.0), ("height", 380.0)]
      }
      for kv in style {
        size_style.push(kv)
      }
      let cv = themed_container(style=size_style)
      handle(cv)
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        sun_draw(
          p,
          b.width,
          b.height,
          data.get(),
          inner,
          center_text,
          show_labels,
        )
      })
      data.subscribe(fn(_d) { ViewLike::schedule_paint(cv) })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
