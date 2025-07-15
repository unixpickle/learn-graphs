import LearnGraphs

func randomPlanarGraph(vertCount: Int = 20) -> Graph<Int> {
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
