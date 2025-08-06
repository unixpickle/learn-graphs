public enum IsomorphismAlgorithm: Sendable {
  case bruteForce
}

extension Graph {

  /// Check if this graph is isomorphic to another graph.
  ///
  /// If so, return a mapping between vertices of this graph and the
  /// corresponding vertices in the other graph.
  public func isomorphism<V1: Hashable>(
    to g: Graph<V1>,
    algorithm: IsomorphismAlgorithm
  ) -> [V: V1]? {
    if vertices.count != g.vertices.count {
      return nil
    }
    switch algorithm {
    case .bruteForce:
      return bruteForceIsomorphism(to: g)
    }
  }

  private func bruteForceIsomorphism<V1: Hashable>(to g: Graph<V1>, partial: [V: V1] = [:]) -> [V:
    V1]?
  {
    if partial.count == vertices.count {
      return partial
    }
    let mappedSrc = Set(partial.keys)
    let mappedDst = Set(partial.values)
    let unmappedSrc = vertices.subtracting(mappedSrc)
    let unmappedDst = g.vertices.subtracting(mappedDst)
    for a in unmappedSrc {
      for b in unmappedDst {
        let neighborsA = neighbors(vertex: a)
        let neighborsB = g.neighbors(vertex: b)
        if neighborsA.count != neighborsB.count {
          continue
        }
        let mappedInA = neighborsA.filter(mappedSrc.contains)
        let mappedInB = Set(neighborsB.filter(mappedDst.contains))
        if mappedInA.count != mappedInB.count {
          continue
        }
        let mappedToB = Set(mappedInA.map { partial[$0]! })
        if mappedToB != mappedInB {
          continue
        }
        var newPartial = partial
        newPartial[a] = b
        if let solution = bruteForceIsomorphism(to: g, partial: newPartial) {
          return solution
        }
      }
    }
    return nil
  }

}
