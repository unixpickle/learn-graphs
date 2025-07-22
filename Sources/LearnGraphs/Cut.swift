public struct GomoryHuTree<V: Hashable, C> where C: Comparable, C: AdditiveArithmetic {
  public let tree: Graph<V>
  public let cost: [Edge<V>: C]

  /// Compute a minimum cut between the two vertices.
  public func minCut(from v1: V, to v2: V) -> (Set<V>, Set<V>, C) {
    let path = tree.shortestPath(from: v1, to: v2) { _ in 1 }!

    var minCost: C? = nil
    var minEdge: Edge<V>? = nil
    for (start, end) in zip(path, path[1...]) {
      let c = cost[Edge(start, end)]!
      if minCost == nil || c < minCost! {
        minCost = c
        minEdge = Edge(start, end)
      }
    }
    var splitG = tree
    splitG.remove(edge: minEdge!)
    let comps = splitG.components()
    assert(comps.count == 2)
    return (comps[0].vertices, comps[1].vertices, minCost!)
  }

  /// Iterate through all of the cuts induced by edges in the tree.
  public func cuts() -> AnyIterator<(Set<V>, Set<V>, C)> {
    let edges = Array(tree.edgeSet)
    var i = 0
    return AnyIterator { [tree] in
      if i == edges.count {
        return nil
      }
      let edge = edges[i]
      i += 1
      var splitG = tree
      splitG.remove(edge: edge)
      let comps = splitG.components()
      assert(comps.count == 2)
      return (comps[0].vertices, comps[1].vertices, cost[edge]!)
    }
  }
}

extension Graph {

  /// Get the set of edges separating the given vertices from the rest of the
  /// graph.
  public func cutSet<C>(vertices vs: C) -> Set<Edge<V>> where C: Collection<V> {
    var g = self
    return g.cut(vertices: vs).1
  }

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

  private class CutVertex: PointerHasher {
    public let vertices: [V]

