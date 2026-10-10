// 真实 bug 语料 → 回归用例：来源是 libyue 源码树 `/home/lkyh/ownCode/yue/patches/`
// 与其提交历史（那些补丁记录的是生产环境里踩出来的布局塌陷，比手写用例更有指向性）。
// 新增语料时保持一条一个 test，注释写清来源提交号与根因一句话。

fn measured(w : Double, h : Double) -> Node {
  let n = Node::new()
  n.set_measure(fn(_aw, _ah) { (w, h) })
  n
}

/// 语料 `93078300`（patches/yoga-display-none-flex-basis.patch）：
/// `flex` 简写派生的 basis-0 在 `display:none` 清零后重显时永久驻留，
/// auto 高父容器下该节点高度恒为 0（MoonBit 层 tabs 切页塌陷的根因）。
/// 本引擎没有 Yoga 那条「computedFlexBasis 被清零后按解析值重写」的驻留路径，
/// 所以要守的是它的**可观察契约**：auto 高父容器下的弹性项在隐藏/重显一轮之后，
/// 高度仍应来自内容测量（这就是 MoonBit 层 tabs 切页不塌的判据）。
test "display:none 重显后 flex 简写节点应回到内容高（语料 93078300）" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  // 父容器高度 auto：主轴无剩余空间，flex-grow 无从分配，高度只能来自内容
  let page = measured(200.0, 60.0)
  root.set_flex_direction(Column)
  root.append_child(page)
  page.set_flex(1.0, 1.0, auto())

  // 第一轮：隐藏
  page.set_display(Display::None)
  calculate_layout(root, Some(200.0), None)
  assert_eq(page.layout().height, 0.0)

  // 第二轮：重显——Yoga 原生在此把简写的 basis-0 留下，节点永久 0 高
  page.set_display(Display::Flex)
  calculate_layout(root, Some(200.0), None)
  assert_eq(page.layout().height, 60.0)
  assert_eq(page.layout().width, 200.0)
  assert_eq(root.layout().height, 60.0)
}

// 语料派生的待查项（不在本文件断言，避免把未对照过的期望写成事实）：
// 显式 `flex-basis: 0` + `min-height: 0` 在 auto 高列容器下，本引擎实测给出
// 60（内容高），而按 CSS 弹性布局推导应为 0（假想主轴尺寸 0、无剩余空间可分配）。
// 需要先用 Chrome 对照确认谁对，再决定是修引擎还是记录为有意取舍——涉及 §4.5
// min:auto 与 auto 主轴尺寸推算的交互，故单列任务跟踪。

/// 语料派生待查项结案（2026-10-11）：显式 `flex-basis: 0` + `min-height: 0`
/// 在 auto 高列容器下应为 0。Chrome（Blink）实测口径：auto 主轴尺寸 =
/// 各子项**假想主轴尺寸**之和（flex base 被 min/max 钳制），growth 完全不参与
/// ——规范 §9.9.1 的 Ideal 与 Web-compatible 两种算法都与 Blink 行为不符
/// （Ideal 会按期望弹性因子放大；Web-compatible 取 max-content contribution，
/// 在 basis 100/内容 300/grow 1 的情形给 300 而 Blink 给 100），以 Blink 为
/// 对齐目标。根因是引擎一处笔误：子项基准读成了**容器**的 `flex_basis`
/// （`s.flex_basis`），导致子项 flex-basis 在整条布局链路上被忽略；修好后
/// 下表与 Chrome 逐行一致。期望值来源：本地页面 + getBoundingClientRect
/// （Chrome 141 系，file:///tmp/flex_probe{2,3}.html）。
test "语料派生结案：auto 高列容器的轴向尺寸与 Chrome 一致（假想主轴尺寸之和）" {
  // (名称, grow, shrink, basis, min, max, Chrome 实测值)
  let rows : Array[(String, Double, Double, Value, Value, Value, Double)] = [
    // flex:0 1 0px; min-height:0 → 0（无增长，基准即结果）
    ("A", 0.0, 1.0, fixed(0.0), fixed(0.0), auto(), 0.0),
    // flex:1 1 0px; min-height:0 → 0（grow 不参与容器推算）
    ("C", 1.0, 1.0, fixed(0.0), fixed(0.0), auto(), 0.0),
    // flex:1 1 0px（min:auto，内容下限 60）→ 60
    ("D", 1.0, 1.0, fixed(0.0), auto(), auto(), 60.0),
    // flex:1 1 40px; min-height:0 → 40（基准优先于内容）
    ("F", 1.0, 1.0, fixed(40.0), fixed(0.0), auto(), 40.0),
    // flex:0 1 auto; min-height:0 → 60（基准=内容）
    ("G", 0.0, 1.0, auto(), fixed(0.0), auto(), 60.0),
    // flex:1 1 40%; min-height:0 → 60（百分比无参照，退回内容）
    ("I", 1.0, 1.0, percent(40.0), fixed(0.0), auto(), 60.0),
    // flex:0 1 auto; max-height:30 → 30（被 max 钳制）
    ("L", 0.0, 1.0, auto(), fixed(0.0), fixed(30.0), 30.0),
  ]
  for row in rows {
    let (name, g, s, basis, minh, maxh, want) = row
    let root = Node::new()
    root.set_width(fixed(200.0))
    root.set_flex_direction(Column)
    let item = measured(200.0, 60.0)
    root.append_child(item)
    item.set_flex(g, s, basis)
    item.set_min_height(minh)
    item.set_max_height(maxh)
    calculate_layout(root, Some(200.0), None)
    let _ = name
    assert_eq(item.layout().height, want)
    assert_eq(root.layout().height, want)
  }
}
