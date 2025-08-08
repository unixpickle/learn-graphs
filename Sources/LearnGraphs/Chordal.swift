extension Graph {

  /// Perform maximum cardinality search on the graph.
  ///
  /// This can be used to find a perfect elimination ordering if the graph is
  /// chordal, or to prove that the graph is not chordal otherwise.
  ///
  /// If the graph is chordal, then the result is the reverse of the PEO.
  public func maximumCardinalitySearch() -> [V] {
    var queue = PriorityQueue<V, Int>()
    for v in vertices {
      queue.push(v, priority: 0)
    }
    var result: [V] = []
    while let (item, _) = queue.pop() {
      result.append(item)
      for v in neighbors(vertex: item) {
        if let curPri = queue.currentPriority(for: v) {
          queue.modify(item: v, priority: curPri + 1)
        }
      }
    }
    return result
  }

  /// Check if the graph is chordal.
  public func isChordal() -> Bool {
    let ordering = maximumCardinalitySearch().reversed()
    let v2i = Dictionary(uniqueKeysWithValues: ordering.enumerated().map { ($0.1, $0.0) })
    for (i, v) in ordering.enumerated() {
      // Make sure the next neighbor is connected to all the neighbors after it.
      // Future iterations of the loop will then recursively verify the remaining
      // edges that are required for a clique.
      let futureNeighbors = neighbors(vertex: v).filter({ v2i[$0]! > i })
      if let nextNeighbor = futureNeighbors.min(by: { v2i[$0]! < v2i[$1]! }) {
        if !futureNeighbors.allSatisfy({
          $0 == nextNeighbor || contains(edge: Edge($0, nextNeighbor))
        }) {
          return false
        }
      }
    }
    return true
  }

  /// Greedily complete the graph to be chordal.
  ///
  /// This is not a minimum fill-in (i.e. it may be suboptimal).
  public mutating func mcsTriangulate() {
    let ordering = maximumCardinalitySearch().reversed()
    let v2i = Dictionary(uniqueKeysWithValues: ordering.enumerated().map { ($0.1, $0.0) })
    for (i, v) in ordering.enumerated() {
      // Make sure the next neighbor is connected to all the neighbors after it.
      // Future iterations of the loop will then recursively verify the remaining
      // edges that are required for a clique.
      let futureNeighbors = neighbors(vertex: v).filter({ v2i[$0]! > i })
      if let nextNeighbor = futureNeighbors.min(by: { v2i[$0]! < v2i[$1]! }) {
        for n in futureNeighbors {
          if n != nextNeighbor {
            insert(edge: Edge(nextNeighbor, n))
          }
        }
      }
    }
  }

  /// Create a chordal completion of this graph using a greedy algorithm.
  ///
  /// This is not a minimum fill-in (i.e. it may be suboptimal).
  public func mcsTriangulated() -> Graph<V> {
    var g = self
    g.mcsTriangulate()
    return g
  }

  /// Create a tree decomposition of a chordal graph.
  ///
  /// Returns nil if the graph is not chordal.
  public func chordalTreeDecomposition() -> Graph<TreeDecompositionBag<V>>? {
    if !isChordal() {
      return nil
    }

    var result = Graph<TreeDecompositionBag<V>>()
    var vertexToNode = [V: TreeDecompositionBag<V>]()

    let peo = Array(maximumCardinalitySearch().reversed())
    let v2i = Dictionary(uniqueKeysWithValues: zip(peo, peo.indices))

    for (i, x) in peo.enumerated() {
      let neighbors = neighbors(vertex: x)
      let bag = neighbors.filter { v2i[$0]! > i }
      let newNode = TreeDecompositionBag(bag: Set(bag + [x]))
      result.insert(vertex: newNode)
      vertexToNode[x] = newNode
    }

    for (i, x) in peo.enumerated() {
      let neighbors = neighbors(vertex: x)
      if let next = neighbors.filter({ v2i[$0]! > i }).min(by: { v2i[$0]! < v2i[$1]! }) {
        result.insertEdge(vertexToNode[x]!, vertexToNode[next]!)
      }
    }

    // If there are multiple components, we should connect them
    // to make a tree.
    let components = result.components()
    var joinedResult = components.first!
    let root = joinedResult.vertices.first!
    for c in components[1...] {
      joinedResult.insert(graph: c)
      joinedResult.insertEdge(root, c.vertices.first!)
    }

    return joinedResult
  }

}
