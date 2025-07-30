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

@Test
func testArticulationAndBridges() {
  for _ in 0..<50 {
    let g = Graph(random: 0..<20, edgeProb: 0.1)
    let (actualArt, actualBridge) = g.articulationAndBridges()
    let (expArt, expBridge) = bruteForceArticulationAndBridges(g)
    #expect(actualArt == expArt)
    #expect(actualBridge == expBridge)
  }
}

func bruteForceArticulationAndBridges<V: Hashable>(_ g: Graph<V>) -> (Set<V>, Set<Edge<V>>) {
  let compCount = g.components().count
  return (
    g.vertices.filter { v in
      var g1 = g
      g1.remove(vertex: v)
      return g1.components().count > compCount
    },
    g.edgeSet.filter { e in
      var g1 = g
      g1.remove(edge: e)
      return g1.components().count > compCount
    }
  )
}
