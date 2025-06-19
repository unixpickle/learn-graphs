extension Array where Element: Comparable {
  internal mutating func popHeap() -> Element? {
    guard let last = popLast() else {
      return nil
    }
    guard let result = self.first else {
      return last
    }

    self[0] = last
    downHeap(0)

    return result
  }

  internal mutating func pushHeap(_ x: Element) {
    self.append(x)
    upHeap(count - 1)
  }

  private mutating func downHeap(_ idx: Int) {
    let (child1, child2) = (idx * 2 + 1, idx * 2 + 2)
    if child1 >= count {
      // No children
      return
    }
    let swapIdx =
      if child2 == count {
        child1
      } else {
        (self[child2] < self[child1] ? child2 : child1)
      }
    if self[swapIdx] < self[idx] {
      (self[idx], self[swapIdx]) = (self[swapIdx], self[idx])
      downHeap(swapIdx)
    }
  }

  private mutating func upHeap(_ idx: Int) {
    if idx == 0 {
      return
    }
    let parent = (idx - 1) >> 1
    if self[parent] > self[idx] {
      (self[parent], self[idx]) = (self[idx], self[parent])
      upHeap(parent)
    }
  }
}
