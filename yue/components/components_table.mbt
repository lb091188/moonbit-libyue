// 表格:table_t / table_v_t 与排序指示绘制。

///|
/// 表格列定义(EP Table):标题 + 宽度(<=0 为弹性列,均分剩余宽)
/// + 单元格文字对齐 + 是否可排序(表头点击切换升降序)。
pub(all) struct TableColumn {
  title : String
  width : Double
  align : @yue.TextAlign
  sortable : Bool
}

///|
/// 创建列定义(align 默认左对齐,sortable 默认可排序)。
pub fn TableColumn::make(
  title : String,
  width : Double,
  align? : @yue.TextAlign = @yue.Start,
  sortable? : Bool = true,
) -> TableColumn {
  { title, width, align, sortable, }
}

///|
/// 表格排序状态(表头点击后写入):column 为参与排序的列号(列定义
/// 下标,与复选框列无关),<0 表示不排序;asc 为升序。经 [table_t] /
/// [table_v_t] 的 sort 参数传入——组件内切换状态并画箭头,使用方
/// 订阅 Store 自行排序数据后回写 rows。
pub(all) struct TableSort {
  column : Int
  asc : Bool
}

///|
/// 表格单元格内容(自定义单元格):纯文本 / 语义 tag / 颜色块 / 多行文本。
pub(all) enum TableCell {
  CellText(String)
  CellTag(String, SemanticType)
  CellColorBox(String, String)
  CellLines(Array[String])
}

///|
/// 表格行数据:单元格按列顺序排列,缺位补空文本。
pub(all) struct TableRow {
  cells : Array[TableCell]
}

///|
/// 用纯文本数组建行(全部 CellText 的快捷方式)。
pub fn TableRow::make(cells : Array[String]) -> TableRow {
  let out : Array[TableCell] = []
  for c in cells {
    out.push(CellText(c))
  }
  { cells: out, }
}

///|
/// 表格复选框画法(同 checkbox_t):直角方框,选中实心主题色 + 白勾,
/// 部分选中画横条;(x, y) 为 14x14 方框左上角。
fn table_draw_check(
  p : @yue.Painter,
  x : Double,
  y : Double,
  checked : Bool,
  partial : Bool,
) -> Unit {
  p.set_stroke_color(
    if checked || partial {
      @yue.theme_primary()
    } else {
      @yue.theme_border()
    },
  )
  p.stroke_rect(x + 0.5, y + 0.5, 13.0, 13.0)
  if checked {
    p.set_fill_color(@yue.theme_primary())
    p.fill_rect(x + 2.0, y + 2.0, 10.0, 10.0)
    p.set_stroke_color("#FFFFFF")
    for off in [0.0, 0.5] {
      p.begin_path()
      p.move_to(x + 3.9 + off, y + 7.4)
      p.line_to(x + 6.0 + off, y + 9.5)
      p.line_to(x + 10.8 + off, y + 4.4)
      p.stroke()
    }
  } else if partial {
    p.set_fill_color(@yue.theme_primary())
    p.fill_rect(x + 4.0, y + 6.0, 6.0, 2.0)
  }
}

///|
/// 排序箭头(表头):cx/cy 为中心,asc 升序尖端朝上;active=false 画
/// 浅色(可排序列的 hover 提示,不表示当前排序)。8x7 矢量三角,
/// 不依赖字体。

///|
/// 排序箭头(表头,实心三角):cx/cy 为中心,asc 升序尖端朝上;
/// active=false 画灰色(未排序列的常驻 ↕ 提示,不表示当前方向)。
/// 8x7 矢量三角,fill_rect 拼不出圆润边角时保留路径版——表头容器
/// (单一绘制器)路径填充实测正常,小单元格容器反而不渲染(见
/// adaptation.md),故表格表头装饰一律画在表头容器上。
fn draw_sort_triangle(
  p : @yue.Painter,
  cx : Double,
  cy : Double,
  asc : Bool,
  active : Bool,
) -> Unit {
  p.set_fill_color(
    if active {
      @yue.theme_primary()
    } else {
      @yue.theme_border()
    },
  )
  p.begin_path()
  if asc {
    p.move_to(cx - 4.0, cy + 2.0)
    p.line_to(cx + 4.0, cy + 2.0)
    p.line_to(cx, cy - 2.5)
  } else {
    p.move_to(cx - 4.0, cy - 2.0)
    p.line_to(cx + 4.0, cy - 2.0)
    p.line_to(cx, cy + 2.5)
  }
  p.close_path()
  p.fill()
}

///|
/// 排序提示(表头,未排序列):上下双三角(↕),灰色,常驻显示——
/// 用户看到就知道这列可点排序;排序列换实心主题色单向箭头。
fn draw_sort_hint(p : @yue.Painter, cx : Double, cy : Double) -> Unit {
  p.set_fill_color(@yue.theme_border())
  // 上三角(中心 cy-3)
  p.begin_path()
  p.move_to(cx - 3.5, cy - 0.5)
  p.line_to(cx + 3.5, cy - 0.5)
  p.line_to(cx, cy - 5.0)
  p.close_path()
  p.fill()
  // 下三角(中心 cy+3):底边在上、顶点朝下
  p.begin_path()
  p.move_to(cx - 3.5, cy + 1.0)
  p.line_to(cx + 3.5, cy + 1.0)
  p.line_to(cx, cy + 5.5)
  p.close_path()
  p.fill()
}

///|
/// 表格最小列宽(拖动钳制下限):再窄标题/数值不可读。
let min_col_width : Double = 56.0

///|
/// 行底色:选中 > 悬停 > 斑马纹(奇数行) > 透明。
fn table_row_bg(i : Int, selected : Bool, hover : Bool) -> String {
  if selected {
    @yue.theme_primary_light()
  } else if hover {
    @yue.theme_fill_hover()
  } else if i % 2 == 1 {
    @yue.theme_fill_zebra()
  } else {
    ""
  }
}

