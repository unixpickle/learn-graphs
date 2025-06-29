// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "LearnGraphs",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "LearnGraphs", targets: ["LearnGraphs"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "LearnGraphs",
      dependencies: []
    ),
    .testTarget(
      name: "LearnGraphsTests",
      dependencies: [
        "LearnGraphs"
      ],
      swiftSettings: [
        .enableExperimentalFeature("Testing")
      ]
    ),
    .executableTarget(
      name: "TimeMatchings",
      dependencies: [
        "LearnGraphs"
      ],
      exclude: [
        "timings.png"
      ]
    ),
    .executableTarget(
      name: "PlotTSP",
      dependencies: [
        "LearnGraphs"
      ],
      exclude: [
        "plot.png",
        "berlin52.tsp",
      ]
    ),
  ]
)
