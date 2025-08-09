import Foundation
import LearnGraphs

@main
struct App {
  static func main() {
    print("creating graph...")
    let graph = graphFromMap()

    print("computing tree decomp...")
    let decomp = graph.mcsTriangulated().chordalTreeDecomposition()!
    print(" => upper-bounded treewidth", decomp.vertices.map { $0.bag.count - 1 }.max()!)
    print("coloring...")
    let nice = NiceTreeDecomposition(tree: decomp)
    let coloring = graph.color(["red", "yellow", "green", "blue"], usingTree: nice)!
    print("exporting image...")

    guard let url = Bundle.module.url(forResource: "input", withExtension: "svg"),
      var contents = try? String(contentsOf: url, encoding: .utf8)
    else {
      fatalError("Failed to read input.svg from bundle")
    }

    for (state, color) in coloring {
      contents.replace(
        "<path class=\"\(state)\"", with: "<path class=\"\(state)\" fill=\"\(color)\""
      )
    }

    try! contents.write(to: URL(filePath: "output.svg"), atomically: true, encoding: .utf8)
  }
}
