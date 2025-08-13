import Foundation
import LearnGraphs

@main
struct App {
  static func main() {
    let boardData = readBoard()
    print("building board graph...")
    let g = boardGraph()
    print("creating constraints...")
    let constraints = Dictionary(
      uniqueKeysWithValues: boardData.enumerated().compactMap { (i, x) in
        x == nil ? nil : (i, x! - 1)
      }
    )
    print("solving color problem...")
    let (solution, colorCount) = g.colorDepthFirst(
      using: constraints,
      minColorCount: 9,
      maxColorCount: 9
    )!
    print("solution has \(colorCount) colors")
    for row in 0..<9 {
      let rowValues = ((row * 9)..<((row + 1) * 9)).map { String(format: "%d", solution[$0]! + 1) }
      print(rowValues.joined(separator: ""))
    }
  }

  static func readBoard() -> [Int?] {
    print("enter board row-by-row with numbers or spaces in each cell")

    // Read all stdin (works for piping or redirection)
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard var input = String(data: data, encoding: .utf8) else {
      fputs("Error: could not read UTF-8 from stdin.\n", stderr)
      exit(1)
    }

    // Normalize line endings
    input = input.replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    let lines = input.split(separator: "\n", omittingEmptySubsequences: false)

    guard lines.count >= 9 else {
      fputs("Error: expected at least 9 lines, got \(lines.count).\n", stderr)
      exit(1)
    }

    var board = [Int?]()
    board.reserveCapacity(81)

    for (rowIndex, line) in lines.prefix(9).enumerated() {
      var row: [Int?] = []
      row.reserveCapacity(9)

      for ch in line {
        if let v = ch.wholeNumberValue, (1...9).contains(v) {
          row.append(v)
        } else if ch.isWhitespace {
          // whitespace represents an empty cell
          row.append(nil)
        } else {
          fputs("Error: invalid character '\(ch)' on line \(rowIndex + 1).\n", stderr)
          exit(1)
        }
        if row.count == 9 { break }  // ignore any extra trailing characters on the line
      }

      // If line was shorter than 9 cells, pad empties
      if row.count < 9 {
        row.append(contentsOf: Array(repeating: nil, count: 9 - row.count))
      } else if row.count > 9 {
        fputs("Error: line \(rowIndex + 1) has more than 9 cells.\n", stderr)
        exit(1)
      }

      board.append(contentsOf: row)
    }

    // At this point `board` is your 9*9 Int? array
    // Do whatever you need with it. For demo, we’ll just print a compact summary:
    // (Comment this out if you want completely silent behavior.)
    // print(board)

    // Example: ensure it’s exactly 81 cells
    assert(board.count == 81)

    return board
  }

  static func boardGraph() -> Graph<Int> {
    var g = Graph<Int>(vertices: 0..<81)

    func makeClique<C: Sequence<Int>>(_ idxs: C) {
      for x in idxs {
        for y in idxs {
          if x != y {
            g.insertEdge(x, y)
          }
        }
      }
    }

    // Connect rows and columns
    for i in 0..<9 {
      makeClique((i * 9)..<((i + 1) * 9))
      makeClique(stride(from: i, to: i + 81, by: 9))
    }

    // Connect square blocks
    for row in 0..<3 {
      for col in 0..<3 {
        let idxs = ((row * 3)..<(row * 3 + 3)).flatMap { i in
          ((col * 3)..<(col * 3 + 3)).map { j in i * 9 + j }
        }
        makeClique(idxs)
      }
    }

    return g
  }

}
