///|
fn local_payload_size(
  payload_size : Int,
  usable : Int,
  table_leaf : Bool,
) -> Int {
  let max_local = if table_leaf {
    usable - 35
  } else {
    (usable - 12) * 64 / 255 - 23
  }
  if payload_size <= max_local {
    return payload_size
  }
  let min_local = (usable - 12) * 32 / 255 - 23
  let candidate = min_local + (payload_size - min_local) % (usable - 4)
  if candidate <= max_local {
    candidate
  } else {
    min_local
  }
}

///|
priv struct PayloadReader {
  db : Database
  buffer : @buffer.Buffer
  occupied : Map[Int, PageUse]
  observer : ScanObserver
  mut remaining : Int
  mut next : Int
  mut parent : Int
  mut first : Bool
}

///|
fn Database::payload_reader(
  self : Database,
  bytes : Bytes,
  offset : Int,
  size : Int,
  table : Bool,
  occupied : Map[Int, PageUse],
  owner_page : Int,
  observer : ScanObserver,
) -> PayloadReader raise SqliteError {
  if size > self.limits.max_payload_bytes {
    raise LimitExceeded("记录 payload 超过资源限制")
  }
  let usable = self.header.usable_size
  let local_size = local_payload_size(size, usable, table)
  let extra = if local_size < size { 4 } else { 0 }
  if offset < 0 || offset > usable || local_size + extra > usable - offset {
    raise Invalid("cell payload 越过页面可用空间")
  }
  let buffer = @buffer.Buffer(size_hint=size)
  buffer.write_bytes(bytes[offset:offset + local_size])
  if extra != 0 {
    observer.trace.at(
      OverflowChain,
      Some(owner_page),
      byte_offset=Some(offset + local_size),
    )
  }
  {
    db: self,
    buffer,
    occupied,
    observer,
    remaining: size - local_size,
    next: if extra == 0 {
      0
    } else {
      page_number(read_u32(bytes, offset + local_size))
    },
    parent: owner_page,
    first: true,
  }
}

///|
fn PayloadReader::next_page(self : PayloadReader) -> Int? raise SqliteError {
  if self.remaining == 0 {
    if self.next != 0 {
      raise Invalid("overflow 链长于记录声明长度")
    }
    return None
  }
  if self.next == 0 {
    raise Invalid("overflow 链被截断")
  }
  if self.occupied.get(self.next) is Some(page_use) {
    raise Invalid(
      "overflow 页 \{self.next} 已用于 \{page_use_name(page_use)}，存在环或重复占用",
    )
  }
  if self.occupied.length() >= self.db.limits.max_pages {
    raise LimitExceeded("扫描总页数超过限制")
  }
  self.observer.trace.at(ReadPage, Some(self.next))
  Some(self.next)
}

///|
fn PayloadReader::provide(
  self : PayloadReader,
  bytes : Bytes,
) -> Unit raise SqliteError {
  let number = self
    .next_page()
    .unwrap_or_else(() => raise Invalid("payload 已读取完成"))
  if bytes.length() != self.db.header.page_size {
    raise Invalid("overflow 页面长度不正确")
  }
  self.observer.trace.at(PageOwnershipCheck, Some(number))
  (self.observer.claim)(
    number,
    if self.first {
      OverflowFirst
    } else {
      OverflowContinuation
    },
    Some(self.parent),
  )
  self.occupied[number] = Overflow
  let count = Int::min(self.remaining, self.db.header.usable_size - 4)
  self.buffer.write_bytes(bytes[4:4 + count])
  self.remaining = self.remaining - count
  self.parent = number
  self.first = false
  self.observer.trace.at(OverflowChain, Some(number), byte_offset=Some(0))
  self.next = page_number(read_u32(bytes, 0))
}

///|
fn PayloadReader::bytes(self : PayloadReader) -> Bytes raise SqliteError {
  if self.next_page() is Some(_) {
    raise Invalid("payload 尚未读取完成")
  }
  self.buffer.to_bytes()
}
