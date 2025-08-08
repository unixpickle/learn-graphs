public enum IsomorphismAlgorithm: Sendable {
  case bruteForce

  /// The algorithm proposed in "An Improved Algorithm for Matching Large Graphs"
  /// https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=f3e10bd7521ec6263a58fdaa4369dfe8ad50888c
  case vf2

  case vf2Hash(iters: Int)
}

extension Graph {

  /// Check if this graph is isomorphic to another graph.
  ///
  /// If so, return a mapping between vertices of this graph and the
  /// corresponding vertices in the other graph.
  public func isomorphism<V1: Hashable>(
    to g: Graph<V1>,
    algorithm: IsomorphismAlgorithm
  ) -> [V: V1]? {
    if vertices.count != g.vertices.count {
      return nil
    }
    switch algorithm {
    case .bruteForce:
      return bruteForceIsomorphism(to: g)
    case .vf2:
      return vf2(to: g)
    case .vf2Hash(let iters):
      return vf2(to: g, hashIters: iters)
    }
  }

  private func bruteForceIsomorphism<V1: Hashable>(to g: Graph<V1>, partial: [V: V1] = [:]) -> [V:
    V1]?
  {
    if partial.count == vertices.count {
      return partial
    }
    let mappedSrc = Set(partial.keys)
    let mappedDst = Set(partial.values)
    let unmappedSrc = vertices.subtracting(mappedSrc)
    let unmappedDst = g.vertices.subtracting(mappedDst)
    for a in unmappedSrc {
      for b in unmappedDst {
        let neighborsA = neighbors(vertex: a)
        let neighborsB = g.neighbors(vertex: b)
        if neighborsA.count != neighborsB.count {
          continue
        }
        let mappedInA = neighborsA.filter(mappedSrc.contains)
        let mappedInB = Set(neighborsB.filter(mappedDst.contains))
        if mappedInA.count != mappedInB.count {
          continue
        }
        let mappedToB = Set(mappedInA.map { partial[$0]! })
        if mappedToB != mappedInB {
          continue
        }
        var newPartial = partial
        newPartial[a] = b
        if let solution = bruteForceIsomorphism(to: g, partial: newPartial) {
          return solution
        }
      }
    }
    return nil
  }

  internal func hashVertices(iters: Int) -> [V: Int] {
    let vs = Array(vertices)
    var hashes = Dictionary(
      uniqueKeysWithValues: zip(vs, vs.map { neighbors(vertex: $0).count })
    )
    func nestedHash(_ i: V) -> Int {
      var h = Hasher()
      h.combine(hashes[i]!)
      h.combine(Set(neighbors(vertex: i).map { hashes[$0]! }))
      return h.finalize()
    }
    for _ in 0..<iters {
      hashes = Dictionary(
        uniqueKeysWithValues: zip(
          vs, vs.map { i in nestedHash(i) }
        )
      )
    }
    return hashes
  }

  private enum VF2StackOp {
    case startDepth(depth: Int)
    case finishDepth(depth: Int, v1: Int, v2: Int)
    case explore(depth: Int, try1: [Int], try2: Int)
  }

  private func vf2<V1: Hashable>(to g: Graph<V1>, hashIters: Int = 0) -> [V: V1]? {
    // Turn the two graphs into graphs of integers in [0, vertices.count).
    let verts1 = Array(vertices)
    let verts2 = Array(g.vertices)
    let verts1ToIndex = Dictionary(uniqueKeysWithValues: zip(verts1, verts1.indices))
    let verts2ToIndex = Dictionary(uniqueKeysWithValues: zip(verts2, verts2.indices))
    let g1 = map { verts1ToIndex[$0]! }
    let g2 = g.map { verts2ToIndex[$0]! }
    let vertCount = vertices.count

    func gToHash(_ g: Graph<Int>) -> [Int] {
      let h = g.hashVertices(iters: hashIters)
      return (0..<vertCount).map { h[$0]! }
    }

    let h1 = gToHash(g1)
    let h2 = gToHash(g2)

    // Mapping from g1 to g2 (core1) and g2 to g1 (core2)
    var core1 = [Int?](repeating: nil, count: vertCount)
    var core2 = [Int?](repeating: nil, count: vertCount)

    // These are the DFS depth when the node became adjacent to the current
    // matched vertices.
    var adjacent1 = [Int](repeating: 0, count: vertCount)
    var adjacent2 = [Int](repeating: 0, count: vertCount)

    func checkCompatible(v1: Int, v2: Int) -> Bool {
      if h1[v1] != h2[v2] {
        return false
      }
      let n1 = g1.neighbors(vertex: v1)
      let n2 = g2.neighbors(vertex: v2)
      if n1.count != n2.count {
        return false
      }
      let mapped1 = n1.compactMap { core1[$0] }
      let mapped2 = n2.compactMap { core2[$0] }
      if mapped1.count != mapped2.count {
        return false
      }
      if !mapped1.allSatisfy(n2.contains) || !mapped2.allSatisfy(n1.contains) {
        return false
      }
      return true
    }

    var queue = [VF2StackOp.startDepth(depth: 1)]
    while let item = queue.popLast() {
      switch item {
      case .finishDepth(let depth, let v1, let v2):
        assert(core1[v1] == v2)
        assert(core2[v2] == v1)
        core1[v1] = nil
        core2[v2] = nil
        for i in g1.neighbors(vertex: v1) {
          assert(adjacent1[i] <= depth)
          if adjacent1[i] == depth {
            adjacent1[i] = 0
          }
        }
        for i in g2.neighbors(vertex: v2) {
          assert(adjacent2[i] <= depth)
          if adjacent2[i] == depth {
            adjacent2[i] = 0
          }
        }
      case .startDepth(let depth):
        let terminal1 = adjacent1.enumerated().compactMap { (i, adjDepth) in
          (adjDepth != 0 && core1[i] == nil) ? i : nil
        }
        let terminal2 = adjacent2.enumerated().compactMap { (i, adjDepth) in
          (adjDepth != 0 && core2[i] == nil) ? i : nil
        }
        if terminal1.count != terminal2.count {
          // This is an invalid state, so we will not expand further.
          continue
        }
        if let try2 = terminal2.first {
          queue.append(.explore(depth: depth, try1: terminal1, try2: try2))
        } else {
          // Either we are done or need to start a new connected component.
          let set1 = core1.enumerated().compactMap { (i, x) in x == nil ? i : nil }
          let set2 = core2.enumerated().compactMap { (i, x) in x == nil ? i : nil }
          if let try2 = set2.first {
            queue.append(.explore(depth: depth, try1: set1, try2: try2))
          } else {
            return Dictionary(
              uniqueKeysWithValues: zip(verts1, core1.map { verts2[$0!] })
            )
          }
        }
      case .explore(let depth, var try1, let try2):
        let first = try1.popLast()!
        if !try1.isEmpty {
          queue.append(.explore(depth: depth, try1: try1, try2: try2))
        }
        if checkCompatible(v1: first, v2: try2) {
          queue.append(.finishDepth(depth: depth, v1: first, v2: try2))
          queue.append(.startDepth(depth: depth + 1))
          assert(core1[first] == nil)
          assert(core2[try2] == nil)
          core1[first] = try2
          core2[try2] = first
          for neighbor in g1.neighbors(vertex: first) {
            if adjacent1[neighbor] == 0 {
              adjacent1[neighbor] = depth
            }
          }
          for neighbor in g2.neighbors(vertex: try2) {
            if adjacent2[neighbor] == 0 {
              adjacent2[neighbor] = depth
            }
          }
        }
      }
    }

    return nil
  }

}
