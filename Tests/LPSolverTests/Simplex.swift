import Testing

@testable import LPSolver

@Test(arguments: [Simplex.PivotRule.bland, .greedy, .greedyThenBland(2), .devex])
func testSimplexOneSolution2D(pivotRule: Simplex.PivotRule) {
  // There is exactly one solution to this system.
  let constraints: [DenseConstraint] = [
    .init(coeffs: [-3, 4], equals: 5),
    .init(coeffs: [-1, 2], equals: 6),
  ]

  for objective in [[1.0, 1.0], [-1.0, -1.0], [0.0, 0.0]] {
    let solution = Simplex.minimize(
      objective: objective,
      constraints: constraints,
      pivotRule: pivotRule
    )
    #expect(
      solutionsAreClose(
        solution, .solved(solution: [7, 6.5], cost: 7 * objective[0] + 6.5 * objective[1])),
      "\(solution)")
  }
}

@Test(arguments: [Simplex.PivotRule.bland, .greedy, .greedyThenBland(2), .devex])
func testSimplexInfeasible2D(pivotRule: Simplex.PivotRule) {
  // There is a solution here, but it requires x < 0.
  let constraints: [DenseConstraint] = [
    .init(coeffs: [3, 4], equals: 5),
    .init(coeffs: [1, 2], equals: 6),
  ]

  for objective in [[1.0, 1.0], [-1.0, -1.0], [0.0, 0.0]] {
    let solution = Simplex.minimize(
      objective: objective,
      constraints: constraints,
      pivotRule: pivotRule
    )
    #expect(solutionsAreClose(solution, .infeasible), "\(solution)")
  }
}

@Test(arguments: [Simplex.PivotRule.bland, .greedy, .greedyThenBland(2), .devex])
func testSimplexMaybeUnbounded(pivotRule: Simplex.PivotRule) {
  // There are infinite solutions along a line following y = x - 3
  let constraints: [DenseConstraint] = [
    .init(coeffs: [1, -1], equals: 3)
  ]

  var solution = Simplex.minimize(
    objective: [1, 1],
    constraints: constraints,
    pivotRule: pivotRule
  )
  #expect(solutionsAreClose(solution, .solved(solution: [3, 0], cost: 3)), "\(solution)")

  solution = Simplex.minimize(objective: [-1, -1], constraints: constraints, pivotRule: pivotRule)
  #expect(solutionsAreClose(solution, .unbounded), "\(solution)")

  solution = Simplex.minimize(objective: [-1, 2], constraints: constraints, pivotRule: pivotRule)
  #expect(solutionsAreClose(solution, .solved(solution: [3, 0], cost: -3)), "\(solution)")
}

@Test(arguments: [Simplex.PivotRule.bland, .greedy, .greedyThenBland(2), .devex])
func testSimplexRedundant(pivotRule: Simplex.PivotRule) {
  // There are infinite solutions along a line following y = x - 3
  let constraints: [DenseConstraint] = [
    .init(coeffs: [1, -1], equals: 3),
    .init(coeffs: [-1, 1], equals: -3),
  ]

  var solution = Simplex.minimize(
    objective: [1, 1],
    constraints: constraints,
    pivotRule: pivotRule
  )
  #expect(solutionsAreClose(solution, .solved(solution: [3, 0], cost: 3)), "\(solution)")

  solution = Simplex.minimize(
    objective: [-1, -1],
    constraints: constraints,
    pivotRule: pivotRule
  )
  #expect(solutionsAreClose(solution, .unbounded), "\(solution)")

  solution = Simplex.minimize(
    objective: [-1, 2],
    constraints: constraints,
    pivotRule: pivotRule
  )
  #expect(solutionsAreClose(solution, .solved(solution: [3, 0], cost: -3)), "\(solution)")
}

