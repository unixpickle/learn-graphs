import Testing

@testable import LearnGraphs

@Test(arguments: [MaxFlowAlgorithm.linearProgram, .edmundsKarp])
func testMaxFlowSimple(_ algo: MaxFlowAlgorithm) {
  let graph = Graph(vertices: [0, 1], edges: [Edge(0, 1)])
  let flow = graph.maxFlow(from: 0, to: 1, algorithm: algo) { (_, _) in 1.0 }
  ensureFlowIsValid(flow: flow, from: 0, to: 1)
  #expect(abs(flow.totalFlow(from: 0) - 1) < 1e-5)
}

@Test(arguments: [MaxFlowAlgorithm.linearProgram, .edmundsKarp])
func testMaxFlowMinCut(_ algo: MaxFlowAlgorithm) {
  var i = 0
  while i < 5 {
    let graph = Graph(random: 0..<20, edgeProb: 0.1)
    if graph.components().count > 1 {
      continue
    }
    i += 1
    let costs = Dictionary(
      uniqueKeysWithValues: graph.edgeSet.map { ($0, Double.random(in: 0..<1)) }
    )
    let (a, b, cost) = graph.minCostCut { costs[$0]! }
    let someA = a.first!
    let someB = b.first!
    let flow = graph.maxFlow(from: someA, to: someB, algorithm: algo) {
      costs[Edge($0, $1)]!
    }
    ensureFlowIsValid(flow: flow, from: someA, to: someB)
    #expect(abs(flow.totalFlow(from: someA) - cost) < 1e-5)
  }
}

func ensureFlowIsValid<V: Hashable>(flow: Flow<V, Double>, from: V, to: V) {
  for (source, dests) in flow.flows {
    let sum = dests.values.reduce(0, +)
    if source == from {
      #expect(sum >= 0)
    } else if source == to {
      #expect(sum <= 0)
    } else {
      #expect(abs(sum) < 1e-5)
    }
  }
}
