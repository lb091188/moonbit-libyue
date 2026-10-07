///|
fn empty_snapshot() -> Bytes {
  // 公开测试独立构造空页，不调用私有解析器或白盒 fixture。
  b"SQLite format 3\x00\x02\x00\x01\x01\x00\x40\x20\x20" +
  Bytes::make(76, 0) +
  b"\x0d\x00\x00\x00\x00\x02\x00\x00" +
  Bytes::make(404, 0)
}

///|
priv struct BrokenLegacy {
  data : Bytes
}

///|
impl @moonsqlitefile.PageSource for BrokenLegacy with fn byte_length(self) {
  self.data.length()
}

///|
impl @moonsqlitefile.PageSource for BrokenLegacy with fn read_range(
  self,
  _,
  count,
) {
  if count == 100 {
    return self.data[0:100].to_owned()
  }
  raise @moonsqlitefile.Invalid("黑盒宿主读取失败")
}

///|
test "public import and historical Database fields" {
  let db = @moonsqlitefile.open_database(empty_snapshot())
  let { source, header, page_count, limits, } = db
  assert_eq(source.byte_length(), 512)
  assert_eq(header.page_size, 512)
  assert_eq(page_count, 1)
  assert_eq(limits.max_rows, 100000)
  assert_eq(limits.max_payload_bytes, 16777216)
  assert_eq(limits.max_pages, 100000)
  assert_eq(limits.max_depth, 64)
  assert_eq(db.source64().byte_length64(), 512L)
  assert_eq(db.schema().length(), 0)
  assert_eq(db.inspect_database().status, @moonsqlitefile.Complete)
}

///|
test "public source error mapping distinguishes legacy and range reports" {
  let source = BrokenLegacy::{ data: empty_snapshot(), }
  let old = @moonsqlitefile.open_source(source)
  let wide = @moonsqlitefile.open_range_source(
    @moonsqlitefile.PageSourceAdapter::new(source),
  )
  assert_eq(old.inspect_btree(1).status, @moonsqlitefile.Failed)
  assert_eq(wide.inspect_btree(1).status, @moonsqlitefile.Incomplete)
  assert_eq(old.inspect_page(1).status, @moonsqlitefile.Incomplete)
  assert_eq(wide.inspect_page(1).status, @moonsqlitefile.Incomplete)
  match wide.inspect_btree(1).error {
    Some(@moonsqlitefile.Unsupported(message)) =>
      assert_true(message.has_prefix("source/host_failure:"))
    _ => fail("范围宿主错误丢失来源类别")
  }
}

///|
test "public cursor stable requests exact supply and terminal event" {
  let data = empty_snapshot()
  let cursor = @moonsqlitefile.open_database(data).scan_cursor(1)
  match (cursor.next(), cursor.next()) {
    (@moonsqlitefile.NeedPage(1), @moonsqlitefile.NeedPage(1)) => ()
    _ => fail("等待供页时请求发生变化")
  }
  let rejected = try {
    cursor.provide_page(1, b"")
    false
  } catch {
    @moonsqlitefile.Invalid(_) => true
    _ => false
  }
  assert_true(rejected)
  cursor.provide_page(1, data)
  match cursor.next() {
    @moonsqlitefile.ScanFinished(summary) => {
      assert_eq(summary.completion, @moonsqlitefile.Complete)
      assert_eq(summary.records_read, 0)
      assert_eq(summary.pages_read, 1)
    }
    _ => fail("空叶根应完整结束")
  }
  assert_eq(cursor.progress().pages_read, 1)
}

///|
test "public global cursor reject and stop retain incomplete evidence" {
  let cursor = @moonsqlitefile.open_database(empty_snapshot()).inspection_cursor()
  match cursor.next() {
    @moonsqlitefile.NeedInspectionPage(1) => ()
    _ => fail("全库游标应请求 schema 根页")
  }
  cursor.reject_page(
    @moonsqlitefile.Unsupported("source/host_failure: 磁盘失败"),
  )
  while true {
    match cursor.next() {
      @moonsqlitefile.InspectionProgress(_) => ()
      @moonsqlitefile.InspectionFinished(details) => {
        assert_eq(details.inspection.status, @moonsqlitefile.Incomplete)
        assert_false(details.inspection.ownership_complete)
        assert_true(details.issues.length() > 0)
        break
      }
      _ => fail("schema 读取失败不应继续请求其他对象")
    }
  }
  let stopped = @moonsqlitefile.open_database(empty_snapshot()).inspection_cursor()
  let _ = stopped.stop()
  match stopped.next() {
    @moonsqlitefile.InspectionFinished(details) =>
      assert_eq(details.inspection.status, @moonsqlitefile.Incomplete)
    _ => fail("停止后必须返回部分报告")
  }
}

///|
test "public cache range failures and report budget" {
  let source = @moonsqlitefile.BytesSource::new(empty_snapshot())
  let cache = @moonsqlitefile.CachedSource::new(
    source,
    block_size=512,
    max_pages=1,
  )
  assert_eq(cache.read_range64(0L, 16), b"SQLite format 3\x00")
  assert_eq(cache.read_range64(0L, 16), b"SQLite format 3\x00")
  assert_eq(cache.statistics().misses, 1L)
  assert_eq(cache.statistics().hits, 1L)
  let rejected = try {
    let _ = cache.read_range64(512L, 1)
    false
  } catch {
    @moonsqlitefile.RangeOutOfBounds(_) => true
    _ => false
  }
  assert_true(rejected)
  let db = @moonsqlitefile.open_range_source(cache, max_report_pages=1)
  assert_eq(db.inspect_database().pages.length(), 1)
  assert_eq(db.inspect_database(max_issues=0).status, @moonsqlitefile.Failed)
}

///|
test "public WAL cursor cancellation cannot construct snapshot" {
  let source = @moonsqlitefile.BytesSource::new(empty_snapshot())
  let wal = @moonsqlitefile.BytesSource::new(b"")
  let cursor = @moonsqlitefile.WalCursor::new(0L)
  match cursor.next() {
    @moonsqlitefile.WalReady(report) => {
      assert_eq(report.stop_reason, @moonsqlitefile.WalEndOfFile)
      assert_eq(report.committed_frames, 0)
    }
    _ => fail("空 WAL 应结束")
  }
  let snapshot = @moonsqlitefile.RangeWalSource::from_cursor(
    source, wal, cursor,
  )
  match snapshot.page_range(1) {
    @moonsqlitefile.MainPage(0L) => ()
    _ => fail("空 WAL 应使用主文件页")
  }
  cursor.close()
  let rejected = try {
    let _ = @moonsqlitefile.RangeWalSource::from_cursor(source, wal, cursor)
    false
  } catch {
    @moonsqlitefile.Invalid(_) => true
    _ => false
  }
  assert_true(rejected)
}
