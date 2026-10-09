// bind 长文本截断探针:信号文本每 2.5 秒在短/长间轮换,静态对照行是
// 同款长文本(证明布局本身放得下)。
// 病理(已定案):Label set_text 只 MarkDirty + queue_draw,不触发布局
// 下发;根 Layout 重算的 yoga 新值下放到深层 label 依赖各中间容器的
// UpdateChildBounds,而 GTK 对相同 allocation 的 size_allocate 短路,
// 尺寸未变的中间容器不下发 → label 停在旧宽度,变长截断、滞后到下一
// 次真实 resize 才恢复。
// 修复:shim 的 layout_root_down 走根 Layout 后逐层强制 UpdateChildBounds;
// bind_label 订阅回调 set_text 后补 update_layout。
// 验证:每次轮换后打印复刻行 bounds,宽度应与当前文本长度即时同步
// (长≈243 / 短=25),不再滞后一轮。

///|
const SHORT : String = "未选"

///|
const LONG : String = "2026-09-29 12:34:56 选中了一条很长的内容"

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let sig : @yue.Signal[String] = @yue.Signal::new(SHORT)
  let phase : @yue.Store[String] = @yue.Store::new("短")
  // 复刻行:bind_label 完整复刻(Label::make + wrap=false 富文本替换 +
  // set_text),可拿到 Label 引用做测量
  let probe : @yue.Label = @yue.Label::make(SHORT)
  let at = @yue.AttributedText::new(SHORT, valign=@yue.Center, wrap=false)
  probe.set_attributed_text(at)
  let win_ref : Ref[@yue.Window?] = Ref(None)
  let n : Ref[Int] = Ref(0)
  @yue.set_timer(2500, fn() {
    let to_long = sig.get() == SHORT
    sig.set(if to_long { LONG } else { SHORT })
    phase.set(if to_long { "长" } else { "短" })
    // 复刻 set_text 路径(bind_label 订阅回调同款调用)+ 修复动作:
    // set_text 后 update_layout 强制重排(经 shim 逐层下发)
    probe.set_text(if to_long { LONG } else { SHORT })
    probe.update_layout()
    let b = probe.get_bounds()
    println("[轮换#\{n.val + 1}] set_text 后 bounds=\{b.width}x\{b.height}")
    // 诊断:真改尺寸交替抖动(620/700),必然触发 GTK 整链 size_allocate
    match win_ref.val {
      Some(w) => {
        let wide = (n.val + 1) % 2 == 1
        w.set_content_size(if wide { 700.0 } else { 620.0 }, 160.0)
        let b2 = probe.get_bounds()
        println(
          "[轮换#\{n.val + 1}] 改窗宽\{if wide { 700 } else { 620 }} 后 bounds=\{b2.width}x\{b2.height}",
        )
      }
      None => ()
    }
    n.val = n.val + 1
    let b = probe.get_bounds()
    println(
      "[轮换#\{n.val}] 文本长=\{probe.get_text().length()} bounds=\{b.x},\{b.y} \{b.width}x\{b.height}",
    )
    if n.val >= 5 {
      println("探针结束")
      @yue.quit()
    }
    n.val < 5
  })
  ignore(
    @declarative.mount_window(
      [
        // 复刻 showcase 段内滚动架构:bind/复刻行都在 Scroll 内
        @declarative.scroll(
          @declarative.vbox(
            [
              @declarative.hbox(
                [
                  @components.label_t("bind:", role=@components.Body),
                  @declarative.bind(sig, fn(v) { v }),
                  @components.label_t("  ←[\{phase.get()}]", role=@components.Secondary),
                ],
                style=[("alignItems", "center"), ("marginBottom", 14.0)],
              ),
              @declarative.hbox(
                [
                  @components.label_t("复刻行:", role=@components.Body),
                  @declarative.node_of(probe),
                  @components.label_t("  (stdout 打 bounds)", role=@components.Secondary),
                ],
                style=[("alignItems", "center"), ("marginBottom", 14.0)],
              ),
              @declarative.hbox(
                [
                  @components.label_t("静态对照:", role=@components.Body),
                  @components.label_t(LONG, role=@components.Body),
                ],
                style=[("alignItems", "center")],
              ),
            ],
            style=[("padding", 8.0)],
          ),
          style=[("flexgrow", 1.0)],
        ),
      ],
      title="probe-bind",
      size=Some((620.0, 220.0)),
      center=true,
      handle=fn(w) {
        win_ref.val = Some(w)
        w.on_key_down(fn(e) {
          if e.code == @yue.VKEY_ESCAPE {
            @yue.quit()
            true
          } else {
            false
          }
        })
      },
    ),
  )
  @yue.run()
}
