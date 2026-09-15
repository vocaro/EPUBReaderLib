// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EPUBReaderLib",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "EPUBReaderLib", targets: ["EPUBReaderLib"]),
        .library(name: "EPUBReaderFoliate", targets: ["EPUBReaderFoliate"]),
        .library(name: "EPUBReaderTesting", targets: ["EPUBReaderTesting"]),
    ],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")],
    targets: [
        .target(name: "EPUBReaderLib", dependencies: ["ZIPFoundation"]),
        .target(name: "EPUBReaderTesting", dependencies: ["EPUBReaderLib"]),
        .target(name: "EPUBReaderFoliate", dependencies: ["EPUBReaderLib"],
                resources: [.copy("Resources/epub-reader")]),
        .target(name: "EPUBTestSupport", dependencies: ["ZIPFoundation"], path: "Tests/EPUBTestSupport"),
        .target(name: "ReaderSampleSupport", dependencies: ["EPUBReaderLib", "EPUBReaderFoliate"],
                path: "Examples/ReaderSample/Shared"),
        .testTarget(name: "EPUBReaderLibTests", dependencies: ["EPUBReaderLib", "EPUBReaderTesting", "EPUBTestSupport"]),
        .testTarget(name: "EPUBReaderFoliateTests", dependencies: ["EPUBReaderFoliate", "EPUBReaderTesting", "EPUBTestSupport"]),
    ]
)
