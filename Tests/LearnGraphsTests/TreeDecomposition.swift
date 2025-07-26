import Testing

@testable import LearnGraphs

@Test(arguments: [TreeDecompositionAlgorithm.arnborg])
func testTreeDecompositionCycle(algorithm: TreeDecompositionAlgorithm) {
  for n in 3..<6 {
    var g = Graph(vertices: 0..<n)
    for i in 0..<n {
      g.insertEdge(i, (i + 1) % n)
    }
    let maybeTree = g.treeDecomposition(algorithm: algorithm, maxTreewidth: 2)
    #expect(maybeTree != nil, "tree could not be found")
    guard let tree = maybeTree else { return }
    #expect(getTreeWidth(tree) == 2)
    testValidDecomp(graph: g, tree: tree)
  }
}

func getTreeWidth(_ g: Graph<TreeDecompositionBag<Int>>) -> Int {
  g.vertices.map { $0.bag.count - 1 }.reduce(0, max)
}

func testValidDecomp(graph g: Graph<Int>, tree decomp: Graph<TreeDecompositionBag<Int>>) {
  for v in g.vertices {
    #expect(!decomp.vertices.allSatisfy({ !$0.bag.contains(v) }), "vertex \(v) is missing")
  }
  for edge in g.edgeSet {
    #expect(
      !decomp.vertices.allSatisfy({ $0.bag.intersection(edge.vertices).count != 2 }),
      "edge \(edge) not in a bag")
  }
  for v in g.vertices {
    let nodes = decomp.vertices.filter { $0.bag.contains(v) }
    let subset = decomp.filteringVertices(nodes.contains)
    #expect(
      subset.components().count == 1,
      "node \(v) is part of \(subset.components().count) components in tree"
    )
  }
}
