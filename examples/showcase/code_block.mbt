// 章节演示代码的展示形态:toolbar 用 segmented「演示 / 代码」一键切换,
// 复制按钮常驻 toolbar 右端(停在演示态也能直接复制),点击后写入剪贴板
// 并经全局 toast 回显。演示与代码是两个可见性互斥的容器,切换不重建
// 视图树;代码内容为各章节最小自包含示例,见各 pages_*。

///|
/// 全局 toast 推送钩子:main 创建 toast_layer 后注入,复制回显用。
let code_toast : Ref[((String, @yue.SemanticType) -> Unit)?] = Ref(None)

///|
/// 演示/代码切换体:toolbar(segmented + 复制)+ 演示容器 + 代码容器。
/// 初始停在演示态,代码容器挂载即隐藏。
fn code_switcher(content : Array[@yue.Node], lines : Array[String]) -> @yue.Node {
  let mode : @yue.Store[String] = @yue.Store::new("演示")
  let demo_ref : Ref[@yue.Container?] = Ref(None)
  let code_ref : Ref[@yue.Container?] = Ref(None)
  fn apply_mode() -> Unit {
    match demo_ref.val {
      Some(c) => c.set_visible(mode.get() == "演示")
      None => ()
    }
    match code_ref.val {
      Some(c) => c.set_visible(mode.get() == "代码")
      None => ()
    }
  }

  let toolbar = @yue.hbox(
    [
      @yue.segmented(["演示", "代码"], mode),
      @yue.button_t(
        "复制",
        variant=@yue.Text,
        on_click=fn() {
          @yue.Clipboard::get().set_text(lines.join("\n"))
          match code_toast.val {
            Some(push) => push("代码已复制 ✓", @yue.Success)
            None => ()
          }
        },
      ),
    ],
    style=[("marginBottom", 10.0)],
    style_str=[("justifyContent", "space-between"), ("alignItems", "center")],
  )
  let demo = @yue.vbox(content, handle=fn(c) { demo_ref.val = Some(c) })
  let code_area = @yue.vbox(
    [@yue.code_view(lines, lang="moonbit", line_numbers=true, width=1000.0)],
    handle=fn(c) {
      code_ref.val = Some(c)
      c.set_visible(false)
    },
  )
  mode.subscribe(fn(_s) { apply_mode() })
  @yue.vbox([toolbar, demo, code_area])
}
