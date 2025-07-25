import Foundation

/// Shell out to Python to use scipy.optimize.linprog.
public struct ScipyLPSolver: LPSolver {

  enum TextOrVector: Decodable {
    case text(String)
    case vector([Double])

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()

      if let s = try? container.decode(String.self) {
        self = .text(s)
        return
      }

      if let arr = try? container.decode([Double].self) {
        self = .vector(arr)
        return
      }

      throw DecodingError.typeMismatch(
        TextOrVector.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Expected a String or an array of Doubles")
      )
    }
  }

  public init() {}

  /// Raises fatalError() if Python is not present.
  public func minimize<C>(objective: [Double], constraints: [C]) -> Solution where C: Constraint {
    let code = """
      from scipy.optimize import linprog
      import sys
      import numpy as np
      import json

      matrix = None
      equality = None
      objective = None
      row_idx = 0

      for cmd in sys.stdin:
        obj = json.loads(cmd)
        if objective is None:
          objective = np.array(obj, dtype=np.float64)
        elif equality is None:
          equality = np.array(obj, dtype=np.float64)
          matrix = np.zeros((len(equality), len(objective)), dtype=np.float64)
        else:
          if isinstance(obj, list):
            matrix[row_idx] = np.array(obj)
          else:
            for i, x in obj.items():
              matrix[row_idx, int(i)] = x
          row_idx += 1

      res = linprog(objective, A_eq=matrix, b_eq=equality)
      if res.status == 3:
        json.dump("unbounded", sys.stdout)
      elif res.status == 0:
        json.dump(res.x.tolist() + [res.fun], sys.stdout)
      else:
        json.dump("infeasible", sys.stdout)
      """

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["python3", "-c", code]

    let stdinPipe = Pipe()
    process.standardInput = stdinPipe

    let stdoutPipe = Pipe()
    process.standardOutput = stdoutPipe

    do {
      try process.run()

      func writeObject<T: Encodable>(_ obj: T) throws {
        try stdinPipe.fileHandleForWriting.write(contentsOf: JSONEncoder().encode(obj))
        try stdinPipe.fileHandleForWriting.write(contentsOf: Data([10]))  // \n
      }
      try writeObject(objective)
      try writeObject(constraints.map { $0.equals() })
      for c in constraints {
        if let sparseConstraint = c as? SparseConstraint {
          try writeObject(sparseConstraint.coeffMap)
        } else {
          try writeObject(c.coeffs())
        }
      }
      try stdinPipe.fileHandleForWriting.close()

      let outData = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
      process.waitUntilExit()

      guard !outData.isEmpty else { fatalError("no output from program") }

      switch try JSONDecoder().decode(TextOrVector.self, from: outData) {
      case .text(let status):
        if status == "unbounded" {
          return .unbounded
        } else {
          return .infeasible
        }
      case .vector(let x):
        return .solved(solution: Array(x[..<(x.count - 1)]), cost: x.last!)
      }
    } catch {
      fatalError("could not run python process: \(error)")
    }
  }
}
