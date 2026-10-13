// 表单组件页：Store/Signal 驱动。表单值是可写源 Store（组件直接吃 Store，
// 组件写回即状态变化），展示端 bind_label/bind 直连派生。
//
// G7 迁移记档（与 master 的差异）：
// ① `input_t` → `entry`（Store 驱动，`clearable` 未迁，清空走全选+删除）；
// ② `input_number`（Double）→ `stepper`（Int 步进器——自绘栈无原生输入框语义）；
// ③ `radio_group` 的值从「选项字符串」换成「索引 Store[Int]」；
// ④ `checkbox` 从「on_change 写回信号」换成「Store 即状态源」，语义等价；
// ⑤ `style=[("width",…)]` 一类 CSS 通道不存在，宽高/间距全走命名参数。
pub fn page_form(_app : @shared.App) -> @core.Node {
  let qty : @core.Store[Int] = @core.Store::new(3)
  let qty2 : @core.Store[Int] = @core.Store::new(1)
  let slider_val : @core.Store[Double] = @core.Store::new(30.0)
  let rate_val : @core.Store[Int] = @core.Store::new(3)
  let picked_color : @core.Store[String] = @core.Store::new("#2D68C4")
  let dp_val : @core.Store[@ui.DateYMD?] = @core.Store::new(None)
  let sync : @core.Store[Bool] = @core.Store::new(false)
  let notify : @core.Store[Bool] = @core.Store::new(true)
  let theme_idx : @core.Store[Int] = @core.Store::new(1)
  let radio_idx : @core.Store[Int] = @core.Store::new(0)
  let wifi_on : @core.Store[Bool] = @core.Store::new(true)
  let locked : @core.Store[Bool] = @core.Store::new(false)
  let dtr : @core.Store[@ui.DateTimeRange] = @core.Store::new({ start: None, end: None })
  @shared.page([
    @shared.section(
      "输入",
      "输入框与多行",
      "单行 entry（Store 驱动，密码态逐字符遮罩）+ 多行 textarea（自动折行、超宽滚动）。",
      [
        @ui.col(
          [
            @ui.entry(@core.Store::new(""), placeholder="输入点什么…", width=300.0),
            @ui.entry(
              @core.Store::new(""),
              placeholder="密码框",
              password=true,
              width=300.0,
            ),
            @ui.textarea(
              @core.Store::new("多行文本输入演示。\n第二行内容。"),
              rows=3,
              width=300.0,
            ),
          ],
          row_gap=10.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "@ui.entry(@core.Store::new(\"\"), placeholder=\"输入点什么…\", width=300.0)",
        "@ui.entry(@core.Store::new(\"\"), placeholder=\"密码框\", password=true, width=300.0)",
        "@ui.textarea(@core.Store::new(\"多行文本输入演示。\\n第二行内容。\"), rows=3, width=300.0)",
      ],
    ),
    @shared.section(
      "数值",
      "步进器 / 滑杆 / 评分",
      "stepper 步进器 0..10 钳制；slider 自绘轨道 + thumb（拖拽 step 5 量化）；rate 五角星 hover 预亮——值都住 Store，展示端 bind 直连。",
      [
        @ui.stepper(qty, min=0, max=10, step=1),
        @ui.bind_label(qty, fn(v) { "当前数量：\{v}" }),
        @ui.slider(slider_val, min=0.0, max=100.0, step=5.0, width=200.0),
        @ui.bind_label(slider_val, fn(v) { "当前值：\{v.round()}" }),
        @ui.rate_t(rate_val),
        @ui.bind_label(rate_val, fn(v) { "评分：\{v} 星" }),
      ],
      code=[
        "let qty : @core.Store[Int] = @core.Store::new(3)",
        "@ui.stepper(qty, min=0, max=10, step=1)",
        "@ui.bind_label(qty, fn(v) { \"当前数量：\\{v}\" })",
        "let slider_val : @core.Store[Double] = @core.Store::new(30.0)",
        "@ui.slider(slider_val, min=0.0, max=100.0, step=5.0, width=200.0)",
        "let rate_val : @core.Store[Int] = @core.Store::new(3)",
        "@ui.rate_t(rate_val)",
      ],
    ),
    @shared.section(
      "选择",
      "Select 与 ColorPicker",
      "下拉点字段弹候选（悬停高亮 / 选中 ✓），clearable ✕ 清空；取色器预设色板点击选色，hex 值住 Store。",
      [
        @ui.col(
          [
            @ui.select_t(
              ["杭州", "北京", "上海", "深圳", "广州"],
              @core.Store::new(""),
              clearable=true,
              width=170.0,
            ),
            @ui.color_picker_t(picked_color),
            @ui.bind_label(picked_color, fn(c) { c }),
          ],
          row_gap=10.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "@ui.select_t([\"杭州\", \"北京\", \"上海\", \"深圳\", \"广州\"], city, clearable=true, width=170.0)",
        "@ui.color_picker_t(color)",
        "@ui.bind_label(color, fn(c) { c })",
      ],
    ),
    @shared.section(
      "开关",
      "Checkbox / Radio / Switch",
      "勾选与开关的值就是 Store 本身（展示端直连）；单选组点击互斥（第二组禁用）；开关开=主题蓝靠右。",
      [
        @ui.col(
          [
            @ui.checkbox("启用自动同步", sync),
            @ui.checkbox("接收通知", notify),
            @ui.row(
              [
                @ui.bind_label(sync, fn(v) { if v { "同步：开" } else { "同步：关" } }),
                @ui.bind_label(notify, fn(v) { if v { "通知：开" } else { "通知：关" } }),
              ],
              column_gap=24.0,
            ),
            @ui.row(
              [
                @ui.radio_group(["浅色", "深色", "跟随系统"], theme_idx),
                @ui.radio_group(["选项一", "选项二"], radio_idx, disabled=true),
              ],
              column_gap=40.0,
            ),
            @ui.row(
              [
                @ui.switch_t(wifi_on),
                @ui.bind_label(wifi_on, fn(v) { if v { "已开启" } else { "已关闭" } }),
                @ui.switch_t(locked, disabled=true),
                @ui.label_t("禁用", role=@ui.Body),
              ],
              column_gap=12.0,
            ),
          ],
          row_gap=10.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "let sync : @core.Store[Bool] = @core.Store::new(false)",
        "@ui.checkbox(\"启用自动同步\", sync)",
        "@ui.bind_label(sync, fn(v) { if v { \"同步：开\" } else { \"同步：关\" } })",
        "let theme_idx : @core.Store[Int] = @core.Store::new(1)",
        "@ui.radio_group([\"浅色\", \"深色\", \"跟随系统\"], theme_idx)",
        "let wifi_on : @core.Store[Bool] = @core.Store::new(true)",
        "@ui.switch_t(wifi_on)",
        "@ui.switch_t(@core.Store::new(false), disabled=true)",
      ],
    ),
    @shared.section(
      "日期",
      "日期与时间选择",
      "全自绘月历（‹/› 切月）+ 内联 calendar_t；日期区间与日期时间区间选择器，选中值住 Store。",
      [
        @ui.col(
          [
            @ui.date_picker_t(dp_val, clearable=true, width=170.0),
            @ui.row(
              [
                @ui.label_t("选中：", role=@ui.Body),
                @ui.bind(dp_val.signal(), fn(d) {
                  match d {
                    Some(v) => v.format()
                    None => "未选"
                  }
                }),
              ],
              column_gap=6.0,
            ),
          ],
          row_gap=10.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
        @ui.calendar_t(),
        @ui.col([
          @ui.datetime_range_picker_t(dtr),
          @ui.bind_label(dtr, fn(r) {
            match (r.start, r.end) {
              (Some((sd, st)), Some((ed, et))) =>
                "日期时间区间：\{sd.format()} \{st.format()} ~ \{ed.format()} \{et.format()}"
              _ => "日期时间区间：未完成选择"
            }
          }),
        ]),
      ],
      code=[
        "let dp : @core.Store[@ui.DateYMD?] = @core.Store::new(None)",
        "@ui.date_picker_t(dp, clearable=true, width=170.0)",
        "@ui.bind(dp.signal(), fn(d) { match d { Some(v) => v.format()  None -> \"未选\" } })",
        "@ui.calendar_t()",
        "let dtr : @core.Store[@ui.DateTimeRange] = @core.Store::new({ start: None, end: None })",
        "@ui.datetime_range_picker_t(dtr)",
      ],
    ),
    @shared.section(
      "表单",
      "Form 表单",
      "form_item 行布局（标签右对齐 + 控件区）+ form 分组标题。",
      [
        @ui.form("用户设置", [
          @ui.form_item("用户名", @ui.entry(@core.Store::new("moonbit"), width=200.0)),
          @ui.form_item("城市", @ui.entry(@core.Store::new("杭州"), width=200.0)),
          @ui.form_item("数量", @ui.stepper(qty2, min=1, max=9)),
        ]),
      ],
      code=[
        "@ui.form(\"用户设置\", [",
        "  @ui.form_item(\"用户名\", @ui.entry(@core.Store::new(\"moonbit\"), width=200.0)),",
        "  @ui.form_item(\"数量\", @ui.stepper(qty2, min=1, max=9)),",
        "])",
      ],
    ),
  ])
}
