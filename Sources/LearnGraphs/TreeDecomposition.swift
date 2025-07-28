public class TreeDecompositionBag<V: Hashable>: PointerHasher, CustomStringConvertible {
  public let bag: Set<V>

  public init(bag: Set<V>) {
    self.bag = bag
  }

  public var description: String {
    "TreeDecompositionBag(bag: \(bag))"
  }
}

public enum TreeDecompositionAlgorithm: Sendable {
  /// A dynamic programming brute force technique based on separators.
  case arnborg
}

extension Graph {

  /// If the graph is a tree, extract the tree from it, optionally specifying
  /// which node should be the root.
  public func asTree(root: V? = nil) -> (root: V, children: [V: Set<V>])? {
    if vertices.isEmpty {
      return nil
    }
    let root = root ?? vertices.first!

    var visited: Set<V> = [root]
    var children = [V: Set<V>]()
    var queue = [root]
    while let curVert = queue.popLast() {
      for neighbor in neighbors(vertex: curVert) {
        if visited.contains(neighbor) {
          if children[neighbor, default: []].contains(curVert) {
            // This is our parent, it's okay that it's been seen.
            continue
          } else {
            // This is a back-edge to some higher vertex, so there is
            // a cycle and this is not a tree.
            return nil
          }
        }
        visited.insert(neighbor)
        children[curVert, default: []].insert(neighbor)
        queue.append(neighbor)
      }
    }

    return (root: root, children: children)
  }

  public func treeDecomposition(
    algorithm: TreeDecompositionAlgorithm = .arnborg, maxTreewidth: Int? = nil
  ) -> Graph<TreeDecompositionBag<V>>? {
    switch algorithm {
    case .arnborg:
      for sepSize in 1...(maxTreewidth == nil ? vertices.count : maxTreewidth!) {
        if let result = arnborgTreeDecomposition(separatorSize: sepSize) {
          return result
        }
      }
    }
    return nil
  }

  private struct ArnborgSeparatorClass: Hashable {
    let separator: Set<V>
    let component: Set<V>

    var count: Int { separator.count + component.count }
    var vertices: Set<V> { separator.union(component) }
  }

  public func arnborgTreeDecomposition(separatorSize: Int) -> Graph<TreeDecompositionBag<V>>? {
    if vertices.count <= separatorSize + 1 {
      return .init(vertices: [.init(bag: vertices)])
    }

    let separators = allSeparators(maxSize: separatorSize)

    var sepToClass = [Set<V>: [ArnborgSeparatorClass]]()
    var clsToTree = [
      ArnborgSeparatorClass: (root: TreeDecompositionBag<V>, graph: Graph<TreeDecompositionBag<V>>)
    ]()
    var classes = [ArnborgSeparatorClass]()

    for sep in separators {
      var newG = self
      for v in sep {
        newG.remove(vertex: v)
      }
      for comp in newG.components() {
        let cls = ArnborgSeparatorClass(separator: sep, component: comp.vertices)
        sepToClass[sep, default: []].append(cls)
        classes.append(cls)
      }
    }

    classes.sort { $0.count < $1.count }

    for (i, cls) in classes.enumerated() {
      if cls.count <= separatorSize + 1 {
        let bag = TreeDecompositionBag(bag: cls.vertices)
        clsToTree[cls] = (root: bag, graph: .init(vertices: [bag]))
      } else {
        var found = false
        for v in cls.component {
          // Find every component that has at most one extra vertex v
          // from the component of the parent.
          let allowedSeparator = cls.separator.union([v])
          let relevantClasses = classes[..<i].filter {
            clsToTree[$0] != nil
              && $0.separator.allSatisfy(allowedSeparator.contains)
              && $0.separator.contains(v)
              && $0.vertices.allSatisfy(cls.component.union($0.separator).contains)
          }
          let covered = Set(relevantClasses.flatMap { x in x.vertices })
          if !cls.component.allSatisfy(covered.contains) {
            continue
          }

          // We can form a new tree with v added to the root.
          found = true
          let outerRoot = TreeDecompositionBag<V>(bag: cls.separator.union([v]))
          var tree = Graph<TreeDecompositionBag<V>>(vertices: [outerRoot])

          var alreadyCovered: Set<V> = []
          for cls1 in relevantClasses {
            let (innerRoot, subTree) = clsToTree[cls1]!

            let filteredMapping = Dictionary(
              uniqueKeysWithValues: subTree.vertices.map { bagV in
                (bagV, TreeDecompositionBag<V>(bag: bagV.bag.subtracting(alreadyCovered)))
              }
            )

            // After filtering, the tree might have been broken up across empty
            // bags, so we insert each tree separately.
            let treePieces = subTree.map({ filteredMapping[$0]! }).filteringVertices({
              !$0.bag.isEmpty
            }).components()
            for piece in treePieces {
              guard let arbitraryVertex = piece.vertices.first else {
                continue
              }
              tree.insert(graph: piece)
              if piece.vertices.contains(filteredMapping[innerRoot]!) {
                // The root may have been preserved, so we should connect to it.
                tree.insertEdge(filteredMapping[innerRoot]!, outerRoot)
              } else {
                // This was a separated sub-tree with no vertices in common with
                // the outer root, so we can connect it at will.
                tree.insertEdge(arbitraryVertex, outerRoot)
              }
            }

            alreadyCovered.formUnion(cls1.component)
          }
          clsToTree[cls] = (root: outerRoot, graph: tree)
          break
        }
        if !found {
          // Skip coverage check for full graph.
          continue
        }
      }

      if sepToClass[cls.separator]!.allSatisfy({ clsToTree[$0] != nil }) {
        let outerRoot = TreeDecompositionBag<V>(bag: cls.separator)
        var tree = Graph<TreeDecompositionBag<V>>(vertices: [outerRoot])
        for component in sepToClass[cls.separator]! {
          let (innerRoot, subTree) = clsToTree[component]!
          tree.insert(graph: subTree)
          tree.insertEdge(innerRoot, outerRoot)
        }
        return tree
      }
    }
    return nil
  }

  private func allSeparators(maxSize: Int) -> [Set<V>] {
    (1...maxSize).flatMap { allVertexSubsets(size: $0) }.filter { sep in
      var newG = self
      for v in sep {
        newG.remove(vertex: v)
      }
      return newG.vertices.count == 0 || newG.components().count > 1
    }
  }

  private func allVertexSubsets(size: Int) -> [Set<V>] {
    if size == 1 {
      return vertices.map { Set([$0]) }
    } else if size == 0 {
      return [[]]
    }

    let smallerSubsets = allVertexSubsets(size: size - 1)

    var results: Set<Set<V>> = []
    for v in vertices {
      results.formUnion(smallerSubsets.filter { !$0.contains(v) }.map { $0.union([v]) })
    }

    return Array(results)
  }

}
