private class LinkedList<V> {
  class Node {
    let data: V
    var next: Node? = nil
    var prev: Node? = nil

    init(data: V) {
      self.data = data
    }
  }

  var isEmpty: Bool {
    first == nil
  }

  var first: Node? = nil
  var last: Node? = nil

  public init(_ item: V) {
    first = Node(data: item)
    last = first
  }

  func insert(data: V) {
    let node = Node(data: data)
    if let f = first {
      f.prev = node
      node.next = f
      first = node
    } else {
      first = node
      last = node
    }
  }

  func join(other: LinkedList) {
    if other.isEmpty {
      return
    }
    if let l = last {
      l.next = other.first
      other.first!.prev = l
      last = other.last
    } else {
      first = other.first
      last = other.last
    }
    other.first = nil
    other.last = nil
  }

  func array() -> [V] {
    var next = first
    var result = [V]()
    while let x = next {
      result.append(x.data)
      next = x.next
    }
    return result
  }

  func clear() {
    last = nil
    // Free circular references.
    while let x = first {
      first = x.next
      x.next = nil
      x.prev = nil
    }
  }

  deinit {
    clear()
  }
}

extension AdjList {

  /// Contract the edges to arrive at a new graph where vertices in the new
  /// graph correspond to one or more vertices in this graph.
  ///
  /// Edges between vertices of the new graph may correspond to multiple
  /// original edges in the graph, and this mapping is returned.
  public func contract<C>(edges e: C) -> (
    AdjList<Set<V>>, [UndirectedEdge<Set<V>>: Set<UndirectedEdge<V>>]
  ) where C: Collection<UndirectedEdge<V>> {
    var v2vs = [V: LinkedList<V>]()
    for v in vertices {
      v2vs[v] = .init(v)
    }
    for contractEdge in e {
      let vs: [LinkedList<V>] = contractEdge.vertices.map { v2vs[$0]! }
      if vs[0] === vs[1] {
        continue
      }

      // Join vs[1] into vs[0] and point all vertices in vs[1] to vs[0].
      for item in vs[1].array() {
        v2vs[item] = vs[0]
      }
      vs[0].join(other: vs[1])
    }

    var newGraph: AdjList<Set<V>> = .init()
    var sets = [V: Set<V>]()
    while let (v, vs) = v2vs.popFirst() {
      if sets[v] != nil {
        continue
      }
      let vSet = Set(vs.array())
      for v1 in vSet {
        sets[v1] = vSet
      }
      newGraph.insert(vertex: vSet)
    }

    var edgeMap = [UndirectedEdge<Set<V>>: Set<UndirectedEdge<V>>]()
    for edge in edgeSet {
      let vs = Array(edge.vertices)
      let vSet1 = sets[vs[0]]!
      let vSet2 = sets[vs[1]]!
      if vSet1 == vSet2 {
        continue
      }
      edgeMap[UndirectedEdge(vSet1, vSet2), default: .init()].insert(edge)
      newGraph.insertEdge(vSet1, vSet2)
    }
    return (newGraph, edgeMap)
  }

}