///|
/// 表格(EP Table):表头 + 斑马纹 + 悬停底色 + Store 驱动(set 后整表
/// 重建行并清空选择)。不传 selection 时行点击单选高亮;传入
/// selection(Store[Array[Int]])启用复选框列:行点击勾选,表头全选/
/// 清空(部分选中画横条),选中行浅蓝底。单元格支持 CellText/CellTag/
/// CellColorBox/CellLines(多行文本的行自动撑高)。主题色在重绘时读取
/// 当前快照,theme_apply 即时生效。
/// 表头:sort(Store[TableSort])提供后排序列显示升降箭头,点击可排序
/// 列切换「新列升序 / 同列升降序」;列边界(表头右缘 4px)按住拖动
/// 调整列宽,相邻两列此消彼长(最小 min_col_width)。
pub fn table_t(
  columns : Array[TableColumn],
  rows : @yue.Store[Array[TableRow]],
  width? : Double = 560.0,
  row_height? : Double = 36.0,
  selection? : @yue.Store[Array[Int]],
  sort? : @yue.Store[TableSort],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i, _r) {  },
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let font = @yue.Font::new("Sans", 13.0)
      let small_font = @yue.Font::new("Sans", 12.0)
      let head_font = @yue.Font::new("Sans", 13.0, weight=@yue.SemiBold)
      let sel = selection
      let selected_i = Ref(-1)
      let hover_i = Ref(-1)
      let row_cs : Ref[Array[@yue.Container]] = Ref([])
      // 行级订阅的本代退订闭包(rebuild 前整袋退订,见 rebuild)
      let gen : Ref[Array[() -> Unit]] = Ref([])
      // 行内列单元格按 [行][列] 存(拖动列宽时逐行改样式,不重建树)
      let row_cols : Ref[Array[Array[@yue.Container]]] = Ref([])
      let data_r : Ref[Array[TableRow]] = Ref([])
      let head_h = 40.0
      // 1px 内边距让外框描边落在 padding 环里,不被行/表头背景盖住
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", width),
        ("padding", 1.0),
        ("marginBottom", 10.0),
        ("flexDirection", "column"),
      ]
      for kv in style {
        base.push(kv)
      }
      let outer = @yue.themed_container(style=base)
      handle(outer)
      // 面板底:斑马纹(fill_zebra)按「白面板上的浅灰」设计,透明挂在
      // 页面灰底(bg_page,与 fill_zebra 几乎同色)上条纹不可见
      @yue.bind_bg(outer, fn() { @yue.theme_bg_panel() })
      // 列几何(含复选框列偏移):初值=定义宽,弹性列均分剩余宽;
      // 拖动改写本数组并回写各处 cell 样式
      let body_w = width - 2.0 - (if sel is Some(_) { 36.0 } else { 0.0 })
      let col_w : Array[Double] = []
      let mut fixed = 0.0
      let mut flex_count = 0
      for col in columns {
        if col.width > 0.0 {
          fixed = fixed + col.width
        } else {
          flex_count = flex_count + 1
        }
      }
      let flex_w = if flex_count > 0 {
        ((body_w - fixed) / flex_count.to_double()).max(0.0)
      } else {
        0.0
      }
      for col in columns {
        col_w.push(if col.width > 0.0 { col.width } else { flex_w })
      }
      // 排序/列宽拖动态:表头单元格(见 head_cell)点击排序,列边界
      // (单元格左/右缘 4px,两侧都认——对准可见边界按下,事件落左列
      // 右缘或右列左缘都能起拖)按住拖列宽。sort 缺省不画箭头、点击
      // 无效。表头装饰(箭头/边界线/高亮)统一画在 head 容器上:小
      // 单元格容器的路径填充在 GTK 上不渲染(实测,见 adaptation.md),
      // 表头容器单一绘制器正常,与 table_v_t 画布同模型。
      let head_cs : Ref[Array[@yue.Container]] = Ref([])
      let resizing = Ref(-1)
      let resize_start_x = Ref(0.0)
      let resize_w0 = Ref(0.0)
      let resize_w1 = Ref(0.0)
      // 悬停的列边界(左列号,-1 无):表头画高亮线 + 光标反馈用
      let boundary_hover = Ref(-1)
      // 列 x 偏移(含复选框列 36px):表头装饰定位用,与 col_w 同步
      let col_x : Array[Double] = []
      let mut acc_x = if sel is Some(_) { 36.0 } else { 0.0 }
      for j in 0..<col_w.length() {
        col_x.push(acc_x)
        acc_x = acc_x + col_w[j]
      }

      fn sort_cur_col() -> Int {
        match sort {
          Some(s) => s.get().column
          None => -1
        }
      }

      fn sort_cur_asc() -> Bool {
        match sort {
          Some(s) => s.get().asc
          None => true
        }
      }

      outer.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(outer)
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
      })

      fn sel_has(i : Int) -> Bool {
        match sel {
          Some(s) => {
            for x in s.get() {
              if x == i {
                return true
              }
            }
            false
          }
          None => false
        }
      }

      fn toggle_sel(i : Int) -> Unit {
        match sel {
          Some(s) => {
            let out : Array[Int] = []
            let mut had = false
            for x in s.get() {
              if x == i {
                had = true
              } else {
                out.push(x)
              }
            }
            if !had {
              out.push(i)
            }
            s.set(out)
          }
          None => ()
        }
      }

      // 单元格:列宽一律读 col_w[j](弹性列的均分宽也在挂载时算入),
      // 左右各留 12px 内边距;拖动列宽后重建行即按新宽,行不重建时
      // 由 apply_col_widths 统一回写
      fn cell_view(
        content : TableCell,
        j : Int,
        fnt : @yue.Font,
        color_of : () -> String,
      ) -> @yue.Container {
        let col = columns[j]
        let base : Array[(String, &@yue.StyVal)] = [
          ("width", col_w[j]),
          ("paddingLeft", 12.0),
          ("paddingRight", 12.0),
        ]
        base.push(("flexDirection", "row"))
        base.push(("alignItems", "center"))
        let wrap = @yue.themed_container(style=base)
        match content {
          CellText(text) => {
            // 自绘单行省略:Label 无 ellipsize 能力(fork 未暴露),
            // 超宽长文本被平台排版换行穿透行高;draw 走 wrap=false +
            // ellipsis=true 单行截断(与 table_v_t 单元格同模型),
            // 拖列宽/行重建后按当前宽度重截,主题切换随重绘取新色。
            // wrap 无子节点、无高度样式,yoga 测高为 0——Windows 对
            // 0 高视图直接跳过绘制(整列文字消失),必须给出行高下限
            @yue.ViewLike::set_style(wrap, "minHeight", row_height)
            wrap.on_draw(fn(p) {
              let b = @yue.ViewLike::get_bounds(wrap)
              let at = @yue.AttributedText::new_with(text, {
                align: col.align,
                valign: @yue.Center,
                wrap: false,
                ellipsis: true,
                font: Some(fnt),
                color: Some(color_of()),
              })
              p.draw_attributed_text(at, 12.0, 0.0, b.width - 24.0, b.height)
            })
          }
          CellTag(text, t) => {
            let probe = @yue.AttributedText::new(text, wrap=false)
            probe.set_font(small_font)
            let text_w = probe.get_bounds_for(10000.0, 100.0).width
            let w = text_w + 14.0
            let tg = @yue.themed_container(style=[
              ("width", w),
              ("height", 20.0),
            ])
            tg.on_draw(fn(p) {
              p.set_fill_color(type_light_color(t))
              p.fill_rect(0.0, 0.0, w, 20.0)
              p.draw_text(
                text,
                0.0,
                0.0,
                w,
                20.0,
                align=@yue.Center,
                valign=@yue.Center,
                color=type_color(t),
              )
            })
            wrap.add_child(tg)
          }
          CellColorBox(hex, name) => {
            let sw = @yue.themed_container(style=[
              ("width", 14.0),
              ("height", 14.0),
            ])
            sw.on_draw(fn(p) {
              p.set_fill_color(hex)
              p.fill_rect(0.0, 0.0, 14.0, 14.0)
              p.set_stroke_color(@yue.theme_border())
              p.stroke_rect(0.5, 0.5, 13.0, 13.0)
            })
            wrap.add_child(sw)
            let l = @yue.Label::new(name)
            @yue.ViewLike::set_font(l, small_font)
            @yue.bind_fg(l, color_of)
            l.set_align(col.align)
            @yue.ViewLike::set_style(l, "flex", 1.0)
            @yue.ViewLike::set_style(l, "marginLeft", 6.0)
            wrap.add_child(l)
          }
          CellLines(lines) => {
            let stack = @yue.themed_container(style=[
              ("paddingTop", 6.0),
              ("paddingBottom", 6.0),
              ("flexDirection", "column"),
            ])
            for ln in lines {
              let l = @yue.Label::new(ln)
              @yue.ViewLike::set_font(l, small_font)
              @yue.bind_fg(l, fn() { @yue.theme_text_regular() })
              stack.add_child(l)
            }
            @yue.ViewLike::set_style(stack, "flex", 1.0)
            wrap.add_child(stack)
          }
        }
        wrap
      }

      // 表头:主题斑马色打底 + 底边分隔线,次级色加粗文字
      let head = @yue.themed_container(style=[
        ("height", head_h),
        ("flexDirection", "row"),
        ("alignItems", "center"),
      ])
      head.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(head)
        p.set_fill_color(@yue.theme_fill_zebra())
        p.fill_rect(0.0, 0.0, b.width, b.height)
        p.set_stroke_color(@yue.theme_border())
        p.begin_path()
        p.move_to(0.0, b.height - 0.5)
        p.line_to(b.width, b.height - 0.5)
        p.stroke()
        // 列边界线(常驻浅色,悬停/拖动变主题色):拖动位置一眼可辨
        for j in 0..<(columns.length() - 1) {
          let hot = resizing.val == j || boundary_hover.val == j
          p.set_stroke_color(
            if hot {
              @yue.theme_primary()
            } else {
              @yue.theme_border()
            },
          )
          let ex = col_x[j] + col_w[j]
          p.begin_path()
          p.move_to(ex, 6.0)
          p.line_to(ex, b.height - 6.0)
          p.stroke()
        }
        // 排序箭头:排序列实心主题色单向箭头;可排序列未排序时常驻
        // 灰色 ↕ 提示(用户看得知可点);sort 缺省全不画
        if sort is Some(_) {
          for j in 0..<columns.length() {
            if !columns[j].sortable {
              continue
            }
            let cx = col_x[j] + col_w[j] - 11.0
            if sort_cur_col() == j {
              draw_sort_triangle(p, cx, head_h / 2.0, sort_cur_asc(), true)
            } else {
              draw_sort_hint(p, cx, head_h / 2.0)
            }
          }
        }
      })
      // 表头复选框(仅 selection 启用时):全选 / 清空,部分选中画横条
      let head_cb = @yue.themed_container(style=[
        ("width", 36.0),
        ("height", head_h),
      ])
      head_cb.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(head_cb)
        let n = data_r.val.length()
        let k = match sel {
          Some(s) => s.get().length()
          None => 0
        }
        table_draw_check(
          p,
          11.0,
          (b.height - 14.0) / 2.0,
          n > 0 && k == n,
          k > 0 && k < n,
        )
      })
      @yue.View::set_cursor(head_cb, @yue.hand())
      @yue.ViewLike::on_mouse_down(head_cb, fn(e) {
        if e.button == 1 {
          match sel {
            Some(s) => {
              let n = data_r.val.length()
              if n > 0 && s.get().length() == n {
                s.set([])
              } else {
                let all : Array[Int] = []
                for i in 0..<n {
                  all.push(i)
                }
                s.set(all)
              }
            }
            None => ()
          }
          true
        } else {
          false
        }
      })
      // 表头点击三态循环:新列默认升序 → 同列翻转 → 再击取消排序
      // (column 置 -1,使用方订阅里恢复原始顺序);sort 缺省点击无效
      fn toggle_sort(j : Int) -> Unit {
        match sort {
          Some(s) => {
            let cur = s.get()
            if cur.column == j {
              if cur.asc {
                s.set({ column: j, asc: false, })
              } else {
                s.set({ column: -1, asc: true, })
              }
            } else {
              s.set({ column: j, asc: true, })
            }
          }
          None => ()
        }
      }

      // 起拖:记录起点窗口坐标与相邻两列宽,捕获鼠标
      fn begin_resize(j : Int, wx : Double) -> Unit {
        resizing.val = j
        resize_start_x.val = wx
        resize_w0.val = col_w[j]
        resize_w1.val = col_w[j + 1]
      }

      // 列宽回写:相邻两列此消彼长(总宽不变),表头 + 全部行单元格
      // 同步改样式后重排,并重算 col_x 供表头装饰定位;行本身不重建,
      // 选择/hover 状态不丢。
      // GTK 上 update_layout 只重排「调用节点及其父下的兄弟」:对根
      // 调用子树不刷新(探针实测 bounds 不变),对单个叶子调用只影响
      // 其所在行——被改样式的容器必须逐个调用(splitter 对唯一包装
      // 容器调,等价于此处的逐容器)。
      fn apply_col_widths(j : Int) -> Unit {
        @yue.ViewLike::set_style(head_cs.val[j], "width", col_w[j])
        @yue.ViewLike::set_style(head_cs.val[j + 1], "width", col_w[j + 1])
        for cells in row_cols.val {
          @yue.ViewLike::set_style(cells[j], "width", col_w[j])
          @yue.ViewLike::set_style(cells[j + 1], "width", col_w[j + 1])
        }
        let mut a = if sel is Some(_) { 36.0 } else { 0.0 }
        for k in 0..<col_w.length() {
          col_x[k] = a
          a = a + col_w[k]
        }
        @yue.ViewLike::update_layout(head_cs.val[j])
        @yue.ViewLike::update_layout(head_cs.val[j + 1])
        for cells in row_cols.val {
          @yue.ViewLike::update_layout(cells[j])
          @yue.ViewLike::update_layout(cells[j + 1])
        }
      }

      // 表头单元格:只放文字 Label(平台布局对齐,勿手动摆位)与事件;
      // 箭头 / 边界线 / 高亮一律画在 head 容器(见 head.on_draw),
      // 小单元格容器路径填充在 GTK 不渲染(实测,见 adaptation.md)。
      // 排序点击与列宽拖动共用本容器:右缘 4px 拖 (j, j+1) 边界,
      // 左缘 4px 拖 (j-1, j) 边界——对准可见边界按下,事件落左列
      // 右缘或右列左缘都能起拖(此前只认右缘,对准边界按常落到下一
      // 列左缘变成排序,拖不动)。
      fn head_cell(j : Int) -> @yue.Container {
        let col = columns[j]
        // 可排序列右侧留 22px 箭头区(标题不跳动)
        let pad_r = if col.sortable { 22.0 } else { 12.0 }
        let cell = @yue.themed_container(style=[
          ("width", col_w[j]),
          ("paddingLeft", 12.0),
          ("paddingRight", pad_r),
          ("flexDirection", "row"),
          ("alignItems", "center"),
        ])
        let l = @yue.Label::new(col.title)
        @yue.ViewLike::set_font(l, head_font)
        @yue.bind_fg(l, fn() { @yue.theme_text_secondary() })
        l.set_align(col.align)
        @yue.ViewLike::set_style(l, "flex", 1.0)
        cell.add_child(l)
        let near_edge = Ref(false)
        @yue.View::set_cursor(cell, @yue.hand())
        // 悬停:靠近任一边界给 ResizeEW 光标 + 表头画高亮线
        @yue.ViewLike::on_mouse_move(cell, fn(e) {
          if resizing.val >= 0 {
            let jr = resizing.val
            let d = e.window_x - resize_start_x.val
            let total = resize_w0.val + resize_w1.val
            let mut w0 = resize_w0.val + d
            let mut w1 = resize_w1.val - d
            if w0 < min_col_width {
              w0 = min_col_width
              w1 = total - w0
            }
            if w1 < min_col_width {
              w1 = min_col_width
              w0 = total - w1
            }
            col_w[jr] = w0
            col_w[jr + 1] = w1
            apply_col_widths(jr)
          } else {
            let b = @yue.ViewLike::get_bounds(cell)
            // 右缘 → (j, j+1) 边界;左缘 → (j-1, j) 边界;末列右缘不设
            let edge = if j + 1 < columns.length() && e.view_x >= b.width - 4.0 {
              j
            } else if j - 1 >= 0 && e.view_x <= 4.0 {
              j - 1
            } else {
              -1
            }
            if edge != boundary_hover.val {
              boundary_hover.val = edge
              @yue.ViewLike::schedule_paint(head)
            }
            let near = edge >= 0
            if near != near_edge.val {
              near_edge.val = near
              @yue.View::set_cursor(
                cell,
                @yue.Cursor::new(if near { @yue.ResizeEW } else { @yue.Hand }),
              )
            }
          }
        })
        @yue.ViewLike::on_mouse_down(cell, fn(e) {
          if e.button != 1 {
            return false
          }
          let b = @yue.ViewLike::get_bounds(cell)
          let edge = if j + 1 < columns.length() && e.view_x >= b.width - 4.0 {
            j
          } else if j - 1 >= 0 && e.view_x <= 4.0 {
            j - 1
          } else {
            -1
          }
          if edge >= 0 {
            begin_resize(edge, e.window_x)
            @yue.ViewLike::set_capture(cell)
            true
          } else {
            if col.sortable {
              toggle_sort(j)
              @yue.ViewLike::schedule_paint(head)
            }
            false
          }
        })
        @yue.ViewLike::on_mouse_up(cell, fn(_e) {
          if resizing.val >= 0 {
            resizing.val = -1
            @yue.ViewLike::release_capture(cell)
            @yue.ViewLike::schedule_paint(head)
            true
          } else {
            false
          }
        })
        // 光标离开边界区:复位光标与高亮
        @yue.ViewLike::on_mouse_leave(cell, fn(_e) {
          if boundary_hover.val != -1 {
            boundary_hover.val = -1
            @yue.ViewLike::schedule_paint(head)
          }
          if near_edge.val {
            near_edge.val = false
            @yue.View::set_cursor(cell, @yue.hand())
          }
        })
        cell
      }

      match sel {
        Some(_) => head.add_child(head_cb)
        None => ()
      }
      for j in 0..<columns.length() {
        let hc = head_cell(j)
        head_cs.val.push(hc)
        head.add_child(hc)
      }
      let body = @yue.themed_container(style=[("flexDirection", "column")])

      fn refresh_row(i : Int) -> Unit {
        let cs = row_cs.val
        if i >= 0 && i < cs.length() {
          @yue.ViewLike::schedule_paint(cs[i])
        }
      }

      // 鼠标离开整个表格(移去表头 / 表格外)时清悬停:兜底行级 leave
      // 丢失导致的 hover 底色永久滞留
      @yue.ViewLike::on_mouse_leave(outer, fn(_e) {
        let prev = hover_i.val
        if prev >= 0 {
          hover_i.val = -1
          refresh_row(prev)
        }
      })

      fn rebuild(data : Array[TableRow]) -> Unit {
        // 旧代订阅整袋退订:行与单元格挂载时登记的主题订阅随旧行视图
        // 一起退场,不随每次数据刷新累积死订阅
        @yue.sub_bag_discard(gen.val)
        for v in row_cs.val {
          ignore(body.remove_child_view(@yue.ViewLike::view(v)))
        }
        row_cs.val = []
        row_cols.val = []
        data_r.val = data
        selected_i.val = -1
        hover_i.val = -1
        match sel {
          Some(s) => s.set([])
          None => ()
        }
        @yue.sub_bag_begin()
        for i in 0..<data.length() {
          let r = data[i]
          let idx = i
          // minHeight:普通行 = row_height,含多行文本时自动撑高
          let row = @yue.themed_container(style=[
            ("minHeight", row_height),
            ("flexDirection", "row"),
            ("alignItems", "center"),
          ])
          row.on_draw(fn(p) {
            let bg = table_row_bg(idx, sel_has(idx), hover_i.val == idx)
            if bg != "" {
              let b = @yue.ViewLike::get_bounds(row)
              p.set_fill_color(bg)
              p.fill_rect(0.0, 0.0, b.width, b.height)
            }
          })
          match sel {
            Some(_) => {
              let cb = @yue.themed_container(style=[
                ("width", 36.0),
                ("alignSelf", "stretch"),
              ])
              cb.on_draw(fn(p) {
                let b = @yue.ViewLike::get_bounds(cb)
                table_draw_check(
                  p,
                  11.0,
                  (b.height - 14.0) / 2.0,
                  sel_has(idx),
                  false,
                )
              })
              row.add_child(cb)
            }
            None => ()
          }
          let cells : Array[@yue.Container] = []
          for j in 0..<columns.length() {
            let content = if j < r.cells.length() {
              r.cells[j]
            } else {
              CellText("")
            }
            let cv = cell_view(content, j, font, fn() {
              @yue.theme_text_regular()
            })
            cells.push(cv)
            row.add_child(cv)
          }
          row_cols.val.push(cells)
          @yue.ViewLike::on_mouse_enter(row, fn(_e) {
            // 旧行的 leave 可能迟到/丢失(快速移动、跨子控件边界事件
            // 乱序),enter 里一并重绘旧行,滞留的 hover 底色即时清掉
            let prev = hover_i.val
            hover_i.val = idx
            if prev != idx {
              refresh_row(prev)
            }
            refresh_row(idx)
          })
          @yue.ViewLike::on_mouse_leave(row, fn(_e) {
            // 仅当当前悬停仍是本行才清:乱序 leave(到达晚于新行 enter)
            // 不得清掉新行的 hover
            if hover_i.val == idx {
              hover_i.val = -1
              refresh_row(idx)
            }
          })
          @yue.View::set_cursor(row, @yue.hand())
          @yue.ViewLike::on_mouse_down(row, fn(e) {
            if e.button == 1 {
              match sel {
                Some(_) => toggle_sel(idx)
                None => {
                  let prev = selected_i.val
                  selected_i.val = idx
                  refresh_row(prev)
                  refresh_row(idx)
                }
              }
              on_row_click(idx, r)
              true
            } else {
              false
            }
          })
          body.add_child(row)
          row_cs.val.push(row)
        }
        gen.val = @yue.sub_bag_end()
        @yue.ViewLike::schedule_paint(head_cb)
      }

      rebuild(rows.get())
      rows.subscribe(rebuild)
      match sel {
        Some(s) =>
          s.subscribe(fn(_v) {
            for c in row_cs.val {
              @yue.ViewLike::schedule_paint(c)
            }
            @yue.ViewLike::schedule_paint(head_cb)
          })
        None => ()
      }
      // 排序状态变化:表头箭头重绘(数据排序由使用方订阅 Store 完成)
      match sort {
        Some(s) => s.subscribe(fn(_v) { @yue.ViewLike::schedule_paint(head) })
        None => ()
      }
      outer.add_child(head)
      outer.add_child(body)
      @yue.attach(parent, @yue.ViewLike::view(outer))
      @yue.ViewLike::view(outer)
    },
  }
}

