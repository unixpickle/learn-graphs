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

  public func treeDecomposition(
    algorithm: TreeDecompositionAlgorithm = .arnborg, maxTreewidth: Int? = nil
  ) -> Graph<TreeDecompositionBag<V>>? {
    switch algorithm {
    case .arnborg:
      for sepSize in 1...(maxTreewidth == nil ? vertices.count : (maxTreewidth! + 1)) {
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
    let separators = allSeparators(maxSize: separatorSize)

    var sepToClass = [Set<V>: [ArnborgSeparatorClass]]()
    var clsToTree = [ArnborgSeparatorClass: Graph<TreeDecompositionBag<V>>]()
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
      var found = false
      if cls.count <= separatorSize {
        clsToTree[cls] = .init(vertices: [TreeDecompositionBag(bag: cls.vertices)])
        found = true
      } else {
        for v in cls.vertices {
          // We might end up with some additional v in the child bag
          // which has some edges connected to cls.separator, in which
          // case we will need to create an extra bag with these vertices
          // and with v.
          let connectedToV = Set(cls.separator.filter { v != $0 && contains(edge: Edge(v, $0)) })

          let superset = cls.separator.union([v])
          let relevantClasses = classes[..<i].filter {
            clsToTree[$0] != nil
              && $0.separator.allSatisfy(superset.contains)
              && $0.vertices.allSatisfy(cls.component.union($0.separator).contains)
              && (!$0.separator.contains(v)
                || $0.separator.union(connectedToV).count <= separatorSize)
          }
          var classesBySeparator = [Set<V>: [ArnborgSeparatorClass]]()
          for cls1 in relevantClasses {
            classesBySeparator[cls1.separator, default: []].append(cls1)
          }
          for (sep, classes) in classesBySeparator {
            let covered = Set(classes.flatMap { $0.vertices })
            if cls.component.allSatisfy(covered.contains) {
              // We have found a new tree.
              let outerRoot = TreeDecompositionBag<V>(bag: cls.separator)
              var tree = Graph<TreeDecompositionBag<V>>(vertices: [outerRoot])
              var connector = outerRoot
              if sep.contains(v) {
                let newBag = sep.union(connectedToV)
                if newBag != cls.separator {
                  connector = TreeDecompositionBag<V>(bag: newBag)
                  tree.insert(vertex: connector)
                  tree.insertEdge(outerRoot, connector)
                }
              }
              for component in classes {
                let subTree = clsToTree[component]!
                tree.insert(graph: subTree)
                let innerRoot = subTree.vertices.filter { sep.allSatisfy($0.bag.contains) }.first!
                tree.insertEdge(innerRoot, connector)
              }
              clsToTree[cls] = tree
              found = true
              break
            }
          }
          if found {
            break
          }
        }
      }
      if found && sepToClass[cls.separator]!.allSatisfy({ clsToTree[$0] != nil }) {
        let outerRoot = TreeDecompositionBag<V>(bag: cls.separator)
        var tree = Graph<TreeDecompositionBag<V>>(vertices: [outerRoot])
        for component in sepToClass[cls.separator]! {
          let subTree = clsToTree[component]!
          tree.insert(graph: subTree)
          let innerRoot = subTree.vertices.filter { cls.separator.allSatisfy($0.bag.contains) }
            .first!
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
