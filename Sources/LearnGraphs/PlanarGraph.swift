/// A rotation system representation of a planar graph.
///
/// Each vertex has an ordered list of neighbors, where the first and last go
/// along the external face in a consistent order for all external vertices.
public struct PlanarGraph<V: Hashable>: Hashable {
  public var vertices: Set<V>
  public var adjacencies: [V: [V]]

  public init() {
    vertices = []
    adjacencies = [:]
  }

  public init<C: Collection<V>>(vertices: C, adjacencies: [V: [V]]) {
    self.vertices = Set(vertices)
    self.adjacencies = adjacencies
  }

  /// Separate the connected components of the graph.
  ///
  /// For empty graphs, this returns a list of a single empty graph.
  public func components() -> [PlanarGraph<V>] {
    var current = self
    var result: [PlanarGraph<V>] = []
    while let first = current.vertices.first {
      let allVerts = current.allConnected(first)
      result.append(current.filteringVertices { allVerts.contains($0) })
      current.filterVertices { !allVerts.contains($0) }
    }
    return result.isEmpty ? [self] : result
  }

  private func allConnected(_ v: V) -> Set<V> {
    var queue = [v]
    var result: Set<V> = [v]
    while let x = queue.popLast() {
      for other in adjacencies[x, default: []] {
        if !result.contains(other) {
          result.insert(other)
          queue.append(other)
        }
      }
    }
    return result
  }

  // Map the vertices while maintaining graph structure.
  public func map<V1>(_ fn: (V) -> V1) -> PlanarGraph<V1> {
    PlanarGraph<V1>(
      vertices: Set(vertices.map(fn)),
      adjacencies: [V1: [V1]](
        uniqueKeysWithValues: adjacencies.map { key, value in
          (fn(key), value.map(fn))
        }
      )
    )
  }

  /// Remove all vertices for which the block returns false.
  public mutating func filterVertices(_ c: (V) -> Bool) {
    vertices = Set(vertices.filter { c($0) })
    adjacencies = Dictionary(
      uniqueKeysWithValues: adjacencies.filter {
        vertices.contains($0.0)
      }.map {
        ($0.0, $0.1.filter { x in vertices.contains(x) })
      }
    )
  }

  /// Get a new graph by retaining only the vertices for which the block returns true.
  public func filteringVertices(_ c: (V) -> Bool) -> Self {
    var result = self
    result.filterVertices(c)
    return result
  }

  public mutating func flip() {
    adjacencies = adjacencies.mapValues { $0.reversed() }
  }

  public func flipped() -> PlanarGraph<V> {
    var g = self
    g.flip()
    return g
  }

  private struct Arrow: Hashable {
    let a: V
    let b: V
  }

  public func faces() -> [[V]]? {
    var arrows: Set<Arrow> = []
    for (v, vs) in adjacencies {
      for v1 in vs {
        arrows.insert(Arrow(a: v, b: v1))
      }
    }
    var results: [[V]] = []
    while let start = arrows.popFirst() {
      var cur = start
      var path = [start.a]
      while true {
        path.append(cur.b)
        let adj = adjacencies[cur.b]!
        let idx = adj.firstIndex(of: cur.a)!
        let next = adj[(idx + 1) % adj.count]
        let arrow = Arrow(a: cur.b, b: next)
        if arrow == start {
          break
        }
        if !arrows.contains(arrow) {
          return nil
        }
        arrows.remove(arrow)
        cur = arrow
      }
      results.append(path)
    }
    return results
  }

  private struct EmbedVertex: Hashable {
    let vertex: V
    let child: V?
  }

  private struct WalkupState {
    let depth: Int
    var visited = Set<EmbedVertex>()
    var pertinentRoots = [V: Set<EmbedVertex>]()
    var backEdges: Set<EmbedVertex> = []
  }

  private struct EmbedState {
    var inGraph: Graph<V>
    var graph = PlanarGraph<EmbedVertex>()
    private var sortedVertices: [V] = []
    private var indices: [V: Int] = [:]
    private var parents: [V: V] = [:]
    private var backEdges: [V: [V]] = [:]
    private var virtualChildren = [V: Set<EmbedVertex>]()
    private var leastBackEdge = [V: Int]()
    private var lowpoint = [V: Int]()
    private var flipFlag = [V: Bool]()

