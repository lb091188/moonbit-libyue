///|
/// 某一页用途的首次归属页数；不重复计入冲突引用。
pub(all) struct PageKindCount {
  kind : PageKind
  pages : Int
} derive(Debug, Eq)

///|
pub extend PageKindCount with @debug.Debug::{to_repr}

///|
pub extend PageKindCount with Eq::{equal, not_equal}

///|
/// 仅统计已经认领的页，不把冲突引用重复计入另一个对象。
/// 一个对象已认领的 B-tree 与 overflow 页数；包含页内空闲空间，不是有效 payload 长度。
pub(all) struct ObjectPageCount {
  root_page : Int
  object_name : String?
  btree_pages : Int
  overflow_pages : Int
} derive(Debug, Eq)

///|
pub extend ObjectPageCount with @debug.Debug::{to_repr}

///|
pub extend ObjectPageCount with Eq::{equal, not_equal}

///|
/// 对已有报告的纯汇总；完整程度、诊断及 payload 请求总量仍以原报告为准。
/// 已有归属报告的纯汇总；不重新读取源。未完成检查的统计只代表已观察前缀，完整程度仍看原报告。
pub(all) struct InspectionSummary {
  claimed_pages : Int
  unclaimed_pages : Int
  page_kinds : Array[PageKindCount]
  objects : Array[ObjectPageCount]
} derive(Debug, Eq)

///|
pub extend InspectionSummary with @debug.Debug::{to_repr}

///|
pub extend InspectionSummary with Eq::{equal, not_equal}

///|
priv struct ObjectPageCounter {
  mut btree_pages : Int
  mut overflow_pages : Int
}

///|
fn page_kind_index(kind : PageKind) -> Int {
  match kind {
    BtreeRoot => 0
    BtreeChild => 1
    OverflowFirst => 2
    OverflowContinuation => 3
    FreelistTrunk => 4
    FreelistLeaf => 5
    PointerMap => 6
    LockByte => 7
  }
}

///|
/// 不读取数据源、不解码记录；未完成报告的统计只表示已观察到的页。
/// 对已有页归属报告作纯汇总，不重读数据源；冲突页只按首次归属计数，未完成报告只代表已观察前缀。
pub fn DatabaseInspection::summarize(
  self : DatabaseInspection,
) -> InspectionSummary {
  let kinds = [
    BtreeRoot,
    BtreeChild,
    OverflowFirst,
    OverflowContinuation,
    FreelistTrunk,
    FreelistLeaf,
    PointerMap,
    LockByte,
  ]
  let counts = Array::make(8, 0)
  let objects : Map[(Int, String?), ObjectPageCounter] = Map([])
  for page in self.pages {
    let index = page_kind_index(page.kind)
    counts[index] = counts[index] + 1
    let btree = page.kind == BtreeRoot || page.kind == BtreeChild
    let overflow = page.kind == OverflowFirst ||
      page.kind == OverflowContinuation
    if (btree || overflow) && page.root_page is Some(root) {
      let key = (root, page.object_name)
      let counter = match objects.get(key) {
        Some(counter) => counter
        None => {
          let counter : ObjectPageCounter = {
            btree_pages: 0,
            overflow_pages: 0,
          }
          objects[key] = counter
          counter
        }
      }
      if btree {
        counter.btree_pages = counter.btree_pages + 1
      }
      if overflow {
        counter.overflow_pages = counter.overflow_pages + 1
      }
    }
  }
  let object_counts : Array[ObjectPageCount] = []
  for (root, name), counter in objects {
    object_counts.push({
      root_page: root,
      object_name: name,
      btree_pages: counter.btree_pages,
      overflow_pages: counter.overflow_pages,
    })
  }
  // 输出顺序固定，避免 Map 枚举顺序导致 CLI 与展示层反复变化。
  object_counts.sort_by((left, right) => {
    let root_order = left.root_page.compare(right.root_page)
    if root_order != 0 {
      root_order
    } else {
      match (left.object_name, right.object_name) {
        (None, None) => 0
        (None, Some(_)) => -1
        (Some(_), None) => 1
        (Some(left_name), Some(right_name)) => left_name.compare(right_name)
      }
    }
  })
  {
    claimed_pages: self.pages.length(),
    unclaimed_pages: self.unclaimed_pages.length(),
    page_kinds: Array::makei(8, i => { kind: kinds[i], pages: counts[i], }),
    objects: object_counts,
  }
}
