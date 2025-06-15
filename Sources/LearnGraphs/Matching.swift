public enum MaxCardMatchAlgorithm: Sendable {
  case bruteForce
  case blossom
}

public enum MaxCardMinCostMatchAlgorithm: Sendable {
  case bruteForce
  case blossom
}

public enum MaxWeightMatchAlgorithm: Sendable {
  case bruteForce
  case blossom
}

public protocol MatchingWeight: Comparable, ExpressibleByIntegerLiteral {
  static func + (lhs: Self, rhs: Self) -> Self
  static func - (lhs: Self, rhs: Self) -> Self
  func half() -> Self
}

extension Float: MatchingWeight {

  public func half() -> Self { self / 2.0 }

}

extension Double: MatchingWeight {

  public func half() -> Self { self / 2.0 }

}

internal struct TupleMatchingWeight<M1: MatchingWeight, M2: MatchingWeight>: MatchingWeight {
  let major: M1
  let minor: M2

  typealias IntegerLiteralType = M2.IntegerLiteralType

  init(major: M1, minor: M2) {
    self.major = major
    self.minor = minor
  }

  init(integerLiteral value: Self.IntegerLiteralType) {
    self.major = 0
    self.minor = M2(integerLiteral: value)
    precondition(
      self.minor == 0,
      "matching algorithms should only construct 0 values explicitly"
    )
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.major < rhs.major || (lhs.major == rhs.major && lhs.minor < rhs.minor)
  }

  static func <= (lhs: Self, rhs: Self) -> Bool {
    lhs.major < rhs.major || (lhs.major == rhs.major && lhs.minor <= rhs.minor)
  }

  static func >= (lhs: Self, rhs: Self) -> Bool {
    lhs.major > rhs.major || (lhs.major == rhs.major && lhs.minor >= rhs.minor)
  }

  static func > (lhs: Self, rhs: Self) -> Bool {
    lhs.major > rhs.major || (lhs.major == rhs.major && lhs.minor > rhs.minor)
  }

  static func + (lhs: Self, rhs: Self) -> Self {
    Self(major: lhs.major + rhs.major, minor: lhs.minor + rhs.minor)
  }

  static func - (lhs: Self, rhs: Self) -> Self {
    Self(major: lhs.major - rhs.major, minor: lhs.minor - rhs.minor)
  }

  func half() -> Self {
    Self(major: major.half(), minor: minor.half())
  }
}

extension Graph {
  /// Compute a maximum weight matching, i.e. a matching which maximizes the
  /// sum of all the weights for the included edges.
  public func maxWeightMatch<C>(
    algorithm: MaxWeightMatchAlgorithm = .bruteForce,
    weight: (Edge<V>) -> C
  ) -> Set<Edge<V>> where C: MatchingWeight {
    switch algorithm {
    case .bruteForce:
      bruteForceMaximumWeightMatching(weight: weight)
    case .blossom:
      edmundMatching(weight: weight)
    }
  }

  /// Compute a maximum cardinality matching in the graph.
  public func maxCardMatch(
    algorithm: MaxCardMatchAlgorithm = .bruteForce
  ) -> Set<Edge<V>> {
    switch algorithm {
    case .bruteForce:
      maxCardMatchWithMaxWeight(algorithm: .bruteForce)
    case .blossom:
      maxCardMatchWithMaxWeight(algorithm: .blossom)
    }
  }

  internal func maxCardMatchWithMaxWeight(algorithm: MaxWeightMatchAlgorithm) -> Set<Edge<V>> {
    maxWeightMatch(algorithm: algorithm) { _ in 1 }
  }

  /// Compute a maximum cardinality matching while minimizing the total weight
  /// of the matching.
  public func maxCardMinCostMatch<C: MatchingWeight>(
    algorithm: MaxCardMinCostMatchAlgorithm = .bruteForce,
    edgeCost: (Edge<V>) -> C
  ) -> Set<Edge<V>> {
    switch algorithm {
    case .bruteForce:
      maxCardMinCostWithMaxWeight(algorithm: .bruteForce, edgeCost: edgeCost)
    case .blossom:
      maxCardMinCostWithMaxWeight(algorithm: .blossom, edgeCost: edgeCost)
    }
  }

