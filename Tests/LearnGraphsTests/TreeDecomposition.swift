import Testing

@testable import LearnGraphs

@Test
func testAsTreeCycle() {
  for n in 3..<6 {
    var g = Graph(vertices: 0..<n)
    for i in 0..<n {
      g.insertEdge(i, (i + 1) % n)
    }
    #expect(g.asTree() == nil)
  }
}

@Test
func testAsTreeSmall() {
  let g = Graph(vertices: 0..<5, edges: [Edge(0, 1), Edge(0, 2), Edge(2, 3), Edge(2, 4)])
  for v in g.vertices {
    #expect(g.asTree(root: v) != nil, "unable to build tree at \(v)")
  }
  #expect(g.asTree(root: 0)! == (root: 0, children: [0: [1, 2], 2: [3, 4]]))
}

@Test(arguments: [TreeDecompositionAlgorithm.arnborg])
func testTreeDecompositionCycle(algorithm: TreeDecompositionAlgorithm) {
  for n in 3...6 {
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

@Test(arguments: [TreeDecompositionAlgorithm.arnborg])
func testTreeDecompositionExample(algorithm: TreeDecompositionAlgorithm) {
  // https://en.wikipedia.org/wiki/Tree_decomposition#/media/File:Tree_decomposition.svg
  let g = Graph(
    vertices: ["A", "B", "C", "D", "E", "F", "G", "H"],
    edges: [
      Edge("A", "B"), Edge("A", "C"), Edge("B", "C"), Edge("B", "E"), Edge("B", "G"),
      Edge("B", "F"), Edge("C", "D"), Edge("C", "E"), Edge("D", "E"), Edge("E", "G"),
      Edge("E", "H"), Edge("F", "G"), Edge("G", "H"),
    ]
  )
  let maybeTree = g.treeDecomposition(algorithm: algorithm, maxTreewidth: 2)
  #expect(maybeTree != nil, "tree could not be found")
  guard let tree = maybeTree else { return }
  #expect(getTreeWidth(tree) == 2)
  testValidDecomp(graph: g, tree: tree)
}

@Test(arguments: [TreeDecompositionAlgorithm.arnborg])
func testTreeDecompositionGrid(algorithm: TreeDecompositionAlgorithm) {
  // The grid is:
  // 0 1 2
  // 3 4 5
  // 6 7 8
  let g = Graph(
    vertices: 0...8,
    edges: [
      // Horizontal
      Edge(0, 1), Edge(1, 2),
      Edge(3, 4), Edge(4, 5),
      Edge(6, 7), Edge(7, 8),
      // Vertical
      Edge(0, 3), Edge(3, 6),
      Edge(1, 4), Edge(4, 7),
      Edge(2, 5), Edge(5, 8),
    ]
  )
  let maybeTree = g.treeDecomposition(algorithm: algorithm, maxTreewidth: 3)
  #expect(maybeTree != nil, "tree could not be found")
  guard let tree = maybeTree else { return }
  #expect(getTreeWidth(tree) == 3)
  testValidDecomp(graph: g, tree: tree)
}

@Test(arguments: [TreeDecompositionAlgorithm.arnborg])
func testTreeDecompositionRandomKTree(algorithm: TreeDecompositionAlgorithm) {
  for (count, k) in [(30, 3), (5, 4)] {
    for _ in 0..<count {
      let g = Graph(randomKTree: 0..<10, k: k, deleteProb: 0.1)
      let maybeTree = g.treeDecomposition(algorithm: algorithm, maxTreewidth: k)
      #expect(maybeTree != nil, "tree could not be found")
      guard let tree = maybeTree else { return }
      #expect(getTreeWidth(tree) <= k)
      testValidDecomp(graph: g, tree: tree)
    }
  }
}

func getTreeWidth<V>(_ g: Graph<TreeDecompositionBag<V>>) -> Int {
  g.vertices.map { $0.bag.count - 1 }.reduce(0, max)
}

func testValidDecomp<V>(graph g: Graph<V>, tree decomp: Graph<TreeDecompositionBag<V>>) {
  #expect(decomp.asTree() != nil)
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
