public enum MinSpanTreeAlgorithm {
  case boruvka
}

extension AdjList {

  /// Compute the minimum spanning tree of the graph.
  ///
  /// If the graph has multiple connected components, then a separate spanning
  /// tree is computed for each component.
  public func minimumSpanningTree<C>(
    algorithm: MinSpanTreeAlgorithm = .boruvka, edgeCost: (UndirectedEdge<V>) -> C
  ) -> AdjList where C: Comparable {
    switch algorithm {
    case .boruvka:
      boruvka(edgeCost: edgeCost)
    }
  }

  private func boruvka<C>(edgeCost: (UndirectedEdge<V>) -> C) -> AdjList where C: Comparable {
    var minEdge = [V: (edge: UndirectedEdge<V>, cost: C)]()
    for edge in edgeSet {
      let cost = edgeCost(edge)

      for vertex in edge.vertices {
        if let item = minEdge[vertex], cost > item.cost {
        } else {
          minEdge[vertex] = (edge: edge, cost: cost)
        }
      }
    }

    if minEdge.isEmpty {
      // There are no edges in the graph, meaning we have one vertex per connected component.
      return self
    }

    let contractEdges = minEdge.values.map { $0.edge }
    let (contracted, edgeMap) = contract(edges: contractEdges)

    // Use a representative sample from each group of vertices to avoid
    // changing the vertex type at each Boruvka step.
    var representatives = [Set<V>: V]()
    for v in contracted.vertices {
      representatives[v] = v.first!
    }

    // Map edges in the new graph to the min-cost edge in the old graph.
    var minCostConnections = [UndirectedEdge<V>: (edge: UndirectedEdge<V>, cost: C)]()
    for (newEdge, oldEdges) in edgeMap {
      let oldEdges = Array(oldEdges)
      let newEdge = newEdge.map { representatives[$0]! }
      let costs = oldEdges.map { edgeCost($0) }

      var minIdx = 0
      var minCost = costs[0]
      for (i, x) in costs.enumerated() {
        if x < minCost {
          minCost = x
          minIdx = i
        }
      }

      minCostConnections[newEdge] = (edge: oldEdges[minIdx], cost: minCost)
    }

    let subTree = contracted.map { representatives[$0]! }.boruvka { newEdge in
      minCostConnections[newEdge]!.cost
    }

    var result = AdjList(vertices: vertices)
    for edge in subTree.edgeSet {
      result.insertEdge(minCostConnections[edge]!.edge)
    }
    for edge in contractEdges {
      result.insertEdge(edge)
    }
    return result
  }

}
