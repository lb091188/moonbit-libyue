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
        @yue.alert("成功提示:配置已保存。", @yue.Success),
        @yue.alert("信息提示:有新版本可用。", @yue.Info),
        @yue.alert("警告提示:磁盘剩余空间不足。", @yue.Warning),
        @yue.alert("错误提示:网络连接已断开。", @yue.Danger),
      ],
      code=[
        "// alert(文字, 语义类型, height?=40.0):类型浅底 + 左侧色条 + 同族深字,",
        "// 全宽、文字垂直居中;类型 Success/Info/Warning/Danger/Primary 任选其一",
        "@yue.alert(\"成功提示:配置已保存。\", @yue.Success)",
        "@yue.alert(\"信息提示:有新版本可用。\", @yue.Info)",
        "@yue.alert(\"警告提示:磁盘剩余空间不足。\", @yue.Warning)",
        "@yue.alert(\"错误提示:网络连接已断开。\", @yue.Danger)",
      ],
    ),
    @ui.section(
      "可关闭",
      "Alert 可关闭",
      "点击右侧 ✕ 关闭整条横幅。",
      [
        @yue.alert_closeable(
          "可关闭横幅:点我右侧的 ✕ 试试。",
          @yue.Warning,
        ),
      ],
      code=[
        "// alert_closeable(文字, 语义类型):同 alert 样式,右侧多一枚 ✕,点击整条隐藏",
        "@yue.alert_closeable(\"可关闭横幅:点我右侧的 ✕ 试试。\", @yue.Warning)",
      ],
    ),
    @ui.section(
      "结果页",
      "Result 结果页",
      "大色块符号 + 标题 + 描述 + 操作区;四种语义类型。",
      [
        @yue.hbox([
          @yue.result(
            @yue.Success,
            "操作成功",
            "配置已写入并生效。",
            [@yue.button_t("返回首页")],
          ),
          @yue.result(
            @yue.Danger,
            "操作失败",
            "网络异常,请稍后重试。",
            [@yue.button_t("重新加载", variant=@yue.Soft)],
          ),
          ])
      ],
      code=[
        "// result(语义类型, 标题, 描述, 操作区节点数组):大色块图标随类型画符号",
        "// Success 画 ✓、Danger 画 ✕、其余画感叹号;整块高 208,内容居中排版",
        "@yue.result(",
        "  @yue.Success,                // 语义类型",
        "  \"操作成功\",                   // 标题",
        "  \"配置已写入并生效。\",          // 描述",
        "  // 第 4 参元素常用 button_t(文字, on_click?, variant?=Soft)",
        "  [@yue.button_t(\"返回首页\")], // 操作区:任意 Node 数组,常放按钮",
        ")",
      ],
    ),
    @ui.section(
      "气泡",
      "Popover 气泡弹层",
      "popover_t 给任意节点包点击弹层:内容为任意 Node,再次点击收起。",
      [
        @yue.popover_t(
          @yue.button_t("打开气泡"),
          @yue.label_t("气泡内容:任意 Node。", role=@yue.Body),
          180.0,
          60.0,
        ),
      ],
      code=[
        "// popover_t(触发节点, 弹层内容, 宽, 高):点触发件在其下方弹出弹层,",
        "// 内容为任意 Node,再次点击收起;点弹层外空白也收起(Linux 系统行为)",
        "@yue.popover_t(",
        "  @yue.button_t(\"打开气泡\"), // 触发节点;button_t(文字, on_click?, variant?=Soft)",
        "  @yue.label_t(\"气泡内容:任意 Node。\", role=@yue.Body), // 弹层内容;role=Body 正文档(默认)",
        "  180.0,   // 弹层宽",
        "  60.0,    // 弹层高",
        ")",
      ],
    ),
    @ui.section(
      "轻提示",
      "Toast 轻提示",
      "操作反馈瞬态提示:推送后顶部居中出现,2.6 秒自动消失,多条堆叠;层挂在窗口根(absolute 顶部,不占布局)。",
      [
        @yue.hbox([
          @yue.button_t("成功", on_click=fn() {
            app.toast_push("保存成功", @yue.Success)
          }),
          @yue.button_t("警告", on_click=fn() {
            app.toast_push("连接超时,已重试", @yue.Warning)
          }),
          @yue.button_t("错误", on_click=fn() {
            app.toast_push("提交失败:网络不可达", @yue.Danger)
          }),
          @yue.button_t("普通", variant=@yue.Solid, on_click=fn() {
            app.toast_push("已加入下载队列", @yue.Info)
          }),
        ]),
      ],
      code=[
        "// toast_layer(duration_ms?=2600):返回 (层节点, 推送函数);层节点挂窗口根",
        "// (absolute 顶部横条,不占布局),推送后 duration_ms 毫秒自动消失,",
        "// 多条自上而下堆叠;推送须在层挂载之后调用(典型:按钮回调里)",
        "let (toast_node, toast_push) = @yue.toast_layer()",
        "// toast_node 加入 mount_window 根节点数组,之后任意位置推送:",
        "toast_push(\"保存成功\", @yue.Success)      // push(文字, 语义类型)",
        "toast_push(\"连接超时,已重试\", @yue.Warning)",
        "toast_push(\"提交失败:网络不可达\", @yue.Danger)",
      ],
    ),
    @ui.section(
      "对话框",
      "Dialog 对话框",
      "同窗遮罩 + 居中面板;回调后自动收起,visible 由 Store 驱动。",
      [
        @yue.hbox([
          @yue.button_t("基础对话框", on_click=fn() {
            app.dlg_basic.set(true)
          }),
          @yue.button_t("表单对话框", variant=@yue.Solid, on_click=fn() {
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
        "// dialog_t(visible, 标题, 内容节点数组, width?=420, confirm_text?=\"确定\",",
        "// cancel_text?=\"取消\", on_confirm?, on_cancel?, close_on_mask?=false):",
        "// visible 由 Store[Bool] 驱动弹/收;确定/取消/✕ 触发回调后自动收起;",
        "// 按钮文案传空串隐藏该按钮(两空则整行不显示);close_on_mask 点遮罩也收",
        "let visible = @yue.Store::new(false)   // Store::new(初值):可订阅的值",
        "let name = @yue.Store::new(\"\")",
        "@yue.dialog_t(",
        "  visible,        // Store[Bool]:set(true) 弹出,set(false) 收起",
        "  \"新建连接\",      // 标题栏文字,右侧自带 ✕",
        "  [",
        "    @yue.label_t(\"名称\", role=@yue.Body),   // role 文字角色,Body=正文档(默认)",
        "    // input_t(...):边框输入框;每次键入触发 on_input(t=当前文本),width 默认 280",
        "    @yue.input_t(text=\"\", width=320.0, on_input=fn(t) { name.set(t) }),",
        "  ],",
        "  width=380.0,    // 面板宽,默认 420",
        ")",
        "// 任意位置 set(true) 打开:",
        "visible.set(true)",
      ],
    ),
  ])
}
