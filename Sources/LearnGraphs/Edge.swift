public struct DirectedEdge<V: Hashable>: Hashable {
  public let from: V
  public let to: V

  public init(from: V, to: V) {
    self.from = from
    self.to = to
  }
}

public struct UndirectedEdge<V: Hashable>: Hashable {
  let from: V
  let to: V

  public var vertices: Set<V> { Set([from, to]) }

  public init(_ from: V, _ to: V) {
    self.from = from
    self.to = to
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(vertices)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    (lhs.from == rhs.from && lhs.to == rhs.to) || (lhs.from == rhs.to && lhs.to == rhs.from)
  }
}
