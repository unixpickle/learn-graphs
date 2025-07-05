extension Graph {

  /// Compute the line graph of this graph, where vertices in the new graph are
  /// edges in the current graph, and edges between these edge-vertices are
  /// created wherever a vertex connects the edges.
  public func lineGraph() -> Graph<Edge<V>> {
    var result = Graph<Edge<V>>(vertices: edgeSet)
    for v in vertices {
      let vertEdges = edgesAt(vertex: v)
      for edge1 in vertEdges {
        for edge2 in vertEdges {
          result.insertEdge(edge1, edge2)
        }
      }
    }
    return result
  }

}
