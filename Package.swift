// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "WeChat",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .executable(name: "wechat", targets: ["WeChat"]),
    .library(name: "WeChatLibrary", targets: ["WeChatLibrary"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.3.1"))
  ],
  targets: [
    .executableTarget(
      name: "WeChat",
      dependencies: ["WeChatLibrary"]
    ),
    .target(
      name: "WeChatLibrary",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]
    ),
  ]
)
