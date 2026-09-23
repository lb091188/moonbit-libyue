// 应用壳 + 资源导航（U1/U2）：Mission Center 式双栏布局。
// 左栏 = 资源卡片（处理器 / 内存 / 磁盘 / 网络 / 显卡×N / 进程），
// 按硬件实况出卡（核显 / 独显各一张），卡片即菜单：点击切换右栏
// 详情页，选中卡主题色描边。右栏 = 全部详情页一次性挂载、只切可见
// 性（tabs_t 同款机制），选中态 / 滚动位置 / 表格选择不丢。
// 数据来自 main.mbt 的 1Hz sample_once；卡片数值只改文本，迷你曲线
// 只 schedule_paint 画布。

///|
/// 右栏视图（与左栏卡片一一对应；GPU 卡共享传感器页）。
pub(all) enum ViewId {
  VCpu
  VMem
  VDisk
  VNet
  VGpu
  VProc
}

///|
/// 视图 → 序号（枚举比较经序号，全库同款做法）。
fn view_index(v : ViewId) -> Int {
  match v {
    VCpu => 0
    VMem => 1
    VDisk => 2
    VNet => 3
    VGpu => 4
    VProc => 5
  }
}

///|
/// 卡内迷你曲线：序列窗口值 + 末端圆点。y_range 给固定值域；None 时
/// 取窗口峰值自适应（floor 保底，防全零时除零 / 全平时看不出起伏）。
fn sparkline_box(
  hist : @yue.Store[Array[@yue.LineSeries]],
  y_range : (Double, Double)?,
  floor : Double,
) -> @yue.Node {
  @yue.vbox(
    [],
    style=[("height", 34.0), ("marginTop", 8.0)],
    handle=fn(c) {
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        let t = @yue.theme_current()
        let (lo, hi) = match y_range {
          Some((a, bb)) => (a, bb)
          None => {
            let mut peak = floor
            for s in hist.get() {
              for v in s.points {
                if v > peak {
                  peak = v
                }
              }
            }
            (0.0, peak)
          }
        }
        // 多序列同窗叠加（网络卡 rx 主题色 / tx 警告色）
        for si, s in hist.get() {
          let color = if si == 0 {
            t.primary
          } else {
            t.warning
          }
          draw_sparkline(p, 0.0, 2.0, b.width, b.height - 4.0, s.points, lo, hi, color)
        }
      })
      hist.subscribe(fn(_s) { c.schedule_paint() })
      // 主题切换后重绘（绘制时读 theme_current）
      @yue.on_theme_change(fn() { c.schedule_paint() })
    },
  )
}

///|
/// 资源卡片（导航菜单项）：图标 + 标题 / 规格副标题 / 当前值 / 迷你
/// 曲线（hist 为 None 时省略）。点击切到 target 视图；选中卡主题色
/// 描边 + 浅底。不做 hover 高亮：卡内子控件会打断容器的
/// enter/leave（GTK 按原生窗口边界派发），高亮会闪烁，悬停反馈只
/// 留手型光标。
fn res_card(
  icon : @yue.IconKind,
  title : String,
  subtitle : @yue.Store[String],
  value : @yue.Store[String],
  hist : @yue.Store[Array[@yue.LineSeries]]?,
  view : @yue.Store[ViewId],
  target : ViewId,
  y_range? : (Double, Double)? = None,
  floor? : Double = 1.0,
) -> @yue.Node {
  let spark = match hist {
    None => @yue.label("")
    Some(h) => sparkline_box(h, y_range, floor)
  }
  @yue.vbox(
    [
      @yue.hbox(
        [
          @yue.icon(icon, size=16.0),
          @yue.label_t(title, role=@yue.Section, style=[("marginLeft", 6.0)]),
        ],
        style_str=[("alignItems", "center")],
      ),
      @yue.label_t(
        subtitle.get(),
        role=@yue.Secondary,
        handle=fn(l) { subtitle.subscribe(fn(s) { l.set_text(s) }) },
        style=[("marginTop", 2.0)],
      ),
      @yue.label_t(
        value.get(),
        role=@yue.Title,
        handle=fn(l) { value.subscribe(fn(v) { l.set_text(v) }) },
        style=[("marginTop", 4.0)],
      ),
      spark,
    ],
    style=[("padding", 12.0), ("marginBottom", 10.0)],
    handle=fn(c) {
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        let t = @yue.theme_current()
        let act = view_index(view.get()) == view_index(target)
        p.set_fill_color(if act { t.fill_hover } else { t.bg_panel })
        p.fill_rect(0.0, 0.0, b.width, b.height)
        p.set_stroke_color(if act { t.primary } else { t.border })
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
      })
      // 主题切换 / 选中态变化都只重绘画布
      @yue.on_theme_change(fn() { c.schedule_paint() })
      view.subscribe(fn(_v) { c.schedule_paint() })
      @yue.View::set_cursor(c, @yue.Cursor::new(@yue.Hand))
      @yue.ViewLike::on_mouse_down(c, fn(e) {
        if e.button == 1 {
          view.set(target)
          true
        } else {
          false
        }
      })
    },
  )
}

