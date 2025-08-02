import Testing

@testable import LearnGraphs

@Test
func testDisjointSet() {
  for count in [10, 50] {
    var dummySet = DummyDisjointSet(0..<count)
    var realSet = DisjointSet(0..<count)
    for _ in 0..<(count * 5) {
      let a = (0..<count).randomElement()!
      let b = (0..<count).randomElement()!
      let actualOut = realSet.union(a, b)
      let expOut = dummySet.union(a, b)
      #expect(actualOut == expOut)
      #expect(dummySet.sets == Set(realSet.sets()))
    }
  }
}

private struct DummyDisjointSet<V: Hashable> {
  var sets: Set<Set<V>>

  public init<C: Collection<V>>(_ values: C) {
    sets = Set(values.map { Set([$0]) })
  }

  mutating func union(_ a: V, _ b: V) -> Bool {
    let setA = sets.filter { $0.contains(a) }.first!
    let setB = sets.filter { $0.contains(b) }.first!
    if setA == setB {
      return false
    }
    sets.remove(setA)
    sets.remove(setB)
    sets.insert(setA.union(setB))
    return true
  }
}
