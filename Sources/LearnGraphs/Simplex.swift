import Accelerate

private let Epsilon: Double = 1e-8

internal class Simplex {
  internal enum PivotRule {
    case greedy
    case bland
    case devex
    case greedyThenBland(Int)
  }

  internal protocol Constraint {
    func coeffs() -> [Double]
    func equals() -> Double
  }

  internal struct DenseConstraint: Constraint {
    let rawCoeffs: [Double]
    let rawEquals: Double

    init(coeffs: [Double], equals: Double) {
      rawCoeffs = coeffs
      rawEquals = equals
    }

    func setting(_ idx: Int, equalTo: Double) -> Self {
      assert(idx > 0 && idx < rawCoeffs.count, "constraint setting argument out of bounds")
      let newCoeffs = Array(rawCoeffs[..<idx] + rawCoeffs[(idx + 1)...])
      let newEquals = rawEquals - rawCoeffs[idx] * equalTo
      return .init(coeffs: newCoeffs, equals: newEquals)
    }

    func coeffs() -> [Double] {
      rawCoeffs
    }

    func equals() -> Double {
      rawEquals
    }
  }

  internal struct SparseConstraint: Constraint {
    let coeffCount: Int
    let coeffMap: [Int: Double]
    let rawEquals: Double

    init(coeffCount: Int, coeffMap: [Int: Double], equals: Double) {
      self.coeffCount = coeffCount
      self.coeffMap = coeffMap
      self.rawEquals = equals
    }

    func setting(_ idx: Int, equalTo: Double) -> Self {
      assert(idx > 0 && idx < coeffCount, "constraint setting argument out of bounds")
      let newCoeffs = Dictionary(
        uniqueKeysWithValues: coeffMap.compactMap { iv in
          if iv.0 < idx {
            iv
          } else if iv.0 == idx {
            nil
          } else {
            (iv.0 - 1, iv.1)
          }
        })
      let newEquals = rawEquals - coeffMap[idx, default: 0] * equalTo
      return .init(coeffCount: coeffCount - 1, coeffMap: newCoeffs, equals: newEquals)
    }

    func addZeroCoeff() -> Self {
      .init(coeffCount: coeffCount + 1, coeffMap: coeffMap, equals: rawEquals)
    }

    func coeffs() -> [Double] {
      var result = [Double](repeating: 0, count: coeffCount)
      for (i, x) in coeffMap {
        result[i] = x
      }
      return result
    }

    func equals() -> Double {
      rawEquals
    }
  }

  internal enum Solution {
    case solved(solution: [Double], cost: Double)
    case unbounded
    case infeasible
  }

