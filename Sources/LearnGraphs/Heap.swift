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

/// A priority queue where the maximum item can be popped efficiently.
internal struct PriorityQueue<T: Hashable, P: Comparable> {
  private var heap: [T] = []
  private var priority: [P] = []
  private var index: [T: Int] = [:]

  var count: Int { heap.count }

  mutating func push(_ item: T, priority p: P) {
    assert(index[item] == nil, "queue cannot contain more than one copy of item")
    index[item] = count
    heap.append(item)
    priority.append(p)
    upHeap(count - 1)
  }

  mutating func pop() -> (item: T, priority: P)? {
    guard let last = heap.popLast(), let lastPri = priority.popLast() else {
      return nil
    }
    guard let result = heap.first, let resultPri = priority.first else {
      index.removeValue(forKey: last)
      return (item: last, priority: lastPri)
    }
    index.removeValue(forKey: result)

    heap[0] = last
    priority[0] = lastPri
    downHeap(0)

    return (item: result, priority: resultPri)
  }

  mutating func modify(item: T, priority p: P) {
    guard let idx = index[item] else {
      fatalError()
    }
    priority[idx] = p
    upHeap(index[item]!)
    downHeap(index[item]!)
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
        (priority[child2] > priority[child1] ? child2 : child1)
      }
    if priority[swapIdx] > priority[idx] {
      swap(idx, swapIdx)
      downHeap(swapIdx)
    }
  }

  private mutating func upHeap(_ idx: Int) {
    if idx == 0 {
      return
    }
    let parent = (idx - 1) >> 1
    if priority[parent] < priority[idx] {
      swap(parent, idx)
      upHeap(parent)
    }
  }

  private mutating func swap(_ idx1: Int, _ idx2: Int) {
    (priority[idx1], priority[idx2]) = (priority[idx2], priority[idx1])
    (heap[idx1], heap[idx2]) = (heap[idx2], heap[idx1])
    index[heap[idx1]] = idx1
    index[heap[idx2]] = idx2
  }
}
