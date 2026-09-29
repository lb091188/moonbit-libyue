// 表单组件页:Signal 驱动。表单值是可写源信号,组件参数经 .store()
// 视图接入(组件写回即信号变化),展示端 bind 直连派生。

///|
pub fn page_form(app : @ui.App) -> @yue.Node {
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
  let dtr : @yue.Store[@yue.DateTimeRange] = @yue.Store::new({
    start: None,
    end: None,
  })
  @ui.page([
    @ui.section(
      "输入",
      "文本输入(Input / Textarea)",
      "自绘 1px 边框(聚焦变中性灰)+ 白底;clearable 悬停非空时 ✕ 清空;多行内容超出按平台滚动。",
      [
        @yue.vbox([
          @yue.input_t(text="输入点什么…", clearable=true),
          @yue.input_t(text="密码框", password=true, clearable=true, style=[("marginTop", 10.0), ("marginBottom", 10.0)]),
          @yue.textarea_t(
            text="多行文本输入演示。\n第二行内容。",
            style=[("height", 90.0), ("width", 300.0)],
            clearable=true,
          ),
        ]),
      ],
      code=[
        "// input_t 边框输入框:自绘 1px 边框(聚焦变中性灰)+ 白底;text=初显文本",
        "// password=true 原生密码掩码(默认 false);margin=上下外边距(默认 0.0)",
        "// clearable=true 悬停且非空时右侧 ✕ 点击清空(默认 false);其余可选:",
        "// width 默认 280 / height 默认 32, on_input 收文本变化, invalid 挂 Store[Bool]",
        "// 为 true 时边框变红(校验失败态)",
        "@yue.input_t(text=\"输入点什么…\", margin=10.0)",
        "// 同一组件,仅换 password=true",
        "@yue.input_t(text=\"密码框\", password=true)",
        "// 可清空形态:✕ 只在悬停且有内容时出现",
        "@yue.input_t(text=\"悬停出现 ✕,点击清空\", clearable=true)",
        "// textarea_t 多行输入:参数同 input_t 套路(text/width 默认 280/",
        "// height 默认 110/margin/on_input/clearable/invalid),内容超出",
        "// 按平台自身滚动",
        "@yue.textarea_t(",
        "  text=\"多行文本输入演示。\\n第二行内容。\",",
        "  height=90.0,",
        "  width=300.0,",
        "  clearable=true,",
        ")",
      ],
    ),
    @ui.section(
      "数值",
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
      code=[
        "// Signal::new 建可写源信号;组件的 Store 参数用 signal.store() 视图",
        "// 接入:与信号共享值和订阅,组件写回即信号变化",
        "let qty = @yue.Signal::new(3.0)",
        "// input_number 步进器:两侧 -/+ 按钮按 step 加减,结果钳制在",
        "// [min, max];首参 Store[Double] 存值(必填),min/max 默认 0..100,",
        "// step 默认 1.0,num_width 中间数值区宽默认 64;本例钳到 0..10",
        "@yue.input_number(qty.store(), min=0.0, max=10.0, step=1.0)",
        "// bind(信号, fn):挂载即建 Label 显示 f(当前值),之后信号一变",
        "// 文本自动刷新;可选 style 叠加布局样式",
        "@yue.bind(qty, fn(v) { \"当前数量:\\{v.round()}\" })",
        "// slider_t 自绘滑杆:点击轨道/拖拽 thumb 调值,按 step 量化写入;",
        "// 首参 Store[Double],min/max/step 默认 0..100 步 1,on_change 随",
        "// 拖拽过程回调;width<=0(缺省)flex 占满父宽",
        "let slider_val = @yue.Signal::new(30.0)",
        "@yue.slider_t(slider_val.store(), min=0.0, max=100.0, step=5.0)",
        "// rate_t 评分:五角星,点击写入 Store[Int](0..max,max 默认 5),",
        "// 悬停预亮到第 N 颗;on_change 随写入回调(信号不去重,点同一颗星也触发)",
        "let rate_val = @yue.Signal::new(3)",
        "@yue.rate_t(rate_val.store())",
      ],
    ),
    @ui.section(
      "选择",
      "选择器(Select / ColorPicker)",
      "下拉点字段弹候选(悬停高亮/选中 ✓),clearable ✕ 清空;取色器预设色板点击选色,hex 值响应式。",
      [
        @yue.hbox(
          [
            @yue.select_t(
              ["杭州", "北京", "上海", "深圳", "广州"],
              app.picked_lang.store(),
              style=[("width", 170.0)],
              clearable=true,
            ),
            @yue.color_picker_t(picked_color.store()),
            @yue.bind(picked_color, fn(c) { c }),
          ],
          style=[("alignItems", "center")],
        ),
      ],
      code=[
        "// select_t 下拉选择:点击字段弹候选列表(Popover),悬停高亮、",
        "// 当前项主题色 ✓,点选回填收起,失焦收起;位置参数:选项数组 →",
        "// 选中值 Store[String](存选中项文本,清空即置空串);width 默认 200,",
        "// on_change 选中时回调,clearable ✕ 清空(默认 false)",
        "let city = @yue.Signal::new(\"\")",
        "@yue.select_t(",
        "  [\"杭州\", \"北京\", \"上海\", \"深圳\", \"广州\"],",
        "  city.store(),",
        "  width=170.0,",
        "  clearable=true,",
        ")",
        "// color_picker_t 取色器:字段显「色块 + hex + 箭头」,点击弹预设色板,",
        "// 点色块写入 \"#RRGGBB\" 并收起;colors 自定色板(默认 15 色),",
        "// width 默认 200",
        "let color = @yue.Signal::new(\"#2D68C4\")",
        "@yue.color_picker_t(color.store())",
        "// bind 直连信号:选中色 hex 一变文本即刷新(此处原样回显)",
        "@yue.bind(color, fn(c) { c })",
      ],
    ),
    @ui.section(
      "开关",
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
            @yue.radio_group(
              ["浅色", "深色", "跟随系统"],
              theme_mode.store(),
            ),
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
          style=[("marginTop", 10.0), ("alignItems", "center")],
        ),
      ],
      code=[
        "// checkbox_t 复选框:14x14 方框,选中实心主题色 + 白勾;首参标题,",
        "// checked=初始勾选(Bool 初值,勾选态存组件内部,默认 false),",
        "// disabled 禁用;on_change 收点击后的新勾选态——这里手动写回源信号",
        "let sync = @yue.Signal::new(false)",
        "@yue.checkbox_t(\"启用自动同步\", on_change=fn(v) { sync.set(v) })",
        "// bind 直连:信号一变,开/关文案自动刷新",
        "@yue.bind(sync, fn(v) { if v { \"同步:开\" } else { \"同步:关\" } })",
        "// radio_group 单选组:整行悬停变色,点击互斥并把选中项文本写回",
        "// Store[String];位置参数:选项数组 → 选中值 Store,disabled 整组禁用",
        "let mode = @yue.Signal::new(\"深色\")",
        "@yue.radio_group([\"浅色\", \"深色\", \"跟随系统\"], mode.store())",
        "// switch_t 开关:开=主题蓝轨道滑块靠右,关=浅灰靠左,点击切换写回",
        "// Store[Bool];disabled 不响应点击且滑块变浅",
        "let wifi_on = @yue.Signal::new(true)",
        "@yue.switch_t(wifi_on.store())",
        "@yue.switch_t(@yue.Signal::new(false).store(), disabled=true)",
      ],
    ),
    @ui.section(
      "日期",
      "日期与时间(DatePicker / 区间选择)",
      "全自绘月历(‹/› 切月)+ 内联 calendar_t;日期/时间/日期时间三区间选择器,选中值响应式。",
      [
        @yue.hbox(
          [
            @yue.date_picker_t(
              value=dp_val.store(),
              style=[("width", 170.0)],
              clearable=true,
            ),
            @yue.label_t("选中:", role=@yue.Body),
            @yue.bind(dp_val, fn(d) {
              match d {
                Some(v) => v.format()
                None => "未选"
              }
            }),
          ],
          style=[("alignItems", "center")],
        ),
        @yue.calendar_t(),
        @yue.vbox([
          @yue.datetime_range_picker_t(value=dtr),
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
        "// date_picker_t 日期选择器:点击字段弹自绘月历(‹/› 切月),点选",
        "// 回填收起;value 接 Store[DateYMD?],None 即未选;on_change 选中时",
        "// 回调,width 默认 200,placeholder 默认「请选择日期」,clearable",
        "// ✕ 清空置 None(清空不触发 on_change)",
        "let dp : @yue.Signal[@yue.DateYMD?] = @yue.Signal::new(None)",
        "@yue.date_picker_t(value=dp.store(), width=170.0, clearable=true)",
        "// bind 读 DateYMD?:Some 显 format(),None 显占位文案",
        "@yue.bind(dp, fn(d) {",
        "  match d {",
        "    Some(v) => v.format()",
        "    None => \"未选\"",
        "  }",
        "})",
        "// calendar_t 内联月历(不经弹层):‹/› 切月 + 42 格月网格,跨月灰显、",
        "// 「今天」主题色;可选 on_pick(点当月日期回调)与 value 同步选中",
        "@yue.calendar_t()",
        "// 三种区间选择器:value 分别接 DateRange / TimeRange / DateTimeRange",
        "// 的 Store(start/end 类型上各自可空);tr / dtr 定义同理,此处省略。",
        "// 回调与写入时机:日期区间点两次选完起止才写 value 并回调;时间",
        "// 区间起止默认 00:00、步进即改即写即回调(恒成对);日期时间区间",
        "// 选到一半碰到时间步进才把已定起点先行写入 value",
        "let dr : @yue.Store[@yue.DateRange] =",
        "  @yue.Store::new({ start: None, end: None })",
        "// 日期区间:点两次选起止,终点早于起点自动对调;width 默认 260",
        "@yue.date_range_picker_t(value=dr)",
        "// 时间区间:弹起/止两行步进编辑器(时 0-23 / 分 0-59);width 默认 180",
        "@yue.time_range_picker_t(value=tr)",
        "// 日期时间区间:区间日历 + 底部起/止时间步进;width 默认 340",
        "@yue.datetime_range_picker_t(value=dtr, width=340.0)",
      ],
    ),
    @ui.section(
      "表单",
      "Form 表单组合",
      "form_item 行布局(标签右对齐 + 控件区)+ form 分组标题。",
      [
        @yue.form("用户设置", [
          @yue.form_item("用户名", @yue.input_t(text="moonbit", style=[("width", 200.0)])),
          @yue.form_item("城市", @yue.input_t(text="杭州", style=[("width", 200.0)])),
          @yue.form_item(
            "数量",
            @yue.input_number(qty2.store(), min=1.0, max=9.0),
          ),
        ]),
      ],
      code=[
        "// form(标题, items):Section 角色分组标题 + 纵向排一组表单项",
        "let qty = @yue.Signal::new(1.0)",
        "@yue.form(\"用户设置\", [",
        "  // form_item(标签, 控件):标签灰色右对齐(定宽 label_width 默认 90,",
        "  // 右边距 12)+ 右侧控件区垂直居中;error 挂 Store[String],非空时",
        "  // 控件行下方显 danger 红字(行高预留,出现/消失不跳动)",
        "  @yue.form_item(\"用户名\", @yue.input_t(text=\"moonbit\", width=200.0)),",
        "  @yue.form_item(\"数量\", @yue.input_number(qty.store(), min=1.0, max=9.0)),",
        "])",
      ],
    ),
  ])
}
