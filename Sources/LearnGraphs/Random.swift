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

  /// Create a random k-tree which has cliques of size k+1.
  ///
  /// If deleteProb is specified, randomly delete edges.
  public init<C>(
    randomKTree v: C, k: Int, deleteProb: Double = 0.0, using: inout some RandomNumberGenerator
  ) where C: Collection<V> {
    let orderedV = Array(v)
    self.init(vertices: v)
    precondition(vertices.count >= k + 1)

    var cliques: [[V]] = []
    for i in 0...k {
      cliques.append(Array(orderedV[...k].filter { $0 != orderedV[i] }))
      for j in 0...k {
        if i != j {
          insertEdge(orderedV[i], orderedV[j])
        }
      }
    }

    for i in (k + 1)..<orderedV.count {
      let newNode = orderedV[i]
      let clique = cliques.randomElement(using: &using)!
      for v in clique {
        insertEdge(newNode, v)
        cliques.append(clique.filter { $0 != v } + [newNode])
      }
    }

    if deleteProb > 0 {
      for edge in edgeSet {
        if Double.random(in: 0..<1, using: &using) < deleteProb {
          remove(edge: edge)
        }
      }
    }
  }

  public init<C>(
    randomKTree v: C, k: Int, deleteProb: Double = 0.0
  ) where C: Collection<V> {
    var rng = SystemRandomNumberGenerator()
    self.init(randomKTree: v, k: k, deleteProb: deleteProb, using: &rng)
  }
}
