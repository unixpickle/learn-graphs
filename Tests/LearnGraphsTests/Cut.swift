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
}
