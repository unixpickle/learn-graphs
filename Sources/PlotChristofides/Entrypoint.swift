import AppKit
import CoreGraphics
import Foundation
import LearnGraphs

struct Point: Hashable {
  let x: Double
  let y: Double

  func distance(to other: Point) -> Double {
    sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
  }
}

func normalize(_ points: [Point], to size: CGSize, padding: CGFloat = 20.0) -> [CGPoint] {
  guard let minX = points.map({ $0.x }).min(),
    let maxX = points.map({ $0.x }).max(),
    let minY = points.map({ $0.y }).min(),
    let maxY = points.map({ $0.y }).max()
  else { return [] }

  let scaleX = (size.width - 2 * padding) / CGFloat(maxX - minX)
  let scaleY = (size.height - 2 * padding) / CGFloat(maxY - minY)
  let scale = min(scaleX, scaleY)

  let heightUsed = CGFloat(maxY - minY) * scale
  let verticalPadding = (size.height - heightUsed) / 2

  return points.map { point in
    let normX = CGFloat(point.x - minX) * scale + padding
    let normY = CGFloat(point.y - minY) * scale + verticalPadding
    return CGPoint(x: normX, y: size.height - normY)
  }
}

func drawTSP(
  points: [Point], tour: [Int], imageSize: CGSize = CGSize(width: 800, height: 800), outputURL: URL
) {
  let normalized = normalize(points, to: imageSize)

  let colorSpace = CGColorSpaceCreateDeviceRGB()
  guard
    let context = CGContext(
      data: nil,
      width: Int(imageSize.width),
      height: Int(imageSize.height),
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else {
    print("Failed to create graphics context.")
    return
  }

  context.setFillColor(NSColor.white.cgColor)
  context.fill(CGRect(origin: .zero, size: imageSize))

  // Draw tour path
  context.setStrokeColor(NSColor.red.cgColor)
  context.setLineWidth(2.0)
  context.beginPath()
  context.move(to: normalized[tour[0]])
  for i in 1..<tour.count {
    context.addLine(to: normalized[tour[i]])
  }
  context.addLine(to: normalized[tour[0]])
  context.strokePath()

  // Draw points
  context.setFillColor(NSColor.black.cgColor)
  for point in normalized {
    let radius: CGFloat = 5.0
    let rect = CGRect(
      x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
    context.fillEllipse(in: rect)
  }

  // Save image
  if let cgImage = context.makeImage() {
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
      try? pngData.write(to: outputURL)
      print("Saved image to \(outputURL.path)")
    }
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

drawTSP(
  points: coordinates,
  tour: path.map { coordinates.firstIndex(of: $0)! },
  outputURL: URL(fileURLWithPath: "plot.png")
)
