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
      self.insertEdge(edge)
    }
  }

  public func map<V1>(_ fn: (V) -> V1) -> Graph<V1> {
    Graph<V1>(
      vertices: vertices.map(fn),
      adjacencies: [V1: Set<V1>](
        uniqueKeysWithValues: adjacencies.map { key, value in
          (fn(key), Set(value.map(fn)))
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
  public mutating func insertEdge(_ edge: Edge<V>) -> Bool {
    let items = Array(edge.vertices)
    return insertEdge(items[0], items[1])
  }

}
