// 反馈组件页：Store/Signal 驱动。两个对话框的可见性挂窗口根（状态在 App，
// 由 main.mbt 把 `dialog` 挂进窗口根），反馈页的按钮只是触发方；
// Toast 推送函数经 App 传入（新栈的 toast 自己开在浮层图层上，页面里不必
// 再常驻一棵空树，与 master 的一条差）。
//
// G7 迁移记档：
// ① `alert_closeable` 在本栈并入 `alert`（`closable=true`），不再另出一个函数；
// ② `result` 在本栈只吃（标题, 副标题, 语义类型），操作区由调用方在旁边摆
//    ——旧链路把它作为数组参数传，本栈按「组件只给形状、操作区是内容」拆开；
// ③ `input_t` → `input`（Store 驱动）。

///|
pub fn page_feedback(app : @shared.App) -> @widget.Node {
  let msg_open : @base.Store[Bool] = @base.Store::new(false)
  let msg_kind : @base.Store[Int] = @base.Store::new(0)
  let msg_text : @base.Store[String] = @base.Store::new("")
  let msg_btns : @base.Store[Array[(String, Int)]] = @base.Store::new([("知道了", 1)])
  let msg_resp : @base.Store[String] = @base.Store::new("（还没弹过自绘消息框）")
  @shared.page([
    @shared.section(
      "横幅",
      "Alert 提示横幅",
      "四种语义类型：左侧色条 + 类型浅底 + 同族深字，文字垂直居中；最后一条是 `closable` 可关闭形态——点右侧 ✕ 收起整条横幅，`on_close` 回调可选（不需要另一个函数）。",
      [
        @ui.alert("成功提示：配置已保存。", t=@ui.Success),
        @ui.alert("信息提示：有新版本可用。", t=@ui.Info),
        @ui.alert("警告提示：磁盘剩余空间不足。", t=@ui.Warning),
        @ui.alert("错误提示：网络连接已断开。", t=@ui.Danger),
        @ui.alert(
          "可关闭横幅：点我右侧的 ✕ 试试。",
          description="关闭回调可选，这里留默认（只收起）。",
          t=@ui.Warning,
          closable=true,
        ),
      ],
      code=[
        "@ui.alert(\"成功提示：配置已保存。\", t=@ui.Success)",
        "@ui.alert(\"信息提示：有新版本可用。\", t=@ui.Info)",
        "@ui.alert(\"警告提示：磁盘剩余空间不足。\", t=@ui.Warning)",
        "@ui.alert(\"错误提示：网络连接已断开。\", t=@ui.Danger)",
        "@ui.alert(\"可关闭横幅：点我右侧的 ✕ 试试。\", t=@ui.Warning, closable=true)",
      ],
    ),
    @shared.section(
      "结果页",
      "Result 结果页",
      "大色块符号 + 标题 + 描述；四种语义类型。操作区由调用方摆在旁边（组件只给形状）。",
      [
        @ui.row(
          [
            @ui.col(
              [
                @ui.result("操作成功", subtitle="配置已写入并生效。", t=@ui.Success),
                @ui.row([@ui.button("返回首页")], column_gap=8.0),
              ],
              row_gap=10.0,
            ),
            @ui.col(
              [
                @ui.result("操作失败", subtitle="网络异常，请稍后重试。", t=@ui.Danger),
                @ui.row(
                  [@ui.button("重新加载", variant=@ui.Soft)],
                  column_gap=8.0,
                ),
              ],
              row_gap=10.0,
            ),
          ],
          column_gap=40.0,
        ),
      ],
      code=[
        "@ui.result(\"操作成功\", subtitle=\"配置已写入并生效。\", t=@ui.Success)",
        "@ui.result(\"操作失败\", subtitle=\"网络异常，请稍后重试。\", t=@ui.Danger)",
      ],
    ),
    @shared.section(
      "气泡",
      "Popover 气泡弹层",
      "popover 给任意节点包点击弹层：内容为任意 Node，再次点击收起。",
      [
        @ui.popover(
          @ui.button("打开气泡"),
          @ui.text("气泡内容：任意 Node。", role=@ui.Body),
          width=180.0,
          height=60.0,
        ),
      ],
      code=[
        "@ui.popover(",
        "  @ui.button(\"打开气泡\"),",
        "  @ui.text(\"气泡内容：任意 Node。\", role=@ui.Body),",
        "  180.0,",
        "  60.0,",
        ")",
      ],
    ),
    @shared.section(
      "轻提示",
      "Toast 轻提示",
      "操作反馈瞬态提示：推送后顶部居中出现，2.6 秒自动消失，多条堆叠。新栈里这条带子开在浮层图层上（第一条推送才开），所以页面里不必挂一个「提示层」节点，提示也永远压在对话框之上。",
      [
        @ui.row(
          [
            @ui.button("成功", on_click=fn() {
              app.toast_push("保存成功", @ui.Success)
            }),
            @ui.button("警告", on_click=fn() {
              app.toast_push("连接超时，已重试", @ui.Warning)
            }),
            @ui.button("错误", on_click=fn() {
              app.toast_push("提交失败：网络不可达", @ui.Danger)
            }),
            @ui.button("普通", variant=@ui.Solid, on_click=fn() {
              app.toast_push("已加入下载队列", @ui.Info)
            }),
          ],
          column_gap=8.0,
        ),
      ],
      code=[
        "let toast_push = @ui.toast_layer(duration_ms=2600)",
        "// 不必再挂层节点，直接推：",
        "toast_push(\"保存成功\", @ui.Success)",
        "toast_push(\"连接超时，已重试\", @ui.Warning)",
      ],
    ),
    @shared.section(
      "对话框",
      "Dialog 对话框",
      "同窗遮罩 + 居中面板；回调后自动收起，visible 由 Store 驱动。两个对话框由 main 挂在窗口根，本页只负责触发。",
      [
        @ui.row(
          [
            @ui.button("基础对话框", on_click=fn() {
              app.dlg_basic.set(true)
            }),
            @ui.button("表单对话框", variant=@ui.Solid, on_click=fn() {
              app.dlg_form.set(true)
            }),
            @ui.text("最近确认：", role=@ui.Body),
            @ui.bind(app.dlg_result.signal(), fn(n) {
              if n == "" {
                "（尚未提交）"
              } else {
                n
              }
            }),
          ],
          column_gap=8.0,
        ),
      ],
      code=[
        "let visible : @base.Store[Bool] = @base.Store::new(false)",
        "let name : @base.Store[String] = @base.Store::new(\"\")",
        "@ui.dialog(",
        "  visible,",
        "  \"新建连接\",",
        "  [",
        "    @ui.text(\"名称\", role=@ui.Body),",
        "    @ui.input(name, placeholder=\"例如：开发库\", width=320.0),",
        "  ],",
        ")",
        "visible.set(true)",
      ],
    ),

    @shared.section(
      "消息框",
      "自绘消息框",
      "纯自绘消息框（三平台同构，Esc 收起、Enter 走默认钮）：与「系统集成」页的原生消息框并存。响应编号由调用方在 buttons 里定，回调收编号。",
      [
        @ui.row(
          [
            @ui.button("信息·单钮", on_click=fn() {
              msg_kind.set(0)
              msg_text.set("这是一条信息档的自绘消息框。")
              msg_btns.set([("知道了", 1)])
              msg_open.set(true)
            }),
            @ui.button("警告·是/否", variant=@ui.Soft, on_click=fn() {
              msg_kind.set(1)
              msg_text.set("要继续这个演示吗？")
              msg_btns.set([("是", 1), ("否", 0)])
              msg_open.set(true)
            }),
            @ui.button("错误·三钮", variant=@ui.Danger, on_click=fn() {
              msg_kind.set(2)
              msg_text.set("演示用的错误消息。")
              msg_btns.set([("重试", 2), ("忽略", 1), ("取消", 0)])
              msg_open.set(true)
            }),
          ],
          column_gap=8.0,
        ),
        @ui.bind_label(msg_resp, fn(s) { s }),
        @widget.bind_node(
          @base.Signal::computed(fn() {
            (msg_kind.get(), msg_text.get(), msg_btns.get())
          }),
          fn(t : (Int, String, Array[(String, Int)])) -> @widget.Node {
            @ui.message_box(
              msg_open,
              "自绘消息框",
              t.1,
              kind=if t.0 == 1 {
                @ui.Warning
              } else if t.0 == 2 {
                @ui.Error
              } else {
                @ui.Information
              },
              informative="Esc 收起 · Enter 走默认钮",
              buttons=t.2,
              on_response=fn(r : Int) {
                msg_resp.set("自绘消息框响应：\{r}")
              },
            )
          },
        ),
      ],
      code=[
        "@ui.message_box(",
        "  open_store,          // 可见性：Store[Bool] 驱动",
        "  \"标题\", \"正文\",",
        "  kind=@ui.Warning,    // Default/Information/Warning/Question/Error",
        "  buttons=[(\"是\", 1), (\"否\", 0)],",
        "  on_response=fn(r) { ... },  // 收回按钮编号",
        ")",
      ],
    ),
  ])
}
