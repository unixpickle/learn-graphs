import Testing

@testable import LearnGraphs

@Test
func testCutSimple() {
  var graph = Graph(vertices: 0..<5)
  graph.insertEdge(0, 1)
  graph.insertEdge(1, 2)
  graph.insertEdge(3, 4)

  // Cut out the first complete subgraph
  var keptPart = graph
  var (removedPart, cutSet) = keptPart.cut(vertices: [0, 1, 2])
  #expect(keptPart == Graph(vertices: [3, 4], edges: [Edge(3, 4)]))
  #expect(removedPart == Graph(vertices: 0..<3, edges: [Edge(0, 1), Edge(1, 2)]))
  #expect(cutSet == Set())

  // Cut out the second complete subgraph
  keptPart = graph
  (removedPart, cutSet) = keptPart.cut(vertices: [3, 4])
  #expect(removedPart == Graph(vertices: [3, 4], edges: [Edge(3, 4)]))
  #expect(keptPart == Graph(vertices: 0..<3, edges: [Edge(0, 1), Edge(1, 2)]))
  #expect(cutSet == Set())

  // Cut out parts of the first subgraph
  keptPart = graph
  (removedPart, cutSet) = keptPart.cut(vertices: [1])
  #expect(removedPart == Graph(vertices: [1]))
  #expect(keptPart == Graph(vertices: [0, 2, 3, 4], edges: [Edge(3, 4)]))
  #expect(cutSet == [Edge(0, 1), Edge(1, 2)])
  keptPart = graph
  (removedPart, cutSet) = keptPart.cut(vertices: [0])
  #expect(removedPart == Graph(vertices: [0]))
  #expect(keptPart == Graph(vertices: [1, 2, 3, 4], edges: [Edge(1, 2), Edge(3, 4)]))
  #expect(cutSet == [Edge(0, 1)])
  keptPart = graph
  (removedPart, cutSet) = keptPart.cut(vertices: [0, 1])
  #expect(removedPart == Graph(vertices: [0, 1], edges: [Edge(0, 1)]))
  #expect(keptPart == Graph(vertices: [2, 3, 4], edges: [Edge(3, 4)]))
  #expect(cutSet == [Edge(1, 2)])
}

@Test
func testMinCostCutComponents() {
  for _ in 0..<10 {
    var graph = Graph(random: 0..<20, edgeCount: 20)
    while graph.components().count != 2 {
      graph = Graph(random: 0..<20, edgeCount: 20)
    }

    let components = graph.components()
    let (set1, set2, cost) = graph.minCostCut { _ in 1 }
    #expect(cost == 0)
    #expect(
      Set(components) == Set([set1, set2].map { s in graph.filteringVertices { s.contains($0) } })
    )

    let fullGraph = Graph(
      vertices: graph.vertices,
      edges: graph.vertices.flatMap { x in graph.vertices.filter { $0 != x }.map { y in Edge(x, y) }
      }
    )
    let (set1A, set2A, costA) = fullGraph.minCostCut { edge in graph.contains(edge: edge) ? 1 : 0 }
    #expect(costA == 0)
    #expect(
      Set(components)
        == Set([set1A, set2A].map { s in graph.filteringVertices { s.contains($0) } })
    )
  }
}

@Test
func testGomoryHuTree() {
  var i = 0
  while i < 5 {
    let graph = Graph(random: 0..<20, edgeProb: 0.1)
    if graph.components().count > 1 {
      continue
    }
    i += 1

    let costs = Dictionary(
      uniqueKeysWithValues: graph.edgeSet.map { ($0, Double.random(in: 0..<1)) }
    )
    let tree = graph.gomoryHuTree { costs[$0]! }

    // Check that the minimum cost cut is reflected.
    let (s1, s2, cutCost) = graph.minCostCut { costs[$0]! }
    for v1 in s1 {
      for v2 in s2 {
        let (_, _, minCost) = tree.minCut(from: v1, to: v2)
        assert(abs(minCost - cutCost) < 1e-5)
      }
    }

    // Check all pairwise costs
    for v1 in graph.vertices {
      for v2 in graph.vertices {
        if v1 == v2 {
          continue
        }
        let flow = graph.maxFlow(from: v1, to: v2) { (x, y) in costs[Edge(x, y)]! }
        let actualMinCost = flow.totalFlow(from: v1)
        let (_, _, minCost) = tree.minCut(from: v1, to: v2)
        assert(abs(minCost - actualMinCost) < 1e-5)
      }
    }
  }
}
