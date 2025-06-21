/// An adjacency list representation of an undirected multi-graph,
/// where each adjacency can have any positive integer value.
public struct MultiGraph<V: Hashable>: Hashable {
  public var vertices: Set<V>
  public var adjacencies: [V: [V: UInt]]

  public var edges: [Edge<V>: UInt] {
    var result = [Edge<V>: UInt]()
    for (v, adj) in adjacencies {
      for (other, count) in adj {
        result[Edge(v, other), default: 0] += count
      }
    }

    // Every edge was counted from both directions, so divide by 2.
    return result.mapValues { $0 / 2 }
  }

  public var edgeCount: Int {
    Int(adjacencies.values.reduce(0, { $0 + $1.values.reduce(0, +) }) / 2)
  }

  public init() {
    self.vertices = .init()
    self.adjacencies = [:]
  }

  public init<C>(vertices: C, adjacencies: [V: [V: UInt]] = [:]) where C: Collection<V> {
    self.vertices = Set(vertices)
    self.adjacencies = adjacencies
  }

  public init<C, C1>(vertices: C, edges: C1) where C: Collection<V>, C1: Collection<Edge<V>> {
    self.vertices = Set(vertices)
    self.adjacencies = [:]
    for edge in edges {
      self.insertEdge(edge)
    }
  }

  public func map<V1>(_ fn: (V) -> V1) -> MultiGraph<V1> {
    var result = MultiGraph<V1>(vertices: vertices.map(fn))
    for (edge, count) in edges {
      let vs = edge.vertices.map(fn)
      assert(vs[0] != vs[1], "edge is collapsed into a vertex and itself")
      result.insertEdge(Edge(vs[0], vs[1]), count: count)
    }
    return result
  }

  @discardableResult
  public mutating func remove(vertex: V) -> Bool {
    if vertices.remove(vertex) == nil {
      return false
    }
    if let neighbors = adjacencies.removeValue(forKey: vertex)?.keys {
      for neighbor in neighbors {
        adjacencies[neighbor]!.removeValue(forKey: vertex)
        if adjacencies[neighbor]!.isEmpty {
          adjacencies.removeValue(forKey: neighbor)
        }
      }
    }
    return true
  }

  @discardableResult
  public mutating func remove(edge: Edge<V>, count: UInt) -> UInt {
    let vs = Array(edge.vertices)
    return removeEdge(vs[0], vs[1], count: count)
  }

  @discardableResult
  public mutating func removeEdge(_ from: V, _ to: V, count: UInt = 1) -> UInt {
    if let oldCount = adjacencies[from]?[to] {
      let maxDelete = min(count, oldCount)
      if maxDelete == oldCount {
        adjacencies[from]!.removeValue(forKey: to)
        adjacencies[to]!.removeValue(forKey: from)
        if adjacencies[from]!.isEmpty {
          adjacencies.removeValue(forKey: from)
        }
        if adjacencies[to]!.isEmpty {
          adjacencies.removeValue(forKey: to)
        }
      } else {
        adjacencies[from]![to]! -= count
        adjacencies[to]![from]! -= count
      }
      return maxDelete
    } else {
      return 0
    }
  }

  @discardableResult
  public mutating func insert(vertex: V) -> Bool {
    vertices.insert(vertex).inserted
  }

  public mutating func insertEdge(_ from: V, _ to: V, count: UInt = 1) {
    precondition(from != to, "cannot create an edge from a vertex to itself")
    for v in [from, to] {
      if adjacencies[v] == nil {
        adjacencies[v] = [:]
      }
    }
    adjacencies[from]![to, default: 0] += count
    adjacencies[to]![from, default: 0] += count
  }

  public mutating func insertEdge(_ edge: Edge<V>, count: UInt = 1) {
    let items = Array(edge.vertices)
    return insertEdge(items[0], items[1], count: count)
  }

  public func edgesAt(vertex: V) -> [Edge<V>: UInt] {
    Dictionary(
      uniqueKeysWithValues: (adjacencies[vertex] ?? [:]).map { (Edge($0.0, vertex), $0.1) }
    )
  }

  public func contains(edge: Edge<V>) -> Bool {
    let vs = Array(edge.vertices)
    if let a = adjacencies[vs[0]], let c = a[vs[1]], c > 0 {
      return true
    } else {
      return false
    }
  }

  public func contains(vertex: V) -> Bool {
    vertices.contains(vertex)
  }

}
