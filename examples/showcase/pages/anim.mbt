// 过渡与效果页：状态桶切换的属性插值（`transition_ms`）+ 样式槽文本字段的观感对照。
//
// 参与插值的是每帧从样式槽读出的绘制期属性：三条颜色 + 边框宽 + 圆角 + 字号 + 行高
// （后两条与 CSS 同口径可动画，测量期读同一份插值值，见 `@style.transition`）。
// `opacity` 的生效点是 `apply` 落宿主字段，不插值。

///|
fn hover_card(label : String, sub : String, dur : Double) -> @widget.Node {
  @ui.view(
    [
      @ui.text(label, align=@text.Center),
      @ui.text(sub, role=@ui.Secondary, align=@text.Center),
    ],
    width=170.0,
    height=64.0,
    row_gap=2.0,
    align_items=@yoga.AlignItems::Center,
    justify_content=@yoga.JustifyContent::Center,
    class=[
      @style.style(
        background_color="bg_panel",
        border_color="border",
        border_width=1.0,
        border_radius=4.0,
        color="text_regular",
        transition_ms=dur,
      ).hover(
        background_color="primary",
        border_color="primary_hover",
        border_width=3.0,
        border_radius=18.0,
        color="#ffffff",
      ),
    ],
  )
}

///|

///|
/// GIF 图源候选（moon run 可能从仓库根或 examples/ 目录起跑，逐个探测）。
fn anim_gif_path() -> String {
  for c in ["examples/showcase/assets/dot.gif", "assets/dot.gif", "showcase/assets/dot.gif"] {
    if @sys.sys_path_exists(c) {
      return c
    }
  }
  "examples/showcase/assets/dot.gif"
}

