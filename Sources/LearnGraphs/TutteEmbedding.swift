import LPSolver

extension Graph {
  /// Compute a 2-D embedding of the graph if the graph is planar and
  /// triconnected.
  ///
  /// Returns nil if the system of equations cannot be solved.
  public func tutteEmbedding(boundary: [V: (Double, Double)]) -> [V: (Double, Double)]? {
    var vToIndex = [V: Int]()
    for v in vertices {
      if boundary[v] != nil {
        continue
      }
      vToIndex[v] = vToIndex.count
    }

    let numVars = vToIndex.count * 2
    var rhs = ColMajorMatrix(rows: numVars, cols: 1)
    var mat = ColMajorMatrix(rows: numVars, cols: numVars)
    for (v, row) in vToIndex {
      for dim in 0..<2 {
        mat[row * 2 + dim, row * 2 + dim] = 1
        let neighbors = neighbors(vertex: v)
        for neighbor in neighbors {
          if let neighborIdx = vToIndex[neighbor] {
            mat[row * 2 + dim, neighborIdx * 2 + dim] = -1.0 / Double(neighbors.count)
          } else if let coord = boundary[neighbor] {
            rhs[row * 2 + dim, 0] += (dim == 0 ? coord.0 : coord.1) / Double(neighbors.count)
          } else {
            fatalError()
          }
        }
      }
    }
    guard case .success(var lu) = mat.lu() else {
      return nil
    }
    lu.apply(&rhs)
    var coords = boundary
    for (v, row) in vToIndex {
      coords[v] = (rhs[row * 2, 0], rhs[row * 2 + 1, 0])
    }
    return coords
  }
}
