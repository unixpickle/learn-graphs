public enum ColoringAlgorithm: Sendable {
  /// Recursively add edges or contract unconnected vertices.
  case addContract

  /// Compute an optimal tree decomposition and do dynamic programming
  /// on top of it.
  case treeDecomposition(TreeDecompositionAlgorithm)

  /// Use depth-first search.
  case depthFirst
}

extension Graph {

  /// Compute a coloring of the graph with as few colors as possible.
  public func color(algorithm: ColoringAlgorithm = .addContract) -> (colors: [V: Int], count: Int) {
    switch algorithm {
    case .addContract:
      colorAddContract()
    case .treeDecomposition(let algo):
      colorTreeDecomposition(algorithm: algo)
    case .depthFirst:
      colorDepthFirst()
    }
  }

  private func colorTreeDecomposition(algorithm: TreeDecompositionAlgorithm) -> (
    colors: [V: Int], count: Int
  ) {
    let rawTree = treeDecomposition(algorithm: algorithm)!
    let niceTree = NiceTreeDecomposition(tree: rawTree)
    for i in 1... {
      if let c = color(0..<i, usingTree: niceTree) {
        return (colors: c, count: i)
      }
    }
    fatalError()
  }

  private func colorAddContract() -> (colors: [V: Int], count: Int) {
    var queue: [Graph<ContractedVertex<V>>] = [map { ContractedVertex(vertices: [$0]) }]

    var bestCompleteGraph: Set<ContractedVertex<V>>? = nil

    while let g = queue.popLast() {
      var missingEdges = [Edge<ContractedVertex<V>>]()
      let vs = Array(g.vertices)
      for (i, v1) in vs.enumerated() {
        for (j, v2) in vs.enumerated() {
          if i >= j {
            continue
          }
          let e = Edge(v1, v2)
          if !g.contains(edge: e) {
            missingEdges.append(e)
          }
        }
      }

      if missingEdges.count == 0 {
        if bestCompleteGraph == nil || bestCompleteGraph!.count > g.vertices.count {
          bestCompleteGraph = g.vertices
        }
        continue
      }

      // We will try all possible edge additions *after* contractions,
      // which means we push edge additions to the stack first.
      for edge in missingEdges {
        queue.append(g.inserting(edge: edge))
      }
      for edge in missingEdges {
        let vs = Array(edge.vertices)
        var g1 = g
        let neighbors = g.neighbors(vertex: vs[0]).union(g.neighbors(vertex: vs[1]))
        g1.remove(vertex: vs[0])
        g1.remove(vertex: vs[1])
        let newVertex = ContractedVertex<V>(vertices: vs[0].vertices.union(vs[1].vertices))
        g1.insert(vertex: newVertex)
        for neighbor in neighbors {
          g1.insertEdge(newVertex, neighbor)
        }
        queue.append(g1)
      }
    }
    guard let bestCompleteGraph = bestCompleteGraph else {
      fatalError()
    }
    let groups = Array(bestCompleteGraph)
    var coloring = [V: Int]()
    for (color, group) in groups.enumerated() {
      for v in group.vertices {
        coloring[v] = color
      }
    }
    return (colors: coloring, count: groups.count)
  }

  private enum ColorDepthFirstOp {
    case color(V, Int)
    case uncolor(V, oldColorCount: Int)
    case finishColoring(V)
  }

