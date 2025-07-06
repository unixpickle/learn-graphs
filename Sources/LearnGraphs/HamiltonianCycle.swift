extension Graph {

  /// Compute a cycle through the graph that visits every vertex exactly once.
  ///
  /// This runs in exponential time in the worst case. To avoid expensive
  /// computation, pass a backtraceLimit to specify the maximum number of extra
  /// search nodes to explore (beyond what you'd need for a dense graph) before
  /// giving up on the search.
  ///
  /// Returns nil if no cycle can be found, or if backtrackLimit was reached.
  public func hamiltonianCycle<C: Collection<Edge<V>>>(
    start: V? = nil, mustUse: C, backtrackLimit: Int? = nil
  ) -> [V]? {
    if vertices.count <= 2 {
      return nil
    }

    var mustBeAdjacent = [V: Set<V>]()
    for edge in mustUse {
      if !contains(edge: edge) {
        return nil
      }
      let vs = Array(edge.vertices)
      mustBeAdjacent[vs[0], default: []].insert(vs[1])
      mustBeAdjacent[vs[1], default: []].insert(vs[0])
      if mustBeAdjacent[vs[0]]!.count > 2 || mustBeAdjacent[vs[1]]!.count > 2 {
        return nil
      }
    }

    var numBacktracks: Int = 0
    func search(path: [V], pathSet: Set<V>) -> [V]? {
      if path.count == vertices.count {
        if !contains(edge: Edge(path.first!, path.last!)) {
          numBacktracks += 1
          return nil
        }
        // Make sure adjacency requirement of first/last is met
        let lastAdj: Set<V> = [path[path.count - 2], path.first!]
        let firstAdj: Set<V> = [path[1], path.last!]
        if !mustBeAdjacent[path.last!, default: []].allSatisfy(lastAdj.contains)
          || !mustBeAdjacent[path.first!, default: []].allSatisfy(firstAdj.contains)
        {
          numBacktracks += 1
          return nil
        }
        return path + [path.first!]
      }
      let requiredAdj = mustBeAdjacent[path.last!, default: []]
      for neighbor in neighbors(vertex: path.last!) {
        if pathSet.contains(neighbor) {
          continue
        }
        if requiredAdj.count == 2 {
          if !requiredAdj.contains(neighbor) {
            continue
          }
        } else if requiredAdj.count == 1 {
          if !requiredAdj.contains(neighbor) && path.count > 1
            && !requiredAdj.contains(path[path.count - 2])
          {
            continue
          }
        }
        if let result = search(path: path + [neighbor], pathSet: pathSet.union([neighbor])) {
          return result
        } else if backtrackLimit != nil && numBacktracks > backtrackLimit! {
          return nil
        }
      }
      numBacktracks += 1
      return nil
    }

    let first = start ?? vertices.first!
    return search(path: [first], pathSet: [first])
  }

  public func hamiltonianCycle(start: V? = nil, backtrackLimit: Int? = nil) -> [V]? {
    hamiltonianCycle(start: start, mustUse: [], backtrackLimit: backtrackLimit)
  }

}