  internal func maxCardMinCostWithMaxWeight<C: MatchingWeight>(
    algorithm: MaxWeightMatchAlgorithm, edgeCost: (Edge<V>) -> C
  ) -> Set<Edge<V>> {
    maxWeightMatch(algorithm: algorithm) { e in
      TupleMatchingWeight(major: 1.0, minor: 0 - edgeCost(e))
    }
  }

  internal func bruteForceMaximumWeightMatching<C: MatchingWeight>(weight: (Edge<V>) -> C) -> Set<
    Edge<V>
  > {
    var result: Set<Edge<V>> = []
    var resultWeight: C = 0
    iterateMatchings(current: [], remaining: edgeSet) { matching in
      let newWeight = matching.map(weight).reduce(0, +)
      if newWeight > resultWeight {
        result = matching
        resultWeight = newWeight
      }
    }
    return result
  }

  internal func iterateMatchings(
    current: Set<Edge<V>>, remaining: Set<Edge<V>>, _ cb: (Set<Edge<V>>) -> Void
  ) {
    if remaining.isEmpty {
      cb(current)
      return
    }
    var remaining = remaining
    while let nextEdge = remaining.popFirst() {
      var newCurrent = current
      newCurrent.insert(nextEdge)
      var newRemaining = remaining
      for edge in remaining {
        if !edge.vertices.intersection(nextEdge.vertices).isEmpty {
          newRemaining.remove(edge)
        }
      }
      iterateMatchings(current: newCurrent, remaining: newRemaining, cb)
    }
  }

  internal func edmundMatching<C: MatchingWeight>(weight: (Edge<V>) -> C) -> Set<
    Edge<V>
  > {
    let algo = EdmundAlgorithm(graph: self, weight: weight)
    while algo.buildNextTree() {}
    algo.expandBlossoms()
    var matching: Set<Edge<V>> = []
    for edge in algo.matching {
      let rawVerts = edge.vertices.compactMap { $0.rawVertex }
      if rawVerts.count == 2 {
        matching.insert(Edge(rawVerts[0], rawVerts[1]))
      }
    }
    return matching
  }

  private class EdmundAlgorithm<W: MatchingWeight> {
    class Blossom {
      var stemVertex: Vertex {
        vertices[0]
      }

      var edges: [Edge<Vertex>] {
        edgesInPath(vertices) + [Edge(vertices.first!, vertices.last!)]
      }

      var minVertex: Vertex {
        vertices.filter { $0.weight == self.minWeight }.first!
      }

      /// Vertices in counter-clockwise order in the Blossom.
      /// The first vertex is the vertex which touches the stem.
      var vertices: [Vertex]

      /// A set version of vertices.
      let vertexSet: Set<Vertex>

      /// The minimum weight of the vertices in the Blossom.
      /// This is an upper-bound on the weight of pseudovertices for this Blossom.
      let minWeight: W

      init(vertices: [Vertex]) {
        assert(vertices.count % 2 == 1 && vertices.count >= 3)
        self.vertices = vertices
        self.vertexSet = Set(vertices)
        self.minWeight = vertices.map { $0.weight }.reduce(vertices[0].weight, min)
      }

      /// If the vertex is the stem, we can determine a unique matching.
      ///
      /// If there is no stem, we will pick one based on weights.
      func matchingForStem(vertex maybeVertex: Vertex?, edgeWeights: [Edge<Vertex>: W]) -> Set<
        Edge<Vertex>
      > {
        let vertex = if let v = maybeVertex { v } else { minVertex }
        let idx = vertices.firstIndex(of: vertex)!
        vertices = Array(vertices[idx...] + vertices[..<idx])
        var result = Set<Edge<Vertex>>()
        for (i, v) in vertices.enumerated() {
          let next = vertices[(i + 1) % vertices.count]
          if i % 2 == 1 {
            result.insert(Edge(v, next))
          }
        }
        return result
      }

