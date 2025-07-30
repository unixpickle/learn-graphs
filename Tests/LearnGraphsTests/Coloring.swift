import Foundation
import Testing

@testable import LearnGraphs

@Test
func testColoringCycle() {
  let graph = Graph(
    vertices: 0..<5,
    edges: [
      Edge(0, 1),
      Edge(1, 2),
      Edge(2, 3),
      Edge(3, 4),
    ]
  )
  let rawTree = graph.treeDecomposition()
  #expect(rawTree != nil, "could not compute tree decomposition")
  guard let tree = rawTree else {
    return
  }
  let coloring = graph.color([0, 1], usingTree: NiceTreeDecomposition(tree: tree))
  #expect(coloring != nil)
  guard let coloring = coloring else {
    return
  }
  #expect(coloring[0] == coloring[2])
  #expect(coloring[0] != coloring[1])
  #expect(coloring[0] != coloring[3])
  #expect(coloring[1] == coloring[3])
}

@Test
func testColoringSquareWithDiagonal() {
  let graph = Graph(
    vertices: 0..<5,
    edges: [
      Edge(0, 1),
      Edge(1, 2),
      Edge(2, 3),
      Edge(3, 4),
      Edge(0, 2),
    ]
  )
  let rawTree = graph.treeDecomposition()
  #expect(rawTree != nil, "could not compute tree decomposition")
  guard let tree = rawTree else {
    return
  }
  let coloring2 = graph.color([0, 1], usingTree: NiceTreeDecomposition(tree: tree))
  #expect(coloring2 == nil)
  let coloring3 = graph.color([0, 1, 2], usingTree: NiceTreeDecomposition(tree: tree))
  guard let coloring = coloring3 else {
    return
  }
  testValidColoring(graph: graph, coloring: coloring)
}

@Test
func testColoringRandomK3() {
  for _ in 0..<5 {
    let graph = Graph(randomKTree: 0..<10, k: 3)
    let rawTree = graph.treeDecomposition()
    #expect(rawTree != nil, "could not compute tree decomposition")
    guard let tree = rawTree else {
      return
    }
    let nice = NiceTreeDecomposition(tree: tree)
    let coloring2 = graph.color([0, 1], usingTree: nice)
    #expect(coloring2 == nil)
    let coloring3 = graph.color([0, 1, 2], usingTree: nice)
    #expect(coloring3 == nil)
    let coloring4 = graph.color([0, 1, 2, 3], usingTree: nice)
    #expect(coloring4 != nil)
    guard let coloring = coloring4 else {
      return
    }
    testValidColoring(graph: graph, coloring: coloring)
  }
}

func testValidColoring<V: Hashable>(graph: Graph<V>, coloring: [V: Int]) {
  for edge in graph.edgeSet {
    let colors = edge.vertices.map { coloring[$0] }
    #expect(Set(colors).count == 2, "edge \(edge) had colors \(colors)")
  }
}
