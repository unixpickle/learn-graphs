extension MultiGraph {

  private class CycleNode {
    let vertex: V
    var next: CycleNode?

    init(vertex: V, next: CycleNode? = nil) {
      self.vertex = vertex
      self.next = next
    }
  }

  /// Create an Eulerian cycle through the graph, possibly starting at a
  /// specified vertex.
  ///
  /// If a cycle cannot be found, either because there's a node of odd degree
  /// or because the graph contains more than one component, this will return
  /// nil.
  public func eulerianCycle(start: V? = nil) -> [V]? {
    guard let someVertex = vertices.first else {
      return []
    }

    let start = start ?? someVertex
    let startNode = CycleNode(vertex: start)
    var visitedVertices: Set<V> = [start]
    var remainingEdges = [V: [V: UInt]]()
    var vertexToSomeNode = [V: CycleNode]()
    guard let startAdj = adjacencies[start] else {
      return nil
    }
    remainingEdges[start] = startAdj
    vertexToSomeNode[start] = startNode

    func removeEdge(_ v1: V, _ v2: V) {
      for (v1, v2) in [(v1, v2), (v2, v1)] {
        if remainingEdges[v1]![v2] == 1 {
          remainingEdges[v1]!.removeValue(forKey: v2)
          if remainingEdges[v1]!.isEmpty {
            remainingEdges.removeValue(forKey: v1)
          }
        } else {
          remainingEdges[v1]![v2]! -= 1
        }
      }
    }

    while let nextStart = remainingEdges.keys.first {
      let startNode = vertexToSomeNode[nextStart]!
      let oldNext = startNode.next
      var currentNode = startNode
      var didCycle = false
      while let otherVertex = remainingEdges[currentNode.vertex]?.keys.first {
        if !visitedVertices.contains(otherVertex) {
          visitedVertices.insert(otherVertex)
          remainingEdges[otherVertex] = adjacencies[otherVertex]!
        }
        removeEdge(currentNode.vertex, otherVertex)

        let nextNode = CycleNode(vertex: otherVertex)
        currentNode.next = nextNode
        currentNode = nextNode
        vertexToSomeNode[otherVertex] = nextNode

        if otherVertex == nextStart {
          didCycle = true
          break
        }
      }
      if !didCycle {
        return nil
      }
      currentNode.next = oldNext
    }
    if vertexToSomeNode.count < vertices.count {
      return nil
    }

    var path = [V]()
    var node: CycleNode? = startNode
    while let n = node {
      path.append(n.vertex)
      node = n.next
    }
    return path
  }
}

extension Graph {
  public func eulerianCycle(start: V? = nil) -> [V]? {
    MultiGraph(self).eulerianCycle(start: start)
  }
}
