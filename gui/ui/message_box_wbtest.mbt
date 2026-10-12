// W21b 自绘消息框回归：纯函数（图标/取色/默认钮）+ 运行时（Store 驱动弹收、
// 按钮响应编号、✕ 与 Esc 走 dismiss、Enter 走默认钮、遮罩按 close_on_mask 决定）。
// 运行时部分用无头控件树 + 手动装的浮层宿主（同 `overlay_wbtest`），不需要真窗口。

///|
/// 取控件的按键回调（没有就返回恒 false 的桩，省得每处写 match）。
fn msgbox_key_of(w : @core.Widget) -> (@core.KeyEvent) -> Bool {
  match w.on_key {
    Some(f) => f
    None => fn(_e : @core.KeyEvent) -> Bool { false }
  }
}

///|
test "msgbox_icon_of：五种消息种类各给一个图标" {
  inspect(@icons.icon_name(msgbox_icon_of(Default)), content="info-circle-fill")
  inspect(@icons.icon_name(msgbox_icon_of(Information)), content="info-circle-fill")
  inspect(@icons.icon_name(msgbox_icon_of(Warning)), content="warning-circle-fill")
  inspect(@icons.icon_name(msgbox_icon_of(Question)), content="question-circle-fill")
  inspect(@icons.icon_name(msgbox_icon_of(Error)), content="close-circle-fill")
}

///|
test "msgbox_icon_color_of：取色非空，警示/危险与主色不同" {
  let info = msgbox_icon_color_of(Information)
  let warn = msgbox_icon_color_of(Warning)
  let err = msgbox_icon_color_of(Error)
  assert_true(info.length() > 0)
  assert_true(warn.length() > 0)
  assert_true(err.length() > 0)
  // 三种语义色互不相同（否则「按种类取色」名不副实）
  assert_true(info != warn)
  assert_true(warn != err)
  assert_true(info != err)
  // Default 与 Information 同色（同一个图标）
  assert_eq(msgbox_icon_color_of(Default), info)
}

///|
test "msgbox_default_code：空表给 0、否则给第一个" {
  inspect(msgbox_default_code([]), content="0")
  inspect(msgbox_default_code([("是", 6), ("否", 7)]), content="6")
  inspect(msgbox_default_code([("好", 0)]), content="0")
}

///|
test "消息框：Store 驱动弹收，按钮回调响应编号并收起" {
  if !ui_text_guard() {
    return
  }
  let vis = @core.Store::new(false)
  let got : Array[Int] = []
  let dismissed = Ref(0)
  let (root, _anchor) = mounted_with_overlay(
    message_box_t(
      vis,
      "删除确认",
      "要删掉这一条吗？",
      kind=Warning,
      informative="删掉后无法恢复。",
      buttons=[("删除", 10), ("取消", 20)],
      on_response=fn(code : Int) -> Unit { got.push(code) },
      on_dismiss=fn() -> Unit { dismissed.val = dismissed.val + 1 },
    ),
    400.0,
    300.0,
  )
  assert_eq(@core.overlay_count(), 0)
  vis.set(true)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let scrim = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  // 遮罩铺满整窗（宽度是显式 100% 而不是内容撑），面板居中
  assert_eq(scrim.rect.w, 400.0)
  assert_eq(scrim.rect.h, 300.0)
  let panel = scrim.children()[0]
  assert_eq(panel.rect.w, 420.0)
  assert_eq(panel.rect.x + panel.rect.w / 2.0, scrim.rect.w / 2.0)
  assert_eq(panel.rect.y + panel.rect.h / 2.0, scrim.rect.h / 2.0)
  // 面板四区：标题栏 / ✕ / 正文区 / 按钮区
  assert_eq(panel.children().length(), 4)
  let body = panel.children()[2]
  // 正文区：图标 + 文本列；文本列两行（正文 + informative）
  assert_eq(body.children().length(), 2)
  assert_eq(body.children()[1].children().length(), 2)
  let footer = panel.children()[3]
  assert_eq(footer.children().length(), 2)
  assert_eq(
    match footer.children()[0].on_pointer {
      Some(_) => true
      None => false
    },
    true,
  )
  // 点「取消」（第二个钮，非主色）：回调 20 + 收起 + Store 归假
  click_at(root, footer.children()[1], 20.0, 15.0)
  assert_eq(got, [20])
  assert_eq(@core.overlay_count(), 0)
  assert_eq(vis.get(), false)
  assert_eq(dismissed.val, 0)
  // 再开一次，点「删除」（第一个钮）
  vis.set(true)
  root.relayout(400.0, 300.0)
  let scrim2 = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  click_at(root, scrim2.children()[0].children()[3].children()[0], 20.0, 15.0)
  assert_eq(got, [20, 10])
  assert_eq(vis.get(), false)
}