pub fn page_anim(_app : @shared.App) -> @widget.Node {
  let gif_h : @ui.GifHandle = @ui.GifHandle::make()
  let gif_note : @base.Store[String] = @base.Store::new("自转中")
  @shared.page([
    @shared.section(
      "属性过渡",
      "Transition 状态桶插值",
      "三块卡片只有 `transition_ms` 不同：悬停时底色/描边/圆角/字色都从当前值过渡到 hover 桶的值，离开时反向从当前帧的值续接（中途移开不跳变）。插值按真实时间推进，掉帧只少几帧、不会变快慢；每拍只给活动中的控件局部置脏，全部收敛就停表。",
      [
        @ui.row(
          [
            hover_card("0 ms", "直接切换", 0.0),
            hover_card("150 ms", "常用反馈", 150.0),
            hover_card("600 ms", "慢到看得清", 600.0),
          ],
          column_gap=16.0,
        ),
      ],
      code=[
        "@style.style(",
        "  background_color=\"bg_panel\", border_radius=4.0,",
        "  transition_ms=150.0,          // 时长写在基块上",
        ").hover(",
        "  background_color=\"primary\", border_radius=18.0,",
        ")",
      ],
    ),
    @shared.section(
      "插值范围",
      "哪些属性会渐变",
      "左边卡片悬停时底色平滑过渡；右边卡片同时改字号——**字号也进插值集合**（13→17 在 300ms 里渐变，盒子按同一份值一起长，不会被裁）。当前集合是三条颜色 + 边框宽 + 圆角 + 字号 + 行高（与 CSS 可动画的 `<length>` 对齐）；`opacity` / `box_shadow` 仍在集合外，切换即生效。",
      [
        @ui.row(
          [
            @ui.view(
              [@ui.text("底色过渡 300 ms", align=@text.Center)],
              width=170.0,
              height=48.0,
              align_items=@yoga.AlignItems::Center,
              justify_content=@yoga.JustifyContent::Center,
              class=[
                @style.style(
                  background_color="bg_panel",
                  border_color="border",
                  transition_ms=300.0,
                ).hover(background_color="success"),
              ],
            ),
            @ui.view(
              [
                // 字号写在**文本控件自己**的槽上：状态桶按控件各算各的，父块的
                // hover 不会替子件换字号。文本铺满整块（width=170），指针在块内
                // 任意位置都命中文本，字号这一档才看得见。测量期读同一份插值
                // 字号（`@style.resolved_for_measure`），所以字长大会连着盒子一起长。
                @ui.text(
                  "字号+底色",
                  align=@text.Center,
                  class=[
                    @style.style(font_size=13.0, transition_ms=300.0).hover(
                      font_size=17.0,
                    ),
                  ],
                ),
              ],
              width=170.0,
              height=48.0,
              align_items=@yoga.AlignItems::Center,
              justify_content=@yoga.JustifyContent::Center,
              class=[
                @style.style(
                  background_color="bg_panel",
                  border_color="border",
                  transition_ms=300.0,
                ).hover(background_color="warning"),
              ],
            ),
          ],
          column_gap=16.0,
        ),
      ],
    ),
    @shared.section(
      "文本与效果",
      "样式槽里的文本字段",
      "`text_align` 定绘制对齐、`white_space` 定折行、`line_height` 抬高行盒、`text_decoration` 画下划线。都是绘制期属性，写进 `class` 就生效，组件不必另开参数。（投影档试过分层羽化，真机观感不过关，已整条撤掉。）",
      [
        @ui.col(
          [
            @ui.row(
              [
                @ui.view(
                  [
                    @ui.text(
                      "下划线",
                      class=[@style.style(text_decoration=@style.Underline)],
                    ),
                  ],
                  width=180.0,
                  class=[@style.style(background_color="bg_page")],
                ),
                @ui.view(
                  [
                    @ui.text(
                      "右对齐（text_align）",
                      class=[@style.style(text_align=@text.End)],
                    ),
                  ],
                  width=180.0,
                  class=[@style.style(background_color="bg_page")],
                ),
                @ui.text("行高 32", class=[@style.style(line_height=32.0)]),
              ],
              column_gap=12.0,
            ),
            @ui.col(
              [
                @ui.text(
                  "折行：这段文字开了 white_space=Normal 并限宽 300，会按词折成多行；同一句改成 NoWrap 就停在盒宽外。",
                  max_width=300.0,
                  class=[@style.style(white_space=@style.Normal)],
                ),
                @ui.text(
                  "不折行：这段文字开了 white_space=NoWrap 并限宽 300，超出的部分不折行。",
                  max_width=300.0,
                  class=[@style.style(white_space=@style.NoWrap)],
                ),
              ],
              row_gap=8.0,
              align_items=@yoga.AlignItems::FlexStart,
            ),
          ],
          row_gap=12.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "@style.style(text_decoration=@style.Underline)",
        "@style.style(text_align=@text.End, line_height=32.0)",
        "@style.style(white_space=@style.Normal, max_width=300.0)",
      ],
    ),

    @shared.section(
      "动图",
      "GIF 动图",
      "按每帧时长自转的 GIF 组件（解码走 `render` 的动画通道，静图退回首帧）；句柄可暂停/继续、读已换帧数。",
      [
        @ui.row(
          [
            @ui.gif(
              anim_gif_path(),
              width=48.0,
              height=48.0,
              state=gif_h,
            ),
            @ui.button("暂停", variant=@ui.Soft, on_click=fn() {
              gif_h.pause()
              gif_note.set("已暂停（running=\{gif_h.running}）")
            }),
            @ui.button("继续", variant=@ui.Soft, on_click=fn() {
              gif_h.play()
              gif_note.set("已继续（running=\{gif_h.running}）")
            }),
            @ui.button("读帧数", variant=@ui.Text, on_click=fn() {
              gif_note.set("已换 \{gif_h.frame_count()} 帧")
            }),
          ],
          column_gap=10.0,
          align_items=@yoga.AlignItems::Center,
        ),
        @ui.bind_label(gif_note, fn(s) { s }, font_size=12.0, color="text_secondary"),
      ],
      code=[
        "let h = @ui.GifHandle::make()",
        "@ui.gif(\"assets/dot.gif\", width=48.0, height=48.0, state=h)",
        "h.pause()  // 暂停自转",
        "h.play()   // 继续",
        "h.frame_count()  // 已换过的帧数",
      ],
    ),
  ])
}
