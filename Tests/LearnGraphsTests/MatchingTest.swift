import Darwin
import Testing

@testable import LearnGraphs

@Test(arguments: [MaxCardMatchAlgorithm.bruteForce, .blossom])
func testMaxCardMatchSimple(_ algo: MaxCardMatchAlgorithm) {
  var graph = Graph(vertices: 0...3, edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3)])
  #expect(graph.maxCardMatch(algorithm: algo) == [Edge(0, 1), Edge(2, 3)])

  graph = Graph(vertices: 0...3, edges: [Edge(0, 1), Edge(1, 2), Edge(2, 0)])
  #expect(graph.maxCardMatch(algorithm: algo).count == 1)

  graph = Graph(vertices: 0...3, edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 0)])
  let match = graph.maxCardMatch(algorithm: algo)
  #expect(match == [Edge(0, 1), Edge(2, 3)] || match == [Edge(1, 2), Edge(3, 0)])
}

@Test(arguments: [MaxCardMinCostMatchAlgorithm.bruteForce, .blossom])
func testMaxCardMinCostMatchSimple(_ algo: MaxCardMinCostMatchAlgorithm) {
  var graph = Graph(vertices: 0...3, edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3)])
  var matching = graph.maxCardMinCostMatch(algorithm: algo) { edge in
    switch edge {
    case Edge(0, 1): 3.0
    case Edge(1, 2): 0.0
    case Edge(2, 3): 3.0
    default: fatalError()
    }
  }
  #expect(matching == [Edge(0, 1), Edge(2, 3)])

  graph = Graph(vertices: 0...3, edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3)])
  matching = graph.maxCardMinCostMatch(algorithm: algo) { edge in
    switch edge {
    case Edge(0, 1): 0.0
    case Edge(1, 2): 3.0
    case Edge(2, 3): 0.0
    default: fatalError()
    }
  }
  #expect(matching == [Edge(0, 1), Edge(2, 3)])

  graph = Graph(vertices: 0...3, edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 0)])
  matching = graph.maxCardMinCostMatch(algorithm: algo) { edge in
    switch edge {
    case Edge(0, 1): 0.0
    case Edge(1, 2): 3.0
    case Edge(2, 3): 5.0
    case Edge(3, 0): 1.0
    default: fatalError()
    }
  }
  #expect(matching == [Edge(1, 2), Edge(3, 0)])

  graph = Graph(vertices: 0...3, edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 0)])
  matching = graph.maxCardMinCostMatch(algorithm: algo) { edge in
    switch edge {
    case Edge(0, 1): 0.0
    case Edge(1, 2): 3.0
    case Edge(2, 3): 3.0
    case Edge(3, 0): 1.0
    default: fatalError()
    }
  }
  #expect(matching == [Edge(0, 1), Edge(2, 3)])
}

@Test(arguments: [MaxCardMinCostMatchAlgorithm.bruteForce, .blossom])
func testMaxCardMinCostMatchBipartite(_ algo: MaxCardMinCostMatchAlgorithm) {
  let weights: [[Double]] = [
    [0.63703113, 0.05463863, 0.7068842, 0.881898, 0.51384588],
    [0.4628616, 0.89583315, 0.96715435, 0.64414505, 0.6300843],
    [0.6044282, 0.41535184, 0.66711726, 0.42664525, 0.01200919],
    [0.09214885, 0.18397983, 0.26484529, 0.52215792, 0.6478958],
    [0.42073377, 0.8417317, 0.94740205, 0.07050757, 0.13856445],
  ]
  var graph = Graph(vertices: 0..<10)
  var edgeWeights = [Edge<Int>: Double]()
  for (i, ws) in weights.enumerated() {
    for (j, w) in ws.enumerated() {
      graph.insertEdge(i, j + 5)
      edgeWeights[Edge(i, j + 5)] = w
    }
  }

  let matching = graph.maxCardMinCostMatch(algorithm: algo) { edgeWeights[$0]! }
  #expect(
    matching == [Edge(0, 1 + 5), Edge(1, 0 + 5), Edge(2, 4 + 5), Edge(3, 2 + 5), Edge(4, 3 + 5)]
  )
}

@Test(arguments: [MaxCardMinCostMatchAlgorithm.blossom])
func testMaxCardMinCostRandom(_ algo: MaxCardMinCostMatchAlgorithm) {
  for _ in 0..<30 {
    let graph = Graph(random: 0..<10, edgeProb: Double.random(in: 0.1...1.0))
    let edgeWeights = Dictionary(
      uniqueKeysWithValues: graph.edgeSet.map { ($0, Double.random(in: 0.0..<1.0)) }
    )
    let expected = graph.maxCardMinCostMatch(algorithm: .bruteForce) { edgeWeights[$0]! }
    let m = graph.maxCardMinCostMatch(algorithm: algo) { edgeWeights[$0]! }
    #expect(m == expected)
  }
}
