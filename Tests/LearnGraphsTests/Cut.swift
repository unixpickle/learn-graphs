import Testing

@testable import LearnGraphs

@Test
func testCutSimple() {
  var graph = AdjList(vertices: 0..<5)
  graph.insertEdge(0, 1)
  graph.insertEdge(1, 2)
  graph.insertEdge(3, 4)

  // Cut out the first complete subgraph
  var keptPart = graph
  var (removedPart, cutSet) = keptPart.cut(vertices: [0, 1, 2])
  #expect(keptPart == AdjList(vertices: [3, 4], edges: [3: [4], 4: [3]]))
  #expect(removedPart == AdjList(vertices: 0..<3, edges: [0: [1], 1: [0, 2], 2: [1]]))
  #expect(cutSet == Set())

  // Cut out the second complete subgraph
  keptPart = graph
  (removedPart, cutSet) = keptPart.cut(vertices: [3, 4])
  #expect(removedPart == AdjList(vertices: [3, 4], edges: [3: [4], 4: [3]]))
  #expect(keptPart == AdjList(vertices: 0..<3, edges: [0: [1], 1: [0, 2], 2: [1]]))
  #expect(cutSet == Set())

  // Cut out parts of the first subgraph
  keptPart = graph
  (removedPart, cutSet) = keptPart.cut(vertices: [1])
  #expect(removedPart == AdjList(vertices: [1]))
  #expect(keptPart == AdjList(vertices: [0, 2, 3, 4], edges: [3: [4], 4: [3]]))
  #expect(cutSet == [UndirectedEdge(0, 1), UndirectedEdge(1, 2)])
  keptPart = graph
  (removedPart, cutSet) = keptPart.cut(vertices: [0])
  #expect(removedPart == AdjList(vertices: [0]))
  #expect(keptPart == AdjList(vertices: [1, 2, 3, 4], edges: [1: [2], 2: [1], 3: [4], 4: [3]]))
  #expect(cutSet == [UndirectedEdge(0, 1)])
  keptPart = graph
  (removedPart, cutSet) = keptPart.cut(vertices: [0, 1])
  #expect(removedPart == AdjList(vertices: [0, 1], edges: [0: [1], 1: [0]]))
  #expect(keptPart == AdjList(vertices: [2, 3, 4], edges: [3: [4], 4: [3]]))
  #expect(cutSet == [UndirectedEdge(1, 2)])
}
