public struct DirectedEdge<V: Hashable>: Hashable {
  public let from: V
  public let to: V

  public init(from: V, to: V) {
    self.from = from
    self.to = to
  }
}

public struct UndirectedEdge<V: Hashable>: Hashable {
  public let vertices: Set<V>

  public init(_ from: V, _ to: V) {
    self.vertices = Set([from, to])
  }
}