///|
/// 虚拟滚动表格(table_t 的 L3 万行级形态):整面 canvas 自绘、只画可见行,
/// 自管滚动——滚轮(Linux 经 shim scroll-event)/拖拽滚动条/键盘,不受原生
/// 滚动容器的内容高度上限约束(X11 子窗口高度 65535,万行内容放不进
/// GtkViewport)。单元格画法与 table_t 一致(CellLines 在行高内最多画
/// 两行);selection 语义同 table_t(复选框列 + 表头全选)。
/// 表头:sort(Store[TableSort])提供后排序列显示升降箭头,点击可排序列
/// 切换「新列升序 / 同列升降序」;列边界(表头,±3px 命中)按住拖动调整
/// 列宽,相邻两列此消彼长(最小 min_col_width,末列边界不设把手)。
pub fn table_v_t(
  columns : Array[TableColumn],
  rows : @yue.Store[Array[TableRow]],
  width? : Double = 560.0,
  height? : Double = 360.0,
  row_height? : Double = 32.0,
  selection? : @yue.Store[Array[Int]],
  sort? : @yue.Store[TableSort],
  on_row_click? : (Int, TableRow) -> Unit = fn(_i, _r) {  },
  fill? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let small_font = @yue.Font::new("Sans", 12.0)
      let sel = selection
      let data_r : Ref[Array[TableRow]] = Ref([])
      let selected_i = Ref(-1)
      let hover_i = Ref(-1)
      let offset = Ref(0.0)
      let dragging = Ref(false)
      // 排序/列宽拖动态:resizing 为边界左列号,-1 无;head_hover 为
      // 悬停表头列号(-1 无);near_edge 光标是否已是 ResizeEW;
      // boundary_hover 为悬停列边界(左列号,-1 无),表头画高亮线
      let head_hover = Ref(-1)
      let near_edge = Ref(false)
      let boundary_hover = Ref(-1)
      let resizing = Ref(-1)
      let resize_start_x = Ref(0.0)
      let resize_w0 = Ref(0.0)
      let resize_w1 = Ref(0.0)
      let head_h = 40.0
      let bar_w = 10.0
      // 表体宽随实际视口宽(fill 模式跟随窗口伸缩),绘制与命中共用
      let body_w = Ref(width - bar_w)
      let vis_h = height - head_h
      // 复选框列占 36px(selection 启用时),列几何整体右移
      let col_x0 = if sel is Some(_) { 36.0 } else { 0.0 }
      // 列几何:固定宽直接用,弹性列均分剩余宽度;col_x 含复选框列偏移
      let mut fixed = 0.0
      let mut flex_count = 0
      for col in columns {
        if col.width > 0.0 {
          fixed = fixed + col.width
        } else {
          flex_count = flex_count + 1
        }
      }
      let flex_w = if flex_count > 0 {
        ((body_w.val - col_x0 - fixed) / flex_count.to_double()).max(0.0)
      } else {
        0.0
      }
      let col_x : Array[Double] = []
      let col_w : Array[Double] = []
      // 手动拖过宽度的列(含弹性列):此后退出弹性均分,按拖定的宽走,
      // 窗口伸缩也不再摊薄——否则每次 on_draw 的 relayout_body 会把
      // 弹性列重置回均分宽,拖动结果被当场抹掉(拖了没效果)
      let manual : Array[Bool] = []
      for _col in columns {
        manual.push(false)
      }
      let mut acc = col_x0
      for col in columns {
        let w = if col.width > 0.0 { col.width } else { flex_w }
        col_x.push(acc)
        col_w.push(w)
        acc = acc + w
      }

      fn relayout_cols() -> Unit {
        let mut a = col_x0
        for j in 0..<col_w.length() {
          col_x[j] = a
          a = a + col_w[j]
        }
      }

      // 列几何随实际宽度重排:固定列保留(可能被拖宽改过的)宽度,弹性
      // 列分摊剩余宽度。拖列宽两列此消彼长守恒,与弹性列重排不冲突。
      // 手动拖过的列(manual)视同固定列:计入 fixed_w、不参与均分,
      // 否则每次绘制都把弹性列重置回均分宽、拖动结果被抹掉。
      fn relayout_body(bw : Double) -> Unit {
        body_w.val = bw - bar_w
        if flex_count > 0 {
          let mut fixed_w = col_x0
          let mut flex_left = 0
          for j in 0..<col_w.length() {
            if columns[j].width > 0.0 || manual[j] {
              fixed_w = fixed_w + col_w[j]
            } else {
              flex_left = flex_left + 1
            }
          }
          let fw = if flex_left > 0 {
            ((body_w.val - fixed_w) / flex_left.to_double()).max(0.0)
          } else {
            0.0
          }
          for j in 0..<col_w.length() {
            if columns[j].width <= 0.0 && !manual[j] {
              col_w[j] = fw
            }
          }
        }
        relayout_cols()
      }

      // 列边界命中:x(画布坐标)距某条数据列右边界 3px 内返回左列号
      fn boundary_at(vx : Double) -> Int {
        for j in 0..<(col_w.length() - 1) {
          let edge = col_x[j] + col_w[j]
          if vx >= edge - 3.0 && vx <= edge + 3.0 {
            return j
          }
        }
        -1
      }

      // 命中列号:数据列(不含复选框列),越界 -1
      fn col_at(vx : Double) -> Int {
        for j in 0..<col_w.length() {
          if vx >= col_x[j] && vx < col_x[j] + col_w[j] {
            return j
          }
        }
        -1
      }

      fn sort_cur_col() -> Int {
        match sort {
          Some(s) => s.get().column
          None => -1
        }
      }

      fn sort_cur_asc() -> Bool {
        match sort {
          Some(s) => s.get().asc
          None => true
        }
      }

      // 表头点击三态循环:新列默认升序 → 同列翻转 → 再击取消排序
      // (column 置 -1,使用方订阅里恢复原始顺序);sort 缺省点击无效
      fn toggle_sort(j : Int) -> Unit {
        match sort {
          Some(s) => {
            let cur = s.get()
            if cur.column == j {
              if cur.asc {
                s.set({ column: j, asc: false, })
              } else {
                s.set({ column: -1, asc: true, })
              }
            } else {
              s.set({ column: j, asc: true, })
            }
          }
          None => ()
        }
      }

      let size_style : Array[(String, &@yue.StyVal)] = if fill {
        [("height", height), ("marginBottom", 10.0)]
      } else {
        [("width", width), ("height", height), ("marginBottom", 10.0)]
      }
      for kv in style {
        size_style.push(kv)
      }
      let cv = @yue.themed_container(style=size_style)
      handle(cv)
      // 面板底:斑马纹按「白面板上的浅灰」设计,透明挂在页面灰底上
      // 条纹不可见(与 table_t 同理)
      @yue.bind_bg(cv, fn() { @yue.theme_bg_panel() })

      fn sel_has(i : Int) -> Bool {
        match sel {
          Some(s) => {
            for x in s.get() {
              if x == i {
                return true
              }
            }
            false
          }
          None => false
        }
      }

      fn toggle_sel(i : Int) -> Unit {
        match sel {
          Some(s) => {
            let out : Array[Int] = []
            let mut had = false
            for x in s.get() {
              if x == i {
                had = true
              } else {
                out.push(x)
              }
            }
            if !had {
              out.push(i)
            }
            s.set(out)
          }
          None => ()
        }
      }

      fn toggle_all() -> Unit {
        match sel {
          Some(s) => {
            let n = data_r.val.length()
            if n > 0 && s.get().length() == n {
              s.set([])
            } else {
              let all : Array[Int] = []
              for i in 0..<n {
                all.push(i)
              }
              s.set(all)
            }
          }
          None => ()
        }
      }

      fn total_h() -> Double {
        head_h + data_r.val.length().to_double() * row_height
      }

      fn max_offset() -> Double {
        (total_h() - vis_h).max(0.0)
      }

      fn clamp_offset() -> Unit {
        let m = max_offset()
        if offset.val > m {
          offset.val = m
        }
        if offset.val < 0.0 {
          offset.val = 0.0
        }
      }

      // 文本按列对齐交给平台布局引擎(align 参数):Windows 的测宽与绘制
      // 格式不一致,手动按测量宽摆位会偏左(见 adaptation.md)。水平方向
      // 两侧统一留 12px。单行 + 超宽省略:默认换行会让长文本穿透定高
      // 行界(命令行动辄上百字符),排版截断由平台完成,不逐格测宽。
      fn draw_align_text(
        p : @yue.Painter,
        text : String,
        align : @yue.TextAlign,
        x : Double,
        w : Double,
        y : Double,
        h : Double,
        color : String,
      ) -> Unit {
        if text == "" {
          return
        }
        p.draw_text(
          text,
          x + 12.0,
          y,
          w - 24.0,
          h,
          align~,
          valign=@yue.Center,
          color~,
          wrap=false,
          ellipsis=true,
        )
      }

      cv.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(cv)
        relayout_body(b.width)
        let data = data_r.val
        let n = data.length()
        // 表头
        p.set_fill_color(@yue.theme_fill_zebra())
        p.fill_rect(0.0, 0.0, b.width, head_h)
        p.set_stroke_color(@yue.theme_border())
        p.begin_path()
        p.move_to(0.0, head_h - 0.5)
        p.line_to(b.width, head_h - 0.5)
        p.stroke()
        match sel {
          Some(s) => {
            let k = s.get().length()
            table_draw_check(
              p,
              11.0,
              (head_h - 14.0) / 2.0,
              n > 0 && k == n,
              k > 0 && k < n,
            )
          }
          None => ()
        }
        // 列标题与箭头(边界线在行之后画,避免被斑马纹盖住)
        for j in 0..<columns.length() {
          // 可排序列右侧留 14px 箭头区(标题右界同步内收,排序切换时
          // 标题不跳动;数据行无箭头保持原样)
          let w_eff = col_w[j] - (if columns[j].sortable { 14.0 } else { 0.0 })
          draw_align_text(
            p,
            columns[j].title,
            columns[j].align,
            col_x[j],
            w_eff,
            0.0,
            head_h,
            @yue.theme_text_secondary(),
          )
          // 排序箭头:排列表实心主题色单向;可排序列未排序时常驻灰色 ↕
          if sort is Some(_) && columns[j].sortable {
            let cx = col_x[j] + col_w[j] - 14.0
            if sort_cur_col() == j {
              draw_sort_triangle(p, cx, head_h / 2.0, sort_cur_asc(), true)
            } else {
              draw_sort_hint(p, cx, head_h / 2.0)
            }
          }
        }
        // 可见行窗口(裁剪到表头以下,行滚动经过时不遮盖表头)
        p.save()
        p.clip_rect(0.0, head_h, b.width, vis_h)
        let first = (offset.val / row_height).to_int()
        let mut last = ((offset.val + vis_h) / row_height).ceil().to_int() + 1
        if last > n {
          last = n
        }
        for i in first..<last {
          let row_y = head_h + i.to_double() * row_height - offset.val
          let bg = table_row_bg(i, sel_has(i), hover_i.val == i)
          if bg != "" {
            p.set_fill_color(bg)
            p.fill_rect(0.0, row_y, body_w.val, row_height)
          }
          if sel is Some(_) {
            table_draw_check(
              p,
              11.0,
              row_y + (row_height - 14.0) / 2.0,
              sel_has(i),
              false,
            )
          }
          let r = data[i]
          for j in 0..<columns.length() {
            let content = if j < r.cells.length() {
              r.cells[j]
            } else {
              CellText("")
            }
            let x = col_x[j]
            let w = col_w[j]
            match content {
              CellText(text) =>
                draw_align_text(
                  p,
                  text,
                  columns[j].align,
                  x,
                  w,
                  row_y,
                  row_height,
                  @yue.theme_text_regular(),
                )
              CellTag(text, t) => {
                let probe = @yue.AttributedText::new(text, wrap=false)
                probe.set_font(small_font)
                let tw = probe.get_bounds_for(10000.0, 100.0).width
                let tag_w = tw + 14.0
                let ty = row_y + (row_height - 20.0) / 2.0
                p.set_fill_color(type_light_color(t))
                p.fill_rect(x + 12.0, ty, tag_w, 20.0)
                p.draw_text(
                  text,
                  x + 12.0 + (tag_w - tw) / 2.0,
                  ty,
                  tag_w,
                  20.0,
                  valign=@yue.Center,
                  color=type_color(t),
                  wrap=false,
                )
              }
              CellColorBox(hex, name) => {
                let sy = row_y + (row_height - 14.0) / 2.0
                p.set_fill_color(hex)
                p.fill_rect(x + 12.0, sy, 14.0, 14.0)
                p.set_stroke_color(@yue.theme_border())
                p.stroke_rect(x + 12.5, sy + 0.5, 13.0, 13.0)
                p.draw_text(
                  name,
                  x + 12.0 + 20.0,
                  row_y,
                  w - 32.0,
                  row_height,
                  valign=@yue.Center,
                  color=@yue.theme_text_regular(),
                  wrap=false,
                )
              }
              CellLines(lines) => {
                // 行高内最多画两行,超出截断(虚拟滚动行高固定);
                // 单行不换行,超宽平台省略
                let mut ly = row_y + (row_height - 28.0) / 2.0
                let limit = row_y + row_height - 2.0
                for ln in lines {
                  if ly > limit - 12.0 {
                    break
                  }
                  p.draw_text(
                    ln,
                    x + 12.0,
                    ly,
                    w,
                    14.0,
                    color=@yue.theme_text_regular(),
                    wrap=false,
                    ellipsis=true,
                  )
                  ly = ly + 14.0
                }
              }
            }
          }
        }
        p.restore()
        // 滚动条(细 thumb,可拖拽)
        let th = total_h()
        if th > vis_h {
          let thumb_h = (vis_h * vis_h / th).max(30.0)
          let t = if max_offset() > 0.0 {
            offset.val / max_offset()
          } else {
            0.0
          }
          let thumb_y = head_h + (vis_h - thumb_h) * t
          p.set_fill_color(@yue.theme_border())
          p.fill_rect(b.width - bar_w + 2.0, thumb_y, bar_w - 4.0, thumb_h)
        }
        // 列边界线(常驻浅色,悬停/拖动变主题色):拖动位置一眼可辨。
        // 画在行之后——先前画在行之前,偶数行斑马纹 fill_rect 把线盖住,
        // 体感上「列分割线时有时无」
        for j in 0..<(columns.length() - 1) {
          let hot = resizing.val == j || boundary_hover.val == j
          p.set_stroke_color(
            if hot {
              @yue.theme_primary()
            } else {
              @yue.theme_border()
            },
          )
          let ex = col_x[j] + col_w[j]
          p.begin_path()
          p.move_to(ex, 6.0)
          p.line_to(ex, head_h + vis_h - 6.0)
          p.stroke()
        }
        // 列宽拖动中的边界高亮线(表头到底,主题色 1px)
        if resizing.val >= 0 {
          let edge = col_x[resizing.val] + col_w[resizing.val]
          p.set_stroke_color(@yue.theme_primary())
          p.begin_path()
          p.move_to(edge, head_h)
          p.line_to(edge, b.height)
          p.stroke()
        }
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
      })

      fn thumb_geo() -> (Double, Double) {
        let th = total_h()
        let thumb_h = (vis_h * vis_h / th).max(30.0)
        (thumb_h, th)
      }

      fn scroll_to_thumb(evy : Double) -> Unit {
        let (thumb_h, _) = thumb_geo()
        let t = ((evy - head_h - thumb_h / 2.0) / (vis_h - thumb_h))
          .max(0.0)
          .min(1.0)
        offset.val = t * max_offset()
        @yue.ViewLike::schedule_paint(cv)
      }

      @yue.View::set_cursor(cv, @yue.hand())
      @yue.ViewLike::on_mouse_down(cv, fn(e) {
        if e.button != 1 {
          return false
        }
        let n = data_r.val.length()
        if e.view_x >= body_w.val && max_offset() > 0.0 {
          scroll_to_thumb(e.view_y)
          dragging.val = true
          @yue.ViewLike::set_capture(cv)
          return true
        }
        if e.view_y < head_h {
          // 列边界把手(表头 ±3px):按住拖列宽,不与排序点击冲突
          if e.view_x >= col_x0 {
            let jb = boundary_at(e.view_x)
            if jb >= 0 {
              resizing.val = jb
              resize_start_x.val = e.window_x
              resize_w0.val = col_w[jb]
              resize_w1.val = col_w[jb + 1]
              // 拖过即转固定:退出弹性均分,后续绘制/窗口伸缩保留拖定宽
              manual[jb] = true
              manual[jb + 1] = true
              @yue.ViewLike::set_capture(cv)
              @yue.ViewLike::schedule_paint(cv)
              return true
            }
          }
          if e.view_x < col_x0 {
            match sel {
              Some(_) => toggle_all()
              None => ()
            }
          } else {
            // 表头点击(把手外):可排序列切换升降序,组件内更新 sort
            let j = col_at(e.view_x)
            if j >= 0 && columns[j].sortable {
              toggle_sort(j)
            }
          }
          @yue.ViewLike::schedule_paint(cv)
          return true
        }
        let idx = ((e.view_y - head_h + offset.val) / row_height).to_int()
        if idx >= 0 && idx < n {
          match sel {
            Some(_) => toggle_sel(idx)
            None => selected_i.val = idx
          }
          on_row_click(idx, data_r.val[idx])
        }
        @yue.ViewLike::schedule_paint(cv)
        true
      })
      @yue.ViewLike::on_mouse_move(cv, fn(e) {
        if dragging.val {
          scroll_to_thumb(e.view_y)
          return
        }
        if resizing.val >= 0 {
          // 列宽拖动:相邻两列此消彼长,总宽不变,钳制最小宽
          let j = resizing.val
          let d = e.window_x - resize_start_x.val
          let total = resize_w0.val + resize_w1.val
          let mut w0 = resize_w0.val + d
          let mut w1 = resize_w1.val - d
          if w0 < min_col_width {
            w0 = min_col_width
            w1 = total - w0
          }
          if w1 < min_col_width {
            w1 = min_col_width
            w0 = total - w1
          }
          col_w[j] = w0
          col_w[j + 1] = w1
          relayout_cols()
          @yue.ViewLike::schedule_paint(cv)
          return
        }
        // 表头区:悬停列记录 + 边界把手光标 + 边界高亮线
        if e.view_y < head_h && e.view_x >= col_x0 {
          let bh = boundary_at(e.view_x)
          let near = bh >= 0
          if near != near_edge.val {
            near_edge.val = near
            @yue.View::set_cursor(
              cv,
              @yue.Cursor::new(if near { @yue.ResizeEW } else { @yue.Hand }),
            )
          }
          if bh != boundary_hover.val {
            boundary_hover.val = bh
            @yue.ViewLike::schedule_paint(cv)
          }
          let hc = col_at(e.view_x)
          if hc != head_hover.val {
            head_hover.val = hc
            @yue.ViewLike::schedule_paint(cv)
          }
        } else {
          if near_edge.val {
            near_edge.val = false
            @yue.View::set_cursor(cv, @yue.hand())
          }
          if boundary_hover.val != -1 {
            boundary_hover.val = -1
            @yue.ViewLike::schedule_paint(cv)
          }
          if head_hover.val != -1 {
            head_hover.val = -1
            @yue.ViewLike::schedule_paint(cv)
          }
        }
        let n = data_r.val.length()
        let idx = ((e.view_y - head_h + offset.val) / row_height).to_int()
        let inside = e.view_x < body_w.val && e.view_y >= head_h
        let new_hover = if inside && idx >= 0 && idx < n { idx } else { -1 }
        if new_hover != hover_i.val {
          hover_i.val = new_hover
          @yue.ViewLike::schedule_paint(cv)
        }
      })
      @yue.ViewLike::on_mouse_up(cv, fn(_e) {
        if dragging.val {
          dragging.val = false
          @yue.ViewLike::release_capture(cv)
          true
        } else if resizing.val >= 0 {
          resizing.val = -1
          @yue.ViewLike::release_capture(cv)
          true
        } else {
          false
        }
      })
      @yue.ViewLike::on_mouse_leave(cv, fn(_e) {
        if hover_i.val != -1 {
          hover_i.val = -1
          @yue.ViewLike::schedule_paint(cv)
        }
        if head_hover.val != -1 {
          head_hover.val = -1
          @yue.ViewLike::schedule_paint(cv)
        }
        if boundary_hover.val != -1 {
          boundary_hover.val = -1
          @yue.ViewLike::schedule_paint(cv)
        }
        if near_edge.val {
          near_edge.val = false
          @yue.View::set_cursor(cv, @yue.hand())
        }
      })
      @yue.ViewLike::on_wheel(cv, fn(delta) {
        offset.val = offset.val + delta * 60.0
        clamp_offset()
        @yue.ViewLike::schedule_paint(cv)
      })
      @yue.ViewLike::set_focusable(cv, true)
      @yue.ViewLike::on_key_down(cv, fn(e) {
        let page = (vis_h - row_height).max(row_height)
        if e.code == @yue.VKEY_DOWN {
          offset.val = offset.val + row_height
        } else if e.code == @yue.VKEY_UP {
          offset.val = offset.val - row_height
        } else if e.code == @yue.VKEY_NEXT {
          offset.val = offset.val + page
        } else if e.code == @yue.VKEY_PRIOR {
          offset.val = offset.val - page
        } else if e.code == @yue.VKEY_END {
          offset.val = max_offset()
        } else if e.code == @yue.VKEY_HOME {
          offset.val = 0.0
        } else {
          return false
        }
        clamp_offset()
        @yue.ViewLike::schedule_paint(cv)
        true
      })

      fn load(data : Array[TableRow]) -> Unit {
        data_r.val = data
        selected_i.val = -1
        hover_i.val = -1
        offset.val = 0.0
        match sel {
          Some(s) => s.set([])
          None => ()
        }
        @yue.ViewLike::schedule_paint(cv)
      }

      load(rows.get())
      rows.subscribe(load)
      match sel {
        Some(s) => s.subscribe(fn(_v) { @yue.ViewLike::schedule_paint(cv) })
        None => ()
      }
      // 排序状态变化:表头箭头重绘(数据排序由使用方订阅 Store 完成)
      match sort {
        Some(s) => s.subscribe(fn(_v) { @yue.ViewLike::schedule_paint(cv) })
        None => ()
      }
      @yue.attach(parent, @yue.ViewLike::view(cv))
      @yue.ViewLike::view(cv)
    },
  }
}
