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

  var count: Int = 0
  var first: Node? = nil
  var last: Node? = nil

  public init(_ item: V) {
    first = Node(data: item)
    last = first
  }

  func insert(data: V) {
    count += 1
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
    other.count = 0
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

public class ContractedVertex<V>: Hashable where V: Hashable {
  public let vertices: Set<V>

  /// An arbitrary vertex in the set that can be used to represent this vertex
  /// for recursive algorithms.
  public let representative: V

  internal init(vertices: Set<V>) {
    self.vertices = vertices
    self.representative = vertices.first!
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }

  public static func == (_ a: ContractedVertex<V>, _ b: ContractedVertex<V>) -> Bool {
    a === b
  }
}

extension Graph {

  /// Contract the edges to arrive at a new graph where vertices in the new
  /// graph correspond to one or more vertices in this graph.
  ///
  /// Edges between vertices of the new graph may correspond to multiple
  /// original edges in the graph, and this mapping is returned.
  public func contract<C>(edges e: C) -> (
    Graph<ContractedVertex<V>>, [Edge<ContractedVertex<V>>: Set<Edge<V>>]
  ) where C: Collection<Edge<V>> {
    var newGraph: Graph<ContractedVertex<V>> = .init()
    var vMap = [V: ContractedVertex<V>]()
    for s in contractionGroups(edges: e, includeSingle: true) {
      let cv = ContractedVertex(vertices: s)
      for v in s {
        vMap[v] = cv
      }
      newGraph.insert(vertex: cv)
    }

    var edgeMap = [Edge<ContractedVertex<V>>: Set<Edge<V>>]()
    for edge in edgeSet {
      let vs = edge.vertices.map { vMap[$0]! }
      if vs[0] == vs[1] {
        continue
      }
      edgeMap[Edge(vs[0], vs[1]), default: .init()].insert(edge)
      newGraph.insertEdge(vs[0], vs[1])
    }

    return (newGraph, edgeMap)
  }

  /// Perform the core part of edge contraction by gathering sets of vertices
  /// that become equivalent under contraction.
  ///
  /// If a vertex is not involved in a merge, then it will only be included in
  /// a singleton set if includeSingle is true.
  public func contractionGroups<C>(edges e: C, includeSingle: Bool) -> [Set<V>]
  where C: Collection<Edge<V>> {
    var v2vs = [V: LinkedList<V>]()
    for contractEdge in e {
      let vs: [LinkedList<V>] = contractEdge.vertices.map { v in
        if let result = v2vs[v] {
          return result
        } else {
          let x: LinkedList<V> = .init(v)
          v2vs[v] = x
          return x
        }
      }
      var keepList = vs[0]
      var deleteList = vs[1]

      if keepList === deleteList {
        continue
      } else if deleteList.count > keepList.count {
        // Minimize the number of entries in v2vs that we have to update
        swap(&keepList, &deleteList)
      }

      // Point all vertices that pointed to deleteList to keepList.
      for item in deleteList.array() {
        v2vs[item] = keepList
      }

      // Move deleteList items into keepList.
      keepList.join(other: deleteList)
    }

    var result = [ObjectIdentifier: Set<V>]()
    for item in v2vs.values {
      let id = ObjectIdentifier(item)
      if result[id] == nil {
        result[id] = Set(item.array())
      }
    }

    var resultArray = Array(result.values)
    if includeSingle {
      let included = Set(resultArray.flatMap { $0 })
      for v in vertices {
        if !included.contains(v) {
          resultArray.append([v])
        }
      }
    }

    return resultArray
  }

}
