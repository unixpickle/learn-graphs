import Testing

@testable import LearnGraphs

@Test
func testHeap() {
  var groundTruth = [Int]()
  var heap = [Int]()
  for _ in 0..<1000 {
    if Int.random(in: 0..<3) == 0 {
      // Delete
      #expect(heap.popHeap() == groundTruth.popLast())
    } else {
      // Insert
      let item = Int.random(in: 0..<100)
      heap.pushHeap(item)
      groundTruth.append(item)
      groundTruth.sort()
      groundTruth.reverse()
      #expect(heap.sorted().reversed() == groundTruth)
    }
  }
}

@Test
func testPriorityQueue() {
  var groundTruth = [Int]()
  var queue = PriorityQueue<Int, Int>()
  for _ in 0..<1000 {
    if Int.random(in: 0..<3) == 0 {
      // Delete
      #expect(queue.pop()?.item == groundTruth.popLast())
    } else {
      // Insert
      var item = Int.random(in: 0..<1000)
      while groundTruth.contains(item) {
        item = Int.random(in: 0..<1000)
      }
      queue.push(item, priority: item)
      groundTruth.append(item)
      groundTruth.sort()
    }
  }

  for item in groundTruth.shuffled() {
    queue.modify(item: item, priority: -item)
  }
  var popped = [Int]()
  while let x = queue.pop()?.item {
    popped.append(x)
  }
  #expect(popped == groundTruth)
}
