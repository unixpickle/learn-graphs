import Testing

@testable import LearnGraphs

@Test
func testSimplexOneSolution2D() {
  // There is exactly one solution to this system.
  let constraints: [Simplex.Constraint] = [
    .init(coeffs: [-3, 4], equals: 5),
    .init(coeffs: [-1, 2], equals: 6),
  ]

  for objective in [[1.0, 1.0], [-1.0, -1.0], [0.0, 0.0]] {
    let solution = Simplex.minimize(objective: objective, constraints: constraints)
    #expect(
      solutionsAreClose(
        solution, .solved(solution: [7, 6.5], cost: 7 * objective[0] + 6.5 * objective[1])),
      "\(solution)")
  }
}

@Test
func testSimplexInfeasible2D() {
  // There is a solution here, but it requires x < 0.
  let constraints: [Simplex.Constraint] = [
    .init(coeffs: [3, 4], equals: 5),
    .init(coeffs: [1, 2], equals: 6),
  ]

  for objective in [[1.0, 1.0], [-1.0, -1.0], [0.0, 0.0]] {
    let solution = Simplex.minimize(objective: objective, constraints: constraints)
    #expect(solutionsAreClose(solution, .infeasible), "\(solution)")
  }
}

@Test
func testSimplexMaybeUnbounded() {
  // There are infinite solutions along a line following y = x - 3
  let constraints: [Simplex.Constraint] = [
    .init(coeffs: [1, -1], equals: 3)
  ]

  var solution = Simplex.minimize(objective: [1, 1], constraints: constraints)
  #expect(solutionsAreClose(solution, .solved(solution: [3, 0], cost: 3)), "\(solution)")

  solution = Simplex.minimize(objective: [-1, -1], constraints: constraints)
  #expect(solutionsAreClose(solution, .unbounded), "\(solution)")

  solution = Simplex.minimize(objective: [-1, 2], constraints: constraints)
  #expect(solutionsAreClose(solution, .solved(solution: [3, 0], cost: -3)), "\(solution)")
}

@Test
func testSimplexRedundant() {
  // There are infinite solutions along a line following y = x - 3
  let constraints: [Simplex.Constraint] = [
    .init(coeffs: [1, -1], equals: 3),
    .init(coeffs: [-1, 1], equals: -3),
  ]

  var solution = Simplex.minimize(objective: [1, 1], constraints: constraints)
  #expect(solutionsAreClose(solution, .solved(solution: [3, 0], cost: 3)), "\(solution)")

  solution = Simplex.minimize(objective: [-1, -1], constraints: constraints)
  #expect(solutionsAreClose(solution, .unbounded), "\(solution)")

  solution = Simplex.minimize(objective: [-1, 2], constraints: constraints)
  #expect(solutionsAreClose(solution, .solved(solution: [3, 0], cost: -3)), "\(solution)")
}

@Test
func testSimplexClosedPolytope() {
  // Create a system of four inequalities that encloses a quadrilateral in the
  // x-y plane.
  let constraints: [Simplex.Constraint] = [
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
    let solution = Simplex.minimize(objective: objective, constraints: constraints)
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

func solutionsAreClose(_ a: Simplex.Solution, _ b: Simplex.Solution, tol: Double = 1e-5) -> Bool {
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