      /// Compute an even path through the Blossom, where one of the points is
      /// the stem vertex.
      ///
      /// Even means that there are an even number of edges, and an odd number of vertices.
      func evenPath(from: Vertex, to: Vertex) -> [Vertex] {
        let idx1 = vertices.firstIndex(of: from)!
        var idx2 = vertices.firstIndex(of: to)!
        if idx1 == idx2 {
          return [from]
        }
        if idx2 < idx1 {
          idx2 += vertices.count
        }
        if (idx2 - idx1) % 2 == 0 {
          return (idx1...idx2).map { vertices[$0 % vertices.count] }
        } else {
          return (idx2...(idx1 + vertices.count)).map { vertices[$0 % vertices.count] }.reversed()
        }
      }

      /// Compute adjacent edges to the Blossom vertices while they are still
      /// in the graph.
      func adjacentEdges(graph: Graph<Vertex>) -> Set<Edge<Vertex>> {
        assert(vertices.allSatisfy { graph.contains(vertex: $0) })
        return graph.edgesAt(vertices: vertices).filter {
          vertexSet.intersection($0.vertices).count == 1
        }
      }

      /// Get a mapping from adjacent edges to the blossom vertices that should
      /// be attached to expand the edge from the collapsed blossom.
      func adjacentToInterior(
        graph: Graph<Vertex>,
        tightEdges: Set<Edge<Vertex>>,
        edgeWeights: [Edge<Vertex>: W]
      ) -> [Vertex: Set<Vertex>] {
        assert(
          vertices.allSatisfy { graph.contains(vertex: $0) },
          "blossom must be expanded in the graph"
        )
        let vertexSet = Set(vertices)
        var adjToInterior = [Vertex: Set<Vertex>]()
        var minEdgeSlack = [Vertex: W]()
        var minEdgeIsTight = [Vertex: Bool]()
        for e in adjacentEdges(graph: graph) {
          let blossomVertex = e.vertices.filter { vertexSet.contains($0) }.first!
          let otherVertex = e.other(blossomVertex)
          let newSlack = blossomVertex.weight + otherVertex.weight - edgeWeights[e]!
          let newIsTight = tightEdges.contains(e)

          let (isBetter, isEqual) =
            if let existingSlack = minEdgeSlack[otherVertex],
              let existingIsTight = minEdgeIsTight[otherVertex]
            {
              if newIsTight {
                (isBetter: !existingIsTight, isEqual: existingIsTight)
              } else {
                (
                  isBetter: !existingIsTight && (newSlack < existingSlack),
                  isEqual: !existingIsTight && (newSlack == existingSlack)
                )
              }
            } else {
              (true, false)
            }
          if isBetter {
            adjToInterior[otherVertex] = [blossomVertex]
            minEdgeSlack[otherVertex] = newSlack
            minEdgeIsTight[otherVertex] = newIsTight
          } else if isEqual {
            adjToInterior[otherVertex]!.insert(blossomVertex)
          }
        }
        return adjToInterior
      }
    }

    class Vertex: Hashable {
      var weight: W
      var rawVertex: V? = nil
      var blossom: Blossom? = nil

      init(weight: W, rawVertex: V) {
        self.weight = weight
        self.rawVertex = rawVertex
      }

      init(weight: W, blossom: Blossom) {
        self.weight = weight
        self.blossom = blossom
      }

      func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
      }

      static func == (lhs: Vertex, rhs: Vertex) -> Bool {
        lhs === rhs
      }
    }

    struct HungarianUpdate {
      var delta: W
      var reduceToZero: Set<Vertex>
      var tighten: Set<Edge<Vertex>>
      var unfoldBlossom: Vertex?

      var requiresNewTree: Bool {
        unfoldBlossom == nil
      }
    }

    class Tree {
      var root: Vertex
      private var treeGraph: Graph<Vertex>
      private var isOuterMap: [Vertex: Bool]
      private var parents: [Vertex: Vertex] = [:]

