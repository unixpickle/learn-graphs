extension AdjList {

  /// Get the connected components of the graph.
  ///
  /// If the graph is empty, this returns a single empty graph in the lits.
  public func components() -> [AdjList] {
    if vertices.isEmpty {
      [self]
    } else {
      contract(edges: edgeSet).0.vertices.map { chop in
        AdjList(
          vertices: chop,
          edges: Dictionary(uniqueKeysWithValues: edges.filter { chop.contains($0.0) })
        )
      }
    }
  }

}
