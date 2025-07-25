import Testing

@testable import LPSolver

@Test
func testScipyOneSolution2D() {
  // There is exactly one solution to this system.
  let constraints: [DenseConstraint] = [
    .init(coeffs: [-3, 4], equals: 5),
    .init(coeffs: [-1, 2], equals: 6),
  ]

  for objective in [[1.0, 1.0], [-1.0, -1.0], [0.0, 0.0]] {
    let solution = ScipyLPSolver().minimize(
      objective: objective,
      constraints: constraints
    )
    #expect(
      solutionsAreClose(
        solution, .solved(solution: [7, 6.5], cost: 7 * objective[0] + 6.5 * objective[1])),
      "\(solution)")
  }
}

@Test
func testScipyInfeasible2D() {
  // There is a solution here, but it requires x < 0.
  let constraints: [DenseConstraint] = [
    .init(coeffs: [3, 4], equals: 5),
    .init(coeffs: [1, 2], equals: 6),
  ]

  for objective in [[1.0, 1.0], [-1.0, -1.0], [0.0, 0.0]] {
    let solution = ScipyLPSolver().minimize(
      objective: objective,
      constraints: constraints
    )
    #expect(solutionsAreClose(solution, .infeasible), "\(solution)")
  }
}