  private func colorDepthFirst() -> (colors: [V: Int], count: Int) {
    var currentAssignment: [V: Int] = [:]
    var currentCount = 0

    var bestAssignment: [V: Int]? = nil
    var bestCount: Int? = nil

    let firstV = vertices.first!
    var opQueue: [ColorDepthFirstOp] = [.uncolor(firstV, oldColorCount: 0), .color(firstV, 0)]
    var neighborQueue = PriorityQueue<V, Int>()
    for v in vertices {
      if v != firstV {
        neighborQueue.push(v, priority: contains(edge: Edge(v, firstV)) ? 1 : 0)
      }
    }
    while let op = opQueue.popLast() {
      switch op {
      case .color(let v, let color):
        assert(!neighborQueue.contains(v))
        assert(color <= currentCount)
        if color == currentCount {
          if let bc = bestCount, (currentCount + 1) >= bc {
            // Prune this part of the search tree because we already
            // have a better solution.
            guard case .uncolor(let v1, let oldCount) = opQueue.popLast() else {
              fatalError()
            }
            assert(v1 == v)
            assert(oldCount == currentCount)
            break
          }
          currentCount += 1
        }
        currentAssignment[v] = color

        if let (nextV, priority) = neighborQueue.pop() {
          for neighbor in neighbors(vertex: nextV) {
            if let oldPriority = neighborQueue.currentPriority(for: neighbor) {
              neighborQueue.modify(
                item: neighbor,
                priority: oldPriority + 1
              )
            }
          }

          opQueue.append(.finishColoring(nextV))

          assert(priority == neighbors(vertex: nextV).count { currentAssignment[$0] != nil })
          // Try existing colors.
          let neighborColors = Set(neighbors(vertex: nextV).compactMap { currentAssignment[$0] })
          for color in 0..<currentCount {
            if !neighborColors.contains(color) {
              opQueue.append(.uncolor(nextV, oldColorCount: currentCount))
              opQueue.append(.color(nextV, color))
            }
          }

          // Allocate a new color.
          opQueue.append(.uncolor(nextV, oldColorCount: currentCount))
          opQueue.append(.color(nextV, currentCount))
        } else {
          if bestCount == nil || currentCount < bestCount! {
            bestCount = currentCount
            bestAssignment = currentAssignment
          }
        }
      case .uncolor(let v, let oldCount):
        currentAssignment.removeValue(forKey: v)
        currentCount = oldCount
      case .finishColoring(let v):
        assert(currentAssignment[v] == nil)
        assert(!neighborQueue.contains(v))
        var assignedNeighborCount = 0
        for neighbor in neighbors(vertex: v) {
          if let neighborPriority = neighborQueue.currentPriority(for: neighbor) {
            neighborQueue.modify(
              item: neighbor,
              priority: neighborPriority - 1
            )
          } else {
            assignedNeighborCount += 1
          }
        }
        neighborQueue.push(v, priority: assignedNeighborCount)
      }
    }

    return (colors: bestAssignment!, count: bestCount!)
  }

  private enum ColorOp {
    case recurse(TreeDecompositionBag<V>)
    case processResult(TreeDecompositionBag<V>)
  }

  /// Compute the coloring of the graph with the provided colors.
  ///
  /// This uses dynamic programming over a tree decomposition, which must be
  /// computed separately and supplied.
  public func color<Color: Hashable, C: Collection<Color>>(
    _ colors: C, usingTree tree: NiceTreeDecomposition<V>
  ) -> [V: Color]? {
    let colors = Array(colors)

    // As always, this is a recursive function, defined explicitly as a stack.
    var opStack = [ColorOp.recurse(tree.root)]
    var resultStack: [[[V: Color]]] = []

    while let op = opStack.popLast() {
      switch op {
      case .recurse(let bagNode):
        switch tree.op[bagNode]! {
        case .leaf(let v):
          resultStack.append(colors.map { [v: $0] })
        default:
          opStack.append(.processResult(bagNode))
          for ch in tree.children(vertex: bagNode) {
            opStack.append(.recurse(ch))
          }
        }
      case .processResult(let bagNode):
        switch tree.op[bagNode]! {
        case .leaf(_):
          fatalError()
        case .join:
          let options1 = resultStack.popLast()!
          let options2 = resultStack.popLast()!
          let merged = mergeCompatibleColorings(common: bagNode.bag, c1: options1, c2: options2)
          if merged.isEmpty {
            return nil
          }
          resultStack.append(merged)
        case .introduce(let v):
          let colorings = resultStack.popLast()!
          var newColorings = [[V: Color]]()
          for coloring in colorings {
            for color in colors {
              var bad = false
              for neighbor in neighbors(vertex: v) {
                if let c = coloring[neighbor], c == color {
                  bad = true
                  break
                }
              }
              if !bad {
                var coloring = coloring
                coloring[v] = color
                newColorings.append(coloring)
              }
            }
          }
          if newColorings.isEmpty {
            return nil
          }
          resultStack.append(newColorings)
        case .forget(_):
          let colorings = resultStack.popLast()!
          let deduped = bagColorings(bag: bagNode.bag, colorings: colorings).values
          resultStack.append(Array(deduped))
        }
      }
    }
    assert(resultStack.count == 1)
    return resultStack.first!.first
  }
}

private func mergeCompatibleColorings<V: Hashable, Color: Hashable>(
  common: Set<V>, c1: [[V: Color]], c2: [[V: Color]]
) -> [[V: Color]] {
  let bag1 = bagColorings(bag: common, colorings: c1)
  let bag2 = bagColorings(bag: common, colorings: c2)
  let commonKeys = Set(bag1.keys).intersection(bag2.keys)
  return commonKeys.map { bag1[$0]!.merging(bag2[$0]!, uniquingKeysWith: { (a, b) in a }) }
}

private func bagColorings<V: Hashable, Color: Hashable>(bag: Set<V>, colorings: [[V: Color]])
  -> [[V:
  Color]: [V: Color]]
{
  var result = [[V: Color]: [V: Color]]()
  for coloring in colorings {
    let bagColors = coloring.filter { bag.contains($0.key) }
    result[bagColors] = coloring
  }
  return result
}
