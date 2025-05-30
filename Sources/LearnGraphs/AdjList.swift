public struct AdjList<V: Hashable> {
  public var vertices: Set<V>
  public var edges: [V: Set<V>]

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

  public mutating func remove(vertex: V) {
    vertices.remove(vertex)
    if let neighbors = edges.removeValue(forKey: vertex) {
      for neighbor in neighbors {
        edges[neighbor]!.remove(neighbor)
        if edges[neighbor]!.isEmpty {
          edges.removeValue(forKey: neighbor)
        }
      }
    }
  }

  public mutating func removeEdge(from: V, to: V) {
    if edges[from]?.remove(to) != nil {
      edges[to]!.remove(from)
    }
  }

  public mutating func insertEdge(from: V, to: V) {
    for v in [from, to] {
      if edges[v] == nil {
        edges[v] = Set()
      }
    }
    edges[from]!.insert(to)
    edges[to]!.insert(from)
  }

}
