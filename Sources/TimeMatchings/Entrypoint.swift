import Foundation
import LearnGraphs

func timeMatching(
  algorithm: MaxCardMinCostMatchAlgorithm,
  graph: Graph<Int>,
  weights: [Edge<Int>: Double]
) -> Double {
  let t1 = DispatchTime.now().uptimeNanoseconds

  let _ = graph.maxCardMinCostMatch(algorithm: algorithm) { weights[$0]! }

  let t2 = DispatchTime.now().uptimeNanoseconds
  return Double(t2 - t1) / 1e9
}

func randomGraph(count: Int, prob: Double) -> (graph: Graph<Int>, weights: [Edge<Int>: Double]) {
  let graph = Graph(random: 0..<count, edgeProb: prob)
  let weights = Dictionary(
    uniqueKeysWithValues: graph.edgeSet.map { ($0, Double.random(in: 0.0..<1.0)) }
  )
  return (graph, weights)
}

func timeAlgo<C>(
  algorithm: MaxCardMinCostMatchAlgorithm,
  counts: C,
  prob: Double,
  sampleCount: Int = 3
) -> [Double] where C: Collection<Int> {
  return counts.map { c in
    return (0..<sampleCount).map { _ in
      let (graph, weights) = randomGraph(count: c, prob: prob)
      return timeMatching(algorithm: algorithm, graph: graph, weights: weights)
    }.reduce(0.0, +) / Double(sampleCount)
  }
}

for (algo, xs): (MaxCardMinCostMatchAlgorithm, [Int]) in [
  (.bruteForce, [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
  (.blossom, [3, 4, 5, 10, 20, 40, 80, 160, 320]),
] {
  let ys = timeAlgo(algorithm: algo, counts: xs, prob: 1.0)
  print("\"\(algo)\": (\(xs), \(ys)),")
}