    init(inGraph: Graph<V>, root: V) {
      self.inGraph = inGraph

      graph = PlanarGraph<EmbedVertex>()

      // Depth first search to setup initial graph and assign indices.
      var queue: [(child: V, parent: V?)] = [(root, nil)]
      while let (child, parent) = queue.popLast() {
        if indices[child] != nil {
          guard let parent = parent else {
            fatalError("root search node had an index")
          }
          assert(leastBackEdge[child, default: Int.max] > indices[parent]!)
          backEdges[parent, default: []].append(child)
          leastBackEdge[child] = indices[parent]!
          continue
        }

        indices[child] = indices.count
        sortedVertices.append(child)

        for newChild in inGraph.neighbors(vertex: child) {
          if indices[newChild] == nil {
            queue.append((child: newChild, parent: child))
          }
        }
        guard let parent = parent else {
          continue
        }

        let virtual = EmbedVertex(vertex: parent, child: child)
        let concreteChild = EmbedVertex(vertex: child, child: nil)
        virtualChildren[parent, default: []].insert(virtual)
        graph.vertices.insert(virtual)
        graph.vertices.insert(concreteChild)
        graph.adjacencies[virtual] = [concreteChild]
        graph.adjacencies[concreteChild] = [virtual]

        parents[child] = parent
      }

      for v in sortedVertices.reversed() {
        recalculateLowpoint(vertex: v)
      }
    }

    mutating func embed() -> Bool {
      for (i, v) in sortedVertices.enumerated().reversed() {
        var state = WalkupState(depth: i)
        for neighbor in backEdges[v, default: []] {
          if !walkup(state: &state, startVertex: neighbor, endVertex: v) {
            return false
          }
        }
        for child in state.pertinentRoots[v, default: []] {
          for exterior: Exterior in [.first, .last] {
            walkdown(state: &state, startVertex: child, exterior: exterior)
          }
        }
        if !state.backEdges.isEmpty {
          // We missed a back edge.
          return false
        }
        assert(
          walkExterior().isSuperset(
            of: graph.vertices.filter {
              externallyActive(vertex: $0.vertex, depth: state.depth)
                || ($0.child != nil && externallyActive(root: $0, depth: state.depth))
            }
          ),
          "an externally active vertex is not on the exterior"
        )
      }
      applyFlips()
      return true
    }

    private mutating func applyFlips() {
      // Flip back and forth as we go down the DFS tree.
      for x in sortedVertices {
        let parentFlip =
          if let parent = parents[x] {
            flipFlag[parent] ?? false
          } else {
            false
          }
        if parentFlip {
          flipFlag[x] = !flipFlag[x, default: false]
        }
      }
      for v in graph.vertices {
        if flipFlag[v.vertex, default: false] {
          graph.adjacencies[v] = graph.adjacencies[v]!.reversed()
        }
      }
    }

    private func walkExterior() -> Set<EmbedVertex> {
      let roots = graph.vertices.filter { $0.child != nil }
      var reachable = Set<EmbedVertex>()
      for root in roots {
        reachable.insert(root)
        var next = graph.adjacencies[root]!.first!
        while !reachable.contains(next) {
          reachable.insert(next)
          let adj = graph.adjacencies[next]!
          next = reachable.contains(adj.first!) ? adj.last! : adj.first!
        }
      }
      return reachable
    }

    private func walkup(state: inout WalkupState, startVertex: V, endVertex: V) -> Bool {
      state.backEdges.insert(EmbedVertex(vertex: startVertex, child: nil))
      var v = startVertex
      while v != endVertex {
        switch findNextRoot(state: &state, from: v) {
        case .alreadyVisited:
          return true
        case .root(let newRoot, _):
          v = newRoot.vertex
          state.pertinentRoots[v, default: []].insert(newRoot)
        case .unreachable:
          return false
        }
      }
      return true
    }

