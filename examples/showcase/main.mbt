// 组件库演示板：侧边导航切换分页。目录结构：
//   shared/ 共享层（App 跨页状态、page/section 段装配、复制回显钩子）
//   pages/  各页内容（每页一个文件）
//   assets/ 图片资源
//
// 响应式分层演示：主题五页（基础/表单/导航/数据/反馈）与各组件页用
// Store/Signal 直连，展示端不写手动 subscribe。
//
// G7 示例迁移（本批 = 骨架 + 第一页）：
//   - 旧链路的 `@yue.initialize()` + `@yue.run()` 换成 `@ui.mount_window` +
//     `App::run`；窗口居中交给 WM（本栈不提供 `center`，与 master 的一条差）。
//   - 主题跟随不再走 `@yue.on_system_theme_change`（旧链路的平台事件通道），
//     改为「跟随开关 + 每 2 秒读一次系统偏好」：手动选色/切深浅先把开关关掉，
//     否则下一拍就被盖回去。系统偏好读数用 `@win.sys_color_scheme/sys_accent`
//     （与 `App::follow_system_theme` 内部同一来源，示例要能手动覆盖故自己开表）。
//   - 菜单栏 / 托盘 / 单实例 / 对话框尚未迁入（它们各自随「系统集成」「窗口」
//     两页进来，或在 `examples/native-app` 已有对照演示）。
//   - 待迁页：导航 / 数据展示 / 图表 / 代码与文档 / Store 对照 / 事件与布局 /
//     系统集成 / 窗口 / 图标库 / 画布与富文本 / 浏览器（见 TODO.md；
//     表单组件页 2026-10-12 已迁）。

///|
/// 窗口标题
const SHOWCASE_TITLE : String = "组件库演示板"

///|
/// 侧栏底部的版本号。旧链路读 `@yue.VERSION`（主包常量，`scripts/prebuild.py`
/// 在构建期校验它与 `moon.mod` 一致）；新栈示例不再 import 主包，故本地留一份
/// ——它只用于显示，权威值仍是 `moon.mod` 与 `yue/version.mbt`。
const SHOWCASE_VERSION : String = "0.1.0"

///|
/// 主题应用：主色空串用内置基准盘，非空按 HSL 公式派生；深浅随 `dark`。
fn apply_theme(app : @shared.App) -> Unit {
  let dark = app.dark_mode.get()
  let accent = app.accent.get()
  if accent.length() == 0 {
    @theme.theme_apply(if dark {
      @theme.dark_theme()
    } else {
      @theme.default_theme()
    })
  } else {
    @theme.theme_apply(@theme.theme_from_accent(accent, dark=dark))
  }
}

///|
/// 侧栏里的深/浅切换按钮：手动改即视为「不跟随系统」。
fn theme_toggle_button(app : @shared.App) -> @core.Node {
  @ui.icon_button_t(
    @icons.Moon,
    on_click=fn() {
      app.follow.set(false)
      app.dark_mode.update(fn(v) { !v })
    },
  )
}

