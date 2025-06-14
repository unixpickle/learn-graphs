public enum MaxCardMatchAlgorithm: Sendable {
  case bruteForce
}

public enum MaxCardMinCostMatchAlgorithm: Sendable {
  case bruteForce
}

public enum MaxWeightMatchAlgorithm: Sendable {
  case bruteForce
}

public protocol MatchingWeight: Comparable, ExpressibleByIntegerLiteral {
  static func + (lhs: Self, rhs: Self) -> Self
  static func - (lhs: Self, rhs: Self) -> Self
}

extension Int: MatchingWeight {}
extension Int64: MatchingWeight {}
extension Float: MatchingWeight {}
extension Double: MatchingWeight {}

internal struct TupleMatchingWeight<M1: MatchingWeight, M2: MatchingWeight>: MatchingWeight {
  let major: M1
  let minor: M2

  typealias IntegerLiteralType = M2.IntegerLiteralType

  init(major: M1, minor: M2) {
    self.major = major
    self.minor = minor
  }

  init(integerLiteral value: Self.IntegerLiteralType) {
    self.major = 0
    self.minor = M2(integerLiteral: value)
    precondition(
      self.minor == 0, "matching algorithms should only construct zero values explicitly"
    )
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.major < rhs.major || (lhs.major == rhs.major && lhs.minor < rhs.minor)
  }

  static func <= (lhs: Self, rhs: Self) -> Bool {
    lhs.major < rhs.major || (lhs.major == rhs.major && lhs.minor <= rhs.minor)
  }

  static func >= (lhs: Self, rhs: Self) -> Bool {
    lhs.major > rhs.major || (lhs.major == rhs.major && lhs.minor <= rhs.minor)
  }

  static func > (lhs: Self, rhs: Self) -> Bool {
    lhs.major > rhs.major || (lhs.major == rhs.major && lhs.minor > rhs.minor)
  }

  static func + (lhs: Self, rhs: Self) -> Self {
    Self(major: lhs.major + rhs.major, minor: lhs.minor + rhs.minor)
  }

  static func - (lhs: Self, rhs: Self) -> Self {
    Self(major: lhs.major - rhs.major, minor: lhs.minor - rhs.minor)
  }
}

extension Graph {
  /// Compute a maximum weight matching, i.e. a matching which maximizes the
  /// sum of all the weights for the included edges.
  public func maxWeightMatch<C>(
    algorithm: MaxWeightMatchAlgorithm = .bruteForce,
    weight: (Edge<V>) -> C
  ) -> Set<Edge<V>> where C: MatchingWeight {
    switch algorithm {
    case .bruteForce:
      bruteForceMaximumWeightMatching(weight: weight)
    }
  }

  /// Compute a maximum cardinality matching in the graph.
  public func maxCardMatch(
    algorithm: MaxCardMatchAlgorithm = .bruteForce
  ) -> Set<Edge<V>> {
    switch algorithm {
    case .bruteForce:
      maxCardMatchWithMaxWeight(algorithm: .bruteForce)
    }
  }

  internal func maxCardMatchWithMaxWeight(algorithm: MaxWeightMatchAlgorithm) -> Set<Edge<V>> {
    maxWeightMatch(algorithm: algorithm) { _ in 1 }
  }

  /// Compute a maximum cardinality matching while minimizing the total weight
  /// of the matching.
  public func maxCardMinCostMatch<C: MatchingWeight>(
    algorithm: MaxCardMinCostMatchAlgorithm = .bruteForce,
    edgeCost: (Edge<V>) -> C
  ) -> Set<Edge<V>> {
    switch algorithm {
    case .bruteForce:
      maxCardMinCostWithMaxWeight(algorithm: .bruteForce, edgeCost: edgeCost)
    }
  }

  internal func maxCardMinCostWithMaxWeight<C: MatchingWeight>(
    algorithm: MaxWeightMatchAlgorithm, edgeCost: (Edge<V>) -> C
  ) -> Set<Edge<V>> {
    maxWeightMatch(algorithm: algorithm) { e in
      TupleMatchingWeight(major: 1, minor: 0 - edgeCost(e))
    }
  }

  internal func bruteForceMaximumWeightMatching<C: MatchingWeight>(weight: (Edge<V>) -> C) -> Set<
    Edge<V>
  > {
    var result: Set<Edge<V>> = []
    var resultWeight: C = 0
    iterateMatchings(current: [], remaining: edgeSet) { matching in
      let newWeight = matching.map(weight).reduce(0, +)
      if newWeight > resultWeight {
        result = matching
        resultWeight = newWeight
      }
    }
    return result
  }

  internal func iterateMatchings(
    current: Set<Edge<V>>, remaining: Set<Edge<V>>, _ cb: (Set<Edge<V>>) -> Void
  ) {
    if remaining.isEmpty {
      cb(current)
      return
    }
    var remaining = remaining
    while let nextEdge = remaining.popFirst() {
      var newCurrent = current
      newCurrent.insert(nextEdge)
      var newRemaining = remaining
      for edge in remaining {
        if !edge.vertices.intersection(nextEdge.vertices).isEmpty {
          newRemaining.remove(edge)
        }
      }
      iterateMatchings(current: newCurrent, remaining: newRemaining, cb)
    }
  }
}
