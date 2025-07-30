extension Graph {
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