    private enum RootResult {
      case root(EmbedVertex, Int)
      case unreachable
      case alreadyVisited
    }

    private func findNextRoot(state: inout WalkupState, from: V) -> RootResult {
      let d1 = findNextRootDirected(state: &state, from: from, direction: false)
      let d2 = findNextRootDirected(state: &state, from: from, direction: true)
      if case .alreadyVisited = d1 {
        return .alreadyVisited
      } else if case .alreadyVisited = d2 {
        return .alreadyVisited
      }
      if case .root(_, let d1Dist) = d1, case .root(_, let d2Dist) = d2 {
        if d1Dist < d2Dist {
          return d1
        } else {
          return d2
        }
      } else if case .root(_, _) = d1 {
        return d1
      } else {
        return d2
      }
    }

    /// Find the next root in the biconnected component containing a vertex.
    /// Only goes left or right depending on direction, and terminates early
    /// and returns nil if an externally active vertex is hit.
    private func findNextRootDirected(state: inout WalkupState, from: V, direction: Bool)
      -> RootResult
    {
      let from = EmbedVertex(vertex: from, child: nil)
      if state.visited.contains(from) {
        return .alreadyVisited
      }

      var seen: Set<EmbedVertex> = [from]
      let adj = graph.adjacencies[from]!
      var next = direction ? adj.first! : adj.last!
      assert(
        graph.adjacencies[next]!.first! == from || graph.adjacencies[next]!.last! == from,
        "path did not trace the exterior"
      )
      var pathLength = 1
      while next.child == nil {
        if state.visited.contains(next) {
          return .alreadyVisited
        }
        state.visited.insert(next)
        seen.insert(next)
        if externallyActive(vertex: next.vertex, depth: state.depth) {
          return .unreachable
        }
        let adj = graph.adjacencies[next]!
        let prev = next
        next = seen.contains(adj.first!) ? adj.last! : adj.first!
        assert(
          graph.adjacencies[next]!.first! == prev || graph.adjacencies[next]!.last! == prev,
          "path did not trace the exterior"
        )
        pathLength += 1
      }
      return .root(next, pathLength)
    }

    private enum WalkdownWork {
      case explore(virtualRoot: EmbedVertex, parent: EmbedVertex?, parentExterior: Exterior?)
      case backEdge(vertex: EmbedVertex, exterior: Exterior)
      case merge(
        parent: EmbedVertex, child: EmbedVertex, parentExterior: Exterior, childExterior: Exterior)
      case noMoreBackEdges
    }

    private mutating func walkdown(
      state: inout WalkupState, startVertex: EmbedVertex, exterior: Exterior
    ) {
      assert(startVertex.child != nil)

      // This is a clear-cut recursive method, but recursive functions will overflow the stack,
      // so I implement it as an in-memory stack instead.
      var queue: [WalkdownWork] = [
        .explore(virtualRoot: startVertex, parent: nil, parentExterior: nil)
      ]
      var passedExternallyActive = false
      while let op = queue.popLast() {
        switch op {
        case .noMoreBackEdges:
          passedExternallyActive = true
        case .merge(let parent, let child, let parentExterior, let childExterior):
          mergeComponents(
            parent: parent,
            child: child,
            parentExterior: parentExterior,
            childExterior: childExterior
          )
        case .backEdge(let vertex, exterior: let childExterior):
          assert(!passedExternallyActive, "adding back edge after processing externally active")
          if exterior == .first {
            graph.adjacencies[startVertex]!.append(vertex)
          } else {
            graph.adjacencies[startVertex]!.insert(vertex, at: 0)
          }
          if childExterior == .first {
            graph.adjacencies[vertex]!.append(startVertex)
          } else {
            graph.adjacencies[vertex]!.insert(startVertex, at: 0)
          }
          state.backEdges.remove(vertex)
        case .explore(let virtualRoot, let parent, let parentExterior):
          let path1 = walkdownPath(state: state, startVertex: virtualRoot, exterior: exterior)
          let path2 = walkdownPath(state: state, startVertex: virtualRoot, exterior: exterior.other)
          let path = path2.priority > path1.priority ? path2 : path1
          if parent == nil {
            assert(path.exterior == exterior)
          } else {
            assert(state.pertinentRoots[virtualRoot.vertex]!.contains(virtualRoot))
            state.pertinentRoots[virtualRoot.vertex]!.remove(virtualRoot)
          }
          if let parentExterior = parentExterior, let parent = parent {
            // After processing this node, we should merge it with the parent.
            queue.append(
              .merge(
                parent: parent,
                child: virtualRoot,
                parentExterior: parentExterior,
                childExterior: path.exterior
              )
            )
          }

          var addToQueue: [WalkdownWork] = []
          for step in path.steps {
            switch step {
            case .backEdge(let vertex, let childExterior, _):
              addToQueue.append(.backEdge(vertex: vertex, exterior: childExterior))
            case .enter(let parent, let child, let parentExterior, _):
              addToQueue.append(
                .explore(
                  virtualRoot: child,
                  parent: parent,
                  parentExterior: parentExterior
                )
              )
            case .stopForExternal:
              addToQueue.append(.noMoreBackEdges)
            }
          }
          queue.append(contentsOf: addToQueue.reversed())
        }
      }
    }