  /// Minimize an objective subject to equality constraints.
  internal static func minimize<C: Constraint>(
    objective: [Double],
    constraints: [C],
    basic: Set<Int> = [],
    pivotRule: PivotRule = .bland,
    refactorInterval: Int? = nil
  ) -> Solution {
    var table = Table.stage1(varCount: objective.count, constraints: constraints, basic: basic)
    var tableStart = table

    var doneStage1 = false
    var step = 0
    while !doneStage1 {
      switch table.step(pivotRule: pivotRule) {
      case .unbounded:
        fatalError("stage 1 should never be unbounded")
      case .success:
        step += 1
        if let ival = refactorInterval, step % ival == 0 {
          table.refactor(original: tableStart)
        }
        continue
      case .converged:
        doneStage1 = true
      }
    }
    table.finishStage1()

    guard var table2 = table.stage2(objective: objective) else {
      return .infeasible
    }
    tableStart = table2
    step = 0
    while true {
      switch table2.step(pivotRule: pivotRule) {
      case .unbounded:
        return .unbounded
      case .success:
        step += 1
        if let ival = refactorInterval, step % ival == 0 {
          table2.refactor(original: tableStart)
        }
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

    // Used for greedyThenBland pivot rule
    var costHistory: [Double] = []
    var switchedToBland: Bool = false

    // Used for the devex decision rule
    var devexCoeffs: [Double]? = nil

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
    static func stage1<C: Constraint>(varCount: Int, constraints: [C], basic: Set<Int> = []) -> Self
    {
      var result = Table(
        rows: constraints.count + 1,
        cols: varCount + constraints.count + 1,
        basicCols: Array(varCount..<(varCount + constraints.count))
      )

      for (i, constraint) in constraints.enumerated() {
        let coeffs = constraint.coeffs()
        let equals = constraint.equals()
        assert(
          coeffs.count == varCount,
          "constraint has \(coeffs.count) coefficients, but varCount is \(varCount)"
        )
        // Normalize the row by infinity norm.
        let divisor = max(abs(equals), coeffs.map(abs).reduce(0, max))

        // Negate a constraint if the rhs is negative, so that the slack
        // variable can be strictly non-negative.
        let mult = (equals > 0 ? 1.0 : -1.0) / (divisor == 0 ? 1 : divisor)

        for (j, coeff) in coeffs.enumerated() {
          result[i, j] = coeff * mult
        }
        result[i, -1] = equals * mult
      }

      // Fill in the identity matrix
      for i in 0..<constraints.count {
        result[i, varCount + i] = 1.0
      }

      for v in basic {
        assert(v <= varCount)
        let maxRow = (0..<constraints.count).filter { result.basicCols[$0] >= varCount }
          .max { abs(result[$0, v]) < abs(result[$1, v]) }!
        assert(abs(result[maxRow, v]) > Epsilon, "basic variable cannot be created")
        result.pivot(pivotRule: .greedy, entering: v, leaving: result.basicCols[maxRow])
      }

      // Make sure remaining slack variables are positive
      if !basic.isEmpty {
        for (row, col) in result.basicCols.enumerated() {
          if col >= varCount && result[row, -1] < 0 {
            result.scale(row: row, by: -1)
            result[row, col] *= -1
          } else if col < varCount {
            assert(result[row, -1] > -Epsilon)
          }
        }
      }

      // The cost is maximal for basic auxiliary variables.
      for i in 0..<result.cols {
        result[-1, i] = 0.0
      }
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
        pivot(pivotRule: pivotRule, entering: entering, leaving: leaving)
        costHistory.append(cost)
        return .success
      }
    }

    private mutating func eliminateBasicCosts() {
      for (basicRow, basicCol) in basicCols.enumerated() {
        add(row: basicRow, to: -1, scale: -self[-1, basicCol])
        assert(abs(self[-1, basicCol]) < Epsilon, "elimination did not work")
      }
    }

    private mutating func choosePivot(pivotRule: PivotRule) -> Pivot {
      let entering: Int? =
        switch pivotRule {
        case .bland:
          (0..<(cols - 1)).first(where: { self[-1, $0] < -Epsilon })
        case .greedy:
          (0..<(cols - 1))
            .filter { self[-1, $0] < -Epsilon }
            .min { self[-1, $0] < self[-1, $1] }
        case .devex:
          {
            if devexCoeffs == nil {
              devexCoeffs = [Double](repeating: 1, count: cols - 1)
            }
            return (0..<(cols - 1))
              .filter { self[-1, $0] < -Epsilon }
              .max {
                abs(self[-1, $0]) / devexCoeffs![$0].squareRoot() < abs(self[-1, $1])
                  / devexCoeffs![$1].squareRoot()
              }
          }()
        case .greedyThenBland(let stallStepCount):
          {
            if switchedToBland
              || (costHistory.count > stallStepCount
                && costHistory[costHistory.count - stallStepCount] <= costHistory.last!)
            {
              switchedToBland = true
              return (0..<(cols - 1)).first(where: { self[-1, $0] < -Epsilon })
            } else {
              return (0..<(cols - 1))
                .filter { self[-1, $0] < -Epsilon }
                .min { self[-1, $0] < self[-1, $1] }
            }
          }()
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

    private mutating func pivot(pivotRule: PivotRule, entering: Int, leaving: Int) {
      switch pivotRule {
      case .devex:
        // Update devex coefficient for entering
        assert(devexCoeffs != nil, "choosePivot() should have initialized devex coeffs")
        var newCoeff = 0.0
        for row in 0..<(rows - 1) {
          newCoeff += pow(self[row, entering], 2) * devexCoeffs![basicCols[row]]
        }
        devexCoeffs![entering] = newCoeff
      default:
        ()
      }

      let row = basicCols.firstIndex(of: leaving)!
      basicCols[row] = entering
      scale(row: row, by: 1 / self[row, entering])

      let rowValue: [Double] = (0..<cols).map { self[row, $0] }
      var scalePerRow = [Double](repeating: 0.0, count: rows)
      for i in 0..<rows {
        if i != row {
          scalePerRow[i] = -self[i, entering]
        }
      }

      cblas_dger(
        CblasRowMajor,
        Int32(rows),  // m
        Int32(cols),  // n
        1.0,  // scale for outer product
        scalePerRow,  // rows vector
        1,  // stride in rows vector
        rowValue,  // cols vector
        1,  // stride in cols vector
        &values,  // output matrix
        Int32(cols)  // stride of output matrix
      )

      clipRHS()
      fillIdentityColumn(col: entering, rowWithOne: row)
    }

    private mutating func clipRHS() {
      for row in 0..<(rows - 1) {
        self[row, -1] = max(0, self[row, -1])
      }
    }

    private mutating func fillIdentityColumn(col: Int, rowWithOne: Int) {
      for i in 0..<rows {
        if i == rowWithOne {
          self[i, col] = 1
        } else {
          self[i, col] = 0
        }
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

    /// Any remaining slack variables in the basic set which are zero
    /// can either be pivoted out or deleted.
    /// This handles the case where we pivot out the variables.
    mutating func finishStage1() {
      let constraintCount = rows - 1
      let varCount = cols - 1
      let originalVarCount = varCount - constraintCount
      for (row, col) in basicCols.enumerated() {
        if col >= originalVarCount {
          if abs(self[row, -1]) < Epsilon {
            if let nonzeroIdx = (0..<originalVarCount).first(where: { self[row, $0] > Epsilon }) {
              self.pivot(pivotRule: .greedy, entering: nonzeroIdx, leaving: col)
            }
          }
        }
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

    mutating func refactor(original: Table) {
      assert(rows <= cols)
      assert(rows - 1 == basicCols.count)
      var mat = ColMajorMatrix(rows: rows - 1, cols: rows - 1)
      for (row, col) in basicCols.enumerated() {
        let dstCol = row
        for i in 0..<(rows - 1) {
          mat[i, dstCol] = original[i, col]
        }
      }
      guard case .success(var solution) = mat.lu() else {
        fatalError("failed to solve refactor basis")
      }

      // Apply the inverse to all the non-basic columns.
      // We leave the basic columns as-is, since they are exactly
      // columns of the identity already.
      let basicSet = Set(basicCols)
      let nonbasicColumns = (0..<cols).filter { !basicSet.contains($0) }
      var fullMatrix = ColMajorMatrix(rows: rows - 1, cols: nonbasicColumns.count)
      for i in 0..<(rows - 1) {
        for (dstCol, srcCol) in nonbasicColumns.enumerated() {
          fullMatrix[i, dstCol] = original[i, srcCol]
        }
      }
      solution.apply(&fullMatrix)
      for i in 0..<(rows - 1) {
        for (srcCol, dstCol) in nonbasicColumns.enumerated() {
          self[i, dstCol] = fullMatrix[i, srcCol]
        }
      }

      // Copy original reduced costs before eliminating
      for i in 0..<cols {
        self[-1, i] = original[-1, i]
      }
      eliminateBasicCosts()

      // Deal with rounding error of LU factorization.
      clipRHS()
    }
  }
}
