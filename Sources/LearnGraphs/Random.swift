private struct Pair<V: Hashable>: Hashable {
  let x: V
  let y: V
}

extension AdjList {
  public init<C>(
    random: C, edgeProb: Double, using: inout RandomNumberGenerator
  ) where C: Collection<V> {
    self.init()
    for (i, v) in random.enumerated() {
      for (j, v1) in random.enumerated() {
        if j <= i {
          continue
        }
        if Double.random(in: 0.0..<1.0, using: &using) < edgeProb {
          insertEdge(from: v, to: v1)
        }
      }
    }
  }

  public init<C>(random: C, edgeProb: Double) where C: Collection<V> {
    self.init()
    for (i, v) in random.enumerated() {
      for (j, v1) in random.enumerated() {
        if j <= i {
          continue
        }
        if Double.random(in: 0.0..<1.0) < edgeProb {
          insertEdge(from: v, to: v1)
        }
      }
    }
  }

  public init<C>(random: C, edgeCount: Int, using: inout RandomNumberGenerator)
  where C: Collection<V> {
    self.init()

    var allEdges: Set<Pair<V>> = .init()
    for (i, v) in random.enumerated() {
      for (j, v1) in random.enumerated() {
        if j <= i {
          continue
        }
        allEdges.insert(Pair(x: v, y: v1))
      }
    }
    for _ in 0..<edgeCount {
      guard let x = allEdges.randomElement(using: &using) else {
        fatalError("requested edgeCount \(edgeCount) is greater than the maximum number of edges")
      }
      allEdges.remove(x)
      insertEdge(from: x.x, to: x.y)
    }
  }

  public init<C>(random: C, edgeCount: Int) where C: Collection<V> {
    self.init()

    var allEdges: Set<Pair<V>> = .init()
    for (i, v) in random.enumerated() {
      for (j, v1) in random.enumerated() {
        if j <= i {
          continue
        }
        allEdges.insert(Pair(x: v, y: v1))
      }
    }
    for _ in 0..<edgeCount {
      guard let x = allEdges.randomElement() else {
        fatalError("requested edgeCount \(edgeCount) is greater than the maximum number of edges")
      }
      insertEdge(from: x.x, to: x.y)
      allEdges.remove(x)
    }
  }

  public mutating func insertEdge(from: V, to: V) {
    for v in [from, to] {
      if vertices[v] == nil {
        vertices[v] = Set()
      }
    }
    vertices[from]!.insert(to)
    vertices[to]!.insert(from)
  }
}
