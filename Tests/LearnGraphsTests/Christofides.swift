import Foundation
import Testing

@testable import LearnGraphs

@Test
func testChristofidesBurma14() {
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
  let path = graph.christofides(edgeCost: edgeCost)
  #expect(path.first! == path.last!)
  #expect(Set(path) == Set(coordinates))
  #expect(path.count == coordinates.count + 1)

  let pathLength = zip(path[..<(path.count - 1)], path[1...]).map {
    $0.0.geoDistance(to: $0.1)
  }.reduce(0, +)
  #expect(pathLength < 3323.0 * 3.0 / 2.0)
}

@Test
func testChristofidesBerlin52() {
  struct Point: Hashable {
    let x: Double
    let y: Double

    func distance(to other: Point) -> Double {
      sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }
  }

  let coordinates: [Point] = [
    Point(x: 565.0, y: 575.0),
    Point(x: 25.0, y: 185.0),
    Point(x: 345.0, y: 750.0),
    Point(x: 945.0, y: 685.0),
    Point(x: 845.0, y: 655.0),
    Point(x: 880.0, y: 660.0),
    Point(x: 25.0, y: 230.0),
    Point(x: 525.0, y: 1000.0),
    Point(x: 580.0, y: 1175.0),
    Point(x: 650.0, y: 1130.0),
    Point(x: 1605.0, y: 620.0),
    Point(x: 1220.0, y: 580.0),
    Point(x: 1465.0, y: 200.0),
    Point(x: 1530.0, y: 5.0),
    Point(x: 845.0, y: 680.0),
    Point(x: 725.0, y: 370.0),
    Point(x: 145.0, y: 665.0),
    Point(x: 415.0, y: 635.0),
    Point(x: 510.0, y: 875.0),
    Point(x: 560.0, y: 365.0),
    Point(x: 300.0, y: 465.0),
    Point(x: 520.0, y: 585.0),
    Point(x: 480.0, y: 415.0),
    Point(x: 835.0, y: 625.0),
    Point(x: 975.0, y: 580.0),
    Point(x: 1215.0, y: 245.0),
    Point(x: 1320.0, y: 315.0),
    Point(x: 1250.0, y: 400.0),
    Point(x: 660.0, y: 180.0),
    Point(x: 410.0, y: 250.0),
    Point(x: 420.0, y: 555.0),
    Point(x: 575.0, y: 665.0),
    Point(x: 1150.0, y: 1160.0),
    Point(x: 700.0, y: 580.0),
    Point(x: 685.0, y: 595.0),
    Point(x: 685.0, y: 610.0),
    Point(x: 770.0, y: 610.0),
    Point(x: 795.0, y: 645.0),
    Point(x: 720.0, y: 635.0),
    Point(x: 760.0, y: 650.0),
    Point(x: 475.0, y: 960.0),
    Point(x: 95.0, y: 260.0),
    Point(x: 875.0, y: 920.0),
    Point(x: 700.0, y: 500.0),
    Point(x: 555.0, y: 815.0),
    Point(x: 830.0, y: 485.0),
    Point(x: 1170.0, y: 65.0),
    Point(x: 830.0, y: 610.0),
    Point(x: 605.0, y: 625.0),
    Point(x: 595.0, y: 360.0),
    Point(x: 1340.0, y: 725.0),
    Point(x: 1740.0, y: 245.0),
  ]

  func edgeCost(_ x: Edge<Point>) -> Double {
    let vs = Array(x.vertices)
    return vs[0].distance(to: vs[1])
  }

  var graph = Graph(vertices: coordinates)
  for (i, x) in coordinates.enumerated() {
    for y in coordinates[..<i] {
      graph.insertEdge(x, y)
    }
  }
  let path = graph.christofides(edgeCost: edgeCost)
  #expect(path.first! == path.last!)
  #expect(Set(path) == Set(coordinates))
  #expect(path.count == coordinates.count + 1)

  let pathLength = zip(path[..<(path.count - 1)], path[1...]).map {
    $0.0.distance(to: $0.1)
  }.reduce(0, +)
  #expect(pathLength < 7542.0 * 3.0 / 2.0)
}