@Test(arguments: [Simplex.PivotRule.bland, .greedy, .greedyThenBland(2), .devex])
func testSimplexClosedPolytope(pivotRule: Simplex.PivotRule) {
  // Create a system of four inequalities that encloses a quadrilateral in the
  // x-y plane.
  let constraints: [DenseConstraint] = [
    .init(coeffs: [1, 1, -1, 0, 0, 0, 0], equals: 2),  // y+x - slack1 = 2 => y+x >= 2
    .init(coeffs: [1, 1, 0, 1, 0, 0, 0], equals: 6),  // y+x + slack2 = 6 => y+x <= 6
    .init(coeffs: [-1, 1, 0, 0, 1, 0, 0], equals: 1),  // y-x + slack3 = 1 => y-x <= 1
    .init(coeffs: [-0.5, 1, 0, 0, 0, -1, 0], equals: 1),  // y-0.5x - slack4 = 1 => y-0.5x >= 1

    // This constraint is redundant, as it lies outside the bounds.
    .init(coeffs: [0, 1, 0, 0, 0, 0, 1], equals: 4),  // y + slack5 = 4 => y <= 4
  ]
  let vertices: [(Double, Double)] = [
    (0.5, 1.5),
    (2.0 / 3.0, 4.0 / 3.0),
    (10.0 / 3.0, 8.0 / 3.0),
    (2.5, 3.5),
  ]

  for _ in 0..<30 {
    let objective = [Double.random(in: -10...10), Double.random(in: -10...10), 0, 0, 0, 0, 0]
    let atEachVertex = vertices.map { $0.0 * objective[0] + $0.1 * objective[1] }
    let minCost = atEachVertex.reduce(Double.infinity, min)
    let bestVertex = vertices[atEachVertex.firstIndex(of: minCost)!]
    let solution = Simplex.minimize(
      objective: objective,
      constraints: constraints,
      pivotRule: pivotRule
    )
    let ok =
      switch solution {
      case .infeasible:
        false
      case .unbounded:
        false
      case .solved(let solution, let cost):
        abs(solution[0] - bestVertex.0) < 1e-5 && abs(solution[1] - bestVertex.1) < 1e-5
          && abs(cost - minCost) < 1e-5
      }
    #expect(ok, "solution=\(solution) expected=\(bestVertex) expectedCost=\(minCost)")
  }
}

@Test
func testSimplexInfeasibleLarge() {
  let constraints = [
    ([0: 1.0, 4: 1.0], 0.709783861128773),
    ([1: 1.0, 5: 1.0], 0.709783861128773),
    ([2: 1.0, 6: 1.0], 0.6779916925187519),
    ([3: 1.0, 7: 1.0], 0.6779916925187519),
    ([8: -1.0], 0.0),
    ([3: 1.0, 9: 1.0, 2: -1.0], 0.0),
    ([0: -1.0, 3: -1.0, 1: 1.0, 2: 1.0], 0.0),
    ([1: -1.0, 0: 1.0], 0.0),
  ].map { SparseConstraint(coeffCount: 10, coeffMap: $0.0, equals: $0.1) }
  var obj = [Double](repeating: 0, count: 10)
  obj[8] = -1
  switch Simplex.minimize(objective: obj, constraints: constraints) {
  case .solved(solution: _, cost: _):
    ()
  case .infeasible:
    #expect(Bool(false))
  case .unbounded:
    #expect(Bool(false))
  }
}

func solutionsAreClose(_ a: Solution, _ b: Solution, tol: Double = 1e-5) -> Bool {
  switch a {
  case .unbounded:
    if case .unbounded = b {
      true
    } else {
      false
    }
  case .infeasible:
    if case .infeasible = b {
      true
    } else {
      false
    }
  case .solved(let solution, let cost):
    if case .solved(solution: let otherSolution, cost: let otherCost) = b {
      zip(solution, otherSolution).allSatisfy { abs($0.0 - $0.1) < tol }
        && abs(cost - otherCost) < tol
    } else {
      false
    }
  }
}
