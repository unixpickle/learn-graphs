import Testing

@testable import LearnGraphs

@Test
func testRandomGraph() {
  let graph = Graph(random: 0..<100, edgeProb: 0.1)
  let edgeCount = graph.edgeCount
  let expectedCount = 4950 / 10
  #expect(edgeCount < expectedCount * 2 && edgeCount > expectedCount / 2)

  let graph1 = Graph(random: 0..<100, edgeCount: 100)
  #expect(graph1.edgeCount == 100)
}