///|
fn main {
  let selected : @core.Store[String] = @core.Store::new("基础组件")
  let toast_push = @ui.toast_layer(duration_ms=2600)
  // 代码区「复制」的回显走同一 toast 层
  @shared.code_toast.val = Some(toast_push)
  let counter = @core.Signal::new(0)
  let app : @shared.App = {
    selected,
    toast: toast_push,
    dark_mode: @core.Store::new(@win.sys_color_scheme() == "dark"),
    // 启动即跟随系统主色调（系统无主色概念时回落内置 primary）
    accent: @core.Store::new(@win.sys_accent()),
    follow: @core.Store::new(true),
    counter,
    // visits/ratio 由 counter 派生（computed 自动收集依赖，不写手动接线）
    visits: @core.Signal::computed(fn() {
      (counter.get() * 1601 + 12804).to_string()
    }),
    ratio: @core.Signal::computed(fn() {
      let r = 0.25 + counter.get().to_double() * 0.1
      if r > 1.0 {
        1.0
      } else {
        r
      }
    }),
    picked_lang: @core.Signal::new(""),
    dlg_basic: @core.Store::new(false),
    dlg_form: @core.Store::new(false),
    dlg_name: @core.Store::new(""),
    dlg_result: @core.Store::new(""),
  }
  // 深浅/主色任一变化即整体换主题；subscribe 注册不回调，故先应用一次
  app.dark_mode.subscribe(fn(_v) { apply_theme(app) })
  app.accent.subscribe(fn(_a) { apply_theme(app) })
  apply_theme(app)
  let slot : Ref[@core.App?] = Ref(None)
  let mounted = @ui.mount_window(
    [
      @ui.hbox(
        [
          // 侧栏：可滚动的分组菜单（窗口矮时滚到底部项）+ 底部主题切换 + 版本号
          @ui.vbox(
            [
              @ui.scroll_v(
                [
                  @ui.side_menu_sections(
                    [("组件", ["基础组件", "表单组件", "导航组件", "反馈组件"])],
                    selected,
                    icons=[
                      ("基础组件", @icons.Appstore),
                      ("表单组件", @icons.Edit1),
                      ("导航组件", @icons.Compass),
                      ("反馈组件", @icons.ChatRound),
                    ],
                    width=180.0,
                  ),
                ],
                @ui.ScrollState::new(),
                handle=fn(v) { v.node.set_flex_grow(1.0) },
              ),
              @ui.hbox(
                [
                  @ui.label_t("V" + SHOWCASE_VERSION, role=@ui.Secondary),
                  theme_toggle_button(app),
                ],
                padding=10.0,
                column_gap=8.0,
              ),
            ],
            width=180.0,
          ),
          // 主区：按导航状态切换的页（惰性挂载，首次选中才建控件）
          @ui.vbox(
            [
              @shared.nav_page("基础组件", selected, @pages.page_basic(app)),
              @shared.nav_page("表单组件", selected, @pages.page_form(app)),
              @shared.nav_page("导航组件", selected, @pages.page_nav(app)),
              @shared.nav_page("反馈组件", selected, @pages.page_feedback(app)),
              // 对话框挂窗口根：锚点自己是 0 尺寸占位，可见性只由 Store 驱动
              @ui.dialog_t(
                app.dlg_basic,
                "删除确认",
                [
                  @ui.alert(
                    "此操作不可撤销，请确认。",
                    t=@ui.Warning,
                    closable=true,
                  ),
                  @ui.label_t("确定要删除「示例项目」吗？", role=@ui.Body),
                ],
                confirm_text="删除",
                cancel_text="取消",
                on_confirm=fn() { app.dlg_result.set("已确认删除") },
                close_on_mask=true,
              ),
              @ui.dialog_t(
                app.dlg_form,
                "新建连接",
                [
                  @ui.label_t("名称", role=@ui.Body),
                  @ui.entry(app.dlg_name, placeholder="例如：开发库", width=320.0),
                  @ui.label_t("地址", role=@ui.Body),
                  @ui.entry(@core.Store::new(""), placeholder="host:port", width=320.0),
                ],
                on_confirm=fn() { app.dlg_result.set(app.dlg_name.get()) },
                width=380.0,
              ),
            ],
            grow=1.0,
          ),
        ],
        grow=1.0,
        align_items=@yoga.AlignItems::Stretch,
      ),
    ],
    title=SHOWCASE_TITLE,
    width=1280,
    height=720,
    handle=fn(a : @core.App) {
      slot.val = Some(a)
      // 「跟随系统」轮询：开关打开时每 2 秒读一次系统深浅与主色，
      // 变了就写进 App（App 的 subscribe 再落成 theme_apply）
      let tick : Ref[() -> Unit] = Ref(fn() { () })
      tick.val = fn() -> Unit {
        if app.follow.get() {
          app.dark_mode.set(@win.sys_color_scheme() == "dark")
          app.accent.set(@win.sys_accent())
        }
        let _ = a.timer(2000, tick.val)
      }
      (tick.val)()
    },
  )
  match mounted {
    None => {
      println("SHOWCASE-SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(host) => {
      println("SHOWCASE-READY title=\{SHOWCASE_TITLE} pages=4 follow=1")
      host.run()
    }
  }
  println("SHOWCASE-DONE page=\{selected.get()}")
}
