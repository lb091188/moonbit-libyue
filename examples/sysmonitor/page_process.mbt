// 进程页（U3）：table_v 虚拟表格（千行级）+ 搜索过滤 + 列头排序 +
// 选中 kill（SIGTERM 失败 SIGKILL）/ renice，1Hz 增量刷新。
// 选择按 pid 重映射：每次刷新把旧选中行号经 pid 数组映射到新行号，
// 排序变化（CPU% 实时变动）不会让选中漂到别的进程。数据来自 main.mbt
// 的 1Hz sample_once 写入的 app.procs。

///|
/// 进程排序列（列头索引经 sort_of_col 映射；状态与命令行列不参与排序）。
pub(all) enum ProcSort {
  ByPid
  ByName
  ByCpu
  ByMem
  ByNice
  ByThreads
}

///|
/// 一位小数（CPU% 显示）。
fn fmt1(v : Double) -> String {
  let scaled = (v * 10.0).round().to_int()
  "\{scaled / 10}.\{scaled % 10}"
}

///|
/// 搜索过滤：query 命中 pid 十进制 / 进程名 / 命令行（大小写不敏感）；
/// 空 query 全收。返回新数组，不改入参。
pub fn filter_procs(procs : Array[ProcInfo], query : String) -> Array[ProcInfo] {
  let q = query.trim().to_lower()
  if q == "" {
    let all : Array[ProcInfo] = []
    for p in procs {
      all.push(p)
    }
    return all
  }
  let out : Array[ProcInfo] = []
  for p in procs {
    let hay = "\{p.pid} \{p.name} \{p.cmd}".to_lower()
    if hay.contains(q) {
      out.push(p)
    }
  }
  out
}

///|
/// 按列排序（asc 升序 / false 降序），返回新数组。
pub fn sort_procs(
  procs : Array[ProcInfo],
  by : ProcSort,
  asc : Bool,
) -> Array[ProcInfo] {
  let out : Array[ProcInfo] = []
  for p in procs {
    out.push(p)
  }
  fn key_of(p : ProcInfo, by : ProcSort) -> Double {
    match by {
      ByPid => p.pid.to_double()
      ByName => 0.0
      ByCpu => p.cpu_pct
      ByMem => p.rss_kb.to_double()
      ByNice => p.nice.to_double()
      ByThreads => p.threads.to_double()
    }
  }

  if by is ByName {
    // 名称列按字符串比较（大小写不敏感）
    out
    .mut_view()
    .sort_by(fn(a, b) {
      let ka = a.name.to_lower()
      let kb = b.name.to_lower()
      let c = if ka < kb { -1 } else if ka > kb { 1 } else { 0 }
      if asc {
        c
      } else {
        -c
      }
    })
  } else {
    out
    .mut_view()
    .sort_by(fn(a, b) {
      let ka = key_of(a, by)
      let kb = key_of(b, by)
      let c = if ka < kb { -1 } else if ka > kb { 1 } else { 0 }
      if asc {
        c
      } else {
        -c
      }
    })
  }
  out
}

///|
/// 进程行 → 表格行（列序：PID / 进程名 / 状态 / CPU% / 内存 / nice / 线程 /
/// 命令行；与 page_process 的 columns 定义一致）。
pub fn proc_row(p : ProcInfo) -> @ui.TableRow {
  @ui.TableRow::make([
    "\{p.pid}",
    p.name,
    p.state,
    fmt1(p.cpu_pct),
    fmt_kb(p.rss_kb),
    "\{p.nice}",
    "\{p.threads}",
    p.cmd,
  ])
}

///|
/// 列头索引 → 排序列（状态 / 命令行列返回 None）。
fn sort_of_col(j : Int) -> ProcSort? {
  match j {
    0 => Some(ByPid)
    1 => Some(ByName)
    3 => Some(ByCpu)
    4 => Some(ByMem)
    5 => Some(ByNice)
    6 => Some(ByThreads)
    _ => None
  }
}

