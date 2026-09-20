// 反馈组件页:Signal 驱动。对话框可见性挂窗口根(状态在 App),
// 反馈页的按钮只是触发方;Toast 推送函数经 App 传入。

///|
fn page_feedback(app : App) -> @yue.Node {
  scroll_page([
    section(
      "Alert 提示横幅",
      "四种语义类型:左侧色条 + 类型浅底 + 同族深字,文字垂直居中。",
      [
        @yue.alert("成功提示:配置已保存。", @yue.Success),
        @yue.alert("信息提示:有新版本可用。", @yue.Info),
        @yue.alert("警告提示:磁盘剩余空间不足。", @yue.Warning),
        @yue.alert("错误提示:网络连接已断开。", @yue.Danger),
      ],
    ),
    section("Alert 可关闭", "点击右侧 ✕ 关闭整条横幅。", [
      @yue.alert_closeable(
        "可关闭横幅:点我右侧的 ✕ 试试。",
        @yue.Warning,
      ),
    ]),
    section(
      "Result 结果页",
      "大色块符号 + 标题 + 描述 + 操作区;四种语义类型。",
      [
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
      ],
    ),
    section(
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
    ),
    section(
      "Toast 轻提示",
      "操作反馈瞬态提示:推送后顶部居中出现,2.6 秒自动消失,多条堆叠;层挂在窗口根(absolute 顶部,不占布局)。",
      [
        @yue.hbox([
          @yue.button_t("成功", on_click=fn() { app.toast_push("保存成功", @yue.Success) }),
          @yue.button_t("警告", on_click=fn() { app.toast_push("连接超时,已重试", @yue.Warning) }),
          @yue.button_t("错误", on_click=fn() { app.toast_push("提交失败:网络不可达", @yue.Danger) }),
          @yue.button_t("普通", variant=@yue.Solid, on_click=fn() { app.toast_push("已加入下载队列", @yue.Info) }),
        ]),
      ],
    ),
    section(
      "Dialog 对话框",
      "同窗遮罩 + 居中面板(absolute 相对挂载容器,本演示挂在窗口根,遮罩盖全窗);✕/取消/确定触发回调后自动收起,visible 由 Store 驱动(挂窗口根,状态在 App)。",
      [
        @yue.hbox([
          @yue.button_t("基础对话框", on_click=fn() { app.dlg_basic.set(true) }),
          @yue.button_t("表单对话框", variant=@yue.Solid, on_click=fn() { app.dlg_form.set(true) }),
          @yue.bind(app.dlg_name.signal(), fn(n) { if n == "" { "尚未提交" } else { "提交了:\\{n}" } }),
        ]),
      ],
    ),
  ])
}
