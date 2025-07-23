struct Deque<T>: ExpressibleByArrayLiteral {
  private var items: [T?]
  private var start: Int
  private var size: Int

  var isEmpty: Bool { size == 0 }
  var count: Int { size }

  init() {
    items = []
    start = 0
    size = 0
  }

  init(arrayLiteral elements: T...) {
    items = elements
    start = 0
    size = items.count
  }

  mutating func popFirst() -> T? {
    if size == 0 {
      return nil
    }
    let item = items[start]!
    items[start] = nil
    start = (start + 1) % items.count
    size -= 1
    return item
  }

  mutating func popLast() -> T? {
    if size == 0 {
      return nil
    }
    let idx = (start + size - 1) % items.count
    let item = items[idx]!
    items[idx] = nil
    size -= 1
    return item
  }

  mutating func pushFirst(_ x: T) {
    if size == items.count {
      grow()
    }
    start = (start + items.count - 1) % items.count
    items[start] = x
    size += 1
  }

  mutating func pushLast(_ x: T) {
    if size == items.count {
      grow()
    }
    let end = (start + size) % items.count
    items[end] = x
    size += 1
  }

  private mutating func grow() {
    var newList = [T?](repeating: nil, count: max(2, items.count * 2))
    for i in 0..<size {
      newList[i] = items[(i + start) % items.count]
    }
    items = newList
    start = 0
  }
}
