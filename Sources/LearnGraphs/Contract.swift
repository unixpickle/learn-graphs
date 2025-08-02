public class ContractedVertex<V>: PointerHasher where V: Hashable {
  public let vertices: Set<V>

  /// An arbitrary vertex in the set that can be used to represent this vertex
  /// for recursive algorithms.
  public let representative: V

  internal init(vertices: Set<V>) {
    self.vertices = vertices
    self.representative = vertices.first!
  }
}

extension Graph {

  /// Contract the edges to arrive at a new graph where vertices in the new
  /// graph correspond to one or more vertices in this graph.
  ///
  /// Edges between vertices of the new graph may correspond to multiple
  /// original edges in the graph, and this mapping is returned.
  public func contract<C>(edges e: C) -> (
    Graph<ContractedVertex<V>>, [Edge<ContractedVertex<V>>: Set<Edge<V>>]
  ) where C: Collection<Edge<V>> {
    var newGraph: Graph<ContractedVertex<V>> = .init()
    var vMap = [V: ContractedVertex<V>]()
    for s in contractionGroups(edges: e, includeSingle: true) {
      let cv = ContractedVertex(vertices: s)
      for v in s {
        vMap[v] = cv
      }
      newGraph.insert(vertex: cv)
    }

    var edgeMap = [Edge<ContractedVertex<V>>: Set<Edge<V>>]()
    for edge in edgeSet {
      let vs = edge.vertices.map { vMap[$0]! }
      if vs[0] == vs[1] {
        continue
      }
      edgeMap[Edge(vs[0], vs[1]), default: .init()].insert(edge)
      newGraph.insertEdge(vs[0], vs[1])
    }

    return (newGraph, edgeMap)
  }

  /// Perform the core part of edge contraction by gathering sets of vertices
  /// that become equivalent under contraction.
  ///
  /// If a vertex is not involved in a merge, then it will only be included in
  /// a singleton set if includeSingle is true.
  public func contractionGroups<C>(edges e: C, includeSingle: Bool) -> [Set<V>]
  where C: Collection<Edge<V>> {
    var ds = DisjointSet(vertices)
    for edge in e {
      let vs = Array(edge.vertices)
      ds.union(vs[0], vs[1])
    }
    if includeSingle {
      return ds.sets()
    } else {
      return ds.sets().filter { $0.count > 1 }
    }
  }

}
