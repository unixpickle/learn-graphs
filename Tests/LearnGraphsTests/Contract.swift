import Testing

@testable import LearnGraphs

extension Graph {
  public func contractAsSet<C>(edges e: C) -> (
    Graph<Set<V>>, [Edge<Set<V>>: Set<Edge<V>>]
  ) where C: Collection<Edge<V>> {
    let (g1, edgeSet) = contract(edges: e)
    return (
      g1.map { $0.vertices },
      Dictionary(
        uniqueKeysWithValues: edgeSet.map { (k, v) in
          let arr = k.vertices.map { $0.vertices }
          return (Edge(arr[0], arr[1]), v)
        }
      )
    )
  }
}

@Test
func testContractSimple1() {
  var graph = Graph(vertices: 0...3)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  let (g1, edgeMap) = graph.contractAsSet(edges: [Edge(2, 3)])

  #expect(
    g1.edgeSet
      == Set([
        Edge(Set([0]), Set([1])),
        Edge(Set([0]), Set([2, 3])),
        Edge(Set([1]), Set([2, 3])),
      ])
  )
  #expect(
    edgeMap == [
      Edge(Set([0]), Set([1])): Set([Edge(0, 1)]),
      Edge(Set([0]), Set([2, 3])): Set([Edge(0, 2)]),
      Edge(Set([1]), Set([2, 3])): Set([Edge(1, 3)]),
    ]
  )
}

@Test
func testContractSimple2() {
  var graph = Graph(vertices: 0...3)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(0, 3)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  let (g1, edgeMap) = graph.contractAsSet(edges: [Edge(2, 3)])

  #expect(
    g1.edgeSet
      == Set([
        Edge(Set([0]), Set([1])),
        Edge(Set([0]), Set([2, 3])),
        Edge(Set([1]), Set([2, 3])),
      ])
  )
  #expect(
    edgeMap == [
      Edge(Set([0]), Set([1])): Set([Edge(0, 1)]),
      Edge(Set([0]), Set([2, 3])): Set([Edge(0, 2), Edge(0, 3)]),
      Edge(Set([1]), Set([2, 3])): Set([Edge(1, 3)]),
    ]
  )
}

@Test
func testContractMulti1() {
  var graph = Graph(vertices: 0...3)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(0, 3)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  let (g1, edgeMap) = graph.contractAsSet(edges: [Edge(2, 3), Edge(0, 1)])

  #expect(
    g1.edgeSet
      == Set([
        Edge(Set([0, 1]), Set([2, 3]))
      ])
  )
  #expect(
    edgeMap == [
      Edge(Set([0, 1]), Set([2, 3])): Set([
        Edge(0, 2), Edge(0, 3), Edge(1, 3),
      ])
    ]
  )
}

@Test
func testContractMulti2() {
  var graph = Graph(vertices: 0...5)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(0, 3)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  graph.insertEdge(4, 0)
  graph.insertEdge(5, 1)
  graph.insertEdge(5, 2)
  graph.insertEdge(5, 3)
  let (g1, edgeMap) = graph.contractAsSet(edges: [Edge(2, 3), Edge(0, 1)])

  #expect(
    g1.edgeSet
      == Set([
        Edge(Set([0, 1]), Set([2, 3])),
        Edge(Set([0, 1]), Set([4])),
        Edge(Set([0, 1]), Set([5])),
        Edge(Set([2, 3]), Set([5])),
      ])
  )
  #expect(
    edgeMap == [
      Edge(Set([0, 1]), Set([2, 3])): Set([
        Edge(0, 2), Edge(0, 3), Edge(1, 3),
      ]),
      Edge(Set([0, 1]), Set([4])): Set([
        Edge(0, 4)
      ]),
      Edge(Set([0, 1]), Set([5])): Set([
        Edge(1, 5)
      ]),
      Edge(Set([2, 3]), Set([5])): Set([
        Edge(2, 5), Edge(3, 5),
      ]),
    ]
  )
}

@Test
func testContractMulti3() {
  var graph = Graph(vertices: 0...5)
  graph.insertEdge(0, 1)
  graph.insertEdge(0, 2)
  graph.insertEdge(0, 3)
  graph.insertEdge(1, 3)
  graph.insertEdge(2, 3)
  graph.insertEdge(4, 0)
  graph.insertEdge(5, 1)
  graph.insertEdge(5, 2)
  graph.insertEdge(5, 3)
  let (g1, edgeMap) = graph.contractAsSet(edges: [
    Edge(2, 3), Edge(0, 1), Edge(0, 3),
  ])

  #expect(
    g1.edgeSet
      == Set([
        Edge(Set([0, 1, 2, 3]), Set([4])),
        Edge(Set([0, 1, 2, 3]), Set([5])),
      ])
  )
  #expect(
    edgeMap == [
      Edge(Set([0, 1, 2, 3]), Set([4])): Set([
        Edge(0, 4)
      ]),
      Edge(Set([0, 1, 2, 3]), Set([5])): Set([
        Edge(1, 5), Edge(2, 5), Edge(3, 5),
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
    var graph = Graph(vertices: vertices)
    graph.insertEdge(vertices[0], vertices[1])
    graph.insertEdge(vertices[0], vertices[2])
    graph.insertEdge(vertices[0], vertices[3])
    graph.insertEdge(vertices[1], vertices[3])
    graph.insertEdge(vertices[2], vertices[3])
    graph.insertEdge(vertices[4], vertices[0])
    graph.insertEdge(vertices[5], vertices[1])
    graph.insertEdge(vertices[5], vertices[2])
    graph.insertEdge(vertices[5], vertices[3])
    let (g1, edgeMap) = graph.contractAsSet(edges: [
      Edge(vertices[2], vertices[3]),
      Edge(vertices[0], vertices[1]),
      Edge(vertices[0], vertices[3]),
    ])

    #expect(
      g1.edgeSet
        == Set([
          Edge(
            Set([vertices[0], vertices[1], vertices[2], vertices[3]]), Set([vertices[4]])),
          Edge(
            Set([vertices[0], vertices[1], vertices[2], vertices[3]]), Set([vertices[5]])),
        ])
    )
    #expect(Vertex.refCount > 0)
    #expect(
      edgeMap == [
        Edge(
          Set([vertices[0], vertices[1], vertices[2], vertices[3]]), Set([vertices[4]])): Set([
            Edge(vertices[0], vertices[4])
          ]),
        Edge(
          Set([vertices[0], vertices[1], vertices[2], vertices[3]]), Set([vertices[5]])): Set([
            Edge(vertices[1], vertices[5]), Edge(vertices[2], vertices[5]),
            Edge(vertices[3], vertices[5]),
          ]),
      ]
    )
  }()
  #expect(Vertex.refCount == 0)
}