      init(root: Vertex) {
        self.treeGraph = Graph<Vertex>(vertices: [root])
        self.root = root
        self.isOuterMap = [root: true]
      }

      func contains(vertex: Vertex) -> Bool {
        treeGraph.contains(vertex: vertex)
      }

      func contains(edge: Edge<Vertex>) -> Bool {
        treeGraph.contains(edge: edge)
      }

      func isOuter(vertex: Vertex) -> Bool {
        assert(contains(vertex: vertex))
        return isOuterMap[vertex]!
      }

      func insert(existing: Vertex, new: Vertex) {
        assert(!contains(vertex: new))
        treeGraph.insert(vertex: new)
        treeGraph.insertEdge(existing, new)
        isOuterMap[new] = !isOuterMap[existing]!
        parents[new] = existing
      }

      func children(vertex: Vertex) -> [Vertex] {
        let parent = parents[vertex]
        return treeGraph.neighbors(vertex: vertex).filter { $0 != parent }
      }

      /// Get a trail from one vertex in the tree to another, starting at v0.
      func trace(from v0: Vertex, to v1: Vertex) -> [Vertex] {
        if let path = traceUpward(from: v1, to: v0) {
          return path.reversed()
        } else {
          return traceUpward(from: v0, to: v1)!
        }
      }

      private func traceUpward(from: Vertex, to: Vertex) -> [Vertex]? {
        var path = [Vertex]()
        var v = from
        while true {
          path.append(v)
          if v == to {
            return path
          }
          if let parent = parents[v] {
            v = parent
          } else {
            return nil
          }
        }
      }

      func traceBlossom(finalEdge: Edge<Vertex>) -> [Vertex] {
        let startNode = finalEdge.vertices.first!
        let otherNode = finalEdge.other(startNode)
        var searchNodes: Set<[Vertex]> = [[startNode]]
        var seen: Set<Vertex> = [startNode]
        while let nextNode = searchNodes.popFirst() {
          for v in treeGraph.neighbors(vertex: nextNode.last!) {
            let nextPath = Array(nextNode + [v])
            if v == otherNode {
              return nextPath
            }
            if !seen.contains(v) {
              searchNodes.insert(nextPath)
              seen.insert(v)
            }
          }
        }
        fatalError("could not identify blossom")
      }

      func outerAndInner() -> (outer: Set<Vertex>, inner: Set<Vertex>) {
        return (
          outer: Set(isOuterMap.compactMap { $0.1 ? $0.0 : nil }),
          inner: Set(isOuterMap.compactMap { !$0.1 ? $0.0 : nil })
        )
      }

      func collapseInnerBlossom(vertex: Vertex) {
        guard let blossom = vertex.blossom else {
          fatalError("vertex was not a blossom")
        }
        let neighbors = blossom.vertices.flatMap { treeGraph.neighbors(vertex: $0) }.filter {
          !blossom.vertexSet.contains($0)
        }
        let previousVerts = Set(
          neighbors.filter {
            if let p = parents[$0] {
              !blossom.vertexSet.contains(p)
            } else {
              false
            }
          })
        assert(previousVerts.count <= 1)

        for v in blossom.vertices {
          treeGraph.remove(vertex: v)
          parents.removeValue(forKey: v)
          isOuterMap.removeValue(forKey: v)
        }

        treeGraph.insert(vertex: vertex)
        for neighbor in neighbors {
          treeGraph.insertEdge(neighbor, vertex)
        }
        isOuterMap[vertex] = true
        for parent in previousVerts {
          parents[vertex] = parent
        }
        for v in neighbors {
          if !previousVerts.contains(v) {
            parents[v] = vertex
          }
        }

        if previousVerts.isEmpty {
          root = vertex
        } else {
          assert(!isOuter(vertex: parents[vertex]!), "parent of collapsed blossom must be inner")
        }
      }

