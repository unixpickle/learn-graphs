public protocol LPSolver {
  func minimize<C: Constraint>(objective: [Double], constraints: [C]) -> Solution
}

public struct SimplexLPSolver: LPSolver {
  public let basic: Set<Int>
  public let pivotRule: Simplex.PivotRule
  public let refactorInterval: Int?

  public init(
    basic: Set<Int> = [], pivotRule: Simplex.PivotRule = .bland, refactorInterval: Int? = nil
  ) {
    self.basic = basic
    self.pivotRule = pivotRule
    self.refactorInterval = refactorInterval
  }

  public func minimize<C: Constraint>(objective: [Double], constraints: [C]) -> Solution {
    Simplex.minimize(
      objective: objective,
      constraints: constraints,
      basic: basic,
      pivotRule: pivotRule,
      refactorInterval: refactorInterval
    )
  }
}