///|
/// 页面状态：派生表格数据 + 过滤 / 排序条件 + 操作消息。
/// 排序条件走 @ui.TableSort Store（表头点击由 table_v 组件内切换，
/// 本页订阅后重建数据），箭头显示与点击切换因此对组件透明。
struct ProcPage {
  rows : @base.Store[Array[@ui.TableRow]]
  sel : @base.Store[Array[Int]]
  msg : @base.Store[String]
  status : @base.Store[String]
  sort : @base.Store[@ui.TableSort]
  mut pids : Array[Int]
  mut query : String
  mut nice_text : String
}

///|
/// 重建派生数据：过滤 + 排序 → rows；选择按 pid 重映射到新行号。
fn ProcPage::rebuild(self : ProcPage, procs : Array[ProcInfo]) -> Unit {
  // 旧选中行号 → pid（刷新前先取，避免排序变化后漂移）
  let old = self.sel.get()
  let sel_pids : Array[Int] = []
  for i in old {
    if i >= 0 && i < self.pids.length() {
      sel_pids.push(self.pids[i])
    }
  }
  let filtered = filter_procs(procs, self.query)
  let st = self.sort.get()
  let sorted = match sort_of_col(st.column) {
    None => filtered
    Some(by) => sort_procs(filtered, by, st.asc)
  }
  let rows : Array[@ui.TableRow] = []
  let pids : Array[Int] = []
  for p in sorted {
    rows.push(proc_row(p))
    pids.push(p.pid)
  }
  self.pids = pids
  self.rows.set(rows)
  // 重映射选择：pid 仍存在才保留
  let new_sel : Array[Int] = []
  for pid in sel_pids {
    for i in 0..<pids.length() {
      if pids[i] == pid {
        new_sel.push(i)
        break
      }
    }
  }
  self.sel.set(new_sel)
  let base = if pids.length() == procs.length() {
    "\{pids.length()} 个进程"
  } else {
    "\{pids.length()}/\{procs.length()} 个进程"
  }
  self.status.set(
    if new_sel.length() > 0 {
      "\{base} · 选中 \{new_sel.length()}"
    } else {
      base
    },
  )
}

///|
/// 当前选中行对应的 pid 列表。
fn ProcPage::selected_pids(self : ProcPage) -> Array[Int] {
  let out : Array[Int] = []
  for i in self.sel.get() {
    if i >= 0 && i < self.pids.length() {
      out.push(self.pids[i])
    }
  }
  out
}

///|
/// 对选中进程发信号（结束 / 强杀），逐个报告结果。
fn ProcPage::signal_selected(
  self : ProcPage,
  sig : Int,
  label : String,
) -> Unit {
  let pids = self.selected_pids()
  if pids.length() == 0 {
    self.msg.set("先选中进程")
    return
  }
  let mut ok = 0
  let mut fail = ""
  for pid in pids {
    match kill_signal(pid, sig) {
      Ok(_) => ok += 1
      Err(e) => fail = "\{fail},[\{pid}]\{e}"
    }
  }
  self.msg.set(
    if fail == "" {
      "已\{label} \{ok} 个进程"
    } else {
      "\{label}:\{ok} 个成功\{fail}"
    },
  )
}

///|
/// 对选中进程设 nice（-20..19），逐个报告结果。Windows 侧 set 后回读
/// 档位代表值（离散档钳制后的实际值），Linux 直接报告输入值。
fn ProcPage::renice_selected(self : ProcPage, platform : String) -> Unit {
  let pids = self.selected_pids()
  if pids.length() == 0 {
    self.msg.set("先选中进程")
    return
  }
  let nice = match parse_i64(self.nice_text.trim()) {
    None => {
      self.msg.set("nice 需为整数")
      return
    }
    Some(v) => v.to_int()
  }
  if nice < -20 || nice > 19 {
    self.msg.set("nice 需在 -20..19")
    return
  }
  let mut ok = 0
  let mut fail = ""
  let mut effective = nice
  for pid in pids {
    match set_priority(pid, nice) {
      Ok(_) => {
        ok += 1
        if platform == "windows" {
          // 离散档:回读钳制后的档位代表值再报告
          match get_priority(pid) {
            Ok(v) => effective = v
            Err(_) => ()
          }
        }
      }
      Err(e) => fail = "\{fail},[\{pid}]\{e}"
    }
  }
  self.msg.set(priority_result(platform, effective, ok, fail))
}

