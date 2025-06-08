import Testing

@testable import LearnGraphs

@Test
func testBoruvkaSimple() {
  // Graph shown on wikipedia: https://en.wikipedia.org/wiki/File:Multiple_minimum_spanning_trees.svg
  var graph = AdjList(vertices: ["A", "B", "C", "D", "E", "F"])
  graph.insertEdge("A", "B")
  graph.insertEdge("A", "D")
  graph.insertEdge("A", "E")
  graph.insertEdge("B", "D")
  graph.insertEdge("B", "E")
  graph.insertEdge("D", "E")
  graph.insertEdge("C", "E")
  graph.insertEdge("C", "F")
  graph.insertEdge("E", "F")
  let weights: [UndirectedEdge<String>: Int] = [
    UndirectedEdge("A", "B"): 1,
    UndirectedEdge("A", "D"): 4,
    UndirectedEdge("A", "E"): 3,
    UndirectedEdge("B", "D"): 4,
    UndirectedEdge("B", "E"): 2,
    UndirectedEdge("D", "E"): 4,
    UndirectedEdge("C", "E"): 4,
    UndirectedEdge("C", "F"): 5,
    UndirectedEdge("E", "F"): 7,
  ]

  let tree = graph.minimumSpanningTree(algorithm: .boruvka) { weights[$0]! }
  let totalCost = tree.edgeSet.map { weights[$0]! }.reduce(0, +)
  #expect(totalCost == 16)
}

@Test
func testBoruvkaRandom() {
  let graph = AdjList(random: 0..<100, edgeCount: 1000)
  let edges = Array(graph.edgeSet).shuffled()
  let weights = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })

  let spanTree = graph.minimumSpanningTree(algorithm: .boruvka) { weights[$0]! }
  #expect(spanTree.edgeCount < graph.edgeCount)

  let badSpanTree = graph.minimumSpanningTree(algorithm: .boruvka) { -weights[$0]! }
  let goodCost = spanTree.edgeSet.map({ weights[$0]! }).reduce(0, +)
  let badCost = badSpanTree.edgeSet.map({ weights[$0]! }).reduce(0, +)
  #expect(goodCost < badCost)

  // TODO: test that the spanning tree has the same components as the original graph.
}
