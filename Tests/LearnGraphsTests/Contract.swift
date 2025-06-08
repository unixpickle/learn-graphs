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

@Test
func testContractNoLeak() {
  class Vertex: Hashable {
    nonisolated(unsafe) static var refCount: Int = 0

    let value: Int

    init(value: Int) {
      self.value = value
      Self.refCount += 1
    }

    deinit {
      Self.refCount -= 1
    }

    static func == (lhs: Vertex, rhs: Vertex) -> Bool {
      lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(self.value)
    }
  }
  {
    let vertices = [
      Vertex(value: 0),
      Vertex(value: 1),
      Vertex(value: 2),
      Vertex(value: 3),
      Vertex(value: 4),
      Vertex(value: 5),
    ]
    var graph = AdjList(vertices: vertices)
    graph.insertEdge(vertices[0], vertices[1])
    graph.insertEdge(vertices[0], vertices[2])
    graph.insertEdge(vertices[0], vertices[3])
    graph.insertEdge(vertices[1], vertices[3])
    graph.insertEdge(vertices[2], vertices[3])
    graph.insertEdge(vertices[4], vertices[0])
    graph.insertEdge(vertices[5], vertices[1])
    graph.insertEdge(vertices[5], vertices[2])
    graph.insertEdge(vertices[5], vertices[3])
    let (g1, edgeMap) = graph.contract(edges: [
      UndirectedEdge(vertices[2], vertices[3]),
      UndirectedEdge(vertices[0], vertices[1]),
      UndirectedEdge(vertices[0], vertices[3]),
    ])

    #expect(
      g1.edgeSet
        == Set([
          UndirectedEdge(
            Set([vertices[0], vertices[1], vertices[2], vertices[3]]), Set([vertices[4]])),
          UndirectedEdge(
            Set([vertices[0], vertices[1], vertices[2], vertices[3]]), Set([vertices[5]])),
        ])
    )
    #expect(Vertex.refCount > 0)
    #expect(
      edgeMap == [
        UndirectedEdge(
          Set([vertices[0], vertices[1], vertices[2], vertices[3]]), Set([vertices[4]])): Set([
            UndirectedEdge(vertices[0], vertices[4])
          ]),
        UndirectedEdge(
          Set([vertices[0], vertices[1], vertices[2], vertices[3]]), Set([vertices[5]])): Set([
            UndirectedEdge(vertices[1], vertices[5]), UndirectedEdge(vertices[2], vertices[5]),
            UndirectedEdge(vertices[3], vertices[5]),
          ]),
      ]
    )
  }()
  #expect(Vertex.refCount == 0)
}