    private enum Exterior {
      case first
      case last

      var other: Exterior {
        if self == .first { .last } else { .first }
      }
    }

    private enum WalkdownStep {
      case backEdge(vertex: EmbedVertex, exterior: Exterior, externallyActive: Bool)
      case enter(
        parent: EmbedVertex, child: EmbedVertex, parentExterior: Exterior, externallyActive: Bool)
      case stopForExternal
    }

    private struct WalkdownPath {
      let exterior: Exterior
      var steps: [WalkdownStep] = []

      var priority: Int {
        for s in steps {
          switch s {
          case .backEdge(_, _, let externallyActive): return externallyActive ? 1 : 2
          case .enter(_, _, _, let externallyActive): return externallyActive ? 1 : 2
          case .stopForExternal: return 0
          }
        }
        return 0
      }
    }

    private func walkdownPath(
      state: WalkupState,
      startVertex: EmbedVertex,
      exterior: Exterior
    ) -> WalkdownPath {
      assert(startVertex.child != nil)
      assert(parents[startVertex.child!] == startVertex.vertex, "invalid parent-child relationship")
      var result = WalkdownPath(exterior: exterior)

      var seen: Set<EmbedVertex> = [startVertex]
      let adj = graph.adjacencies[startVertex]!
      var next = exterior == .last ? adj.first! : adj.last!
      var prev = startVertex
      while !seen.contains(next) {
        seen.insert(next)

        let adj = graph.adjacencies[next]!
        let first = adj.first!
        let last = adj.last!
        let nextNext = first == prev ? last : first
        prev = next
        let curExterior: Exterior =
          if adj.count == 1 {
            exterior.other
          } else {
            first == nextNext ? .first : .last
          }
        let isExtAct = externallyActive(vertex: next.vertex, depth: state.depth)
        assert(
          !isExtAct || externallyActive(root: startVertex, depth: state.depth),
          "expect parent to be externally active"
        )

        if state.backEdges.contains(next) {
          result.steps.append(
            .backEdge(vertex: next, exterior: curExterior, externallyActive: isExtAct))
        }
        if let roots = state.pertinentRoots[next.vertex] {
          var someExternal: EmbedVertex?
          for root in roots {
            if externallyActive(root: root, depth: state.depth) {
              someExternal = root
            } else {
              result.steps.append(
                .enter(
                  parent: next,
                  child: root,
                  parentExterior: curExterior,
                  externallyActive: isExtAct
                )
              )
            }
          }
          if let x = someExternal {
            result.steps.append(
              .enter(
                parent: next,
                child: x,
                parentExterior: curExterior,
                externallyActive: isExtAct
              )
            )
            assert(externallyActive(vertex: next.vertex, depth: state.depth))
          }
        }
        if isExtAct {
          result.steps.append(.stopForExternal)
          return result
        }
        next = nextNext
      }
      return result
    }

