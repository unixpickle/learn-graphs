import Foundation
import LearnGraphs

struct Point: Hashable {
  let x: Double
  let y: Double

  func distance(to other: Point) -> Double {
    sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
  }
}

struct Problem {
  let graph: Graph<Point>

  func edgeCost(_ edge: Edge<Point>) -> Double {
    let vs = Array(edge.vertices)
    return vs[0].distance(to: vs[1])
  }

  static func load(from path: String) throws -> Problem {
    let points = try loadTSPFile(from: path)
    var graph = Graph(vertices: points)
    for v1 in graph.vertices {
      for v2 in graph.vertices {
        if v1 != v2 {
          graph.insertEdge(v1, v2)
        }
      }
    }
    return Problem(graph: graph)
  }
}

enum TSPParseError: Error, LocalizedError {
  case missingNodeSection
  case invalidCoordinateLine(String)

  var errorDescription: String? {
    switch self {
    case .missingNodeSection:
      return "Missing NODE_COORD_SECTION."
    case .invalidCoordinateLine(let line):
      return "Invalid coordinate line: \(line)"
    }
  }
}

func loadTSPFile(from path: String) throws -> [Point] {
  let content = try String(contentsOfFile: path)

  let lines = content.components(separatedBy: .newlines).map {
    $0.trimmingCharacters(in: .whitespaces)
  }

  guard let nodeSectionIndex = lines.firstIndex(where: { $0.uppercased() == "NODE_COORD_SECTION" })
  else {
    throw TSPParseError.missingNodeSection
  }

  var points = [Point]()

  for line in lines[(nodeSectionIndex + 1)...] {
    if line.uppercased() == "EOF" || line.isEmpty { break }
    let components = line.split(separator: " ", omittingEmptySubsequences: true)
    guard components.count == 3,
      let x = Double(components[1]),
      let y = Double(components[2])
    else {
      throw TSPParseError.invalidCoordinateLine(line)
    }
    points.append(Point(x: x, y: y))
  }

  return points
}
