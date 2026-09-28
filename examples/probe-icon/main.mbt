// 图标画法探针:网格铺开 Yh 生成图标(iconfont 选型子集),配合截图自看迭代
// 图标清单由 scripts/gen_icons.py 选型生成,此处按同序铺 9 列
let icons : Array[@yue.IconKind] = [
  @yue.IconKind::YhTreeStructure, @yue.IconKind::YhTreeTable, @yue.IconKind::YhTable, @yue.IconKind::YhTab,
  @yue.IconKind::YhTextField, @yue.IconKind::YhTextarea, @yue.IconKind::YhNumberField, @yue.IconKind::YhSelectField,
  @yue.IconKind::YhEditTable, @yue.IconKind::YhScript, @yue.IconKind::YhFunction, @yue.IconKind::YhParams,
  @yue.IconKind::YhQueryFilter, @yue.IconKind::YhFontSize, @yue.IconKind::YhFontColor, @yue.IconKind::YhLineHeight,
  @yue.IconKind::YhStrikethrough, @yue.IconKind::YhIndent, @yue.IconKind::YhOutdent, @yue.IconKind::YhColumnHeight,
  @yue.IconKind::YhColumnWidth, @yue.IconKind::YhVAlignBottom, @yue.IconKind::YhVAlignMiddle, @yue.IconKind::YhVAlignTop,
  @yue.IconKind::YhBorderOuter, @yue.IconKind::YhBorderTop, @yue.IconKind::YhBorderBottom, @yue.IconKind::YhBorderLeft,
  @yue.IconKind::YhBorderRight, @yue.IconKind::YhBorderInner, @yue.IconKind::YhBorderVertical, @yue.IconKind::YhBorderHorizontal,
  @yue.IconKind::YhAppstore, @yue.IconKind::YhFullscreen, @yue.IconKind::YhFullscreenExit, @yue.IconKind::YhToTop,
  @yue.IconKind::YhSwap, @yue.IconKind::YhRollback, @yue.IconKind::YhEnter, @yue.IconKind::YhDrag,
  @yue.IconKind::YhMenuFold, @yue.IconKind::YhMenuUnfold, @yue.IconKind::YhSortDesc, @yue.IconKind::YhSortAsc,
  @yue.IconKind::YhFile, @yue.IconKind::YhFilePdf, @yue.IconKind::YhFileWord, @yue.IconKind::YhFileExcel,
  @yue.IconKind::YhFilePpt, @yue.IconKind::YhFileZip, @yue.IconKind::YhFileMarkdown, @yue.IconKind::YhFileSearch,
  @yue.IconKind::YhSnippets, @yue.IconKind::YhCloudServer, @yue.IconKind::YhCloudSync, @yue.IconKind::YhApi,
  @yue.IconKind::YhGateway, @yue.IconKind::YhQrcode, @yue.IconKind::YhBarcode, @yue.IconKind::YhScan,
  @yue.IconKind::YhLaptop, @yue.IconKind::YhTablet, @yue.IconKind::YhUsb, @yue.IconKind::YhVideo,
  @yue.IconKind::YhAreaChart, @yue.IconKind::YhLineChart, @yue.IconKind::YhRadarChart, @yue.IconKind::YhBoxplot,
  @yue.IconKind::YhDashboard, @yue.IconKind::YhIdcard, @yue.IconKind::YhContacts, @yue.IconKind::YhStop,
  @yue.IconKind::YhExport, @yue.IconKind::YhImport, @yue.IconKind::YhSmile, @yue.IconKind::YhFrown,
  @yue.IconKind::YhPaperclip, @yue.IconKind::YhCrop, @yue.IconKind::YhMagicStick, @yue.IconKind::YhWallet,
  @yue.IconKind::YhBooks,
]

fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_content_size(540.0, 540.0)
  window.set_title("icon-probe")
  window.center()
  let box_ = @yue.Container::new()
  box_.set_style("width", 540.0)
  box_.set_style("height", 540.0)
  box_.on_draw(fn(p) {
    for i, k in icons {
      let col = i % 9
      let row = i / 9
      let x = 30.0 + col.to_double() * 60.0
      let y = 30.0 + row.to_double() * 60.0
      @yue.draw_icon(p, k, x, y, 22.0, "#333333")
    }
  })
  window.set_content(box_)
  window.activate()
  println("probe-icon ready")
  @yue.run()
}
