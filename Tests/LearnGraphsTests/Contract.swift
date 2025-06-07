import Testing

@testable import LearnGraphs

@Test
func testContractSimple1() {
  var graph = AdjList(vertices: 0...3)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  let (g1, edgeMap) = graph.contract(edges: [UndirectedEdge(2, 3)])

  #expect(
    g1.edgeSet
      == Set([
        UndirectedEdge(Set([0]), Set([1])),
        UndirectedEdge(Set([0]), Set([2, 3])),
        UndirectedEdge(Set([1]), Set([2, 3])),
      ])
  )
  #expect(
    edgeMap == [
      UndirectedEdge(Set([0]), Set([1])): Set([UndirectedEdge(0, 1)]),
      UndirectedEdge(Set([0]), Set([2, 3])): Set([UndirectedEdge(0, 2)]),
      UndirectedEdge(Set([1]), Set([2, 3])): Set([UndirectedEdge(1, 3)]),
    ]
  )
}

@Test
func testContractSimple2() {
  var graph = AdjList(vertices: 0...3)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(0, 3)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  let (g1, edgeMap) = graph.contract(edges: [UndirectedEdge(2, 3)])

  #expect(
    g1.edgeSet
      == Set([
        UndirectedEdge(Set([0]), Set([1])),
        UndirectedEdge(Set([0]), Set([2, 3])),
        UndirectedEdge(Set([1]), Set([2, 3])),
      ])
  )
  #expect(
    edgeMap == [
      UndirectedEdge(Set([0]), Set([1])): Set([UndirectedEdge(0, 1)]),
      UndirectedEdge(Set([0]), Set([2, 3])): Set([UndirectedEdge(0, 2), UndirectedEdge(0, 3)]),
      UndirectedEdge(Set([1]), Set([2, 3])): Set([UndirectedEdge(1, 3)]),
    ]
  )
}

@Test
func testContractMulti1() {
  var graph = AdjList(vertices: 0...3)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(0, 3)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  let (g1, edgeMap) = graph.contract(edges: [UndirectedEdge(2, 3), UndirectedEdge(0, 1)])

  #expect(
    g1.edgeSet
      == Set([
        UndirectedEdge(Set([0, 1]), Set([2, 3]))
      ])
  )
  #expect(
    edgeMap == [
      UndirectedEdge(Set([0, 1]), Set([2, 3])): Set([
        UndirectedEdge(0, 2), UndirectedEdge(0, 3), UndirectedEdge(1, 3),
      ])
    ]
  )
}

@Test
func testContractMulti2() {
  var graph = AdjList(vertices: 0...5)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(0, 3)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  graph.insertEdge(4, 0)
  graph.insertEdge(5, 1)
  graph.insertEdge(5, 2)
  graph.insertEdge(5, 3)
  let (g1, edgeMap) = graph.contract(edges: [UndirectedEdge(2, 3), UndirectedEdge(0, 1)])

  #expect(
    g1.edgeSet
      == Set([
        UndirectedEdge(Set([0, 1]), Set([2, 3])),
        UndirectedEdge(Set([0, 1]), Set([4])),
        UndirectedEdge(Set([0, 1]), Set([5])),
        UndirectedEdge(Set([2, 3]), Set([5])),
      ])
  )
  #expect(
    edgeMap == [
      UndirectedEdge(Set([0, 1]), Set([2, 3])): Set([
        UndirectedEdge(0, 2), UndirectedEdge(0, 3), UndirectedEdge(1, 3),
      ]),
      UndirectedEdge(Set([0, 1]), Set([4])): Set([
        UndirectedEdge(0, 4)
      ]),
      UndirectedEdge(Set([0, 1]), Set([5])): Set([
        UndirectedEdge(1, 5)
      ]),
      UndirectedEdge(Set([2, 3]), Set([5])): Set([
        UndirectedEdge(2, 5), UndirectedEdge(3, 5),
      ]),
    ]
  )
}

@Test
func testContractMulti3() {
  var graph = AdjList(vertices: 0...5)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(0, 3)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  graph.insertEdge(4, 0)
  graph.insertEdge(5, 1)
  graph.insertEdge(5, 2)
  graph.insertEdge(5, 3)
  let (g1, edgeMap) = graph.contract(edges: [
    UndirectedEdge(2, 3), UndirectedEdge(0, 1), UndirectedEdge(0, 3),
  ])

  #expect(
    g1.edgeSet
      == Set([
        UndirectedEdge(Set([0, 1, 2, 3]), Set([4])),
        UndirectedEdge(Set([0, 1, 2, 3]), Set([5])),
      ])
  )
  #expect(
    edgeMap == [
      UndirectedEdge(Set([0, 1, 2, 3]), Set([4])): Set([
        UndirectedEdge(0, 4)
      ]),
      UndirectedEdge(Set([0, 1, 2, 3]), Set([5])): Set([
        UndirectedEdge(1, 5), UndirectedEdge(2, 5), UndirectedEdge(3, 5),
      ]),
    ]
  )
}
