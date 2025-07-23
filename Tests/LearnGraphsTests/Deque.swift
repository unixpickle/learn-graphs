import Testing

@testable import LearnGraphs

@Test
func testDeque() {
  for _ in 0..<5 {
    var groundTruth = [Int]()

    func slowPopFirst() -> Int? {
      if groundTruth.isEmpty {
        nil
      } else {
        groundTruth.remove(at: 0)
      }
    }

    var deque = Deque<Int>()
    for _ in 0..<100 {
      let op = Int.random(in: 0..<4)
      switch op {
      case 0:
        #expect(slowPopFirst() == deque.popFirst())
      case 1:
        #expect(groundTruth.popLast() == deque.popLast())
      case 2:
        let item = Int.random(in: 0..<100)
        groundTruth.append(item)
        deque.pushLast(item)
      default:
        let item = Int.random(in: 0..<100)
        groundTruth.insert(item, at: 0)
        deque.pushFirst(item)
      }
    }
  }
}
