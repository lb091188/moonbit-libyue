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
  let theme_mode = @yue.Signal::new("深色")
  let radio_disabled = @yue.Signal::new("选项一")
  let wifi_on = @yue.Signal::new(true)
  let locked = @yue.Signal::new(false)
  let dr : @yue.Store[@yue.DateRange] = @yue.Store::new({ start: None, end: None })
  let tr : @yue.Store[@yue.TimeRange] = @yue.Store::new({ start: None, end: None })
  let dtr : @yue.Store[@yue.DateTimeRange] = @yue.Store::new({ start: None, end: None })
  scroll_page([
    section(
      "Input 输入框",
      "现代化主题唯一输入框:外层自绘 1px 边框(聚焦变主题蓝)+ 白底,内部 Entry 去原生边框与内阴影;margin 控制外边距,直角。clearable=true:悬停且非空时右侧出现 ✕,点击清空。",
      [
        @yue.vbox([
          @yue.input_t(text="输入点什么…", margin=10.0),
          @yue.input_t(text="密码框", password=true),
          @yue.input_t(text="悬停出现 ✕,点击清空", clearable=true),
        ]),
      ],
    ),
    section(
      "Textarea 多行输入",
      "外层自绘边框(聚焦变主题色)+ 8px 内边距,内容超出按平台滚动;clearable=true 悬停非空时 ✕ 清空。",
      [
        @yue.textarea_t(
          text="多行文本输入演示。\n第二行内容。",
          height=90.0,
          width=300.0,
          clearable=true,
        ),
      ],
    ),
    section(
      "InputNumber 数字输入器",
      "-/+ 按钮步进(步长 1),范围 0..10 钳制,数值响应式。",
      [
        @yue.input_number(qty.store(), min=0.0, max=10.0, step=1.0),
        @yue.bind(qty, fn(v) { "当前数量:\{v.round()}" }, style=[
          ("marginTop", 6.0),
        ]),
      ],
    ),
    section(
      "Select 下拉选择",
      "点击字段弹候选列表(EP 样式):悬停高亮、当前选中 ✓ 标记,点选回填并收起;clearable=true 悬停有值时箭头旁 ✕ 清空选择;三平台同形态。",
      [
        @yue.select_t(
          ["杭州", "北京", "上海", "深圳", "广州"],
          app.picked_lang.store(),
          width=170.0,
          clearable=true,
        ),
      ],
    ),
    section(
      "DatePicker 日期选择",
      "全自绘日历(EP 样式):点字段弹月历,‹/› 切月,点选回填;下方为内联 calendar_t 面板;clearable=true 悬停有值时 ✕ 清空。",
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
      ],
    ),
    section(
      "区间选择(日期 / 时间 / 日期时间)",
      "date_range_picker_t:区间日历两段式点选起止(终点早于起点自动对调);time_range_picker_t:起/止时:分步进,步进即改;datetime_range_picker_t:日历选日 + 底部时间步进,「完成」或失焦收起。值经 Store 驱动回显。",
      [
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
      "Slider 滑杆",
      "自绘轨道 + thumb,点击/拖拽调值(step 5 量化),值响应式。",
      [
        @yue.slider_t(slider_val.store(), min=0.0, max=100.0, step=5.0),
        @yue.bind(slider_val, fn(v) { "当前值:\{v.round()}" }),
      ],
    ),
    section(
      "Rate 评分",
      "五角星:选中实心主题色、未选中描边灰,hover 预亮,点击评分。",
      [
        @yue.rate_t(rate_val.store(), on_change=fn(v) { ignore(v) }),
        @yue.bind(rate_val, fn(v) { "评分:\{v} 星" }),
      ],
    ),
    section(
      "Radio 单选组",
      "选中项实心方块 + 主题色文字,整行悬停变色,点击互斥;第二组为禁用态。",
      [
        @yue.hbox([
          @yue.vbox([
            @yue.radio_group(["浅色", "深色", "跟随系统"], theme_mode.store()),
          ]),
          @yue.label("        "),
          @yue.vbox([
            @yue.radio_group(
              ["选项一", "选项二"],
              radio_disabled.store(),
              disabled=true,
            ),
          ]),
        ]),
      ],
    ),
    section(
      "Switch 开关",
      "开=主题蓝轨道滑块靠右,关=浅灰轨道滑块靠左;点击切换,含禁用态。",
      [
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
          style_str=[("alignItems", "center")],
        ),
      ],
    ),
    section(
      "ColorPicker 取色器",
      "预设色板:点击选色,选中主题色描边 + 白勾;hex 值响应式。",
      [@yue.color_picker_t(picked_color.store())],
    ),
    section(
      "Form 表单",
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
