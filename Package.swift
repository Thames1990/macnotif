// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacNotif",
    platforms: [.macOS("15.0")],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", exact: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "macnotif",
            dependencies: [.product(name: "TOMLKit", package: "TOMLKit")],
            path: ".",
            exclude: ["Resources", "docs", "scripts", "tests", "templates", "build", "README.md",
                      "AGENTS.md", "GLOSSARY.md", "build.sh"],
            sources: ["main.swift", "NoticeConfiguration.swift"]
        )
    ]
)
