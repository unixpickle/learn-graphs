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
