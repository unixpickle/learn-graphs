import Testing

@testable import LearnGraphs

@Test
func testTutteEmbeddingSpoke() {
  let graph = Graph(
    vertices: 0..<4,
    edges: [Edge(0, 1), Edge(1, 2), Edge(2, 0), Edge(3, 0), Edge(3, 1), Edge(3, 2)]
  )
  let emb = graph.tutteEmbedding(boundary: [
    0: (0.0, 0.0),
    1: (1.0, 1.0),
    2: (0.0, 1.0),
  ])
  #expect(emb != nil)
  guard let emb = emb else {
    return
  }

  let coord3 = emb[3]!
  #expect(abs(coord3.0 - 1.0 / 3.0) < 1e-5)
  #expect(abs(coord3.1 - 2.0 / 3.0) < 1e-5)
}

@Test
func testTutteEmbeddingRandomPlanar() {
  for _ in 0..<50 {
    let graph = randomPlanarGraph()
    let emb = PlanarGraph.embed(graph: graph)
    #expect(emb != nil && emb!.count == 1, "count: \(emb?.count ?? 0)")
    if emb == nil {
      continue
    }
    let combined = PlanarGraph.mergeBiconnected(emb![0])
    let triangulated = combined.triangulated()
    let triGraph = triangulated.graph()
    let boundary = triangulated.faces()!.first!
    assert(boundary.count == 4)
    let triCoords = triGraph.tutteEmbedding(boundary: [
      boundary[0]: (0.0, 0.0),
      boundary[1]: (1.0, 1.0),
      boundary[2]: (0.0, 1.0),
    ])
    #expect(triCoords != nil)
  }
}
