private let Epsilon = 1e-5

extension Graph {
  /// Solve the traveling salesman problem using a branch-and-bound method.
  ///
  /// The graph must be fully connected.
  ///
  /// The path will always begin and end at the same place.
  public func branchAndBoundTSP(edgeCost: (Edge<V>) -> Double) -> [V] {
    if vertices.count == 0 {
      return []
    } else if vertices.count == 1 {
      return [vertices.first!]
    }
    assert(isFullyConnected, "graph must be dense")

    let edges = Array(edgeSet)
    let edgeCost = edges.map { edgeCost($0) }
    let edgeToIdx = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })

    var constraints = vertices.map { vertex in
      var coeffs = [Double](repeating: 0, count: edges.count * 2)
      for edge in edgesAt(vertex: vertex) {
        coeffs[edgeToIdx[edge]!] = 1.0
      }
      return Simplex.Constraint(coeffs: coeffs, equals: 2.0)
    }

    // Constrain each edge <= 1 using a set of slack variables.
    for i in 0..<edges.count {
      var coeffs = [Double](repeating: 0, count: edges.count * 2)
      coeffs[i] = 1
      coeffs[i + edges.count] = 1
      constraints.append(Simplex.Constraint(coeffs: coeffs, equals: 1.0))
    }

    var best: Set<Edge<V>>?
    var bestCost: Double? = nil
    branchAndBound(
      edges: edges,
      edgeCost: edgeCost,
      constraints: constraints,
      best: &best,
      bestCost: &bestCost
    )

    assert(best != nil, "a solution should have been found; did you pass invalid weights?")

    // Trace out the cycle.
    let graph = Graph(vertices: vertices, edges: best!)
    assert(graph.components().count == 1, "graph should have exactly one component")
    var v = graph.vertices.first!
    var result = [v]
    while let next = graph.neighbors(vertex: v).filter({ !result.contains($0) }).first {
      result.append(next)
      v = next
    }
    result.append(result[0])
    assert(result.count == vertices.count + 1, "result missing vertices")
    return result
  }

  private func solveWithoutCycles(
    edges: [Edge<V>], edgeCost: [Double], constraints: inout [Simplex.Constraint],
    existingEdges: Set<Edge<V>> = [], bound: Double = 0.0
  ) -> [Double]? {
    let extra = constraints.first!.coeffs.count - edgeCost.count
    var objective: [Double] = edgeCost + [Double](repeating: 0, count: extra)
    let edgeToIdx = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })
    while true {
      let (solution, cost): ([Double], Double) =
        switch Simplex.minimize(objective: objective, constraints: constraints) {
        case .unbounded:
          fatalError("solution should not be unbounded")
        case .infeasible:
          fatalError("problem should be feasible")
        case .solved(let solution, let cost):
          (solution, cost)
        }
      if cost > bound {
        return nil
      }
      assert(solution.count >= edges.count)
      let (cutVerts, _, cutCost) = minCostCut { edge in
        if let idx = edgeToIdx[edge] {
          solution[idx]
        } else {
          existingEdges.contains(edge) ? 1.0 : 0.0
        }
      }
      if cutCost >= 2 - Epsilon {
        return solution
      }

      // Add a constraint that the cut cost cannot go under 2
      let slackVarIdx = objective.count
      objective.append(0)
      for i in 0..<constraints.count {
        let old = constraints[i]
        constraints[i] = .init(coeffs: old.coeffs + [0], equals: old.equals)
      }

      var coeffs = [Double](repeating: 0, count: slackVarIdx + 1)
      var equals = 2.0
      for cutEdge in cutSet(vertices: cutVerts) {
        if let idx = edgeToIdx[cutEdge] {
          coeffs[idx] = 1.0
        } else if existingEdges.contains(cutEdge) {
          // We have to remove this constant edge from the constraint.
          equals -= 1
        }
      }
      coeffs[slackVarIdx] = -1
      constraints.append(.init(coeffs: coeffs, equals: equals))
    }
  }

  private func branchAndBound(
    edges: [Edge<V>],
    edgeCost: [Double],
    constraints: [Simplex.Constraint],
    best: inout Set<Edge<V>>?,
    bestCost: inout Double?,
    existingEdges: Set<Edge<V>> = [],
    existingCost: Double = 0.0
  ) {
    var constraints = constraints

    guard
      let fullSolution = solveWithoutCycles(
        edges: edges, edgeCost: edgeCost, constraints: &constraints, existingEdges: existingEdges,
        bound: (bestCost ?? Double.infinity) + existingCost)
    else {
      return
    }

    // Ignore the slack variables in the solution.
    let solution = fullSolution[..<edges.count]

    let nonBinaryIndices = solution.enumerated().filter {
      min(abs($0.1), abs(1 - $0.1)) > Epsilon
    }.map { $0.0 }

    if nonBinaryIndices.count == 0 {
      var chosenEdges: [Edge<V>] = []
      var chosenCost: Double = 0.0
      for (dimension, (edge, cost)) in zip(solution, zip(edges, edgeCost)) {
        if dimension > 1 - Epsilon {
          chosenEdges.append(edge)
          chosenCost += cost
        }
      }
      let totalCost = existingCost + chosenCost
      if bestCost == nil || totalCost < bestCost! {
        best = existingEdges.union(chosenEdges)
        bestCost = totalCost
      }
      return
    }

    // TODO: sort non-binary indices by the ones closest to 0 or 1
    for idx in nonBinaryIndices {
      let edge = edges[idx]
      var newEdges = edges
      var newEdgeCost = edgeCost
      newEdges.remove(at: idx)
      newEdgeCost.remove(at: idx)
      let ordering: [Bool] = solution[idx] > 0.5 ? [true, false] : [false, true]
      for keep in ordering {
        var newExistingEdges = existingEdges
        var newExistingCost = existingCost
        if keep {
          newExistingEdges.insert(edge)
          newExistingCost += edgeCost[idx]
        }
        let newConstraints = constraints.map { $0.setting(idx, equalTo: keep ? 1 : 0) }
        branchAndBound(
          edges: newEdges,
          edgeCost: newEdgeCost,
          constraints: newConstraints,
          best: &best,
          bestCost: &bestCost,
          existingEdges: newExistingEdges,
          existingCost: newExistingCost
        )
      }
    }
  }
}
