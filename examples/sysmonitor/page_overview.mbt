// 应用壳 + 资源导航（U1/U2）：Mission Center 式双栏布局。
// 左栏 = 资源卡片（处理器 / 内存 / 磁盘 / 网络 / 显卡×N / 进程），
// 按硬件实况出卡（核显 / 独显各一张），卡片即菜单：点击切换右栏
// 详情页，选中卡主题色描边。右栏 = 全部详情页一次性挂载、只切可见
// 性，选中态 / 滚动位置 / 表格选择不丢。
// 数据来自 main.mbt 的 1Hz sample_once；卡片数值只改文本，迷你曲线
// 只进程级 invalidate 重绘画布。

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
/// 手型光标由外层 cursor_group 统一下发（本栈光标按悬停路径最深请求
/// 生效，不再逐子控件各设一份）。
fn sparkline_box(
  hist : @core.Store[Array[@charts.LineSeries]],
  y_range : (Double, Double)?,
  floor : Double,
) -> @core.Node {
  @core.node_of_new(fn(c : @core.Widget) -> @core.Widget {
    c.node.set_height(@yoga.fixed(34.0))
    c.node.set_width(@yoga.percent(100.0))
    c.on_draw = Some(fn(_s : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
      let t = @theme.theme_current()
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
        let color = if si == 0 { t.primary } else { t.warning }
        draw_sparkline(p, 0.0, 2.0, r.w, r.h - 4.0, s.points, lo, hi, color)
      }
    })
    hist.subscribe(fn(_s) { @core.invalidate() })
    ignore(@theme.on_theme_change(fn() { @core.invalidate() }))
    c
  })
}

///|
/// 资源卡片（导航菜单项）：标题行 = 图标 + 标题 + 右侧当前值（紧凑
/// 格式），下方可选迷你曲线（hist 为 None 时省略，卡片只剩标题栏 +
/// 内边距的高度）。点击切到 target 视图；选中卡主题色描边 + 浅底。
/// 悬停反馈只有手型光标（cursor_group 统一给）。
fn res_card(
  icon : @icons.IconKind,
  title : String,
  value : @core.Store[String],
  hist : @core.Store[Array[@charts.LineSeries]]?,
  view : @core.Store[ViewId],
  target : ViewId,
  y_range? : (Double, Double)? = None,
  floor? : Double = 1.0,
) -> @core.Node {
  let spark : Array[@core.Node] = match hist {
    None => []
    Some(h) => [sparkline_box(h, y_range, floor)]
  }
  @ui.container(
    [
      @ui.hbox(
        [
          @ui.icon(icon, size=16.0),
          @ui.label_t(title, role=@ui.Section),
          // 值行：吃掉标题行剩余宽度（grow），文本右对齐——空间全部
          // 给数值，比标题小两档，固定右缘不随文本回流换行
          @ui.label_dyn(
            value.signal(),
            size=14.0,
            weight=@text.SemiBold,
            color=@theme.theme_text_primary(),
            align=@text.End,
            handle=fn(w) { w.node.set_flex_grow(1.0) },
          ),
        ],
        column_gap=6.0,
      ),
    ] + spark,
    padding=12.0,
    handle=fn(c) {
      // 覆盖 container 的默认底色绘制：选中态主题色描边 + 浅底
      c.on_draw = Some(fn(_s : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
        let t = @theme.theme_current()
        let act = view_index(view.get()) == view_index(target)
        p.set_fill_color(if act { t.fill_hover } else { t.bg_panel })
        p.fill_rect(0.0, 0.0, r.w, r.h)
        p.set_stroke_color(if act { t.primary } else { t.border })
        p.set_line_width(1.0)
        p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      })
      // 主题切换 / 选中态变化都只请求一次全窗重绘
      ignore(@theme.on_theme_change(fn() { @core.invalidate() }))
      view.subscribe(fn(_v) { @core.invalidate() })
      c.on_pointer = Some(fn(_s : @core.Widget, ev : @core.PointerEvent) -> Bool {
        match ev.kind {
          @core.Down =>
            if ev.button == 1 {
              view.set(target)
              true
            } else {
              false
            }
          _ => false
        }
      })
      c.cursor = @core.CURSOR_HAND
    },
  )
}

