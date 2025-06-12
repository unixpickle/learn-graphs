extension Graph {
  public init<C>(
    random: C, edgeProb: Double, using: inout some RandomNumberGenerator
  ) where C: Collection<V> {
    self.init(vertices: Array(random))
    for (i, v) in random.enumerated() {
      for (j, v1) in random.enumerated() {
        if j <= i {
          continue
        }
        if Double.random(in: 0.0..<1.0, using: &using) < edgeProb {
          insertEdge(v, v1)
        }
      }
    }
  }

  public init<C>(random: C, edgeProb: Double) where C: Collection<V> {
    var rng = SystemRandomNumberGenerator()
    self.init(random: random, edgeProb: edgeProb, using: &rng)
  }

  public init<C>(random: C, edgeCount: Int, using: inout some RandomNumberGenerator)
  where C: Collection<V> {
    self.init(vertices: Array(random))

    var allEdges: Set<DirectedEdge<V>> = .init()
    for (i, v) in random.enumerated() {
      for (j, v1) in random.enumerated() {
        if j <= i {
          continue
        }
        allEdges.insert(DirectedEdge(from: v, to: v1))
      }
    }
    assert(
      allEdges.count >= edgeCount,
      "edgeCount \(edgeCount) is more than total edge count \(allEdges.count)"
    )
    for _ in 0..<edgeCount {
      guard let x = allEdges.randomElement(using: &using) else {
        fatalError("requested edgeCount \(edgeCount) is greater than the maximum number of edges")
      }
      allEdges.remove(x)
      insertEdge(x.from, x.to)
    }
  }

  public init<C>(random: C, edgeCount: Int) where C: Collection<V> {
    var rng = SystemRandomNumberGenerator()
    self.init(random: random, edgeCount: edgeCount, using: &rng)
  }
}