      /// Transform the tree by expanding the even path in the vertex in place
      /// of an inner vertex.
      func expandInnerBlossom(vertex: Vertex, tightEdges: Set<Edge<Vertex>>) {
        assert(!isOuter(vertex: vertex))
        assert(children(vertex: vertex).count == 1, "inner vertex should have exactly one child")

        guard let blossom = vertex.blossom else {
          fatalError("vertex was not a blossom")
        }

        isOuterMap.removeValue(forKey: vertex)

        let parent = parents[vertex]!
        let child = children(vertex: vertex).first!
        parents.removeValue(forKey: vertex)
        parents.removeValue(forKey: child)
        assert(isOuter(vertex: parent))
        assert(isOuter(vertex: child))

        // Figure out appropriate points in blossom to connect to tree.
        let childNeighbor = blossom.stemVertex
        let parentNeighbor = blossom.vertices.filter { innerVertex in
          tightEdges.contains(Edge(innerVertex, parent))
        }.first!

        let newPath = blossom.evenPath(from: parentNeighbor, to: childNeighbor)
        assert(newPath.count % 2 == 1)
        assert(newPath.first! == parentNeighbor)
        assert(newPath.last! == childNeighbor)

        treeGraph.remove(vertex: vertex)
        var prev = parent
        for v in newPath {
          treeGraph.insert(vertex: v)
          treeGraph.insertEdge(prev, v)
          parents[v] = prev
          isOuterMap[v] = !isOuter(vertex: prev)
          prev = v
        }
        assert(!isOuter(vertex: prev))
        parents[child] = prev
        treeGraph.insertEdge(prev, child)
      }

      /// Verify that the paths along the tree are all alternating.
      func assertTreeValid(graph: Graph<Vertex>, matching: Set<Edge<Vertex>>) {
        var searchNodes: Set<Vertex> = [root]
        var seenEdges: Set<Edge<Vertex>> = []
        while let nextNode = searchNodes.popFirst() {
          let nodeChildren = children(vertex: nextNode)
          if nodeChildren.isEmpty {
            continue
          }
          if isOuter(vertex: nextNode) {
            // Outer vertex.
            for v in nodeChildren {
              assert(!matching.contains(Edge(nextNode, v)))
            }
          } else {
            // Inner vertex.
            assert(nodeChildren.count == 1)
            assert(matching.contains(Edge(nextNode, nodeChildren.first!)))
          }
          for v in nodeChildren {
            let edge = Edge(nextNode, v)
            assert(graph.contains(edge: edge))
            seenEdges.insert(edge)
            assert(contains(edge: edge))
            assert(isOuter(vertex: v) != isOuter(vertex: nextNode))
            searchNodes.insert(v)
          }
        }
        // Make sure `edges` has no extra edges.
        assert(
          seenEdges == treeGraph.edgeSet,
          "saw \(seenEdges.count) edges, but recorded a total of \(treeGraph.edgeSet.count)"
        )
      }

    }

    let baseGraph: Graph<Vertex>
    let baseWeights: [Edge<Vertex>: W]
    var graph: Graph<Vertex>
    var edgeWeights: [Edge<Vertex>: W]
    var tightEdges: Set<Edge<Vertex>> = []
    var matching: Set<Edge<Vertex>> = []

    init(graph: Graph<V>, weight: (Edge<V>) -> W) {
      let vertMap = Dictionary(
        uniqueKeysWithValues: graph.vertices.map { ($0, Vertex(weight: 0, rawVertex: $0)) }
      )
      self.graph = graph.map { vertMap[$0]! }
      baseGraph = self.graph
      edgeWeights = Dictionary(
        uniqueKeysWithValues: self.graph.edgeSet.map { edge in
          let parts = Array(edge.vertices)
          return (edge, weight(Edge(parts[0].rawVertex!, parts[1].rawVertex!)))
        }
      )
      baseWeights = edgeWeights
      let maxWeight = self.edgeWeights.values.reduce(0, max)

      // Make sure we don't violate the constraints.
      for v in vertMap.values {
        v.weight = maxWeight
      }
    }

    /// List all of the exposed vertices.
    func exposed() -> Set<Vertex> {
      graph.vertices.subtracting(Set(matching.flatMap { $0.vertices }))
    }

