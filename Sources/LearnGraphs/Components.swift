extension Graph {

  /// Get the connected components of the graph.
  ///
  /// If the graph is empty, this returns a single empty graph in the list.
  public func components() -> [Graph] {
    if vertices.isEmpty {
      return [self]
    }
    var remainder = self
    var result = [Graph]()
    while let start = remainder.vertices.first {
      let subgraph = remainder.reachableFrom(vertex: start)
      result.append(subgraph)
      remainder.remove(vertices: subgraph.vertices)
    }
    return result
  }

  /// Get the number of connected components.
  ///
  /// Returns 1 if the graph is empty.
  public func componentCount() -> Int {
    if vertices.isEmpty {
      return 1
    }

    var result = 0
    var uncovered = vertices
    while let next = uncovered.popFirst() {
      for x in reachableVerticesFrom(vertex: next) {
        uncovered.remove(x)
      }
      result += 1
    }
    return result
  }

  /// Get the subgraph that is reachable from a vertex.
  public func reachableFrom(vertex: V) -> Graph {
    return filteringVertices(reachableVerticesFrom(vertex: vertex).contains)
  }

  /// Get the vertices that are reachable from a starting vertex.
  private func reachableVerticesFrom(vertex: V) -> Set<V> {
    var resultVertices: Set<V> = [vertex]
    var queue = [vertex]
    while let next = queue.popLast() {
      for v in neighbors(vertex: next) {
        if !resultVertices.contains(v) {
          resultVertices.insert(v)
          queue.append(v)
        }
      }
    }
    return resultVertices
  }

  private enum TarjanStep {
    case finish(V)
    case explore(V, parent: V?)
  }

  /// Find the articulation points and bridges of the graph.
  public func articulationAndBridges() -> (Set<V>, Set<Edge<V>>) {
    var lowpoint = [V: Int]()
    var ids = [V: Int]()
    var children = [V: Set<V>]()
    var queue = vertices.map { TarjanStep.explore($0, parent: nil) }
    var roots = Set<V>()

    var articulation = Set<V>()
    var bridges = Set<Edge<V>>()
    while let step = queue.popLast() {
      switch step {
      case .explore(let v, let parent):
        if ids[v] != nil {
          break
        }
        let id = ids.count
        ids[v] = id
        lowpoint[v] = id
        queue.append(.finish(v))
        for n in neighbors(vertex: v) {
          if n == parent {
            continue
          }
          if let other = ids[n] {
            lowpoint[v] = min(lowpoint[v]!, other)
          } else {
            queue.append(.explore(n, parent: v))
          }
        }
        if let parent = parent {
          children[parent, default: []].insert(v)
        } else {
          roots.insert(v)
        }
      case .finish(let v):
        let isRoot = roots.contains(v)
        let nodeID = ids[v]!

        // Save memory by deleting children we won't need again.
        let nodeChildren = children.removeValue(forKey: v) ?? []

        for child in nodeChildren {
          let childLow = lowpoint[child]!
          lowpoint[v] = min(lowpoint[v]!, childLow)
          if childLow >= nodeID {
            if !isRoot {
              articulation.insert(v)
            }
          }
          if childLow > nodeID {
            bridges.insert(Edge(v, child))
          }
        }
        if (isRoot && nodeChildren.count > 1)
          || (!isRoot && lowpoint[v]! >= nodeID && !nodeChildren.isEmpty)
        {
          articulation.insert(v)
        }
      }
    }
    return (articulation, bridges)
  }

  /// Get all sets of vertices with at most size at most maxSize such that the
  /// graph is split into at least two separate components when removing the
  /// vertices in the set.
  ///
  /// Note that this does not only return minimal separators, but rather every
  /// single separator. So, for example, if the graph already has more than one
  /// component, then every possible subset is returned.
  public func separators(maxSize: Int) -> [Set<V>] {
    (1...maxSize).flatMap { allVertexSubsets(size: $0) }.filter { sep in
      var newG = self
      for v in sep {
        newG.remove(vertex: v)
      }
      return newG.vertices.count == 0 || newG.componentCount() > 1
    }
  }

  private func allVertexSubsets(size: Int) -> [Set<V>] {
    if size == 1 {
      return vertices.map { Set([$0]) }
    } else if size == 0 {
      return [[]]
    }

    let smallerSubsets = allVertexSubsets(size: size - 1)

    var results: Set<Set<V>> = []
    for v in vertices {
      results.formUnion(smallerSubsets.filter { !$0.contains(v) }.map { $0.union([v]) })
    }

    return Array(results)
  }

}
