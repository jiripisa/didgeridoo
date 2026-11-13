// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Didgeridoo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // The macOS app (bundle assembled by build.sh — see development_workflow.md §2).
        .executable(name: "Didgeridoo", targets: ["Didgeridoo"]),
        // App logic without UI — what `swift test` covers.
        .library(name: "DidgeridooCore", targets: ["DidgeridooCore"]),
        // The Audio Unit's code (build.sh turns it into Didgeridoo.component).
        .library(name: "DidgeridooAU", type: .dynamic, targets: ["DidgeridooAU"]),
    ],
    dependencies: [
        // Auto-update: the standard updater for apps outside the App Store;
        // EdDSA-signed appcast on GitHub Pages.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4"),
    ],
    targets: [
        // The sound engine: C++ with a C interface (include/DidgeridooDSP.h).
        .target(
            name: "DidgeridooDSP",
            path: "Sources/DidgeridooDSP",
            exclude: ["dsp/LICENSE-MPC-SDK.txt"]
        ),
        // Apple's AudioUnitSDK (Apache-2.0), vendored: it is not a Swift package.
        .target(
            name: "AudioUnitSDK",
            path: "ThirdParty/AudioUnitSDK",
            exclude: ["LICENSE.txt"],
            sources: ["src"],
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMIDI"),
            ]
        ),
        // The Audio Unit (AUv2 instrument). build.sh wraps the dylib into Didgeridoo.component.
        .target(
            name: "DidgeridooAU",
            dependencies: ["DidgeridooDSP", "AudioUnitSDK"],
            path: "Sources/DidgeridooAU",
            linkerSettings: [
                // A plug-in shares the host's process with other plug-ins: export only the
                // factory function the host looks up (AudioUnit-Info.plist, factoryFunction).
                .unsafeFlags(["-Xlinker", "-exported_symbol", "-Xlinker", "_DidgeridooAUFactory"]),
            ]
        ),
        .target(
            name: "DidgeridooCore",
            dependencies: ["DidgeridooDSP"],
            path: "Sources/DidgeridooCore"
        ),
        .executableTarget(
            name: "Didgeridoo",
            dependencies: [
                "DidgeridooCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Didgeridoo",
            linkerSettings: [
                // Embedded frameworks ship in Contents/Frameworks (build.sh).
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "DidgeridooCoreTests",
            // The engine too: some of its promises are tested through its C interface.
            dependencies: ["DidgeridooCore", "DidgeridooDSP"],
            path: "Tests/DidgeridooCoreTests"
        ),
    ],
    // AudioUnitSDK needs C++23.
    cxxLanguageStandard: .cxx2b
)
