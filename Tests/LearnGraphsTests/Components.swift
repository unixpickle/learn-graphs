import Testing

@testable import LearnGraphs

@Test
func testComponentsEmpty() {
  let graph = Graph<Int>()
  #expect(graph.components() == [graph])
}

@Test
func testComponentsNoEdges() {
  let graph = Graph(vertices: 0..<10)
  #expect(Set(graph.components()) == Set((0..<10).map { Graph(vertices: [$0]) }))
}

@Test
func testComponentsCycle() {
  var graph = Graph(vertices: 0..<10)
  for i in 0..<10 {
    graph.insertEdge(i, (i + 1) % 10)
  }
  #expect(graph.components() == [graph])
}
