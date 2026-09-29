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
        "let clicks = Ref(0)",
        "let echo : Ref[@yue.Label?] = Ref(None)",
        "@yue.button(\"原生按钮\", on_click=fn() {",
        "  clicks.val = clicks.val + 1",
        "  match echo.val {",
        "    Some(l) => l.set_text(\"已点 \\{clicks.val} 次\")",
        "    None => ()",
        "  }",
        "})",
        "@yue.label(\"已点 0 次\", handle=fn(l) { echo.val = Some(l) })",
      ],
    ),
    @ui.section(
      "输入",
      "Entry 与 TextEdit",
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
        "@yue.entry(text=\"在这里输入…\", on_input=fn(t) {",
        "  println(\"输入:\\{t}\")",
        "}, on_enter=fn(t) { println(\"回车:\\{t}\") })",
        "@yue.entry(text=\"口令\", password=true)",
        "@yue.text_edit(text=\"多行文本…\", handle=fn(t) {",
        "  t.undo()",
        "  t.redo()",
        "  t.select_all()",
        "  t.paste()",
        "  t.insert_text(\"\\n(插入)\")",
        "})",
      ],
    ),
    @ui.section(
      "数值",
      "Slider 与 ProgressBar",
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
        "@yue.slider(range=Some((0.0, 100.0)), step=Some(1.0), on_change=fn(v) {",
        "  match bar.val {",
        "    Some(p) => p.set_value(v / 100.0)",
        "    None => ()",
        "  }",
        "})",
        "@yue.progress(handle=fn(p) { bar.val = Some(p) })",
        "p.set_indeterminate(true)",
      ],
    ),
    @ui.section(
      "选择",
      "Checkbox / Radio / Combo / Picker",
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
        "@yue.checkbox(\"启用扩展\", on_change=fn(v) { println(v) })",
        "@yue.radio(\"甲\", on_change=fn(v) { if v { println(\"甲\") } })",
        "@yue.radio(\"乙\", checked=true, on_change=fn(v) { ignore(v) })",
        "@yue.combo(",
        "  items=[\"MoonBit\", \"libyue\", \"GTK\"],",
        "  selected=0,",
        "  on_select=fn() { () },",
        "  handle=fn(c) { ignore(c) },",
        ")",
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
        "let dp = @yue.DatePicker::new_with({",
        "  elements: @yue.HourMinute,",
        "  has_stepper: true,",
        "})",
        "dp.set_date(946684800L)",
        "println(dp.get_date())",
        "@yue.node_of(dp)",
      ],
    ),
    @ui.section(
      "展示",
      "GIF / Group / Tab",
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
        "@yue.gif(",
        "  image=Some(@yue.Image::new_from_file(\"examples/showcase/assets/dot.gif\")),",
        "  style=[(\"width\", 120.0), (\"height\", 120.0)],",
        ")",
        "@yue.group(\"分组:内嵌标签\", @yue.label(\"分组里的内容\"))",
        "@yue.tab(",
        "  [",
        "    (\"文本\", @yue.label(\"第一个页签的内容\")),",
        "    (\"输入\", @yue.entry(text=\"页签里的输入框\")),",
        "  ],",
        "  on_change=fn() { println(\"切换页签\") },",
        "  style=[(\"height\", 120.0)],",
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
        "impl @yue.TableModel for MyModel with fn row_count(self) {",
        "  self.names.length()",
        "}",
        "impl @yue.TableModel for MyModel with fn get_value(self, col, row) {",
        "  match col {",
        "    0 => @yue.Str(self.names[row])",
        "    1 => @yue.Flag(true)",
        "    _ => @yue.Str(\"?\")",
        "  }",
        "}",
        "impl @yue.TableModel for MyModel with fn set_value(self, col, row, v) {",
        "  ignore((col, row, v))",
        "}",
        "let table = @yue.Table::new()",
        "table.add_column_with_options(\"语言\", {",
        "  column_type: @yue.Text,",
        "  column: 0,",
        "  width: 160,",
        "})",
        "table.set_model(MyModel::new(), 1)",
        "table.on_row_activate(fn(row) { println(\"行激活:\\{row}\") })",
      ],
    ),
    @ui.section(
      "滚动",
      "Scroll 滚动区",
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
        "@yue.scroll(",
        "  @yue.vbox([@yue.label_t(\"滚动内容\", role=@yue.Body)]),",
        "  overlay=false,",
        "  handle=fn(s) {",
        "    s.set_scrollbar_policy(@yue.Automatic, @yue.Automatic)",
        "  },",
        "  style=[(\"height\", 90.0)],",
        ")",
      ],
    ),
  ])
}