///|
/// 左栏：资源卡片导航（显单一列，超高滚动）。显卡按硬件实况出卡
/// （核显 / 独显各一张，均指向传感器页）。
fn left_pane(app : App, view : @yue.Store[ViewId]) -> @yue.Node {
  let blank = @yue.Store::new("")
  let cards : Array[@yue.Node] = [
    res_card(
      @yue.Cpu,
      "处理器",
      app.card_cpu_sub,
      app.card_cpu,
      Some(app.cpu_hist),
      view,
      VCpu,
      y_range=Some((0.0, 100.0)),
    ),
    res_card(
      @yue.Database,
      "内存",
      app.card_mem_sub,
      app.card_mem,
      Some(app.mem_hist),
      view,
      VMem,
    ),
    res_card(
      @yue.HardDrive,
      "磁盘",
      app.card_disk_sub,
      app.card_disk,
      Some(app.disk_hist),
      view,
      VDisk,
      y_range=Some((0.0, 100.0)),
    ),
    res_card(
      @yue.Wifi,
      "网络",
      blank,
      app.card_net,
      Some(app.net_hist),
      view,
      VNet,
      floor=1048576.0,
    ),
  ]
  // 显卡卡：一块物理卡一张（数据取构建时枚举结果，GPU 热插拔不重建）
  for i, g in app.gpus.get() {
    let sub = @yue.Store::new("\{g.vendor} · \{g.device}")
    let val = @yue.Store::new(match g.celsius {
      None => "—"
      Some(c) => "\{c.to_int()}℃"
    })
    cards.push(
      res_card(@yue.Monitor, "显卡 \{i + 1}", sub, val, None, view, VGpu),
    )
  }
  cards.push(
    res_card(
      @yue.TableRows,
      "进程",
      blank,
      app.card_proc,
      Some(app.proc_hist),
      view,
      VProc,
    ),
  )
  @yue.scroll(
    @yue.vbox(cards, style=[("padding", 10.0)]),
    style=[("width", 292.0)],
  )
}

///|
/// 右栏：全部详情页一次性挂载，按 view 切可见性（tabs_t 同款机制，
/// 页内选中态 / 滚动位置不丢）。
fn view_area(app : App, view : @yue.Store[ViewId]) -> @yue.Node {
  let items : Array[(ViewId, @yue.Node)] = [
    (VCpu, page_cpu_detail(app)),
    (VMem, page_mem_detail(app)),
    (VDisk, page_disk(app)),
    (VNet, page_net(app)),
    (VGpu, page_sensors(app)),
    (VProc, page_process(app)),
  ]
  @yue.vbox(
    [],
    style=[("flex", 1.0)],
    style_str=[("flexDirection", "column")],
    handle=fn(area) {
      let boxes : Array[@yue.Container] = []
      for item in items {
        let (_, node) = item
        let pc = @yue.Container::make(
          style=[("flex", 1.0)],
          style_str=[("flexDirection", "column")],
        )
        @yue.ViewLike::set_visible(pc, view_index(item.0) == view_index(view.get()))
        ignore(node.mount_into(@yue.ViewLike::view(pc)))
        area.add_child(pc)
        boxes.push(pc)
      }
      view.subscribe(fn(cur) {
        for j in 0..<boxes.length() {
          @yue.ViewLike::set_visible(boxes[j], view_index(items[j].0) == view_index(cur))
        }
      })
    },
  )
}

///|
/// 处理器详情：总占用曲线（0-100 固定轴）+ 各核占用柱状（0-100，
/// 自动量程会让 5% 看起来像满格）。
fn page_cpu_detail(app : App) -> @yue.Node {
  @yue.vbox(
    [
      @yue.label_t("总占用（%）", role=@yue.Section, style=[
        ("marginBottom", 6.0),
      ]),
      @yue.line_chart_t(
        app.cpu_hist,
        height=250.0,
        y_range=Some((0.0, 100.0)),
        fill=true,
      ),
      @yue.label_t("各逻辑核（%）", role=@yue.Section, style=[
        ("marginTop", 14.0),
        ("marginBottom", 6.0),
      ]),
      @yue.bar_chart_t(
        app.core_bars,
        height=250.0,
        y_range=Some((0.0, 100.0)),
        fill=true,
      ),
    ],
    style=[("padding", 12.0)],
  )
}

///|
/// 内存详情：已用曲线 + swap 曲线（自适应轴看细节）。
fn page_mem_detail(app : App) -> @yue.Node {
  @yue.vbox(
    [
      @yue.label_t("内存（GB）", role=@yue.Section, style=[
        ("marginBottom", 6.0),
      ]),
      @yue.line_chart_t(app.mem_hist, height=250.0, fill=true),
      @yue.label_t("swap（GB）", role=@yue.Section, style=[
        ("marginTop", 14.0),
        ("marginBottom", 6.0),
      ]),
      @yue.line_chart_t(app.swap_hist, height=250.0, fill=true),
    ],
    style=[("padding", 12.0)],
  )
}

///|
/// 双栏应用壳：左栏卡片导航 + 右栏详情页。
fn app_shell(app : App) -> @yue.Node {
  let view : @yue.Store[ViewId] = @yue.Store::new(VCpu)
  @yue.hbox(
    [left_pane(app, view), view_area(app, view)],
    style=[("flex", 1.0)],
  )
}