///|
test "消息框：✕ 与 Esc 走 dismiss（不给响应编号），Enter 走默认钮" {
  if !ui_text_guard() {
    return
  }
  let vis = @core.Store::new(true)
  let got : Array[Int] = []
  let dismissed = Ref(0)
  let (_root, _a) = mounted_with_overlay(
    message_box_t(
      vis,
      "提示",
      "正文",
      buttons=[("确定", 1), ("取消", 2)],
      on_response=fn(code : Int) -> Unit { got.push(code) },
      on_dismiss=fn() -> Unit { dismissed.val = dismissed.val + 1 },
    ),
    400.0,
    300.0,
  )
  assert_eq(@core.overlay_count(), 1)
  let panel = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0].children()[0]
    None => @core.Widget::new()
  }
  let key = msgbox_key_of(panel)
  // Esc：收起 + dismiss，不给编号；抬起不处理
  assert_eq(key({ press: false, keysym: @core.KS_ESCAPE, mods: 0 }), false)
  assert_eq(key({ press: true, keysym: @core.KS_ESCAPE, mods: 0 }), true)
  assert_eq(dismissed.val, 1)
  assert_eq(got.length(), 0)
  assert_eq(@core.overlay_count(), 0)
  assert_eq(vis.get(), false)
  // 再开一次：Enter → 第一个按钮的编号 1
  vis.set(true)
  assert_eq(@core.overlay_count(), 1)
  let panel2 = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0].children()[0]
    None => @core.Widget::new()
  }
  let key2 = msgbox_key_of(panel2)
  assert_eq(key2({ press: true, keysym: @core.KS_RETURN, mods: 0 }), true)
  assert_eq(got, [1])
  assert_eq(dismissed.val, 1)
  assert_eq(@core.overlay_count(), 0)
}

///|
test "消息框：close_on_mask=false 时点遮罩不收，但 ✕ 收（走 dismiss）" {
  if !ui_text_guard() {
    return
  }
  let vis = @core.Store::new(true)
  let got : Array[Int] = []
  let dismissed = Ref(0)
  let (root, _a) = mounted_with_overlay(
    message_box_t(
      vis,
      "标题",
      "内容",
      buttons=[("确定", 1)],
      close_on_mask=false,
      on_response=fn(code : Int) -> Unit { got.push(code) },
      on_dismiss=fn() -> Unit { dismissed.val = dismissed.val + 1 },
    ),
    400.0,
    300.0,
  )
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let scrim = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  // 点遮罩角落（面板外）：close_on_mask=false 收不了
  click_at(root, scrim, 5.0, 5.0)
  assert_eq(@core.overlay_count(), 1)
  assert_eq(vis.get(), true)
  assert_eq(dismissed.val, 0)
  // ✕ 在标题栏右上角（面板子项第 2 个）：收起 + dismiss，不给响应编号
  click_at(root, scrim.children()[0].children()[1], 12.0, 12.0)
  assert_eq(dismissed.val, 1)
  assert_eq(got.length(), 0)
  assert_eq(@core.overlay_count(), 0)
  assert_eq(vis.get(), false)
}

///|
test "消息框：close_on_mask=true 时点遮罩收起且走 dismiss" {
  if !ui_text_guard() {
    return
  }
  let vis = @core.Store::new(true)
  let dismissed = Ref(0)
  let (root, _a) = mounted_with_overlay(
    message_box_t(
      vis,
      "标题",
      "内容",
      close_on_mask=true,
      on_dismiss=fn() -> Unit { dismissed.val = dismissed.val + 1 },
    ),
    400.0,
    300.0,
  )
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let scrim = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  // 点遮罩角落（面板外）：收起 + dismiss
  click_at(root, scrim, 5.0, 5.0)
  assert_eq(dismissed.val, 1)
  assert_eq(@core.overlay_count(), 0)
  assert_eq(vis.get(), false)
  // 点 ✕ 也走 dismiss（换一个实例，遮罩不参与）
  let vis2 = @core.Store::new(true)
  let dismissed2 = Ref(0)
  let (root2, _b) = mounted_with_overlay(
    message_box_t(
      vis2,
      "标题",
      "内容",
      close_on_mask=false,
      on_dismiss=fn() -> Unit { dismissed2.val = dismissed2.val + 1 },
    ),
    400.0,
    300.0,
  )
  root2.relayout(400.0, 300.0)
  let scrim2 = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  // ✕ 在标题栏右上角（面板子项第 2 个）
  click_at(root2, scrim2.children()[0].children()[1], 12.0, 12.0)
  assert_eq(dismissed2.val, 1)
  assert_eq(@core.overlay_count(), 0)
  assert_eq(vis2.get(), false)
}

///|
test "消息框：informative 为空时不占副行；空文案按钮跳过" {
  if !ui_text_guard() {
    return
  }
  let vis = @core.Store::new(true)
  let (_root, _a) = mounted_with_overlay(
    message_box_t(
      vis,
      "标题",
      "只有正文",
      buttons=[("确定", 1), ("", 2), ("取消", 3)],
    ),
    400.0,
    300.0,
  )
  let panel = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0].children()[0]
    None => @core.Widget::new()
  }
  // 文本列只有正文一行
  assert_eq(panel.children()[2].children()[1].children().length(), 1)
  // 三个按钮里空文案那个被跳过
  assert_eq(panel.children()[3].children().length(), 2)
}
