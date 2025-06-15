import LearnGraphs

// let weights: [[Double]] = [
//   [0.63703113, 0.05463863, 0.7068842, 0.881898, 0.51384588],
//   [0.4628616, 0.89583315, 0.96715435, 0.64414505, 0.6300843],
//   [0.6044282, 0.41535184, 0.66711726, 0.42664525, 0.01200919],
//   [0.09214885, 0.18397983, 0.26484529, 0.52215792, 0.6478958],
//   [0.42073377, 0.8417317, 0.94740205, 0.07050757, 0.13856445],
// ]
// var graph = Graph(vertices: 0..<10)
// var edgeWeights = [Edge<Int>: Double]()
// for (i, ws) in weights.enumerated() {
//   for (j, w) in ws.enumerated() {
//     graph.insertEdge(i, j + 5)
//     edgeWeights[Edge(i, j + 5)] = w
//   }
// }

while true {
  print("--------")
  let graph = Graph(random: 0..<15, edgeProb: 0.1)
  let edgeWeights = Dictionary(
    uniqueKeysWithValues: graph.edgeSet.map { ($0, Double.random(in: 0.0..<1.0)) }
  )
  let expected = graph.maxCardMinCostMatch(algorithm: .bruteForce) { edgeWeights[$0]! }
  let m = graph.maxCardMinCostMatch(algorithm: .blossom) { edgeWeights[$0]! }
  if m == expected {
    print("found good case")
  } else {
    let expectedCost = expected.map { edgeWeights[$0]! }.reduce(0.0, +)
    let actualCost = m.map { edgeWeights[$0]! }.reduce(0.0, +)
    print("m", m)
    print("expected", expected)
    print("found bad case: expected cost \(expectedCost) but got \(actualCost)")
    break
  }
}