    init(vertices: [V]) {
      self.vertices = vertices
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
      assert(queue.pop() == nil)

      if stage + 1 == vertices.count {
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

  class GomoryHuVertex: PointerHasher {
    let innerVertex: V?

    init(innerVertex: V? = nil) {
      self.innerVertex = innerVertex
    }
  }

  enum GomoryHuStep<C> where C: Comparable, C: AdditiveArithmetic {
    case merge(GomoryHuVertex, GomoryHuVertex, C)
    case recurse(Graph<GomoryHuVertex>, [Edge<GomoryHuVertex>: C], Set<GomoryHuVertex>)
  }

  /// Create a Gomory-Hu tree for the graph.
  public func gomoryHuTree<C>(edgeCost: (Edge<V>) -> C) -> GomoryHuTree<V, C>
  where C: Comparable, C: AdditiveArithmetic {
    if vertices.isEmpty {
      return GomoryHuTree<V, C>(tree: self, cost: [:])
    }

    // Based on https://courses.grainger.illinois.edu/cs598csc/sp2010/Lectures/Lecture6.pdf.

    let startGraph = map(GomoryHuVertex.init)
    let startCosts = Dictionary(
      uniqueKeysWithValues: startGraph.edgeSet.map {
        ($0, edgeCost($0.map { x in x.innerVertex! }))
      }
    )

    // Instead of using recursion, we use an explicit stack to prevent stack
    // overflows for large graphs.
    var resultStack: [(GomoryHuTree<GomoryHuVertex, C>, [GomoryHuVertex: Set<GomoryHuVertex>])] =
      []
    var steps = [GomoryHuStep<C>.recurse(startGraph, startCosts, startGraph.vertices)]
    while let step = steps.popLast() {
      switch step {
      case .merge(let v1, let v2, let mergeCost):
        assert(resultStack.count >= 2)
        let (v2Tree, v2Groups) = resultStack.popLast()!
        let (v1Tree, v1Groups) = resultStack.popLast()!

        let rep1 = v1Groups.filter { $0.value.contains(v1) }.first!.key
        let rep2 = v2Groups.filter { $0.value.contains(v2) }.first!.key
        var newTree = v1Tree.tree
        for v in v2Tree.tree.vertices {
          newTree.insert(vertex: v)
        }
        for edge in v2Tree.tree.edgeSet {
          newTree.insert(edge: edge)
        }
        newTree.insert(edge: Edge(rep1, rep2))
        var newGroups = v1Groups.mapValues { $0.subtracting([v1]) }
        for (k, v) in v2Groups {
          newGroups[k] = v.subtracting([v2])
        }

        assert(newGroups.values.allSatisfy { !$0.contains(v1) && !$0.contains(v2) })

        var newCosts = v1Tree.cost
        for (k, v) in v2Tree.cost {
          newCosts[k] = v
        }
        newCosts[Edge(rep1, rep2)] = mergeCost
        resultStack.append((.init(tree: newTree, cost: newCosts), newGroups))
      case .recurse(let g, let costs, let active):
        if active.count == 1 {
          let v = active.first!
          resultStack.append((.init(tree: .init(vertices: [v]), cost: [:]), [v: g.vertices]))
        } else {
          let vs = Array(active)
          let v1 = vs[0]
          let v2 = vs[1]

          // Compute an optimal cut between v1 and v2
          let flow = g.maxFlowEK(from: v1, to: v2) { (v1, v2) in costs[Edge(v1, v2)]! }
          let resid = flow.residual(graph: g) { (v1, v2) in costs[Edge(v1, v2)]! }
          let comp = resid.components().filter { $0.vertices.contains(v1) }.first!
          assert(!comp.vertices.contains(v2), "failed to find minimum cut")

          let contraction1 = comp.vertices
          let contraction2 = g.vertices.filter { !comp.vertices.contains($0) }
          let (newGraph1, newV1, newCosts1) = gomoryHuContraction(
            graph: g, verts: contraction1, costs: costs)
          let (newGraph2, newV2, newCosts2) = gomoryHuContraction(
            graph: g, verts: contraction2, costs: costs)

          steps.append(.merge(newV1, newV2, flow.totalFlow(from: v1)))
          steps.append(.recurse(newGraph2, newCosts2, contraction1.intersection(active)))
          steps.append(.recurse(newGraph1, newCosts1, contraction2.intersection(active)))
        }
      }
    }
    assert(resultStack.count == 1)
    let outTree = resultStack.first!.0

    // All vertices should be unique
    assert(outTree.tree.vertices.count == Set(outTree.tree.vertices.map { $0.innerVertex! }).count)

    let outCost = outTree.cost.map { ($0.0.map { x in x.innerVertex! }, $0.1) }
    assert(outCost.count == Set(outCost.map { $0.0 }).count)

    return .init(
      tree: outTree.tree.map { $0.innerVertex! },
      cost: Dictionary(
        uniqueKeysWithValues: outCost
      )
    )
  }

  private func gomoryHuContraction<C>(
    graph: Graph<GomoryHuVertex>,
    verts: Set<GomoryHuVertex>,
    costs: [Edge<GomoryHuVertex>: C]
  ) -> (Graph<GomoryHuVertex>, GomoryHuVertex, [Edge<GomoryHuVertex>: C])
  where C: Comparable, C: AdditiveArithmetic {
    var newGraph = graph
    let (_, cutSet) = newGraph.cut(vertices: verts)
    let newVert = GomoryHuVertex()
    newGraph.insert(vertex: newVert)

    var newCost = Dictionary(uniqueKeysWithValues: costs.filter { !cutSet.contains($0.0) })
    for edge in cutSet {
      let vs = Array(edge.vertices)
      let keptVert = verts.contains(vs[0]) ? vs[1] : vs[0]
      let newEdge = Edge(newVert, keptVert)
      newCost[newEdge, default: .zero] += costs[edge, default: .zero]
      newGraph.insert(edge: newEdge)
    }

    return (newGraph, newVert, newCost)
  }

}
