extension Graph {

  /// Cut the graph into a subgraph without the given vertices, and another
  /// subgraph with the given vertices (which is returned).
  ///
  /// If the supplied vertices contains vertices not in the graph, they will be
  /// ignored.
  ///
  /// Also returns the cut-set of the cut, i.e. the edges that spanned
  /// between the two subgraphs.
  public mutating func cut<C>(vertices vs: C) -> (Graph, Set<Edge<V>>)
  where C: Collection<V> {
    let vs = Set(vs)

    var trueGraph = Graph()
    for v in vertices {
      if vs.contains(v) {
        trueGraph.insert(vertex: v)
      }
    }

    var cutSet: Set<Edge<V>> = .init()
    for (sourceVertex, otherVertices) in adjacencies {
      let sourceInVs = vs.contains(sourceVertex)
      for otherVertex in otherVertices {
        let otherInVs = vs.contains(otherVertex)
        if sourceInVs != otherInVs {
          cutSet.insert(Edge(sourceVertex, otherVertex))
        } else if sourceInVs {
          trueGraph.insertEdge(sourceVertex, otherVertex)
        }
      }
    }

    for v in vs {
      remove(vertex: v)
    }

    return (trueGraph, cutSet)
  }

  private class CutVertex: Hashable {

    public let vertices: [V]

    init(vertices: [V]) {
      self.vertices = vertices
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self))
    }

    static func == (lhs: CutVertex, rhs: CutVertex) -> Bool {
      lhs === rhs
    }
  }

  /// Compute a minimum-cost cut of the graph, given a positive cost for every
  /// edge.
  ///
  /// Returns the sets for each side of the split, and the cost of the cut set.
  public func minCostCut<C>(edgeCost: (Edge<V>) -> C) -> (Set<V>, Set<V>, C)
  where C: Comparable, C: AdditiveArithmetic {
    if vertices.count == 1 {
      return (vertices, [], .zero)
    }

    let vertMap = Dictionary(uniqueKeysWithValues: vertices.map { ($0, CutVertex(vertices: [$0])) })
    var g = map { vertMap[$0]! }

    var costMap = Dictionary(
      uniqueKeysWithValues: edgeSet.map { edge in (edge.map { v in vertMap[v]! }, edgeCost(edge)) }
    )

    var optimalCutCost: C? = nil
    var optimalCut: [V]? = nil

    for stage in 1..<vertices.count {
      let curVerts = Array(g.vertices)
      let first = curVerts[0]
      let costs = Dictionary(
        uniqueKeysWithValues: g.edgesAt(vertex: first).map { ($0.other(first), costMap[$0]!) }
      )
      var queue = PriorityQueue<CutVertex, C>()
      for item in curVerts[1...] {
        queue.push(item, priority: costs[item] ?? .zero)
      }
      var secondToLast: CutVertex? = nil
      for _ in stage..<(vertices.count - 1) {
        let item = queue.pop()!.item
        secondToLast = item
        for edge in g.edgesAt(vertex: item) {
          let other = edge.other(item)
          if let p = queue.currentPriority(for: other) {
            let cost = costMap[edge]!
            queue.modify(item: other, priority: p + cost)
          }
        }
      }
      let lastNode = queue.pop()!
      if let lastCost = optimalCutCost {
        if lastCost > lastNode.priority {
          optimalCutCost = lastNode.priority
          optimalCut = lastNode.item.vertices
        }
      } else {
        optimalCutCost = lastNode.priority
        optimalCut = lastNode.item.vertices
      }

      if stage + 1 < vertices.count {
        break
      }

      // Merge the last and second-to-last vertex.
      let newVertex = CutVertex(vertices: lastNode.item.vertices + secondToLast!.vertices)

      // This edge might not exist, but we want to make sure to avoid creating an
      // unnecessarily new edge cost.
      g.removeEdge(lastNode.item, secondToLast!)

      g.insert(vertex: newVertex)
      for v in [lastNode.item, secondToLast!] {
        for edge in g.edgesAt(vertex: v) {
          let newEdge = Edge(newVertex, edge.other(v))
          costMap[newEdge, default: .zero] += costMap[edge]!
          costMap.removeValue(forKey: edge)
          g.insert(edge: newEdge)
        }
      }
      for v in [lastNode.item, secondToLast!] {
        g.remove(vertex: v)
      }
    }

    assert(optimalCut != nil && optimalCutCost != nil)
    return (Set(optimalCut!), vertices.subtracting(optimalCut!), optimalCutCost!)
  }

}
