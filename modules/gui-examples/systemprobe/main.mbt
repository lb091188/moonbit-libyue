// 系统能力与扩展图表演示板（systemprobe，G7 新栈版）：侧边导航切换
// 分页，装配方式与 showcase 同构（shared/ 的 page/section/nav_page）。
//
// 与 master 旧版的差（G7 迁移记档）：
//   - 装配层照搬 showcase 的 shared（段式页面 + 代码区 + 复制钩子），
//     旧 `ui/page.mbt` 的 page_shell/report_set/nav_page 不再需要
//     （report_set 是 GTK 标签自然高的补丁，新栈 yoga 布局不存在该问题）。
//   - 页面 7 页全数迁入，其中「系统能力」21 族探针里本栈未接的 5 族
//     （磁盘卷/时区与语言/蓝牙/传感器/logind 电源会话）以说明行替代，
//     其余 16 族走 `@sys` 真调 + 2 族走 `@dbus`（MPRIS 媒体、电源计划里
//     无 dbus 的环境自然 Err 降级）。
//   - 媒体两页改用 gui-media 的 `player_t`（音视频一体的完整播放器
//     组件：内部自建引擎、控制条、字幕、错误降级全包），旧版
//     `VideoPlayer::make` + `video_player_t` / `AudioPlayer::make` +
//     `audio_player_t` 的手动分离形态不再需要。
//   - 「新图表」页的地图组件暂不展示（geo_map_t 已平移，但演示用
//     抽象多边形容易与真实地图观感混淆，等地图能力线一起定口径），
//     其余八种全数迁入。
//   - 特效散点动画 `EffAnim` 由 `eff_chart_t` 内部自驱动（组件自挂
//     定时器），ProbeApp 不再持有动画句柄。

///|
/// 窗口标题
const PROBE_TITLE : String = "systemprobe"

///|
fn main {
  let selected : @core.Store[String] = @core.Store::new("系统能力")
  let toast_push = @ui.toast_layer(duration_ms=2600)
  let app : @shared.ProbeApp = { selected, toast: toast_push, host: Ref(None) }
  let mounted = @ui.mount_window(
    [
      @ui.row(
        [
          // 侧栏：分组菜单 + 说明
          @ui.col(
            [
              @ui.scroll_v(
                [
                  @ui.side_menu_sections(
                    [
                      ("能力", ["系统能力", "命令与状态"]),
                      ("媒体", ["视频播放", "音频播放"]),
                      ("图表", ["扩展图表", "新图表", "交互图表"]),
                    ],
                    selected,
                    icons=[
                      ("系统能力", @icons.Monitor1),
                      ("命令与状态", @icons.CopyDocument),
                      ("视频播放", @icons.VideoPlay),
                      ("音频播放", @icons.Headset),
                      ("扩展图表", @icons.DataAnalysis),
                      ("新图表", @icons.DataLine),
                      ("交互图表", @icons.PieChart),
                    ],
                    width=200.0,
                  ),
                ],
                @ui.ScrollState::new(),
                handle=fn(v) { v.node.set_flex_grow(1.0) },
              ),
              @ui.text(
                "系统能力真读本机\n图表为演示数据",
                role=@ui.Secondary,
              ),
            ],
            width=200.0,
            padding=10.0,
            row_gap=8.0,
          ),
          // 主区：按导航状态切换的页（惰性挂载，首次选中才建控件）
          @ui.col(
            [
              @shared.nav_page("系统能力", selected, @pages.page_sysinfo(app)),
              @shared.nav_page("视频播放", selected, @pages.page_video(app)),
              @shared.nav_page("音频播放", selected, @pages.page_audio(app)),
              @shared.nav_page("命令与状态", selected, @pages.page_cmdpreview(app)),
              @shared.nav_page("扩展图表", selected, @pages.page_charts1(app)),
              @shared.nav_page("新图表", selected, @pages.page_charts2(app)),
              @shared.nav_page("交互图表", selected, @pages.page_charts_it(app)),
            ],
            grow=1.0,
          ),
        ],
        grow=1.0,
        align_items=@yoga.AlignItems::Stretch,
      ),
    ],
    title=PROBE_TITLE,
    width=1080,
    height=760,
    handle=fn(a : @core.App) {
      app.host.val = Some(a)
      ignore(a)
    },
  )
  match mounted {
    None => {
      println("PROBE-SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(host) => {
      println("PROBE-READY title=\{PROBE_TITLE} pages=7")
      host.run()
    }
  }
  println("PROBE-DONE page=\{selected.get()}")
}
