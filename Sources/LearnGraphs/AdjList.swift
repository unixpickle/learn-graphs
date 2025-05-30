public struct AdjList<V: Hashable> {
  public var vertices: [V: Set<V>]

  public var edgeCount: Int {
    vertices.values.reduce(0, { $0 + $1.count }) / 2
  }

  public init() {
    self.vertices = [:]
  }
}
