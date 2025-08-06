import Foundation
import Testing

@testable import LearnGraphs

@Test(arguments: [IsomorphismAlgorithm.bruteForce])
func testIsomorphismPermutedRandom(_ algo: IsomorphismAlgorithm) {
  for _ in 0..<20 {
    let count = Int.random(in: 3...5)
    let g1 = Graph(random: 0..<count, edgeProb: Double.random(in: (0.1)..<(1.0)))
    let g2 = g1.map { -$0 - 1 }

    let isomorphism = g1.isomorphism(to: g2, algorithm: algo)
    #expect(isomorphism != nil)
    guard let isomorphism = isomorphism else {
      continue
    }
    #expect(Set(isomorphism.keys) == g1.vertices)
    #expect(Set(isomorphism.values) == g2.vertices)
    #expect(g1.map { isomorphism[$0]! } == g2)
  }
}

@Test(arguments: [IsomorphismAlgorithm.bruteForce])
func testIsomorphismMismatchedEdgeCount(_ algo: IsomorphismAlgorithm) {
  for _ in 0..<20 {
    let count = Int.random(in: 3...5)
    let g1 = Graph(random: 0..<count, edgeProb: Double.random(in: (0.1)..<(1.0)))
    guard let removeEdge = g1.edgeSet.first else {
      continue
    }
    var g2 = g1
    g2.remove(edge: removeEdge)
    #expect(g1.isomorphism(to: g2, algorithm: algo) == nil)
  }
}

@Test(arguments: [IsomorphismAlgorithm.bruteForce])
func testIsomorphismSeparateCycles(_ algo: IsomorphismAlgorithm) {
  // Two separate cycles
  let g1 = Graph(
    vertices: 0...5,
    edges: [Edge(0, 1), Edge(1, 2), Edge(2, 0), Edge(3, 4), Edge(4, 5), Edge(5, 3)]
  )
  // One large cycle
  let g2 = Graph(
    vertices: 0...5,
    edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 4), Edge(4, 5), Edge(5, 0)]
  )

  // Node cardinality should all match, but the graphs are not
  // actually isomorphic.
  #expect(g1.isomorphism(to: g2, algorithm: algo) == nil)
}
