extension Graph {
  private class DijkstraNode<C>: Comparable where C: Comparable, C: AdditiveArithmetic {
    let vertex: V
    let totalCost: C
    let parent: DijkstraNode<C>?

    init(vertex: V, totalCost: C, parent: DijkstraNode<C>? = nil) {
      self.vertex = vertex
      self.totalCost = totalCost
      self.parent = parent
    }

    static func < (lhs: DijkstraNode, rhs: DijkstraNode) -> Bool {
      lhs.totalCost < rhs.totalCost
    }

    static func == (lhs: DijkstraNode, rhs: DijkstraNode) -> Bool {
      lhs.totalCost == rhs.totalCost
    }
  }

  /// Finds the shortest path from a vertex to another vertex.
  ///
  /// If no such path exists, returns nil.
  ///
  /// The path includes the start and end nodes.
  public func shortestPath<C>(from: V, to: V, edgeCost: (Edge<V>) -> C) -> [V]?
  where C: Comparable, C: AdditiveArithmetic {
    var queue = [DijkstraNode<C>(vertex: from, totalCost: .zero)]
    var visited: Set<V> = []
    while let next = queue.popHeap() {
      if next.vertex == to {
        var path = [V]()
        var node: DijkstraNode<C>? = next
        while let n = node {
          path.append(n.vertex)
          node = n.parent
        }
        return path.reversed()
      }
      if !visited.contains(next.vertex) {
        visited.insert(next.vertex)
        for other in neighbors(vertex: next.vertex) {
          if visited.contains(other) {
            continue
          }
          let edge = Edge(next.vertex, other)
          let newCost = next.totalCost + edgeCost(edge)
          queue.pushHeap(DijkstraNode(vertex: other, totalCost: newCost, parent: next))
        }
      }
    }
    return nil
  }
}
