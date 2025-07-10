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

}
