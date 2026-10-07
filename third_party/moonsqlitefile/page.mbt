///|
/// 四种 SQLite B-tree 页面类型；不用于 overflow、freelist、Ptrmap 或 lock-byte 页面。
pub(all) enum PageType {
  TableLeaf
  TableInterior
  IndexLeaf
  IndexInterior
} derive(Debug, Eq)

///|
pub extend PageType with @debug.Debug::{to_repr}

///|
pub extend PageType with Eq::{equal, not_equal}

///|
/// 已校验的 B-tree 页元数据。number 从 1 开始，所有偏移均相对页起始；right_child 只存在于内部页，cell_offsets 按逻辑 cell 顺序排列。
pub(all) struct Page {
  number : Int
  kind : PageType
  first_freeblock : Int
  cell_count : Int
  content_start : Int
  fragmented_bytes : Int
  right_child : Int?
  cell_offsets : Array[Int]
} derive(Debug)

///|
pub extend Page with @debug.Debug::{to_repr}

///|
/// 读取并验证指定 B-tree 页的完整 cell/freeblock 空间布局；不是通用 overflow/freelist 解码入口，不检查 record 或 overflow 内容。
pub fn Database::page(self : Database, number : Int) -> Page raise SqliteError {
  self.page_from_bytes(number, self.read_page(number))
}

///|
fn Database::page_from_bytes(
  self : Database,
  number : Int,
  bytes : Bytes,
  trace? : InspectionTrace? = None,
) -> Page raise SqliteError {
  if trace is Some(context) {
    context.at(PageLayout, Some(number))
  }
  self.parse_btree_page(number, bytes).0 catch {
    PageInvalid(diagnostic) => {
      if trace is Some(context) {
        context.at(
          PageLayout,
          Some(number),
          byte_offset=diagnostic.byte_offset,
          cell_index=diagnostic.cell_index,
        )
        context.page_diagnostic = Some(diagnostic)
      }
      raise diagnostic.error
    }
  }
}

