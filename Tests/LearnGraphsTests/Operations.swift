import Testing

@testable import LearnGraphs

@Test
func testCoW() {
  var graph = AdjList(vertices: 0...2)
  graph.insertEdge(0, 1)
  graph.insertEdge(1, 2)

  let graph1 = graph
  graph.insertEdge(0, 2)

  #expect(graph.edgeCount != graph1.edgeCount)
}
