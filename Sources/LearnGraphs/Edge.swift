public struct DirectedEdge<V: Hashable>: Hashable {
  public let from: V
  public let to: V

  public init(from: V, to: V) {
    self.from = from
    self.to = to
  }
}

public struct Edge<V: Hashable>: Hashable {
  public let vertices: Set<V>

  public init(_ from: V, _ to: V) {
    self.vertices = Set([from, to])
    precondition(self.vertices.count == 2, "vertices in edge are equal")
  }

  private init(vertices: Set<V>) {
    self.vertices = vertices
  }

  public func map<V1>(_ fn: (V) -> V1) -> Edge<V1> {
    let newSet = Set(vertices.map(fn))
    precondition(newSet.count == 2, "mapping identified vertices that used to be separate")
    return Edge<V1>(vertices: newSet)
  }
}