///|
fn Database::parse_btree_page(
  self : Database,
  number : Int,
  bytes : Bytes,
) -> (Page, PageStatistics) raise PageValidationError {
  let offset = if number == 1 { 100 } else { 0 }
  let kind = match bytes[offset].to_int() {
    13 => TableLeaf
    5 => TableInterior
    10 => IndexLeaf
    2 => IndexInterior
    other =>
      raise page_invalid(
        number,
        PageTypeTag,
        offset,
        "页 \{number} 不是 B-tree 页：type=\{other}",
      )
  }
  let interior = kind == TableInterior || kind == IndexInterior
  let header_size = if interior { 12 } else { 8 }
  let cell_count = page_u16(bytes, number, offset + 3, PageHeader)
  let pointers_end = offset + header_size + cell_count * 2
  let usable = self.header.usable_size
  if pointers_end > usable {
    raise page_invalid(
      number,
      PageHeader,
      offset + 3,
      "cell pointer array 越界",
    )
  }
  let raw_start = page_u16(bytes, number, offset + 5, PageHeader)
  let content_start = if raw_start == 0 { 65536 } else { raw_start }
  if content_start < pointers_end || content_start > usable {
    raise page_invalid(
      number,
      PageHeader,
      offset + 5,
      "无效 cell content 起点",
    )
  }
  let fragmented_bytes = bytes[offset + 7].to_int()
  if fragmented_bytes > 60 {
    raise page_invalid(
      number,
      FragmentCount,
      offset + 7,
      "碎片字节数超过 60",
    )
  }
  let first_freeblock = page_u16(bytes, number, offset + 1, Freeblock)
  if first_freeblock != 0 &&
    (first_freeblock < content_start || first_freeblock > usable - 4) {
    raise page_invalid(number, Freeblock, offset + 1, "freeblock 指针越界")
  }
  let seen : Map[Int, Bool] = Map([])
  let cell_offsets : Array[Int] = []
  for i = 0; i < cell_count; i = i + 1 {
    let pointer = page_u16(
      bytes,
      number,
      offset + header_size + i * 2,
      CellPointer,
      cell_index=Some(i),
    )
    if pointer < content_start || pointer >= usable || seen.contains(pointer) {
      raise page_invalid(
        number,
        CellPointer,
        offset + header_size + i * 2,
        "cell 指针越界或重复",
        cell_index=Some(i),
      )
    }
    seen[pointer] = true
    cell_offsets.push(pointer)
  }
  // 按完整字节区间记录 cell 与 freeblock，避免仅检查起点而遗漏内容重叠。
  let spans : Array[(Int, Int, Int?)] = []
  let mut cell_bytes = 0
  let mut payload_bytes = 0UL
  let mut local_payload_bytes = 0UL
  let mut max_payload_bytes = 0
  let mut overflow_cells = 0
  for i = 0; i < cell_offsets.length(); i = i + 1 {
    let pointer = cell_offsets[i]
    let (end, payload, local_bytes) = page_cell_layout(
      bytes, pointer, kind, usable,
    ) catch {
      error =>
        raise PageInvalid({
          code: CellFormat,
          page_number: number,
          byte_offset: Some(pointer),
          cell_index: Some(i),
          error,
        })
    }
    spans.push((pointer, end, Some(i)))
    cell_bytes = cell_bytes + end - pointer
    payload_bytes = payload_bytes + payload.to_uint64()
    local_payload_bytes = local_payload_bytes + local_bytes.to_uint64()
    if payload > max_payload_bytes {
      max_payload_bytes = payload
    }
    if payload > local_bytes {
      overflow_cells = overflow_cells + 1
    }
  }
  let mut freeblock_bytes = 0
  // 空闲块链仍须按偏移递增；空间覆盖统一在排序后检查。
  let mut freeblock = first_freeblock
  while freeblock != 0 {
    if freeblock < content_start || freeblock > usable - 4 {
      raise page_invalid(
        number,
        Freeblock,
        freeblock,
        "freeblock 链指针越界",
      )
    }
    let next = page_u16(bytes, number, freeblock, Freeblock)
    let size = page_u16(bytes, number, freeblock + 2, Freeblock)
    if size < 4 || size > usable - freeblock {
      raise page_invalid(
        number,
        Freeblock,
        freeblock + 2,
        "freeblock 长度无效",
      )
    }
    let block_end = freeblock + size
    spans.push((freeblock, block_end, None))
    freeblock_bytes = freeblock_bytes + size
    if next != 0 && next < block_end + 4 {
      raise page_invalid(
        number,
        Freeblock,
        freeblock,
        "freeblock 链重叠、间距不足或形成环",
      )
    }
    freeblock = next
  }
  if !interior &&
    cell_count == 0 &&
    (content_start != usable || first_freeblock != 0 || fragmented_bytes != 0) {
    raise page_invalid(
      number,
      PageHeader,
      offset + 5,
      "页 \{number} 的空叶页不能包含 cell content 空间",
    )
  }
  spans.sort_by((left, right) => left.0.compare(right.0))
  let mut cursor = content_start
  let mut fragments = 0
  for (start, end, cell_index) in spans {
    if start < cursor {
      raise page_invalid(
        number,
        SpaceOverlap,
        start,
        "页 \{number} 的 cell/freeblock 区间重叠：offset=\{start}",
        cell_index~,
      )
    }
    let gap = start - cursor
    fragments = fragments + gap
    cursor = end
  }
  let tail = usable - cursor
  fragments = fragments + tail
  if fragments != fragmented_bytes {
    raise page_invalid(
      number,
      FragmentCount,
      offset + 7,
      "页 \{number} 的碎片计数不一致：declared=\{fragmented_bytes}, actual=\{fragments}",
    )
  }
  let right_child = if interior {
    let child = page_number(read_u32(bytes, offset + 8)) catch {
      error =>
        raise PageInvalid({
          code: ChildPointer,
          page_number: number,
          byte_offset: Some(offset + 8),
          cell_index: None,
          error,
        })
    }
    if child < 1 || child > self.page_count {
      raise page_invalid(number, ChildPointer, offset + 8, "右子页越界")
    }
    Some(child)
  } else {
    None
  }
  let page = {
    number,
    kind,
    first_freeblock,
    cell_count,
    content_start,
    fragmented_bytes,
    right_child,
    cell_offsets,
  }
  let statistics = {
    database_header_bytes: offset,
    btree_header_bytes: header_size,
    pointer_bytes: cell_count * 2,
    unallocated_bytes: content_start - pointers_end,
    cell_bytes,
    freeblock_bytes,
    fragmented_bytes,
    reserved_bytes: self.header.page_size - usable,
    payload_bytes,
    local_payload_bytes,
    max_payload_bytes,
    overflow_cells,
  }
  (page, statistics)
}

///|
fn page_cell_layout(
  bytes : Bytes,
  offset : Int,
  kind : PageType,
  usable : Int,
) -> (Int, Int, Int) raise SqliteError {
  let interior = kind == TableInterior || kind == IndexInterior
  if interior && offset > usable - 4 {
    raise Invalid("interior cell 子页指针越过页面可用空间")
  }
  let mut cursor = offset + (if interior { 4 } else { 0 })
  let (value, width) = page_varint(bytes, cursor, usable)
  cursor = cursor + width
  let mut payload_size = 0
  let mut local_size = 0
  if kind != TableInterior {
    payload_size = bounded_int(value, "payload size")
    if kind == TableLeaf {
      let (_, rowid_width) = page_varint(bytes, cursor, usable)
      cursor = cursor + rowid_width
    }
    local_size = local_payload_size(payload_size, usable, kind == TableLeaf)
    let extra = if local_size < payload_size { 4 } else { 0 }
    if local_size + extra > usable - cursor {
      raise Invalid("cell payload 越过页面可用空间：offset=\{offset}")
    }
    cursor = cursor + local_size + extra
  }
  // SQLite 的小 cell 至少占四字节；填充字节同样不能被其他 cell 或空闲块占用。
  let size = if cursor - offset < 4 { 4 } else { cursor - offset }
  if size > usable - offset {
    raise Invalid(
      "cell 最小空间越过页面可用边界：offset=\{offset}",
    )
  }
  (offset + size, payload_size, local_size)
}
