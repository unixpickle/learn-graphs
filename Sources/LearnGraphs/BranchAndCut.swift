import LPSolver

private let Epsilon = 1e-5

extension Graph {

  private struct ForcedEdge: Hashable {
    let edge: Edge<V>
    let value: Bool
  }

  private struct SearchNode {
    let forcedEdges: Set<ForcedEdge>
    var constraints: [SparseConstraint]
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
  public func branchAndCutTSP(
    edgeCost: (Edge<V>) -> Double, solver: LPSolver? = nil, logFn: ((String) -> Void)? = nil
  )
    -> [V]
  {
    let solver = solver ?? SimplexLPSolver(pivotRule: .greedyThenBland(200))

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
      return SparseConstraint(coeffCount: edges.count, coeffMap: coeffs, equals: 2.0)
    }

    let best = branchAndCut(
      solver: solver,
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

    let g = Graph(vertices: vertices, edges: edgeSet.filter { edgeCost($0) > Epsilon })
    let tree = g.gomoryHuTree(edgeCost: edgeCost)
    var result: [Set<V>] = []
    for (cut, _, cost) in tree.cuts() {
      if cost < 2 - Epsilon {
        result.append(cut)
      }
    }
    return result
  }

  private func findViolatedBlossom(edgeCost: (Edge<V>) -> Double) -> [(
    handle: Set<V>, teeth: Set<Edge<V>>
  )] {
    // https://www.lancaster.ac.uk/staff/letchfoa/other-publications/2004-IPCO-bmatching.pdf
    let g = Graph(vertices: vertices, edges: edgeSet.filter { edgeCost($0) > Epsilon })
    let tree = g.gomoryHuTree { edge in
      let c = edgeCost(edge)
      return min(c, 1 - c)
    }

    var results: [(handle: Set<V>, teeth: Set<Edge<V>>)] = []
    for (handle, _, _) in tree.cuts() {
      let possibleTeeth = cutSet(vertices: handle).sorted { e1, e2 in
        return edgeCost(e1) > edgeCost(e2)
      }
      var currentCost = possibleTeeth.map(edgeCost).reduce(0, +)
      for (i, tooth) in possibleTeeth.enumerated() {
        currentCost += 1
        currentCost -= edgeCost(tooth) * 2  // Turn the positive into a negative
        if i > 0 && i % 2 == 0 && 1 - currentCost > Epsilon {
          results.append(
            (
              handle: handle,
              teeth: Set(possibleTeeth[...i])
            )
          )
        }
      }
    }

    return results
  }

  private enum SolveResult {
    case infeasible
    case addedConstraints(Double)
    case solved([Double], Double)
  }

  private func solveWithoutCycles(
    solver: LPSolver,
    edges: [Edge<V>],
    edgeCost: [Double],
    constraints: inout [SparseConstraint],
    logFn: ((String) -> Void)?
  ) -> SolveResult {
    let varCount = constraints.first!.coeffCount
    let extra = varCount - edgeCost.count
    var objective: [Double] = edgeCost + [Double](repeating: 0, count: extra)
    let edgeToIdx = Dictionary(uniqueKeysWithValues: edges.enumerated().map { ($0.1, $0.0) })
    var (solution, cost): ([Double], Double)
    switch solver.minimize(objective: objective, constraints: constraints) {
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
    let nonIntegerCount = solution[..<edges.count].count { min($0, 1 - $0) > Epsilon }
    let violatedBlossom: [(handle: Set<V>, teeth: Set<Edge<V>>)] =
      if !cuts.isEmpty || nonIntegerCount == 0 {
        []
      } else {
        findViolatedBlossom(edgeCost: { edge in solution[edgeToIdx[edge]!] })
      }

    logFn?(
      "solved LP: cycles=\(cuts.count) blossom=\(violatedBlossom.count) fractional=\(nonIntegerCount) cost=\(cost)"
    )

    if cuts.isEmpty && violatedBlossom.isEmpty {
      return .solved(solution, cost)
    }

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

    for (handle, teeth) in violatedBlossom {
      // Add a constraint that edges(kept) - edges(teeth) <= 1 - count(teeth)
      let slackVarIdx = objective.count
      objective.append(0)
      for i in 0..<constraints.count {
        constraints[i] = constraints[i].addZeroCoeff()
      }

      let handleEdges = cutSet(vertices: handle)
      let handleKept = handleEdges.subtracting(teeth)

      var coeffs = [Int: Double]()
      for edge in handleKept {
        coeffs[edgeToIdx[edge]!] = 1.0
      }
      for edge in teeth {
        coeffs[edgeToIdx[edge]!] = -1.0
      }
      coeffs[slackVarIdx] = -1
      constraints.append(
        .init(coeffCount: slackVarIdx + 1, coeffMap: coeffs, equals: 1.0 - Double(teeth.count))
      )
    }

    return .addedConstraints(cost)
  }

  private func branchAndCut(
    solver: LPSolver,
    edges: [Edge<V>],
    edgeCost: [Double],
    constraints: [SparseConstraint],
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
        SparseConstraint(
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
          solver: solver,
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
        logFn?(
          "found solution depth=\(next.forcedEdges.count) cost=\(next.costLowerBound) sub-nodes")
        // This is the minimum cost, valid solution.
        return Set(
          zip(solution, edges).compactMap {
            if $0.0 > 0.5 {
              return $0.1
            } else {
              return nil
            }
          })
      }

      assert(
        Set(nonInteger.map { edges[$0] }).intersection(Set(next.forcedEdges.map { $0.edge })).count
          == 0,
        "failed to constrain an edge correctly"
      )
      logFn?(
        "branching with \(next.forcedEdges.count * 2) subnodes and \(nonInteger.count) non-integers"
      )
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
