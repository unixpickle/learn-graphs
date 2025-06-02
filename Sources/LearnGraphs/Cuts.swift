extension AdjList {

  /// Cut the graph into a subgraph with the given vertices and another
  /// subgraph without the given vertices.
  ///
  /// If the supplied vertices contains vertices not in the graph, they will be
  /// ignored.
  ///
  /// Also returns the cut-set of the cut, i.e. the edges that spanned
  /// between the two subgraphs.
  public func cut<C>(vertices vs: C) -> (AdjList, AdjList, Set<UndirectedEdge<V>>)
  where C: Collection<V> {
    let vs = Set(vs)

    var trueGraph = AdjList()
    var falseGraph = AdjList()
    for v in vertices {
      if vs.contains(v) {
        trueGraph.insert(vertex: v)
      } else {
        falseGraph.insert(vertex: v)
      }
    }

    var cutSet: Set<UndirectedEdge<V>> = .init()
    for (sourceVertex, otherVertices) in edges {
      let sourceInVs = vs.contains(sourceVertex)
      for otherVertex in otherVertices {
        let otherInVs = vs.contains(otherVertex)
        if sourceInVs != otherInVs {
          cutSet.insert(UndirectedEdge(sourceVertex, otherVertex))
        } else if sourceInVs {
          trueGraph.insertEdge(from: sourceVertex, to: otherVertex)
        } else {
          falseGraph.insertEdge(from: sourceVertex, to: otherVertex)
        }
      }
    }

    return (trueGraph, falseGraph, cutSet)
  }

}
