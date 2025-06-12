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

}
