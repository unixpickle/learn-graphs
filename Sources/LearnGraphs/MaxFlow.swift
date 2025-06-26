public struct Flow<V: Hashable> {
  /// Flows from each vertex into each neighboring vertex.
  public var flows: [V: [V: Double]]
}

public enum MaxFlowAlgorithm {
  case linearProgram
}

extension Graph {
  /// Compute the maximum flow from source to destination vertices, given a
  /// capacity function from each vertex to neighboring vertices.
  public func maxFlow(
    from source: V,
    to destination: V,
    algorithm: MaxFlowAlgorithm,
    capacity: (V, V) -> Double
  ) -> Flow<V> {
    switch algorithm {
    case .linearProgram:
      maxFlowLP(from: source, to: destination, capacity: capacity)
    }
  }

  private func maxFlowLP(from source: V, to destination: V, capacity: (V, V) -> Double) -> Flow {
    var dirEdges = edgeSet.map { edge in
      let vs = Array(edge.vertices)
      return DirectedEdge(from: vs[0], to: vs[1])
    }
    var edgeCapacity = Dictionary(
      uniqueKeysWithValues: dirEdges.map { edge in
        (edge, capacity(edge.from, edge.to))
      }
    )
    var edgeToIdx = Dictionary(uniqueKeysWithValues: dirEdges.enumerated().map { ($0.1, $0.0) })

    var constraints = [Simplex.Constraint]()

    // Make sure edge capacities are respected
    for (i, dirEdge) in dirEdges.enumerated() {
      constraints.append(Simplex.SparseConstraint(coeffCount: dirEdges.count, coeffMap: [i: ]))
    }
  }
}
