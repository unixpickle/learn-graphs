public struct Flow<V: Hashable> {
  /// Flows from each vertex into each neighboring vertex.
  public var flows: [V: [V: Double]]

  /// Compute the total flow out of a source node.
  public func totalFlow(from source: V) -> Double {
    flows[source, default: [:]].values.reduce(0, +)
  }
}

public enum MaxFlowAlgorithm: Sendable {
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

  private func maxFlowLP(from source: V, to destination: V, capacity: (V, V) -> Double) -> Flow<V> {
    let dirEdges = edgeSet.flatMap { edge in
      let vs = Array(edge.vertices)
      return [
        DirectedEdge(from: vs[0], to: vs[1]),
        DirectedEdge(from: vs[1], to: vs[0]),
      ]
    }
    let edgeCapacity = Dictionary(
      uniqueKeysWithValues: dirEdges.map { edge in
        (edge, capacity(edge.from, edge.to))
      }
    )
    let edgeToIdx = Dictionary(uniqueKeysWithValues: dirEdges.enumerated().map { ($0.1, $0.0) })

    var constraints = [Simplex.SparseConstraint]()

    // One slack variable per edge, plus a slack variable for
    // the source and sink
    let varCount = dirEdges.count * 2 + 2
    let sourceVar = dirEdges.count * 2
    let sinkVar = dirEdges.count * 2 + 1

    // Make sure edge capacities are respected
    for (i, dirEdge) in dirEdges.enumerated() {
      let slackIdx = dirEdges.count + i
      constraints.append(
        Simplex.SparseConstraint(
          coeffCount: varCount,
          coeffMap: [i: 1, slackIdx: 1],
          equals: edgeCapacity[dirEdge]!
        )
      )
    }

    // Make sure outgoing and incoming for a vertex are equal
    for v in vertices {
      var coeffs = [Int: Double]()
      for other in neighbors(vertex: v) {
        let outgoing = DirectedEdge(from: v, to: other)
        let incoming = DirectedEdge(from: other, to: v)
        coeffs[edgeToIdx[outgoing]!] = 1.0
        coeffs[edgeToIdx[incoming]!] = -1.0
      }
      if v == source {
        coeffs[sourceVar] = -1.0
      } else if v == destination {
        coeffs[sinkVar] = 1.0
      }
      constraints.append(
        Simplex.SparseConstraint(coeffCount: varCount, coeffMap: coeffs, equals: 0)
      )
    }

    var objective = [Double](repeating: 0, count: varCount)
    objective[sourceVar] = -1.0
    guard
      case .solved(let solution, _) = Simplex.minimize(
        objective: objective, constraints: constraints)
    else {
      fatalError()
    }

    var flows = [V: [V: Double]]()
    for edge in edgeSet {
      let vs = Array(edge.vertices)
      let d1 = DirectedEdge(from: vs[0], to: vs[1])
      let d2 = DirectedEdge(from: vs[1], to: vs[0])
      let d1Flow = solution[edgeToIdx[d1]!] - solution[edgeToIdx[d2]!]
      flows[d1.from, default: [:]][d1.to] = d1Flow
      flows[d2.from, default: [:]][d2.to] = -d1Flow
    }
    return Flow(flows: flows)
  }
}
