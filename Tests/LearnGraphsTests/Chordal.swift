import Testing

@testable import LearnGraphs

@Test
func testIsChordalTree() {
  var nextID = 1
  func randomTree(_ g: inout Graph<Int>, _ id: Int) {
    let numChildren =
      switch Int.random(in: 0..<4) {
      case 0, 1: 0
      case 2: 1
      case 3: 2
      default: fatalError()
      }
    for _ in 0..<numChildren {
      let newNode = nextID
      nextID += 1
      g.insert(vertex: newNode)
      g.insertEdge(id, newNode)
      randomTree(&g, newNode)
    }
  }
  for _ in 0..<10 {
    var g = Graph<Int>(vertices: [0])
    nextID = 1
    randomTree(&g, 0)
    #expect(g.isChordal())
  }
}

@Test
func testIsChordalSquare() {
  var g = Graph(vertices: [0, 1, 2, 3], edges: [Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 0)])
  #expect(!g.isChordal())
  g.insert(edge: Edge(0, 2))
  #expect(g.isChordal())
  g.insert(edge: Edge(1, 3))
  #expect(g.isChordal())
}

@Test
func testIsChordalPentagon() {
  var g = Graph(
    vertices: [0, 1, 2, 3, 4],
    edges: [
      Edge(0, 1), Edge(1, 2), Edge(2, 3), Edge(3, 4), Edge(4, 0),
    ]
  )
  #expect(!g.isChordal())
  g.insert(edge: Edge(0, 2))
  #expect(!g.isChordal())
  g.insert(edge: Edge(2, 4))
  #expect(g.isChordal())
  g.remove(edge: Edge(2, 4))

  g.insert(edge: Edge(0, 3))
  #expect(g.isChordal())
  g.remove(edge: Edge(0, 3))

  g.insert(edge: Edge(1, 4))
  #expect(!g.isChordal())
  g.insert(edge: Edge(1, 3))
  #expect(!g.isChordal())

  // Removing an edge removes a cycle that wasn't triangulated.
  g.remove(edge: Edge(0, 2))
  #expect(g.isChordal())
}

@Test
func testIsChordalKTree() {
  for _ in 0..<10 {
    let g = Graph(randomKTree: 0..<20, k: (1...10).randomElement()!)
    #expect(g.isChordal())
  }
}

@Test
func testMCSTriangulate() {
  var tested = 0
  while tested < 20 {
    var g = Graph(random: 0..<20, edgeProb: 0.1)
    if g.isChordal() {
      continue
    }
    g.mcsTriangulate()
    #expect(g.isChordal())
    tested += 1
  }
}