    func buildNextTree() -> Bool {
      var otherExposed = exposed()
      let availableRoots = otherExposed.filter { $0.weight > 0 }
      guard let root = availableRoots.first else {
        return false
      }
      otherExposed.remove(root)

      let tree = Tree(root: root)
      var queue = Set<Edge<Vertex>>()

      func populateQueueFor(outer: Vertex) {
        for edge in graph.edgesAt(vertex: outer) {
          if !matching.contains(edge) && tightEdges.contains(edge) {
            queue.insert(edge)
          }
        }
      }

      func populateQueue() {
        for v in tree.outerAndInner().outer {
          populateQueueFor(outer: v)
        }
      }

      populateQueue()

      while true {
        guard let edge = queue.popFirst() else {
          // Hungarian update
          let update = planHungarianUpdate(tree: tree)
          performHungarianUpdate(tree: tree, update: update)
          if update.requiresNewTree {
            return true
          }
          populateQueue()
          continue
        }

        assert(tightEdges.contains(edge))
        assert(!matching.contains(edge))

        let containedVertices = edge.vertices.filter { tree.contains(vertex: $0) }
        if containedVertices.count == 2 {
          // Two outer vertices connecting => odd length cycle => blossom
          // One outer and one inner vertex connection => even length cycle
          if !containedVertices.allSatisfy({ tree.isOuter(vertex: $0) }) {
            // Harmless even cycle
            continue
          }
          // This is a Blossom; collapse it into a vertex.
          let blossomVertices = tree.traceBlossom(finalEdge: edge)
          let blossom = Blossom(vertices: blossomVertices)
          let blossomVertex = collapse(blossom: blossom)
          tree.collapseInnerBlossom(vertex: blossomVertex)
          #if DEBUG
            tree.assertTreeValid(graph: graph, matching: matching)
          #endif

          assert(tree.isOuter(vertex: blossomVertex))

          if blossomVertex.weight <= 0 {
            // This is now an augmenting path ending at a zero-weight outer vertex.
            let path = tree.trace(from: tree.root, to: blossomVertex)
            assert(path.count % 2 == 1)
            flipAugmentingPath(path)
            return true
          }

          populateQueueFor(outer: blossomVertex)

          // Some unmatched edges coming out of the blossom might have been in the queue.
          for edge in Set(queue) {
            if tree.contains(edge: edge)
              || !edge.vertices.allSatisfy({ graph.contains(vertex: $0) })
            {
              queue.remove(edge)
            }
          }
        } else {
          assert(containedVertices.count == 1)
          let oldOuter = containedVertices.first!
          let newInner = edge.other(oldOuter)
          guard let followingMatched = matching.filter({ $0.vertices.contains(newInner) }).first
          else {
            // This is an augmenting path ending in an exposed inner vertex.
            tree.insert(existing: oldOuter, new: newInner)
            let path = tree.trace(from: tree.root, to: newInner)
            assert(path.count % 2 == 0)
            flipAugmentingPath(path)
            return true
          }
          let newOuter = followingMatched.other(newInner)
          assert(!tree.contains(vertex: newOuter))
          tree.insert(existing: oldOuter, new: newInner)
          tree.insert(existing: newInner, new: newOuter)
          #if DEBUG
            tree.assertTreeValid(graph: graph, matching: matching)
          #endif

          if newOuter.weight <= 0 {
            // This is an augmenting path ending at a zero-weight outer vertex.
            let path = tree.trace(from: tree.root, to: newOuter)
            assert(path.count % 2 == 1)
            flipAugmentingPath(path)
            return true
          }

          populateQueueFor(outer: newOuter)
        }
      }
    }

    func expandBlossoms() {
      func expandRecursively(vertex: Vertex) {
        if let b = vertex.blossom {
          expand(vertex: vertex)
          for v in b.vertices {
            expandRecursively(vertex: v)
          }
        }
      }
      for v in graph.vertices {
        expandRecursively(vertex: v)
      }
    }

    func flipAugmentingPath(_ path: [Vertex]) {
      let edges = edgesInPath(path)
      for edge in edges {
        flipMatching(edge: edge)
      }
    }

