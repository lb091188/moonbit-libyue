// 原生控件页:libyue 原生件演示,纯命令式——状态用 Ref,回显用
// label handle + set_text,不接 Store/Signal(原生语义即命令式,
// 响应式形态对照见主题页与「Store 对照」页)。

///|
pub fn page_native(_app : @ui.App) -> @yue.Node {
  let nat_clicks = Ref(0)
  let nat_clicks_lb : Ref[@yue.Label?] = Ref(None)
  let nat_echo_lb : Ref[@yue.Label?] = Ref(None)
  let nat_slider_lb : Ref[@yue.Label?] = Ref(None)
  let nat_pick_lb : Ref[@yue.Label?] = Ref(None)
  let nat_combo_lb : Ref[@yue.Label?] = Ref(None)
  let nat_picker_lb : Ref[@yue.Label?] = Ref(None)
  let nat_date_lb : Ref[@yue.Label?] = Ref(None)
  let nat_tab_lb : Ref[@yue.Label?] = Ref(None)
  let nat_tab_sw = Ref(0)
  let nat_bar : Ref[@yue.ProgressBar?] = Ref(None)
  let nat_indet = Ref(false)
  let nat_cb : Ref[@yue.ComboBox?] = Ref(None)
  let nat_pk : Ref[@yue.Picker?] = Ref(None)
  let nat_edit : Ref[@yue.TextEdit?] = Ref(None)
  let nat_scroll : Ref[@yue.Scroll?] = Ref(None)
  let nat_policy = Ref(false)
  let nat_date = @yue.DatePicker::new_with({
    elements: @yue.HourMinute,
    has_stepper: true,
  })
  nat_date.set_date(946684800L)
  @ui.page([
    @ui.section(
      "按钮",
      "标签 / 按钮",
      "libyue 原生 Button/Label(系统主题外观),点击计数由命令式 set_text 回显。",
      [
        @yue.hbox([
          @yue.button("原生按钮", on_click=fn() {
            nat_clicks.val += 1
            match nat_clicks_lb.val {
              Some(l) => l.set_text("已点 \{nat_clicks.val} 次")
              None => ()
            }
          }),
          @yue.label("已点 0 次", style=[("marginLeft", 10.0)], handle=fn(
            l,
          ) {
            nat_clicks_lb.val = Some(l)
          }),
        ]),
      ],
      code=[
        "// libyue 原生件(系统主题外观),命令式语义:Ref 存状态",
        "let clicks = Ref(0)", "let echo : Ref[@yue.Label?] = Ref(None)",
        "// button(标题, on_click=点击回调, style, style_str, handle):原生按钮,点击时执行 on_click",
        "@yue.button(\"原生按钮\", on_click=fn() {",
        "  clicks.val = clicks.val + 1", "  match echo.val {", "    Some(l) => l.set_text(\"已点 \\{clicks.val} 次\")",
        "    None => ()", "  }", "})",
        "// label(文本, style, style_str, handle):静态标签;handle 挂载时收到 Label 句柄,set_text 更新文本",
        "@yue.label(\"已点 0 次\", handle=fn(l) { echo.val = Some(l) })",
      ],
    ),
    @ui.section(
      "输入",
      "文本输入(Entry / TextEdit)",
      "原生 Entry:on_input 实时回显、on_enter 回车、password 密码框;TextEdit 撤销重做/剪切复制粘贴/选区与插入。",
      [
        @yue.vbox([
          @yue.entry(
            text="在这里输入…",
            on_input=fn(t) {
              match nat_echo_lb.val {
                Some(l) => l.set_text("回显:\{t}")
                None => ()
              }
            },
            on_enter=fn(t) {
              match nat_echo_lb.val {
                Some(l) => l.set_text("回显:\{t}(回车)")
                None => ()
              }
            },
          ),
          @yue.label("回显:", style=[("marginTop", 8.0)], handle=fn(l) {
            nat_echo_lb.val = Some(l)
          }),
          @yue.entry(text="口令", password=true, style=[("marginTop", 8.0)]),
          @yue.text_edit(
            text="多行文本…\n试试撤销 / 重做 / 全选 / 插入。",
            handle=fn(t) { nat_edit.val = Some(t) },
            style=[("height", 96.0), ("marginTop", 8.0)],
          ),
          @yue.hbox(
            [
              @yue.button_t("撤销", on_click=fn() {
                match nat_edit.val {
                  Some(t) => t.undo()
                  None => ()
                }
              }),
              @yue.button_t("重做", on_click=fn() {
                match nat_edit.val {
                  Some(t) => t.redo()
                  None => ()
                }
              }),
              @yue.button_t("全选", on_click=fn() {
                match nat_edit.val {
                  Some(t) => t.select_all()
                  None => ()
                }
              }),
              @yue.button_t("粘贴", on_click=fn() {
                match nat_edit.val {
                  Some(t) => t.paste()
                  None => ()
                }
              }),
              @yue.button_t("插入一行", on_click=fn() {
                match nat_edit.val {
                  Some(t) => t.insert_text("\n(插入)")
                  None => ()
                }
              }),
            ],
            style=[("marginTop", 8.0)],
          ),
        ]),
      ],
      code=[
        "// entry(text=初始文本, password=true 密码框, on_enter=回车回调, on_input=内容变化回调,均携带当前文本)",
        "@yue.entry(text=\"在这里输入…\", on_input=fn(t) {",
        "  println(\"输入:\\{t}\")",
        "}, on_enter=fn(t) { println(\"回车:\\{t}\") })",
        "// password=true 即密码框,输入回显为圆点",
        "@yue.entry(text=\"口令\", password=true)",
        "// text_edit(text=初始文本, on_input=内容变化回调, handle=挂载时收到 TextEdit 句柄)",
        "@yue.text_edit(text=\"多行文本…\", handle=fn(t) {",
        "  // undo/redo 撤销重做一步;select_all 全选;paste 光标处粘贴;insert_text 光标处插入",
        "  t.undo()", "  t.redo()", "  t.select_all()", "  t.paste()", "  t.insert_text(\"\\n(插入)\")",
        "})",
      ],
    ),
    @ui.section(
      "数值",
      "数值(Slider / ProgressBar)",
      "原生 Slider + ProgressBar(handle 命令式 set_value);按钮切换不确定态。",
      [
        @yue.slider(range=Some((0.0, 100.0)), step=Some(1.0), on_change=fn(v) {
          match nat_bar.val {
            Some(p) => p.set_value(v / 100.0)
            None => ()
          }
          match nat_slider_lb.val {
            Some(l) => l.set_text("滑块值:\{v.round()}")
            None => ()
          }
        }),
        @yue.progress(handle=fn(p) { nat_bar.val = Some(p) }, style=[
          ("marginTop", 8.0),
        ]),
        @yue.label("滑块值:0", style=[("marginTop", 8.0)], handle=fn(l) {
          nat_slider_lb.val = Some(l)
        }),
        @yue.button_t("切换不确定态", on_click=fn() {
          nat_indet.val = !nat_indet.val
          match nat_bar.val {
            Some(p) => p.set_indeterminate(nat_indet.val)
            None => ()
          }
        }),
      ],
      code=[
        "let bar : Ref[@yue.ProgressBar?] = Ref(None)",
        "// slider(value=初值, range=Some((min,max)) 量程缺省 0~100, step=Some(步长), on_change=拖动中持续回调当前值)",
        "@yue.slider(range=Some((0.0, 100.0)), step=Some(1.0), on_change=fn(v) {",
        "  match bar.val {",
        "    // progress 取值 0.0~1.0,set_value 按比例驱动进度条",
        "    Some(p) => p.set_value(v / 100.0)", "    None => ()",
        "  }", "})",
        "// progress(value=初值 0..1, indeterminate=不确定态, handle=挂载时收到 ProgressBar 句柄)",
        "@yue.progress(handle=fn(p) { bar.val = Some(p) })",
        "// 不确定态:来回滑动的繁忙动画",
        "p.set_indeterminate(true)",
      ],
    ),
    @ui.section(
      "选择",
      "选择(Checkbox / Radio / ComboBox / Picker)",
      "checkbox 独立勾选;radio 同组自动互斥;ComboBox 可编辑(on_select/on_input);Picker 只读列表选择。",
      [
        @yue.hbox([
          @yue.vbox([
            @yue.checkbox("启用扩展", on_change=fn(v) {
              match nat_pick_lb.val {
                Some(l) =>
                  l.set_text(
                    "当前:\{if v { "扩展已启用" } else { "扩展已停用" }}",
                  )
                None => ()
              }
            }),
            @yue.radio("甲", on_change=fn(v) {
              if v {
                match nat_pick_lb.val {
                  Some(l) => l.set_text("当前:甲")
                  None => ()
                }
              }
            }),
            @yue.radio("乙", checked=true, on_change=fn(v) {
              if v {
                match nat_pick_lb.val {
                  Some(l) => l.set_text("当前:乙")
                  None => ()
                }
              }
            }),
            @yue.radio("丙", on_change=fn(v) {
              if v {
                match nat_pick_lb.val {
                  Some(l) => l.set_text("当前:丙")
                  None => ()
                }
              }
            }),
          ]),
          @yue.label("        "),
          @yue.vbox([
            @yue.combo(
              items=["MoonBit", "libyue", "GTK"],
              selected=0,
              on_select=fn() {
                match nat_cb.val {
                  Some(c) =>
                    match nat_combo_lb.val {
                      Some(l) =>
                        l.set_text("组合框:\{c.get_selected_item()}")
                      None => ()
                    }
                  None => ()
                }
              },
              handle=fn(c) { nat_cb.val = Some(c) },
            ),
            @yue.picker(
              items=["红", "绿", "蓝"],
              on_change=fn() {
                match nat_pk.val {
                  Some(p) =>
                    match nat_picker_lb.val {
                      Some(l) =>
                        l.set_text("选择器:\{p.get_selected_item()}")
                      None => ()
                    }
                  None => ()
                }
              },
              handle=fn(p) { nat_pk.val = Some(p) },
              style=[("marginTop", 8.0)],
            ),
            @yue.label("组合框:MoonBit", style=[("marginTop", 8.0)], handle=fn(
              l,
            ) {
              nat_combo_lb.val = Some(l)
            }),
            @yue.label("选择器:-", handle=fn(l) {
              nat_picker_lb.val = Some(l)
            }),
          ]),
        ]),
      ],
      code=[
        "// checkbox(title, checked=初始勾选默认 false, on_change=点击后回调新勾选态);radio 同一父容器内自动互斥",
        "@yue.checkbox(\"启用扩展\", on_change=fn(v) { println(v) })",
        "@yue.radio(\"甲\", on_change=fn(v) { if v { println(\"甲\") } })", "@yue.radio(\"乙\", checked=true, on_change=fn(v) { ignore(v) })",
        "// combo(可编辑组合框):items=选项, selected=初始下标, on_select=选中变化/on_input=文本变化,均无参回调",
        "// handle=挂载时收到 ComboBox 句柄,经 get_selected_item()/get_text() 取当前选项或输入文本",
        "@yue.combo(", "  items=[\"MoonBit\", \"libyue\", \"GTK\"],",
        "  selected=0,", "  on_select=fn() { () },   // get_selected_item() 取值",
        "  handle=fn(c) { ignore(c) },", ")",
        "// picker(只读下拉):items=选项, selected=初始下标, on_change=选择变化回调(无参);get_selected_item() 取选中文本",
        "@yue.picker(items=[\"红\", \"绿\", \"蓝\"], on_change=fn() { () })",
      ],
    ),
    @ui.section(
      "日期",
      "日期时间选择",
      "原生 DatePicker(HourMinute 元素 + 步进器),epoch 秒读写。",
      [
        @yue.node_of(nat_date, style=[("marginBottom", 8.0)]),
        @yue.label("当前 epoch 秒:946684800", handle=fn(l) {
          nat_date_lb.val = Some(l)
        }),
        @yue.hbox(
          [
            @yue.button_t("读当前值", on_click=fn() {
              match nat_date_lb.val {
                Some(l) => l.set_text("当前 epoch 秒:\{nat_date.get_date()}")
                None => ()
              }
            }),
          ],
          style=[("marginTop", 4.0)],
        ),
      ],
      code=[
        "// DatePicker::new_with({elements: 元素组合, has_stepper: 步进器});日期按 Unix epoch 秒读写",
        "// elements 可选 YearMonth/YearMonthDay/HourMinute/HourMinuteSecond,has_stepper 显示上下步进按钮",
        "let dp = @yue.DatePicker::new_with({",
        "  elements: @yue.HourMinute,   // 也有年月日/秒组合", "  has_stepper: true,",
        "})",
        "// set_date / get_date 读写日期,均为 Unix epoch 秒(Int64)",
        "dp.set_date(946684800L)", "println(dp.get_date())",
        "// node_of(视图, style, style_str):把已有原生控件包成 Node 挂进声明式树",
        "@yue.node_of(dp)",
      ],
    ),
    @ui.section(
      "展示",
      "展示(GIF / Group / Tab)",
      "GifPlayer 播放 GIF;分组 Group 标题 + 内容;原生 Tab 切换页签。",
      [
        @yue.hbox([
          @yue.gif(
            image=Some(@yue.Image::new_from_file("examples/showcase/assets/dot.gif")),
            style=[("width", 120.0), ("height", 120.0)],
          ),
          @yue.group(
            "分组:内嵌标签",
            @yue.label("分组里的内容", style=[("padding", 8.0)]),
            style=[("height", 96.0), ("marginLeft", 12.0)],
          ),
        ]),
        @yue.tab(
          [
            (
              "文本",
              @yue.label("第一个页签的内容", style=[("padding", 8.0)]),
            ),
            (
              "输入",
              @yue.entry(text="页签里的输入框", style=[("padding", 8.0)]),
            ),
            (
              "按钮",
              @yue.hbox([@yue.button("页签内按钮")], style=[
                ("padding", 8.0),
              ]),
            ),
          ],
          on_change=fn() {
            nat_tab_sw.val += 1
            match nat_tab_lb.val {
              Some(l) => l.set_text("切换次数:\{nat_tab_sw.val}")
              None => ()
            }
          },
          style=[("height", 120.0), ("marginBottom", 8.0)],
        ),
        @yue.label("切换次数:0", handle=fn(l) { nat_tab_lb.val = Some(l) }),
      ],
      code=[
        "// gif(image=Some(Image) 要播放的 GIF, scale=缩放模式默认 Down, style=布局)",
        "@yue.gif(",
        "  // Image::new_from_file(路径) 从文件加载图片",
        "  image=Some(@yue.Image::new_from_file(\"examples/showcase/assets/dot.gif\")),",
        "  style=[(\"width\", 120.0), (\"height\", 120.0)],", ")",
        "// group(title=分组标题, content=内容 Node, style=布局)",
        "@yue.group(\"分组:内嵌标签\", @yue.label(\"分组里的内容\"))",
        "// tab(pages=[(页标题, 页内容 Node)], on_change=切换页签回调, handle=取 Tab 句柄, style=布局)",
        "@yue.tab(", "  [", "    (\"文本\", @yue.label(\"第一个页签的内容\")),",
        "    (\"输入\", @yue.entry(text=\"页签里的输入框\")),", "  ],",
        "  on_change=fn() { println(\"切换页签\") },", "  style=[(\"height\", 120.0)],",
        ")",
      ],
    ),
    @ui.section(
      "表格",
      "原生表格 Table",
      "TableModel 数据视图分离;列类型 Text/Checkbox/Edit;GTK 下放 Notebook 页签崩溃,故独立子窗口。",
      [
        @yue.button_t("打开表格演示窗口", variant=@yue.Solid, on_click=fn() {
          open_table_window()
        }),
      ],
      code=[
        "// 实现 TableModel trait 三方法:row_count 行数 / get_value(col,row) 取值 / set_value(col,row,v) 写回",
        "impl @yue.TableModel for MyModel with fn row_count(self) {",
        "  self.names.length()", "}",
        "// get_value 返回 TableValue:文本/编辑列用 Str,复选框列用 Flag(列类型决定合法变体)",
        "impl @yue.TableModel for MyModel with fn get_value(self, col, row) {",
        "  match col {", "    0 => @yue.Str(self.names[row])", "    1 => @yue.Flag(true)",
        "    _ => @yue.Str(\"?\")", "  }", "}",
        "// Checkbox/Edit 列的编辑经 set_value 回写模型(trait 必需的第三个方法)",
        "impl @yue.TableModel for MyModel with fn set_value(self, col, row, v) {",
        "  ignore((col, row, v))",
        "}",
        "// Table::new() 建表格;add_column_with_options(列标题, 列选项) 加列",
        "let table = @yue.Table::new()",
        "// 列选项:column_type=Text/Edit/Checkbox/Custom, column=对应模型列(-1 末列), width=初始宽度(-1 默认)",
        "table.add_column_with_options(\"语言\", {", "  column_type: @yue.Text,",
        "  column: 0,", "  width: 160,", "})",
        "// set_model(模型实现, 列数):挂载数据模型,列数需与加列一致,行数据按需取数",
        "table.set_model(MyModel::new(), 1)",
        "// on_row_activate(回调):行双击/激活时触发,参数为行号",
        "table.on_row_activate(fn(row) { println(\"行激活:\\{row}\") })",
      ],
    ),
    @ui.section(
      "滚动",
      "滚动区 Scroll(平台滚动条)",
      "平台经典滚动条的 Automatic/Always/Never 策略切换(declarative scroll 默认悬浮细条,本段 overlay=false 保住平台条语义)。",
      [
        @yue.scroll(
          @yue.vbox([
            @yue.label_t("滚动区第一行", role=@yue.Body, style=[
              ("padding", 8.0),
            ]),
            @yue.label_t("滚动区第二行", role=@yue.Body, style=[
              ("padding", 8.0),
            ]),
            @yue.label_t("滚动区第三行", role=@yue.Body, style=[
              ("padding", 8.0),
            ]),
            @yue.label_t("滚动区第四行", role=@yue.Body, style=[
              ("padding", 8.0),
            ]),
          ]),
          handle=fn(s) { nat_scroll.val = Some(s) },
          overlay=false,
          style=[("height", 90.0), ("marginBottom", 8.0)],
        ),
        @yue.button("切换滚动条策略", on_click=fn() {
          nat_policy.val = !nat_policy.val
          match nat_scroll.val {
            Some(s) =>
              if nat_policy.val {
                s.set_scrollbar_policy(@yue.Always, @yue.Always)
              } else {
                s.set_scrollbar_policy(@yue.Automatic, @yue.Automatic)
              }
            None => ()
          }
        }),
      ],
      code=[
        "// scroll(content=内容 Node, overlay=false 用平台经典滚动条(默认 true 悬浮细条), style, handle)",
        "@yue.scroll(",
        "  // vbox(children=子节点数组);label_t(text, role=文字角色默认 Body) 按角色统一字号/颜色",
        "  @yue.vbox([@yue.label_t(\"滚动内容\", role=@yue.Body)]),", "  overlay=false,",
        "  handle=fn(s) {",
        "    // set_scrollbar_policy(横向, 纵向):Automatic 溢出才出现 / Always 常驻 / Never 隐藏",
        "    s.set_scrollbar_policy(@yue.Automatic, @yue.Automatic)", "  },", "  style=[(\"height\", 90.0)],",
        ")",
      ],
    ),
  ])
}
