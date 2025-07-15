import Accelerate

internal enum LUFactorizationResult {
  case success(LUFactorization)
  case singular(Int)
}

internal struct LUFactorization {
  let rows: Int
  let cols: Int
  var values: [Double]
  var pivots: [__CLPK_integer]

  mutating func apply(_ mat: inout ColMajorMatrix) {
    var nrhs = __CLPK_integer(mat.cols)
    var ldb = __CLPK_integer(mat.rows)
    var lda = __CLPK_integer(cols)
    var n1 = __CLPK_integer(cols)
    var info: __CLPK_integer = 0
    var order: CChar = 78  // ASCII code for 'N'
    dgetrs_(&order, &n1, &nrhs, &values, &lda, &pivots, &mat.values, &ldb, &info)
    assert(info == 0)
  }
}

internal struct ColMajorMatrix {
  let rows: Int
  let cols: Int
  var values: [Double]

  init(rows: Int, cols: Int) {
    self.rows = rows
    self.cols = cols
    self.values = [Double](repeating: 0, count: rows * cols)
  }

  subscript(_ row: Int, _ col: Int) -> Double {
    get {
      assert(row >= 0 && row < rows && col >= 0 && col < cols)
      return values[row + col * rows]
    }
    set {
      assert(row >= 0 && row < rows && col >= 0 && col < cols)
      values[row + col * rows] = newValue
    }
  }

  func lu() -> LUFactorizationResult {
    var newValues = values
    // Compute LU factorization
    var n1 = __CLPK_integer(rows)
    var n2 = __CLPK_integer(cols)
    var lda = n1
    var pivots = [__CLPK_integer](repeating: 0, count: min(rows, cols))
    var info: __CLPK_integer = 0
    dgetrf_(&n1, &n2, &newValues, &lda, &pivots, &info)
    if info != 0 {
      assert(info > 0)
      return .singular(Int(info) - 1)
    } else {
      return .success(LUFactorization(rows: rows, cols: cols, values: newValues, pivots: pivots))
    }
  }
}
