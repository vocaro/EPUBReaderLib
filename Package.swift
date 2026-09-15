// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EPUBReaderLib",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EPUBReaderLib", targets: ["EPUBReaderLib"]),
        .library(name: "EPUBReaderFoliate", targets: ["EPUBReaderFoliate"]),
    ],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")],
    targets: [
        .target(name: "EPUBReaderLib", dependencies: ["ZIPFoundation"]),
        .target(name: "EPUBReaderFoliate", dependencies: ["EPUBReaderLib"],
                resources: [.copy("Resources/epub-reader")]),
        .target(name: "EPUBTestSupport", dependencies: ["ZIPFoundation"], path: "Tests/EPUBTestSupport"),
        .testTarget(name: "EPUBReaderLibTests", dependencies: ["EPUBReaderLib", "EPUBTestSupport"]),
        .testTarget(name: "EPUBReaderFoliateTests", dependencies: ["EPUBReaderFoliate", "EPUBTestSupport"]),
    ]
)
