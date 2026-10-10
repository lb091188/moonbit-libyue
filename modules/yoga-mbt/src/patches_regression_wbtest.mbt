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
