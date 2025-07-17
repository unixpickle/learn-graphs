import AppKit
import CoreGraphics
import Foundation
import LearnGraphs

@main
struct Entrypoint {
  static func main() {
    let mgr = FileManager.default
    let outDir = URL(filePath: "animation")
    try? mgr.createDirectory(at: outDir, withIntermediateDirectories: false)

    let graph = randomPlanarGraph(vertCount: 20)
    let initCoords = Dictionary(uniqueKeysWithValues: graph.vertices.map { ($0, Point.random()) })

    print("embedding...")
    let emb = PlanarGraph.embed(graph: graph)
    let combined = PlanarGraph.mergeBiconnected(emb![0])

    var bestResult: [Int: Point]? = nil
    var bestShortEdge: Double = 0

    print("searching for solutions...")
    for _ in 0..<10 {
      let triangulated = combined.triangulated(algorithm: .randomized)
      let triGraph = triangulated.graph()
      for boundary in triangulated.faces()! {
        assert(boundary.count == 4)
        let triCoords = triGraph.tutteEmbedding(boundary: [
          boundary[0]: (0.5, 0.0),
          boundary[1]: (1.0, 1.0),
          boundary[2]: (0.0, 1.0),
        ])!
        let finalCoords = triCoords.mapValues { Point(x: $0.0, y: $0.1) }
        let lengths = edgeLengths(graph: graph, coords: finalCoords)
        let minLength = lengths.reduce(Double.infinity, min)
        if minLength > bestShortEdge {
          bestShortEdge = minLength
          bestResult = finalCoords
        }
      }
    }

    print("plotting...")
    for (i, frac) in stride(from: 0.0, through: 1.0, by: 1.0 / 64.0).enumerated() {
      let interp = interpolate(from: initCoords, to: bestResult!, frac: frac)
      drawGraph(
        graph: graph.map { interp[$0]! },
        outputURL: outDir.appending(component: "\(i).png")
      )
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