    func flipMatching(edge: Edge<Vertex>) {
      if matching.contains(edge) {
        matching.remove(edge)
      } else {
        matching.insert(edge)
      }
    }

    func planHungarianUpdate(tree: Tree) -> HungarianUpdate {
      let (outer, inner) = tree.outerAndInner()
      assert(outer.allSatisfy { $0.weight > 0 })
      var result: HungarianUpdate? = nil

      for vertex in outer {
        if result == nil || vertex.weight < result!.delta {
          result = HungarianUpdate(delta: vertex.weight, reduceToZero: [vertex], tighten: [])
        } else if vertex.weight == result!.delta {
          result?.reduceToZero.insert(vertex)
        }
        for other in graph.neighbors(vertex: vertex) {
          if inner.contains(other) {
            continue
          }
          let edge = Edge(vertex, other)
          assert(!tightEdges.contains(edge), "tree is not hungarian")
          var w = (vertex.weight + other.weight) - edgeWeights[edge]!
          if outer.contains(other) {
            w = w.half()
          }
          if result == nil || w < result!.delta {
            result = HungarianUpdate(delta: w, reduceToZero: [], tighten: [edge])
          } else if w == result!.delta {
            result!.tighten.insert(edge)
          }
        }
      }
      for vertex in inner {
        if let blossom = vertex.blossom {
          let delta = max(0, blossom.minWeight - vertex.weight)
          if result == nil || delta < result!.delta {
            result = HungarianUpdate(delta: delta, reduceToZero: [], tighten: [])
            result!.unfoldBlossom = vertex
          }
        }
      }

      return result!
    }

    func performHungarianUpdate(tree: Tree, update: HungarianUpdate) {
      let (outer, inner) = tree.outerAndInner()
      assert(
        outer.count == inner.count + 1, "outer.count=\(outer.count) inner.count=\(inner.count)")

      for v in outer {
        if update.reduceToZero.contains(v) {
          v.weight = 0
        } else {
          v.weight = max(0, v.weight - update.delta)
        }
      }

      for v in inner {
        v.weight = v.weight + update.delta

        // Some tight edges might become loose again.
        for otherEdge in graph.edgesAt(vertex: v) {
          if !outer.contains(otherEdge.other(v)) {
            untighten(edge: otherEdge)
          }
        }
      }

      for edge in update.tighten {
        tighten(edge: edge)
      }

      if let blossomVertex = update.unfoldBlossom {
        expand(vertex: blossomVertex)
        tree.expandInnerBlossom(vertex: blossomVertex, tightEdges: tightEdges)
        #if DEBUG
          tree.assertTreeValid(graph: graph, matching: matching)
        #endif
      }
    }

    func tighten(edge: Edge<Vertex>) {
      tightEdges.insert(edge)
    }

    func untighten(edge: Edge<Vertex>) {
      tightEdges.remove(edge)
    }

    func collapse(blossom: Blossom) -> Vertex {
      let blossomVertex = Vertex(weight: blossom.minWeight, blossom: blossom)
      let oldEdges = Array(blossom.adjacentEdges(graph: graph))
      let adjMapping = blossom.adjacentToInterior(
        graph: graph,
        tightEdges: tightEdges,
        edgeWeights: edgeWeights
      )
      let adjacentVertices = oldEdges.flatMap { $0.vertices }.filter {
        !blossom.vertexSet.contains($0)
      }

      for v in blossom.vertices {
        graph.remove(vertex: v)
      }
      graph.insert(vertex: blossomVertex)
      for v in adjacentVertices {
        graph.insertEdge(v, blossomVertex)
      }
      for e in blossom.edges {
        assert(tightEdges.contains(e))
        tightEdges.remove(e)
        matching.remove(e)
      }

      for (edge, adjVertex) in zip(oldEdges, adjacentVertices) {
        let newEdge = Edge(adjVertex, blossomVertex)
        if tightEdges.remove(edge) != nil {
          tightEdges.insert(newEdge)
        }
        if matching.remove(edge) != nil {
          matching.insert(newEdge)
        }
      }
      for (adjVertex, innerVertices) in adjMapping {
        let inner = innerVertices.first!
        let oldWeight = edgeWeights[Edge(inner, adjVertex)]!
        let newWeight = oldWeight + (blossomVertex.weight - inner.weight)
        edgeWeights[Edge(blossomVertex, adjVertex)] = newWeight
      }
      for edge in oldEdges {
        assert(edgeWeights[edge] != nil)
        edgeWeights.removeValue(forKey: edge)
      }

      return blossomVertex
    }

