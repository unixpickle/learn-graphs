import Testing

@testable import LearnGraphs

@Test(arguments: [MinSpanTreeAlgorithm.boruvka])
func testSimpleMinimumSpanningTree(_ algo: MinSpanTreeAlgorithm) {
  // Graph shown on wikipedia: https://en.wikipedia.org/wiki/File:Multiple_minimum_spanning_trees.svg
  var graph = Graph(vertices: ["A", "B", "C", "D", "E", "F"])
  graph.insertEdge("A", "B")
  graph.insertEdge("A", "D")
  graph.insertEdge("A", "E")
  graph.insertEdge("B", "D")
  graph.insertEdge("B", "E")
  graph.insertEdge("D", "E")
  graph.insertEdge("C", "E")
  graph.insertEdge("C", "F")
  graph.insertEdge("E", "F")
  let weights: [Edge<String>: Int] = [
    Edge("A", "B"): 1,
    Edge("A", "D"): 4,
    Edge("A", "E"): 3,
    Edge("B", "D"): 4,
    Edge("B", "E"): 2,
    Edge("D", "E"): 4,
    Edge("C", "E"): 4,
    Edge("C", "F"): 5,
    Edge("E", "F"): 7,
  ]

  let tree = graph.minimumSpanningTree(algorithm: algo) { weights[$0]! }
  let totalCost = tree.edgeSet.map { weights[$0]! }.reduce(0, +)
  #expect(totalCost == 16)
}

@Test(arguments: [MinSpanTreeAlgorithm.boruvka])
func testBoruvkaRandom(_ algo: MinSpanTreeAlgorithm) {
  // Make a multi-component random graph.
  var graph = Graph<Int>()
  while graph.components().count < 2 {
    graph = Graph(random: 0..<100, edgeCount: 200)
  }

  // Randomize edge weights by permuting indices.
  let edges = Array(graph.edgeSet).shuffled()
  let weights = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })

  let spanTree = graph.minimumSpanningTree(algorithm: algo) { weights[$0]! }
  #expect(spanTree.edgeCount < graph.edgeCount)

  let badSpanTree = graph.minimumSpanningTree(algorithm: algo) { -weights[$0]! }
  let goodCost = spanTree.edgeSet.map({ weights[$0]! }).reduce(0, +)
  let badCost = badSpanTree.edgeSet.map({ weights[$0]! }).reduce(0, +)
  #expect(goodCost < badCost)

  for tree in [spanTree, badSpanTree] {
    let oldComponents = graph.components()
    let newComponents = tree.components()
    #expect(oldComponents.count == newComponents.count)
    #expect(Set(oldComponents.map { $0.vertices }) == Set(newComponents.map { $0.vertices }))

    for component in newComponents {
      // Iff a graph is connected, and the number of edges is |V|-1, then
      // the graph is a tree.
      #expect(component.edgeCount == component.vertices.count - 1)
    }
  }
}
