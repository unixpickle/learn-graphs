import Testing

@testable import LearnGraphs

@Test
func testPlanarEmbeddingCycle() {
  let c = Graph(
    vertices: 0...3,
    edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 0)]
  )
  let emb = PlanarGraph.embed(graph: c)
  let expected1 = PlanarGraph(
    vertices: 0...3,
    adjacencies: [0: [3, 1], 1: [0, 2], 2: [1, 3], 3: [2, 0]]
  )
  let expected2 = PlanarGraph(
    vertices: 0...3,
    adjacencies: [0: [1, 3], 1: [0, 2], 2: [3, 1], 3: [2, 0]]
  )
  #expect(
    emb == [[expected1]] || emb == [[expected1.flipped()]] || emb == [[expected2]]
      || emb == [[expected2.flipped()]])
  #expect(emb?.first?.first?.faces()?.count == 2)
}

@Test
func testPlanarEmbeddingSplitSquare() {
  let c = Graph(
    vertices: 0...3,
    edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 0), Edge(0, 2)]
  )
  let emb = PlanarGraph.embed(graph: c)
  #expect(emb?.count == 1)
  #expect(emb?.first?.count == 1)
  #expect(emb?.first?.first?.faces()?.count == 3)
}

@Test
func testPlanarEmbeddingBothSplitSquare() {
  let c = Graph(
    vertices: 0...3,
    edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 0), Edge(0, 2), Edge(1, 3)]
  )
  let emb = PlanarGraph.embed(graph: c)
  #expect(emb?.count == 1)
  #expect(emb?.first?.count == 1)
  #expect(emb?.first?.first?.faces()?.count == 4)
}

@Test
func testPlanarEmbeddingSpoke() {
  let c = Graph(
    vertices: 0...4,
    edges: [
      Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 0), Edge(4, 0), Edge(4, 1), Edge(4, 2),
      Edge(4, 3),
    ]
  )
  let emb = PlanarGraph.embed(graph: c)
  #expect(emb?.count == 1)
  #expect(emb?.first?.count == 1)
  #expect(emb?.first?.first?.faces()?.count == 5)
}

@Test
func testPlanarEmbeddingK5() {
  let c = Graph(fullyConnected: 0..<5)
  let emb = PlanarGraph.embed(graph: c)
  #expect(emb == nil)
}

@Test
func testPlanarEmbeddingRandom() {
  for _ in 0..<100 {
    let graph = randomPlanarGraph()
    let emb = PlanarGraph.embed(graph: graph)
    #expect(emb != nil && emb!.count == 1, "count: \(emb?.count ?? 0)")
    if emb == nil {
      continue
    }
    let combined = PlanarGraph.mergeBiconnected(emb![0])
    #expect(combined.graph() == graph)
    let faces = combined.faces()
    #expect(faces != nil)
    if faces == nil {
      continue
    }
    let expectedFaceCount = graph.edgeCount - graph.vertices.count + 2
    #expect(expectedFaceCount == faces!.count, "faces.count=\(faces!.count)")
  }
}

@Test(arguments: [TriangulationAlgorithm.greedy, .randomized])
func testPlanarTriangulate(_ algorithm: TriangulationAlgorithm) {
  for _ in 0..<50 {
    let graph = randomPlanarGraph()
    let emb = PlanarGraph.embed(graph: graph)
    #expect(emb != nil && emb!.count == 1, "count: \(emb?.count ?? 0)")
    if emb == nil {
      continue
    }
    let combined = PlanarGraph.mergeBiconnected(emb![0])
    let oldFaces = combined.faces()
    #expect(oldFaces != nil)
    guard let oldFaces = oldFaces else {
      continue
    }
    let triangulated = combined.triangulated(algorithm: algorithm)
    let newFaces = triangulated.faces()
    #expect(newFaces != nil)
    guard let newFaces = newFaces else {
      continue
    }
    #expect(newFaces.count >= oldFaces.count)
    #expect(newFaces.allSatisfy { $0.count <= 4 }, "\(newFaces.map({ $0.count }))")
    let triGraph = triangulated.graph()
    let expectedFaceCount = triGraph.edgeCount - triGraph.vertices.count + 2
    #expect(expectedFaceCount == newFaces.count, "newFaces.count=\(newFaces.count)")
  }
}

func randomPlanarGraph() -> Graph<Int> {
  struct Point: Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    let x: Double
    let y: Double

    // Give callers an easy way to choose random or explicit coordinates
    init(
      x: Double = .random(in: 0..<1),
      y: Double = .random(in: 0..<1)
    ) {
      self.x = x
      self.y = y
    }

    var description: String {
      "(\(x.formatted(.number.precision(.fractionLength(3)))), "
        + "\(y.formatted(.number.precision(.fractionLength(3)))))"
    }

    var debugDescription: String {
      "Point(x: \(x), y: \(y))"
    }
  }

  func edgesIntersect(_ e1: Edge<Point>, _ e2: Edge<Point>, eps: Double = 1e-12) -> Bool {
    func orient(_ a: Point, _ b: Point, _ c: Point) -> Double {
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    let e1Array = Array(e1.vertices)
    let e2Array = Array(e2.vertices)
    let p = e1Array[0]
    let p2 = e1Array[1]
    let q = e2Array[0]
    let q2 = e2Array[1]

    if (p == q && p2 == q2) || (p == q2 && p2 == q) {
      return true
    } else if p == q || p == q2 || p2 == q || p2 == q2 {
      // The edges join at a single vertex
      return false
    }

    let o1 = orient(p, p2, q)
    let o2 = orient(p, p2, q2)
    let o3 = orient(q, q2, p)
    let o4 = orient(q, q2, p2)

    return (o1 * o2 < 0) && (o3 * o4 < 0)
  }

  let vertCount = (5..<20).randomElement()!
  var graph = Graph(
    vertices: (0..<vertCount).map { _ in
      Point()
    }
  )
  var possibleEdges = Set<Edge<Point>>()
  for v1 in graph.vertices {
    for v2 in graph.vertices {
      if v1 != v2 {
        possibleEdges.insert(Edge(v1, v2))
      }
    }
  }

  while graph.components().count > 1 {
    let newEdge = possibleEdges.randomElement()!
    possibleEdges.remove(newEdge)
    possibleEdges = possibleEdges.filter { !edgesIntersect($0, newEdge) }
    graph.insert(edge: newEdge)
  }

  let verts = Array(graph.vertices)
  return graph.map { verts.firstIndex(of: $0)! }
}
