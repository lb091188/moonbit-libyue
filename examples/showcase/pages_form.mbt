// 表单组件页:Signal 驱动。表单值是可写源信号,组件参数经 .store()
// 视图接入(组件写回即信号变化),展示端 bind 直连派生。

///|
fn page_form(app : App) -> @yue.Node {
  let qty = @yue.Signal::new(3.0)
  let qty2 = @yue.Signal::new(1.0)
  let slider_val = @yue.Signal::new(30.0)
  let rate_val = @yue.Signal::new(3)
  let picked_color = @yue.Signal::new("#2D68C4")
  let dp_val : @yue.Signal[@yue.DateYMD?] = @yue.Signal::new(None)
  let sync = @yue.Signal::new(false)
  let notify = @yue.Signal::new(true)
  let theme_mode = @yue.Signal::new("深色")
  let radio_disabled = @yue.Signal::new("选项一")
  let wifi_on = @yue.Signal::new(true)
  let locked = @yue.Signal::new(false)
  let dr : @yue.Store[@yue.DateRange] = @yue.Store::new({ start: None, end: None })
  let tr : @yue.Store[@yue.TimeRange] = @yue.Store::new({ start: None, end: None })
  let dtr : @yue.Store[@yue.DateTimeRange] = @yue.Store::new({ start: None, end: None })
  scroll_page([
    section(
      "文本输入(Input / Textarea)",
      "自绘 1px 边框(聚焦变主题蓝)+ 白底;clearable 悬停非空时 ✕ 清空;多行内容超出按平台滚动。",
      [
        @yue.vbox([
          @yue.input_t(text="输入点什么…", margin=10.0),
          @yue.input_t(text="密码框", password=true),
          @yue.input_t(text="悬停出现 ✕,点击清空", clearable=true),
          @yue.textarea_t(
            text="多行文本输入演示。\n第二行内容。",
            height=90.0,
            width=300.0,
            clearable=true,
          ),
        ]),
      ],
    ),
    section(
      "数值输入(InputNumber / Slider / Rate)",
      "步进器 0..10 钳制;滑杆自绘轨道 + thumb(拖拽 step 5 量化);评分五角星 hover 预亮,值均响应式。",
      [
        @yue.input_number(qty.store(), min=0.0, max=10.0, step=1.0),
        @yue.bind(qty, fn(v) { "当前数量:\{v.round()}" }, style=[
          ("marginTop", 6.0),
        ]),
        @yue.slider_t(slider_val.store(), min=0.0, max=100.0, step=5.0),
        @yue.bind(slider_val, fn(v) { "当前值:\{v.round()}" }),
        @yue.rate_t(rate_val.store(), on_change=fn(v) { ignore(v) }),
        @yue.bind(rate_val, fn(v) { "评分:\{v} 星" }),
      ],
    ),
    section(
      "选择器(Select / ColorPicker)",
      "下拉点字段弹候选(悬停高亮/选中 ✓),clearable ✕ 清空;取色器预设色板点击选色,hex 值响应式。",
      [
        @yue.hbox(
          [
            @yue.select_t(
              ["杭州", "北京", "上海", "深圳", "广州"],
              app.picked_lang.store(),
              width=170.0,
              clearable=true,
            ),
            @yue.color_picker_t(picked_color.store()),
            @yue.bind(picked_color, fn(c) { c }),
          ],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "开关与勾选(Checkbox / Radio / Switch)",
      "勾选态存 Signal 勾选即回显;单选组整行悬停变色点击互斥(第二组禁用);开关开=主题蓝靠右,含禁用态。",
      [
        @yue.vbox([
          @yue.checkbox_t("启用自动同步", on_change=fn(v) { sync.set(v) }),
          @yue.checkbox_t("接收通知", checked=true, on_change=fn(v) {
            notify.set(v)
          }),
          @yue.hbox(
            [
              @yue.bind(sync, fn(v) { if v { "同步:开" } else { "同步:关" } }),
              @yue.label("   "),
              @yue.bind(notify, fn(v) { if v { "通知:开" } else { "通知:关" } }),
            ],
            style=[("marginTop", 8.0)],
          ),
        ]),
        @yue.hbox(
          [
            @yue.radio_group(["浅色", "深色", "跟随系统"], theme_mode.store()),
            @yue.label("        "),
            @yue.radio_group(
              ["选项一", "选项二"],
              radio_disabled.store(),
              disabled=true,
            ),
          ],
          style=[("marginTop", 10.0)],
        ),
        @yue.hbox(
          [
            @yue.switch_t(wifi_on.store()),
            @yue.bind(wifi_on, fn(v) {
              if v {
                "已开启"
              } else {
                "已关闭"
              }
            }),
            @yue.label("     "),
            @yue.switch_t(locked.store(), disabled=true),
            @yue.label_t("禁用", role=@yue.Body),
          ],
          style=[("marginTop", 10.0)],
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "日期与时间(DatePicker / 区间选择)",
      "全自绘月历(‹/› 切月)+ 内联 calendar_t;日期/时间/日期时间三区间选择器,选中值响应式。",
      [
        @yue.hbox(
          [
            @yue.date_picker_t(value=dp_val.store(), width=170.0, clearable=true),
            @yue.label_t("选中:", role=@yue.Body),
            @yue.bind(dp_val, fn(d) {
              match d {
                Some(v) => v.format()
                None => "未选"
              }
            }),
          ],
          style_str=[("alignItems", "center")],
        ),
        @yue.calendar_t(),
        @yue.vbox([
          @yue.date_range_picker_t(value=dr),
          @yue.bind_label(dr, fn(r) {
            match (r.start, r.end) {
              (Some(s), Some(e)) => "日期区间:\{s.format()} ~ \{e.format()}"
              (Some(s), None) => "日期区间:\{s.format()} ~ (再点终点日)"
              _ => "日期区间:未选择"
            }
          }),
          @yue.time_range_picker_t(value=tr),
          @yue.bind_label(tr, fn(r) {
            match (r.start, r.end) {
              (Some(s), Some(e)) => "时间区间:\{s.format()} ~ \{e.format()}"
              _ => "时间区间:未选择"
            }
          }),
          @yue.datetime_range_picker_t(value=dtr, width=340.0),
          @yue.bind_label(dtr, fn(r) {
            match (r.start, r.end) {
              (Some((sd, st)), Some((ed, et))) =>
                "日期时间区间:\{sd.format()} \{st.format()} ~ \{ed.format()} \{et.format()}"
              _ => "日期时间区间:未完成选择"
            }
          }),
        ]),
      ],
    ),
    section(
      "Form 表单组合",
      "form_item 行布局(标签右对齐 + 控件区)+ form 分组标题。",
      [
        @yue.form("用户设置", [
          @yue.form_item("用户名", @yue.input_t(text="moonbit", width=200.0)),
          @yue.form_item("城市", @yue.input_t(text="杭州", width=200.0)),
          @yue.form_item("数量", @yue.input_number(qty2.store(), min=1.0, max=9.0)),
        ]),
      ],
    ),
  ])
}
