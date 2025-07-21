public struct Flow<V: Hashable, C> where C: Comparable, C: AdditiveArithmetic {
  /// Flows from each vertex into each neighboring vertex.
  public var flows: [V: [V: C]]

  /// Compute the total flow out of a source node.
  public func totalFlow(from source: V) -> C {
    flows[source, default: [:]].values.reduce(.zero, +)
  }

  public func flow(from source: V, to dest: V) -> C {
    flows[source, default: [:]][dest, default: .zero]
  }

  public mutating func add(flow: C, from source: V, to dest: V) {
    flows[source, default: [:]][dest, default: .zero] += flow
    flows[dest, default: [:]][source, default: .zero] -= flow
  }

  public mutating func set(flow: C, from source: V, to dest: V) {
    flows[source, default: [:]][dest, default: .zero] = flow
    flows[dest, default: [:]][source, default: .zero] = .zero - flow
  }

  /// Create a graph where we only keep edges that are not at full
  /// flow capacity in one direction or the other.
  public func residual(graph: Graph<V>, capacity: (V, V) -> C) -> Graph<V> {
    Graph(
      vertices: graph.vertices,
      edges: graph.edgeSet.filter { edge in
        let vs = Array(edge.vertices)
        let f1 = flow(from: vs[0], to: vs[1])
        let f2 = flow(from: vs[1], to: vs[0])
        return f1 < capacity(vs[0], vs[1]) && f2 < capacity(vs[1], vs[0])
      }
    )
  }
}

public enum MaxFlowAlgorithm: Sendable {
  case linearProgram
  case edmundsKarp
}

extension Graph {
  /// Compute the maximum flow from source to destination vertices, given a
  /// capacity function from each vertex to neighboring vertices.
  public func maxFlow(
    from source: V,
    to destination: V,
    algorithm: MaxFlowAlgorithm = .edmundsKarp,
    capacity: (V, V) -> Double
  ) -> Flow<V, Double> {
    switch algorithm {
    case .linearProgram:
      maxFlowLP(from: source, to: destination, capacity: capacity)
    case .edmundsKarp:
      maxFlowEK(from: source, to: destination, capacity: capacity)
    }
  }

  private func maxFlowLP(from source: V, to destination: V, capacity: (V, V) -> Double) -> Flow<
    V, Double
  > {
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

  /// Compute the maximum flow using Edmunds-Karp.
  public func maxFlowEK<C>(from source: V, to destination: V, capacity: (V, V) -> C) -> Flow<V, C>
  where C: Comparable, C: AdditiveArithmetic {
    var result = Flow<V, C>(flows: [:])
    while true {
      var foundPath: [V]? = nil
      var queue = [[source]]
      var seen: Set<V> = [source]

      while let path = queue.first {
        queue.remove(at: 0)
        let v = path.last!
        if v == destination {
          foundPath = path
        }
        for neighbor in neighbors(vertex: v) {
          if result.flow(from: v, to: neighbor) < capacity(v, neighbor) {
            if !seen.contains(neighbor) {
              queue.append(path + [neighbor])
              seen.insert(neighbor)
            }
          }
        }
      }

      guard let augPath = foundPath else {
        break
      }

      var increase: C? = nil
      var tightEdges: [DirectedEdge<V>: C] = [:]
      for (v1, v2) in zip(augPath, augPath[1...]) {
        let currentFlow = result.flow(from: v1, to: v2)
        let capacity = capacity(v1, v2)
        let bound = capacity - currentFlow
        if increase == nil || bound < increase! {
          increase = bound
          tightEdges = [DirectedEdge(from: v1, to: v2): capacity]
        } else if bound == increase {
          tightEdges[DirectedEdge(from: v1, to: v2)] = capacity
        }
      }
      guard let increase = increase else { fatalError() }

      for (v1, v2) in zip(augPath, augPath[1...]) {
        if let exactFlow = tightEdges[DirectedEdge(from: v1, to: v2)] {
          // Avoid numerical issues to make sure at least one edge is actually
          // hitting the constraint.
          result.set(flow: exactFlow, from: v1, to: v2)
        } else {
          result.add(flow: increase, from: v1, to: v2)
        }
      }
    }
    return result
  }
}
