import Foundation
import Testing

@testable import LearnGraphs

@Test(arguments: [ColoringAlgorithm.addContract, .treeDecomposition(.arnborg), .depthFirst])
func testColoringCycle(algorithm: ColoringAlgorithm) {
  let graph = Graph(
    vertices: 0..<5,
    edges: [
      Edge(0, 1),
      Edge(1, 2),
      Edge(2, 3),
      Edge(3, 4),
    ]
  )
  let (coloring, count) = graph.color(algorithm: algorithm)
  #expect(count == 2)
  #expect(coloring[0] == coloring[2])
  #expect(coloring[0] != coloring[1])
  #expect(coloring[0] != coloring[3])
  #expect(coloring[1] == coloring[3])
}

@Test(arguments: [ColoringAlgorithm.addContract, .treeDecomposition(.arnborg), .depthFirst])
func testColoringSquareWithDiagonal(algorithm: ColoringAlgorithm) {
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
  let (coloring, count) = graph.color(algorithm: algorithm)
  #expect(count == 3)
  testValidColoring(graph: graph, coloring: coloring)
}

@Test(arguments: [
  ColoringAlgorithm.addContract, ColoringAlgorithm.treeDecomposition(.arnborg), .depthFirst,
])
func testColoringRandomK3Small(algorithm: ColoringAlgorithm) {
  for _ in 0..<5 {
    let graph = Graph(randomKTree: 0..<6, k: 3)

    let (coloring, count) = graph.color(algorithm: algorithm)
    #expect(count == 4)
    testValidColoring(graph: graph, coloring: coloring)
  }
}

@Test(arguments: [ColoringAlgorithm.treeDecomposition(.arnborg), .depthFirst])
func testColoringRandomK3(algorithm: ColoringAlgorithm) {
  for _ in 0..<5 {
    let graph = Graph(randomKTree: 0..<10, k: 3)
    let (coloring, count) = graph.color(algorithm: algorithm)
    #expect(count == 4)
    testValidColoring(graph: graph, coloring: coloring)
  }
}

func testValidColoring<V: Hashable>(graph: Graph<V>, coloring: [V: Int]) {
  for edge in graph.edgeSet {
    let colors = edge.vertices.map { coloring[$0] }
    #expect(Set(colors).count == 2, "edge \(edge) had colors \(colors)")
  }
}
