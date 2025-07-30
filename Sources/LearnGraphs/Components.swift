extension Graph {

  /// Get the connected components of the graph.
  ///
  /// If the graph is empty, this returns a single empty graph in the list.
  public func components() -> [Graph] {
    if vertices.isEmpty {
      [self]
    } else {
      contractionGroups(edges: edgeSet, includeSingle: true).map { chop in
        Graph(
          vertices: chop,
          adjacencies: Dictionary(uniqueKeysWithValues: adjacencies.filter { chop.contains($0.0) })
        )
      }
    }
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

}
