private let Epsilon = 1e-5

extension Graph {

  private struct ForcedEdge: Hashable {
    let edge: Edge<V>
    let value: Bool
  }

  private struct SearchNode {
    let forcedEdges: Set<ForcedEdge>
    var constraints: [Simplex.SparseConstraint]
    var costLowerBound: Double
    var solution: [Double]?

    var nonInteger: [Int]? {
      if let s = solution {
        s.enumerated().compactMap { min(abs($0.1), abs($0.1 - 1)) > Epsilon ? $0.0 : nil }
      } else {
        nil
      }
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

    let best = branchAndCut(
      edges: edges,
      edgeCost: edgeCost,
      constraints: constraints,
      logFn: logFn
    )

    // Trace out the cycle.
    let graph = Graph(vertices: vertices, edges: best)
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

  private enum SolveResult {
    case infeasible
    case addedConstraints(Double)
    case solved([Double], Double)
  }

  private func solveWithoutCycles(
    edges: [Edge<V>],
    edgeCost: [Double],
    constraints: inout [Simplex.SparseConstraint],
    logFn: ((String) -> Void)?
  ) -> SolveResult {
    let varCount = constraints.first!.coeffCount
    let extra = varCount - edgeCost.count
    var objective: [Double] = edgeCost + [Double](repeating: 0, count: extra)
    let edgeToIdx = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })
    var (solution, cost): ([Double], Double)
    switch Simplex.minimize(
      objective: objective,
      constraints: constraints,
      pivotRule: .greedyThenBland(100)
    ) {
    case .unbounded:
      fatalError("solution should not be unbounded")
    case .infeasible:
      logFn?("found infeasible problem")
      return .infeasible
    case .solved(let s, let c):
      solution = s
      cost = c
    }
    assert(solution.count >= edges.count)

    let cuts = findBadCuts { edge in solution[edgeToIdx[edge]!] }
    if cuts.isEmpty {
      logFn?("solved LP: cycles=0 cost=\(cost)")
      return .solved(solution, cost)
    }

    logFn?("solved LP: cycles=\(cuts.count) cost=\(cost)")

    for cutVerts in cuts {
      // Add a constraint that the cut cost cannot go under 2
      let slackVarIdx = objective.count
      objective.append(0)
      for i in 0..<constraints.count {
        constraints[i] = constraints[i].addZeroCoeff()
      }

      var coeffs = [Int: Double]()
      for cutEdge in cutSet(vertices: cutVerts) {
        coeffs[edgeToIdx[cutEdge]!] = 1.0
      }
      coeffs[slackVarIdx] = -1
      constraints.append(.init(coeffCount: slackVarIdx + 1, coeffMap: coeffs, equals: 2.0))
    }

    return .addedConstraints(cost)
  }

  private func branchAndCut(
    edges: [Edge<V>],
    edgeCost: [Double],
    constraints: [Simplex.SparseConstraint],
    logFn: ((String) -> Void)?
  ) -> Set<Edge<V>> {
    let edgeToIdx = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })

    var nodes = [SearchNode(forcedEdges: [], constraints: constraints, costLowerBound: 0)]
    var seenTrees: Set<Set<ForcedEdge>> = [[]]

    func sortNodes() {
      nodes.sort {
        if $0.costLowerBound > $1.costLowerBound {
          return true
        } else if $0.costLowerBound < $1.costLowerBound {
          return false
        } else {
          // Prioritize deeper nodes to hit a solution faster.
          return $0.forcedEdges.count > $1.forcedEdges.count
        }
      }
    }

    func addEdgeConstraint(_ sn: SearchNode, edge: Edge<V>, value: Bool) -> SearchNode {
      var newForced = sn.forcedEdges
      newForced.insert(ForcedEdge(edge: edge, value: value))
      var newConstraints = sn.constraints
      newConstraints.append(
        Simplex.SparseConstraint(
          coeffCount: newConstraints[0].coeffCount,
          coeffMap: [edgeToIdx[edge]!: 1.0],
          equals: value ? 1 : 0
        )
      )
      return SearchNode(
        forcedEdges: newForced,
        constraints: newConstraints,
        costLowerBound: sn.costLowerBound
      )
    }

    while var next = nodes.popLast() {
      logFn?(
        "working on node with depth=\(next.forcedEdges.count) constraints=\(next.constraints.count) bound=\(next.costLowerBound)"
      )
      guard let solution = next.solution, let nonInteger = next.nonInteger else {
        // This node hasn't been solved yet; we may need re-insert it
        var feasible = true
        switch solveWithoutCycles(
          edges: edges,
          edgeCost: edgeCost,
          constraints: &next.constraints,
          logFn: logFn
        ) {
        case .infeasible:
          feasible = false
        case .addedConstraints(let cost):
          next.costLowerBound = cost
        case .solved(let solution, let cost):
          next.solution = Array(solution[..<edges.count])
          next.costLowerBound = cost
        }
        if feasible {
          nodes.append(next)
          sortNodes()
        }
        continue
      }

      if nonInteger.isEmpty {
        logFn?("found solution depth=\(next.forcedEdges.count) cost=\(next.costLowerBound) sub-nodes")
        // This is the minimum cost, valid solution.
        return Set(zip(solution, edges).compactMap {
          if $0.0 > 0.5 {
            return $0.1
          } else {
            return nil
          }
        })
      }

      assert(
        Set(nonInteger.map { edges[$0] }).intersection(Set(next.forcedEdges.map { $0.edge })).count == 0,
        "failed to constrain an edge correctly"
      )
      logFn?("branching with \(next.forcedEdges.count * 2) subnodes")
      for varIdx in nonInteger {
        for value in [true, false] {
          let newNode = addEdgeConstraint(next, edge: edges[varIdx], value: value)
          if !seenTrees.contains(newNode.forcedEdges) {
            seenTrees.insert(newNode.forcedEdges)
            nodes.append(newNode)
          }
        }
      }
      sortNodes()
    }

    fatalError("no tour was found")
  }

}