    /// Merge biconnected components.
    private mutating func mergeComponents(
      parent: EmbedVertex,
      child: EmbedVertex,
      parentExterior: Exterior,
      childExterior: Exterior
    ) {
      assert(parent.vertex == child.vertex)
      assert(parent.child == nil)
      assert(child.child != nil)

      for childOfChild in graph.adjacencies[child, default: []] {
        if let adj = graph.adjacencies[childOfChild] {
          graph.adjacencies[childOfChild] = adj.map { $0 == child ? parent : $0 }
        }
      }
      var childAdj = graph.adjacencies.removeValue(forKey: child)!
      var parentAdj = graph.adjacencies[parent]!
      if parentExterior == .first {
        // We want to insert the child adjacencies into the end
        if childExterior == .first {
          flipFlag[child.child!] = true
          childAdj.reverse()
        }
        parentAdj.append(contentsOf: childAdj)
      } else {
        // We want to insert the child adjacencies into the start
        if childExterior == .last {
          flipFlag[child.child!] = true
          childAdj.reverse()
        }
        parentAdj.insert(contentsOf: childAdj, at: 0)
      }
      graph.adjacencies[parent] = parentAdj
      graph.vertices.remove(child)

      virtualChildren[parent.vertex]!.remove(child)
    }

    private mutating func recalculateLowpoint(vertex: V) {
      var lp =
        if let lbe = leastBackEdge[vertex] {
          lbe
        } else {
          indices[vertex]!
        }
      for child in virtualChildren[vertex, default: []] {
        lp = min(lp, lowpoint[child.child!]!)
      }
      lowpoint[vertex] = lp
    }

    private func externallyActive(vertex: V, depth: Int) -> Bool {
      var lp =
        if let lbe = leastBackEdge[vertex] {
          lbe
        } else {
          indices[vertex]!
        }
      for child in virtualChildren[vertex, default: []] {
        lp = min(lp, lowpoint[child.child!]!)
      }
      return lp < depth
    }

    private func externallyActive(root: EmbedVertex, depth: Int) -> Bool {
      lowpoint[root.child!]! < depth
    }
  }

  /// Compute a planar embedding of a graph.
  ///
  /// Each component of the graph will yield a separate sub-array, and each entry in the
  /// sub-array corresponds to a different biconnected component.
  ///
  /// Biconnected components can be merged into a single PlanarGraph using mergeBiconnected.
  ///
  /// Based on https://www.emis.de/journals/JGAA/accepted/2004/BoyerMyrvold2004.8.3.pdf
  public static func embed(graph g: Graph<V>) -> [[PlanarGraph<V>]]? {
    var result: [[PlanarGraph<V>]] = []
    for component in g.components() {
      guard let root = component.vertices.first else {
        result.append([.init()])
        continue
      }
      if component.vertices.count == 1 {
        result.append([.init(vertices: [root], adjacencies: [:])])
        continue
      }

      var embed = EmbedState(inGraph: component, root: root)
      if !embed.embed() {
        return nil
      }
      result.append(
        embed.graph.components().map { embedded in
          embedded.map { $0.vertex }
        }
      )
    }
    return result
  }

  /// Merge biconnected components, as returned by embed().
  ///
  /// Pairs of biconnected components should only have one common vertex.
  public static func mergeBiconnected(_ graphs: [PlanarGraph<V>]) -> PlanarGraph<V> {
    var graphs = graphs
    var result = graphs.popLast()!
    while !graphs.isEmpty {
      var merged = false
      for (i, g) in graphs.enumerated() {
        let common = result.vertices.intersection(g.vertices)
        if common.isEmpty {
          continue
        }
        assert(common.count == 1)

        let sharedVertex = common.first!
        for (k, v) in g.adjacencies {
          if k != sharedVertex {
            result.adjacencies[k] = v
          } else {
            result.adjacencies[k]!.append(contentsOf: v)
          }
        }
        result.vertices = result.vertices.union(g.vertices)

        graphs.remove(at: i)
        merged = true
        break
      }
      precondition(merged, "\(graphs)")
    }
    return result
  }

}
