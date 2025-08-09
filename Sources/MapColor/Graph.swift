import Foundation
import LearnGraphs

public func graphFromMap() -> Graph<String> {
  let (pairs, states) = pairsAndStates()
  return Graph(vertices: states, edges: pairs.map { (x, y) in Edge(x, y) })
}

private func pairsAndStates() -> ([(String, String)], [String]) {
  guard let url = Bundle.module.url(forResource: "input", withExtension: "svg"),
    let contents = try? String(contentsOf: url, encoding: .utf8)
  else {
    fatalError("Failed to read input.svg from bundle")
  }

  let pairPattern = #"path class="([a-zA-Z]{2})-([a-zA-Z]{2})""#
  let pairRegex = try! NSRegularExpression(pattern: pairPattern, options: [])

  let pairMatches = pairRegex.matches(
    in: contents, range: NSRange(contents.startIndex..., in: contents))

  let pairs: [(String, String)] = pairMatches.compactMap { match in
    guard match.numberOfRanges == 3,
      let range1 = Range(match.range(at: 1), in: contents),
      let range2 = Range(match.range(at: 2), in: contents)
    else {
      return nil
    }
    return (String(contents[range1]), String(contents[range2]))
  }

  let statePattern = #"path class="([a-zA-Z]{2})""#
  let stateRegex = try! NSRegularExpression(pattern: statePattern, options: [])

  let stateMatches = stateRegex.matches(
    in: contents, range: NSRange(contents.startIndex..., in: contents))

  let states: [String] = stateMatches.compactMap { match in
    guard match.numberOfRanges == 2, let range = Range(match.range(at: 1), in: contents) else {
      return nil
    }
    return String(contents[range])
  }

  return (pairs, states)
}
