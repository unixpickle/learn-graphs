private let Epsilon = 1e-5

extension Graph {

  struct ForcedEdge: Hashable {
    let edge: Edge<V>
    let value: Bool
  }

  class ForcedEdgeTracker {
    var visited: Set<Set<ForcedEdge>> = []

    init() {
    }

    func add(_ v: Set<ForcedEdge>) {
      visited.insert(v)
    }

    func contains(superset: Set<ForcedEdge>) -> Bool {
      for x in visited {
        if superset.isSuperset(of: x) {
          return true
        }
      }
      return false
    }
  }

  /// Solve the traveling salesman problem using a branch-and-cut method.
  ///
  /// The graph must be fully connected.
  ///
  /// The path will always begin and end at the same place.
  public func branchAndCutTSP(edgeCost: (Edge<V>) -> Double, logFn: ((String) -> Void)? = nil)
    -> [V]
  {
    if vertices.count == 0 {
      return []
    } else if vertices.count == 1 {
      return [vertices.first!]
    }
    assert(isFullyConnected, "graph must be dense")

    let edges = Array(edgeSet)
    let edgeCost = edges.map { edgeCost($0) }
    let edgeToIdx = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })

    let constraints = vertices.map { vertex in
      var coeffs = [Int: Double]()
      for edge in edgesAt(vertex: vertex) {
        coeffs[edgeToIdx[edge]!] = 1.0
      }
      return Simplex.SparseConstraint(coeffCount: edges.count, coeffMap: coeffs, equals: 2.0)
    }

    var best: Set<Edge<V>>?
    var bestCost: Double? = nil
    branchAndCut(
      edges: edges,
      edgeCost: edgeCost,
      constraints: constraints,
      best: &best,
      bestCost: &bestCost,
      logFn: logFn
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

  private func findBadCuts(edgeCost: (Edge<V>) -> Double) -> [Set<V>] {
    let overweightEdges = edgeSet.filter { edgeCost($0) > 1 + Epsilon }
    if !overweightEdges.isEmpty {
      // First we focus on constraining individual edges before cycles
      return overweightEdges.map { $0.vertices }
    }

    let (cutVerts, _, cutCost) = minCostCut(edgeCost: edgeCost)
    if cutCost >= 2 - Epsilon {
      return []
    }
    if cutCost > Epsilon {
      return [cutVerts]
    }
    // We have a disjoint component, so we should explore sub-cuts.
    var g1 = self
    let (g2, _) = g1.cut(vertices: cutVerts)
    return [cutVerts] + g1.findBadCuts(edgeCost: edgeCost) + g2.findBadCuts(edgeCost: edgeCost)
  }

  private func solveWithoutCycles(
    edges: [Edge<V>],
    edgeCost: [Double],
    constraints: inout [Simplex.SparseConstraint],
    logFn: ((String) -> Void)?,
    existingEdges: Set<Edge<V>> = [],
    existingCost: Double = 0.0,
    bound: Double = 0.0
  ) -> [Double]? {
    logFn?("solving with \(constraints.count) initial constraints")
    let varCount = constraints.first!.coeffCount
    let extra = varCount - edgeCost.count
    var objective: [Double] = edgeCost + [Double](repeating: 0, count: extra)
    let edgeToIdx = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })
    while true {
      var (solution, cost): ([Double], Double)
      switch Simplex.minimize(
        objective: objective,
        constraints: constraints,
        pivotRule: .greedyThenBland(100)
      ) {
      case .unbounded:
        fatalError("solution should not be unbounded")
      case .infeasible:
        //fatalError("problem should be feasible")
        return nil
      case .solved(let s, let c):
        solution = s
        cost = c + existingCost
      }
      if cost > bound {
        logFn?("cost \(cost) is higher than bound \(bound)")
        return nil
      }
      assert(solution.count >= edges.count)

      let cuts = findBadCuts { edge in
        if let idx = edgeToIdx[edge] {
          solution[idx]
        } else {
          existingEdges.contains(edge) ? 1.0 : 0.0
        }
      }
      if cuts.isEmpty {
        logFn?("found solution without cycles")
        return solution
      }

      logFn?("found \(cuts.count) bad cuts to add constraints for; lower bound is \(cost)")

      for cutVerts in cuts {
        // Add a constraint that the cut cost cannot go under 2
        let slackVarIdx = objective.count
        objective.append(0)
        for i in 0..<constraints.count {
          constraints[i] = constraints[i].addZeroCoeff()
        }

        var coeffs = [Int: Double]()
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
        constraints.append(.init(coeffCount: slackVarIdx + 1, coeffMap: coeffs, equals: equals))
      }
    }
  }

  private func branchAndCut(
    edges: [Edge<V>],
    edgeCost: [Double],
    constraints: [Simplex.SparseConstraint],
    best: inout Set<Edge<V>>?,
    bestCost: inout Double?,
    logFn: ((String) -> Void)?,
    existingEdges: Set<Edge<V>> = [],
    existingCost: Double = 0.0,
    forcedEdges: Set<ForcedEdge> = [],
    tracker: ForcedEdgeTracker = .init()
  ) {
    if tracker.contains(superset: forcedEdges) {
      logFn?("skipping visited constraints")
      return
    }
    var constraints = constraints

    guard
      let fullSolution = solveWithoutCycles(
        edges: edges,
        edgeCost: edgeCost,
        constraints: &constraints,
        logFn: logFn,
        existingEdges: existingEdges,
        existingCost: existingCost,
        bound: bestCost ?? Double.infinity
      )
    else {
      tracker.add(forcedEdges)
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
      logFn?("found valid solution with cost \(totalCost)")
      if bestCost == nil || totalCost < bestCost! {
        best = existingEdges.union(chosenEdges)
        bestCost = totalCost
      }
      tracker.add(forcedEdges)
      return
    }

    // Focus on the "least binary" variables first
    let sortedIdxs = nonBinaryIndices.sorted {
      abs(0.5 - solution[$0]) < abs(0.5 - solution[$1])
    }

    logFn?("branching on non-binary variables: \(sortedIdxs)")
    for idx in sortedIdxs {
      let edge = edges[idx]
      var newEdges = edges
      var newEdgeCost = edgeCost
      var newGraph = self
      newEdges.remove(at: idx)
      newEdgeCost.remove(at: idx)
      for keep in [true, false] {
        logFn?("fixing edge \(idx) with initial value \(solution[idx]) to \(keep)")
        var newExistingEdges = existingEdges
        var newExistingCost = existingCost
        if keep {
          newExistingEdges.insert(edge)
          newExistingCost += edgeCost[idx]
        } else {
          newGraph.remove(edge: edge)
        }
        let newConstraints = constraints.map {
          $0.setting(idx, equalTo: keep ? 1 : 0)
        }
        let newForcedEdges = forcedEdges.union([ForcedEdge(edge: edges[idx], value: keep)])
        newGraph.branchAndCut(
          edges: newEdges,
          edgeCost: newEdgeCost,
          constraints: newConstraints,
          best: &best,
          bestCost: &bestCost,
          logFn: logFn,
          existingEdges: newExistingEdges,
          existingCost: newExistingCost,
          forcedEdges: newForcedEdges,
          tracker: tracker
        )
      }
    }
    logFn?("completed branching for \(nonBinaryIndices)")
    tracker.add(forcedEdges)
  }

}
