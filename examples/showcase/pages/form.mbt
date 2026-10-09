// 表单组件页:Signal 驱动。表单值是可写源信号,组件参数经 .store()
// 视图接入(组件写回即信号变化),展示端 bind 直连派生。

///|
pub fn page_form(app : @ui.App) -> @yue.Node {
  let qty = @yue.Signal::new(3.0)
  let qty2 = @yue.Signal::new(1.0)
  let slider_val = @yue.Signal::new(30.0)
  let rate_val = @yue.Signal::new(3)
  let picked_color = @yue.Signal::new("#2D68C4")
  let dp_val : @yue.Signal[@components.DateYMD?] = @yue.Signal::new(None)
  let sync = @yue.Signal::new(false)
  let notify = @yue.Signal::new(true)
  let theme_mode = @yue.Signal::new("深色")
  let radio_disabled = @yue.Signal::new("选项一")
  let wifi_on = @yue.Signal::new(true)
  let locked = @yue.Signal::new(false)
  let dtr : @yue.Store[@components.DateTimeRange] = @yue.Store::new({
    start: None,
    end: None,
  })
  @ui.page([
    @ui.section(
      "输入",
      "Input 与 Textarea",
      "自绘 1px 边框(聚焦变中性灰)+ 白底;clearable 悬停非空时 ✕ 清空;多行内容超出按平台滚动。",
      [
        @yue.vbox([
          @components.input_t(text="输入点什么…", clearable=true),
          @components.input_t(text="密码框", password=true, clearable=true, style=[
            ("marginTop", 10.0),
            ("marginBottom", 10.0),
          ]),
          @components.textarea_t(
            text="多行文本输入演示。\n第二行内容。",
            style=[("height", 90.0), ("width", 300.0)],
            clearable=true,
          ),
        ]),
      ],
      code=[
        "@components.input_t(text=\"输入点什么…\")", "@components.input_t(text=\"密码框\", password=true)",
        "@components.input_t(text=\"悬停出现 ✕,点击清空\", clearable=true)", "@components.textarea_t(",
        "  text=\"多行文本输入演示。\\n第二行内容。\",", "  style=[(\"height\", 90.0), (\"width\", 300.0)],",
        "  clearable=true,", ")",
      ],
    ),
    @ui.section(
      "数值",
      "InputNumber / Slider / Rate",
      "步进器 0..10 钳制;滑杆自绘轨道 + thumb(拖拽 step 5 量化);评分五角星 hover 预亮,值均响应式。",
      [
        @components.input_number(qty.store(), min=0.0, max=10.0, step=1.0),
        @yue.bind(qty, fn(v) { "当前数量:\{v.round()}" }, style=[
          ("marginTop", 6.0),
        ]),
        @components.slider_t(slider_val.store(), min=0.0, max=100.0, step=5.0),
        @yue.bind(slider_val, fn(v) { "当前值:\{v.round()}" }),
        @components.rate_t(rate_val.store(), on_change=fn(v) { ignore(v) }),
        @yue.bind(rate_val, fn(v) { "评分:\{v} 星" }),
      ],
      code=[
        "let qty = @yue.Signal::new(3.0)", "@components.input_number(qty.store(), min=0.0, max=10.0, step=1.0)",
        "@yue.bind(qty, fn(v) { \"当前数量:\\{v.round()}\" })", "let slider_val = @yue.Signal::new(30.0)",
        "@components.slider_t(slider_val.store(), min=0.0, max=100.0, step=5.0)", "let rate_val = @yue.Signal::new(3)",
        "@components.rate_t(rate_val.store())",
      ],
    ),
    @ui.section(
      "选择",
      "Select 与 ColorPicker",
      "下拉点字段弹候选(悬停高亮/选中 ✓),clearable ✕ 清空;取色器预设色板点击选色,hex 值响应式。",
      [
        @yue.vbox(
          [
            @components.select_t(
              ["杭州", "北京", "上海", "深圳", "广州"],
              app.picked_lang.store(),
              style=[("width", 170.0), ("marginBottom", 10.0)],
              clearable=true,
            ),
            @components.color_picker_t(picked_color.store()),
            @yue.bind(picked_color, fn(c) { c }),
          ],
          style=[("alignItems", "flex-start")],
        ),
      ],
      code=[
        "let city = @yue.Signal::new(\"\")", "@components.select_t(", "  [\"杭州\", \"北京\", \"上海\", \"深圳\", \"广州\"],",
        "  city.store(),", "  style=[(\"width\", 170.0)],", "  clearable=true,",
        ")", "let color = @yue.Signal::new(\"#2D68C4\")", "@components.color_picker_t(color.store())",
        "@yue.bind(color, fn(c) { c })",
      ],
    ),
    @ui.section(
      "开关",
      "Checkbox / Radio / Switch",
      "勾选经 on_change 写回信号即时回显;单选组整行悬停、点击互斥(第二组禁用);开关开=主题蓝靠右,含禁用态。",
      [
        @yue.vbox([
          @components.checkbox_t("启用自动同步", on_change=fn(v) { sync.set(v) }),
          @components.checkbox_t("接收通知", checked=true, on_change=fn(v) {
            notify.set(v)
          }),
          @yue.hbox(
            [
              @yue.bind(sync, fn(v) {
                if v {
                  "同步:开"
                } else {
                  "同步:关"
                }
              }),
              @yue.label("   "),
              @yue.bind(notify, fn(v) {
                if v {
                  "通知:开"
                } else {
                  "通知:关"
                }
              }),
            ],
            style=[("marginTop", 8.0)],
          ),
        ]),
        @yue.hbox(
          [
            @components.radio_group(
              ["浅色", "深色", "跟随系统"],
              theme_mode.store(),
            ),
            @yue.label("        "),
            @components.radio_group(
              ["选项一", "选项二"],
              radio_disabled.store(),
              disabled=true,
            ),
          ],
          style=[("marginTop", 10.0)],
        ),
        @yue.hbox(
          [
            @components.switch_t(wifi_on.store()),
            @yue.bind(wifi_on, fn(v) {
              if v {
                "已开启"
              } else {
                "已关闭"
              }
            }),
            @yue.label("     "),
            @components.switch_t(locked.store(), disabled=true),
            @components.label_t("禁用", role=@components.Body),
          ],
          style=[("marginTop", 10.0), ("alignItems", "center")],
        ),
      ],
      code=[
        "let sync = @yue.Signal::new(false)", "@components.checkbox_t(\"启用自动同步\", on_change=fn(v) { sync.set(v) })",
        "@yue.bind(sync, fn(v) { if v { \"同步:开\" } else { \"同步:关\" } })",
        "let mode = @yue.Signal::new(\"深色\")", "@components.radio_group([\"浅色\", \"深色\", \"跟随系统\"], mode.store())",
        "let wifi_on = @yue.Signal::new(true)", "@components.switch_t(wifi_on.store())",
        "@components.switch_t(@yue.Signal::new(false).store(), disabled=true)",
      ],
    ),
    @ui.section(
      "日期",
      "日期与时间选择",
      "全自绘月历(‹/› 切月)+ 内联 calendar_t;日期/时间/日期时间三区间选择器,选中值响应式。",
      [
        @yue.vbox(
          [
            @components.date_picker_t(
              value=dp_val.store(),
              style=[("width", 170.0)],
              clearable=true,
            ),
            @yue.hbox([
              @components.label_t("选中:", role=@components.Body),
              @yue.bind(dp_val, fn(d) {
                match d {
                  Some(v) => v.format()
                  None => "未选"
                }
              }),
            ]),
          ],
          style=[("alignItems", "flex-start"), ("marginBottom", 10.0)],
        ),
        @components.calendar_t(style=[("marginBottom", 10.0)]),
        @yue.vbox([
          @components.datetime_range_picker_t(value=dtr),
          @yue.bind_label(dtr, fn(r) {
            match (r.start, r.end) {
              (Some((sd, st)), Some((ed, et))) =>
                "日期时间区间:\{sd.format()} \{st.format()} ~ \{ed.format()} \{et.format()}"
              _ => "日期时间区间:未完成选择"
            }
          }),
        ]),
      ],
      code=[
        "let dp : @yue.Signal[@components.DateYMD?] = @yue.Signal::new(None)", "@components.date_picker_t(value=dp.store(), style=[(\"width\", 170.0)], clearable=true)",
        "@yue.bind(dp, fn(d) {", "  match d {", "    Some(v) => v.format()", "    None => \"未选\"",
        "  }", "})", "@components.calendar_t()", "let dr : @yue.Store[@components.DateRange] =",
        "  @yue.Store::new({ start: None, end: None })", "@components.date_range_picker_t(value=dr)",
        "let tr : @yue.Store[@components.TimeRange] =", "  @yue.Store::new({ start: None, end: None })",
        "@components.time_range_picker_t(value=tr)", "let dtr : @yue.Store[@components.DateTimeRange] =",
        "  @yue.Store::new({ start: None, end: None })", "@components.datetime_range_picker_t(value=dtr)",
      ],
    ),
    @ui.section(
      "表单",
      "Form 表单",
      "form_item 行布局(标签右对齐 + 控件区)+ form 分组标题。",
      [
        @components.form("用户设置", [
          @components.form_item(
            "用户名",
            @components.input_t(text="moonbit", style=[("width", 200.0)]),
          ),
          @components.form_item(
            "城市",
            @components.input_t(text="杭州", style=[("width", 200.0)]),
          ),
          @components.form_item(
            "数量",
            @components.input_number(qty2.store(), min=1.0, max=9.0),
          ),
        ]),
      ],
      code=[
        "let qty = @yue.Signal::new(1.0)", "@components.form(\"用户设置\", [", "  @components.form_item(\"用户名\", @components.input_t(text=\"moonbit\", style=[(\"width\", 200.0)])),",
        "  @components.form_item(\"数量\", @components.input_number(qty.store(), min=1.0, max=9.0)),",
        "])",
      ],
    ),
  ])
}
