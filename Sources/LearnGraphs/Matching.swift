public enum MaxCardMatchAlgorithm: Sendable {
  case bruteForce
}

public enum MaxCardMinCostMatchAlgorithm: Sendable {
  case bruteForce
}

extension Graph {
  /// Compute a maximum cardinality matching in the graph.
  public func maxCardMatch(
    algorithm: MaxCardMatchAlgorithm = .bruteForce
  ) -> Set<Edge<V>> {
    switch algorithm {
    case .bruteForce:
      bruteForceMaximumCardinalityMatching()
    }
  }

  /// Compute a maximum cardinality matching while minimizing the total weight
  /// of the matching.
  public func maxCardMinCostMatch<C>(
    algorithm: MaxCardMinCostMatchAlgorithm = .bruteForce,
    edgeCost: (Edge<V>) -> C
  ) -> Set<Edge<V>> where C: Numeric, C: Comparable {
    switch algorithm {
    case .bruteForce:
      bruteForceMaximumCardinalityMinimumWeightMatching(edgeCost: edgeCost)
    }
  }

  internal func bruteForceMaximumCardinalityMatching() -> Set<Edge<V>> {
    var result: Set<Edge<V>> = []
    iterateMatchings(current: [], remaining: edgeSet) { matching in
      if matching.count > result.count {
        result = matching
      }
    }
    return result
  }

  internal func bruteForceMaximumCardinalityMinimumWeightMatching<C>(
    edgeCost: (Edge<V>) -> C
  ) -> Set<Edge<V>> where C: Numeric, C: Comparable {
    var result: Set<Edge<V>> = []
    var resultWeight: C = 0
    iterateMatchings(current: [], remaining: edgeSet) { matching in
      if matching.count > result.count {
        result = matching
        resultWeight = matching.map(edgeCost).reduce(0, +)
      } else if matching.count == result.count {
        let newWeight = matching.map(edgeCost).reduce(0, +)
        if newWeight < resultWeight {
          result = matching
          resultWeight = newWeight
        }
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
