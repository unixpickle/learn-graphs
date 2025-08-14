extension Graph {

  /// If the graph is a tree, encode it in Graphviz DOT.
  public func treeDotRepresentation(root: V? = nil, label: (V) -> String) -> String? {
    guard let (root, children) = asTree(root: root) else {
      return nil
    }
    let vToId = Dictionary(
      uniqueKeysWithValues: vertices.enumerated().map { (i, v) in (v, "\(i)") }
    )
    var lines: [String] = [
      "digraph G {",
      "  graph [rankdir=TB];",
      "  node [shape=oval,fontname=Helvetica];",
    ]
    func walk(_ v: V) {
      lines.append("  \"\(vToId[v]!)\" [label=\"\(label(v))\"];")
      for c in (children[v] ?? []) {
        lines.append("  \"\(vToId[v]!)\" -> \"\(vToId[c]!)\";")
        walk(c)
      }
    }
    walk(root)
    lines.append("}")
    return lines.joined(separator: "\n")
  }

}
