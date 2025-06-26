extension Graph {
  /// Find an approximate solution to the TSP using the Christofides algorithm.
  ///
  /// The graph must be fully connected.
  ///
  /// The path will always begin and end at the same place.
  public func christofides<W: MatchingWeight>(
    spanningAlgorithm: MinSpanTreeAlgorithm = .boruvka,
    matchingAlgorithm: MaxCardMinCostMatchAlgorithm = .blossom,
    edgeCost: (Edge<V>) -> W
  ) -> [V] {
    if vertices.count == 0 {
      return []
    } else if vertices.count == 1 {
      return [vertices.first!]
    }
    assert(isFullyConnected, "graph must be dense")
    let tree = minimumSpanningTree(algorithm: spanningAlgorithm, edgeCost: edgeCost)
    let odd: Set = tree.vertices.filter { tree.neighbors(vertex: $0).count % 2 == 1 }
    let oddSubgraph = filteringVertices { odd.contains($0) }
    let matching = oddSubgraph.maxCardMinCostMatch(algorithm: matchingAlgorithm, edgeCost: edgeCost)
    var multigraph = MultiGraph(tree)
    for edge in matching {
      multigraph.insert(edge: edge)
    }
    let circuit = multigraph.eulerianCycle()!

    var seen = Set<V>()
    var result = [V]()
    for v in circuit {
      if !seen.contains(v) {
        seen.insert(v)
        result.append(v)
      }
    }
    result.append(circuit[0])
    return result
  }
}
