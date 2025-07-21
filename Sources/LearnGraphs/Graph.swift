/// An adjacency list representation of an undirected graph.
public struct Graph<V: Hashable>: Hashable {
  public var vertices: Set<V>
  public var adjacencies: [V: Set<V>]

  public var edgeSet: Set<Edge<V>> {
    Set(adjacencies.flatMap { kv in kv.1.map { x in Edge(kv.0, x) } })
  }

  public var edgeCount: Int {
    adjacencies.values.reduce(0, { $0 + $1.count }) / 2
  }

  public var isFullyConnected: Bool {
    edgeCount == (vertices.count - 1) * vertices.count / 2
  }

  public init() {
    self.vertices = .init()
    self.adjacencies = [:]
  }

  public init<C>(vertices: C, adjacencies: [V: Set<V>] = [:]) where C: Collection<V> {
    self.vertices = Set(vertices)
    self.adjacencies = adjacencies
  }

  public init<C, C1>(vertices: C, edges: C1) where C: Collection<V>, C1: Collection<Edge<V>> {
    self.vertices = Set(vertices)
    self.adjacencies = [:]
    for edge in edges {
      self.insert(edge: edge)
    }
  }

  public init<C: Collection<V>>(fullyConnected: C) {
    self.vertices = Set(fullyConnected)
    self.adjacencies = [:]
    for v1 in self.vertices {
      for v2 in self.vertices {
        if v1 != v2 {
          insertEdge(v1, v2)
        }
      }
    }
  }

  public func map<V1>(_ fn: (V) -> V1) -> Graph<V1> {
    let vertMapping = Dictionary(
      uniqueKeysWithValues: vertices.map { ($0, fn($0)) }
    )
    return Graph<V1>(
      vertices: vertices.map { vertMapping[$0]! },
      adjacencies: [V1: Set<V1>](
        uniqueKeysWithValues: adjacencies.map { key, value in
          (vertMapping[key]!, Set(value.map { x in vertMapping[x]! }))
        }
      )
    )
  }

  @discardableResult
  public mutating func remove(vertex: V) -> Bool {
    if vertices.remove(vertex) == nil {
      return false
    }
    if let neighbors = adjacencies.removeValue(forKey: vertex) {
      for neighbor in neighbors {
        adjacencies[neighbor]!.remove(vertex)
        if adjacencies[neighbor]!.isEmpty {
          adjacencies.removeValue(forKey: neighbor)
        }
      }
    }
    return true
  }

  @discardableResult
  public mutating func remove(edge: Edge<V>) -> Bool {
    let vs = Array(edge.vertices)
    return removeEdge(vs[0], vs[1])
  }

  @discardableResult
  public mutating func removeEdge(_ from: V, _ to: V) -> Bool {
    if adjacencies[from]?.remove(to) != nil {
      adjacencies[to]!.remove(from)
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
    precondition(from != to, "cannot create an edge from a vertex to itself")
    for v in [from, to] {
      if adjacencies[v] == nil {
        adjacencies[v] = Set()
      }
    }
    adjacencies[from]!.insert(to)
    return adjacencies[to]!.insert(from).inserted
  }

  @discardableResult
  public mutating func insert(edge: Edge<V>) -> Bool {
    let items = Array(edge.vertices)
    return insertEdge(items[0], items[1])
  }

  public func neighbors(vertex: V) -> Set<V> {
    adjacencies[vertex] ?? Set()
  }

  public func edgesAt(vertex: V) -> Set<Edge<V>> {
    return Set((adjacencies[vertex] ?? []).map { Edge($0, vertex) })
  }

  public func edgesAt<C>(vertices: C) -> Set<Edge<V>> where C: Collection<V> {
    return Set(vertices.flatMap { edgesAt(vertex: $0) })
  }

  public func contains(edge: Edge<V>) -> Bool {
    let vs = Array(edge.vertices)
    if let a = adjacencies[vs[0]], a.contains(vs[1]) {
      return true
    } else {
      return false
    }
  }

  public func contains(vertex: V) -> Bool {
    vertices.contains(vertex)
  }

  public mutating func filterVertices(_ c: (V) -> Bool) {
    vertices = Set(vertices.filter { c($0) })
    adjacencies = Dictionary(
      uniqueKeysWithValues: adjacencies.filter {
        vertices.contains($0.0)
      }.map {
        ($0.0, $0.1.intersection(vertices))
      }
    )
  }

  public func filteringVertices(_ c: (V) -> Bool) -> Self {
    var result = self
    result.filterVertices(c)
    return result
  }

}
