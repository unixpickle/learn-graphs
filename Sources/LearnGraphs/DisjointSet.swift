public struct DisjointSet<V: Hashable> {
  private var nodeValues: [V]
  private var parentPointers: [Int]
  private var valueToIndex: [V: Int]
  private var size: [Int]

  public init<C: Collection<V>>(_ values: C) {
    nodeValues = Array(values)
    parentPointers = Array(0..<values.count)
    size = [Int](repeating: 1, count: values.count)
    valueToIndex = Dictionary(
      uniqueKeysWithValues: values.enumerated().map { ($0.1, $0.0) }
    )
  }

  private mutating func findRoot(_ value: V) -> Int {
    var idx = valueToIndex[value]!
    while true {
      let p = parentPointers[idx]
      if idx == p {
        return idx
      }
      let pp = parentPointers[p]
      parentPointers[idx] = pp
      idx = p
    }
  }

  @discardableResult
  public mutating func union(_ a: V, _ b: V) -> Bool {
    var root1 = findRoot(a)
    var root2 = findRoot(b)
    if root1 == root2 {
      return false
    }
    if size[root1] < size[root2] {
      (root1, root2) = (root2, root1)
    }
    parentPointers[root2] = root1
    size[root1] = size[root1] + size[root2]
    return true
  }

  /// Sets gets the current disjoint sets.
  public mutating func sets() -> [Set<V>] {
    var piles = [Int: Set<V>]()
    for value in nodeValues {
      piles[findRoot(value), default: []].insert(value)
    }
    return Array(piles.values)
  }
}
