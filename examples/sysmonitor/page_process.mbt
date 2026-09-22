// 进程页（U3）：table_v_t 虚拟表格（千行级）+ 搜索过滤 + 列头排序 +
// 选中 kill（SIGTERM 失败 SIGKILL）/ renice，1Hz 增量刷新。
// 选择按 pid 重映射：每次刷新把旧选中行号经 pid 数组映射到新行号，
// 排序变化（CPU% 实时变动）不会让选中漂到别的进程。数据来自 main.mbt
// 的 1Hz sample_once 写入的 app.procs。

///|
/// 进程排序列（列头点击切换；状态与命令行列不参与排序）。
pub(all) enum ProcSort {
  ByPid
  ByName
  ByCpu
  ByMem
  ByNice
  ByThreads
}

///|
/// 排序列 → 稳定整数编号（枚举未派生 Eq，比较走编号）。
fn sort_id(by : ProcSort) -> Int {
  match by {
    ByPid => 0
    ByName => 1
    ByCpu => 2
    ByMem => 3
    ByNice => 4
    ByThreads => 5
  }
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
    out.mut_view().sort_by(fn(a, b) {
      let ka = a.name.to_lower()
      let kb = b.name.to_lower()
      let c = if ka < kb {
        -1
      } else if ka > kb {
        1
      } else {
        0
      }
      if asc {
        c
      } else {
        -c
      }
    })
  } else {
    out.mut_view().sort_by(fn(a, b) {
      let ka = key_of(a, by)
      let kb = key_of(b, by)
      let c = if ka < kb {
        -1
      } else if ka > kb {
        1
      } else {
        0
      }
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
pub fn proc_row(p : ProcInfo) -> @yue.TableRow {
  @yue.TableRow::make([
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
/// 排序方向文案（工具栏 / 状态行显示）。
fn sort_text(by : ProcSort, asc : Bool) -> String {
  let name = match by {
    ByPid => "PID"
    ByName => "进程名"
    ByCpu => "CPU%"
    ByMem => "内存"
    ByNice => "nice"
    ByThreads => "线程"
  }
  "\{name} \{if asc { "↑" } else { "↓" }}"
}

///|
/// 页面状态：派生表格数据 + 过滤 / 排序条件 + 操作消息。
struct ProcPage {
  rows : @yue.Store[Array[@yue.TableRow]]
  sel : @yue.Store[Array[Int]]
  msg : @yue.Store[String]
  status : @yue.Store[String]
  mut pids : Array[Int]
  mut query : String
  mut sort_by : ProcSort
  mut sort_asc : Bool
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
  let sorted = sort_procs(filtered, self.sort_by, self.sort_asc)
  let rows : Array[@yue.TableRow] = []
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
  self.status.set(
    "共 \{pids.length()} 个进程（过滤自 \{procs.length()}）· 选中 \{new_sel.length()} · 排序 \{sort_text(self.sort_by, self.sort_asc)}",
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
/// 对选中进程发信号（SIGTERM / SIGKILL），逐个人态化报告。
fn ProcPage::signal_selected(self : ProcPage, sig : Int, label : String) -> Unit {
  let pids = self.selected_pids()
  if pids.length() == 0 {
    self.msg.set("未选中进程（先点表格行选中）")
    return
  }
  let mut ok = 0
  let mut fail = ""
  for pid in pids {
    match kill_signal(pid, sig) {
      Ok(_) => ok += 1
      Err(e) => fail = "\{fail} [\{pid}]\{e}"
    }
  }
  self.msg.set(
    if fail == "" {
      "\{label}：已发送给 \{ok} 个进程"
    } else {
      "\{label}：\{ok} 个成功，失败:\{fail}"
    },
  )
}

///|
/// 对选中进程设 nice（-20..19），逐个人态化报告。
fn ProcPage::renice_selected(self : ProcPage) -> Unit {
  let pids = self.selected_pids()
  if pids.length() == 0 {
    self.msg.set("未选中进程（先点表格行选中）")
    return
  }
  let nice = match parse_i64(self.nice_text.trim()) {
    None => {
      self.msg.set("nice 需为整数（-20..19）")
      return
    }
    Some(v) => v.to_int()
  }
  if nice < -20 || nice > 19 {
    self.msg.set("nice 需在 -20..19（越大越谦让）")
    return
  }
  let mut ok = 0
  let mut fail = ""
  for pid in pids {
    match set_priority(pid, nice) {
      Ok(_) => ok += 1
      Err(e) => fail = "\{fail} [\{pid}]\{e}"
    }
  }
  self.msg.set(
    if fail == "" {
      "renice：\{ok} 个进程已设为 \{nice}"
    } else {
      "renice：\{ok} 个成功，失败:\{fail}"
    },
  )
}

///|
fn page_process(app : App) -> @yue.Node {
  let page : ProcPage = {
    rows: @yue.Store::new([]),
    sel: @yue.Store::new([]),
    msg: @yue.Store::new("选中行后可结束进程 / 调整 nice；数据 1Hz 增量刷新。"),
    status: @yue.Store::new("采样中…"),
    pids: [],
    query: "",
    sort_by: ByCpu,
    sort_asc: false,
    nice_text: "10",
  }
  // 初始数据 + 订阅 1Hz 刷新（增量：只重算派生数据，不重建视图树）
  page.rebuild(app.procs.get())
  app.procs.subscribe(fn(procs) { page.rebuild(procs) })

  let columns = [
    @yue.TableColumn::make("PID", 86.0, align=@yue.End),
    @yue.TableColumn::make("进程名", 150.0),
    @yue.TableColumn::make("状态", 56.0, align=@yue.Center),
    @yue.TableColumn::make("CPU%", 72.0, align=@yue.End),
    @yue.TableColumn::make("内存", 96.0, align=@yue.End),
    @yue.TableColumn::make("nice", 56.0, align=@yue.End),
    @yue.TableColumn::make("线程", 56.0, align=@yue.End),
    @yue.TableColumn::make("命令行", 0.0),
  ]
  @yue.vbox(
    [
      // 工具栏：搜索 + 操作 + 消息
      @yue.hbox(
        [
          // 搜索框：主题化输入（自绘主题边框 + 主题底色 + 聚焦变色，
          // 悬停非空显示清空 ✕）——不用裸原生 Entry（Linux 下不跟主题）
          @yue.input_t(
            text=page.query,
            width=220.0,
            height=28.0,
            clearable=true,
            on_input=fn(s) {
              page.query = s
              page.rebuild(app.procs.get())
            },
          ),
          @yue.button_t("结束进程(SIGTERM)", variant=@yue.Soft, on_click=fn() {
            page.signal_selected(SIGTERM, "SIGTERM")
          }),
          @yue.button_t("强杀(SIGKILL)", variant=@yue.Danger, on_click=fn() {
            page.signal_selected(SIGKILL, "SIGKILL")
          }),
          @yue.input_t(
            text=page.nice_text,
            width=72.0,
            height=28.0,
            on_input=fn(s) { page.nice_text = s },
          ),
          @yue.button_t("设 nice", variant=@yue.Soft, on_click=fn() {
            page.renice_selected()
          }),
        ],
        style=[("marginBottom", 8.0)],
        style_str=[("alignItems", "center")],
      ),
      @yue.label_t(
        page.msg.get(),
        role=@yue.Secondary,
        handle=fn(l) { page.msg.subscribe(fn(m) { l.set_text(m) }) },
        style=[("marginBottom", 6.0)],
      ),
      @yue.table_v_t(
        columns,
        page.rows,
        width=1140.0,
        height=520.0,
        row_height=30.0,
        selection=page.sel,
        on_header_click=fn(j) {
          match sort_of_col(j) {
            None => ()
            Some(by) => {
              if sort_id(by) == sort_id(page.sort_by) {
                page.sort_asc = !page.sort_asc
              } else {
                page.sort_by = by
                page.sort_asc = false
              }
              page.rebuild(app.procs.get())
            }
          }
        },
      ),
      @yue.label_t(
        page.status.get(),
        role=@yue.Secondary,
        handle=fn(l) { page.status.subscribe(fn(s) { l.set_text(s) }) },
        style=[("marginTop", 6.0)],
      ),
    ],
    style=[("padding", 12.0)],
  )
}
