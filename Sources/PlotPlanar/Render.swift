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

  static func interpolate(from: Point, to: Point, frac: Double) -> Point {
    Point(x: from.x * (1 - frac) + to.x * frac, y: from.y * (1 - frac) + to.y * frac)
  }

  static func random() -> Point {
    Point(x: Double.random(in: 0..<1), y: Double.random(in: 0..<1))
  }
}

func normalize(_ points: [Point], to size: CGSize, padding: CGFloat = 20.0) -> [CGPoint] {
  guard
    let minX = points.map(\.x).min(),
    let maxX = points.map(\.x).max(),
    let minY = points.map(\.y).min(),
    let maxY = points.map(\.y).max(),
    maxX > minX,
    maxY > minY
  else { return [] }

  let scaleX = (size.width - 2 * padding) / CGFloat(maxX - minX)
  let scaleY = (size.height - 2 * padding) / CGFloat(maxY - minY)
  let scale = min(scaleX, scaleY)

  let widthUsed = CGFloat(maxX - minX) * scale
  let heightUsed = CGFloat(maxY - minY) * scale

  let horizontalPadding = max(padding, (size.width - widthUsed) / 2)
  let verticalPadding = max(padding, (size.height - heightUsed) / 2)

  return points.map { p in
    let x = CGFloat(p.x - minX) * scale + horizontalPadding
    let y = CGFloat(p.y - minY) * scale + verticalPadding
    return CGPoint(x: x, y: size.height - y)
  }
}

func drawGraph(
  graph: Graph<Point>,
  outputURL: URL,
  imageSize: CGSize = CGSize(width: 1600, height: 1600),
  radius: CGFloat = 10.0,
  padding: CGFloat = 40.0,
  lineWidth: CGFloat = 4.0
) {
  let points = Array(graph.vertices)
  let normalized = Dictionary(
    uniqueKeysWithValues: zip(points, normalize(points, to: imageSize, padding: padding))
  )

  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let context = CGContext(
    data: nil,
    width: Int(imageSize.width),
    height: Int(imageSize.height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!

  context.setFillColor(NSColor.white.cgColor)
  context.fill(CGRect(origin: .zero, size: imageSize))

  // Draw tour path
  context.setStrokeColor(NSColor.red.cgColor)
  context.setLineWidth(lineWidth)
  context.beginPath()
  for edge in graph.edgeSet {
    let vs = Array(edge.vertices)
    context.move(to: normalized[vs[0]]!)
    context.addLine(to: normalized[vs[1]]!)
  }
  context.strokePath()

  // Draw points
  context.setFillColor(NSColor.black.cgColor)
  for point in normalized.values {
    let rect = CGRect(
      x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
    context.fillEllipse(in: rect)
  }

  // Save image
  if let cgImage = context.makeImage() {
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
      do {
        try pngData.write(to: outputURL)
      } catch {
        print("ERROR: failed to write file to \(outputURL.path)")
      }
    }
  }
}
