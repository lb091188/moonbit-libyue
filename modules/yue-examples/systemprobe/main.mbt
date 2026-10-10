// 系统能力与扩展图表演示板:侧边导航切换分页(与 showcase 同构)。
// 目录结构:
//   ui/    共享层(ProbeApp 跨页状态、page_shell 页面壳 + nav_page)
//   pages/ 各页内容(每页一个文件)
// 页面惰性挂载:未选中过的页只留空壳,首次选中才挂载内容;
// 页内动态长高的内容(报告 set_text、播放器挂载)完成后由页面调用
// page_shell 注入的刷新闭包更新滚动范围。

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  @yue.theme_apply(@yue.theme_from_system())
  let (toast_node, toast_push) = @components.toast_layer()
  let app : @ui.ProbeApp = {
    selected: @yue.Store::new("系统能力"),
    win_ref: Ref(None),
    toast: toast_push,
    // 特效散点涟漪动画句柄:关窗时停止定时器
    eff_anim: @charts.EffAnim::make(),
    vid_player: Ref(None),
    aud_ap: Ref(None),
  }
  ignore(
    @declarative.mount_window(
      [
        @declarative.hbox(style=[("flex", 1.0), ("alignItems", "stretch")], [
          // 侧栏:菜单 + 演示说明
          @declarative.vbox(
            [
              @declarative.scroll(
                @declarative.vbox(
                  [
                    @components.side_menu_sections(
                      [
                        ("能力", ["系统能力", "命令与状态"]),
                        ("媒体", ["视频播放", "音频播放"]),
                        (
                          "图表",
                          ["扩展图表", "新图表", "交互图表"],
                        ),
                      ],
                      app.selected,
                      icons=[
                        ("系统能力", @icons.Monitor1),
                        ("命令与状态", @icons.CopyDocument),
                        ("视频播放", @icons.VideoPlay),
                        ("音频播放", @icons.Headset),
                        ("扩展图表", @icons.DataAnalysis),
                        ("新图表", @icons.DataLine),
                        ("交互图表", @icons.PieChart),
                      ],
                    ),
                  ],
                  style=[("width", 200.0)],
                ),
                style=[("flex", 1.0), ("width", 200.0)],
              ),
              @components.label_t(
                "系统能力真读本机\n图表为演示数据",
                role=@components.Secondary,
                style=[
                  ("paddingLeft", 20.0),
                  ("paddingRight", 12.0),
                  ("paddingTop", 6.0),
                  ("paddingBottom", 10.0),
                ],
              ),
            ],
            style=[("width", 200.0)],
            handle=fn(c) {
              fn apply() -> Unit {
                c.set_background_color(@yue.theme_current().bg_panel)
              }

              apply()
              ignore(@yue.on_theme_change(apply))
            },
          ),
          @declarative.vbox(
            [
              @ui.nav_page(
                "系统能力",
                app.selected,
                @pages.page_sysinfo(app),
              ),
              @ui.nav_page("视频播放", app.selected, @pages.page_video(app)),
              @ui.nav_page("音频播放", app.selected, @pages.page_audio(app)),
              @ui.nav_page(
                "命令与状态",
                app.selected,
                @pages.page_cmdpreview(app),
              ),
              @ui.nav_page(
                "扩展图表",
                app.selected,
                @pages.page_charts1(app),
              ),
              @ui.nav_page("新图表", app.selected, @pages.page_charts2(app)),
              @ui.nav_page(
                "交互图表",
                app.selected,
                @pages.page_charts_it(app),
              ),
            ],
            style=[("flex", 1.0)],
            handle=fn(c) {
              fn apply() -> Unit {
                c.set_background_color(@yue.theme_current().bg_page)
              }

              apply()
              ignore(@yue.on_theme_change(apply))
            },
          ),
          // 轻提示层挂窗口根:absolute 顶部横条,不占布局
          toast_node,
        ]),
      ],
      title="systemprobe",
      size=Some((1080.0, 760.0)),
      center=true,
      on_close=fn(_w) {
        @charts.eff_stop(app.eff_anim)
        match app.aud_ap.val {
          Some(a) => a.free()
          None => ()
        }
        match app.vid_player.val {
          Some(p) => p.free()
          None => ()
        }
        @yue.quit()
      },
      handle=fn(w) { app.win_ref.val = Some(w) },
    ),
  )
  @yue.run()
}
