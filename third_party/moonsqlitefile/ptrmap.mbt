///|
/// auto-vacuum Ptrmap 的五种页面反向引用类型。
pub(all) enum PtrmapType {
  RootPage
  FreePage
  FirstOverflow
  NextOverflow
  NonRootBtree
} derive(Debug, Eq)

///|
pub extend PtrmapType with @debug.Debug::{to_repr}

///|
pub extend PtrmapType with Eq::{equal, not_equal}

///|
/// 已校验的反向指针；page_number 和 map_page 从 1 开始，parent_page 为格式存储的父页值，根页/空闲页使用 0。
pub(all) struct PtrmapEntry {
  page_number : Int
  map_page : Int
  kind : PtrmapType
  parent_page : Int
} derive(Debug, Eq)

///|
pub extend PtrmapEntry with @debug.Debug::{to_repr}

///|
pub extend PtrmapEntry with Eq::{equal, not_equal}

///|
fn ptrmap_page_number(number : Int, usable : Int, page_size : Int) -> Int {
  let step = usable / 5 + 1
  let map_page = (number - 2) / step * step + 2
  let lock_page = 1073741824 / page_size + 1
  if map_page == lock_page {
    map_page + 1
  } else {
    map_page
  }
}

///|
fn Database::visit_ptrmap(
  self : Database,
  visit : (PtrmapEntry) -> Bool raise SqliteError,
  trace? : InspectionTrace = InspectionTrace::new(),
) -> Bool raise SqliteError {
  let cursor = self.ptrmap_cursor(trace)
  while true {
    match cursor.next() {
      MapPage(number) => {
        cursor.cached = self.read_page(number)
        cursor.cached_number = number
      }
      MapEntry(entry) => if !visit(entry) { return false }
      MapFinished => return true
    }
  } nobreak {
    false
  }
}

///|
/// 读取 auto-vacuum 反向指针；与真实页归属对照请使用 inspect_database。
/// 读取并校验 auto-vacuum 的 Ptrmap 条目；非 auto-vacuum 返回空数组。真实归属交叉检查由 inspect_database 完成。
pub fn Database::ptrmap_entries(
  self : Database,
) -> Array[PtrmapEntry] raise SqliteError {
  let entries : Array[PtrmapEntry] = []
  ignore(
    self.visit_ptrmap(entry => {
      entries.push(entry)
      true
    }),
  )
  entries
}

///|
fn OwnershipState::check_root_positions(
  self : OwnershipState,
  db : Database,
) -> Unit {
  let largest = db.header.largest_root_page.reinterpret_as_int()
  let mut actual_largest = 1
  for number, owner in self.owners {
    if owner.kind == BtreeRoot {
      if number > actual_largest {
        actual_largest = number
      }
    } else if owner.kind != PointerMap &&
      owner.kind != LockByte &&
      number <= largest {
      self.trace.at(PtrmapCheck, Some(number))
      self.failed = true
      self.issue(
        ScanError(
          None,
          Invalid(
            "auto-vacuum 的非根页出现在 largest root 之前：\{number}",
          ),
        ),
      )
    }
  }
  if actual_largest != largest {
    self.trace.at(PtrmapCheck, Some(1), byte_offset=Some(52))
    self.failed = true
    self.issue(
      ScanError(None, Invalid("largest root 与 schema 根页集合不一致")),
    )
  }
}

///|
fn OwnershipState::check_ptrmap_entry(
  self : OwnershipState,
  entry : PtrmapEntry,
) -> Bool {
  if self.owners.get(entry.page_number) is Some(owner) {
    let expected = match owner.kind {
      BtreeRoot => RootPage
      BtreeChild => NonRootBtree
      OverflowFirst => FirstOverflow
      OverflowContinuation => NextOverflow
      FreelistTrunk | FreelistLeaf => FreePage
      PointerMap | LockByte => return false
    }
    let parent = if expected == RootPage || expected == FreePage {
      0
    } else {
      owner.parent_page.unwrap()
    }
    if entry.kind != expected || entry.parent_page != parent {
      self.failed = true
      self.issue(PtrmapMismatch(entry, owner))
    }
  } else {
    // 尚无归属的页由最终覆盖检查报告，不根据 Ptrmap 推断真实归属。
    return false
  }
  true
}
