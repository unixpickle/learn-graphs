import Testing

@testable import LearnGraphs

@Test
func testEulerianCycleSimple() {
  var g = Graph(
    vertices: 0..<3,
    edges: [Edge(0, 1), Edge(1, 2), Edge(2, 0)]
  )
  for i in 0..<3 {
    let cycle = g.eulerianCycle(start: i)
    expectEulerianCycle(graph: MultiGraph(g), cycle: cycle)
  }
  g.removeEdge(0, 1)
  for i in 0..<3 {
    let cycle = g.eulerianCycle(start: i)
    #expect(cycle == nil)
  }
}

@Test(arguments: [11, 21])
func testEulerianCycleRandom(vertexCount: Int) {
  // Create a random even graph that has one component.
  var g: Graph<Int>
  while true {
    g = Graph(random: 0..<vertexCount, edgeProb: 0.1)
    let oddVertices: Array = g.vertices.filter { g.neighbors(vertex: $0).count % 2 == 1 }
    for i in stride(from: 0, to: oddVertices.count, by: 2) {
      let (v1, v2) = (oddVertices[i], oddVertices[i + 1])
      if !g.insertEdge(v1, v2) {
        g.removeEdge(v1, v2)
      }
    }
    if g.components().count == 1 {
      break
    }
  }

  for start in g.vertices {
    let cycle = g.eulerianCycle(start: start)
    expectEulerianCycle(graph: MultiGraph(g), cycle: cycle)
  }

  g.remove(edge: g.edgeSet.first!)
  for start in g.vertices {
    #expect(g.eulerianCycle(start: start) == nil)
  }
}

@Test(arguments: [11, 21])
func testEulerianCycleRandomMultigraph(vertexCount: Int) {
  // Create a random even graph that has one component.
  var g: MultiGraph<Int>
  while true {
    g = MultiGraph(Graph(random: 0..<vertexCount, edgeProb: 0.1))
    let oddVertices: Array = g.vertices.filter { g.edgesAt(vertex: $0).count % 2 == 1 }
    for i in stride(from: 0, to: oddVertices.count, by: 2) {
      let (v1, v2) = (oddVertices[i], oddVertices[i + 1])
      g.insertEdge(v1, v2)
    }

    // Make sure we have one component, but are also leveraging the
    // fact that this is a multigraph.
    let singleGraph = Graph(vertices: g.vertices, edges: g.edges.keys)
    if singleGraph.components().count == 1 && singleGraph.edgeCount < g.edgeCount {
      break
    }
  }

  for start in g.vertices {
    let cycle = g.eulerianCycle(start: start)
    expectEulerianCycle(graph: g, cycle: cycle)
  }

  g.remove(edge: g.edges.keys.first!)
  for start in g.vertices {
    #expect(g.eulerianCycle(start: start) == nil)
  }
}

func expectEulerianCycle<V: Hashable>(graph: MultiGraph<V>, cycle: [V]?) {
  guard let cycle = cycle else {
    #expect(cycle != nil)
    return
  }
  #expect(cycle.first! == cycle.last!)
  var g = graph
  var seenVertices = Set<V>()
  for (i, x) in cycle[..<(cycle.count - 1)].enumerated() {
    #expect(g.removeEdge(x, cycle[i + 1]) == 1)
    seenVertices.insert(x)
  }
  #expect(seenVertices == graph.vertices)
  #expect(g.edgeCount == 0)
}
