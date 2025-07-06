import Testing

@testable import LearnGraphs

@Test
func testHamiltonianCycleSimple() throws {
  var g = Graph(vertices: 0..<3, edges: [.init(0, 1), .init(1, 2)])
  var cycle = g.hamiltonianCycle()
  try #require(cycle == nil)

  g = Graph(vertices: 0..<3, edges: [.init(0, 1), .init(1, 2), .init(2, 0)])
  cycle = g.hamiltonianCycle()
  try #require(cycle != nil)
  checkHamiltonianCycle(g, cycle!)

  // Nondeterminism might make a bad test succeed sometimes.
  for _ in 0..<100 {
    cycle = g.hamiltonianCycle(start: 1)
    #expect(cycle == [1, 2, 0, 1] || cycle == [1, 0, 2, 1])

    cycle = g.hamiltonianCycle(start: 1, mustUse: g.edgeSet)
    #expect(cycle == [1, 2, 0, 1] || cycle == [1, 0, 2, 1])

    cycle = g.hamiltonianCycle(start: 1, mustUse: [Edge(0, 1)])
    #expect(cycle == [1, 2, 0, 1] || cycle == [1, 0, 2, 1])

    cycle = g.hamiltonianCycle(start: 2, mustUse: [Edge(0, 1)])
    #expect(cycle == [2, 0, 1, 2] || cycle == [2, 1, 0, 2])
  }
}

@Test
func testHamiltonianCycleConstrained() throws {
  var g = Graph(vertices: 0..<10)
  for v1 in g.vertices {
    for v2 in g.vertices {
      if v1 != v2 {
        g.insertEdge(v1, v2)
      }
    }
  }

  // Remove one possible cycle
  for i in 0..<10 {
    g.removeEdge(i, (i + 1) % 10)
  }

  for _ in 0..<100 {
    let cycle = g.hamiltonianCycle(mustUse: [Edge(3, 8), Edge(2, 4), Edge(4, 6)])
    try #require(cycle != nil)
    checkHamiltonianCycle(g, cycle!)
    #expect(cycle!.contains([3, 8]) || cycle!.contains([8, 3]))
    #expect(cycle!.contains([2, 4]) || cycle!.contains([6, 4]))
    #expect(cycle!.contains([4, 2]) || cycle!.contains([4, 6]))
  }
}

func checkHamiltonianCycle(_ g: Graph<Int>, _ cycle: [Int]) {
  #expect(cycle.count == g.vertices.count + 1)
  #expect(cycle.first! == cycle.last!)
  #expect(Set(cycle).count == cycle.count - 1)
  for (v1, v2) in zip(cycle[..<(cycle.count - 1)], cycle[1...]) {
    #expect(g.contains(edge: Edge(v1, v2)))
  }
}