///|
/// 左栏：资源卡片导航（显单一列，超高滚动）。显卡按硬件实况出卡
/// （核显 / 独显各一张，均指向传感器页）。
fn left_pane(app : App, view : @core.Store[ViewId]) -> @core.Node {
  let cards : Array[@core.Node] = [
    res_card(
      @icons.Cpu,
      "处理器",
      app.card_cpu,
      Some(app.cpu_hist),
      view,
      VCpu,
      y_range=Some((0.0, 100.0)),
    ),
    res_card(
      @icons.Database,
      "内存",
      app.card_mem,
      Some(app.mem_hist),
      view,
      VMem,
    ),
    res_card(
      @icons.Wifi,
      "网络",
      app.card_net,
      Some(app.net_hist),
      view,
      VNet,
      floor=1048576.0,
    ),
  ]
  // 磁盘卡：每个用户挂载一张（根分区标题「磁盘」，其余用挂载点做
  // 标题），数量取启动枚举结果，1Hz 采样更新各自文本与曲线
  for i in 0..<app.disk_hists.length() {
    let mount = if i < app.disks.get().length() {
      app.disks.get()[i].mount
    } else {
      ""
    }
    let title = if mount == "/" || app.disk_hists.length() == 1 {
      "磁盘"
    } else {
      mount
    }
    cards.push(
      res_card(
        @icons.Sever,
        title,
        app.card_disk_vals[i],
        Some(app.disk_hists[i]),
        view,
        VDisk,
        y_range=Some((0.0, 100.0)),
      ),
    )
  }
  // 显卡卡：一块物理卡一张（值 = 使用率·温度，无曲线，紧凑高度；
  // Store 在 App 构建时按启动枚举预建，1Hz 采样更新文本）
  for i in 0..<app.card_gpu_vals.length() {
    cards.push(
      res_card(
        @icons.Monitor,
        "显卡 \{i + 1}",
        app.card_gpu_vals[i],
        None,
        view,
        VGpu,
      ),
    )
  }
  cards.push(
    res_card(@icons.TableIcon, "进程", app.card_proc, None, view, VProc),
  )
  @ui.scroll(
    [@ui.vbox(cards, padding=10.0, row_gap=10.0)],
    @ui.ScrollState::new(),
    width=292.0,
    handle=fn(v) { v.node.set_flex_grow(1.0) },
  )
}

///|
/// 右栏：全部详情页一次性挂载，按 view 切可见性（页内选中态 /
/// 滚动位置不丢）。
fn view_area(app : App, view : @core.Store[ViewId]) -> @core.Node {
  let items : Array[(ViewId, @core.Node)] = [
    (VCpu, page_cpu_detail(app)),
    (VMem, page_mem_detail(app)),
    (VDisk, page_disk(app)),
    (VNet, page_net(app)),
    (VGpu, page_sensors(app)),
    (VProc, page_process(app)),
  ]
  @ui.container(
    [],
    grow=1.0,
    handle=fn(area) {
      let boxes : Array[@core.Widget] = []
      for item in items {
        let (_, node) = item
        let pc = @core.Widget::new()
        pc.node.set_flex_direction(@yoga.Column)
        pc.node.set_flex_grow(1.0)
        pc.node.set_min_width(@yoga.fixed(0.0))
        pc.node.set_min_height(@yoga.fixed(0.0))
        pc.set_visible(view_index(item.0) == view_index(view.get()))
        // 页面内容整页滚动，超窗不裁切
        let sc = @ui.scroll([node], @ui.ScrollState::new())
        let _ = sc.mount_into(pc)
        area.append_child(pc)
        boxes.push(pc)
      }
      view.subscribe(fn(cur) {
        for j in 0..<boxes.length() {
          boxes[j].set_visible(view_index(items[j].0) == view_index(cur))
        }
        @core.invalidate()
      })
    },
  )
}

///|
/// 处理器详情：总占用曲线（0-100 固定轴）+ 各核占用柱状（0-100，
/// 自动量程会让 5% 看起来像满格）。
fn page_cpu_detail(app : App) -> @core.Node {
  @ui.vbox(
    [
      @ui.label_t("总占用（%）", role=@ui.Section),
      @charts.line_chart_t(
        app.cpu_hist,
        height=250.0,
        y_range=Some((0.0, 100.0)),
        area=true,
      ),
      @ui.label_t("各逻辑核（%）", role=@ui.Section),
      @charts.bar_chart_t(
        app.core_bars,
        height=250.0,
        y_range=Some((0.0, 100.0)),
      ),
    ],
    padding=12.0,
    row_gap=6.0,
  )
}

///|
/// 内存详情：已用曲线 + swap 曲线（自适应轴看细节）。
fn page_mem_detail(app : App) -> @core.Node {
  @ui.vbox(
    [
      @ui.label_t("内存（GB）", role=@ui.Section),
      @charts.line_chart_t(app.mem_hist, height=250.0, area=true),
      @ui.label_t("swap（GB）", role=@ui.Section),
      @charts.line_chart_t(app.swap_hist, height=250.0, area=true),
    ],
    padding=12.0,
    row_gap=6.0,
  )
}

///|
/// 双栏应用壳：左栏卡片导航 + 右栏详情页。手型光标套 cursor_group，
/// 组内任意位置（含卡片子控件）都是手型。
fn app_shell(app : App) -> @core.Node {
  let view : @core.Store[ViewId] = @core.Store::new(VCpu)
  @ui.cursor_group(
    [@ui.hbox([left_pane(app, view), view_area(app, view)], grow=1.0)],
  )
}
