import Foundation
import Testing

@testable import LearnGraphs

@Test
func testBranchAndCut() {
  struct Point: Hashable {
    let latitude: Double
    let longitude: Double

    private func toRadians(_ coord: Double) -> Double {
      let deg = floor(coord)
      let min = coord - deg
      let decimalDegrees = deg + (5.0 * min) / 3.0
      return .pi * decimalDegrees / 180.0
    }

    func geoDistance(to other: Point) -> Double {
      let R = 6378.388

      let lat1 = toRadians(self.latitude)
      let lon1 = toRadians(self.longitude)
      let lat2 = toRadians(other.latitude)
      let lon2 = toRadians(other.longitude)

      let q1 = cos(lat1) * cos(lat2) * cos(lon1 - lon2)
      let q2 = sin(lat1) * sin(lat2)
      let centralAngle = acos(q1 + q2)

      return (R * centralAngle + 0.5).rounded()
    }
  }

  let coordinates: [Point] = [
    Point(latitude: 16.47, longitude: 96.10),
    Point(latitude: 16.47, longitude: 94.44),
    Point(latitude: 20.09, longitude: 92.54),
    Point(latitude: 22.39, longitude: 93.37),
    Point(latitude: 25.23, longitude: 97.24),
    Point(latitude: 22.00, longitude: 96.05),
    Point(latitude: 20.47, longitude: 97.02),
    Point(latitude: 17.20, longitude: 96.29),
    Point(latitude: 16.30, longitude: 97.38),
    Point(latitude: 14.05, longitude: 98.12),
    Point(latitude: 16.53, longitude: 97.38),
    Point(latitude: 21.52, longitude: 95.59),
    Point(latitude: 19.41, longitude: 97.13),
    Point(latitude: 20.09, longitude: 94.55),
  ]

  func edgeCost(_ x: Edge<Point>) -> Double {
    let vs = Array(x.vertices)
    return vs[0].geoDistance(to: vs[1])
  }

  var graph = Graph(vertices: coordinates)
  for (i, x) in coordinates.enumerated() {
    for y in coordinates[..<i] {
      graph.insertEdge(x, y)
    }
  }
  let path = graph.branchAndCutTSP(edgeCost: edgeCost)
  #expect(path.first! == path.last!)
  #expect(Set(path) == Set(coordinates))
  #expect(path.count == coordinates.count + 1)

  let pathLength = zip(path[..<(path.count - 1)], path[1...]).map {
    $0.0.geoDistance(to: $0.1)
  }.reduce(0, +)
  #expect(abs(pathLength - 3323.0) < 1e-5)
}
