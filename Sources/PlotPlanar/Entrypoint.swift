import AppKit
import CoreGraphics
import Foundation
import LearnGraphs

@main
struct Entrypoint {
  static func main() {
    do {
      let mgr = FileManager.default
      let outDir = URL(filePath: "animation")
      try mgr.createDirectory(at: outDir, withIntermediateDirectories: false)

      let graph = randomPlanarGraph()
      let initCoords = Dictionary(uniqueKeysWithValues: graph.vertices.map { ($0, Point.random()) })

      // Solve for coords
      let emb = PlanarGraph.embed(graph: graph)
      let combined = PlanarGraph.mergeBiconnected(emb![0])
      let triangulated = combined.triangulated()
      let triGraph = triangulated.graph()

      var bestResult: [Int: Point]? = nil
      var bestLengthVar: Double = Double.infinity

      for boundary in triangulated.faces()! {
        assert(boundary.count == 4)
        let triCoords = triGraph.tutteEmbedding(boundary: [
          boundary[0]: (0.0, 0.0),
          boundary[1]: (1.0, 1.0),
          boundary[2]: (0.0, 1.0),
        ])!
        let finalCoords = triCoords.mapValues { Point(x: $0.0, y: $0.1) }
        let lengths = edgeLengths(graph: graph, coords: finalCoords)
        let mean = lengths.reduce(0, +)
        let variance = lengths.map { pow($0 - mean, 2) }.reduce(0, +)
        if variance < bestLengthVar {
          bestLengthVar = variance
          bestResult = finalCoords
        }
        print("result of variance \(variance) (best \(bestLengthVar))")
      }

      for (i, frac) in stride(from: 0.0, through: 1.0, by: 1.0 / 64.0).enumerated() {
        let interp = interpolate(from: initCoords, to: bestResult!, frac: frac)
        drawGraph(
          graph: graph.map { interp[$0]! },
          outputURL: outDir.appending(component: "\(i).png")
        )
      }
    } catch {
      print("ERROR: \(error)")
      exit(1)
    }
  }
}

func interpolate(from: [Int: Point], to: [Int: Point], frac: Double) -> [Int: Point] {
  Dictionary(
    uniqueKeysWithValues: from.map {
      ($0.0, Point.interpolate(from: $0.1, to: to[$0.0]!, frac: frac))
    }
  )
}

func edgeLengths(graph: Graph<Int>, coords: [Int: Point]) -> [Double] {
  graph.edgeSet.map { edge in
    let vs = Array(edge.vertices)
    let c1 = coords[vs[0]]!
    let c2 = coords[vs[1]]!
    return c1.distance(to: c2)
  }
}
