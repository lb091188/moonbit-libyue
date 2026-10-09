// 反馈组件页:Signal 驱动。对话框可见性挂窗口根(状态在 App),
// 反馈页的按钮只是触发方;Toast 推送函数经 App 传入。

///|
pub fn page_feedback(app : @ui.App) -> @yue.Node {
  @ui.page([
    @ui.section(
      "横幅",
      "Alert 提示横幅",
      "四种语义类型:左侧色条 + 类型浅底 + 同族深字,文字垂直居中。",
      [
        @components.alert("成功提示:配置已保存。", @components.Success),
        @components.alert("信息提示:有新版本可用。", @components.Info),
        @components.alert("警告提示:磁盘剩余空间不足。", @components.Warning),
        @components.alert("错误提示:网络连接已断开。", @components.Danger),
      ],
      code=[
        "@components.alert(\"成功提示:配置已保存。\", @components.Success)", "@components.alert(\"信息提示:有新版本可用。\", @components.Info)",
        "@components.alert(\"警告提示:磁盘剩余空间不足。\", @components.Warning)",
        "@components.alert(\"错误提示:网络连接已断开。\", @components.Danger)",
      ],
    ),
    @ui.section(
      "可关闭",
      "Alert 可关闭",
      "点击右侧 ✕ 关闭整条横幅。",
      [
        @components.alert_closeable(
          "可关闭横幅:点我右侧的 ✕ 试试。",
          @components.Warning,
        ),
      ],
      code=[
        "@components.alert_closeable(\"可关闭横幅:点我右侧的 ✕ 试试。\", @components.Warning)",
      ],
    ),
    @ui.section(
      "结果页",
      "Result 结果页",
      "大色块符号 + 标题 + 描述 + 操作区;四种语义类型。",
      [
        @yue.hbox([
          @components.result(
            @components.Success,
            "操作成功",
            "配置已写入并生效。",
            [@components.button_t("返回首页")],
          ),
          @components.result(
            @components.Danger,
            "操作失败",
            "网络异常,请稍后重试。",
            [@components.button_t("重新加载", variant=@components.Soft)],
          ),
        ]),
      ],
      code=[
        "@components.result(", "  @components.Success,", "  \"操作成功\",", "  \"配置已写入并生效。\",",
        "  [@components.button_t(\"返回首页\")],", ")",
      ],
    ),
    @ui.section(
      "气泡",
      "Popover 气泡弹层",
      "popover_t 给任意节点包点击弹层:内容为任意 Node,再次点击收起。",
      [
        @components.popover_t(
          @components.button_t("打开气泡"),
          @components.label_t("气泡内容:任意 Node。", role=@components.Body),
          180.0,
          60.0,
        ),
      ],
      code=[
        "@components.popover_t(", "  @components.button_t(\"打开气泡\"),", "  @components.label_t(\"气泡内容:任意 Node。\", role=@components.Body),",
        "  180.0,", "  60.0,", ")",
      ],
    ),
    @ui.section(
      "轻提示",
      "Toast 轻提示",
      "操作反馈瞬态提示:推送后顶部居中出现,2.6 秒自动消失,多条堆叠;层挂在窗口根(absolute 顶部,不占布局)。",
      [
        @yue.hbox([
          @components.button_t("成功", on_click=fn() {
            app.toast_push("保存成功", @components.Success)
          }),
          @components.button_t("警告", on_click=fn() {
            app.toast_push("连接超时,已重试", @components.Warning)
          }),
          @components.button_t("错误", on_click=fn() {
            app.toast_push("提交失败:网络不可达", @components.Danger)
          }),
          @components.button_t("普通", variant=@components.Solid, on_click=fn() {
            app.toast_push("已加入下载队列", @components.Info)
          }),
        ]),
      ],
      code=[
        "let (toast_node, toast_push) = @components.toast_layer()", "// toast_node 加入 mount_window 根节点数组,之后任意位置推送:",
        "toast_push(\"保存成功\", @components.Success)", "toast_push(\"连接超时,已重试\", @components.Warning)",
      ],
    ),
    @ui.section(
      "对话框",
      "Dialog 对话框",
      "同窗遮罩 + 居中面板;回调后自动收起,visible 由 Store 驱动。",
      [
        @yue.hbox([
          @components.button_t("基础对话框", on_click=fn() {
            app.dlg_basic.set(true)
          }),
          @components.button_t("表单对话框", variant=@components.Solid, on_click=fn() {
            app.dlg_form.set(true)
          }),
          @yue.bind(app.dlg_name.signal(), fn(n) {
            if n == "" {
              "尚未提交"
            } else {
              "提交了:\\{n}"
            }
          }),
        ]),
      ],
      code=[
        "let visible = @yue.Store::new(false)", "let name = @yue.Store::new(\"\")",
        "@components.dialog_t(", "  visible,", "  \"新建连接\",", "  [", "    @components.label_t(\"名称\", role=@components.Body),",
        "    @components.input_t(text=\"\", style=[(\"width\", 320.0)], on_input=fn(t) { name.set(t) }),",
        "  ],", "  style=[(\"width\", 380.0)],", ")", "visible.set(true)",
      ],
    ),
  ])
}
