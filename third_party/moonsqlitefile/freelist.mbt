///|
/// 返回 freelist 中的 trunk 与 leaf 页号，并校验计数与循环。
/// 校验 freelist trunk/leaf、数量和重复引用，返回空闲页号；页号从 1 开始并受页预算限制。
pub fn Database::freelist(self : Database) -> Array[Int] raise SqliteError {
  self.freelist_observed((_, _, _) => ())
}

///|
fn Database::freelist_observed(
  self : Database,
  claim : (Int, PageKind, Int?) -> Unit raise SqliteError,
  trace? : InspectionTrace = InspectionTrace::new(),
) -> Array[Int] raise SqliteError {
  let cursor = self.freelist_cursor(claim, trace)
  while cursor.next() is Some(number) {
    cursor.supplied = Some(self.read_page(number))
  }
  cursor.result
}
