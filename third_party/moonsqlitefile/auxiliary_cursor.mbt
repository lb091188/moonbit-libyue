///|
priv struct FreelistCursor {
  db : Database
  claim : (Int, PageKind, Int?) -> Unit raise SqliteError
  trace : InspectionTrace
  result : Array[Int]
  visited : Map[Int, Bool]
  mut next_page : Int
  mut supplied : Bytes?
  mut done : Bool
}

///|
fn Database::freelist_cursor(
  self : Database,
  claim : (Int, PageKind, Int?) -> Unit raise SqliteError,
  trace : InspectionTrace,
) -> FreelistCursor raise SqliteError {
  trace.at(FreelistCheck, Some(1), byte_offset=Some(32))
  {
    db: self,
    claim,
    trace,
    result: [],
    visited: Map([]),
    next_page: page_number(self.header.freelist_trunk),
    supplied: None,
    done: false,
  }
}

///|
fn FreelistCursor::next(self : FreelistCursor) -> Int? raise SqliteError {
  if self.done {
    return None
  }
  while self.next_page != 0 {
    let number = self.next_page
    if number == 1 {
      raise Invalid("schema 页不能出现在 freelist")
    }
    if self.visited.contains(number) {
      raise Invalid("freelist 页重复或形成环")
    }
    if self.result.length() >= self.db.limits.max_pages {
      raise LimitExceeded("freelist 页数超过限制")
    }
    if self.supplied is None {
      self.trace.at(ReadPage, Some(number))
      return Some(number)
    }
    let bytes = self.supplied.unwrap()
    self.supplied = None
    self.trace.at(PageOwnershipCheck, Some(number))
    (self.claim)(number, FreelistTrunk, None)
    self.visited[number] = true
    self.result.push(number)
    self.trace.at(FreelistCheck, Some(number), byte_offset=Some(4))
    let count = page_number(read_u32(bytes, 4))
    if count > (self.db.header.usable_size - 8) / 4 {
      raise Invalid("freelist trunk 指针数组越界")
    }
    for i = 0; i < count; i = i + 1 {
      self.trace.at(FreelistCheck, Some(number), byte_offset=Some(8 + i * 4))
      let leaf = page_number(read_u32(bytes, 8 + i * 4))
      if leaf <= 1 || leaf > self.db.page_count || self.visited.contains(leaf) {
        raise Invalid("freelist leaf 越界或重复")
      }
      if self.result.length() >= self.db.limits.max_pages {
        raise LimitExceeded("freelist 页数超过限制")
      }
      self.visited[leaf] = true
      (self.claim)(leaf, FreelistLeaf, None)
      self.result.push(leaf)
    }
    self.trace.at(FreelistCheck, Some(number), byte_offset=Some(0))
    self.next_page = page_number(read_u32(bytes, 0))
  }
  self.trace.at(FreelistCheck, Some(1), byte_offset=Some(36))
  if self.result.length().reinterpret_as_uint() != self.db.header.freelist_pages {
    raise Invalid("freelist 长度与数据库头不一致")
  }
  self.done = true
  None
}

///|
priv enum PtrmapEvent {
  MapPage(Int)
  MapEntry(PtrmapEntry)
  MapFinished
}

///|
priv struct PtrmapCursor {
  db : Database
  trace : InspectionTrace
  mut number : Int
  mut cached_number : Int
  mut cached : Bytes
}

///|
fn Database::ptrmap_cursor(
  self : Database,
  trace : InspectionTrace,
) -> PtrmapCursor raise SqliteError {
  trace.at(PtrmapCheck, Some(1), byte_offset=Some(52))
  if self.header.largest_root_page == 0U && self.header.incremental_vacuum {
    raise Invalid("未启用 auto-vacuum 却设置 incremental-vacuum")
  }
  if self.header.largest_root_page.to_uint64() > self.page_count.to_uint64() {
    raise Invalid("largest root page 越界")
  }
  if self.header.largest_root_page != 0U &&
    self.page_count > self.limits.max_pages {
    raise LimitExceeded("Ptrmap 枚举超过页数预算")
  }
  { db: self, trace, number: 2, cached_number: 0, cached: b"", }
}

///|
fn PtrmapCursor::next(self : PtrmapCursor) -> PtrmapEvent raise SqliteError {
  if self.db.header.largest_root_page == 0U {
    return MapFinished
  }
  let lock_page = 1073741824 / self.db.header.page_size + 1
  while self.number <= self.db.page_count {
    let number = self.number
    let map_page = ptrmap_page_number(
      number,
      self.db.header.usable_size,
      self.db.header.page_size,
    )
    if number == lock_page || number == map_page {
      self.number = self.number + 1
      continue
    }
    if map_page != self.cached_number {
      self.trace.at(ReadPage, Some(map_page))
      return MapPage(map_page)
    }
    let offset = (number - map_page - 1) * 5
    self.trace.at(PtrmapCheck, Some(map_page), byte_offset=Some(offset))
    if offset < 0 || offset > self.db.header.usable_size - 5 {
      raise Invalid("Ptrmap 条目位置越界")
    }
    let kind = match self.cached[offset].to_int() {
      1 => RootPage
      2 => FreePage
      3 => FirstOverflow
      4 => NextOverflow
      5 => NonRootBtree
      _ => raise Invalid("页 \{number} 的 Ptrmap 类型无效")
    }
    self.trace.at(PtrmapCheck, Some(map_page), byte_offset=Some(offset + 1))
    let parent = page_number(read_u32(self.cached, offset + 1))
    let zero_parent = kind == RootPage || kind == FreePage
    if (zero_parent && parent != 0) ||
      (
        !zero_parent &&
        (parent < 1 || parent > self.db.page_count || parent == number)
      ) {
      raise Invalid("页 \{number} 的 Ptrmap 父页无效")
    }
    self.trace.at(PtrmapCheck, Some(map_page), byte_offset=Some(offset))
    self.number = self.number + 1
    return MapEntry({
      page_number: number,
      map_page,
      kind,
      parent_page: parent,
    })
  }
  MapFinished
}
