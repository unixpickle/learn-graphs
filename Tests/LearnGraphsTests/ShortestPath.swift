import Testing

@testable import LearnGraphs

@Test
func testShortestPathSimple() {
  let g = Graph(vertices: 0..<3, edges: [Edge(0, 1), Edge(1, 2), Edge(0, 2)])
  var path = g.shortestPath(from: 0, to: 1) { edge in
    switch edge {
    case Edge(0, 1): 10.0
    case Edge(1, 2): 3.0
    case Edge(0, 2): 5.0
    default: fatalError()
    }
  }
  #expect(path == [0, 2, 1])
  path = g.shortestPath(from: 0, to: 1) { edge in
    switch edge {
    case Edge(0, 1): 3.0
    case Edge(1, 2): 2.0
    case Edge(0, 2): 1.5
    default: fatalError()
    }
  }
  #expect(path == [0, 1])
}

@Test
func testShortestPathMild() {
  // https://en.wikipedia.org/wiki/File:Dijkstra_Animation.gif
  let g = Graph(
    vertices: 1...6,
    edges: [
      Edge(1, 2),
      Edge(1, 3),
      Edge(1, 6),
      Edge(2, 3),
      Edge(2, 4),
      Edge(3, 6),
      Edge(3, 4),
      Edge(4, 5),
      Edge(5, 6),
    ])
  func edgeCost(edge: Edge<Int>) -> Int {
    switch edge {
    case Edge(1, 2): 7
    case Edge(1, 3): 9
    case Edge(1, 6): 14
    case Edge(2, 3): 10
    case Edge(2, 4): 15
    case Edge(3, 6): 2
    case Edge(3, 4): 11
    case Edge(4, 5): 6
    case Edge(5, 6): 9
    default: fatalError()
    }
  }
  var path = g.shortestPath(from: 1, to: 5, edgeCost: edgeCost)
  #expect(path == [1, 3, 6, 5])
  path = g.shortestPath(from: 5, to: 1, edgeCost: edgeCost)
  #expect(path == [5, 6, 3, 1])
  path = g.shortestPath(from: 4, to: 6, edgeCost: edgeCost)
  #expect(path == [4, 3, 6])
}

@Test
func testShortestPathRandom() {
  let maxVertex = 5
  var g = Graph(vertices: 0...maxVertex)
  for i in g.vertices {
    for j in g.vertices {
      if i < j {
        g.insertEdge(i, j)
      }
    }
  }

  let costs: [Edge<Int>: Double] = Dictionary(
    uniqueKeysWithValues: g.edgeSet.map { ($0, Double.random(in: 0.0..<100.0)) }
  )
  func pathCost(_ path: [Int]) -> Double {
    let edges = zip(path[..<(path.count - 1)], path[1...]).map { Edge($0.0, $0.1) }
    return edges.map { costs[$0]! }.reduce(0, +)
  }

  let shortestPath = g.shortestPath(from: 0, to: maxVertex) { costs[$0]! }
  #expect(shortestPath != nil)
  let shortestCost = pathCost(shortestPath!)
  for _ in 0..<100 {
    let randomInner = (1...maxVertex).shuffled().makeIterator().prefix { $0 != maxVertex }
    let randomCost = pathCost([0] + randomInner + [maxVertex])
    #expect(randomCost >= shortestCost)
  }
}
