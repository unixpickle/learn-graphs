public class TreeDecompositionBag<V: Hashable>: PointerHasher, CustomStringConvertible {
  public let bag: Set<V>

  public init(bag: Set<V>) {
    self.bag = bag
  }

  public var description: String {
    "TreeDecompositionBag(bag: \(bag))"
  }
}

public class NiceTreeDecomposition<V: Hashable> {

  public indirect enum NodeOp {
    case leaf(V)
    case introduce(V)
    case forget(V)
    case join(TreeDecompositionBag<V>, TreeDecompositionBag<V>)

    var isLeaf: Bool {
      if case .leaf(_) = self {
        true
      } else {
        false
      }
    }

    var isJoin: Bool {
      if case .join(_, _) = self {
        true
      } else {
        false
      }
    }
  }

  public let root: TreeDecompositionBag<V>
  public let tree: Graph<TreeDecompositionBag<V>>
  public let parent: [TreeDecompositionBag<V>: TreeDecompositionBag<V>]
  public let op: [TreeDecompositionBag<V>: NodeOp]

  /// Turn a tree into a nice tree.
  ///
  /// Raises an error if the supplied graph is not actually a tree.
  public init(tree g: Graph<TreeDecompositionBag<V>>) {
    root = g.vertices.max { $0.bag.count < $1.bag.count }!
    guard let (_, children) = g.asTree(root: root) else {
      fatalError("the passed graph is not a tree")
    }

    var tree = Graph<TreeDecompositionBag<V>>(vertices: [root])
    var parent = [TreeDecompositionBag<V>: TreeDecompositionBag<V>]()
    var op = [TreeDecompositionBag<V>: NodeOp]()

    var queue = [(root, children[root, default: []])]
    while let (next, nextChildren) = queue.popLast() {
      if nextChildren.count > 1 {
        let child1 = TreeDecompositionBag<V>(bag: next.bag)
        let child2 = TreeDecompositionBag<V>(bag: next.bag)
        tree.insert(vertex: child1)
        tree.insert(vertex: child2)
        tree.insertEdge(next, child1)
        tree.insertEdge(next, child2)
        op[next] = .join(child1, child2)
        parent[child1] = next
        parent[child2] = next

        let ch = Array(nextChildren)
        queue.append((child1, Set(ch[..<(ch.count / 2)])))
        queue.append((child2, Set(ch[(ch.count / 2)...])))
      } else if nextChildren.count == 1 {
        let child = nextChildren.first!
        if let introduced = next.bag.subtracting(child.bag).first {
          let newChild = TreeDecompositionBag<V>(bag: next.bag.subtracting([introduced]))
          tree.insert(vertex: newChild)
          tree.insertEdge(next, newChild)
          op[next] = .introduce(introduced)
          parent[newChild] = next
          queue.append((newChild, [child]))
        } else if let removed = child.bag.subtracting(next.bag).first {
          let newChild = TreeDecompositionBag<V>(bag: next.bag.union([removed]))
          tree.insert(vertex: newChild)
          tree.insertEdge(next, newChild)
          op[next] = .forget(removed)
          parent[newChild] = next
          queue.append((newChild, [child]))
        } else {
          // We have reached an identical parent to the child, so we can now
          // skip the child in the resulting tree.
          queue.append((next, children[child, default: []]))
        }
      } else {
        assert(nextChildren.isEmpty)
        if next.bag.count == 1 {
          op[next] = .leaf(next.bag.first!)
        } else {
          let first = next.bag.first!
          let rest = next.bag.subtracting([first])
          let child = TreeDecompositionBag<V>(bag: rest)
          tree.insert(vertex: child)
          tree.insertEdge(next, child)
          parent[child] = next
          op[next] = .introduce(first)
          queue.append((child, []))
        }
      }
    }

    self.tree = tree
    self.parent = parent
    self.op = op
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
