public struct AdjList<V: Hashable> {
  public var vertices: Set<V>
  public var edges: [V: Set<V>]

  public var edgeSet: Set<UndirectedEdge<V>> {
    Set(edges.flatMap { kv in kv.1.map { x in UndirectedEdge(kv.0, x) } })
  }

  public var edgeCount: Int {
    edges.values.reduce(0, { $0 + $1.count }) / 2
  }

  public init() {
    self.vertices = .init()
    self.edges = [:]
  }

  public init<C>(vertices: C, edges: [V: Set<V>] = [:]) where C: Collection<V> {
    self.vertices = Set(vertices)
    self.edges = edges
  }

  @discardableResult
  public mutating func remove(vertex: V) -> Bool {
    if vertices.remove(vertex) == nil {
      return false
    }
    if let neighbors = edges.removeValue(forKey: vertex) {
      for neighbor in neighbors {
        edges[neighbor]!.remove(neighbor)
        if edges[neighbor]!.isEmpty {
          edges.removeValue(forKey: neighbor)
        }
      }
    }
    return true
  }

  @discardableResult
  public mutating func removeEdge(_ from: V, _ to: V) -> Bool {
    if edges[from]?.remove(to) != nil {
      edges[to]!.remove(from)
      return true
    } else {
      return false
    }
  }

  @discardableResult
  public mutating func insert(vertex: V) -> Bool {
    vertices.insert(vertex).inserted
  }

  @discardableResult
  public mutating func insertEdge(_ from: V, _ to: V) -> Bool {
    for v in [from, to] {
      if edges[v] == nil {
        edges[v] = Set()
      }
    }
    edges[from]!.insert(to)
    return edges[to]!.insert(from).inserted
  }

}
