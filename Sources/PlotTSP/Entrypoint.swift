import AppKit
import CoreGraphics
import Foundation
import LearnGraphs

@main
struct Entrypoint {
  static func main() {
    let args = CommandLine.arguments

    guard args.count == 2 else {
      print("Usage: \(args[0]) <problem.tsp>")
      exit(1)
    }

    let inputFile = args[1]
    do {
      let problem = try Problem.load(from: inputFile)

      print("running Christofides...")
      var path = problem.graph.christofides(edgeCost: problem.edgeCost)

      drawTSP(
        graph: problem.graph,
        tour: path,
        outputURL: URL(fileURLWithPath: "plot_christofides.png")
      )

      print("running branch-and-cut...")
      path = problem.graph.branchAndCutTSP(edgeCost: problem.edgeCost) { msg in
        print("[solve] \(msg)")
      }

      drawTSP(
        graph: problem.graph,
        tour: path,
        outputURL: URL(fileURLWithPath: "plot_optimal.png")
      )
    } catch {
      print("ERROR: \(error)")
      exit(1)
    }
  }
}
