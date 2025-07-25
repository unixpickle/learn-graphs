public protocol Constraint {
  func coeffs() -> [Double]
  func equals() -> Double
}

public struct DenseConstraint: Constraint {
  public let rawCoeffs: [Double]
  public let rawEquals: Double

  public init(coeffs: [Double], equals: Double) {
    rawCoeffs = coeffs
    rawEquals = equals
  }

  public func setting(_ idx: Int, equalTo: Double) -> Self {
    assert(idx > 0 && idx < rawCoeffs.count, "constraint setting argument out of bounds")
    let newCoeffs = Array(rawCoeffs[..<idx] + rawCoeffs[(idx + 1)...])
    let newEquals = rawEquals - rawCoeffs[idx] * equalTo
    return .init(coeffs: newCoeffs, equals: newEquals)
  }

  public func coeffs() -> [Double] {
    rawCoeffs
  }

  public func equals() -> Double {
    rawEquals
  }
}

public struct SparseConstraint: Constraint {
  public let coeffCount: Int
  public let coeffMap: [Int: Double]
  public let rawEquals: Double

  public init(coeffCount: Int, coeffMap: [Int: Double], equals: Double) {
    self.coeffCount = coeffCount
    self.coeffMap = coeffMap
    self.rawEquals = equals
  }

  public func setting(_ idx: Int, equalTo: Double) -> Self {
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

  public func addZeroCoeff() -> Self {
    .init(coeffCount: coeffCount + 1, coeffMap: coeffMap, equals: rawEquals)
  }

  public func coeffs() -> [Double] {
    var result = [Double](repeating: 0, count: coeffCount)
    for (i, x) in coeffMap {
      result[i] = x
    }
    return result
  }

  public func equals() -> Double {
    rawEquals
  }
}