///|
fn page_process(app : App) -> @widget.Node {
  // 平台化文案：Windows kill 一律 TerminateProcess 一档、优先级四档
  // 离散钳制；Linux 维持 SIGTERM/SIGKILL 两档与连续 nice
  let platform : String = if on_windows() { "windows" } else { "linux" }
  let (end_label, force_label) = kill_button_labels(platform)
  let (prio_btn, prio_hint) = priority_ui(platform)
  let page : ProcPage = {
    rows: @base.Store::new([]),
    sel: @base.Store::new([]),
    // 初始消息即优先级口径说明（首次操作后被结果覆盖）
    msg: @base.Store::new(prio_hint),
    status: @base.Store::new("采样中…"),
    // 初始排序：CPU% 降序（列 3）
    sort: @base.Store::new(@ui.TableSort::{ column: 3, asc: false, }),
    pids: [],
    query: "",
    nice_text: "10",
  }
  // 初始数据 + 订阅 1Hz 刷新（增量：只重算派生数据，不重建视图树）
  page.rebuild(app.procs.get())
  app.procs.subscribe(fn(procs) { page.rebuild(procs) })
  // 表头排序点击（table_v 组件内切换 Store）→ 重建数据
  page.sort.subscribe(fn(_s) { page.rebuild(app.procs.get()) })

  let query_store : @base.Store[String] = @base.Store::new("")
  let nice_store : @base.Store[String] = @base.Store::new("10")
  let tools : Array[@widget.Node] = [
    @ui.text("搜索", color="text_secondary", role=Body),
    // 搜索框：文本经 store 双向投影，on_change 里重建派生数据
    @ui.input(
      query_store,
      placeholder="进程名 / pid",
      width=220.0,
      on_change=fn(s) {
        page.query = s
        page.rebuild(app.procs.get())
      },
    ),
  ]
  match force_label {
    None =>
      // Windows：一律立即终止，单按钮
      tools.push(
        @ui.button(end_label, variant=@ui.Danger, on_click=fn() {
          page.signal_selected(SIGKILL, "强制结束")
        }),
      )
    Some(fl) => {
      // Linux：温和结束（SIGTERM）+ 强制结束（SIGKILL 兜底）两档
      tools.push(
        @ui.button(end_label, variant=@ui.Soft, on_click=fn() {
          page.signal_selected(SIGTERM, "结束")
        }),
      )
      tools.push(
        @ui.button(fl, variant=@ui.Danger, on_click=fn() {
          page.signal_selected(SIGKILL, "强制结束")
        }),
      )
    }
  }
  tools.push(
    @ui.input(nice_store, width=72.0, on_change=fn(s) { page.nice_text = s }),
  )
  tools.push(
    @ui.button(prio_btn, variant=@ui.Soft, on_click=fn() {
      page.renice_selected(platform)
    }),
  )

  let columns = [
    @ui.TableColumn::make("PID", 86.0, align=@text.End),
    @ui.TableColumn::make("进程名", 150.0),
    @ui.TableColumn::make("状态", 56.0, align=@text.Center, sortable=false),
    @ui.TableColumn::make("CPU%", 72.0, align=@text.End),
    @ui.TableColumn::make("内存", 96.0, align=@text.End),
    @ui.TableColumn::make(priority_col_header(platform), 72.0, align=@text.End),
    @ui.TableColumn::make("线程", 56.0, align=@text.End),
    @ui.TableColumn::make("命令行", 0.0, sortable=false),
  ]
  @ui.col(
    [
      // 工具栏：搜索 + 操作 + 消息
      @ui.row(tools, column_gap=8.0),
      @ui.text_dyn(
        page.msg.signal(),
        color="text_secondary",
      ),
      @ui.table_v(
        columns,
        page.rows,
        width=880.0,
        height=520.0,
        row_height=30.0,
        selection=page.sel,
        sort=page.sort,
      ),
      @ui.text_dyn(
        page.status.signal(),
        color="text_secondary",
      ),
    ],
    padding=12.0,
    row_gap=6.0,
  )
}
