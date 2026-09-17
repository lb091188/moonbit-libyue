// 原生控件 × 主题探测示例:真机收集 Windows 渲染机制信息。
// 运行:moon run examples/probe > probe.log 2>&1
// 操作:点击「执行探测」后,连同 probe.log 与窗口截图一起反馈。

///|
#borrow(window)
extern "c" fn ffi_probe_env(window : @yue.View) -> Unit = "yue_mbt_probe_env"

///|
#borrow(view, label)
extern "c" fn ffi_probe_view(
  view : @yue.View,
  label : Bytes,
) -> Unit = "yue_mbt_probe_view"

///|
extern "c" fn ffi_probe_dark(view : @yue.View) -> Unit = "yue_mbt_probe_dark"

///|
/// 探测表格数据模型:名称 / 完成(复选) / 状态(自绘色块)。
struct ProbeModel {
  data : Array[Array[@yue.TableValue]]
}

///|
impl @yue.TableModel for ProbeModel with fn row_count(self) -> Int {
  self.data.length()
}

///|
impl @yue.TableModel for ProbeModel with fn get_value(
  self,
  column : Int,
  row : Int,
) -> @yue.TableValue {
  match self.data[row][column] {
    @yue.Flag(b) => @yue.Flag(b)
    @yue.ColorText(text, color) => @yue.ColorText(text, color)
    @yue.Str(s) => @yue.Str(s)
  }
}

///|
impl @yue.TableModel for ProbeModel with fn set_value(
  self,
  column : Int,
  row : Int,
  value : @yue.TableValue,
) -> Unit {
  self.data[row][column] = value
}

///|
fn section(title : String, note : String, child : @yue.Node) -> @yue.Node {
  @yue.vbox(
    [
      @yue.label(title, style=[("marginBottom", 4.0)]),
      @yue.label(note, style=[("marginBottom", 8.0)]),
      child,
    ],
    style=[("padding", 14.0), ("marginBottom", 8.0)],
  )
}

///|
fn main {
  ignore(@yue.initialize())
  let win_holder : Ref[@yue.Window?] = Ref(None)
  // 待探测控件(按钮点击时统一输出探针日志)
  let entry = @yue.Entry::make(text="原生输入框")
  entry.set_style("width", 260.0)
  entry.set_style("height", 26.0)
  let text_edit = @yue.TextEdit::new()
  text_edit.set_style("width", 260.0)
  text_edit.set_style("height", 56.0)
  let date_picker = @yue.DatePicker::new()
  date_picker.set_style("width", 150.0)
  date_picker.set_style("height", 26.0)
  let picker = @yue.Picker::new()
  picker.add_item("甲")
  picker.add_item("乙")
  picker.add_item("丙")
  picker.set_style("width", 160.0)
  let combo = @yue.ComboBox::new()
  combo.add_item("Red")
  combo.add_item("Green")
  combo.add_item("Blue")
  combo.set_style("width", 160.0)
  let progress = @yue.ProgressBar::new()
  progress.set_value(0.4)
  progress.set_style("width", 260.0)
  progress.set_style("height", 18.0)
  let native_btn = @yue.Button::new("原生按钮")
  let table = @yue.Table::new()
  table.add_column_text("名称", 160)
  table.add_column_checkbox("完成", 80)
  table.add_column_custom("状态", 120, fn(p, x, y, w, h, _name, color) {
    p.set_fill_color(color)
    p.fill_rect(x + 12.0, y + 5.0, w - 24.0, h - 10.0)
  })
  table.set_model(
    ProbeModel::{
      data: [
        [
          @yue.Str("第一行"),
          @yue.Flag(true),
          @yue.ColorText("正常", "#2E9E5B"),
        ],
        [
          @yue.Str("第二行"),
          @yue.Flag(false),
          @yue.ColorText("警告", "#D9822B"),
        ],
        [
          @yue.Str("第三行"),
          @yue.Flag(false),
          @yue.ColorText("失败", "#D64550"),
        ],
      ],
    },
    3,
  )
  table.set_style("width", 400.0)
  table.set_style("height", 140.0)
  let content = @yue.vbox(
    [
      section(
        "原生单行输入 Entry",
        "原生控件;暗色下底色/文字色是否跟随主题",
        @yue.node_of(entry),
      ),
      section("多行文本 TextEdit", "同上", @yue.node_of(text_edit)),
      section(
        "日期 DatePicker",
        "弹出的日历面板样式",
        @yue.node_of(date_picker),
      ),
      section("下拉 Picker", "点开的下拉列表样式", @yue.node_of(picker)),
      section(
        "可编辑下拉 ComboBox",
        "同上,输入框+下拉",
        @yue.node_of(combo),
      ),
      section("进度条 ProgressBar", "轨道/填充色", @yue.node_of(progress)),
      section("原生按钮 Button", "hover/底色", @yue.node_of(native_btn)),
      section(
        "表格 Table",
        "表头/行选中底色/复选框/最右列为 Custom 自绘色块(应显示绿/橙/红)",
        @yue.node_of(table),
      ),
      @yue.hbox(
        [
          @yue.button("执行探测", on_click=fn() {
            match win_holder.val {
              Some(w) => ffi_probe_env(w.view)
              None => ()
            }
            ffi_probe_view(entry.view, b"Entry")
            ffi_probe_view(text_edit.view, b"TextEdit")
            ffi_probe_view(date_picker.view, b"DatePicker")
            ffi_probe_view(picker.view, b"Picker")
            ffi_probe_view(combo.view, b"ComboBox")
            ffi_probe_view(progress.view, b"ProgressBar")
            ffi_probe_view(native_btn.view, b"Button")
            ffi_probe_view(table.view, b"Table")
          }),
          @yue.button("切暗色主题", on_click=fn() {
            @yue.theme_apply(@yue.dark_theme())
          }),
          @yue.button("切浅色主题", on_click=fn() {
            @yue.theme_apply(@yue.default_theme())
          }),
          @yue.button("尝试暗色化原生控件", on_click=fn() {
            // 对每个原生子控件注入暗色手段并打日志:
            // Explorer 系(ListView/Header/DateTimePick/ComboBox)走
            // Darkmode_Explorer;RichEdit 走消息;进度条走 PBM 自定色
            ffi_probe_dark(entry.view)
            ffi_probe_dark(text_edit.view)
            ffi_probe_dark(date_picker.view)
            ffi_probe_dark(picker.view)
            ffi_probe_dark(combo.view)
            ffi_probe_dark(progress.view)
            ffi_probe_dark(native_btn.view)
            ffi_probe_dark(table.view)
          }),
        ],
        style=[("padding", 14.0)],
        style_str=[("alignItems", "center")],
      ),
      @yue.label(
        "说明:切主题后自绘色立即变;原生控件(输入框/表格/日期等)预期不变——这正是要探测的。",
        style=[("paddingLeft", 14.0), ("paddingBottom", 14.0)],
      ),
    ],
  )
  let window = @yue.mount_window(
    [
      // flex 1 让 Scroll 填满窗口可用区(与 showcase 同式,否则高度塌 0 空白)
      @yue.scroll(
        content,
        style=[("flex", 1.0)],
        style_str=[("alignItems", "stretch")],
      ),
    ],
    title="原生控件探测",
    size=Some((560.0, 720.0)),
    handle=fn(w) { win_holder.val = Some(w) },
  )
  window.activate()
  @yue.run()
}
