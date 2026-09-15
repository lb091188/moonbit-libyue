// 布局与容器页：Group / Scroll / Separator / 嵌套布局 / 光标。

///|
fn page_layout() -> @yue.Node {
  let scroll_box : Ref[@yue.Scroll?] = Ref(None)
  let policy_on = Ref(false)
  let cursor_area : Ref[@yue.Container?] = Ref(None)
  let cursor_now : @yue.Store[String] = @yue.Store::new("Default")
  let apply_cursor = fn(t : @yue.CursorType, name : String) -> Unit {
    when_some(cursor_area, fn(c) {
      @yue.View::set_cursor(c, @yue.Cursor::new(t))
      cursor_now.set(name)
    })
  }
  scroll_page([
    section(
      "分组 Group",
      "标题 + 内容；win32 的 Group 不按内容自增长（GTK 按自然尺寸撑开），跨平台一致需显式高度。",
      [
        @yue.group(
          "分组：内嵌标签",
          @yue.label("分组里的内容", style=[("padding", 8.0)]),
          style=[("height", 96.0)],
        ),
      ],
    ),
    section(
      "滚动区 Scroll",
      "内容尺寸 + 滚动条策略（Automatic/Always/Never）切换；overlay 滚动条仅 GTK 生效，Windows 无此概念。",
      [
        @yue.node_of(make_policy_scroll(scroll_box), style=[
          ("height", 128.0),
          ("marginBottom", 8.0),
        ]),
        @yue.button("切换滚动条策略", on_click=fn() {
          policy_on.val = !policy_on.val
          when_some(scroll_box, fn(s) {
            if policy_on.val {
              s.set_scrollbar_policy(@yue.Always, @yue.Always)
            } else {
              s.set_scrollbar_policy(@yue.Automatic, @yue.Automatic)
            }
          })
        }),
      ],
    ),
    section(
      "分隔线 Separator",
      "水平 / 垂直两种方向，本页每段之间的分隔线就是它。",
      [
        @yue.label("上下两条水平分隔线之间"),
        @yue.separator(),
        @yue.label("（上方是 Separator）"),
      ],
    ),
    section(
      "嵌套布局",
      "hbox/vbox 嵌套、固定宽 / 百分比 / flex 权重三种宽度模型（yoga 样式，全集见 docs/layout.md）。",
      [
        @yue.hbox(
          [
            @yue.label(
              "固定 80",
              style=[("width", 80.0), ("height", 40.0), ("marginRight", 8.0)],
              style_str=[("backgroundcolor", "#3A5F8A")],
            ),
            @yue.label("50%", style=[("height", 40.0), ("marginRight", 8.0)], style_str=[
              ("width", "50%"),
              ("backgroundcolor", "#8A3A5F"),
            ]),
            @yue.label("flex 1", style=[("flex", 1.0), ("height", 40.0)], style_str=[
              ("backgroundcolor", "#5F8A3A"),
            ]),
          ],
          style=[("marginBottom", 8.0)],
        ),
      ],
    ),
    section(
      "光标 Cursor",
      "View::set_cursor 切换悬停光标——把鼠标移到下方色块上再点按钮。",
      [
        @yue.container(
          handle=fn(c) { cursor_area.val = Some(c) },
          style=[("height", 48.0), ("marginBottom", 8.0)],
          style_str=[("backgroundcolor", "#356AA0")],
        ),
        @yue.hbox(
          [
            @yue.button("手型", on_click=fn() {
              apply_cursor(@yue.Hand, "Hand")
            }),
            @yue.button("文本", on_click=fn() {
              apply_cursor(@yue.Text, "Text")
            }),
            @yue.button("十字", on_click=fn() {
              apply_cursor(@yue.Crosshair, "Crosshair")
            }),
            @yue.button("禁止", on_click=fn() {
              apply_cursor(@yue.NotAllowed, "NotAllowed")
            }),
            @yue.button("默认", on_click=fn() {
              apply_cursor(@yue.Default, "Default")
            }),
          ],
          style=[("marginBottom", 8.0)],
        ),
        @yue.bind_label(cursor_now, fn(s) { "当前光标：\{s}" }),
      ],
    ),
  ])
}

///|
/// 滚动策略演示用的滚动区：固定内容尺寸 + 多行文本。
fn make_policy_scroll(handle : Ref[@yue.Scroll?]) -> @yue.Scroll {
  let s = @yue.Scroll::new()
  s.set_content_size(640.0, 96.0)
  let edit = @yue.TextEdit::new()
  edit.set_text(
    "滚动区文本…\n第二行\n第三行\n第四行\n第五行\n第六行\n第七行",
  )
  s.set_content(edit)
  handle.val = Some(s)
  s
}