    func expand(vertex: Vertex) {
      let blossom = vertex.blossom!

      graph.remove(vertex: vertex)
      for v in blossom.vertices {
        graph.insert(vertex: v)
      }
      for newEdge in liftEdgesFromBaseGraph() {
        edgeWeights[newEdge] = liftEdgeWeight(edge: newEdge)!
      }

      let adjMapping = blossom.adjacentToInterior(
        graph: graph,
        tightEdges: .init(),  // use numerically tightest edge
        edgeWeights: edgeWeights
      )

      // Eliminate edge weights
      for adj in adjMapping.keys {
        edgeWeights.removeValue(forKey: Edge(adj, vertex))
      }

      var stemVertex: Vertex? = nil
      for (adj, blossomVertices) in adjMapping {
        let oldEdge = Edge(adj, vertex)
        if tightEdges.remove(oldEdge) != nil {
          for v in blossomVertices {
            tightEdges.insert(Edge(adj, v))
          }
        }
        if matching.remove(oldEdge) != nil {
          assert(stemVertex == nil)
          stemVertex = blossomVertices.first!
          matching.insert(Edge(adj, stemVertex!))
        }
      }

      assert(
        stemVertex == nil
          || !adjMapping.keys.allSatisfy { !matching.contains(Edge(stemVertex!, $0)) })

      // All edges in a blossom must have been tight.
      for innerEdge in blossom.edges {
        tightEdges.insert(innerEdge)
      }
      for e in blossom.matchingForStem(vertex: stemVertex, edgeWeights: edgeWeights) {
        matching.insert(e)
      }
    }

    func liftEdgesFromBaseGraph() -> Set<Edge<Vertex>> {
      var baseToCurrent = [Vertex: Vertex]()
      func explore(vertex: Vertex, current: Vertex) {
        if let blossom = vertex.blossom {
          for v in blossom.vertices {
            explore(vertex: v, current: current)
          }
        } else {
          baseToCurrent[vertex] = current
        }
      }
      for v in graph.vertices {
        explore(vertex: v, current: v)
      }

      var result: Set<Edge<Vertex>> = []
      for edge in baseGraph.edgeSet {
        let vs = edge.vertices.map { baseToCurrent[$0]! }
        if vs[0] != vs[1] {
          if graph.insertEdge(vs[0], vs[1]) {
            result.insert(Edge(vs[0], vs[1]))
          }
        }
      }
      return result
    }

    func liftEdgeWeight(edge: Edge<Vertex>) -> W? {
      if let w = baseWeights[edge] {
        return w
      }
      var vs = Array(edge.vertices)
      if vs[1].blossom != nil {
        vs = vs.reversed()
      }
      if let blossom = vs[0].blossom {
        var tightestSlack: W? = nil
        var tightestWeight: W? = nil
        for innerVertex in blossom.vertices {
          if let w = liftEdgeWeight(edge: Edge(innerVertex, vs[1])) {
            let slack = max(0, (innerVertex.weight + vs[1].weight) - w)
            if tightestSlack == nil || slack <= tightestSlack! {
              tightestSlack = slack
              tightestWeight = w + blossom.minWeight - innerVertex.weight
            }
          }
        }
        return tightestWeight
      }

      return nil
    }

  }

}

private func edgesInPath<V: Hashable>(_ vertices: [V]) -> [Edge<V>] {
  return (0..<(vertices.count - 1)).map { Edge(vertices[$0], vertices[$0 + 1]) }
}
