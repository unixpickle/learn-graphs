private let Epsilon: Double = 1e-8

internal class Simplex {
  internal enum PivotRule {
    case greedy
    case bland
  }

  internal struct Constraint {
    let coeffs: [Double]
    let equals: Double

    func setting(_ idx: Int, equalTo: Double) -> Constraint {
      assert(idx > 0 && idx < coeffs.count, "constraint setting argument out of bounds")
      let newCoeffs = Array(coeffs[..<idx] + coeffs[(idx + 1)...])
      let newEquals = equals - coeffs[idx] * equalTo
      return .init(coeffs: newCoeffs, equals: newEquals)
    }
  }

  internal enum Solution {
    case solved(solution: [Double], cost: Double)
    case unbounded
    case infeasible
  }

  /// Minimize an objective subject to equality constraints.
  internal static func minimize(
    objective: [Double], constraints: [Constraint], pivotRule: PivotRule = .bland
  ) -> Solution {
    var table = Table.stage1(varCount: objective.count, constraints: constraints)

    var doneStage1 = false
    while !doneStage1 {
      switch table.step(pivotRule: pivotRule) {
      case .unbounded:
        fatalError("stage 1 should never be unbounded")
      case .success:
        continue
      case .converged:
        doneStage1 = true
      }
    }

    guard var table2 = table.stage2(objective: objective) else {
      return .infeasible
    }
    while true {
      switch table2.step(pivotRule: pivotRule) {
      case .unbounded:
        return .unbounded
      case .success:
        continue
      case .converged:
        return .solved(solution: table2.solution, cost: table2.cost)
      }
    }
  }

  /// Stores the table as
  ///
  ///     [A b]
  ///     [c z]
  ///
  /// Where c is the cost coefficients, z is the current objective value, and
  /// Ax = b.
  internal struct Table {
    internal enum StepResult {
      case success
      case unbounded
      case converged
    }

    private enum Pivot {
      case improvement(entering: Int, leaving: Int)
      case unbounded
      case converged
    }

    let rows: Int
    let cols: Int
    var values: [Double]  // row major order

    // For each constraint row, this indicates which column contains the
    // basic value entry, 1.
    var basicCols: [Int]

    var cost: Double {
      -self[-1, -1]
    }

    var solution: [Double] {
      var result = [Double](repeating: 0.0, count: cols - 1)
      for (row, col) in basicCols.enumerated() {
        result[col] = self[row, -1]
      }
      return result
    }

    init(rows: Int, cols: Int, basicCols: [Int]) {
      assert(basicCols.count + 1 == rows)
      assert(Set(basicCols).count == basicCols.count, "basicCols \(basicCols) is invalid")
      assert(basicCols.allSatisfy { $0 >= 0 && $0 < cols - 1 }, "basicCols \(basicCols) is invalid")
      self.rows = rows
      self.cols = cols
      self.values = [Double](repeating: 0, count: rows * cols)
      self.basicCols = basicCols
    }

    /// Create a table for stage 1, where we add auxiliary variables for each constraint
    /// such that we have an initial basic solution.
    ///
    /// The objective will be to minimize the auxiliary variables, so that none of them are
    /// feasible anymore.
    static func stage1(varCount: Int, constraints: [Constraint]) -> Self {
      var result = Table(
        rows: constraints.count + 1,
        cols: varCount + constraints.count + 1,
        basicCols: Array(varCount..<(varCount + constraints.count))
      )

      for (i, constraint) in constraints.enumerated() {
        assert(
          constraint.coeffs.count == varCount,
          "constraint has \(constraint.coeffs.count) coefficients, but varCount is \(varCount)"
        )
        // Normalize the row by infinity norm.
        let divisor = max(abs(constraint.equals), constraint.coeffs.map(abs).reduce(0, max))

        // Negate a constraint if the rhs is negative, so that the slack
        // variable can be strictly non-negative.
        let mult = (constraint.equals > 0 ? 1.0 : -1.0) / (divisor == 0 ? 1 : divisor)

        for (j, coeff) in constraint.coeffs.enumerated() {
          result[i, j] = coeff * mult
        }
        result[i, -1] = constraint.equals * mult
      }

      // Fill in the identity matrix
      for i in 0..<constraints.count {
        result[i, varCount + i] = 1.0
      }

      // The cost is maximal for basic auxiliary variables.
      for i in varCount..<(result.cols - 1) {
        result[-1, i] = 1.0
      }
      result.eliminateBasicCosts()

      return result
    }

    private subscript(_ i: Int, _ j: Int) -> Double {
      get {
        let i =
          if i < 0 {
            i + rows
          } else {
            i
          }
        let j =
          if j < 0 {
            j + cols
          } else {
            j
          }
        assert(i >= 0 && i < rows && j >= 0 && j < cols, "\(i) \(j) out of bounds \(rows)x\(cols)")
        return values[i * cols + j]
      }
      set {
        let i =
          if i < 0 {
            i + rows
          } else {
            i
          }
        let j =
          if j < 0 {
            j + cols
          } else {
            j
          }
        assert(i >= 0 && i < rows && j >= 0 && j < cols, "\(i) \(j) out of bounds \(rows)x\(cols)")
        values[i * cols + j] = newValue
      }
    }

    mutating func step(pivotRule: PivotRule) -> StepResult {
      switch choosePivot(pivotRule: pivotRule) {
      case .converged:
        return .converged
      case .unbounded:
        return .unbounded
      case .improvement(let entering, let leaving):
        pivot(entering: entering, leaving: leaving)
        return .success
      }
    }

    private mutating func eliminateBasicCosts() {
      for (basicRow, basicCol) in basicCols.enumerated() {
        add(row: basicRow, to: -1, scale: -self[-1, basicCol])
        assert(abs(self[-1, basicCol]) < Epsilon, "elimination did not work")
      }
    }

    private func choosePivot(pivotRule: PivotRule) -> Pivot {
      let entering: Int? =
        switch pivotRule {
        case .bland:
          (0..<(cols - 1)).first(where: { self[-1, $0] < -Epsilon })
        case .greedy:
          (0..<(cols - 1))
            .filter { self[-1, $0] < -Epsilon }
            .min { self[-1, $0] < self[0, $1] }
        }

      guard let enteringCol = entering else {
        return .converged
      }

      guard let leavingCol = chooseLeaving(entering: enteringCol) else {
        return .unbounded
      }

      return .improvement(entering: enteringCol, leaving: leavingCol)
    }

    private func chooseLeaving(entering: Int) -> Int? {
      var minRatio = Double.infinity
      var candidateCol = Int.max

      for i in 0..<(rows - 1) {
        let coeff = self[i, entering]
        if coeff > Epsilon {
          let rhs = self[i, -1]
          let ratio = rhs / coeff
          if ratio < minRatio - Epsilon
            || (abs(ratio - minRatio) <= Epsilon && basicCols[i] < candidateCol)
          {
            minRatio = ratio
            candidateCol = basicCols[i]
          }
        }
      }

      return candidateCol == Int.max ? nil : candidateCol
    }

    private mutating func pivot(entering: Int, leaving: Int) {
      let row = basicCols.firstIndex(of: leaving)!
      basicCols[row] = entering
      scale(row: row, by: 1 / self[row, entering])
      for i in 0..<rows {
        if i == row {
          continue
        }
        add(row: row, to: i, scale: -self[i, entering])
        assert(abs(self[i, entering]) < Epsilon, "elimination did not work")
      }
    }

    private mutating func scale(row: Int, by: Double) {
      for i in 0..<cols {
        self[row, i] *= by
      }
    }

    private mutating func add(row: Int, to: Int, scale: Double) {
      for i in 0..<cols {
        self[to, i] += self[row, i] * scale
      }
    }

    /// Extract a stage2 table for this stage1 table.
    /// Returns nil if stage1 failed to find a feasible solution.
    func stage2(objective: [Double]) -> Table? {
      let constraintCount = rows - 1
      let varCount = cols - 1
      let originalVarCount = varCount - constraintCount

      assert(objective.count == originalVarCount)

      var deleteRows: Set<Int> = []
      for (row, col) in basicCols.enumerated() {
        if col >= originalVarCount {
          // This basic variable should be set to zero, in which case
          // it only remains because an entire row is zero.
          // Otherwise, the solution is infeasible.
          if abs(self[row, -1]) > Epsilon {
            return nil
          }
          assert(
            (0..<originalVarCount).allSatisfy { self[row, $0] < Epsilon },
            "found zero basic variable without zero row; a pivot should have been performed: \((0..<originalVarCount).map { self[row, $0] })"
          )
          deleteRows.insert(row)
        }
      }

      let newRowToOldRow = (0..<rows).filter { !deleteRows.contains($0) }

      // Remove columns for all auxiliary variables
      var result = Table(
        rows: newRowToOldRow.count,
        cols: originalVarCount + 1,
        basicCols: newRowToOldRow[..<(newRowToOldRow.count - 1)].map { basicCols[$0] }
      )
      for (newRow, oldRow) in newRowToOldRow.enumerated() {
        for j in 0..<originalVarCount {
          result[newRow, j] = self[oldRow, j]
        }
        result[newRow, -1] = self[oldRow, -1]
      }

      for (i, x) in objective.enumerated() {
        result[-1, i] = x
      }
      result[-1, -1] = 0
      result.eliminateBasicCosts()

      return result
    }
  }
}
